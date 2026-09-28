-- =============================================================================
-- Add PERSON_ID to BPM_WORKFLOW_TASKS for location enrichment
-- =============================================================================
-- Populated by pkg_bpm_tasks.enrich_person_ids from the BPM /payload endpoint.
-- JOIN to FBX_HCM_EMPLOYEE on PERSON_ID to get LOCATION_NAME for filtering.
-- =============================================================================

ALTER TABLE bpm_workflow_tasks ADD (person_id NUMBER);
