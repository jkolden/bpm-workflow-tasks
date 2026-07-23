create or replace PACKAGE pkg_bpm_tasks AS
-- =============================================================================
-- PKG_BPM_TASKS  --  Load & act on Fusion BPM workflow tasks via REST
-- =============================================================================
-- Endpoint: /bpm/api/4.0/tasks
-- Credential: gcs_reports (APEX Web Credential, Basic Auth to dev4)
-- =============================================================================

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

    ---------------------------------------------------------------------------
    -- Return comments JSON for a single task  (on-demand from detail drawer)
    -- Uses 4.0 API (3.0 returns a different JSON shape).
    ---------------------------------------------------------------------------
    FUNCTION get_comments(p_task_number IN NUMBER) RETURN CLOB;

    ---------------------------------------------------------------------------
    -- Post a new comment to a task  (3.0 API)
    ---------------------------------------------------------------------------
    PROCEDURE add_comment(
        p_task_number IN NUMBER,
        p_comment     IN VARCHAR2
    );

    ---------------------------------------------------------------------------
    -- Return attachments JSON for a single task  (4.0 API)
    ---------------------------------------------------------------------------
    FUNCTION get_attachments(p_task_number IN NUMBER) RETURN CLOB;

    ---------------------------------------------------------------------------
    -- Upload an attachment to a task  (3.0 API, multipart/mixed)
    -- p_file_name     : original filename  (e.g. 'resume.pdf')
    -- p_content_type  : MIME type          (e.g. 'application/pdf')
    -- p_file_b64      : file contents as base64-encoded CLOB
    ---------------------------------------------------------------------------
    PROCEDURE add_attachment(
        p_task_number  IN NUMBER,
        p_file_name    IN VARCHAR2,
        p_content_type IN VARCHAR2,
        p_file_b64     IN CLOB
    );

    ---------------------------------------------------------------------------
    -- Return approval history JSON for a single task  (4.0 API)
    ---------------------------------------------------------------------------
    FUNCTION get_history(p_task_number IN NUMBER) RETURN CLOB;

    ---------------------------------------------------------------------------
    -- Return raw XML payload CLOB for a single task  (4.0 API)
    -- Parsed on the APEX side by GET_TASK_PAYLOAD callback, keyed on
    -- task_def_name, to produce a {label, value} field list.
    ---------------------------------------------------------------------------
    FUNCTION get_payload(p_task_number IN NUMBER) RETURN CLOB;

    ---------------------------------------------------------------------------
    -- Emit payload fields as apex_json objects (label/value pairs) for a task.
    -- Called from the GET_TASK_PAYLOAD Ajax callback — caller must have already
    -- opened an apex_json array before calling this procedure.
    -- Branches per task_def_name; emits nothing for unknown task types.
    ---------------------------------------------------------------------------
    PROCEDURE emit_payload_fields(p_task_number IN NUMBER);

    ---------------------------------------------------------------------------
    -- Create a standalone todo task  (3.0 API)
    -- Creates a notification in the assignee's BPM inbox.
    ---------------------------------------------------------------------------
    PROCEDURE create_todo_task(
        p_title       IN VARCHAR2,
        p_assignee_id IN VARCHAR2,
        p_priority    IN NUMBER   DEFAULT 3,
        p_start_date  IN VARCHAR2 DEFAULT NULL,
        p_due_date    IN VARCHAR2 DEFAULT NULL
    );

END pkg_bpm_tasks;
/