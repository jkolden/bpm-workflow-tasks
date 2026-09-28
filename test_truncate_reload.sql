-- Truncate and full reload of bpm_workflow_tasks
begin
    execute immediate 'truncate table bpm_workflow_tasks';
    dbms_output.put_line('Table truncated.');

    pkg_bip_soap.load_bpm_tasks(p_updated_since => null);
    dbms_output.put_line('Load complete.');
end;
/

-- Verify resignation rows got person data
select task_number, task_def_name, person_id, assignment_id, person_number
  from bpm_workflow_tasks
 where task_def_name = 'ResignationApproval'
 order by task_number desc;
