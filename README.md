# BPM Workflow Tasks

Oracle APEX application for managing Fusion BPM approval tasks via REST API. Provides a faceted search dashboard with inline detail panels for comments, attachments, and approval history -- plus the ability to take actions (approve, reject, reassign, etc.) directly from APEX.

## Features

- **Task Dashboard** -- Faceted search page (6004) displaying all pending BPM workflow tasks with status, assignee, priority, and days pending
- **Inline Detail Panel** -- Expand/collapse panel per task row showing task payload details, comments, and attachments fetched live from the BPM API
- **Task Payload Details** -- Amber "Details" section showing business-relevant fields parsed from the raw BPM XML payload, keyed per `task_def_name` (AP invoices, HCM changes, absences, timecards, requisitions, etc.)
- **Add Comments** -- Post comments to tasks directly from the panel (Ctrl+Enter to submit)
- **Upload Attachments** -- Upload files to tasks via multipart/mixed POST with client-side 10 MB guard
- **Download Attachments** -- Download attachment files via streaming proxy (base64 decode in browser)
- **Approval History** -- Separate toggle column showing the full approval chain with action, approver, state, and timestamps; future participants are visually dimmed
- **Task Actions** -- Approve, reject, reassign, acquire, delegate, push back, escalate, suspend, resume, skip current assignment, or request information with optional comments
- **Request Information** -- Sends an INFO_REQUEST to the task submitter (or any Fusion user), moving the task to `INFO_REQUESTED` state. Assignee field auto-populates with the original submitter's user ID. Comment included inline in the same API call and appears in task history.
- **Fusion Deeplink** -- "View in Fusion" icon link on each row opens the native Fusion notification form in a new tab (built from stored `TASK_ID` GUID, no extra API call needed)
- **Create Todo Tasks** -- Drawer form (page 6104) to create standalone todo tasks in assignees' BPM inboxes
- **Incremental Refresh** -- Orders by `updatedDate desc` and stops paging once caught up, minimizing API calls on subsequent syncs

## Files

| File | Description |
|---|---|
| `bpm_workflow_tasks.sql` | Table DDL -- stores task metadata + action audit trail |
| `pkg_bpm_tasks.sql` | Package spec |
| `pkg_bpm_tasks.plb` | Package body |
| `bpm_task_detail_js.js` | JavaScript -- toggle panels, fetch/render payload details, comments, attachments, history; upload/download handlers |
| `bpm_task_detail_css.css` | Styles -- amber for payload details, blue for comments, teal for attachments, redwood for history |
| `bpm_task_detail_apex.sql` | APEX setup instructions + Ajax callback PL/SQL for pages 6003 and 6004 |
| `bpm_task_details_bip.sql` | BIP-sourced task supplemental data DDL |
| `f121_page_6004.sql` | APEX page export (faceted search) |

## API Endpoints Used

| Method | Endpoint | Version | Credential | Purpose |
|---|---|---|---|---|
| GET | `/bpm/api/4.0/tasks` | 4.0 | `gc_credential` | List tasks (paginated, with `orderBy`) |
| GET | `/bpm/api/4.0/tasks/{number}` | 4.0 | `gc_credential` | Single task detail with `actionList` |
| GET | `/bpm/api/4.0/tasks/{number}/payload` | 4.0 | `gc_credential` | Raw XML payload (business context fields) |
| GET | `/bpm/api/4.0/tasks/{number}/comments` | 4.0 | `gc_credential` | Fetch comments |
| GET | `/bpm/api/4.0/tasks/{number}/attachments` | 4.0 | `gc_credential` | Fetch attachment metadata |
| GET | `/bpm/api/4.0/tasks/{number}/attachments/{name}/stream` | 4.0 | `gc_credential` | Download attachment bytes |
| GET | `/bpm/api/4.0/tasks/{number}/history` | 4.0 | `gc_credential` | Approval history chain |
| POST | `/bpm/api/3.0/tasks/{number}/comments` | 3.0 | `gc_credential` | Add comment |
| POST | `/bpm/api/3.0/tasks/{number}/attachments` | 3.0 | `gc_credential` | Upload attachment (multipart/mixed) |
| POST | `/bpm/api/3.0/tasks/todoTask` | 3.0 | `gc_credential` | Create standalone todo task |
| PUT | `/bpm/api/4.0/tasks/{number}` | 4.0 | `gc_user_credential` | ACQUIRE, SKIP_CURRENT_ASSIGNMENT, INFO_REQUEST |
| PUT | `/bpm/api/3.0/tasks` | 3.0 | `gc_user_credential` | All other actions (APPROVE, REJECT, REASSIGN, ESCALATE, SUSPEND, RESUME, etc.) |

## Package Procedures & Functions

### `refresh_tasks(p_status, p_assignment)`
Incremental sync -- paginates the task list ordered by `updatedDate desc`, MERGEs into `bpm_workflow_tasks`, and exits early once it reaches tasks already synced. First run fetches everything. Preserves `last_action_*` and `tracking_status` columns between refreshes.

### `action_task(p_task_number, p_action, p_comment, p_assignee_id, p_assignee_type, p_credential_id)`
Validates the action against the task's `actionList`, then routes to the correct endpoint:
- **4.0 single-task endpoint** (`PUT /tasks/{number}`): `ACQUIRE`, `SKIP_CURRENT_ASSIGNMENT`, `INFO_REQUEST`
- **3.0 bulk endpoint** (`PUT /tasks`): all other actions (APPROVE, REJECT, REASSIGN, ESCALATE, etc.)

`INFO_REQUEST` requires 4.0 -- the 3.0 bulk endpoint silently no-ops it. The `identities` array (target user) sits at the top level of the payload, not inside `action`. Optional comment is passed as an inline object `{"commentStr":"...","commentScope":"TASK"}` and appears in task history. Logs results to audit columns.

### `get_comments(p_task_number) RETURN CLOB`
Returns raw JSON from the 4.0 comments endpoint.

### `add_comment(p_task_number, p_comment)`
Posts a comment via the 3.0 API.

### `get_attachments(p_task_number) RETURN CLOB`
Returns raw JSON from the 4.0 attachments endpoint.

### `add_attachment(p_task_number, p_file_name, p_content_type, p_file_b64)`
Decodes base64 CLOB to BLOB, builds multipart/mixed body, POSTs via 3.0 API.

### `get_history(p_task_number) RETURN CLOB`
Returns raw JSON from the 4.0 history endpoint.

### `get_payload(p_task_number) RETURN CLOB`
Returns raw XML CLOB from the 4.0 payload endpoint (`/tasks/{number}/payload`).

### `emit_payload_fields(p_task_number)`
Parses the raw XML payload and emits `apex_json` `{label, value}` objects for business-relevant fields. Called from the `GET_TASK_PAYLOAD` Ajax callback with an `apex_json` array already open. Branches per `task_def_name` using XMLTABLE with per-namespace parsing. Covered task types:

| `task_def_name` | Fields emitted |
|---|---|
| `FinApInvoiceApproval` | Supplier, Invoice #, Amount, Currency, Invoice Date, Description |
| `FinApIncompleteInvoiceHold` | Hold Name, Invoice #, Requestor |
| `TransfersApproval`, `PromotionsApproval`, `ChangeSalaryApprovalTask`, `TerminationsApproval`, `ChangeAssignmentApproval` | Worker, Action, Effective Date, Position, Department, Business Unit |
| `RequestNewPositionApproval` | Position, Department, Business Unit, Effective Date |
| `AbsencesApprovalsTask` | Person, Absence Type, Start Date, End Date, Duration |
| `TimecardApprovalELA` | Consumer Code, Period Start, Period End, Total Hours |
| `ReqStatusFYI`, `DocumentOpenFyi` | (FYI notifications -- no payload fields extracted) |

### `create_todo_task(p_title, p_assignee_id, p_priority, p_start_date, p_due_date)`
Creates a standalone todo task in the assignee's BPM inbox via the 3.0 API.

## APEX Setup

See `bpm_task_detail_apex.sql` for step-by-step instructions:

1. Compile `pkg_bpm_tasks.sql` (spec) then `pkg_bpm_tasks.plb` (body)
2. Upload `bpm_task_detail_js.js` and `bpm_task_detail_css.css` to Static Application Files
3. Reference on page 6004 as `#APP_FILES#bpm_task_detail_js#MIN#.js` / `#APP_FILES#bpm_task_detail_css#MIN#.css`
4. Add `DETAIL_TOGGLE`, `HISTORY_TOGGLE`, and `FUSION_LINK` columns to report SQL (Escape Special Characters = No). Also add `TO_CHAR(task_number) AS task_number_vc` as a hidden column and use it (not `task_number`) in the Row Search searchable columns — APEX Row Search does not match NUMBER columns via LIKE.
5. Create seven Ajax Callback processes on page 6004: `GET_TASK_PAYLOAD`, `GET_TASK_COMMENTS`, `GET_TASK_ATTACHMENTS`, `ADD_TASK_COMMENT`, `ADD_TASK_ATTACHMENT`, `DOWNLOAD_TASK_ATTACHMENT`, `GET_TASK_HISTORY`
6. Create modal page 6003 (Task Actions) with items `P6003_TASK_NUMBER`, `P6003_ACTION`, `P6003_COMMENT`, `P6003_ASSIGNEE` (hidden/shown via JS), `P6003_FROM_USER_NAME` (hidden). Ajax callbacks: `GET_TASK_ACTIONS`, `ACTION_TASK`. Add `from_user_name` as a hidden column to the page 6004 report and pass it via Link Builder as `P6003_FROM_USER_NAME` when opening the modal.
7. Create drawer page 6104 for New Todo with `CREATE_TODO_TASK` process

## v3.0 vs v4.0 Notes

- **GETs use 4.0** -- richer JSON shape, supports `orderBy`, `history` and `payload` sub-resources
- **POSTs/PUTs use 3.0** -- the v4.0 PUT endpoint returns error 76012 on most write operations
- **Exceptions requiring 4.0 single-task endpoint** (`PUT /tasks/{number}`):
  - `ACQUIRE` and `SKIP_CURRENT_ASSIGNMENT` -- 3.0 bulk endpoint returns HTTP 500
  - `INFO_REQUEST` -- 3.0 bulk endpoint silently no-ops it (returns 200 but state never changes). Payload: `{"action":{"id":"INFO_REQUEST"},"identities":[{"id":"<user>","type":"user"}],"comment":{"commentStr":"...","commentScope":"TASK"}}`. Comment must be an object (plain string returns 400). The `"reason"` field is not a valid property.
- **BPM API quirks**: `updatedAfter` query parameter is silently ignored; `updatedDate` in comments JSON is misspelled as `updateddDate` (double "d")

## Credential Strategy

Two APEX Web Credentials are defined as package-level constants:

| Constant | Default | Role |
|---|---|---|
| `gc_credential` | `gcs_reports` | Admin service account — used for all read-only GETs |
| `gc_user_credential` | *(configure)* | Logged-in user's Fusion token — used where user identity matters |

### Why two credentials?

**Read-only operations** (`refresh_tasks`, `get_comments`, `get_payload`, `get_history`, `get_attachments`, attachment download) use `gc_credential`. The admin account can see all tasks in the system regardless of assignee, which is exactly what the dashboard sync and detail panel reads need.

**User-identity operations** must use `gc_user_credential`:

- **`GET_TASK_ACTIONS`** — the BPM `actionList` is user-specific. The 4.0 API returns only the actions the *authenticated caller* is permitted to take on that task. Calling with the admin credential returns the admin's action list, not the current user's.
- **`action_task` (PUT)** — BPM records the authenticated caller as the approver in its audit trail, not a field in the request body. Using the admin credential would show `gcs_reports` as the approver in every BPM workflow history.

### How user credentials work in APEX

APEX's Fusion Auth integration automatically stores the logged-in user's Fusion access token as an APEX Web Credential. This credential is identified by a single fixed static ID (`gc_user_credential`) shared by all users — APEX resolves it to the current session user's token at runtime. No page items or client-side credential-passing are needed.

Set `gc_user_credential` in `pkg_bpm_tasks.sql` to the static ID of the APEX Web Credential configured for your Fusion Auth scheme.

Base URL is sourced from `pkg_bicc_common.gc_fa_base_url`.

## Known Issues

### Fusion deep link unavailable for API-claimed tasks

The "View in Fusion" deep link uses the `atkPopupItems` REST endpoint to generate a URL containing an encrypted `bpmWorklistContext` token. This only works for tasks that arrived through Fusion's notification routing (i.e., tasks that appear in the Notifications bell icon).

Tasks claimed via the BPM API (e.g., ACQUIRE from APEX) update the BPM Worklist assignee but do **not** generate a Fusion notification event. As a result, `atkPopupItems` returns no URL for these tasks.

The `bpmWorklistContext` token is encrypted and session-bound -- it cannot be reconstructed programmatically, and no alternative direct-link URL format exists on Fusion Cloud. The on-premise SOA Worklist URL (`/integration/worklistapp/faces/detail.jspx`) returns 404 on Cloud.

**Impact**: Users who claim tasks from the APEX dashboard will see "No Fusion link found" when clicking the Fusion icon for those tasks. Tasks arriving through normal Fusion workflow (the vast majority in production) will have working deep links.
