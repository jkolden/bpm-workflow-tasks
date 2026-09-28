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
--     PAGE: 6204
--   Manifest End
--   Version:         24.2.17
--   Instance ID:     8325348246048613
--

begin
null;
end;
/
prompt --application/pages/delete_06204
begin
wwv_flow_imp_page.remove_page (p_flow_id=>wwv_flow.g_flow_id, p_page_id=>6204);
end;
/
prompt --application/pages/page_06204
begin
wwv_flow_imp_page.create_page(
 p_id=>6204
,p_name=>'Task List'
,p_alias=>'TASK-LIST-FACETED1'
,p_step_title=>'Task List'
,p_autocomplete_on_off=>'OFF'
,p_javascript_file_urls=>wwv_flow_string.join(wwv_flow_t_varchar2(
'#APP_FILES#bpm_task_detail_js.js',
''))
,p_javascript_code=>wwv_flow_string.join(wwv_flow_t_varchar2(
'function refreshTasks() {',
'',
'    var icon = $("#REFRESH_TASKS .t-Icon--left");',
'    icon.addClass("fa-anim-spin");',
'',
'    apex.server.process("REFRESH_TASKS", {}, {',
'',
'        dataType: "json",',
'',
'        success: function (data) {',
'',
'            try {',
'',
'                if (data.status === "OK") {',
'                    apex.region("bpm_tasks_ir").refresh();',
'                } else {',
'                    apex.message.alert(data.message);',
'                }',
'',
'            } finally {',
'',
'                icon.removeClass("fa-anim-spin");',
'',
'            }',
'',
'        },',
'',
'        error: function (jqXHR, textStatus, errorThrown) {',
'',
'            icon.removeClass("fa-anim-spin");',
'',
'            console.error("Refresh failed:", textStatus, errorThrown);',
'            apex.message.alert("Refresh failed.");',
'',
'        }',
'',
'    });',
'',
'}',
''))
,p_css_file_urls=>'#APP_FILES#bpm_task_detail_css#MIN#.css'
,p_step_template=>2526643373347724467
,p_page_css_classes=>'inbasket-redwood'
,p_page_template_options=>'#DEFAULT#'
,p_protection_level=>'C'
,p_page_component_map=>'13'
);
wwv_flow_imp_page.create_report_region(
 p_id=>wwv_flow_imp.id(497757278301198488)
,p_name=>'Search Results'
,p_region_name=>'bpm_tasks_ir'
,p_template=>4072358936313175081
,p_display_sequence=>50
,p_region_template_options=>'#DEFAULT#:t-Region--noPadding:t-Region--hideHeader js-addHiddenHeadingRoleDesc:t-Region--scrollBody'
,p_component_template_options=>'#DEFAULT#:t-Report--stretch:t-Report--staticRowColors:t-Report--rowHighlight:t-Report--inline:t-Report--hideNoPagination'
,p_source_type=>'NATIVE_SQL_REPORT'
,p_query_type=>'SQL'
,p_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT ''<button type="button" class="btask-toggle"',
'               data-task-number="'' || task_number || ''"',
'               data-task-state="'' || state || ''"',
'               aria-label="Task Details">',
'         <span class="fa fa-folder-o"></span>',
'       </button>'' AS detail_toggle,',
'       ''<button type="button" class="btask-history-toggle"',
'               data-task-number="'' || task_number || ''"',
'               aria-label="Approval History">',
'         <span class="fa fa-clock-o"></span>',
'       </button>'' AS history_toggle,',
'CASE WHEN task_id IS NOT NULL THEN',
'           ''<a href="javascript:void(0)" class="bpm-fusion-link"''',
'           || '' data-task-id="'' || task_id || ''"''',
'           || '' title="View in Fusion">''',
'           || ''<span class="fa fa-external-link"></span></a>''',
'       END AS fusion_link,',
' CASE',
'    WHEN last_action IS NULL THEN NULL',
'    ELSE ''<span class="btask-la btask-la-'' || LOWER(NVL(last_action_status, ''ok'')) || ''"''',
'      || '' title="'' || TO_CHAR(last_action_ts, ''MM/DD/YY HH24:MI'')',
'      || CASE WHEN last_action_response IS NOT NULL',
'              THEN ''&#10;'' || last_action_response END',
'      || ''">''',
'      || INITCAP(REPLACE(last_action, ''_'', '' ''))',
'      || ''</span>''',
'END AS last_action_html,',
'',
'       task_number,',
'       TO_CHAR(task_number) AS task_number_vc,',
'       title,',
'       INITCAP(REPLACE(',
'           REGEXP_REPLACE(task_def_name, ''([a-z])([A-Z])'', ''\1 \2''),',
'           ''Approval'', '''')) AS task_type,',
'       category,',
'       assignee_id,',
'       assignee_type,',
'       created_by,',
'       from_user_display   AS submitted_by,',
'       assigned_ts,',
'       ROUND(SYSDATE - CAST(assigned_ts AS DATE)) AS days_pending,',
'       priority,',
'       state,',
'       identification_key,',
'       last_action,',
'       last_action_ts,',
'       last_action_status,',
'       last_action_response,',
'       from_user_name,',
'       APEX_UTIL.PREPARE_URL(',
'    ''f?p='' || :APP_ID || '':6003:'' || :APP_SESSION ||',
'    ''::NO:6003:P6003_TASK_NUMBER,P6003_FROM_USER_NAME:'' ||',
'    task_number || '','' || from_user_name',
') AS actions_url,',
'',
'''<span class="task-state task-state--''',
'|| REPLACE(state,'' '',''_'')',
'|| ''">''',
'|| INITCAP(REPLACE(state,''_'','' ''))',
'|| ''</span>'' AS state_html,',
'CASE',
'    WHEN ROUND(SYSDATE - CAST(assigned_ts AS DATE)) < 14 THEN ''fresh''',
'    WHEN ROUND(SYSDATE - CAST(assigned_ts AS DATE)) < 30 THEN ''warning''',
'    WHEN ROUND(SYSDATE - CAST(assigned_ts AS DATE)) < 90 THEN ''old''',
'    ELSE ''stale''',
'END AS age_class,',
'CASE',
'    WHEN from_user_display IS NULL THEN ''is-hidden''',
'END AS submitted_class,',
'',
'CASE',
'    WHEN assignee_id IS NULL THEN ''is-hidden''',
'END AS assignee_class,',
'',
'CASE',
'    WHEN from_user_display IS NULL',
'      OR assignee_id IS NULL',
'    THEN ''is-hidden''',
'END AS people_separator_class,',
'CASE',
'    WHEN from_user_display IS NULL',
'     AND assignee_id IS NULL',
'    THEN ''is-hidden''',
'END AS age_separator_class,',
'CASE',
'    WHEN NULLIF(',
'        TRIM(',
'            INITCAP(',
'                REPLACE(',
'                    REGEXP_REPLACE(',
'                        task_def_name,',
'                        ''([a-z])([A-Z])'',',
'                        ''\1 \2''',
'                    ),',
'                    ''Approval'',',
'                    ''''',
'                )',
'            )',
'        ),',
'        ''''',
'    ) IS NULL',
'    THEN ''is-hidden''',
'END AS task_type_class,',
'',
'CASE',
'    WHEN category IS NULL THEN ''is-hidden''',
'END AS category_class,',
'',
'CASE',
'    WHEN NULLIF(',
'        TRIM(',
'            INITCAP(',
'                REPLACE(',
'                    REGEXP_REPLACE(',
'                        task_def_name,',
'                        ''([a-z])([A-Z])'',',
'                        ''\1 \2''',
'                    ),',
'                    ''Approval'',',
'                    ''''',
'                )',
'            )',
'        ),',
'        ''''',
'    ) IS NULL',
'    OR category IS NULL',
'    THEN ''is-hidden''',
'END AS task_category_separator_class,',
'',
'CASE',
'    WHEN NULLIF(',
'        TRIM(',
'            INITCAP(',
'                REPLACE(',
'                    REGEXP_REPLACE(',
'                        task_def_name,',
'                        ''([a-z])([A-Z])'',',
'                        ''\1 \2''',
'                    ),',
'                    ''Approval'',',
'                    ''''',
'                )',
'            )',
'        ),',
'        ''''',
'    ) IS NULL',
'    AND category IS NULL',
'    THEN ''is-hidden''',
'END AS before_task_info_separator_class,',
'CASE WHEN state IN (''COMPLETED'', ''WITHDRAWN'')',
'     THEN ''is-disabled'' END AS action_css,',
'CASE WHEN last_action IS NOT NULL AND last_action_status = ''OK'' THEN',
'    INITCAP(last_action)',
'    || CASE WHEN last_action_ts IS NOT NULL',
unistr('            THEN '' \00B7 '' || TO_CHAR('),
'                FROM_TZ(last_action_ts, ''UTC'') AT TIME ZONE ''US/Eastern'',',
'                ''Mon DD, YYYY HH:MI:SS AM'') END',
'END AS last_action_summary',
'',
'',
'',
'',
'  FROM bpm_workflow_tasks'))
,p_ajax_enabled=>'Y'
,p_lazy_loading=>false
,p_query_row_template=>2538654340625403440
,p_query_num_rows=>50
,p_query_options=>'DERIVED_REPORT_COLUMNS'
,p_query_no_data_found=>'no data found'
,p_query_num_rows_type=>'NEXT_PREVIOUS_LINKS'
,p_query_row_count_max=>100000
,p_pagination_display_position=>'BOTTOM_RIGHT'
,p_prn_output=>'N'
,p_prn_format=>'PDF'
,p_sort_null=>'L'
,p_plug_query_strip_html=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334274246300269163)
,p_query_column_id=>1
,p_column_alias=>'DETAIL_TOGGLE'
,p_column_display_sequence=>40
,p_hidden_column=>'Y'
,p_display_as=>'WITHOUT_MODIFICATION'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334273040537269163)
,p_query_column_id=>2
,p_column_alias=>'HISTORY_TOGGLE'
,p_column_display_sequence=>50
,p_hidden_column=>'Y'
,p_display_as=>'WITHOUT_MODIFICATION'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334272598289269162)
,p_query_column_id=>3
,p_column_alias=>'FUSION_LINK'
,p_column_display_sequence=>60
,p_hidden_column=>'Y'
,p_display_as=>'WITHOUT_MODIFICATION'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334272262517269162)
,p_query_column_id=>4
,p_column_alias=>'LAST_ACTION_HTML'
,p_column_display_sequence=>240
,p_hidden_column=>'Y'
,p_display_as=>'WITHOUT_MODIFICATION'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334268270373269161)
,p_query_column_id=>5
,p_column_alias=>'TASK_NUMBER'
,p_column_display_sequence=>20
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334274647656269163)
,p_query_column_id=>6
,p_column_alias=>'TASK_NUMBER_VC'
,p_column_display_sequence=>220
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334268623898269161)
,p_query_column_id=>7
,p_column_alias=>'TITLE'
,p_column_display_sequence=>10
,p_column_heading=>'Tasks'
,p_column_html_expression=>wwv_flow_string.join(wwv_flow_t_varchar2(
'<div class="btask-cell">',
'',
'    <div class="btask-cell__content">',
'',
'        <div class="btask-cell__title">',
'            #TITLE#',
'        </div>',
'',
'        <div class="btask-cell__meta btask-cell__identity">',
'',
'            <span class="btask-cell__task-number">',
'                Task #TASK_NUMBER#',
'            </span>',
'',
'            <span class="task-state task-state--#STATE#">',
'                #STATE#',
'            </span>',
'',
'            <span class="btask-cell__separator #BEFORE_TASK_INFO_SEPARATOR_CLASS#">',
unistr('                \2022'),
'            </span>',
'',
'            <span class="#TASK_TYPE_CLASS#">',
'                #TASK_TYPE#',
'            </span>',
'',
'            <span class="btask-cell__separator #TASK_CATEGORY_SEPARATOR_CLASS#">',
unistr('                \2022'),
'            </span>',
'',
'            <span class="#CATEGORY_CLASS#">',
'                #CATEGORY#',
'            </span>',
'',
'            <span class="btask-cell__separator">',
unistr('                \2022'),
'            </span>',
'',
'            <span class="task-age task-age--#AGE_CLASS#"',
'                  title="#DAYS_PENDING# days outstanding">',
'                #DAYS_PENDING#d',
'                <span class="task-age__dot" aria-hidden="true"></span>',
'            </span>',
'',
'        </div>',
'',
'        <div class="btask-cell__meta">',
'',
'            <span class="btask-person #SUBMITTED_CLASS#">',
'                Submitted by <strong>#SUBMITTED_BY#</strong>',
'            </span>',
'',
'            <span class="btask-cell__separator #PEOPLE_SEPARATOR_CLASS#">',
unistr('                \2022'),
'            </span>',
'',
'            <span class="btask-person #ASSIGNEE_CLASS#">',
'                Assigned to <strong>#ASSIGNEE_ID#</strong>',
'            </span>',
'            {if LAST_ACTION_SUMMARY/}',
'<br/><div class="btask-row-meta btask-last-action">Last Action: #LAST_ACTION_SUMMARY#</div>',
'{endif/}',
'',
'        </div>',
'',
'    </div>',
'',
'    <div class="btask-cell__actions">',
'',
'        #DETAIL_TOGGLE#',
'',
'        #HISTORY_TOGGLE#',
'',
'        #FUSION_LINK#',
'',
'      <span class="#ACTION_CSS#">',
'    <a href="#ACTIONS_URL#" class="btask-action-link">',
'        Actions',
'    </a>',
'</span>',
'',
'',
'    </div>',
'',
'</div>'))
,p_heading_alignment=>'LEFT'
,p_default_sort_column_sequence=>1
,p_disable_sort_column=>'N'
,p_display_as=>'WITHOUT_MODIFICATION'
,p_derived_column=>'N'
,p_include_in_export=>'Y'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334269048253269161)
,p_query_column_id=>8
,p_column_alias=>'TASK_TYPE'
,p_column_display_sequence=>70
,p_default_sort_column_sequence=>1
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334269470325269161)
,p_query_column_id=>9
,p_column_alias=>'CATEGORY'
,p_column_display_sequence=>80
,p_default_sort_column_sequence=>1
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334269853967269162)
,p_query_column_id=>10
,p_column_alias=>'ASSIGNEE_ID'
,p_column_display_sequence=>90
,p_default_sort_column_sequence=>1
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334270192670269162)
,p_query_column_id=>11
,p_column_alias=>'ASSIGNEE_TYPE'
,p_column_display_sequence=>100
,p_default_sort_column_sequence=>1
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334270673893269162)
,p_query_column_id=>12
,p_column_alias=>'CREATED_BY'
,p_column_display_sequence=>120
,p_default_sort_column_sequence=>1
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334271009135269162)
,p_query_column_id=>13
,p_column_alias=>'SUBMITTED_BY'
,p_column_display_sequence=>130
,p_default_sort_column_sequence=>1
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334271408496269162)
,p_query_column_id=>14
,p_column_alias=>'ASSIGNED_TS'
,p_column_display_sequence=>140
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334271789363269162)
,p_query_column_id=>15
,p_column_alias=>'DAYS_PENDING'
,p_column_display_sequence=>150
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334265834066269160)
,p_query_column_id=>16
,p_column_alias=>'PRIORITY'
,p_column_display_sequence=>160
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334273785720269163)
,p_query_column_id=>17
,p_column_alias=>'STATE'
,p_column_display_sequence=>110
,p_hidden_column=>'Y'
,p_display_as=>'WITHOUT_MODIFICATION'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334266219143269160)
,p_query_column_id=>18
,p_column_alias=>'IDENTIFICATION_KEY'
,p_column_display_sequence=>170
,p_default_sort_column_sequence=>1
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334266665429269160)
,p_query_column_id=>19
,p_column_alias=>'LAST_ACTION'
,p_column_display_sequence=>180
,p_default_sort_column_sequence=>1
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334267039948269160)
,p_query_column_id=>20
,p_column_alias=>'LAST_ACTION_TS'
,p_column_display_sequence=>190
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334267422537269160)
,p_query_column_id=>21
,p_column_alias=>'LAST_ACTION_STATUS'
,p_column_display_sequence=>200
,p_default_sort_column_sequence=>1
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334267819870269161)
,p_query_column_id=>22
,p_column_alias=>'LAST_ACTION_RESPONSE'
,p_column_display_sequence=>210
,p_default_sort_column_sequence=>1
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334273403312269163)
,p_query_column_id=>23
,p_column_alias=>'FROM_USER_NAME'
,p_column_display_sequence=>230
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334249330491620571)
,p_query_column_id=>24
,p_column_alias=>'ACTIONS_URL'
,p_column_display_sequence=>250
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334249442455620572)
,p_query_column_id=>25
,p_column_alias=>'STATE_HTML'
,p_column_display_sequence=>260
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334249499547620573)
,p_query_column_id=>26
,p_column_alias=>'AGE_CLASS'
,p_column_display_sequence=>270
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334249626551620574)
,p_query_column_id=>27
,p_column_alias=>'SUBMITTED_CLASS'
,p_column_display_sequence=>280
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334249767200620575)
,p_query_column_id=>28
,p_column_alias=>'ASSIGNEE_CLASS'
,p_column_display_sequence=>290
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334249863189620576)
,p_query_column_id=>29
,p_column_alias=>'PEOPLE_SEPARATOR_CLASS'
,p_column_display_sequence=>300
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334249952469620577)
,p_query_column_id=>30
,p_column_alias=>'AGE_SEPARATOR_CLASS'
,p_column_display_sequence=>310
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334250061234620578)
,p_query_column_id=>31
,p_column_alias=>'TASK_TYPE_CLASS'
,p_column_display_sequence=>320
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334250083566620579)
,p_query_column_id=>32
,p_column_alias=>'CATEGORY_CLASS'
,p_column_display_sequence=>330
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334250268843620580)
,p_query_column_id=>33
,p_column_alias=>'TASK_CATEGORY_SEPARATOR_CLASS'
,p_column_display_sequence=>340
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334250311498620581)
,p_query_column_id=>34
,p_column_alias=>'BEFORE_TASK_INFO_SEPARATOR_CLASS'
,p_column_display_sequence=>350
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334250403899620582)
,p_query_column_id=>35
,p_column_alias=>'ACTION_CSS'
,p_column_display_sequence=>360
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(334250491736620583)
,p_query_column_id=>36
,p_column_alias=>'LAST_ACTION_SUMMARY'
,p_column_display_sequence=>370
,p_hidden_column=>'Y'
,p_derived_column=>'N'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(497757367499198488)
,p_plug_name=>'Search'
,p_region_name=>'facet-search'
,p_region_template_options=>'#DEFAULT#:t-Region--noPadding:t-Region--hideHeader js-addHiddenHeadingRoleDesc:t-Region--scrollBody'
,p_plug_template=>4072358936313175081
,p_plug_display_sequence=>10
,p_plug_display_point=>'REGION_POSITION_02'
,p_location=>null
,p_plug_source_type=>'NATIVE_FACETED_SEARCH'
,p_filtered_region_id=>wwv_flow_imp.id(497757278301198488)
,p_landmark_label=>'Filters'
,p_ai_enabled=>false
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'batch_facet_search', 'N',
  'compact_numbers_threshold', '10000',
  'current_facets_selector', '#active_facets',
  'display_chart_for_top_n_values', '10',
  'show_charts', 'Y',
  'show_current_facets', 'E',
  'show_total_row_count', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(497760563640198495)
,p_plug_name=>'Button Bar'
,p_region_template_options=>'#DEFAULT#:t-ButtonRegion--noPadding:t-ButtonRegion--noUI'
,p_escape_on_http_output=>'Y'
,p_plug_template=>2126429139436695430
,p_plug_display_sequence=>10
,p_query_type=>'SQL'
,p_plug_source=>'<div id="active_facets"></div>'
,p_plug_query_num_rows=>15
,p_ai_enabled=>false
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'expand_shortcuts', 'N',
  'output_as', 'HTML',
  'show_line_breaks', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(497780402030206939)
,p_plug_name=>'Breadcrumb'
,p_region_template_options=>'#DEFAULT#:t-BreadcrumbRegion--useBreadcrumbTitle'
,p_component_template_options=>'#DEFAULT#'
,p_plug_template=>2531463326621247859
,p_plug_display_sequence=>70
,p_plug_display_point=>'REGION_POSITION_01'
,p_menu_id=>wwv_flow_imp.id(199194102562822423)
,p_plug_source_type=>'NATIVE_BREADCRUMB'
,p_menu_template_id=>4072363345357175094
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(501260610183525530)
,p_plug_name=>'Menu List'
,p_region_name=>'MENU-LIST'
,p_region_template_options=>'#DEFAULT#'
,p_component_template_options=>'#DEFAULT#'
,p_plug_template=>4501440665235496320
,p_plug_display_sequence=>60
,p_location=>null
,p_list_id=>wwv_flow_imp.id(334306479446628993)
,p_plug_source_type=>'NATIVE_LIST'
,p_list_template_id=>3493710807219547415
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(334279293085269168)
,p_button_sequence=>10
,p_button_plug_id=>wwv_flow_imp.id(497780402030206939)
,p_button_name=>'CREATE'
,p_button_action=>'REDIRECT_PAGE'
,p_button_template_options=>'#DEFAULT#:t-Button--small:t-Button--success:t-Button--iconLeft'
,p_button_template_id=>2082829544945815391
,p_button_image_alt=>'Create To Do'
,p_button_position=>'NEXT'
,p_button_redirect_url=>'f?p=&APP_ID.:6104:&SESSION.::&DEBUG.:6104::'
,p_button_css_classes=>'button'
,p_icon_css_classes=>'fa-plus'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(334278955502269168)
,p_button_sequence=>20
,p_button_plug_id=>wwv_flow_imp.id(497780402030206939)
,p_button_name=>'REFRESH_TASKS'
,p_button_static_id=>'REFRESH_TASKS'
,p_button_action=>'DEFINED_BY_DA'
,p_button_template_options=>'#DEFAULT#:t-Button--small:t-Button--iconLeft'
,p_button_template_id=>2082829544945815391
,p_button_image_alt=>'Refresh Tasks'
,p_button_position=>'NEXT'
,p_warn_on_unsaved_changes=>null
,p_icon_css_classes=>'fa-refresh'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(334279740595269168)
,p_button_sequence=>30
,p_button_plug_id=>wwv_flow_imp.id(497780402030206939)
,p_button_name=>'more'
,p_button_action=>'DEFINED_BY_DA'
,p_button_template_options=>'#DEFAULT#:t-Button--small'
,p_button_template_id=>2349107722467437027
,p_button_image_alt=>'More'
,p_button_position=>'NEXT'
,p_warn_on_unsaved_changes=>null
,p_icon_css_classes=>'fa-ellipsis-v'
,p_button_cattributes=>'data-menu="MENU-LIST_menu" style="color: white"'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(334278492489269167)
,p_button_sequence=>50
,p_button_plug_id=>wwv_flow_imp.id(497760563640198495)
,p_button_name=>'RESET'
,p_button_action=>'REDIRECT_PAGE'
,p_button_template_options=>'#DEFAULT#:t-Button--noUI:t-Button--iconLeft'
,p_button_template_id=>2082829544945815391
,p_button_image_alt=>'Reset'
,p_button_position=>'NEXT'
,p_button_redirect_url=>'f?p=&APP_ID.:6204:&APP_SESSION.::&DEBUG.:RR,6004::'
,p_icon_css_classes=>'fa-undo'
,p_required_patch=>wwv_flow_imp.id(199193574510822421)
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(497491054918546991)
,p_name=>'P6204_LAST_ACTION'
,p_source_data_type=>'VARCHAR2'
,p_item_sequence=>110
,p_item_plug_id=>wwv_flow_imp.id(497757367499198488)
,p_prompt=>'Last Action'
,p_source=>'LAST_ACTION'
,p_source_type=>'FACET_COLUMN'
,p_display_as=>'NATIVE_CHECKBOX'
,p_lov_sort_direction=>'ASC'
,p_item_template_options=>'#DEFAULT#'
,p_fc_show_label=>true
,p_fc_collapsible=>false
,p_fc_compute_counts=>true
,p_fc_show_counts=>true
,p_fc_zero_count_entries=>'H'
,p_fc_show_more_count=>7
,p_fc_filter_values=>false
,p_fc_sort_by_top_counts=>false
,p_fc_show_selected_first=>false
,p_fc_show_chart=>true
,p_fc_initial_chart=>false
,p_fc_actions_filter=>true
,p_fc_display_as=>'INLINE'
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(497768818299198528)
,p_name=>'P6204_SEARCH'
,p_item_sequence=>10
,p_item_plug_id=>wwv_flow_imp.id(497757367499198488)
,p_prompt=>'Search'
,p_source=>'TASK_NUMBER_VC,TITLE,TASK_TYPE,CATEGORY,ASSIGNEE_ID,ASSIGNEE_TYPE,CREATED_BY,SUBMITTED_BY,IDENTIFICATION_KEY,LAST_ACTION,LAST_ACTION_STATUS,LAST_ACTION_RESPONSE'
,p_source_type=>'FACET_COLUMN'
,p_display_as=>'NATIVE_SEARCH'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'input_field', 'FACET',
  'search_type', 'ROW')).to_clob
,p_fc_show_chart=>false
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(497769179235198530)
,p_name=>'P6204_TASK_TYPE'
,p_source_data_type=>'VARCHAR2'
,p_item_sequence=>40
,p_item_plug_id=>wwv_flow_imp.id(497757367499198488)
,p_prompt=>'Task Type'
,p_source=>'TASK_TYPE'
,p_source_type=>'FACET_COLUMN'
,p_display_as=>'NATIVE_CHECKBOX'
,p_lov_sort_direction=>'ASC'
,p_fc_show_label=>true
,p_fc_collapsible=>false
,p_fc_compute_counts=>true
,p_fc_show_counts=>true
,p_fc_zero_count_entries=>'H'
,p_fc_show_more_count=>7
,p_fc_filter_values=>false
,p_fc_sort_by_top_counts=>false
,p_fc_show_selected_first=>false
,p_fc_show_chart=>true
,p_fc_initial_chart=>false
,p_fc_actions_filter=>true
,p_fc_display_as=>'INLINE'
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(497769580511198530)
,p_name=>'P6204_CATEGORY'
,p_source_data_type=>'VARCHAR2'
,p_item_sequence=>50
,p_item_plug_id=>wwv_flow_imp.id(497757367499198488)
,p_prompt=>'Category'
,p_source=>'CATEGORY'
,p_source_type=>'FACET_COLUMN'
,p_display_as=>'NATIVE_CHECKBOX'
,p_lov_sort_direction=>'ASC'
,p_fc_show_label=>true
,p_fc_collapsible=>false
,p_fc_compute_counts=>true
,p_fc_show_counts=>true
,p_fc_zero_count_entries=>'H'
,p_fc_show_more_count=>7
,p_fc_filter_values=>false
,p_fc_sort_by_top_counts=>false
,p_fc_show_selected_first=>false
,p_fc_show_chart=>true
,p_fc_initial_chart=>false
,p_fc_actions_filter=>true
,p_fc_display_as=>'INLINE'
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(497770002369198530)
,p_name=>'P6204_ASSIGNEE_ID'
,p_source_data_type=>'VARCHAR2'
,p_item_sequence=>80
,p_item_plug_id=>wwv_flow_imp.id(497757367499198488)
,p_prompt=>'Assignee Id'
,p_source=>'ASSIGNEE_ID'
,p_source_type=>'FACET_COLUMN'
,p_display_as=>'NATIVE_CHECKBOX'
,p_lov_sort_direction=>'ASC'
,p_fc_show_label=>true
,p_fc_collapsible=>false
,p_fc_compute_counts=>true
,p_fc_show_counts=>true
,p_fc_zero_count_entries=>'H'
,p_fc_show_more_count=>7
,p_fc_filter_values=>false
,p_fc_sort_by_top_counts=>false
,p_fc_show_selected_first=>false
,p_fc_show_chart=>true
,p_fc_initial_chart=>false
,p_fc_actions_filter=>true
,p_fc_display_as=>'INLINE'
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(497770425003198530)
,p_name=>'P6204_ASSIGNEE_TYPE'
,p_source_data_type=>'VARCHAR2'
,p_item_sequence=>60
,p_item_plug_id=>wwv_flow_imp.id(497757367499198488)
,p_prompt=>'Assignee Type'
,p_source=>'ASSIGNEE_TYPE'
,p_source_type=>'FACET_COLUMN'
,p_display_as=>'NATIVE_CHECKBOX'
,p_lov_sort_direction=>'ASC'
,p_fc_show_label=>true
,p_fc_collapsible=>false
,p_fc_compute_counts=>true
,p_fc_show_counts=>true
,p_fc_zero_count_entries=>'H'
,p_fc_show_more_count=>7
,p_fc_filter_values=>false
,p_fc_sort_by_top_counts=>false
,p_fc_show_selected_first=>false
,p_fc_show_chart=>true
,p_fc_initial_chart=>false
,p_fc_actions_filter=>true
,p_fc_display_as=>'INLINE'
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(497770814958198530)
,p_name=>'P6204_CREATED_BY'
,p_source_data_type=>'VARCHAR2'
,p_item_sequence=>70
,p_item_plug_id=>wwv_flow_imp.id(497757367499198488)
,p_prompt=>'Created By'
,p_source=>'CREATED_BY'
,p_source_type=>'FACET_COLUMN'
,p_display_as=>'NATIVE_CHECKBOX'
,p_lov_sort_direction=>'ASC'
,p_fc_show_label=>true
,p_fc_collapsible=>false
,p_fc_compute_counts=>true
,p_fc_show_counts=>true
,p_fc_zero_count_entries=>'H'
,p_fc_show_more_count=>7
,p_fc_filter_values=>false
,p_fc_sort_by_top_counts=>false
,p_fc_show_selected_first=>false
,p_fc_show_chart=>true
,p_fc_initial_chart=>false
,p_fc_actions_filter=>true
,p_fc_display_as=>'INLINE'
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(497771193950198530)
,p_name=>'P6204_SUBMITTED_BY'
,p_source_data_type=>'VARCHAR2'
,p_item_sequence=>100
,p_item_plug_id=>wwv_flow_imp.id(497757367499198488)
,p_prompt=>'Submitted By'
,p_source=>'SUBMITTED_BY'
,p_source_type=>'FACET_COLUMN'
,p_display_as=>'NATIVE_CHECKBOX'
,p_lov_sort_direction=>'ASC'
,p_fc_show_label=>true
,p_fc_collapsible=>false
,p_fc_compute_counts=>true
,p_fc_show_counts=>true
,p_fc_zero_count_entries=>'H'
,p_fc_show_more_count=>7
,p_fc_filter_values=>false
,p_fc_sort_by_top_counts=>false
,p_fc_show_selected_first=>false
,p_fc_show_chart=>true
,p_fc_initial_chart=>false
,p_fc_actions_filter=>true
,p_fc_display_as=>'INLINE'
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(498252886651415982)
,p_name=>'P6204_STATE'
,p_source_data_type=>'VARCHAR2'
,p_item_sequence=>20
,p_item_plug_id=>wwv_flow_imp.id(497757367499198488)
,p_prompt=>'State'
,p_source=>'STATE'
,p_source_type=>'FACET_COLUMN'
,p_display_as=>'NATIVE_CHECKBOX'
,p_lov_sort_direction=>'ASC'
,p_item_template_options=>'#DEFAULT#'
,p_fc_show_label=>true
,p_fc_collapsible=>false
,p_fc_compute_counts=>true
,p_fc_show_counts=>true
,p_fc_zero_count_entries=>'H'
,p_fc_show_more_count=>7
,p_fc_filter_values=>false
,p_fc_sort_by_top_counts=>false
,p_fc_show_selected_first=>false
,p_fc_show_chart=>true
,p_fc_initial_chart=>false
,p_fc_actions_filter=>true
,p_fc_display_as=>'INLINE'
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(334284257344269184)
,p_name=>'js'
,p_event_sequence=>10
,p_triggering_element_type=>'BUTTON'
,p_triggering_button_id=>wwv_flow_imp.id(334278955502269168)
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'click'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(334284755869269185)
,p_event_id=>wwv_flow_imp.id(334284257344269184)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'N'
,p_action=>'NATIVE_JAVASCRIPT_CODE'
,p_attribute_01=>'refreshTasks();'
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(334286939661269186)
,p_name=>'facet change'
,p_event_sequence=>20
,p_triggering_element_type=>'REGION'
,p_triggering_region_id=>wwv_flow_imp.id(497757367499198488)
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'NATIVE_FACETED_SEARCH|REGION TYPE|facetschange'
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(334287290940269187)
,p_name=>'dialog closed'
,p_event_sequence=>30
,p_triggering_element_type=>'REGION'
,p_triggering_region_id=>wwv_flow_imp.id(497757278301198488)
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'apexafterclosedialog'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(334287835948269187)
,p_event_id=>wwv_flow_imp.id(334287290940269187)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'N'
,p_action=>'NATIVE_REFRESH'
,p_affected_elements_type=>'REGION'
,p_affected_region_id=>wwv_flow_imp.id(497757278301198488)
,p_attribute_01=>'N'
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(334285082208269185)
,p_name=>'Create To Do Dialog Closed'
,p_event_sequence=>40
,p_triggering_element_type=>'BUTTON'
,p_triggering_button_id=>wwv_flow_imp.id(334279293085269168)
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'apexafterclosedialog'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(334285598927269186)
,p_event_id=>wwv_flow_imp.id(334285082208269185)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'N'
,p_action=>'NATIVE_REFRESH'
,p_affected_elements_type=>'REGION'
,p_affected_region_id=>wwv_flow_imp.id(497757278301198488)
,p_attribute_01=>'N'
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(334286059671269186)
,p_name=>'New'
,p_event_sequence=>50
,p_triggering_element_type=>'BUTTON'
,p_triggering_button_id=>wwv_flow_imp.id(334279740595269168)
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'click'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(334286548102269186)
,p_event_id=>wwv_flow_imp.id(334286059671269186)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'N'
,p_action=>'NATIVE_JAVASCRIPT_CODE'
,p_attribute_01=>'$("#more_actions_btn").menu("open", event);'
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(334280648302269182)
,p_process_sequence=>10
,p_process_point=>'ON_DEMAND'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'REFRESH_TASKS'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'BEGIN',
'    pkg_bpm_tasks.refresh_tasks;',
'',
'    apex_json.open_object;',
'    apex_json.write(''status'', ''OK'');',
'    apex_json.write(''message'', ''Tasks refreshed.'');',
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
,p_internal_uid=>167027568317905013
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(334280998891269183)
,p_process_sequence=>20
,p_process_point=>'ON_DEMAND'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'GET_TASK_COMMENTS'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    l_task_number NUMBER := TO_NUMBER(apex_application.g_x01);',
'    l_raw_json    CLOB;',
'BEGIN',
'    l_raw_json := pkg_bpm_tasks.get_comments(l_task_number);',
'',
'    apex_json.open_object;',
'    apex_json.write(''status'', ''OK'');',
'    apex_json.open_array(''comments'');',
'',
'    FOR r IN (',
'        SELECT j.comment_str, j.updated_by, j.updated_date, j.user_id',
'          FROM JSON_TABLE(l_raw_json, ''$.items[*]'' COLUMNS (',
'              comment_str  VARCHAR2(4000) PATH ''$.commentStr'',',
'              updated_by   VARCHAR2(200)  PATH ''$.updatedBy'',',
'              updated_date VARCHAR2(50)   PATH ''$.updateddDate'',',
'              user_id      VARCHAR2(200)  PATH ''$.userId''',
'          )) j',
'    ) LOOP',
'        apex_json.open_object;',
'        apex_json.write(''commentStr'',  r.comment_str);',
'        apex_json.write(''updatedBy'',   r.updated_by);',
'        apex_json.write(''updatedDate'', r.updated_date);',
'        apex_json.write(''userId'',      r.user_id);',
'        apex_json.close_object;',
'    END LOOP;',
'',
'    apex_json.close_array;',
'    apex_json.close_object;',
'',
'EXCEPTION',
'    WHEN OTHERS THEN',
'        apex_json.open_object;',
'        apex_json.write(''status'', ''ERROR'');',
'        apex_json.write(''message'', SQLERRM);',
'        apex_json.close_object;',
'END;'))
,p_process_clob_language=>'PLSQL'
,p_internal_uid=>167027918906905014
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(334281452439269183)
,p_process_sequence=>30
,p_process_point=>'ON_DEMAND'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'GET_TASK_ATTACHMENTS'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    l_task_number NUMBER := TO_NUMBER(apex_application.g_x01);',
'    l_raw_json    CLOB;',
'BEGIN',
'    l_raw_json := pkg_bpm_tasks.get_attachments(l_task_number);',
'',
'    apex_json.open_object;',
'    apex_json.write(''status'', ''OK'');',
'    apex_json.open_array(''attachments'');',
'',
'    FOR r IN (',
'        SELECT j.attachment_name, j.mime_type, j.attachment_size,',
'               j.updated_by, j.updated_date',
'          FROM JSON_TABLE(l_raw_json, ''$.items[*]'' COLUMNS (',
'              attachment_name VARCHAR2(500) PATH ''$.attachmentName'',',
'              mime_type       VARCHAR2(200) PATH ''$.mimeType'',',
'              attachment_size NUMBER        PATH ''$.attachmentSize'',',
'              updated_by      VARCHAR2(200) PATH ''$.updatedBy'',',
'              updated_date    VARCHAR2(50)  PATH ''$.updatedDate''',
'          )) j',
'    ) LOOP',
'        apex_json.open_object;',
'        apex_json.write(''attachmentName'', r.attachment_name);',
'        apex_json.write(''mimeType'',       r.mime_type);',
'        apex_json.write(''attachmentSize'', r.attachment_size);',
'        apex_json.write(''updatedBy'',      r.updated_by);',
'        apex_json.write(''updatedDate'',    r.updated_date);',
'        apex_json.close_object;',
'    END LOOP;',
'',
'    apex_json.close_array;',
'    apex_json.close_object;',
'',
'EXCEPTION',
'    WHEN OTHERS THEN',
'        apex_json.open_object;',
'        apex_json.write(''status'', ''ERROR'');',
'        apex_json.write(''message'', SQLERRM);',
'        apex_json.close_object;',
'END;'))
,p_process_clob_language=>'PLSQL'
,p_internal_uid=>167028372454905014
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(334281781194269183)
,p_process_sequence=>40
,p_process_point=>'ON_DEMAND'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'ADD_TASK_COMMENT'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    l_task_number NUMBER        := TO_NUMBER(apex_application.g_x01);',
'    l_comment     VARCHAR2(4000) := SUBSTRB(apex_application.g_x02, 1, 4000);',
'BEGIN',
'    pkg_bpm_tasks.add_comment(l_task_number, l_comment);',
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
'END;'))
,p_process_clob_language=>'PLSQL'
,p_internal_uid=>167028701209905014
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(334282219917269183)
,p_process_sequence=>50
,p_process_point=>'ON_DEMAND'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'ADD_TASK_ATTACHMENT'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    l_task_number  NUMBER        := TO_NUMBER(apex_application.g_x01);',
'    l_file_name    VARCHAR2(500) := apex_application.g_x02;',
'    l_content_type VARCHAR2(200) := apex_application.g_x03;',
'    l_b64          CLOB;',
'BEGIN',
'    -- Reassemble base64 CLOB from f01 array chunks',
'    FOR i IN 1 .. apex_application.g_f01.COUNT LOOP',
'        l_b64 := l_b64 || apex_application.g_f01(i);',
'    END LOOP;',
'',
'    IF l_b64 IS NULL OR LENGTH(l_b64) = 0 THEN',
'        raise_application_error(-20010, ''No file data received.'');',
'    END IF;',
'',
'    pkg_bpm_tasks.add_attachment(',
'        p_task_number  => l_task_number,',
'        p_file_name    => l_file_name,',
'        p_content_type => l_content_type,',
'        p_file_b64     => l_b64',
'    );',
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
'END;'))
,p_process_clob_language=>'PLSQL'
,p_internal_uid=>167029139932905014
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(334282665023269183)
,p_process_sequence=>60
,p_process_point=>'ON_DEMAND'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'DOWNLOAD_TASK_ATTACHMENT'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    l_task_number  NUMBER        := TO_NUMBER(apex_application.g_x01);',
'    l_attach_name  VARCHAR2(500) := apex_application.g_x02;',
'    l_mime_type    VARCHAR2(200) := NVL(apex_application.g_x03, ''application/octet-stream'');',
'    l_url          VARCHAR2(2000);',
'    l_blob         BLOB;',
'    l_b64          CLOB;',
'BEGIN',
'    l_url := pkg_bicc_common.gc_fa_base_url',
'          || ''/bpm/api/4.0/tasks/'' || l_task_number',
'          || ''/attachments/'' || utl_url.escape(l_attach_name, FALSE, ''UTF-8'')',
'          || ''/stream'';',
'',
'    l_blob := apex_web_service.make_rest_request_b(',
'        p_url                  => l_url,',
'        p_http_method          => ''GET'',',
'        p_credential_static_id => pkg_bpm_tasks.gc_credential',
'    );',
'',
'    l_b64 := apex_web_service.blob2clobbase64(l_blob);',
'',
'    apex_json.open_object;',
'    apex_json.write(''status'', ''OK'');',
'    apex_json.write(''fileName'', l_attach_name);',
'    apex_json.write(''mimeType'', l_mime_type);',
'    apex_json.write(''data'', l_b64);',
'    apex_json.close_object;',
'',
'EXCEPTION',
'    WHEN OTHERS THEN',
'        apex_json.open_object;',
'        apex_json.write(''status'', ''ERROR'');',
'        apex_json.write(''message'', SQLERRM);',
'        apex_json.close_object;',
'END;'))
,p_process_clob_language=>'PLSQL'
,p_internal_uid=>167029585038905014
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(334283001259269183)
,p_process_sequence=>70
,p_process_point=>'ON_DEMAND'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'GET_TASK_HISTORY'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    l_task_number NUMBER := TO_NUMBER(apex_application.g_x01);',
'    l_raw_json    CLOB;',
'BEGIN',
'    l_raw_json := pkg_bpm_tasks.get_history(l_task_number);',
'',
'    apex_json.open_object;',
'    apex_json.write(''status'', ''OK'');',
'    apex_json.open_array(''history'');',
'',
'    FOR r IN (',
'        SELECT j.action_name, j.display_name, j.user_id,',
'               j.state, j.reason, j.pattern, j.updated_date',
'          FROM JSON_TABLE(l_raw_json, ''$.items[*]'' COLUMNS (',
'              action_name  VARCHAR2(200) PATH ''$.actionName'',',
'              display_name VARCHAR2(200) PATH ''$.displayName'',',
'              user_id      VARCHAR2(200) PATH ''$.userId'',',
'              state        VARCHAR2(100) PATH ''$.state'',',
'              reason       VARCHAR2(200) PATH ''$.reason'',',
'              pattern      VARCHAR2(100) PATH ''$.pattern'',',
'              updated_date VARCHAR2(50)  PATH ''$.updatedDate''',
'          )) j',
'    ) LOOP',
'        apex_json.open_object;',
'        apex_json.write(''actionName'',  r.action_name);',
'        apex_json.write(''displayName'', r.display_name);',
'        apex_json.write(''userId'',      r.user_id);',
'        apex_json.write(''state'',       r.state);',
'        apex_json.write(''reason'',      r.reason);',
'        apex_json.write(''pattern'',     r.pattern);',
'        apex_json.write(''updatedDate'', r.updated_date);',
'        apex_json.close_object;',
'    END LOOP;',
'',
'    apex_json.close_array;',
'    apex_json.close_object;',
'',
'EXCEPTION',
'    WHEN OTHERS THEN',
'        apex_json.open_object;',
'        apex_json.write(''status'', ''ERROR'');',
'        apex_json.write(''message'', SQLERRM);',
'        apex_json.close_object;',
'END;'))
,p_process_clob_language=>'PLSQL'
,p_internal_uid=>167029921274905014
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(334283434781269183)
,p_process_sequence=>80
,p_process_point=>'ON_DEMAND'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'GET_TASK_PAYLOAD'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    l_task_number NUMBER := TO_NUMBER(apex_application.g_x01);',
'BEGIN',
'    apex_json.open_object;',
'    apex_json.write(''status'', ''OK'');',
'    apex_json.open_array(''fields'');',
'    pkg_bpm_tasks.emit_payload_fields(l_task_number);',
'    apex_json.close_array;',
'    apex_json.close_object;',
'EXCEPTION',
'    WHEN NO_DATA_FOUND THEN',
'        apex_json.open_object;',
'        apex_json.write(''status'', ''ERROR'');',
'        apex_json.write(''message'', ''Task '' || l_task_number || '' not found.'');',
'        apex_json.close_object;',
'    WHEN OTHERS THEN',
'        apex_json.open_object;',
'        apex_json.write(''status'', ''ERROR'');',
'        apex_json.write(''message'', SQLERRM);',
'        apex_json.close_object;',
'END;'))
,p_process_clob_language=>'PLSQL'
,p_internal_uid=>167030354796905014
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(334283806238269184)
,p_process_sequence=>90
,p_process_point=>'ON_DEMAND'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'GET_FUSION_DEEPLINK'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    l_task_id  VARCHAR2(64) := apex_application.g_x01;',
'    l_response CLOB;',
'    l_url      VARCHAR2(4000);',
'BEGIN',
'    l_response := apex_web_service.make_rest_request(',
'        p_url                  => pkg_bicc_common.gc_fa_base_url',
'                               || ''/fscmRestApi/resources/11.13.18.05/atkPopupItems''',
'                               || ''?q=TaskId='' || l_task_id,',
'        p_http_method          => ''GET'',',
'        p_credential_static_id => pkg_bpm_tasks.gc_user_credential',
'    );',
'',
'    BEGIN',
'        apex_json.parse(l_response);',
'        l_url := apex_json.get_varchar2(''items[1].TaskDisplayURL'');',
'    EXCEPTION',
'        WHEN OTHERS THEN NULL;',
'    END;',
'',
'    apex_json.open_object;',
'    apex_json.write(''url'', NVL(l_url, ''''));',
'    apex_json.close_object;',
'',
'EXCEPTION',
'    WHEN OTHERS THEN',
'        apex_json.open_object;',
'        apex_json.write(''url'', '''');',
'        apex_json.write(''error'', SQLERRM);',
'        apex_json.close_object;',
'END;'))
,p_process_clob_language=>'PLSQL'
,p_internal_uid=>167030726253905015
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
