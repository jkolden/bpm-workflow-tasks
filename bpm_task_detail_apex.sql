-- =============================================================================
-- BPM TASK DETAIL PANEL — APEX Setup Instructions
-- =============================================================================
-- Adds inline expand/collapse panel with Comments + Attachments sections
-- to page 6004 (Task List Faceted). Comments and attachments are fetched
-- from / posted to the Oracle BPM 3.0 REST API via pkg_bpm_tasks.
-- Uses "btask-" CSS prefix.
-- =============================================================================

-- =============================================================================
-- STEP 1: Compile updated package
-- =============================================================================
-- Run pkg_bpm_tasks.sql (spec) then pkg_bpm_tasks.plb (body) in APEX SQL
-- Commands. Adds get_attachments() and add_attachment() to the package.

-- =============================================================================
-- STEP 2: Upload CSS + JS files
-- =============================================================================
-- Upload bpm_task_detail_js.js and bpm_task_detail_css.css to
-- Shared Components > Static Application Files, then reference on page 6004:
--   CSS File URL:  #APP_FILES#bpm_task_detail_css#MIN#.css
--   JS  File URL:  #APP_FILES#bpm_task_detail_js#MIN#.js

-- =============================================================================
-- STEP 3: Modify report SQL — add toggle column
-- =============================================================================
-- Replace the Search Results report SQL with:

/*
SELECT '<button type="button" class="btask-toggle"
               data-task-number="' || task_number || '"
               aria-label="Task Details">
         <span class="fa fa-folder-o"></span>
       </button>' AS detail_toggle,
       '<button type="button" class="btask-history-toggle"
               data-task-number="' || task_number || '"
               aria-label="Approval History">
         <span class="fa fa-clock-o"></span>
       </button>' AS history_toggle,
       task_number,
       title,
       INITCAP(REPLACE(
           REGEXP_REPLACE(task_def_name, '([a-z])([A-Z])', '\1 \2'),
           'Approval', '')) AS task_type,
       category,
       assignee_id,
       assignee_type,
       created_by,
       from_user_display   AS submitted_by,
       assigned_ts,
       ROUND(SYSDATE - CAST(assigned_ts AS DATE)) AS days_pending,
       priority,
       state,
       identification_key,
       last_action,
       last_action_ts,
       last_action_status,
       last_action_response
  FROM bpm_workflow_tasks
*/

-- =============================================================================
-- STEP 4: Configure the DETAIL_TOGGLE column
-- =============================================================================
-- Column Alias:              DETAIL_TOGGLE
-- Heading:                   (leave blank, or set to a small icon heading)
-- Column Type:               Plain Text
-- Escape Special Characters: No  (CRITICAL — so HTML renders)
-- Column Alignment:          Center
-- Width:                     48

-- Configure the HISTORY_TOGGLE column the same way:
-- Column Alias:              HISTORY_TOGGLE
-- Heading:                   (leave blank)
-- Column Type:               Plain Text
-- Escape Special Characters: No
-- Column Alignment:          Center
-- Width:                     48

-- =============================================================================
-- STEP 5: Ajax Callbacks — create five processes on page 6004
-- =============================================================================
-- Process Point: Ajax Callback  |  Type: PL/SQL Code

-- ---- GET_TASK_COMMENTS ----
-- Name: GET_TASK_COMMENTS

/*
DECLARE
    l_task_number NUMBER := TO_NUMBER(apex_application.g_x01);
    l_raw_json    CLOB;
BEGIN
    l_raw_json := pkg_bpm_tasks.get_comments(l_task_number);

    apex_json.open_object;
    apex_json.write('status', 'OK');
    apex_json.open_array('comments');

    FOR r IN (
        SELECT j.comment_str, j.updated_by, j.updated_date, j.user_id
          FROM JSON_TABLE(l_raw_json, '$.items[*]' COLUMNS (
              comment_str  VARCHAR2(4000) PATH '$.commentStr',
              updated_by   VARCHAR2(200)  PATH '$.updatedBy',
              updated_date VARCHAR2(50)   PATH '$.updateddDate',
              user_id      VARCHAR2(200)  PATH '$.userId'
          )) j
    ) LOOP
        apex_json.open_object;
        apex_json.write('commentStr',  r.comment_str);
        apex_json.write('updatedBy',   r.updated_by);
        apex_json.write('updatedDate', r.updated_date);
        apex_json.write('userId',      r.user_id);
        apex_json.close_object;
    END LOOP;

    apex_json.close_array;
    apex_json.close_object;

EXCEPTION
    WHEN OTHERS THEN
        apex_json.open_object;
        apex_json.write('status', 'ERROR');
        apex_json.write('message', SQLERRM);
        apex_json.close_object;
END;
*/


-- ---- GET_TASK_ATTACHMENTS ----
-- Name: GET_TASK_ATTACHMENTS

/*
DECLARE
    l_task_number NUMBER := TO_NUMBER(apex_application.g_x01);
    l_raw_json    CLOB;
BEGIN
    l_raw_json := pkg_bpm_tasks.get_attachments(l_task_number);

    apex_json.open_object;
    apex_json.write('status', 'OK');
    apex_json.open_array('attachments');

    FOR r IN (
        SELECT j.attachment_name, j.mime_type, j.attachment_size,
               j.updated_by, j.updated_date
          FROM JSON_TABLE(l_raw_json, '$.items[*]' COLUMNS (
              attachment_name VARCHAR2(500) PATH '$.attachmentName',
              mime_type       VARCHAR2(200) PATH '$.mimeType',
              attachment_size NUMBER        PATH '$.attachmentSize',
              updated_by      VARCHAR2(200) PATH '$.updatedBy',
              updated_date    VARCHAR2(50)  PATH '$.updatedDate'
          )) j
    ) LOOP
        apex_json.open_object;
        apex_json.write('attachmentName', r.attachment_name);
        apex_json.write('mimeType',       r.mime_type);
        apex_json.write('attachmentSize', r.attachment_size);
        apex_json.write('updatedBy',      r.updated_by);
        apex_json.write('updatedDate',    r.updated_date);
        apex_json.close_object;
    END LOOP;

    apex_json.close_array;
    apex_json.close_object;

EXCEPTION
    WHEN OTHERS THEN
        apex_json.open_object;
        apex_json.write('status', 'ERROR');
        apex_json.write('message', SQLERRM);
        apex_json.close_object;
END;
*/


-- ---- ADD_TASK_COMMENT ----
-- Name: ADD_TASK_COMMENT

/*
DECLARE
    l_task_number NUMBER        := TO_NUMBER(apex_application.g_x01);
    l_comment     VARCHAR2(4000) := SUBSTRB(apex_application.g_x02, 1, 4000);
BEGIN
    pkg_bpm_tasks.add_comment(l_task_number, l_comment);

    apex_json.open_object;
    apex_json.write('status', 'OK');
    apex_json.close_object;

EXCEPTION
    WHEN OTHERS THEN
        apex_json.open_object;
        apex_json.write('status', 'ERROR');
        apex_json.write('message', SQLERRM);
        apex_json.close_object;
END;
*/


-- ---- ADD_TASK_ATTACHMENT ----
-- Name: ADD_TASK_ATTACHMENT

/*
DECLARE
    l_task_number  NUMBER        := TO_NUMBER(apex_application.g_x01);
    l_file_name    VARCHAR2(500) := apex_application.g_x02;
    l_content_type VARCHAR2(200) := apex_application.g_x03;
    l_b64          CLOB;
BEGIN
    -- Reassemble base64 CLOB from f01 array chunks
    FOR i IN 1 .. apex_application.g_f01.COUNT LOOP
        l_b64 := l_b64 || apex_application.g_f01(i);
    END LOOP;

    IF l_b64 IS NULL OR LENGTH(l_b64) = 0 THEN
        raise_application_error(-20010, 'No file data received.');
    END IF;

    pkg_bpm_tasks.add_attachment(
        p_task_number  => l_task_number,
        p_file_name    => l_file_name,
        p_content_type => l_content_type,
        p_file_b64     => l_b64
    );

    apex_json.open_object;
    apex_json.write('status', 'OK');
    apex_json.close_object;

EXCEPTION
    WHEN OTHERS THEN
        apex_json.open_object;
        apex_json.write('status', 'ERROR');
        apex_json.write('message', SQLERRM);
        apex_json.close_object;
END;
*/


-- ---- DOWNLOAD_TASK_ATTACHMENT ----
-- Name: DOWNLOAD_TASK_ATTACHMENT
-- Fetches attachment bytes from BPM stream endpoint, returns as base64 JSON.

/*
DECLARE
    l_task_number  NUMBER        := TO_NUMBER(apex_application.g_x01);
    l_attach_name  VARCHAR2(500) := apex_application.g_x02;
    l_mime_type    VARCHAR2(200) := NVL(apex_application.g_x03, 'application/octet-stream');
    l_url          VARCHAR2(2000);
    l_blob         BLOB;
    l_b64          CLOB;
BEGIN
    l_url := pkg_bicc_common.gc_fa_base_url
          || '/bpm/api/4.0/tasks/' || l_task_number
          || '/attachments/' || utl_url.escape(l_attach_name, FALSE, 'UTF-8')
          || '/stream';

    l_blob := apex_web_service.make_rest_request_b(
        p_url                  => l_url,
        p_http_method          => 'GET',
        p_credential_static_id => pkg_bpm_tasks.gc_credential
    );

    l_b64 := apex_web_service.blob2clobbase64(l_blob);

    apex_json.open_object;
    apex_json.write('status', 'OK');
    apex_json.write('fileName', l_attach_name);
    apex_json.write('mimeType', l_mime_type);
    apex_json.write('data', l_b64);
    apex_json.close_object;

EXCEPTION
    WHEN OTHERS THEN
        apex_json.open_object;
        apex_json.write('status', 'ERROR');
        apex_json.write('message', SQLERRM);
        apex_json.close_object;
END;
*/


-- ---- GET_TASK_HISTORY ----
-- Name: GET_TASK_HISTORY

/*
DECLARE
    l_task_number NUMBER := TO_NUMBER(apex_application.g_x01);
    l_raw_json    CLOB;
BEGIN
    l_raw_json := pkg_bpm_tasks.get_history(l_task_number);

    apex_json.open_object;
    apex_json.write('status', 'OK');
    apex_json.open_array('history');

    FOR r IN (
        SELECT j.action_name, j.display_name, j.user_id,
               j.state, j.reason, j.pattern, j.updated_date
          FROM JSON_TABLE(l_raw_json, '$.items[*]' COLUMNS (
              action_name  VARCHAR2(200) PATH '$.actionName',
              display_name VARCHAR2(200) PATH '$.displayName',
              user_id      VARCHAR2(200) PATH '$.userId',
              state        VARCHAR2(100) PATH '$.state',
              reason       VARCHAR2(200) PATH '$.reason',
              pattern      VARCHAR2(100) PATH '$.pattern',
              updated_date VARCHAR2(50)  PATH '$.updatedDate'
          )) j
    ) LOOP
        apex_json.open_object;
        apex_json.write('actionName',  r.action_name);
        apex_json.write('displayName', r.display_name);
        apex_json.write('userId',      r.user_id);
        apex_json.write('state',       r.state);
        apex_json.write('reason',      r.reason);
        apex_json.write('pattern',     r.pattern);
        apex_json.write('updatedDate', r.updated_date);
        apex_json.close_object;
    END LOOP;

    apex_json.close_array;
    apex_json.close_object;

EXCEPTION
    WHEN OTHERS THEN
        apex_json.open_object;
        apex_json.write('status', 'ERROR');
        apex_json.write('message', SQLERRM);
        apex_json.close_object;
END;
*/


-- =============================================================================
-- STEP 6: New Todo — drawer form page (e.g. page 6104)
-- =============================================================================
-- Create a Drawer page with these items:
--   P6104_TITLE        - Text Field (required)
--   P6104_ASSIGNEE     - Select List, LOV query:
--                          SELECT user_first_name||' '||user_last_name
--                                 || ' (' || username || ')' AS d,
--                                 username AS r
--                            FROM fa_user_accounts
--                           WHERE active_flag = 'Y'
--                           ORDER BY user_last_name
--   P6104_PRIORITY     - Select List, static LOV:
--                          3;Normal, 1;Highest, 2;High, 4;Low, 5;Lowest
--                          Default: 3
--   P6104_START_DATE   - Date Picker (format: YYYY-MM-DD HH24:MI:SS)
--   P6104_DUE_DATE     - Date Picker (format: YYYY-MM-DD HH24:MI:SS)
--
-- Page process (After Submit, when CREATE button pressed):

-- ---- CREATE_TODO_TASK ----
-- Name: CREATE_TODO_TASK

/*
BEGIN
    pkg_bpm_tasks.create_todo_task(
        p_title       => :P6104_TITLE,
        p_assignee_id => :P6104_ASSIGNEE,
        p_priority    => NVL(TO_NUMBER(:P6104_PRIORITY), 3),
        p_start_date  => CASE WHEN :P6104_START_DATE IS NOT NULL
                              THEN :P6104_START_DATE || ' 00:00:00' END,
        p_due_date    => CASE WHEN :P6104_DUE_DATE IS NOT NULL
                              THEN :P6104_DUE_DATE || ' 23:59:59' END
    );

EXCEPTION
    WHEN OTHERS THEN
        apex_error.add_error(
            p_message          => SQLERRM,
            p_display_location => apex_error.c_inline_in_notification
        );
END;
*/

-- On page 6004, add a button (e.g. "New Todo") that opens the drawer:
--   Action:  Redirect to Page
--   Target:  Page 6104
--   (APEX will render it as a drawer/dialog automatically if page mode = Drawer)
--
-- After the drawer closes (Dialog Closed dynamic action on page 6004),
-- optionally refresh the task report.


-- =============================================================================
-- NOTES
-- =============================================================================
-- BPM API JSON shapes (4.0, { items: [...], hasMore, links } wrapper):
--   Comments:    { items: [{ commentStr, updatedBy, updateddDate, userId, commentScope }] }
--                Note the double "d" in updateddDate — this is the BPM API.
--   Attachments: { items: [{ attachmentName, mimeType, attachmentSize,
--                            updatedBy, updatedDate, uri: {href, rel:"stream"} }] }
--
-- Credential: Uses gc_credential = 'gcs_reports' (APEX Web Credential).
-- If multipart/mixed POST fails with the credential (APEX header bleed-through
-- issue seen with pkg_rec_move), fall back to inline p_username/p_password
-- in pkg_bpm_tasks.add_attachment.
--
-- Download: DOWNLOAD_TASK_ATTACHMENT fetches /stream as BLOB, returns base64
-- via apex_json. JS decodes to Blob and triggers browser download.
