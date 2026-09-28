# BPM workflow task BIP loader handoff

## Objective

Replace the unreliable `/bpm/api/4.0/tasks` list feed with a BI Publisher data model based on `FA_FUSION_SOAINFRA.WFTASK`. Load one row per workflow task into ATP `BPM_WORKFLOW_TASKS` and zero or more current assignees into a child table. Use one BIP report for both tables. Preserve local task action and tracking fields across refreshes.

## Verified findings in DEV2

- REST task 347042 has TASKID `3bcc2ec6-a8a5-4d61-b654-54a638143969`, state `ASSIGNED`, assignedDate `2026-09-23 15:14:03`, priority 3, fromUserName `gcs_reports`, fromUserDisplayName `GCS Reports`, ownerUser `fusion_apps_hcm_adf_appid`, and one assignee `dhammond@greenville.k12.sc.us` of type `user`.
- `FA_FUSION_SOAINFRA.WFTASK` returns this task and the corresponding TASKID, TASKNUMBER, STATE, ASSIGNEDDATE, PRIORITY, FROMUSER, FROMUSERDISPLAYNAME, OWNERUSER, and ASSIGNEES (`dhammond@greenville.k12.sc.us,user`). `APPROVALDURATION` is NULL for this task while REST returns 0.
- `FA_FUSION_SOAINFRA.WFTASK_VIEW` returned no row for this task. `FND_BPM_TASK_B` returned no row. Oracle documents `FND_BPM_TASK_B` and related FND tables as workflow archive tables; in-progress ASSIGNED tasks are not eligible for archiving. Source: https://docs.oracle.com/en/cloud/saas/procurement/25d/oapro/how-workflow-tasks-are-archived-and-purged.html
- The current ATP table has primary key `(TASK_NUMBER)` and stores local LAST_ACTION*, TRACKING_STATUS, and PERSON_ID. It cannot hold duplicate task numbers.

## BIP data model SQL candidate

Run this in the same DEV2 BIP connection. The task fields not already tested (notably CREATOR, TITLE, TASKDEFINITIONNAME, CATEGORY, CREATEDDATE, UPDATEDDATE) must be checked for valid column names and semantics before production use.

```sql
SELECT w.tasknumber          AS task_number,
       w.taskid              AS task_id,
       w.title               AS title,
       w.taskdefinitionname  AS task_def_name,
       w.category            AS category,
       w.state               AS state,
       w.priority            AS priority,
       w.assignees           AS assignees_raw,
       w.creator             AS created_by,
       w.createddate         AS created_ts,
       w.assigneddate        AS assigned_ts,
       w.updateddate         AS updated_ts,
       w.fromuser            AS from_user_name,
       w.fromuserdisplayname AS from_user_display,
       w.owneruser           AS owner_user,
       w.identificationkey   AS identification_key,
       w.approvalduration    AS approval_duration
FROM fa_fusion_soainfra.wftask w
WHERE w.category IS NOT NULL
```

Do not assume that this filter matches the old `FND_BPM_TASK_B.CATEGORY_CODE IS NOT NULL` population exactly. Compare counts by state and sample task numbers. Restrict states only after confirming the application's desired lifecycle. A later status change must update a previously loaded task.

## ATP schema

Keep `BPM_WORKFLOW_TASKS` at one row per TASK_NUMBER. Its existing ASSIGNEE_ID and ASSIGNEE_TYPE can remain for compatibility but must not be treated as a complete assignee set. Consider deprecating them after changing the app to read the child table. Create:

```sql
CREATE TABLE bpm_workflow_task_assignees (
    task_number   NUMBER NOT NULL,
    assignee_id   VARCHAR2(200) NOT NULL,
    assignee_type VARCHAR2(50) NOT NULL,
    CONSTRAINT bpm_workflow_task_assignees_pk
        PRIMARY KEY (task_number, assignee_id, assignee_type),
    CONSTRAINT bpm_workflow_task_assignees_fk
        FOREIGN KEY (task_number)
        REFERENCES bpm_workflow_tasks (task_number)
);
```

If identity strings exceed 200 characters in the source, widen the destination before loading. Optional: add `ASSIGNEES_RAW` to the parent for audit and reprocessing. No second BIP report is required.

## Loader contract

1. Retrieve the BIP report using the project's existing report transport/authentication. Parse the report's actual XML/JSON/CSV representation without depending on REST task pagination.
2. Stage each report row and validate TASK_NUMBER, TASK_ID, timestamp formats, lengths, and duplicate TASK_NUMBER rows. Treat unexpected duplicates as an error rather than silently choosing one.
3. Upsert task fields by TASK_NUMBER. On match update only task fields in the BIP extract plus REFRESHED_TS. On insert allow the DDL defaults for REFRESHED_TS and TRACKING_STATUS, or explicitly set REFRESHED_TS. Preserve LAST_ACTION, LAST_ACTION_TS, LAST_ACTION_STATUS, LAST_ACTION_RESPONSE, LAST_ACTION_BY, TRACKING_STATUS, and PERSON_ID on updates.
4. Parse ASSIGNEES_RAW according to observed source grammar, including multiple entries and user/group/role types. The one verified value is `email,user`; its comma is a pair separator, not evidence of how multiple pairs are separated. Obtain at least one multi-assignee sample before implementing the parser. Never load a partial or guessed identity. Reconcile the child table for each refreshed task (insert current pairs and delete stale pairs) in the same transaction as its parent update.
5. Do not delete parent tasks merely because they are absent from one BIP run: report filters, workflow purge, and transient extraction issues could cause omissions. Define a retention/staleness policy separately. Detect a zero-row or sharply reduced report before applying any broad reconciliation.
6. Log report run identifier/time, row counts, inserts/updates, assignee counts, parse failures, and errors. Fail the run or quarantine bad rows; do not silently advance a successful sync marker after partial failure.

## Mapping and validation decisions

| ATP column | BIP expression | Status |
| --- | --- | --- |
| TASK_NUMBER | TASKNUMBER | Verified for 347042 |
| TASK_ID | TASKID | Verified for 347042 |
| TITLE | TITLE | Verify column and length |
| TASK_DEF_NAME | TASKDEFINITIONNAME | Verify column |
| CATEGORY | CATEGORY | Verify column and filter semantics |
| STATE | STATE | Verified for 347042 |
| PRIORITY | PRIORITY | Verified for 347042 |
| CREATED_BY | CREATOR | Verify against REST `createdBy` for 347042 (`Gwynna Buckner`); may be username rather than display name |
| CREATED_TS | CREATEDDATE | Verify |
| ASSIGNED_TS | ASSIGNEDDATE | Matches REST to the second for 347042 |
| UPDATED_TS | UPDATEDDATE | Verify |
| FROM_USER_NAME | FROMUSER | Verified for 347042 |
| FROM_USER_DISPLAY | FROMUSERDISPLAYNAME | Verified for 347042 |
| OWNER_USER | OWNERUSER | Verified for 347042 |
| IDENTIFICATION_KEY | IDENTIFICATIONKEY | Verify |
| APPROVAL_DURATION | APPROVALDURATION | NULL in BIP vs 0 in REST for 347042; compare a nonzero example before deciding whether to `NVL(...,0)` |
| ASSIGNEE_ID, ASSIGNEE_TYPE | Parsed ASSIGNEES | Use child table for complete set; do not duplicate parent rows |

Timestamp values from BIP are shown with `+00:00`, but the ATP target columns are `TIMESTAMP(6)` without timezone. Parse the offset correctly and normalize consistently (recommend UTC) before discarding timezone information. Do not rely on an implicit Oracle session conversion.

## Acceptance checks

- Task 347042 loads as one parent row and one child row with the verified values above; a second identical run remains idempotent.
- A real task with multiple assignees yields one parent and the correct number of child rows. A reassignment replaces stale child membership and updates ASSIGNED_TS while preserving local action fields and TRACKING_STATUS.
- A task with nonzero APPROVALDURATION confirms whether BIP matches REST; document the chosen NULL policy.
- A completed task and an assigned task both appear when expected under the report filter; report truncation or zero rows do not wipe ATP data.
- Compare source and destination counts, task number uniqueness, and a handful of field-level samples before scheduling the loader.

## References

- Oracle workflow archive scope: https://docs.oracle.com/en/cloud/saas/procurement/25d/oapro/how-workflow-tasks-are-archived-and-purged.html
- Oracle workflow task attributes: https://docs.oracle.com/en/middleware/soa-suite/soa/12.2.1.5/develop/understanding-human-workflow-services.html
