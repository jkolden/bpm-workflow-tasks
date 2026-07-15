-- =============================================================================
-- BPM_WORKFLOW_TASKS  --  Pending approval / action requests from Fusion BPM
-- =============================================================================
-- Source: GET /bpm/api/4.0/tasks?assignment=ADMIN&status=ASSIGNED
-- Loaded by: pkg_bpm_tasks.refresh_tasks
-- =============================================================================

CREATE TABLE bpm_workflow_tasks (
    task_number         NUMBER          NOT NULL,
    task_id             VARCHAR2(64),
    title               VARCHAR2(500),
    task_def_name       VARCHAR2(200),
    category            VARCHAR2(200),
    state               VARCHAR2(50),
    priority            NUMBER,
    assignee_id         VARCHAR2(200),
    assignee_type       VARCHAR2(50),       -- 'user' or 'appRole'
    created_by          VARCHAR2(200),
    created_ts          TIMESTAMP,
    assigned_ts         TIMESTAMP,
    updated_ts          TIMESTAMP,
    from_user_name      VARCHAR2(200),
    from_user_display   VARCHAR2(200),
    owner_user          VARCHAR2(200),      -- e.g. fusion_apps_hcm_adf_appid
    identification_key  VARCHAR2(200),      -- Fusion business object ID
    approval_duration   NUMBER,             -- milliseconds
    last_action         VARCHAR2(50),
    last_action_ts      TIMESTAMP,
    last_action_status  VARCHAR2(50),      -- OK, ERROR
    last_action_response VARCHAR2(4000),   -- full API response for debugging
    refreshed_ts        TIMESTAMP DEFAULT systimestamp,
    CONSTRAINT bpm_workflow_tasks_pk PRIMARY KEY (task_number)
);

-- Suggested IRR query:
--
-- SELECT task_number,
--        title,
--        INITCAP(REPLACE(
--            REGEXP_REPLACE(task_def_name, '([a-z])([A-Z])', '\1 \2'),
--            'Approval', '')) AS task_type,
--        category,
--        assignee_id,
--        assignee_type,
--        created_by,
--        from_user_display   AS submitted_by,
--        assigned_ts,
--        ROUND(SYSDATE - CAST(assigned_ts AS DATE)) AS days_pending,
--        priority,
--        identification_key
--   FROM bpm_workflow_tasks
--  ORDER BY assigned_ts DESC;
