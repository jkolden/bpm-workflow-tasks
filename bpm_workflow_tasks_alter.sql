-- Add OUTCOME, END_TS, ASSIGNEES_RAW columns to bpm_workflow_tasks
-- OUTCOME:       workflow outcome (e.g. APPROVE, REJECT) from WFTASK
-- END_TS:        task completion/withdrawal timestamp from WFTASK
-- ASSIGNEES_RAW: colon-delimited "id,type" pairs as returned by WFTASK

ALTER TABLE bpm_workflow_tasks ADD (
    outcome       VARCHAR2(100),
    end_ts        TIMESTAMP(6),
    assignees_raw VARCHAR2(4000)
);
