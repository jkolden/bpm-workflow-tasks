-- =============================================================================
-- BPM Task Notification Details
-- /Custom/SCI/BIP/BPM_Task_Details.xdo
-- =============================================================================
-- Returns one row per BPM workflow task with:
--   • Core task metadata (task number, title, state, assignee, dates, etc.)
--   • Business context payload fields (up to 6 label/value pairs per task)
--     mirroring exactly what users see in the bell-icon notification detail view
--
-- Supported task types:
--   FinApInvoiceApproval           → Invoice Number, Supplier, Amount, Type, Requestor
--   FinApIncompleteInvoiceHold     → Invoice Number, Hold Reason, Requestor
--   ReqApproval                    → Supplier, PO Number, Requisition, Amount, Requester, Type
--   FinExmWorkflowExpenseApproval /
--     FinExmWorkflowSpendAuthorization → Report Number, Employee, Amount, Submitted By
--   FinGlJournalApproval           → Batch, Amount, Requestor, Date
--   FlowManualTaskApproval         → Flow, Category, Task, Owner
--   DocumentApproval               → Requisition Number, Approval Type, Attachments flag
--   TimecardApprovalELA            → Employee, Period, Time Type, Submitted By
--   AbsencesApprovalsTask          → Employee, Absence Type, Period, Duration, Submitted, Action
--   TransfersApproval / PromotionsApproval / AssignmentsApproval /
--     TerminationsApproval / ChangeAssignmentApproval → Employee, Module
--   (all other task types)         → core metadata only; payload fields null
--
-- Notes:
--   • WFTASK.PAYLOAD is assumed to be CLOB; XMLTYPE() cast is applied.
--     If the column is already XMLTYPE in your Fusion version, remove the
--     XMLTYPE() wrapper throughout.
--   • FinGlJournalApproval has an Oracle typo in the payload: element name
--     is "trasactionDate" (missing 'n') — matched exactly here.
--   • GL Amount already includes currency in its formatted string.
--
-- Parameters:
--   :P_DAYS_BACK   NUMBER    Tasks created within N days (NULL = all history)
--   :P_STATE       VARCHAR2  Filter by state: ASSIGNED, COMPLETED, etc. (NULL = all)
-- =============================================================================

with assignees as (
    -- Aggregate per-task assignees (USER type only) into a semicolon list
    select
        taskid,
        listagg(assigneeidentkey, '; ')
            within group (order by assigneeidentkey)  as assignee_list
    from wfassignee
    where assigneetype = 'user'
    group by taskid
),

base as (
    -- Core task metadata with optional date / state filters
    select
        t.tasknumber,
        t.taskid,
        t.title,
        t.taskedefinitionname,
        t.state,
        t.priority,
        t.fromuser                                        as from_user,
        t.owner                                           as owner_user,
        t.acquiredby                                      as acquired_by,
        t.identificationkey                               as identification_key,
        t.category,
        t.createddate                                     as created_ts,
        t.updateddate                                     as updated_ts,
        t.assigneddate                                    as assigned_ts,
        t.duedate                                         as due_ts,
        round(sysdate - cast(t.createddate as date))      as days_pending,
        a.assignee_list,
        -- Pre-convert payload once; used in all per-type CTEs below.
        -- If PAYLOAD is already XMLTYPE in your Fusion version, use t.payload directly.
        case
            when t.payload is not null then xmltype(t.payload)
        end                                               as payload_xml
    from wftask t
    left join assignees a on a.taskid = t.taskid
    where (:P_DAYS_BACK is null or t.createddate >= trunc(sysdate) - :P_DAYS_BACK)
      and (:P_STATE     is null or t.state = :P_STATE)
),

-- =============================================================================
-- GROUP A  –  Tasks with payload root /t:payload, BPM namespace only
-- Covers: FinApInvoiceApproval, FinApIncompleteInvoiceHold, ReqApproval,
--         FinExmWorkflow*, FinGlJournalApproval, DocumentApproval,
--         TimecardApprovalELA (t: fields only — ConsumerCode handled separately)
-- =============================================================================
bpm_ns as (
    select
        b.tasknumber,
        -- AP Invoice fields
        x.invoice_num,
        x.supplier_name,
        x.invoice_amount
            || case when x.invoice_currency is not null
                    then ' ' || x.invoice_currency end     as invoice_amount_cur,
        initcap(x.invoice_type)                            as invoice_type,
        x.invoice_requestor,
        -- AP Hold additional field
        initcap(x.hold_name)                               as hold_name,
        -- ReqApproval fields
        x.req_supplier,
        x.req_doc_number,
        x.req_req_number,
        x.req_amount
            || case when x.req_currency is not null
                    then ' ' || x.req_currency end          as req_amount_cur,
        x.req_requester,
        x.req_doc_style,
        -- Expense / Spend Auth fields
        x.exp_report_number,
        x.exp_requestor,
        x.exp_amount
            || case when x.exp_currency is not null
                    then ' ' || x.exp_currency end          as exp_amount_cur,
        x.exp_owner_email,
        -- GL Journal fields (note Oracle typo: "trasactionDate" — matched exactly)
        x.gl_batch_name,
        x.gl_amount,                                       -- already includes currency
        x.gl_requestor,
        substr(x.gl_txn_date, 1, 10)                       as gl_txn_date,
        -- Document (self-service requisition) fields
        x.doc_req_number,
        case x.doc_title_key
            when 'HtTitle.ApproveRequisition0'  then 'Approve Requisition'
            when 'HtTitle.WithdrawRequisition0' then 'Withdraw Requisition'
            else replace(replace(x.doc_title_key, 'HtTitle.', ''), '0', '')
        end                                                as doc_approval_type,
        case when x.doc_attachment = 'true' then 'Yes' end as doc_has_attachments,
        -- Timecard t:-namespace fields (ConsumerCode comes from tc_consumer below)
        x.tc_employee,
        x.tc_start_date,
        x.tc_stop_date,
        x.tc_requester
    from base b
    cross join xmltable(
        xmlnamespaces('http://xmlns.oracle.com/bpel/workflow/task' as "t"),
        '/t:payload'
        passing b.payload_xml
        columns
            -- AP Invoice
            invoice_num         varchar2(100) path 't:invoiceNum',
            supplier_name       varchar2(200) path 't:supplierName',
            invoice_amount      varchar2(50)  path 't:invoiceAmount',
            invoice_currency    varchar2(10)  path 't:invoiceCurrencyCode',
            invoice_type        varchar2(50)  path 't:invoiceType',
            invoice_requestor   varchar2(200) path 't:invoiceRequestor',
            -- AP Hold
            hold_name           varchar2(200) path 't:holdName',
            -- ReqApproval
            req_supplier        varchar2(200) path 't:SupplierName',
            req_doc_number      varchar2(50)  path 't:DocumentNumber',
            req_req_number      varchar2(50)  path 't:TitleToken3',
            req_amount          varchar2(50)  path 't:DocumentCurrencyApprovalTotal',
            req_currency        varchar2(10)  path 't:DocumentCurrencyCode',
            req_requester       varchar2(200) path 't:TitleToken6',
            req_doc_style       varchar2(100) path 't:DocumentStyleDisplayName',
            -- Expense / Spend Auth
            exp_report_number   varchar2(100) path 't:expenseReportNumber',
            exp_requestor       varchar2(200) path 't:requestorDisplayname',
            exp_amount          varchar2(50)  path 't:expenseReportTotalForTitle',
            exp_currency        varchar2(10)  path 't:currencyCode',
            exp_owner_email     varchar2(200) path 't:ownerUserName',
            -- GL Journal  (Oracle typo: "trasactionDate" is intentional)
            gl_batch_name       varchar2(200) path 't:batchName',
            gl_amount           varchar2(100) path 't:journalBatchAccountedAmount',
            gl_requestor        varchar2(200) path 't:requestorDisplayName',
            gl_txn_date         varchar2(50)  path 't:trasactionDate',
            -- Document approval
            doc_req_number      varchar2(100) path 't:requisitionNumber',
            doc_title_key       varchar2(200) path 't:titleKey',
            doc_attachment      varchar2(10)  path 't:attachmentAdded',
            -- Timecard (t: namespace elements only)
            tc_employee         varchar2(200) path 't:payloadDisplayName',
            tc_requester        varchar2(200) path 't:payloadRequester',
            tc_start_date       varchar2(20)  path 't:payloadStartTime',
            tc_stop_date        varchar2(20)  path 't:payloadStopTime'
    ) x
    where b.taskedefinitionname in (
        'FinApInvoiceApproval',
        'FinApIncompleteInvoiceHold',
        'ReqApproval',
        'FinExmWorkflowExpenseApproval',
        'FinExmWorkflowSpendAuthorization',
        'FinGlJournalApproval',
        'DocumentApproval',
        'TimecardApprovalELA'
    )
),

-- =============================================================================
-- GROUP B  –  Timecard Consumer Code (separate namespace under /t:payload)
-- ConsumerCode: PYR = Payroll, PRJ = Projects, ABS = Absence
-- =============================================================================
tc_consumer as (
    select b.tasknumber,
           case x.consumer_code
               when 'PYR' then 'Payroll'
               when 'PRJ' then 'Projects'
               when 'ABS' then 'Absence'
               else x.consumer_code
           end                                             as time_type
    from base b
    cross join xmltable(
        xmlnamespaces(
            'http://xmlns.oracle.com/bpel/workflow/task' as "t",
            'http://xmlns.oracle.com/apps/hcm/time/approval/model/entity/events/schema/TimeApprovalInitiatedEvent' as "tm"
        ),
        '/t:payload'
        passing b.payload_xml
        columns
            consumer_code varchar2(20) path 'tm:process/tm:ConsumerCode'
    ) x
    where b.taskedefinitionname = 'TimecardApprovalELA'
),

-- =============================================================================
-- GROUP C  –  Absence Approvals
-- =============================================================================
absences as (
    select
        b.tasknumber,
        x.person_name,
        x.absence_type,
        x.disp_date,
        x.duration
            || case when x.uom_name is not null
                    then ' ' || x.uom_name end             as duration_uom,
        x.submitted_date,
        case x.notification_name
            when 'CREATE' then 'New Absence'
            when 'UPDATE' then 'Amendment'
            when 'DELETE' then 'Cancellation'
            else x.notification_name
        end                                                as absence_action
    from base b
    cross join xmltable(
        xmlnamespaces(
            'http://xmlns.oracle.com/bpel/workflow/task' as "bpel",
            'http://xmlns.oracle.com/apps/hcm/globalAbsences/approvals/model/entity/events/schema/AbsencesApprovalsEvent' as "ab"
        ),
        '/bpel:payload/ab:AbsencesApprovalsRequest'
        passing b.payload_xml
        columns
            person_name       varchar2(200) path 'ab:PersonName',
            absence_type      varchar2(200) path 'ab:AbsenceType',
            disp_date         varchar2(100) path 'ab:AbsenceDispDate',
            duration          varchar2(20)  path 'ab:Duration',
            uom_name          varchar2(50)  path 'ab:Durationuomname',
            submitted_date    varchar2(20)  path 'ab:SubmittedDate',
            notification_name varchar2(50)  path 'ab:NotificationName'
    ) x
    where b.taskedefinitionname = 'AbsencesApprovalsTask'
),

-- =============================================================================
-- GROUP D  –  HCM Employment Change Approvals (sparse payload)
-- Covers: TransfersApproval, PromotionsApproval, AssignmentsApproval,
--         TerminationsApproval, ChangeAssignmentApproval
-- =============================================================================
hcm_emp as (
    select
        b.tasknumber,
        x.employee_name,
        x.module_id
    from base b
    cross join xmltable(
        xmlnamespaces(
            'http://xmlns.oracle.com/bpel/workflow/task' as "bpel",
            'http://xmlns.oracle.com/apps/hcm/transaction/model/entity/events/schema/TransactionApproval' as "ta"
        ),
        '/bpel:payload/ta:TransactionApprovalRequest'
        passing b.payload_xml
        columns
            employee_name varchar2(200) path 'ta:sensorNameFromData',
            module_id     varchar2(100) path 'ta:ModuleIdentifier'
    ) x
    where b.taskedefinitionname in (
        'TransfersApproval', 'PromotionsApproval', 'AssignmentsApproval',
        'TerminationsApproval', 'ChangeAssignmentApproval'
    )
),

-- =============================================================================
-- GROUP E  –  HCM Process Flow Manual Tasks (FlowManualTaskApproval)
-- =============================================================================
flow_tasks as (
    select
        b.tasknumber,
        x.flow_name,
        x.subcategory,
        x.checklist_name,
        x.owner
    from base b
    cross join xmltable(
        xmlnamespaces(
            'http://xmlns.oracle.com/bpel/workflow/task' as "bpel",
            'http://xmlns.oracle.com/apps/hcm/processFlows/core/workflowProcess' as "proc"
        ),
        '/bpel:payload/proc:process'
        passing b.payload_xml
        columns
            flow_name      varchar2(200) path 'proc:FlowInstanceName',
            subcategory    varchar2(200) path 'proc:SubCategory',
            checklist_name varchar2(200) path 'proc:ChecklistName',
            owner          varchar2(200) path 'proc:Owner'
    ) x
    where b.taskedefinitionname = 'FlowManualTaskApproval'
)

-- =============================================================================
-- FINAL SELECT  –  One row per task; payload columns populated per task type
-- =============================================================================
select
    -- ----- Task identity -------------------------------------------------------
    b.tasknumber                                             as task_number,
    b.title,
    b.taskedefinitionname                                    as task_def_name,
    case b.taskedefinitionname
        when 'FinApInvoiceApproval'              then 'AP Invoice Approval'
        when 'FinApIncompleteInvoiceHold'        then 'AP Invoice Hold'
        when 'ReqApproval'                       then 'PO Requisition'
        when 'FinExmWorkflowExpenseApproval'     then 'Expense Report'
        when 'FinExmWorkflowSpendAuthorization'  then 'Spend Authorization'
        when 'FinGlJournalApproval'              then 'GL Journal'
        when 'FlowManualTaskApproval'            then 'HCM Process Flow Task'
        when 'DocumentApproval'                  then 'Self-Service Requisition'
        when 'TimecardApprovalELA'               then 'Timecard'
        when 'AbsencesApprovalsTask'             then 'Absence'
        when 'TransfersApproval'                 then 'Transfer'
        when 'PromotionsApproval'                then 'Promotion'
        when 'AssignmentsApproval'               then 'Assignment Change'
        when 'TerminationsApproval'              then 'Termination'
        when 'ChangeAssignmentApproval'          then 'Assignment Change'
        else b.taskedefinitionname
    end                                                      as task_type_display,

    -- ----- Task status & routing -----------------------------------------------
    b.state,
    b.priority,
    b.from_user,
    b.assignee_list,
    b.acquired_by,
    b.owner_user,
    b.identification_key,
    b.category,

    -- ----- Dates ---------------------------------------------------------------
    b.created_ts,
    b.updated_ts,
    b.assigned_ts,
    b.due_ts,
    b.days_pending,

    -- ----- Payload field 1 -----------------------------------------------------
    case b.taskedefinitionname
        when 'FinApInvoiceApproval'              then 'Invoice Number'
        when 'FinApIncompleteInvoiceHold'        then 'Invoice Number'
        when 'ReqApproval'                       then 'Supplier'
        when 'FinExmWorkflowExpenseApproval'     then 'Report Number'
        when 'FinExmWorkflowSpendAuthorization'  then 'Report Number'
        when 'FinGlJournalApproval'              then 'Batch'
        when 'FlowManualTaskApproval'            then 'Flow'
        when 'DocumentApproval'                  then 'Requisition'
        when 'TimecardApprovalELA'               then 'Employee'
        when 'AbsencesApprovalsTask'             then 'Employee'
        when 'TransfersApproval'                 then 'Employee'
        when 'PromotionsApproval'                then 'Employee'
        when 'AssignmentsApproval'               then 'Employee'
        when 'TerminationsApproval'              then 'Employee'
        when 'ChangeAssignmentApproval'          then 'Employee'
    end                                                      as label1,
    case b.taskedefinitionname
        when 'FinApInvoiceApproval'              then ap.invoice_num
        when 'FinApIncompleteInvoiceHold'        then ap.invoice_num
        when 'ReqApproval'                       then ap.req_supplier
        when 'FinExmWorkflowExpenseApproval'     then ap.exp_report_number
        when 'FinExmWorkflowSpendAuthorization'  then ap.exp_report_number
        when 'FinGlJournalApproval'              then ap.gl_batch_name
        when 'FlowManualTaskApproval'            then fl.flow_name
        when 'DocumentApproval'                  then ap.doc_req_number
        when 'TimecardApprovalELA'               then ap.tc_employee
        when 'AbsencesApprovalsTask'             then ab.person_name
        when 'TransfersApproval'                 then hm.employee_name
        when 'PromotionsApproval'                then hm.employee_name
        when 'AssignmentsApproval'               then hm.employee_name
        when 'TerminationsApproval'              then hm.employee_name
        when 'ChangeAssignmentApproval'          then hm.employee_name
    end                                                      as value1,

    -- ----- Payload field 2 -----------------------------------------------------
    case b.taskedefinitionname
        when 'FinApInvoiceApproval'              then 'Supplier'
        when 'FinApIncompleteInvoiceHold'        then 'Hold Reason'
        when 'ReqApproval'                       then 'PO Number'
        when 'FinExmWorkflowExpenseApproval'     then 'Employee'
        when 'FinExmWorkflowSpendAuthorization'  then 'Employee'
        when 'FinGlJournalApproval'              then 'Amount'
        when 'FlowManualTaskApproval'            then 'Category'
        when 'DocumentApproval'                  then 'Approval Type'
        when 'TimecardApprovalELA'               then 'Period'
        when 'AbsencesApprovalsTask'             then 'Absence Type'
        when 'TransfersApproval'                 then 'Module'
        when 'PromotionsApproval'                then 'Module'
        when 'AssignmentsApproval'               then 'Module'
        when 'TerminationsApproval'              then 'Module'
        when 'ChangeAssignmentApproval'          then 'Module'
    end                                                      as label2,
    case b.taskedefinitionname
        when 'FinApInvoiceApproval'              then ap.supplier_name
        when 'FinApIncompleteInvoiceHold'        then ap.hold_name
        when 'ReqApproval'                       then ap.req_doc_number
        when 'FinExmWorkflowExpenseApproval'     then ap.exp_requestor
        when 'FinExmWorkflowSpendAuthorization'  then ap.exp_requestor
        when 'FinGlJournalApproval'              then ap.gl_amount
        when 'FlowManualTaskApproval'            then fl.subcategory
        when 'DocumentApproval'                  then ap.doc_approval_type
        when 'TimecardApprovalELA'               then ap.tc_start_date
                                                          || case when ap.tc_stop_date is not null
                                                                       and ap.tc_stop_date != ap.tc_start_date
                                                                  then ' to ' || ap.tc_stop_date end
        when 'AbsencesApprovalsTask'             then ab.absence_type
        when 'TransfersApproval'                 then hm.module_id
        when 'PromotionsApproval'                then hm.module_id
        when 'AssignmentsApproval'               then hm.module_id
        when 'TerminationsApproval'              then hm.module_id
        when 'ChangeAssignmentApproval'          then hm.module_id
    end                                                      as value2,

    -- ----- Payload field 3 -----------------------------------------------------
    case b.taskedefinitionname
        when 'FinApInvoiceApproval'              then 'Amount'
        when 'FinApIncompleteInvoiceHold'        then 'Requestor'
        when 'ReqApproval'                       then 'Requisition'
        when 'FinExmWorkflowExpenseApproval'     then 'Amount'
        when 'FinExmWorkflowSpendAuthorization'  then 'Amount'
        when 'FinGlJournalApproval'              then 'Requestor'
        when 'FlowManualTaskApproval'            then 'Task'
        when 'DocumentApproval'                  then 'Attachments'
        when 'TimecardApprovalELA'               then 'Time Type'
        when 'AbsencesApprovalsTask'             then 'Period'
    end                                                      as label3,
    case b.taskedefinitionname
        when 'FinApInvoiceApproval'              then ap.invoice_amount_cur
        when 'FinApIncompleteInvoiceHold'        then ap.invoice_requestor
        when 'ReqApproval'                       then ap.req_req_number
        when 'FinExmWorkflowExpenseApproval'     then ap.exp_amount_cur
        when 'FinExmWorkflowSpendAuthorization'  then ap.exp_amount_cur
        when 'FinGlJournalApproval'              then ap.gl_requestor
        when 'FlowManualTaskApproval'            then fl.checklist_name
        when 'DocumentApproval'                  then ap.doc_has_attachments
        when 'TimecardApprovalELA'               then tc.time_type
        when 'AbsencesApprovalsTask'             then ab.disp_date
    end                                                      as value3,

    -- ----- Payload field 4 -----------------------------------------------------
    case b.taskedefinitionname
        when 'FinApInvoiceApproval'              then 'Invoice Type'
        when 'ReqApproval'                       then 'Amount'
        when 'FinExmWorkflowExpenseApproval'     then 'Submitted By'
        when 'FinExmWorkflowSpendAuthorization'  then 'Submitted By'
        when 'FinGlJournalApproval'              then 'Date'
        when 'FlowManualTaskApproval'            then 'Owner'
        when 'TimecardApprovalELA'               then 'Submitted By'
        when 'AbsencesApprovalsTask'             then 'Duration'
    end                                                      as label4,
    case b.taskedefinitionname
        when 'FinApInvoiceApproval'              then ap.invoice_type
        when 'ReqApproval'                       then ap.req_amount_cur
        when 'FinExmWorkflowExpenseApproval'     then ap.exp_owner_email
        when 'FinExmWorkflowSpendAuthorization'  then ap.exp_owner_email
        when 'FinGlJournalApproval'              then ap.gl_txn_date
        when 'FlowManualTaskApproval'            then fl.owner
        when 'TimecardApprovalELA'               then ap.tc_requester
        when 'AbsencesApprovalsTask'             then ab.duration_uom
    end                                                      as value4,

    -- ----- Payload field 5 -----------------------------------------------------
    case b.taskedefinitionname
        when 'FinApInvoiceApproval'              then 'Requestor'
        when 'ReqApproval'                       then 'Requester'
        when 'AbsencesApprovalsTask'             then 'Submitted'
    end                                                      as label5,
    case b.taskedefinitionname
        when 'FinApInvoiceApproval'              then ap.invoice_requestor
        when 'ReqApproval'                       then ap.req_requester
        when 'AbsencesApprovalsTask'             then ab.submitted_date
    end                                                      as value5,

    -- ----- Payload field 6 -----------------------------------------------------
    case b.taskedefinitionname
        when 'ReqApproval'                       then 'Type'
        when 'AbsencesApprovalsTask'             then 'Action'
    end                                                      as label6,
    case b.taskedefinitionname
        when 'ReqApproval'                       then ap.req_doc_style
        when 'AbsencesApprovalsTask'             then ab.absence_action
    end                                                      as value6

from base b

-- Group A: BPM namespace payload tasks
left join bpm_ns ap
    on  ap.tasknumber = b.tasknumber
    and b.taskedefinitionname in (
            'FinApInvoiceApproval', 'FinApIncompleteInvoiceHold',
            'ReqApproval',
            'FinExmWorkflowExpenseApproval', 'FinExmWorkflowSpendAuthorization',
            'FinGlJournalApproval', 'DocumentApproval', 'TimecardApprovalELA')

-- Group B: Timecard consumer code
left join tc_consumer tc
    on  tc.tasknumber = b.tasknumber
    and b.taskedefinitionname = 'TimecardApprovalELA'

-- Group C: Absence approvals
left join absences ab
    on  ab.tasknumber = b.tasknumber
    and b.taskedefinitionname = 'AbsencesApprovalsTask'

-- Group D: HCM employment changes
left join hcm_emp hm
    on  hm.tasknumber = b.tasknumber
    and b.taskedefinitionname in (
            'TransfersApproval', 'PromotionsApproval', 'AssignmentsApproval',
            'TerminationsApproval', 'ChangeAssignmentApproval')

-- Group E: HCM process flow tasks
left join flow_tasks fl
    on  fl.tasknumber = b.tasknumber
    and b.taskedefinitionname = 'FlowManualTaskApproval'

order by b.created_ts desc
