-- ============================================================
-- BPM Task Charts — APEX Setup Guide
-- ============================================================
-- Prerequisites: Run chart_types.sql then get_task_charts.sql
--
-- All chart regions source from the pipelined function which
-- reads the IR's filtered data via apex_region.open_query_context.
-- When facets change → IR refreshes → JS cascades refresh to
-- chart regions → charts re-query with new filters.
--
-- Pick any 2 (or more) of the 4 options below.
-- ============================================================


-- ============================================================
-- OPTION 1: AGING BUCKET  (horizontal bar chart)
-- ============================================================
-- Shows task age distribution: 0-7 / 8-30 / 31-90 / 91-180 / 180+ days
-- Good for: highlighting stale approvals sitting too long
--
-- Region type:    Chart (JET)
-- Chart type:     Bar → Orientation: Horizontal
-- Static ID:      chart_aging
-- Display Seq:    15  (above the IR at 50)
-- Template:       Standard  (or Blank with Attributes for minimal chrome)
-- Title:          Task Age
-- Grid column:    6  (half width — side-by-side with another chart)
-- New Row:        Yes
--
-- Source SQL:
/*
SELECT label, value
  FROM TABLE(get_task_charts(6204, 'bpm_tasks_ir', 'AGING_BUCKET'))
 ORDER BY sort_order
*/
-- Series setup:
--   Name:         Age
--   Label column: LABEL
--   Value column: VALUE
--   Color:        Use Series Color function (below) or leave default
--
-- Optional color function (Initialization JavaScript):
/*
function(options) {
    options.dataFilter = function(data) {
        var colors = {
            '0-7 Days': '#4ade80',
            '8-30 Days': '#a3e635',
            '31-90 Days': '#facc15',
            '91-180 Days': '#fb923c',
            '180+ Days': '#ef4444'
        };
        if (data.series && data.series[0]) {
            data.series[0].items.forEach(function(item) {
                item.color = colors[item.name] || '#94a3b8';
            });
        }
        return data;
    };
    return options;
}
*/


-- ============================================================
-- OPTION 2: BY TASK TYPE  (donut chart)
-- ============================================================
-- Shows breakdown by task type (AP Invoice, PO Req, Timecard, etc.)
-- Good for: seeing which processes generate the most approvals
--
-- Region type:    Chart (JET)
-- Chart type:     Pie → Shape: Donut
-- Static ID:      chart_by_type
-- Display Seq:    16
-- Grid column:    6  (half width, beside aging bucket)
-- New Row:        No  (same row as chart_aging)
--
-- Source SQL:
/*
SELECT label, value
  FROM TABLE(get_task_charts(6204, 'bpm_tasks_ir', 'BY_TASK_TYPE'))
 ORDER BY sort_order DESC
*/
-- Series setup:
--   Name:         Task Types
--   Label column: LABEL
--   Value column: VALUE


-- ============================================================
-- OPTION 3: BY STATE  (donut chart)
-- ============================================================
-- Shows breakdown by task state (ASSIGNED, COMPLETED, INFO_REQUESTED, etc.)
-- Good for: seeing how many tasks are actionable vs completed
--
-- Region type:    Chart (JET)
-- Chart type:     Pie → Shape: Donut
-- Static ID:      chart_by_state
-- Display Seq:    16
-- Grid column:    6
-- New Row:        No
--
-- Source SQL:
/*
SELECT label, value
  FROM TABLE(get_task_charts(6204, 'bpm_tasks_ir', 'BY_STATE'))
 ORDER BY sort_order DESC
*/
-- Series setup:
--   Name:         States
--   Label column: LABEL
--   Value column: VALUE
--
-- Optional color function to match existing state pill colors:
/*
function(options) {
    options.dataFilter = function(data) {
        var colors = {
            'ASSIGNED': '#4ade80',
            'COMPLETED': '#60a5fa',
            'INFO_REQUESTED': '#fbbf24',
            'WAITING': '#9ca3af',
            'SUSPENDED': '#d4a0ab',
            'WITHDRAWN': '#fbbf24',
            'REJECTED': '#f87171',
            'ERRORED': '#f87171'
        };
        if (data.series && data.series[0]) {
            data.series[0].items.forEach(function(item) {
                item.color = colors[item.name] || '#94a3b8';
            });
        }
        return data;
    };
    return options;
}
*/


-- ============================================================
-- OPTION 4: ASSIGNEE × STATE  (stacked horizontal bar)
-- ============================================================
-- Each bar = one assignee, slices = task states (ASSIGNED, COMPLETED, etc.)
-- Good for: seeing who has what and in which state
--
-- Region type:    Chart (JET)
-- Chart type:     Bar → Orientation: Horizontal → Stack: Stack
-- Static ID:      chart_assignee
-- Display Seq:    17
-- Grid column:    12  (full width — stacked bars need room)
-- New Row:        Yes
--
-- Source SQL:
/*
SELECT chart_id AS series_name, label, value
  FROM TABLE(get_task_charts(6204, 'bpm_tasks_ir', 'ASSIGNEE_STACKED'))
 WHERE label != '(Unassigned)'
 ORDER BY sort_order DESC
 FETCH FIRST 80 ROWS ONLY
*/
-- Series setup:
--   Create ONE series:
--     Source Type:    Region Source
--     Series Name:   Column  →  SERIES_NAME
--     Label column:  LABEL
--     Value column:  VALUE
--
-- Color function (Initialization JavaScript):
/*
function(options) {
    options.animationOnDisplay = 'none';
    options.styleDefaults = options.styleDefaults || {};
    options.styleDefaults.colors = [
        '#4ade80',
        '#60a5fa',
        '#fbbf24',
        '#9ca3af',
        '#d4a0ab',
        '#f87171',
        '#a78bfa',
        '#fb923c'
    ];
    return options;
}
*/
-- The palette maps to series in order: ASSIGNED, COMPLETED,
-- INFO_REQUESTED, WAITING, SUSPENDED, ERRORED/REJECTED, etc.
-- JET will cycle through these colors for each unique state series.


-- ============================================================
-- OPTION 5: KPI CARDS  (Assigned to Me + Total)
-- ============================================================
-- Two big numbers at the top of the page — react to facets
--
-- Region type:    PL/SQL Dynamic Content
-- Static ID:      chart_kpi
-- Display Seq:    10  (very top, before charts)
-- Template:       Blank with Attributes
-- Grid column:    12  (full width)
-- New Row:        Yes
--
-- PL/SQL Source:
/*
DECLARE
    l_my_count    NUMBER := 0;
    l_total_count NUMBER := 0;
BEGIN
    BEGIN
        SELECT value INTO l_my_count
          FROM TABLE(get_task_charts(6204, 'bpm_tasks_ir', 'MY_TASKS_KPI'));
    EXCEPTION WHEN no_data_found THEN l_my_count := 0;
    END;

    BEGIN
        SELECT value INTO l_total_count
          FROM TABLE(get_task_charts(6204, 'bpm_tasks_ir', 'TOTAL_KPI'));
    EXCEPTION WHEN no_data_found THEN l_total_count := 0;
    END;

    htp.p('<div class="bpm-kpi-row">');

    htp.p('<div class="bpm-kpi-card bpm-kpi-card--mine">');
    htp.p('<span class="bpm-kpi-icon fa fa-user"></span>');
    htp.p('<span class="bpm-kpi-value">' || l_my_count || '</span>');
    htp.p('<span class="bpm-kpi-label">Assigned to Me</span>');
    htp.p('</div>');

    htp.p('<div class="bpm-kpi-card bpm-kpi-card--total">');
    htp.p('<span class="bpm-kpi-icon fa fa-tasks"></span>');
    htp.p('<span class="bpm-kpi-value">' || l_total_count || '</span>');
    htp.p('<span class="bpm-kpi-label">Total Tasks</span>');
    htp.p('</div>');

    htp.p('</div>');
END;
*/
-- NOTE: For this region, set "Server-side Condition" to always show,
-- and set "AJAX" → "Lazy Loading" to No (so it renders on page load).


-- ============================================================
-- OPTION 6: CHANGE START DATE  (stacked bar chart)
-- ============================================================
-- Shows HCM employment tasks by the change effective date parsed
-- from the task title, stacked by action type (Termination,
-- Transfer, Promotion, etc.)
-- Only includes tasks whose title contains a YYYY-MM-DD date.
-- Grouped by month.
--
-- Region type:    Chart (JET)
-- Chart type:     Bar → Orientation: Vertical → Stack: Stack
-- Static ID:      chart_change_date
-- Display Seq:    18
-- Grid column:    12  (full width — timeline needs room)
-- New Row:        Yes
--
-- Create ONE series per action type.  Each series calls the
-- pipelined function with a different chart_id:
--
-- Series 1 — Terminations (color #ef4444):
/*
SELECT label, value
  FROM TABLE(get_task_charts(6204, 'bpm_tasks_ir', 'CHG_TERMINATION'))
 ORDER BY sort_order
*/
-- Series 2 — Assignment Changes (color #3b82f6):
/*
SELECT label, value
  FROM TABLE(get_task_charts(6204, 'bpm_tasks_ir', 'CHG_ASSIGNMENT'))
 ORDER BY sort_order
*/
-- Series 3 — Transfers (color #f59e0b):
/*
SELECT label, value
  FROM TABLE(get_task_charts(6204, 'bpm_tasks_ir', 'CHG_TRANSFER'))
 ORDER BY sort_order
*/
-- Series 4 — Promotions (color #10b981):
/*
SELECT label, value
  FROM TABLE(get_task_charts(6204, 'bpm_tasks_ir', 'CHG_PROMOTION'))
 ORDER BY sort_order
*/
-- Series 5 — Salary Changes (color #8b5cf6):
/*
SELECT label, value
  FROM TABLE(get_task_charts(6204, 'bpm_tasks_ir', 'CHG_SALARY'))
 ORDER BY sort_order
*/
--
-- Series setup (each series):
--   Label column:  LABEL
--   Value column:  VALUE
--   Assign Color:  Per-series hex color above
--
-- Labels are formatted as "YYYY-MM Mon" (e.g. "2026-03 Mar")
-- so JET sorts them chronologically. The Initialization JS
-- below strips the prefix and displays "Mon YYYY" on the axis.
--
-- Initialization JavaScript:
/*
function(options) {
    options.xAxis = options.xAxis || {};
    options.xAxis.tickLabel = options.xAxis.tickLabel || {};
    options.xAxis.tickLabel.converter = {
        format: function(label) {
            var parts = label.split(' ');
            return parts.length === 2 ? parts[1] + ' ' + parts[0].substring(0, 4) : label;
        }
    };
    return options;
}
*/
-- This converts "2026-03 Mar" → "Mar 2026" on the axis only.


-- ============================================================
-- JAVASCRIPT — Add to page 6204 JavaScript > Execute when Page Loads
-- (or append to bpm_task_detail_js.js)
-- ============================================================
-- This cascades chart refreshes after the IR refreshes from facet changes.
/*

// Refresh all chart regions when the IR refreshes (triggered by facet changes)
$("#bpm_tasks_ir").on("apexafterrefresh", function() {
    ["chart_aging", "chart_by_type", "chart_assignee", "chart_by_state", "chart_kpi", "chart_change_date"].forEach(function(id) {
        var el = document.getElementById(id);
        if (el) {
            var r = apex.region(id);
            if (r) { r.refresh(); }
        }
    });
});

*/


-- ============================================================
-- CSS — Append to bpm_task_detail_css.css (or page Inline CSS)
-- ============================================================
/*

.bpm-kpi-row {
    display: flex;
    gap: 1rem;
    padding: 0.75rem 1rem;
    flex-wrap: wrap;
}

.bpm-kpi-card {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.75rem 1.25rem;
    border-radius: 10px;
    min-width: 180px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.06);
}

.bpm-kpi-card--mine {
    background: linear-gradient(135deg, #e8f4e8 0%, #f0fdf4 100%);
    border: 1px solid #bbf7d0;
}

.bpm-kpi-card--total {
    background: linear-gradient(135deg, #eaf2fb 0%, #f0f7ff 100%);
    border: 1px solid #bfdbfe;
}

.bpm-kpi-icon {
    font-size: 1.5rem;
    opacity: 0.6;
}

.bpm-kpi-card--mine .bpm-kpi-icon { color: #16a34a; }
.bpm-kpi-card--total .bpm-kpi-icon { color: #2563eb; }

.bpm-kpi-value {
    font-size: 2rem;
    font-weight: 700;
    line-height: 1;
}

.bpm-kpi-card--mine .bpm-kpi-value { color: #15803d; }
.bpm-kpi-card--total .bpm-kpi-value { color: #1d4ed8; }

.bpm-kpi-label {
    font-size: 0.85rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    color: #6b7280;
}

*/


-- ============================================================
-- QUICK-START: Recommended 2-chart layout for demo
-- ============================================================
-- 1. Run chart_types.sql
-- 2. Run get_task_charts.sql
-- 3. On page 6204, create regions (pick 2 of the 4 options above):
--
--    Seq 10: KPI Cards (Option 4) — full width
--    Seq 15: Aging Bucket (Option 1) — grid col 6, new row
--    Seq 16: By Task Type (Option 2) — grid col 6, same row
--    Seq 50: [existing IR — no changes]
--
-- 4. Add the JS snippet to page Execute when Page Loads
-- 5. Add the CSS to page Inline CSS (or append to the CSS file)
-- 6. Done — facets now drive the charts
--
-- To test: click a facet value (e.g. State = ASSIGNED),
-- watch charts and KPI numbers update instantly.
