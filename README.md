# BPM Workflow Tasks

Oracle APEX package for listing and acting on Fusion BPM approval tasks via the REST API.

## Overview

Provides an APEX-based approval dashboard that displays all pending BPM workflow tasks and allows administrators to take action (approve, reject, reassign, acquire, etc.) directly from APEX.

## Files

| File | Description |
|---|---|
| `bpm_workflow_tasks.sql` | Table DDL -- stores task metadata + action audit trail |
| `pkg_bpm_tasks.sql` | Package spec |
| `pkg_bpm_tasks.plb` | Package body |

## API Endpoints

- **GET** `/bpm/api/4.0/tasks?assignment=ADMIN&status=ASSIGNED` -- list all pending tasks (paginated)
- **GET** `/bpm/api/4.0/tasks/{number}` -- single task detail with `actionList`
- **PUT** `/bpm/api/3.0/tasks` -- act on tasks (v3.0 required; v4.0 PUT returns error 76012)

## Package Procedures

### `refresh_tasks(p_status, p_assignment)`

Paginates the GET endpoint and MERGEs results into `bpm_workflow_tasks`. Preserves `last_action_*` columns between refreshes.

### `action_task(p_task_number, p_action, p_comment, p_assignee_id, p_assignee_type)`

1. Fetches the task's `actionList` via v4.0 GET to validate the requested action
2. Raises `-20001` if the action is not permitted
3. Sends the action via v3.0 PUT
4. Logs the result to `last_action_*` columns on the table

Supported actions: `APPROVE`, `REJECT`, `REASSIGN`, `ACQUIRE`, `DELEGATE`, `PUSHBACK`, etc.

## v3.0 vs v4.0

The v4.0 PUT endpoint (`/bpm/api/4.0/tasks/{number}`) returns error 76012 ("Identity service cannot get users when identities' size crosses limit") on all write operations. The v3.0 PUT endpoint works correctly with a different payload format:

```json
{
  "tasks": ["230089"],
  "action": { "id": "REASSIGN" },
  "comment": { "commentStr": "Reassigned via API.", "commentScope": "TASK" },
  "identities": [{ "id": "user@example.com", "type": "user" }]
}
```

## APEX Pages

- **Page 6002** -- Parent page with IRR displaying pending tasks + Refresh button
- **Page 6003** -- Modal dialog for task actions (Ajax callback pattern with inline error display)

## Credential

Uses APEX Web Credential `gcs_reports` (must have BPM admin privileges).
