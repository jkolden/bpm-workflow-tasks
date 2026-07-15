CREATE OR REPLACE PACKAGE pkg_bpm_tasks AS
-- =============================================================================
-- PKG_BPM_TASKS  --  Load & act on Fusion BPM workflow tasks via REST
-- =============================================================================
-- Endpoint: /bpm/api/4.0/tasks
-- Credential: gcs_reports (APEX Web Credential, Basic Auth to dev4)
-- =============================================================================

    gc_base_url   CONSTANT VARCHAR2(200) := 'https://ibzsjb-dev4.fa.ocs.oraclecloud.com';
    gc_credential CONSTANT VARCHAR2(50)  := 'gcs_reports';

    ---------------------------------------------------------------------------
    -- Refresh bpm_workflow_tasks with all pending tasks (full replace)
    ---------------------------------------------------------------------------
    PROCEDURE refresh_tasks(
        p_status     IN VARCHAR2 DEFAULT 'ASSIGNED',
        p_assignment IN VARCHAR2 DEFAULT 'ADMIN'
    );

    ---------------------------------------------------------------------------
    -- Act on a task: APPROVE, REJECT, ACQUIRE, REASSIGN, DELEGATE, etc.
    -- Logs result to last_action_* columns on bpm_workflow_tasks.
    -- p_assignee_id / p_assignee_type only needed for REASSIGN / DELEGATE.
    ---------------------------------------------------------------------------
    PROCEDURE action_task(
        p_task_number   IN NUMBER,
        p_action        IN VARCHAR2,
        p_comment       IN VARCHAR2 DEFAULT NULL,
        p_assignee_id   IN VARCHAR2 DEFAULT NULL,
        p_assignee_type IN VARCHAR2 DEFAULT 'user'
    );

END pkg_bpm_tasks;
/
