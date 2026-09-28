create or replace function get_task_charts(
    p_page_id          in number,
    p_region_static_id in varchar2,
    p_chart_id         in varchar2
) return t_chart_tab pipelined
is
    l_region_id     number;
    l_source_type   apex_application_page_regions.source_type%type;
    l_component_id  number := null;
    l_ctx           apex_exec.t_context;
    l_outer_sql     varchar2(4000);

    l_col_label     pls_integer;
    l_col_value     pls_integer;
    l_col_sort      pls_integer;
    l_col_series    pls_integer;
    l_use_series    boolean := false;

    procedure close_ctx is
    begin
        begin apex_exec.close(l_ctx); exception when others then null; end;
    end;
begin
    -- ---------------------------------------------------------------
    -- Resolve region
    -- ---------------------------------------------------------------
    select region_id, source_type
      into l_region_id, l_source_type
      from apex_application_page_regions
     where application_id = v('APP_ID')
       and page_id        = p_page_id
       and static_id      = p_region_static_id;

    if upper(l_source_type) like '%INTERACTIVE REPORT%' then
        begin
            l_component_id := apex_ir.get_last_viewed_report_id(
                                  p_page_id   => p_page_id,
                                  p_region_id => l_region_id);
        exception when others then l_component_id := null;
        end;
    end if;

    -- ---------------------------------------------------------------
    -- Build outer SQL per chart type (aggregation in SQL, not PL/SQL)
    -- ---------------------------------------------------------------
    if p_chart_id = 'AGING_TREND' then
        l_outer_sql := q'[
            select label, value,
                   dense_rank() over (order by mm_key) as sort_key
              from (
                  select to_char(assigned_ts, 'Mon YYYY')  as label,
                         count(*)                           as value,
                         to_char(assigned_ts, 'YYYY-MM')    as mm_key
                    from #APEX$SOURCE_DATA#
                   where assigned_ts is not null
                   group by to_char(assigned_ts, 'Mon YYYY'),
                            to_char(assigned_ts, 'YYYY-MM')
              )
             order by sort_key
        ]';

    elsif p_chart_id = 'AGING_BUCKET' then
        l_outer_sql := q'[
            select b.label, nvl(d.value, 0) as value, b.sort_key
              from (
                  select '0-7 Days'   as label, 1 as sort_key from dual union all
                  select '8-30 Days',  2 from dual union all
                  select '31-90 Days', 3 from dual union all
                  select '91-180 Days',4 from dual union all
                  select '180+ Days',  5 from dual
              ) b
              left join (
                  select case
                             when round(sysdate - cast(assigned_ts as date)) <= 7   then 1
                             when round(sysdate - cast(assigned_ts as date)) <= 30  then 2
                             when round(sysdate - cast(assigned_ts as date)) <= 90  then 3
                             when round(sysdate - cast(assigned_ts as date)) <= 180 then 4
                             else 5
                         end as sort_key,
                         count(*) as value
                    from #APEX$SOURCE_DATA#
                   where assigned_ts is not null
                   group by case
                                when round(sysdate - cast(assigned_ts as date)) <= 7   then 1
                                when round(sysdate - cast(assigned_ts as date)) <= 30  then 2
                                when round(sysdate - cast(assigned_ts as date)) <= 90  then 3
                                when round(sysdate - cast(assigned_ts as date)) <= 180 then 4
                                else 5
                            end
              ) d on d.sort_key = b.sort_key
             order by b.sort_key
        ]';

    elsif p_chart_id = 'BY_ASSIGNEE' then
        l_outer_sql := q'[
            select nvl(assignee_id, '(Unassigned)') as label,
                   count(*)                          as value,
                   count(*)                          as sort_key
              from #APEX$SOURCE_DATA#
             group by nvl(assignee_id, '(Unassigned)')
             order by value desc
        ]';

    elsif p_chart_id = 'BY_CATEGORY' then
        l_outer_sql := q'[
            select nvl(category, '(None)') as label,
                   count(*)                 as value,
                   count(*)                 as sort_key
              from #APEX$SOURCE_DATA#
             group by nvl(category, '(None)')
             order by value desc
        ]';

    elsif p_chart_id = 'BY_STATE' then
        l_outer_sql := q'[
            select nvl(state, '(Unknown)') as label,
                   count(*)                 as value,
                   count(*)                 as sort_key
              from #APEX$SOURCE_DATA#
             group by nvl(state, '(Unknown)')
             order by value desc
        ]';

    elsif p_chart_id = 'BY_TASK_TYPE' then
        l_outer_sql := q'[
            select case nvl(task_type, nvl(category, 'To Do'))
                       when 'Req'                                then 'Requisitions'
                       when 'Document'                           then 'Self-Service'
                       when 'Flow Manual Task'                   then 'HCM Processes'
                       when 'Hcm Email Notification Humantask'   then 'HCM Notifications'
                       when 'Fin Exm Workflow Expense'           then 'Expenses'
                       when 'Fin Exm Workflow Spend Authorization' then 'Spend Auth'
                       when 'Document Open Fyi'                  then 'FYI Notices'
                       when 'Timecard  Ela'                      then 'Timecards'
                       when 'Timecard Ela'                       then 'Timecards'
                       when 'Fin Ap Invoice'                     then 'AP Invoices'
                       when 'Fin Ap Incomplete Invoice Hold'     then 'Invoice Holds'
                       when 'Fin Gl Journal'                     then 'GL Journals'
                       when 'Absences s Task'                    then 'Absences'
                       when 'Absences  s Task'                   then 'Absences'
                       when 'Change Assignment'                  then 'Assignment Changes'
                       else nvl(task_type, nvl(category, 'To Do'))
                   end as label,
                   count(*) as value,
                   count(*) as sort_key
              from #APEX$SOURCE_DATA#
             group by case nvl(task_type, nvl(category, 'To Do'))
                          when 'Req'                                then 'Requisitions'
                          when 'Document'                           then 'Self-Service'
                          when 'Flow Manual Task'                   then 'HCM Processes'
                          when 'Hcm Email Notification Humantask'   then 'HCM Notifications'
                          when 'Fin Exm Workflow Expense'           then 'Expenses'
                          when 'Fin Exm Workflow Spend Authorization' then 'Spend Auth'
                          when 'Document Open Fyi'                  then 'FYI Notices'
                          when 'Timecard  Ela'                      then 'Timecards'
                          when 'Timecard Ela'                       then 'Timecards'
                          when 'Fin Ap Invoice'                     then 'AP Invoices'
                          when 'Fin Ap Incomplete Invoice Hold'     then 'Invoice Holds'
                          when 'Fin Gl Journal'                     then 'GL Journals'
                          when 'Absences s Task'                    then 'Absences'
                          when 'Absences  s Task'                   then 'Absences'
                          when 'Change Assignment'                  then 'Assignment Changes'
                          else nvl(task_type, nvl(category, 'To Do'))
                      end
             order by value desc
        ]';

    elsif p_chart_id = 'MY_TASKS_KPI' then
        l_outer_sql := q'[
            select 'Assigned to Me' as label,
                   count(*)          as value,
                   1                 as sort_key
              from #APEX$SOURCE_DATA#
             where upper(assignee_id) = upper(v('APP_USER'))
        ]';

    elsif p_chart_id = 'TOTAL_KPI' then
        l_outer_sql := q'[
            select 'Total Tasks' as label,
                   count(*)       as value,
                   1              as sort_key
              from #APEX$SOURCE_DATA#
        ]';

    elsif p_chart_id IN ('CHG_TERMINATION','CHG_TRANSFER','CHG_PROMOTION',
                         'CHG_ASSIGNMENT','CHG_SALARY','CHG_OTHER') then
        l_outer_sql := q'[
            select to_char(
                       trunc(to_date(
                           regexp_substr(title, ']' || q'[(\d{4}-\d{2}-\d{2})]' || q'['),
                           'YYYY-MM-DD'), 'MM'),
                       'YYYY-MM Mon') as label,
                   count(*)        as value,
                   to_number(to_char(
                       trunc(to_date(
                           regexp_substr(title, ']' || q'[(\d{4}-\d{2}-\d{2})]' || q'['),
                           'YYYY-MM-DD'), 'MM'),
                       'YYYYMM'))  as sort_key
              from #APEX$SOURCE_DATA#
             where regexp_substr(title, ']' || q'[(\d{4}-\d{2}-\d{2})]' || q'[') is not null
               and trim(task_type) = ]'
            || case p_chart_id
                   when 'CHG_TERMINATION' then q'['Terminations']'
                   when 'CHG_TRANSFER'    then q'['Transfers']'
                   when 'CHG_PROMOTION'   then q'['Promotions']'
                   when 'CHG_ASSIGNMENT'  then q'['Change Assignment']'
                   when 'CHG_SALARY'      then q'['Change Salary  Task']'
                   when 'CHG_OTHER'       then q'['Assignments']'
               end
            || q'[
             group by to_char(
                          trunc(to_date(
                              regexp_substr(title, ']' || q'[(\d{4}-\d{2}-\d{2})]' || q'['),
                              'YYYY-MM-DD'), 'MM'),
                          'YYYY-MM Mon'),
                      to_number(to_char(
                          trunc(to_date(
                              regexp_substr(title, ']' || q'[(\d{4}-\d{2}-\d{2})]' || q'['),
                              'YYYY-MM-DD'), 'MM'),
                          'YYYYMM'))
             order by sort_key
        ]';

    elsif p_chart_id = 'ASSIGNEE_STACKED' then
        l_use_series := true;
        l_outer_sql := q'[
            select nvl(assignee_id, '(Unassigned)') as label,
                   count(*)                          as value,
                   sum(count(*)) over (partition by nvl(assignee_id, '(Unassigned)')) as sort_key,
                   nvl(state, '(Unknown)')           as series_name
              from #APEX$SOURCE_DATA#
             group by nvl(assignee_id, '(Unassigned)'), nvl(state, '(Unknown)')
             order by sort_key desc, label, series_name
        ]';

    else
        return;
    end if;

    -- ---------------------------------------------------------------
    -- Open context and pipe pre-aggregated rows
    -- ---------------------------------------------------------------
    l_ctx := apex_region.open_query_context(
                 p_page_id      => p_page_id,
                 p_region_id    => l_region_id,
                 p_component_id => l_component_id,
                 p_outer_sql    => l_outer_sql);

    l_col_label := apex_exec.get_column_position(l_ctx, 'LABEL');
    l_col_value := apex_exec.get_column_position(l_ctx, 'VALUE');
    l_col_sort  := apex_exec.get_column_position(l_ctx, 'SORT_KEY');

    if l_use_series then
        l_col_series := apex_exec.get_column_position(l_ctx, 'SERIES_NAME');
    end if;

    while apex_exec.next_row(l_ctx) loop
        pipe row(t_chart_row(
            case when l_use_series
                 then apex_exec.get_varchar2(l_ctx, l_col_series)
                 else p_chart_id end,
            apex_exec.get_varchar2(l_ctx, l_col_label),
            apex_exec.get_number(l_ctx, l_col_value),
            apex_exec.get_number(l_ctx, l_col_sort)));
    end loop;

    close_ctx;
    return;

exception
    when no_data_needed then close_ctx; return;
    when others         then close_ctx; raise;
end;
/