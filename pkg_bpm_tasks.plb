CREATE OR REPLACE PACKAGE BODY pkg_bpm_tasks AS

    -- =========================================================================
    -- REFRESH_TASKS  --  Full replace of bpm_workflow_tasks from BPM REST API
    -- =========================================================================

    PROCEDURE refresh_tasks(
        p_status     IN VARCHAR2 DEFAULT 'ASSIGNED',
        p_assignment IN VARCHAR2 DEFAULT 'ADMIN'
    ) IS
        l_url        VARCHAR2(1000);
        l_response   CLOB;
        l_offset     NUMBER := 0;
        c_limit      CONSTANT NUMBER := 100;
        l_has_more   VARCHAR2(10);
        l_inserted   NUMBER := 0;
        l_page_rows  NUMBER;
    BEGIN
        LOOP
            l_url := gc_base_url || '/bpm/api/4.0/tasks'
                  || '?assignment=' || p_assignment
                  || '&status='     || p_status
                  || '&limit='      || c_limit
                  || '&offset='     || l_offset;

            l_response := apex_web_service.make_rest_request(
                p_url                  => l_url,
                p_http_method          => 'GET',
                p_credential_static_id => gc_credential
            );

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
            l_inserted  := l_inserted + l_page_rows;

            l_has_more := JSON_VALUE(l_response, '$.hasMore');
            EXIT WHEN l_has_more != 'true';
            EXIT WHEN l_offset > 10000;   -- safety cap

            l_offset := l_offset + c_limit;
        END LOOP;

        COMMIT;

        DBMS_OUTPUT.PUT_LINE('Refreshed ' || l_inserted || ' workflow tasks.');
    END refresh_tasks;


    -- =========================================================================
    -- ACTION_TASK  --  Approve / Reject / Acquire / Reassign a BPM task
    -- =========================================================================

    PROCEDURE action_task(
        p_task_number   IN NUMBER,
        p_action        IN VARCHAR2,
        p_comment       IN VARCHAR2 DEFAULT NULL,
        p_assignee_id   IN VARCHAR2 DEFAULT NULL,
        p_assignee_type IN VARCHAR2 DEFAULT 'user'
    ) IS
        l_url            VARCHAR2(1000);
        l_body           CLOB;
        l_response       CLOB;
        l_task_response  CLOB;
        l_status         NUMBER;
        l_errmsg         VARCHAR2(4000);
        l_action_count   NUMBER;
    BEGIN
        -- Fetch task detail to check allowed actions
        l_url := gc_base_url || '/bpm/api/4.0/tasks/' || p_task_number;

        l_task_response := apex_web_service.make_rest_request(
            p_url                  => l_url,
            p_http_method          => 'GET',
            p_credential_static_id => gc_credential
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

        -- Build JSON request body  (v3.0 format, string concat to avoid
        -- apex_json.initialize_clob_output which corrupts Ajax callback output)
        l_url := gc_base_url || '/bpm/api/3.0/tasks';

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
            p_credential_static_id => gc_credential
        );

        l_status := apex_web_service.g_status_code;

        -- Log the action and response for debugging
        UPDATE bpm_workflow_tasks
           SET last_action          = UPPER(p_action),
               last_action_ts       = SYSTIMESTAMP,
               last_action_status   = CASE WHEN l_status = 200 THEN 'OK' ELSE 'ERROR' END,
               last_action_response = SUBSTR(l_response, 1, 4000)
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

END pkg_bpm_tasks;
/
