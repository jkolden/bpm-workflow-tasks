prompt --application/set_environment
set define off verify off feedback off
whenever sqlerror exit sql.sqlcode rollback
--------------------------------------------------------------------------------
--
-- Oracle APEX export file
--
-- You should run this script using a SQL client connected to the database as
-- the owner (parsing schema) of the application or as a database user with the
-- APEX_ADMINISTRATOR_ROLE role.
--
-- This export file has been automatically generated. Modifying this file is not
-- supported by Oracle and can lead to unexpected application and/or instance
-- behavior now or in the future.
--
-- NOTE: Calls to apex_application_install override the defaults below.
--
--------------------------------------------------------------------------------
begin
wwv_flow_imp.import_begin (
 p_version_yyyy_mm_dd=>'2024.11.30'
,p_release=>'24.2.17'
,p_default_workspace_id=>8325564762610682
,p_default_application_id=>147
,p_default_id_offset=>167253079984364169
,p_default_owner=>'WKSP_FREEDEMO'
);
end;
/
 
prompt APPLICATION 147 - Task Notification Application
--
-- Application Export:
--   Application:     147
--   Name:            Task Notification Application
--   Exported By:     JOHN.KOLDEN@SIERRA-CEDAR.COM
--   Flashback:       0
--   Export Type:     Page Export
--   Manifest
--     PAGE: 6003
--   Manifest End
--   Version:         24.2.17
--   Instance ID:     8325348246048613
--

begin
null;
end;
/
prompt --application/pages/delete_06003
begin
wwv_flow_imp_page.remove_page (p_flow_id=>wwv_flow.g_flow_id, p_page_id=>6003);
end;
/
prompt --application/pages/page_06003
begin
wwv_flow_imp_page.create_page(
 p_id=>6003
,p_name=>'Task Actions'
,p_alias=>'ACTIONS'
,p_page_mode=>'MODAL'
,p_step_title=>'Task &P6003_TASK_NUMBER. Actions'
,p_warn_on_unsaved_changes=>'N'
,p_autocomplete_on_off=>'OFF'
,p_javascript_code_onload=>wwv_flow_string.join(wwv_flow_t_varchar2(
'(function () {',
'    var taskNum = $v(''P6003_TASK_NUMBER'');',
'    if (!taskNum) return;',
'',
'    // Whitelist: only actions we have tested and built payloads for.',
'    // Intersected with the API actionList so only valid-for-state options appear.',
'    var supported = {',
'        ''ACQUIRE''                : ''Claim'',',
'        ''APPROVE''                : ''Approve'',',
'        ''COMPLETE''               : ''Complete'',',
'        ''DELEGATE''               : ''Delegate'',',
'        ''ESCALATE''               : ''Escalate'',',
'        ''INFO_REQUEST''           : ''Request Information'',',
'        ''INFO_SUBMIT''            : ''Submit Information'',',
'        ''PUSHBACK''               : ''Pushback'',',
'        ''REASSIGN''               : ''Reassign'',',
'        ''REJECT''                 : ''Reject'',',
'        ''RELEASE''                : ''Release'',',
'        ''RESUME''                 : ''Resume'',',
'        ''SKIP_CURRENT_ASSIGNMENT'': ''Skip Current Assignment'',',
'        ''SUSPEND''                : ''Suspend'',',
'        ''WITHDRAW''               : ''Withdraw''',
'    };',
'',
'    // Show/hide the assignee field based on action selection.',
'    // Auto-populate with the task submitter''s Fusion user ID (P6003_FROM_USER_NAME)',
unistr('    // when INFO_REQUEST is chosen \2014 user can override if needed.'),
'    apex.item(''P6003_ACTION'').node.addEventListener(''change'', function () {',
'        var needsAssignee = {''INFO_REQUEST'':1,''DELEGATE'':1,''REASSIGN'':1}.hasOwnProperty(this.value);',
'        $(''#P6003_ASSIGNEE'').closest(''.t-Form-fieldContainer'')',
'            .toggle(needsAssignee);',
'        if (needsAssignee) {',
'            // Pre-fill with submitter''s user ID; only override if currently empty',
'            if (!$v(''P6003_ASSIGNEE'').trim()) {',
'                $s(''P6003_ASSIGNEE'', $v(''P6003_FROM_USER_NAME'') || '''');',
'            }',
'        } else {',
'            $s(''P6003_ASSIGNEE'', '''');',
'        }',
'    });',
'    // Start hidden',
'    $(''#P6003_ASSIGNEE'').closest(''.t-Form-fieldContainer'').hide();',
'',
'    // Clear immediately so static LOV options don''t flash before Ajax returns.',
'    // Keep one disabled placeholder so the floating label renders correctly while loading.',
'    var sel = apex.item(''P6003_ACTION'').node;',
'    sel.innerHTML = ''<option value="" disabled selected>Select an Action\u2026</option>'';',
'',
'    apex.server.process(''GET_TASK_ACTIONS'', { x01: taskNum }, {',
'        success: function (data) {',
'            if (data.status !== ''OK'' || !data.actions || !data.actions.length) return;',
'',
'            // Pin ACQUIRE (Claim) first with a visual separator below it',
'            if (data.actions.indexOf(''ACQUIRE'') !== -1) {',
'                var claim = document.createElement(''option'');',
'                claim.value = ''ACQUIRE'';',
'                claim.text  = ''Claim'';',
'                sel.appendChild(claim);',
'',
'                var sep = document.createElement(''option'');',
'                sep.value    = '''';',
'                sep.text     = ''\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500'';',
'                sep.disabled = true;',
'                sel.appendChild(sep);',
'            }',
'',
'            // Remaining: intersection of API list and our whitelist, sorted alphabetically',
'            data.actions',
'                .filter(function (a) { return a !== ''ACQUIRE'' && supported.hasOwnProperty(a); })',
'                .sort()',
'                .forEach(function (a) {',
'                    var o = document.createElement(''option'');',
'                    o.value = a;',
'                    o.text  = supported[a];',
'                    sel.appendChild(o);',
'                });',
'        }',
'    });',
'',
'    $(document).on(''click'', ''#P6003_SUBMIT'', function () {',
'        var action     = $v(''P6003_ACTION'');',
'        var comment    = $v(''P6003_COMMENT'') || '''';',
'        var assigneeId = $v(''P6003_ASSIGNEE'') || '''';',
'        if (!action) { apex.message.showErrors([{ type: ''error'', location: ''page'',',
'            message: ''Please select an action.'' }]); return; }',
'        if ({''INFO_REQUEST'':1,''DELEGATE'':1,''REASSIGN'':1}.hasOwnProperty(action) && !assigneeId.trim()) {',
'            apex.message.showErrors([{ type: ''error'', location: ''page'',',
'                message: ''Please enter the Fusion user ID.'' }]);',
'            return;',
'        }',
'',
'        apex.server.process(''ACTION_TASK'',',
'            { x01: taskNum, x02: action, x03: comment, x04: assigneeId },',
'            {',
'                success: function (data) {',
'                    if (data.status === ''OK'') {',
'                        apex.navigation.dialog.cancel(true);',
'                    } else {',
'                        apex.message.showErrors([{ type: ''error'', location: ''page'',',
'                            message: data.message || ''Action failed.'' }]);',
'                    }',
'                }',
'            }',
'        );',
'    });',
'}());'))
,p_inline_css=>wwv_flow_string.join(wwv_flow_t_varchar2(
'#P6003_ERROR_MSG{',
'    display: none;',
'    color: #c0392b;',
'    font-weight: bold;',
'    margin-top: 8px;',
'    padding: 8px 12px;',
'    border: 1px solid #c0392b;',
'    border-radius: 4px;',
'    background-color: #fdecea;',
'}',
''))
,p_step_template=>1661186590416509825
,p_page_template_options=>'#DEFAULT#:js-dialog-class-t-Drawer--pullOutEnd'
,p_dialog_resizable=>'Y'
,p_protection_level=>'C'
,p_page_component_map=>'16'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(326245409477345316)
,p_plug_name=>'items'
,p_region_template_options=>'#DEFAULT#:t-Region--removeHeader js-removeLandmark:t-Region--scrollBody'
,p_plug_template=>4072358936313175081
,p_plug_display_sequence=>20
,p_location=>null
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'expand_shortcuts', 'N',
  'output_as', 'HTML')).to_clob
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(330468540562641995)
,p_plug_name=>'err'
,p_region_template_options=>'#DEFAULT#:margin-top-md:margin-bottom-md'
,p_plug_template=>4501440665235496320
,p_plug_display_sequence=>10
,p_location=>null
,p_plug_source=>'<span id="P6003_ERROR_MSG"></span>'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'expand_shortcuts', 'N',
  'output_as', 'HTML')).to_clob
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(330466049307641970)
,p_button_sequence=>60
,p_button_plug_id=>wwv_flow_imp.id(326245409477345316)
,p_button_name=>'Submit'
,p_button_static_id=>'P6003_SUBMIT'
,p_button_action=>'DEFINED_BY_DA'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4072362960822175091
,p_button_image_alt=>'Submit'
,p_warn_on_unsaved_changes=>null
,p_grid_new_row=>'Y'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(326245512108345317)
,p_name=>'P6003_TASK_NUMBER'
,p_item_sequence=>10
,p_item_plug_id=>wwv_flow_imp.id(326245409477345316)
,p_display_as=>'NATIVE_HIDDEN'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(326245667215345318)
,p_name=>'P6003_TITLE'
,p_item_sequence=>20
,p_item_plug_id=>wwv_flow_imp.id(326245409477345316)
,p_prompt=>'Title'
,p_source=>'SELECT title FROM bpm_workflow_tasks WHERE task_number = :P6003_TASK_NUMBER'
,p_source_type=>'QUERY'
,p_display_as=>'NATIVE_DISPLAY_ONLY'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'based_on', 'VALUE',
  'format', 'PLAIN',
  'send_on_page_submit', 'Y',
  'show_line_breaks', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(326245751771345319)
,p_name=>'P6003_ACTION'
,p_item_sequence=>30
,p_item_plug_id=>wwv_flow_imp.id(326245409477345316)
,p_prompt=>'Action'
,p_display_as=>'NATIVE_SELECT_LIST'
,p_lov=>'STATIC2:CLAIM;ACQUIRE,APPROVE;APPROVE,COMPLETE;COMPLETE,DELEGATE;DELEGATE,PUSHBACK;PUSHBACK,REASSIGN;REASSIGN,REJECT;REJECT'
,p_cHeight=>1
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_lov_display_extra=>'NO'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'page_action_on_selection', 'NONE')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(330466329294641973)
,p_name=>'P6003_COMMENT'
,p_item_sequence=>50
,p_item_plug_id=>wwv_flow_imp.id(326245409477345316)
,p_prompt=>'Comment'
,p_display_as=>'NATIVE_TEXTAREA'
,p_cSize=>30
,p_cHeight=>5
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'auto_height', 'N',
  'character_counter', 'N',
  'resizable', 'Y',
  'trim_spaces', 'BOTH')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(330467427163641984)
,p_name=>'P6003_ASSIGNEE'
,p_item_sequence=>40
,p_item_plug_id=>wwv_flow_imp.id(326245409477345316)
,p_prompt=>'Assignee'
,p_display_as=>'NATIVE_POPUP_LOV'
,p_lov=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT user_first_name||'' ''||user_last_name || '' ('' || username || '')'' AS d,',
'       username AS r',
'  FROM fa_user_accounts',
' WHERE active_flag = ''Y''',
' ORDER BY user_last_name',
''))
,p_cSize=>30
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_lov_display_extra=>'YES'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'case_sensitive', 'N',
  'display_as', 'POPUP',
  'fetch_on_search', 'N',
  'initial_fetch', 'FIRST_ROWSET',
  'manual_entry', 'N',
  'match_type', 'CONTAINS',
  'min_chars', '0')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(331233204517511014)
,p_name=>'P6003_FROM_USER_NAME'
,p_item_sequence=>70
,p_item_plug_id=>wwv_flow_imp.id(326245409477345316)
,p_display_as=>'NATIVE_HIDDEN'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(330467970700641989)
,p_name=>'js'
,p_event_sequence=>20
,p_triggering_element_type=>'BUTTON'
,p_triggering_button_id=>wwv_flow_imp.id(330466049307641970)
,p_bind_type=>'live'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'click'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(330468049949641990)
,p_event_id=>wwv_flow_imp.id(330467970700641989)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'N'
,p_action=>'NATIVE_JAVASCRIPT_CODE'
,p_attribute_01=>wwv_flow_string.join(wwv_flow_t_varchar2(
'apex.server.process("ACTION_TASK", {',
'    pageItems: "#P6003_TASK_NUMBER,#P6003_ACTION,#P6003_COMMENT,#P6003_ASSIGNEE"',
'}, {',
'    success: function(data) {',
'        if (data.status === "OK") {',
'            apex.event.trigger(document, "apexclosealilog");',
'            apex.navigation.dialog.close(true);',
'        } else {',
'            $("#P6003_ERROR_MSG").text(data.message).show();',
'        }',
'    },',
'    error: function(jqXHR, textStatus, errorThrown) {',
'        $("#P6003_ERROR_MSG").text("Request failed: " + errorThrown).show();',
'    },',
'    dataType: "json"',
'});',
''))
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(330467862823641988)
,p_process_sequence=>10
,p_process_point=>'ON_DEMAND'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'ACTION_TASK'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    l_task_number NUMBER         := TO_NUMBER(apex_application.g_x01);',
'    l_action      VARCHAR2(50)   := apex_application.g_x02;',
'    l_comment     VARCHAR2(4000) := SUBSTRB(apex_application.g_x03, 1, 4000);',
'    l_assignee_id VARCHAR2(255)  := SUBSTRB(apex_application.g_x04, 1, 255);',
'BEGIN',
'    pkg_bpm_tasks.action_task(',
'        p_task_number => l_task_number,',
'        p_action      => l_action,',
'        p_comment     => l_comment,',
'        p_assignee_id => l_assignee_id',
'    );',
'',
'    BEGIN',
'        pkg_bpm_tasks.refresh_tasks;',
'    EXCEPTION',
'        WHEN OTHERS THEN NULL;  -- Don''t let refresh failure block the success',
'    END;',
'',
'    apex_json.open_object;',
'    apex_json.write(''status'', ''OK'');',
'    apex_json.close_object;',
'',
'EXCEPTION',
'    WHEN OTHERS THEN',
'        apex_json.open_object;',
'        apex_json.write(''status'', ''ERROR'');',
'        apex_json.write(''message'', SQLERRM);',
'        apex_json.close_object;',
'END;',
''))
,p_process_clob_language=>'PLSQL'
,p_internal_uid=>163214782839277819
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(331232504614511007)
,p_process_sequence=>20
,p_process_point=>'ON_DEMAND'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'GET_TASK_ACTIONS'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    l_task_number NUMBER := TO_NUMBER(apex_application.g_x01);',
'    l_response    CLOB;',
'BEGIN',
'    l_response := pkg_bpm_tasks.get_task_actions(l_task_number);',
'',
'    -- Clear any stale HTP buffer from OAuth token exchange',
'    htp.init;',
'',
'    apex_json.open_object;',
'    apex_json.write(''status'', ''OK'');',
'    apex_json.open_array(''actions'');',
'    FOR r IN (',
'        SELECT j.action_id',
'          FROM JSON_TABLE(l_response, ''$.actionList[*]'' COLUMNS (',
'              action_id VARCHAR2(100) PATH ''$.actionId''',
'          )) j',
'    ) LOOP',
'        apex_json.write(r.action_id);',
'    END LOOP;',
'    apex_json.close_array;',
'    apex_json.close_object;',
'',
'EXCEPTION',
'    WHEN OTHERS THEN',
'        htp.init;',
'        apex_json.open_object;',
'        apex_json.write(''status'', ''ERROR'');',
'        apex_json.write(''message'', SQLERRM);',
'        apex_json.close_object;',
'END;'))
,p_process_clob_language=>'PLSQL'
,p_internal_uid=>163979424630146838
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(330466425429641974)
,p_process_sequence=>10
,p_process_point=>'ON_SUBMIT_BEFORE_COMPUTATION'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'submit'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'BEGIN',
'    pkg_bpm_tasks.action_task(',
'        p_task_number => :P6003_TASK_NUMBER,',
'        p_action      => :P6003_ACTION,',
'        p_comment     => :P6003_COMMENT,',
'        p_assignee_id => :P6003_ASSIGNEE',
'    );',
'END;',
'',
''))
,p_process_clob_language=>'PLSQL'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_process_success_message=>'&P6004_ACTION. completed for task &P6004_TASK_NUMBER.'
,p_internal_uid=>163213345445277805
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(330466564987641975)
,p_process_sequence=>20
,p_process_point=>'ON_SUBMIT_BEFORE_COMPUTATION'
,p_process_type=>'NATIVE_CLOSE_WINDOW'
,p_process_name=>'Close Dialog'
,p_attribute_02=>'Y'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_internal_uid=>163213485003277806
);
end;
/
prompt --application/end_environment
begin
wwv_flow_imp.import_end(p_auto_install_sup_obj => nvl(wwv_flow_application_install.get_auto_install_sup_obj, false)
);
commit;
end;
/
set verify on feedback on define on
prompt  ...done
