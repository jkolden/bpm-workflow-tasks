-- =============================================================================
-- GET_PERSONNEL_ACTIONS
-- =============================================================================
-- Calls the Fusion /workers REST API with the Effective-Of header to retrieve
-- all date-effective assignment rows (personnel actions) in a date range.
-- Flattens the nested JSON (workers > workRelationships > assignments) into
-- a single result set suitable for an APEX Interactive Report.
--
-- Returns CLOB of JSON that can be parsed directly in an APEX report query
-- using JSON_TABLE, or call get_personnel_actions_sql() for a ready-made
-- pipelined approach.
--
-- Usage in APEX (Ajax Callback or PL/SQL region):
--   :P_JSON := pkg_bpm_tasks.get_personnel_actions('2024-01-01','2026-08-07');
--
-- Then use this SQL source for an IR/IG:
--   SELECT * FROM TABLE(pkg_bpm_tasks.get_personnel_actions_rows(
--       p_start_date => :P_START_DATE,
--       p_end_date   => :P_END_DATE
--   ))
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1. Object type for pipelined function
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TYPE t_personnel_action AS OBJECT (
    person_number       VARCHAR2(30),
    display_name        VARCHAR2(400),
    assignment_number   VARCHAR2(30),
    action_code         VARCHAR2(30),
    reason_code         VARCHAR2(80),
    effective_start_date VARCHAR2(30),
    department_name     VARCHAR2(400),
    position_code       VARCHAR2(30),
    job_code            VARCHAR2(30),
    location_code       VARCHAR2(30),
    grade_code          VARCHAR2(80),
    assignment_status   VARCHAR2(30),
    work_rel_start_date VARCHAR2(30),
    termination_date    VARCHAR2(30)
);
/

CREATE OR REPLACE TYPE t_personnel_action_tab AS TABLE OF t_personnel_action;
/
