-- ============================================================================
-- Diagnose and repair corrupted PERSON_ID values in BPM_WORKFLOW_TASKS
-- ============================================================================
-- The old title-regex fallback and refresh_tasks stored PERSON_NUMBER
-- (5-6 digit values like 104009) in the PERSON_ID column. Real Fusion
-- PERSON_IDs are 15-digit numbers (300000012932664).
--
-- Run Step 1 first to see affected rows. Then Step 2 to fix them.
-- ============================================================================

-- Step 1: Diagnose — find rows where person_id looks like a person_number
-- (under 1 million = definitely not a Fusion internal ID)
select task_number,
       task_def_name,
       person_id          as bad_person_id,
       person_number,
       assignment_id,
       substr(title, 1, 80) as title_short
  from bpm_workflow_tasks
 where person_id is not null
   and person_id < 1000000
 order by task_number desc;

-- Step 2: NULL out corrupted person_id values
-- The next BIP load (full refresh) will repopulate correct values
-- for tasks that have a TransactionApprovalRequest payload.
update bpm_workflow_tasks
   set person_id = null
 where person_id is not null
   and person_id < 1000000;

-- Step 3: Full reload to repopulate correct values
-- begin
--     pkg_bip_soap.load_bpm_tasks(p_updated_since => null);
-- end;
-- /

-- Step 4: Verify — no rows should have person_id < 1 million after reload
select task_number, person_id, person_number, assignment_id
  from bpm_workflow_tasks
 where person_id is not null
   and person_id < 1000000;
