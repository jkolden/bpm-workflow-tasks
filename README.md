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
- **Task Actions** -- Approve, reject, reassign, acquire, delegate, or push back tasks with optional comments
- **Create Todo Tasks** -- Drawer form (page 6104) to create standalone todo tasks in assignees' BPM inboxes
- **Incremental Refresh** -- Orders by `updatedDate desc` and stops paging once caught up, minimizing API calls on subsequent syncs

## Files

| File | Description |
|---|---|
| `bpm_workflow_tasks.sql` | Table DDL -- stores task metadata + action audit trail |
| `bpm_task_statuses.sql` | Lookup table for tracking status values |
| `pkg_bpm_tasks.sql` | Package spec |
| `pkg_bpm_tasks.plb` | Package body |
| `bpm_task_detail_js.js` | JavaScript -- toggle panels, fetch/render payload details, comments, attachments, history; upload/download handlers |
| `bpm_task_detail_css.css` | Styles -- amber for payload details, blue for comments, teal for attachments, purple for history |
| `bpm_task_detail_apex.sql` | APEX setup instructions + Ajax callback PL/SQL for page 6004 |
| `f121_page_6004.sql` | APEX page export (faceted search) |

## API Endpoints Used

| Method | Endpoint | Version | Purpose |
|---|---|---|---|
| GET | `/bpm/api/4.0/tasks` | 4.0 | List tasks (paginated, with `orderBy`) |
| GET | `/bpm/api/4.0/tasks/{number}` | 4.0 | Single task detail with `actionList` |
| GET | `/bpm/api/4.0/tasks/{number}/payload` | 4.0 | Raw XML payload (business context fields) |
| GET | `/bpm/api/4.0/tasks/{number}/comments` | 4.0 | Fetch comments |
| GET | `/bpm/api/4.0/tasks/{number}/attachments` | 4.0 | Fetch attachment metadata |
| GET | `/bpm/api/4.0/tasks/{number}/attachments/{name}/stream` | 4.0 | Download attachment bytes |
| GET | `/bpm/api/4.0/tasks/{number}/history` | 4.0 | Approval history chain |
| POST | `/bpm/api/3.0/tasks/{number}/comments` | 3.0 | Add comment |
| POST | `/bpm/api/3.0/tasks/{number}/attachments` | 3.0 | Upload attachment (multipart/mixed) |
| POST | `/bpm/api/3.0/tasks/todoTask` | 3.0 | Create standalone todo task |
| PUT | `/bpm/api/4.0/tasks/{number}` | 4.0 | ACQUIRE action only |
| PUT | `/bpm/api/3.0/tasks` | 3.0 | All other actions (APPROVE, REJECT, REASSIGN, etc.) |

## Package Procedures & Functions

### `refresh_tasks(p_status, p_assignment)`
Incremental sync -- paginates the task list ordered by `updatedDate desc`, MERGEs into `bpm_workflow_tasks`, and exits early once it reaches tasks already synced. First run fetches everything. Preserves `last_action_*` and `tracking_status` columns between refreshes.

### `action_task(p_task_number, p_action, p_comment, p_assignee_id, p_assignee_type)`
Validates the action against the task's `actionList`, then routes ACQUIRE to the 4.0 single-task endpoint and all other actions to the 3.0 bulk endpoint. Logs results to audit columns.

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
4. Add `DETAIL_TOGGLE` and `HISTORY_TOGGLE` columns to report SQL (Escape Special Characters = No)
5. Create seven Ajax Callback processes: `GET_TASK_PAYLOAD`, `GET_TASK_COMMENTS`, `GET_TASK_ATTACHMENTS`, `ADD_TASK_COMMENT`, `ADD_TASK_ATTACHMENT`, `DOWNLOAD_TASK_ATTACHMENT`, `GET_TASK_HISTORY`
6. Create drawer page 6104 for New Todo with `CREATE_TODO_TASK` process

## v3.0 vs v4.0 Notes

- **GETs use 4.0** -- richer JSON shape, supports `orderBy`, `history` and `payload` sub-resources
- **POSTs/PUTs use 3.0** -- the v4.0 PUT endpoint returns error 76012 on most write operations
- **Exception: ACQUIRE** -- only works on 4.0 with `PUT /tasks/{number}` and body `{"action":{"id":"ACQUIRE"}}`
- **BPM API quirks**: `updatedAfter` query parameter is silently ignored; `updatedDate` in comments JSON is misspelled as `updateddDate` (double "d")

## Credential

Uses an APEX Web Credential (static ID configured as `gc_credential` in the package). Base URL is sourced from `pkg_bicc_common.gc_fa_base_url`.
