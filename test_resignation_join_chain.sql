-- ============================================================================
-- Test: BPM Resignation → Person mapping via BIP join chain
-- ============================================================================
-- Calls the existing BPM task BIP report and checks whether ASSIGNMENT_ID,
-- PERSON_ID, and PERSON_NUMBER come through for resignation tasks.
--
-- BEFORE updating the BIP data model: all three columns will be NULL.
-- AFTER updating: task 494005 should show:
--   ASSIGNMENT_ID = 300000012932798
--   PERSON_ID     = 300000012932664
--   PERSON_NUMBER = 104009
--
-- Pass p_updated_ts = NULL for full refresh (slower, catches all tasks)
-- or a recent date to narrow the window.
-- ============================================================================
declare
    l_xml         xmltype;
    l_param_xml   clob;
    l_total       number;
    l_resign      number;
    l_mapped      number;
    l_dupes       number;
begin
    -- 90-day lookback to test incremental parameter + join chain
    l_param_xml :=
           '<pub:parameterNameValues>'
        || '  <pub:item>'
        || '    <pub:name>p_updated_ts</pub:name>'
        || '    <pub:values>'
        || '      <pub:item>'
        || to_char(sysdate - 90, 'MM-DD-YYYY')
        || '</pub:item>'
        || '    </pub:values>'
        || '  </pub:item>'
        || '</pub:parameterNameValues>';

    dbms_output.put_line('Calling BIP report (bpm_task_list_xml, 90-day filter)...');

    l_xml := pkg_bip_soap.run_report_xml(
        p_report_name   => 'bpm_task_list_xml.xdo',
        p_parameter_xml => l_param_xml
    );

    dbms_output.put_line('Report returned. Parsing...');
    dbms_output.put_line('');

    -- 1) Total row count
    select count(*)
      into l_total
      from xmltable('//ROW' passing l_xml
               columns task_number number path 'TASK_NUMBER');

    dbms_output.put_line('Total tasks returned: ' || l_total);

    -- 2) Resignation task count
    select count(*)
      into l_resign
      from xmltable('//ROW' passing l_xml
               columns
                   task_number   number        path 'TASK_NUMBER',
                   task_def_name varchar2(200)  path 'TASK_DEF_NAME'
           ) x
     where x.task_def_name = 'ResignationApproval';

    dbms_output.put_line('Resignation tasks:    ' || l_resign);

    -- 3) How many have person_number mapped (0 = BIP model not yet updated)
    select count(*)
      into l_mapped
      from xmltable('//ROW' passing l_xml
               columns
                   task_number   number        path 'TASK_NUMBER',
                   task_def_name varchar2(200)  path 'TASK_DEF_NAME',
                   person_number varchar2(30)   path 'PERSON_NUMBER'
           ) x
     where x.task_def_name = 'ResignationApproval'
       and x.person_number is not null;

    dbms_output.put_line('Mapped (person_num):  ' || l_mapped);

    -- 4) Duplicate check — must be 0 for MERGE to work
    select count(*)
      into l_dupes
      from (
          select x.task_number
            from xmltable('//ROW' passing l_xml
                     columns task_number number path 'TASK_NUMBER') x
           group by x.task_number
          having count(*) > 1
      );

    dbms_output.put_line('Duplicate tasks:      ' || l_dupes);
    dbms_output.put_line('');

    -- 5) Detail for known resignation tasks
    dbms_output.put_line('=== Resignation task detail ===');
    for r in (
        select x.*
          from xmltable(
                   '//ROW'
                   passing l_xml
                   columns
                       task_number        number         path 'TASK_NUMBER',
                       task_def_name      varchar2(200)  path 'TASK_DEF_NAME',
                       title              varchar2(500)  path 'TITLE',
                       state              varchar2(50)   path 'STATE',
                       identification_key varchar2(200)  path 'IDENTIFICATION_KEY',
                       assignment_id      number         path 'ASSIGNMENT_ID',
                       person_id          number         path 'PERSON_ID',
                       person_number      varchar2(30)   path 'PERSON_NUMBER'
               ) x
         where x.task_def_name = 'ResignationApproval'
         order by x.task_number desc
    )
    loop
        dbms_output.put_line('Task ' || r.task_number);
        dbms_output.put_line('  Title:      ' || substr(r.title, 1, 80));
        dbms_output.put_line('  State:      ' || r.state);
        dbms_output.put_line('  ID Key:     ' || r.identification_key);
        dbms_output.put_line('  Assign ID:  ' || nvl(to_char(r.assignment_id), '(null)'));
        dbms_output.put_line('  Person ID:  ' || nvl(to_char(r.person_id), '(null)'));
        dbms_output.put_line('  Person Num: ' || nvl(r.person_number, '(null)'));

        -- Flag the verified example
        if r.task_number = 494005 then
            dbms_output.put_line('  ^^^ VERIFIED EXAMPLE - expect 300000012932798 / 300000012932664 / 104009');
        end if;

        dbms_output.put_line('');
    end loop;

    -- 6) Summary verdict
    dbms_output.put_line('=== Verdict ===');
    if l_mapped = 0 and l_resign > 0 then
        dbms_output.put_line('BIP data model has NOT been updated yet (all person columns NULL).');
        dbms_output.put_line('Update the BIP SQL, then re-run this test.');
    elsif l_mapped > 0 then
        dbms_output.put_line('BIP data model IS returning person data. Verify values above.');
    end if;

    if l_dupes > 0 then
        dbms_output.put_line('WARNING: ' || l_dupes || ' duplicate task_numbers found. Fix JOIN before deploying.');
    else
        dbms_output.put_line('No duplicates — MERGE is safe.');
    end if;
end;
/
