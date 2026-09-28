-- ============================================================================
-- Add resignation person-mapping columns to BPM_WORKFLOW_TASKS
-- ============================================================================
-- ASSIGNMENT_ID: from WFMESSAGEATTRIBUTE TransactionApprovalRequest payload
-- PERSON_NUMBER: resolved via PER_ALL_ASSIGNMENTS_M -> PER_ALL_PEOPLE_F
-- PERSON_ID already exists on the table.
-- All nullable — only resignation tasks will have values populated.
-- ============================================================================
alter table bpm_workflow_tasks add (
    assignment_id  number,
    person_number  varchar2(30)
);
