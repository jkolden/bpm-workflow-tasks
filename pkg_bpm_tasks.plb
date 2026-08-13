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
                  || '&status=INFO_REQUESTED'
                  || '&status=ALERTED'
                  || '&status=OUTCOME_UPDATED'
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
        l_status         NUMBER;
        l_errmsg         VARCHAR2(4000);
        l_cred           VARCHAR2(50) := NVL(p_credential_id, gc_user_credential);
    BEGIN
        -- ACQUIRE and SKIP_CURRENT_ASSIGNMENT use 4.0 single-task endpoint;
        -- INFO_REQUEST uses 4.0 endpoint with identities at top level;
        -- INFO_SUBMIT uses 4.0 endpoint, no identities (routes back to requester);
        -- other actions (APPROVE, REJECT, etc.) use 3.0 bulk endpoint
        IF UPPER(p_action) IN ('ACQUIRE', 'SKIP_CURRENT_ASSIGNMENT') THEN
            l_url := pkg_bicc_common.gc_fa_base_url
                  || '/bpm/api/4.0/tasks/' || p_task_number;

            l_body := '{"action":{"id":"' || UPPER(p_action) || '"}}';

        ELSIF UPPER(p_action) = 'INFO_REQUEST' THEN

            -- 4.0 single-task endpoint; identities at top level (not inside action).
            -- comment object is included inline when provided — appears in task
            -- comments (not history). Tested: 200 received; verify via /comments.
            l_url  := pkg_bicc_common.gc_fa_base_url
                   || '/bpm/api/4.0/tasks/' || p_task_number;
            l_body := '{"action":{"id":"INFO_REQUEST"}'
                   || ',"identities":[{"id":"'
                   || apex_escape.json(p_assignee_id)
                   || '","type":"' || NVL(p_assignee_type, 'user') || '"}]';

            IF p_comment IS NOT NULL THEN
                l_body := l_body || ',"comment":{"commentStr":"'
                       || apex_escape.json(p_comment)
                       || '","commentScope":"TASK"}';
            END IF;

            l_body := l_body || '}';


        ELSIF UPPER(p_action) = 'INFO_SUBMIT' THEN
            -- 4.0 single-task endpoint; no identities needed — routes back to requester.
            -- Action ID confirmed from Oracle BPM API docs.
            l_url  := pkg_bicc_common.gc_fa_base_url
                   || '/bpm/api/4.0/tasks/' || p_task_number;

            l_body := '{"action":{"id":"INFO_SUBMIT"}';

            IF p_comment IS NOT NULL THEN
                l_body := l_body || ',"comment":{"commentStr":"'
                       || apex_escape.json(p_comment)
                       || '","commentScope":"TASK"}';
            END IF;

            l_body := l_body || '}';

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

        -- Clear stale headers so they don't leak into the OAuth token exchange
        apex_web_service.g_request_headers.DELETE;

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

        apex_web_service.g_request_headers.DELETE;

        l_response := apex_web_service.make_rest_request(
            p_url                  => l_url,
            p_http_method          => 'GET',
            p_credential_static_id => gc_user_credential
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
            p_credential_static_id => gc_user_credential
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

        apex_web_service.g_request_headers.DELETE;

        l_response := apex_web_service.make_rest_request(
            p_url                  => l_url,
            p_http_method          => 'GET',
            p_credential_static_id => gc_user_credential
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
            p_credential_static_id => gc_user_credential
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
    -- GET_HISTORY  --  Fetch approval history for a single task  (4.0 API)
    -- Returns raw JSON CLOB for the APEX page to parse and render.
    -- =========================================================================

    FUNCTION get_history(p_task_number IN NUMBER) RETURN CLOB IS
        l_url      VARCHAR2(1000);
        l_response CLOB;
    BEGIN
        l_url := pkg_bicc_common.gc_fa_base_url
              || '/bpm/api/4.0/tasks/' || p_task_number || '/history';

        apex_web_service.g_request_headers.DELETE;

        l_response := apex_web_service.make_rest_request(
            p_url                  => l_url,
            p_http_method          => 'GET',
            p_credential_static_id => gc_user_credential
        );

        RETURN l_response;
    END get_history;


    -- =========================================================================
    -- GET_NOTIFICATION_CONTENT  --  Rendered BIP notification HTML (HCM REST)
    -- Uses businessProcessNotifications endpoint with the task's GUID.
    -- Returns the full HTML that Fusion renders in the bell icon detail panel.
    -- =========================================================================

    FUNCTION get_notification_content(p_task_id IN VARCHAR2) RETURN CLOB IS
        l_url      VARCHAR2(1000);
        l_response CLOB;
    BEGIN
        l_url := pkg_bicc_common.gc_fa_base_url
              || '/hcmRestApi/resources/11.13.18.05/businessProcessNotifications/'
              || p_task_id || '/enclosure/content';

        apex_web_service.g_request_headers.DELETE;

        l_response := apex_web_service.make_rest_request(
            p_url                  => l_url,
            p_http_method          => 'GET',
            p_credential_static_id => gc_user_credential
        );

        RETURN l_response;
    END get_notification_content;


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
            p_credential_static_id => gc_user_credential
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


    -- =========================================================================
    -- GET_DEEPLINK_URL  --  Redwood deep link for editing the transaction
    -- POSTs to businessProcessNotifications/action/getDeeplinkUrlForEditAction
    -- with the task GUID.  Returns $.result.EDIT_INFO URL, or NULL if the
    -- task is not editable (EDIT != "true") or the call fails.
    -- =========================================================================

    FUNCTION get_deeplink_url(p_task_id IN VARCHAR2) RETURN VARCHAR2 IS
        l_url      VARCHAR2(1000);
        l_body     VARCHAR2(200);
        l_response CLOB;
        l_can_edit VARCHAR2(10);
    BEGIN
        l_url := pkg_bicc_common.gc_fa_base_url
              || '/hcmRestApi/resources/11.13.18.05/businessProcessNotifications'
              || '/action/getDeeplinkUrlForEditAction';

        l_body := '{"taskId":"' || apex_escape.json(p_task_id) || '"}';

        apex_web_service.g_request_headers.DELETE;
        apex_web_service.g_request_headers(1).name  := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/vnd.oracle.adf.action+json';
        apex_web_service.g_request_headers(2).name  := 'Accept';
        apex_web_service.g_request_headers(2).value := 'application/json';

        l_response := apex_web_service.make_rest_request(
            p_url                  => l_url,
            p_http_method          => 'POST',
            p_body                 => l_body,
            p_credential_static_id => gc_user_credential
        );

        l_can_edit := JSON_VALUE(l_response, '$.result.EDIT');

        IF l_can_edit = 'true' THEN
            RETURN JSON_VALUE(l_response, '$.result.EDIT_INFO');
        END IF;

        RETURN NULL;
    END get_deeplink_url;


END pkg_bpm_tasks;
/