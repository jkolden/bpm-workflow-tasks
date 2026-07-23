create or replace PACKAGE BODY pkg_bpm_tasks AS

    -- =========================================================================
    -- REFRESH_TASKS  --  Incremental refresh of bpm_workflow_tasks via BPM REST
    -- Orders by updatedDate desc and stops paging once we reach tasks
    -- already synced.  First run (empty table) fetches everything.
    -- =========================================================================

    PROCEDURE refresh_tasks(
        p_status     IN VARCHAR2 DEFAULT 'ASSIGNED',
        p_assignment IN VARCHAR2 DEFAULT 'ADMIN'
    ) IS
        l_url          VARCHAR2(1000);
        l_response     CLOB;
        l_offset       NUMBER := 0;
        c_limit        CONSTANT NUMBER := 100;
        l_has_more     VARCHAR2(10);
        l_total        NUMBER := 0;
        l_page_rows    NUMBER;
        l_last_sync    TIMESTAMP(6);
        l_min_updated  TIMESTAMP(6);
    BEGIN
        -- Most recent updatedDate we already have (NULL on first run)
        SELECT MAX(updated_ts) INTO l_last_sync FROM bpm_workflow_tasks;

        LOOP
            l_url := pkg_bicc_common.gc_fa_base_url || '/bpm/api/4.0/tasks'
                  || '?assignment=' || p_assignment
                  || '&status=ASSIGNED'
                  || '&status=COMPLETED'
                  || '&status=WITHDRAWN'
                  || '&status=EXPIRED'
                  || '&status=ERRORED'
                  || '&status=SUSPENDED'
                  || '&orderBy=updatedDate:desc'
                  || '&limit='  || c_limit
                  || '&offset=' || l_offset;

            l_response := apex_web_service.make_rest_request(
                p_url                  => l_url,
                p_http_method          => 'GET',
                p_credential_static_id => gc_credential
            );

            -- Find the oldest updatedDate in this page
            SELECT MIN(TO_TIMESTAMP(j.updated_date, 'YYYY-MM-DD HH24:MI:SS'))
              INTO l_min_updated
              FROM JSON_TABLE(l_response, '$.items[*]' COLUMNS (
                  updated_date VARCHAR2(50) PATH '$.updatedDate'
              )) j;

            -- Empty page — nothing returned
            EXIT WHEN l_min_updated IS NULL;

            MERGE INTO bpm_workflow_tasks t
            USING (
                SELECT
                    j.task_number, j.task_id, j.title, j.task_def_name, j.category,
                    j.state, j.priority, j.assignee_id, j.assignee_type,
                    j.created_by,
                    TO_TIMESTAMP(j.created_date,  'YYYY-MM-DD HH24:MI:SS') AS created_ts,
                    TO_TIMESTAMP(j.assigned_date, 'YYYY-MM-DD HH24:MI:SS') AS assigned_ts,
                    TO_TIMESTAMP(j.updated_date,  'YYYY-MM-DD HH24:MI:SS') AS updated_ts,
                    j.from_user_name, j.from_user_display, j.owner_user,
                    j.identification_key, j.approval_duration
                FROM JSON_TABLE(l_response, '$.items[*]' COLUMNS (
                    task_number       NUMBER         PATH '$.number',
                    task_id           VARCHAR2(64)   PATH '$.taskId',
                    title             VARCHAR2(500)  PATH '$.title',
                    task_def_name     VARCHAR2(200)  PATH '$.taskDefinitionName',
                    category          VARCHAR2(200)  PATH '$.category',
                    state             VARCHAR2(50)   PATH '$.state',
                    priority          NUMBER         PATH '$.priority',
                    assignee_id       VARCHAR2(200)  PATH '$.assignees.items[0].id',
                    assignee_type     VARCHAR2(50)   PATH '$.assignees.items[0].type',
                    created_by        VARCHAR2(200)  PATH '$.createdBy',
                    created_date      VARCHAR2(50)   PATH '$.createdDate',
                    assigned_date     VARCHAR2(50)   PATH '$.assignedDate',
                    updated_date      VARCHAR2(50)   PATH '$.updatedDate',
                    from_user_name    VARCHAR2(200)  PATH '$.fromUserName',
                    from_user_display VARCHAR2(200)  PATH '$.fromUserDisplayName',
                    owner_user        VARCHAR2(200)  PATH '$.ownerUser',
                    identification_key VARCHAR2(200) PATH '$.identificationKey',
                    approval_duration NUMBER         PATH '$.approvalDuration'
                )) j
            ) s ON (t.task_number = s.task_number)
            WHEN MATCHED THEN UPDATE SET
                t.task_id            = s.task_id,
                t.title              = s.title,
                t.task_def_name      = s.task_def_name,
                t.category           = s.category,
                t.state              = s.state,
                t.priority           = s.priority,
                t.assignee_id        = s.assignee_id,
                t.assignee_type      = s.assignee_type,
                t.created_by         = s.created_by,
                t.created_ts         = s.created_ts,
                t.assigned_ts        = s.assigned_ts,
                t.updated_ts         = s.updated_ts,
                t.from_user_name     = s.from_user_name,
                t.from_user_display  = s.from_user_display,
                t.owner_user         = s.owner_user,
                t.identification_key = s.identification_key,
                t.approval_duration  = s.approval_duration,
                t.refreshed_ts       = SYSTIMESTAMP
            WHEN NOT MATCHED THEN INSERT (
                task_number, task_id, title, task_def_name, category,
                state, priority, assignee_id, assignee_type,
                created_by, created_ts, assigned_ts, updated_ts,
                from_user_name, from_user_display, owner_user,
                identification_key, approval_duration
            ) VALUES (
                s.task_number, s.task_id, s.title, s.task_def_name, s.category,
                s.state, s.priority, s.assignee_id, s.assignee_type,
                s.created_by, s.created_ts, s.assigned_ts, s.updated_ts,
                s.from_user_name, s.from_user_display, s.owner_user,
                s.identification_key, s.approval_duration
            );

            l_page_rows := SQL%ROWCOUNT;
            l_total     := l_total + l_page_rows;

            -- If the oldest task in this page predates our watermark, we've
            -- caught up.  Use < (not <=) so tasks sharing the exact same
            -- updatedDate on a page boundary are not skipped.
            EXIT WHEN l_last_sync IS NOT NULL
                  AND l_min_updated < l_last_sync;

            l_has_more := JSON_VALUE(l_response, '$.hasMore');
            EXIT WHEN l_has_more != 'true';
            EXIT WHEN l_offset > 10000;   -- safety cap

            l_offset := l_offset + c_limit;
        END LOOP;

        COMMIT;

        DBMS_OUTPUT.PUT_LINE('Refreshed ' || l_total || ' workflow tasks.');
    END refresh_tasks;


    -- =========================================================================
    -- ACTION_TASK  --  Approve / Reject / Acquire / Reassign a BPM task
    -- =========================================================================

    PROCEDURE action_task(
        p_task_number   IN NUMBER,
        p_action        IN VARCHAR2,
        p_comment       IN VARCHAR2 DEFAULT NULL,
        p_assignee_id   IN VARCHAR2 DEFAULT NULL,
        p_assignee_type IN VARCHAR2 DEFAULT 'user',
        p_credential_id IN VARCHAR2 DEFAULT NULL
    ) IS
        l_url            VARCHAR2(1000);
        l_body           CLOB;
        l_response       CLOB;
        l_task_response  CLOB;
        l_status         NUMBER;
        l_errmsg         VARCHAR2(4000);
        l_action_count   NUMBER;
        l_cred           VARCHAR2(50) := NVL(p_credential_id, gc_credential);
    BEGIN
        -- Fetch task detail to check allowed actions — use caller's credential
        -- so actionList reflects what that user is actually permitted to do.
        l_url := pkg_bicc_common.gc_fa_base_url || '/bpm/api/4.0/tasks/' || p_task_number;

        l_task_response := apex_web_service.make_rest_request(
            p_url                  => l_url,
            p_http_method          => 'GET',
            p_credential_static_id => l_cred
        );

        SELECT COUNT(*)
          INTO l_action_count
          FROM JSON_TABLE(
              l_task_response,
              '$.actionList[*]'
              COLUMNS (
                  action_id VARCHAR2(100) PATH '$.actionId'
              )
          )
         WHERE action_id = UPPER(p_action);

        IF l_action_count = 0 THEN
            raise_application_error(
                -20001,
                'Task ' || p_task_number || ' does not permit ' || UPPER(p_action)
            );
        END IF;

        -- ACQUIRE uses 4.0 single-task endpoint;
        -- other actions (APPROVE, REJECT, etc.) use 3.0 bulk endpoint
        IF UPPER(p_action) = 'ACQUIRE' THEN
            l_url := pkg_bicc_common.gc_fa_base_url
                  || '/bpm/api/4.0/tasks/' || p_task_number;

            l_body := '{"action":{"id":"ACQUIRE"}}';
        ELSE
            l_url := pkg_bicc_common.gc_fa_base_url || '/bpm/api/3.0/tasks';

            l_body := '{"tasks":["' || TO_CHAR(p_task_number) || '"]'
                   || ',"action":{"id":"' || UPPER(p_action) || '"}';

            IF p_comment IS NOT NULL THEN
                l_body := l_body || ',"comment":{"commentStr":"'
                       || apex_escape.json(p_comment)
                       || '","commentScope":"TASK"}';
            END IF;

            IF p_assignee_id IS NOT NULL THEN
                l_body := l_body || ',"identities":[{"id":"'
                       || apex_escape.json(p_assignee_id)
                       || '","type":"' || NVL(p_assignee_type, 'user') || '"}]';
            END IF;

            l_body := l_body || '}';
        END IF;

        -- Set headers
        apex_web_service.g_request_headers.DELETE;
        apex_web_service.g_request_headers(1).name  := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/json';
        apex_web_service.g_request_headers(2).name  := 'Accept';
        apex_web_service.g_request_headers(2).value := 'application/json';

        l_response := apex_web_service.make_rest_request(
            p_url                  => l_url,
            p_http_method          => 'PUT',
            p_body                 => l_body,
            p_credential_static_id => l_cred
        );

        l_status := apex_web_service.g_status_code;

        -- On success the API echoes the full task JSON — store nothing.
        -- On error store a truncated snippet for debugging.
        UPDATE bpm_workflow_tasks
           SET last_action          = UPPER(p_action),
               last_action_ts       = SYSTIMESTAMP,
               last_action_status   = CASE WHEN l_status = 200 THEN 'OK' ELSE 'ERROR' END,
               last_action_response = CASE WHEN l_status = 200
                                           THEN NULL
                                           ELSE SUBSTR(l_response, 1, 500)
                                      END
         WHERE task_number = p_task_number;
        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            l_errmsg := SQLERRM;
            UPDATE bpm_workflow_tasks
               SET last_action          = UPPER(p_action),
                   last_action_ts       = SYSTIMESTAMP,
                   last_action_status   = 'ERROR',
                   last_action_response = l_errmsg
             WHERE task_number = p_task_number;
            COMMIT;
            RAISE;
    END action_task;

    -- =========================================================================
    -- GET_TASK_ACTIONS  --  Fetch task detail JSON for a single task  (4.0 API)
    -- Returns raw JSON CLOB; caller parses $.actionList[*].actionId.
    -- Uses gc_user_credential so BPM reflects the logged-in user's permissions.
    -- =========================================================================

    FUNCTION get_task_actions(p_task_number IN NUMBER) RETURN CLOB IS
        l_url      VARCHAR2(1000);
        l_response CLOB;
    BEGIN
        l_url := pkg_bicc_common.gc_fa_base_url || '/bpm/api/4.0/tasks/' || p_task_number;

        l_response := apex_web_service.make_rest_request(
            p_url                  => l_url,
            p_http_method          => 'GET',
            p_credential_static_id => gc_user_credential
        );

        RETURN l_response;
    END get_task_actions;


    -- =========================================================================
    -- GET_COMMENTS  --  Fetch comments for a single task  (4.0 API)
    -- Returns raw JSON CLOB for the APEX page to parse and render.
    -- =========================================================================

    FUNCTION get_comments(p_task_number IN NUMBER) RETURN CLOB IS
        l_url      VARCHAR2(1000);
        l_response CLOB;
    BEGIN
        l_url := pkg_bicc_common.gc_fa_base_url || '/bpm/api/4.0/tasks/' || p_task_number || '/comments';

        l_response := apex_web_service.make_rest_request(
            p_url                  => l_url,
            p_http_method          => 'GET',
            p_credential_static_id => gc_credential
        );

        RETURN l_response;
    END get_comments;


    -- =========================================================================
    -- ADD_COMMENT  --  Post a comment to a task  (3.0 API)
    -- =========================================================================

    PROCEDURE add_comment(
        p_task_number IN NUMBER,
        p_comment     IN VARCHAR2
    ) IS
        l_url      VARCHAR2(1000);
        l_body     VARCHAR2(4000);
        l_response CLOB;
    BEGIN
        l_url := pkg_bicc_common.gc_fa_base_url || '/bpm/api/3.0/tasks/' || p_task_number || '/comments';

        l_body := '{"commentStr":"' || apex_escape.json(p_comment) || '"}';

        apex_web_service.g_request_headers.DELETE;
        apex_web_service.g_request_headers(1).name  := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/json';
        apex_web_service.g_request_headers(2).name  := 'Accept';
        apex_web_service.g_request_headers(2).value := 'application/json';

        l_response := apex_web_service.make_rest_request(
            p_url                  => l_url,
            p_http_method          => 'POST',
            p_body                 => l_body,
            p_credential_static_id => gc_credential
        );

        IF apex_web_service.g_status_code != 200 THEN
            raise_application_error(
                -20002,
                'Add comment failed (HTTP ' || apex_web_service.g_status_code
                || '): ' || SUBSTR(l_response, 1, 500)
            );
        END IF;
    END add_comment;


    -- =========================================================================
    -- GET_ATTACHMENTS  --  Fetch attachments for a single task  (4.0 API)
    -- Returns raw JSON CLOB for the APEX page to parse and render.
    -- =========================================================================

    FUNCTION get_attachments(p_task_number IN NUMBER) RETURN CLOB IS
        l_url      VARCHAR2(1000);
        l_response CLOB;
    BEGIN
        l_url := pkg_bicc_common.gc_fa_base_url || '/bpm/api/4.0/tasks/' || p_task_number || '/attachments';

        l_response := apex_web_service.make_rest_request(
            p_url                  => l_url,
            p_http_method          => 'GET',
            p_credential_static_id => gc_credential
        );

        RETURN l_response;
    END get_attachments;


    -- =========================================================================
    -- ADD_ATTACHMENT  --  Upload an attachment to a task  (3.0 API)
    -- Accepts base64-encoded file content, decodes to BLOB, and POSTs as
    -- multipart/mixed (same format proven in add attachment.sql).
    -- =========================================================================

    PROCEDURE add_attachment(
        p_task_number  IN NUMBER,
        p_file_name    IN VARCHAR2,
        p_content_type IN VARCHAR2,
        p_file_b64     IN CLOB
    ) IS
        l_url       VARCHAR2(1000);
        l_boundary  VARCHAR2(100) := '----OracleBpmBoundary7MA4YWxk';
        l_crlf      VARCHAR2(2)   := CHR(13) || CHR(10);
        l_body      BLOB;
        l_file_blob BLOB;
        l_response  CLOB;

        PROCEDURE append_text(p_blob IN OUT NOCOPY BLOB, p_text IN VARCHAR2) IS
            l_raw RAW(32767);
        BEGIN
            l_raw := utl_raw.cast_to_raw(p_text);
            dbms_lob.writeappend(p_blob, utl_raw.length(l_raw), l_raw);
        END append_text;

    BEGIN
        -- Decode base64 to BLOB
        l_file_blob := apex_web_service.clobbase642blob(p_file_b64);

        dbms_lob.createtemporary(l_body, TRUE);

        -- Part 1: JSON metadata
        append_text(l_body, '--' || l_boundary || l_crlf);
        append_text(l_body,
            'Content-Disposition: form-data; '
            || 'name="part1"; filename="request.json"' || l_crlf);
        append_text(l_body, 'Content-Type: application/json' || l_crlf || l_crlf);
        append_text(l_body,
            '{"attachmentName":"' || apex_escape.json(p_file_name)
            || '","mimeType":"' || apex_escape.json(p_content_type)
            || '"}' || l_crlf);

        -- Part 2: file bytes
        append_text(l_body, '--' || l_boundary || l_crlf);
        append_text(l_body,
            'Content-Disposition: form-data; '
            || 'name="part2"; filename="'
            || apex_escape.json(p_file_name) || '"' || l_crlf);
        append_text(l_body, 'Content-Type: ' || p_content_type || l_crlf || l_crlf);

        -- Append actual file BLOB bytes
        dbms_lob.append(l_body, l_file_blob);
        append_text(l_body, l_crlf);

        -- Closing boundary
        append_text(l_body, '--' || l_boundary || '--' || l_crlf);

        -- Headers + POST
        l_url := pkg_bicc_common.gc_fa_base_url || '/bpm/api/3.0/tasks/' || p_task_number || '/attachments';

        apex_web_service.g_request_headers.DELETE;
        apex_web_service.g_request_headers(1).name  := 'Content-Type';
        apex_web_service.g_request_headers(1).value :=
            'multipart/mixed; boundary="' || l_boundary || '"';
        apex_web_service.g_request_headers(2).name  := 'Accept';
        apex_web_service.g_request_headers(2).value := 'application/json';

        l_response := apex_web_service.make_rest_request(
            p_url                  => l_url,
            p_http_method          => 'POST',
            p_body_blob            => l_body,
            p_credential_static_id => gc_credential
        );

        dbms_lob.freetemporary(l_body);

        IF apex_web_service.g_status_code NOT IN (200, 201) THEN
            raise_application_error(
                -20003,
                'Add attachment failed (HTTP ' || apex_web_service.g_status_code
                || '): ' || SUBSTR(l_response, 1, 500)
            );
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            IF l_body IS NOT NULL
               AND dbms_lob.istemporary(l_body) = 1
            THEN
                dbms_lob.freetemporary(l_body);
            END IF;
            RAISE;
    END add_attachment;

    -- =========================================================================
    -- GET_PAYLOAD  --  Fetch raw XML payload for a single task  (4.0 API)
    -- Returns the raw XML CLOB.  Parsing is done by emit_payload_fields below.
    -- =========================================================================

    FUNCTION get_payload(p_task_number IN NUMBER) RETURN CLOB IS
        l_url      VARCHAR2(1000);
        l_response CLOB;
    BEGIN
        l_url := pkg_bicc_common.gc_fa_base_url
              || '/bpm/api/4.0/tasks/' || p_task_number || '/payload';

        l_response := apex_web_service.make_rest_request(
            p_url                  => l_url,
            p_http_method          => 'GET',
            p_credential_static_id => gc_credential
        );

        RETURN l_response;
    END get_payload;


    -- =========================================================================
    -- EMIT_PAYLOAD_FIELDS (private)  --  Write apex_json {label,value} objects
    -- for a task payload, keyed on task_def_name.
    -- Called from the GET_TASK_PAYLOAD Ajax callback on page 6004.
    -- Add a new ELSIF branch here when onboarding a new workflow type.
    --
    -- Supported task_def_name values:
    --   FinApInvoiceApproval           Invoice Number, Supplier, Amount, Type, Requestor
    --   ReqApproval                    Supplier, PO Number, Requisition, Amount, Requester, Type
    --   FinExmWorkflowExpenseApproval /
    --     FinExmWorkflowSpendAuth      Report Number, Employee, Amount, Submitted By
    --   FinGlJournalApproval           Batch, Amount, Requestor, Date
    --                                  (Oracle typo: element is "trasactionDate")
    --   FlowManualTaskApproval         Flow, Category, Task, Owner (workflowProcess ns)
    --   TransfersApproval / Promotions /
    --     Assignments / Terminations /
    --     ChangeAssignment             Employee, Module (HCM sparse, TransactionApproval ns)
    --   DocumentApproval               Requisition Number, Approval Type, Attachments flag
    --   TimecardApprovalELA            Employee, Period, Time Type, Submitted By
    --   AbsencesApprovalsTask          Employee, Absence Type, Period, Duration, Submitted, Action
    --   FinApIncompleteInvoiceHold     Invoice Number, Hold Reason
    -- =========================================================================

    PROCEDURE emit_payload_fields(p_task_number IN NUMBER) IS
        l_task_def VARCHAR2(200);
        l_payload  CLOB;
        l_xml      XMLTYPE;

        -- Emit a {label,value} object only when value is non-blank
        PROCEDURE emit(p_label IN VARCHAR2, p_value IN VARCHAR2) IS
        BEGIN
            IF p_value IS NOT NULL AND TRIM(p_value) IS NOT NULL THEN
                apex_json.open_object;
                apex_json.write('label', p_label);
                apex_json.write('value', p_value);
                apex_json.close_object;
            END IF;
        END emit;

    BEGIN
        SELECT task_def_name INTO l_task_def
          FROM bpm_workflow_tasks
         WHERE task_number = p_task_number;

        l_payload := get_payload(p_task_number);
        l_xml     := XMLType(l_payload);

        -- ------------------------------------------------------------------
        --  AP Invoice approvals
        --  Payload elements are direct children of <payload> in the BPM ns.
        -- ------------------------------------------------------------------
        IF l_task_def = 'FinApInvoiceApproval' THEN
            FOR r IN (
                SELECT x.invoice_num, x.supplier_name, x.invoice_amount,
                       x.invoice_currency, x.invoice_type, x.requestor
                  FROM XMLTABLE(
                           XMLNAMESPACES(
                               'http://xmlns.oracle.com/bpel/workflow/task' AS "t"
                           ),
                           '/t:payload'
                           PASSING l_xml
                           COLUMNS
                               invoice_num      VARCHAR2(100) PATH 't:invoiceNum',
                               supplier_name    VARCHAR2(200) PATH 't:supplierName',
                               invoice_amount   VARCHAR2(50)  PATH 't:invoiceAmount',
                               invoice_currency VARCHAR2(10)  PATH 't:invoiceCurrencyCode',
                               invoice_type     VARCHAR2(50)  PATH 't:invoiceType',
                               requestor        VARCHAR2(200) PATH 't:invoiceRequestor'
                       ) x
            ) LOOP
                emit('Invoice Number', r.invoice_num);
                emit('Supplier',       r.supplier_name);
                emit('Amount',         r.invoice_amount
                                       || CASE WHEN r.invoice_currency IS NOT NULL
                                               THEN ' ' || r.invoice_currency END);
                emit('Invoice Type',   INITCAP(r.invoice_type));
                emit('Requestor',      r.requestor);
            END LOOP;

        -- ------------------------------------------------------------------
        --  HCM employment change approvals (Transfer, Promotion, etc.)
        --  Payload has service stubs; only sensorNameFromData is reliable.
        -- ------------------------------------------------------------------
        ELSIF l_task_def IN ('TransfersApproval', 'PromotionsApproval',
                             'AssignmentsApproval', 'TerminationsApproval',
                             'ChangeAssignmentApproval') THEN
            FOR r IN (
                SELECT x.employee_name, x.module_id
                  FROM XMLTABLE(
                           XMLNAMESPACES(
                               'http://xmlns.oracle.com/bpel/workflow/task' AS "bpel",
                               'http://xmlns.oracle.com/apps/hcm/transaction/model/entity/events/schema/TransactionApproval' AS "ta"
                           ),
                           '/bpel:payload/ta:TransactionApprovalRequest'
                           PASSING l_xml
                           COLUMNS
                               employee_name VARCHAR2(200) PATH 'ta:sensorNameFromData',
                               module_id     VARCHAR2(100) PATH 'ta:ModuleIdentifier'
                       ) x
            ) LOOP
                emit('Employee', r.employee_name);
                emit('Module',   r.module_id);
            END LOOP;

        -- ------------------------------------------------------------------
        --  Purchasing / Requisition approvals  (ReqApproval)
        --  Covers both new POs and change orders.
        -- ------------------------------------------------------------------
        ELSIF l_task_def = 'ReqApproval' THEN
            FOR r IN (
                SELECT x.supplier_name, x.doc_number, x.req_number,
                       x.amount, x.currency_code, x.requester, x.doc_style
                  FROM XMLTABLE(
                           XMLNAMESPACES(
                               'http://xmlns.oracle.com/bpel/workflow/task' AS "t"
                           ),
                           '/t:payload'
                           PASSING l_xml
                           COLUMNS
                               supplier_name VARCHAR2(200) PATH 't:SupplierName',
                               doc_number    VARCHAR2(50)  PATH 't:DocumentNumber',
                               req_number    VARCHAR2(50)  PATH 't:TitleToken3',
                               amount        VARCHAR2(50)  PATH 't:DocumentCurrencyApprovalTotal',
                               currency_code VARCHAR2(10)  PATH 't:DocumentCurrencyCode',
                               requester     VARCHAR2(200) PATH 't:TitleToken6',
                               doc_style     VARCHAR2(100) PATH 't:DocumentStyleDisplayName'
                       ) x
            ) LOOP
                emit('Supplier',    r.supplier_name);
                emit('PO Number',   r.doc_number);
                emit('Requisition', r.req_number);
                emit('Amount',      r.amount
                                    || CASE WHEN r.currency_code IS NOT NULL
                                            THEN ' ' || r.currency_code END);
                emit('Requester',   r.requester);
                emit('Type',        r.doc_style);
            END LOOP;

        -- ------------------------------------------------------------------
        --  Expense report approvals
        -- ------------------------------------------------------------------
        ELSIF l_task_def IN ('FinExmWorkflowExpenseApproval',
                             'FinExmWorkflowSpendAuthorization') THEN
            FOR r IN (
                SELECT x.report_number, x.requestor, x.amount,
                       x.currency_code, x.owner_email
                  FROM XMLTABLE(
                           XMLNAMESPACES(
                               'http://xmlns.oracle.com/bpel/workflow/task' AS "t"
                           ),
                           '/t:payload'
                           PASSING l_xml
                           COLUMNS
                               report_number VARCHAR2(100) PATH 't:expenseReportNumber',
                               requestor     VARCHAR2(200) PATH 't:requestorDisplayname',
                               amount        VARCHAR2(50)  PATH 't:expenseReportTotalForTitle',
                               currency_code VARCHAR2(10)  PATH 't:currencyCode',
                               owner_email   VARCHAR2(200) PATH 't:ownerUserName'
                       ) x
            ) LOOP
                emit('Report Number', r.report_number);
                emit('Employee',      r.requestor);
                emit('Amount',        r.amount
                                      || CASE WHEN r.currency_code IS NOT NULL
                                              THEN ' ' || r.currency_code END);
                emit('Submitted By',  r.owner_email);
            END LOOP;

        -- ------------------------------------------------------------------
        --  GL Journal approvals
        --  Note: Oracle typo — element is "trasactionDate" (missing n).
        --  Amount already includes currency in the formatted string.
        -- ------------------------------------------------------------------
        ELSIF l_task_def = 'FinGlJournalApproval' THEN
            FOR r IN (
                SELECT x.batch_name, x.amount, x.requestor, x.txn_date
                  FROM XMLTABLE(
                           XMLNAMESPACES(
                               'http://xmlns.oracle.com/bpel/workflow/task' AS "t"
                           ),
                           '/t:payload'
                           PASSING l_xml
                           COLUMNS
                               batch_name VARCHAR2(200) PATH 't:batchName',
                               amount     VARCHAR2(100) PATH 't:journalBatchAccountedAmount',
                               requestor  VARCHAR2(200) PATH 't:requestorDisplayName',
                               txn_date   VARCHAR2(50)  PATH 't:trasactionDate'
                       ) x
            ) LOOP
                emit('Batch',     r.batch_name);
                emit('Amount',    r.amount);
                emit('Requestor', r.requestor);
                -- Trim ISO timestamp to date only ("2025-12-16T01:07:17Z" → "2025-12-16")
                emit('Date',      SUBSTR(r.txn_date, 1, 10));
            END LOOP;

        -- ------------------------------------------------------------------
        --  HCM Process Flow manual tasks  (FlowManualTaskApproval)
        --  Payload is in the workflowProcess namespace under <process>.
        --  Category field contains a pipe-delimited code — use SubCategory.
        -- ------------------------------------------------------------------
        ELSIF l_task_def = 'FlowManualTaskApproval' THEN
            FOR r IN (
                SELECT x.flow_name, x.subcategory, x.checklist_name, x.owner
                  FROM XMLTABLE(
                           XMLNAMESPACES(
                               'http://xmlns.oracle.com/bpel/workflow/task' AS "bpel",
                               'http://xmlns.oracle.com/apps/hcm/processFlows/core/workflowProcess' AS "proc"
                           ),
                           '/bpel:payload/proc:process'
                           PASSING l_xml
                           COLUMNS
                               flow_name      VARCHAR2(200) PATH 'proc:FlowInstanceName',
                               subcategory    VARCHAR2(200) PATH 'proc:SubCategory',
                               checklist_name VARCHAR2(200) PATH 'proc:ChecklistName',
                               owner          VARCHAR2(200) PATH 'proc:Owner'
                       ) x
            ) LOOP
                emit('Flow',     r.flow_name);
                emit('Category', r.subcategory);
                emit('Task',     r.checklist_name);
                emit('Owner',    r.owner);
            END LOOP;

        -- ------------------------------------------------------------------
        --  Document (self-service requisition) approvals
        --  titleKey "HtTitle.ApproveRequisition0" confirms requisition type.
        -- ------------------------------------------------------------------
        ELSIF l_task_def = 'DocumentApproval' THEN
            FOR r IN (
                SELECT x.req_number, x.title_key, x.attachment_added
                  FROM XMLTABLE(
                           XMLNAMESPACES(
                               'http://xmlns.oracle.com/bpel/workflow/task' AS "t"
                           ),
                           '/t:payload'
                           PASSING l_xml
                           COLUMNS
                               req_number       VARCHAR2(100) PATH 't:requisitionNumber',
                               title_key        VARCHAR2(200) PATH 't:titleKey',
                               attachment_added VARCHAR2(10)  PATH 't:attachmentAdded'
                       ) x
            ) LOOP
                emit('Requisition',   r.req_number);
                emit('Approval Type', CASE r.title_key
                                          WHEN 'HtTitle.ApproveRequisition0'  THEN 'Approve Requisition'
                                          WHEN 'HtTitle.WithdrawRequisition0' THEN 'Withdraw Requisition'
                                          ELSE REPLACE(REPLACE(r.title_key, 'HtTitle.', ''), '0', '')
                                      END);
                IF r.attachment_added = 'true' THEN
                    emit('Attachments', 'Yes');
                END IF;
            END LOOP;

        -- ------------------------------------------------------------------
        --  Timecard approvals  (TimecardApprovalELA)
        --  BPM-ns payload* elements; ConsumerCode from TimeApprovalInitiatedEvent ns.
        --  ConsumerCode: PYR = Payroll, PRJ = Projects, ABS = Absence.
        -- ------------------------------------------------------------------
        ELSIF l_task_def = 'TimecardApprovalELA' THEN
            FOR r IN (
                SELECT x.employee_name, x.requester,
                       x.start_date, x.stop_date, x.consumer_code
                  FROM XMLTABLE(
                           XMLNAMESPACES(
                               'http://xmlns.oracle.com/bpel/workflow/task' AS "t",
                               'http://xmlns.oracle.com/apps/hcm/time/approval/model/entity/events/schema/TimeApprovalInitiatedEvent' AS "tm"
                           ),
                           '/t:payload'
                           PASSING l_xml
                           COLUMNS
                               employee_name VARCHAR2(200) PATH 't:payloadDisplayName',
                               requester     VARCHAR2(200) PATH 't:payloadRequester',
                               start_date    VARCHAR2(20)  PATH 't:payloadStartTime',
                               stop_date     VARCHAR2(20)  PATH 't:payloadStopTime',
                               consumer_code VARCHAR2(20)  PATH 'tm:process/tm:ConsumerCode'
                       ) x
            ) LOOP
                emit('Employee',  r.employee_name);
                emit('Period',    r.start_date
                                  || CASE WHEN r.stop_date IS NOT NULL
                                               AND r.stop_date != r.start_date
                                          THEN ' to ' || r.stop_date END);
                emit('Time Type', CASE r.consumer_code
                                      WHEN 'PYR' THEN 'Payroll'
                                      WHEN 'PRJ' THEN 'Projects'
                                      WHEN 'ABS' THEN 'Absence'
                                      ELSE r.consumer_code
                                  END);
                emit('Submitted By', r.requester);
            END LOOP;

        -- ------------------------------------------------------------------
        --  Absence approvals  (AbsencesApprovalsTask)
        --  AbsenceDispDate is pre-formatted ("12/31/2025 - 12/31/2025").
        --  NotificationName: CREATE = New, UPDATE = Amendment, DELETE = Cancellation.
        -- ------------------------------------------------------------------
        ELSIF l_task_def = 'AbsencesApprovalsTask' THEN
            FOR r IN (
                SELECT x.person_name, x.absence_type, x.disp_date,
                       x.duration, x.uom_name, x.submitted_date,
                       x.notification_name
                  FROM XMLTABLE(
                           XMLNAMESPACES(
                               'http://xmlns.oracle.com/bpel/workflow/task' AS "bpel",
                               'http://xmlns.oracle.com/apps/hcm/globalAbsences/approvals/model/entity/events/schema/AbsencesApprovalsEvent' AS "ab"
                           ),
                           '/bpel:payload/ab:AbsencesApprovalsRequest'
                           PASSING l_xml
                           COLUMNS
                               person_name       VARCHAR2(200) PATH 'ab:PersonName',
                               absence_type      VARCHAR2(200) PATH 'ab:AbsenceType',
                               disp_date         VARCHAR2(100) PATH 'ab:AbsenceDispDate',
                               duration          VARCHAR2(20)  PATH 'ab:Duration',
                               uom_name          VARCHAR2(50)  PATH 'ab:Durationuomname',
                               submitted_date    VARCHAR2(20)  PATH 'ab:SubmittedDate',
                               notification_name VARCHAR2(50)  PATH 'ab:NotificationName'
                       ) x
            ) LOOP
                emit('Employee',     r.person_name);
                emit('Absence Type', r.absence_type);
                emit('Period',       r.disp_date);
                emit('Duration',     CASE WHEN r.duration IS NOT NULL
                                          THEN r.duration
                                               || CASE WHEN r.uom_name IS NOT NULL
                                                       THEN ' ' || r.uom_name END
                                     END);
                emit('Submitted',    r.submitted_date);
                emit('Action',       CASE r.notification_name
                                         WHEN 'CREATE' THEN 'New Absence'
                                         WHEN 'UPDATE' THEN 'Amendment'
                                         WHEN 'DELETE' THEN 'Cancellation'
                                         ELSE r.notification_name
                                     END);
            END LOOP;

        -- ------------------------------------------------------------------
        --  AP Incomplete Invoice Hold  (FinApIncompleteInvoiceHold)
        --  All elements are direct children of <payload> in the BPM namespace.
        --  Supplier / amount are behind the findInvoiceHeader service stub.
        -- ------------------------------------------------------------------
        ELSIF l_task_def = 'FinApIncompleteInvoiceHold' THEN
            FOR r IN (
                SELECT x.invoice_num, x.hold_name, x.requestor
                  FROM XMLTABLE(
                           XMLNAMESPACES(
                               'http://xmlns.oracle.com/bpel/workflow/task' AS "t"
                           ),
                           '/t:payload'
                           PASSING l_xml
                           COLUMNS
                               invoice_num VARCHAR2(100) PATH 't:invoiceNum',
                               hold_name   VARCHAR2(200) PATH 't:holdName',
                               requestor   VARCHAR2(200) PATH 't:requestor'
                       ) x
            ) LOOP
                emit('Invoice Number', r.invoice_num);
                emit('Hold Reason',   INITCAP(r.hold_name));
                emit('Requestor',     r.requestor);
            END LOOP;

        -- Add ELSIF branches here for additional task definition names.
        END IF;

    END emit_payload_fields;


    -- =========================================================================
    -- GET_HISTORY  --  Fetch approval history for a single task  (4.0 API)
    -- Returns raw JSON CLOB for the APEX page to parse and render.
    -- =========================================================================

    FUNCTION get_history(p_task_number IN NUMBER) RETURN CLOB IS
        l_url      VARCHAR2(1000);
        l_response CLOB;
    BEGIN
        l_url := pkg_bicc_common.gc_fa_base_url
              || '/bpm/api/4.0/tasks/' || p_task_number || '/history';

        l_response := apex_web_service.make_rest_request(
            p_url                  => l_url,
            p_http_method          => 'GET',
            p_credential_static_id => gc_credential
        );

        RETURN l_response;
    END get_history;


    -- =========================================================================
    -- CREATE_TODO_TASK  --  Create a standalone todo task  (3.0 API)
    -- Posts to /bpm/api/3.0/tasks/todoTask — creates a notification
    -- in the assignee's BPM inbox.
    -- =========================================================================

    PROCEDURE create_todo_task(
        p_title       IN VARCHAR2,
        p_assignee_id IN VARCHAR2,
        p_priority    IN NUMBER   DEFAULT 3,
        p_start_date  IN VARCHAR2 DEFAULT NULL,
        p_due_date    IN VARCHAR2 DEFAULT NULL
    ) IS
        l_url      VARCHAR2(1000);
        l_body     VARCHAR2(4000);
        l_response CLOB;
    BEGIN
        l_url := pkg_bicc_common.gc_fa_base_url || '/bpm/api/3.0/tasks/todoTask';

        l_body := '{"title":"' || apex_escape.json(p_title) || '"'
               || ',"priority":"' || p_priority || '"'
               || ',"assignees":[{"id":"' || apex_escape.json(p_assignee_id)
               || '","type":"user"}]';

        IF p_start_date IS NOT NULL THEN
            l_body := l_body || ',"startDate":"' || apex_escape.json(p_start_date) || '"';
        END IF;

        IF p_due_date IS NOT NULL THEN
            l_body := l_body || ',"dueDate":"' || apex_escape.json(p_due_date) || '"';
        END IF;

        l_body := l_body || '}';

        apex_web_service.g_request_headers.DELETE;
        apex_web_service.g_request_headers(1).name  := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/json';
        apex_web_service.g_request_headers(2).name  := 'Accept';
        apex_web_service.g_request_headers(2).value := 'application/json';

        l_response := apex_web_service.make_rest_request(
            p_url                  => l_url,
            p_http_method          => 'POST',
            p_body                 => l_body,
            p_credential_static_id => gc_credential
        );

        IF apex_web_service.g_status_code NOT IN (200, 201) THEN
            raise_application_error(
                -20004,
                'Create todo failed (HTTP ' || apex_web_service.g_status_code
                || '): ' || SUBSTR(l_response, 1, 300)
                || ' | SENT: ' || SUBSTR(l_body, 1, 500)
            );
        END IF;
    END create_todo_task;

END pkg_bpm_tasks;
/
