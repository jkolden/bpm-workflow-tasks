# BPM task → worker mapping handoff

## Goal

Extend the existing BI Publisher report and its APEX/ATP loader so a `ResignationApproval` task carries the affected worker's `PERSON_ID`, `PERSON_NUMBER`, and `ASSIGNMENT_ID`. Do not derive the worker number from the task title. Keep the existing incremental parameter, task exclusions, state derivation, and one row per `TASK_NUMBER`. Other task types can have null worker fields until separately mapped.

## Verified example (DEV2, 2026-09-28)

| Source | Field | Value |
| --- | --- | --- |
| `FA_FUSION_SOAINFRA.WFTASK` | `TASKNUMBER` | `494005` |
| Same | `TASKID` | `e0bb6eec-b475-48bf-b1b0-ea2086a4eb20` |
| Same | `IDENTIFICATIONKEY` | `300000050075607` |
| `WFMESSAGEATTRIBUTE`, `NAME = 'TransactionApprovalRequest'` | XML `ObjectId` | `300000012932798` |
| `WFMESSAGEATTRIBUTE`, `NAME = 'getRepresentativeList'` | XML `personId` | `300000012932664` |
| Same | XML `assignmentId` | `300000012932798` |
| `PER_ALL_ASSIGNMENTS_M` → `PER_ALL_PEOPLE_F` | `ASSIGNMENT_ID` → `PERSON_ID` → `PERSON_NUMBER` | `300000012932798` → `300000012932664` → `104009` |

The task title also contains `104009`, but the payload and HCM tables independently resolve it. `IDENTIFICATIONKEY` is the transaction ID in the XML, not the person number. The `ObjectId`-as-assignment-ID interpretation is verified for this one resignation and should be checked against more examples before treating it as universal.

`WFMESSAGEATTRIBUTE.BLOBVALUE` holds UTF-8 XML (`ENCODING = 'UTF-8'`, `STORAGETYPE = 7`). The sample task has **two** `TransactionApprovalRequest` rows, `ELEMENTSEQ = 2` and `6`, both with the same `ObjectId`. A plain join will duplicate the task.

## Candidate BI Publisher SQL

This is a proposed replacement for the current task report. Run it in the actual Fusion BI Publisher data model before deploying. The ranking chooses the highest `ELEMENTSEQ` payload row; validate that selection across other tasks.

```sql
WITH task_rows AS (
    SELECT w.*
    FROM   fa_fusion_soainfra.wftask w
    WHERE  (w.updateddate >= :p_updated_ts OR :p_updated_ts IS NULL)
      AND  w.taskdefinitionname NOT IN (
               'HcmEmailNotificationHumantask',
               'DocumentOpenFyi',
               'ReqStatusFYI'
           )
),
resignation_payload AS (
    SELECT m.taskid,
           x.assignment_id,
           ROW_NUMBER() OVER (
               PARTITION BY m.taskid ORDER BY m.elementseq DESC
           ) AS rn
    FROM   task_rows w
    JOIN   fa_fusion_soainfra.wfmessageattribute m
           ON m.taskid = w.taskid
          AND m.name = 'TransactionApprovalRequest'
    CROSS JOIN XMLTABLE(
        XMLNAMESPACES(
            DEFAULT 'http://xmlns.oracle.com/apps/hcm/transaction/model/entity/events/schema/TransactionApproval'
        ),
        '/TransactionApprovalRequest'
        PASSING XMLTYPE(m.blobvalue, NLS_CHARSET_ID('AL32UTF8'))
        COLUMNS assignment_id NUMBER PATH 'ObjectId'
    ) x
    WHERE  w.taskdefinitionname = 'ResignationApproval'
)
SELECT w.tasknumber          AS task_number,
       w.taskid              AS task_id,
       w.title               AS title,
       w.taskdefinitionname  AS task_def_name,
       w.category            AS category,
       CASE
           WHEN w.outcome IS NOT NULL THEN 'COMPLETED'
           WHEN w.state IS NOT NULL THEN w.state
           WHEN w.enddate IS NOT NULL THEN 'WITHDRAWN'
           ELSE 'ASSIGNED'
       END                   AS state,
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
       w.approvalduration    AS approval_duration,
       w.outcome             AS outcome,
       w.enddate             AS end_ts,
       rp.assignment_id      AS assignment_id,
       a.person_id           AS person_id,
       p.person_number       AS person_number
FROM   task_rows w
LEFT JOIN resignation_payload rp
       ON rp.taskid = w.taskid AND rp.rn = 1
LEFT JOIN per_all_assignments_m a
       ON a.assignment_id = rp.assignment_id
      AND TRUNC(w.createddate)
          BETWEEN a.effective_start_date AND a.effective_end_date
      AND a.effective_latest_change = 'Y'
LEFT JOIN per_all_people_f p
       ON p.person_id = a.person_id
      AND TRUNC(w.createddate)
          BETWEEN p.effective_start_date AND p.effective_end_date
```

The `LEFT JOIN`s are intentional: the report must retain tasks with absent/unmapped payloads. `PER_ALL_ASSIGNMENTS_M` is effective dated and can contain multiple rows per assignment. Check for duplicate task numbers after this join; adjust the assignment selection if necessary. `TRUNC(w.createddate)` uses the task creation date to resolve historical HCM rows. Check older and future-dated resignation cases before assuming this always works. A malformed payload XML could cause XML parsing to fail; investigate separately if the query errors.

## Local target table

`BPM_WORKFLOW_TASKS` already has `PERSON_ID NUMBER`, as well as the existing task fields, action tracking fields, and primary key `TASK_NUMBER`. Add:

```sql
ALTER TABLE bpm_workflow_tasks ADD (
    assignment_id NUMBER,
    person_number VARCHAR2(30)
);
```

Check the target's person-number convention and increase `VARCHAR2(30)` if necessary. Keep `PERSON_ID`, `ASSIGNMENT_ID`, and `PERSON_NUMBER` nullable because most task types will not have this mapping. Update any report XML mapping, merge/upsert, and source/target row type definitions so all three values load and update on subsequent refreshes. Preserve the existing `TASK_NUMBER` primary key and the `TRACKING_STATUS` foreign key. Do not overwrite locally maintained action/tracking columns during a refresh.

The existing report path in the current loader is `/Custom/SCI/BIP/bpm_task_list_xml.xdo`; confirm the actual current path/configuration in code before changing it. The loader uses an incremental `p_updated_ts` parameter and MERGE behavior. If existing rows should receive worker IDs, an incremental run alone may miss them: run a controlled backfill/full refresh or arrange a dedicated lookup for historical resignation rows. Observe BI Publisher run time and row count after adding XML parsing and HCM joins.

## Validation checklist

1. Run the candidate data model for task `494005`: exactly one row, `ASSIGNMENT_ID = 300000012932798`, `PERSON_ID = 300000012932664`, `PERSON_NUMBER = 104009`.
2. Test older resignation task `493327` (title identifies the same worker, but a different `IDENTIFICATIONKEY`) and a few other resignation tasks. Check `ObjectId`, HCM mapping, and task count.
3. Check duplicate task numbers with `GROUP BY task_number HAVING COUNT(*) > 1`. The source report must remain one row per task for the existing MERGE keyed by `TASK_NUMBER`.
4. Verify unrelated task types still appear with null worker fields. Check missing/malformed XML and missing HCM matches; keep the task row in those cases where feasible.
5. Run the loader in a safe environment, confirm new and updated records, then check that action/tracking data and the incremental watermark behave as before.

## Follow-up option

The `getRepresentativeList` XML supplies `personId` directly and its `assignmentId` matched the `TransactionApprovalRequest.ObjectId` in the verified example. It might be useful as a cross-check or fallback, but its presence and semantics across resignation tasks have not been established. Start with the assignment join and compare both payload fields on additional tasks.
