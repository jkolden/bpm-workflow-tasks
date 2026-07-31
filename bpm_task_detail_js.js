/**
 * BPM Task Detail — Inline Expand/Collapse
 * ------------------------------------------
 * Combined comments + attachments panel for the Task List Faceted page.
 * Comments and attachments are fetched from / posted to the BPM 3.0 REST API.
 * Uses "btask-" prefix to avoid collisions.
 *
 * APEX setup:
 *   - Upload to Shared Components > Static Application Files.
 *   - Reference on page 6004 as: #APP_FILES#bpm_task_detail_js#MIN#.js
 *   - Requires six Ajax callbacks: GET_TASK_PAYLOAD, GET_TASK_COMMENTS,
 *     GET_TASK_ATTACHMENTS, ADD_TASK_COMMENT, ADD_TASK_ATTACHMENT,
 *     DOWNLOAD_TASK_ATTACHMENT (see bpm_task_detail_apex.sql).
 *   - Report needs an HTML Expression column for the toggle button.
 */
(function () {
    "use strict";

    /* ================================================================== */
    /*  Toggle handler — click toggle icon in report row                   */
    /* ================================================================== */
    $(document).on("click", ".btask-toggle", function (e) {
        e.preventDefault();
        e.stopPropagation();

        var $btn      = $(this),
            taskNum   = $btn.data("task-number"),
            taskState = $btn.data("task-state") || "",
            $tr       = $btn.closest("tr"),
            $exist    = $tr.next(".btask-detail-row");

        // Collapse if already open
        if ($exist.length) {
            collapse($exist, $btn);
            return;
        }

        // Close any other open panel first
        $(".btask-detail-row").each(function () {
            var $prev = $(this).prev("tr").find(".btask-toggle");
            collapse($(this), $prev);
        });

        // Flip icon
        $btn.addClass("is-open")
            .find(".fa-folder-o")
            .removeClass("fa-folder-o")
            .addClass("fa-folder-open");

        // Build skeleton row
        var colSpan    = $tr.children("td").length,
            $detailRow = $(
                '<tr class="btask-detail-row">' +
                '<td colspan="' + colSpan + '" class="btask-detail-td">' +
                '<div class="btask-panel">' +
                '<div class="btask-loading">' +
                '<span class="fa fa-refresh fa-anim-spin"></span> Loading&hellip;' +
                '</div></div></td></tr>'
            );

        $tr.after($detailRow);
        $detailRow.hide().slideDown(200);

        fetchData(taskNum, taskState, $detailRow.find(".btask-panel"));
    });

    /* ================================================================== */
    /*  Fetch payload, comments, and attachments in parallel              */
    /* ================================================================== */
    function fetchData(taskNum, taskState, $panel) {
        var dPayload  = $.Deferred(),
            dComments = $.Deferred(),
            dAttach   = $.Deferred();

        apex.server.process("GET_TASK_PAYLOAD", { x01: String(taskNum) }, {
            dataType: "json",
            success: function (data) { dPayload.resolve(data); },
            error:   function ()     { dPayload.resolve({ status: "ERROR", fields: [] }); }
        });

        apex.server.process("GET_TASK_COMMENTS", { x01: String(taskNum) }, {
            dataType: "json",
            success: function (data) { dComments.resolve(data); },
            error:   function ()     { dComments.resolve({ status: "ERROR" }); }
        });

        apex.server.process("GET_TASK_ATTACHMENTS", { x01: String(taskNum) }, {
            dataType: "json",
            success: function (data) { dAttach.resolve(data); },
            error:   function ()     { dAttach.resolve({ status: "ERROR" }); }
        });

        $.when(dPayload, dComments, dAttach).done(function (pData, cData, aData) {
            render(taskNum, taskState, pData, cData, aData, $panel);
        });
    }

    /* ================================================================== */
    /*  Render combined panel                                              */
    /* ================================================================== */
    // States where the BPM API rejects new comments and attachments
    var TERMINAL_STATES = { COMPLETED: 1, WITHDRAWN: 1, EXPIRED: 1, ERRORED: 1, SUSPENDED: 1 };

    function render(taskNum, taskState, payloadData, commentsData, attachData, $panel) {
        var h = "";
        var canAdd = !TERMINAL_STATES[taskState.toUpperCase()];

        // --- Header ---
        h += '<div class="btask-header">' +
             '<span class="btask-title">Task Details</span>' +
             '<button type="button" class="btask-close t-Button t-Button--icon ' +
             't-Button--tiny t-Button--noUI" aria-label="Close panel">' +
             '<span class="fa fa-times"></span></button></div>';

        // --- Body wrapper ---
        h += '<div class="btask-body">';

        // ============================================================
        //  DETAILS section  (payload fields — shown only when present)
        // ============================================================
        var fields = (payloadData && payloadData.fields) ? payloadData.fields : [];
        if (fields.length) {
            h += '<div class="btask-section">';
            h += '<div class="btask-section-title btask-section-title--details">Details</div>';
            h += '<div class="btask-detail-fields">';
            for (var k = 0; k < fields.length; k++) {
                var f = fields[k];
                h += '<div class="btask-detail-field">' +
                     '<span class="btask-field-label">' + escHtml(f.label) + '</span>' +
                     '<span class="btask-field-value">' + escHtml(f.value) + '</span>' +
                     '</div>';
            }
            h += '</div></div>';
        }

        // ============================================================
        //  COMMENTS section
        // ============================================================
        h += '<div class="btask-section">';
        h += '<div class="btask-section-title btask-section-title--comments">Comments</div>';

        // Add comment form — hidden for terminal states
        if (canAdd) {
            h += '<div class="btask-add-comment">' +
                 '<textarea class="btask-comment-input" placeholder="Add a comment..." ' +
                 'rows="2" maxlength="4000"></textarea>' +
                 '<button type="button" class="btask-comment-save t-Button t-Button--hot ' +
                 't-Button--small" data-task-number="' + taskNum + '">' +
                 '<span class="t-Icon fa fa-plus"></span> Add</button></div>';
        }

        // Comments list — normalized by PL/SQL: { status, comments: [...] }
        var comments = commentsData.comments || [];
        if (comments.length) {
            h += '<div class="btask-comment-list">';
            for (var i = 0; i < comments.length; i++) {
                var c = comments[i];
                var cDate = c.updateddDate || c.updatedDate || "";
                h += '<div class="btask-comment-entry">' +
                     '<div class="btask-meta">' +
                     escHtml(c.updatedBy) + ' &mdash; ' + escHtml(cDate) +
                     '</div>' +
                     '<div class="btask-text">' + escHtml(c.commentStr) + '</div>' +
                     '</div>';
            }
            h += '</div>';
        } else if (commentsData.status === "ERROR") {
            h += '<div class="btask-error">Error loading comments.</div>';
        } else {
            h += '<div class="btask-empty">No comments.</div>';
        }
        h += '</div>';

        // ============================================================
        //  ATTACHMENTS section
        // ============================================================
        h += '<div class="btask-section">';
        h += '<div class="btask-section-title btask-section-title--attachments">Attachments</div>';

        // Upload form — hidden for terminal states
        if (canAdd) {
            h += '<div class="btask-add-attach">' +
                 '<input type="file" class="btask-file-input">' +
                 '<button type="button" class="btask-attach-save t-Button t-Button--hot ' +
                 't-Button--small" data-task-number="' + taskNum + '">' +
                 '<span class="t-Icon fa fa-upload"></span> Upload</button></div>';
        }

        // Attachment list — normalized by PL/SQL: { status, attachments: [...] }
        var attachments = attachData.attachments || [];
        if (attachments.length) {
            h += '<div class="btask-attach-list">';
            for (var j = 0; j < attachments.length; j++) {
                var a = attachments[j];
                var aName = a.attachmentName || a.title || a.fileName || "Attachment";
                var aMime = a.mimeType || "application/octet-stream";
                h += '<div class="btask-attach-entry">' +
                     '<span class="fa fa-paperclip btask-attach-icon"></span> ' +
                     '<a href="#" class="btask-attach-name btask-attach-download" ' +
                     'data-task-number="' + taskNum + '" ' +
                     'data-attach-name="' + escHtml(aName) + '" ' +
                     'data-mime-type="' + escHtml(aMime) + '">' +
                     escHtml(aName) + '</a>' +
                     '<span class="btask-attach-meta"> (' +
                     formatFileSize(a.attachmentSize || a.fileSize) +
                     (a.updatedBy ? ', ' + escHtml(a.updatedBy) : '') +
                     (a.updatedDate ? ', ' + escHtml(a.updatedDate) : '') +
                     ')</span></div>';
            }
            h += '</div>';
        } else if (attachData.status === "ERROR") {
            h += '<div class="btask-error">Error loading attachments.</div>';
        } else {
            h += '<div class="btask-empty">No attachments.</div>';
        }
        h += '</div>';  // close attachments section
        h += '</div>';  // close btask-body

        $panel.data("task-state", taskState).html(h);
        $panel.find(".btask-comment-input").focus();
    }

    /* ================================================================== */
    /*  Add comment                                                        */
    /* ================================================================== */
    $(document).on("click", ".btask-comment-save", function () {
        var $btn    = $(this),
            taskNum = $btn.data("task-number"),
            $panel  = $btn.closest(".btask-panel"),
            $input  = $panel.find(".btask-comment-input"),
            txt     = $.trim($input.val());

        if (!txt) { $input.focus(); return; }

        $btn.prop("disabled", true)
            .find(".fa-plus").removeClass("fa-plus")
            .addClass("fa-refresh fa-anim-spin");

        apex.server.process("ADD_TASK_COMMENT",
            { x01: String(taskNum), x02: txt },
            {
                dataType: "json",
                success: function (data) {
                    if (data.status === "OK") {
                        fetchData(taskNum, $panel.data("task-state") || "", $panel);
                    } else {
                        showError(data.message || "Error adding comment.");
                        resetBtn($btn, "fa-plus");
                    }
                },
                error: function () {
                    showError("Error adding comment.");
                    resetBtn($btn, "fa-plus");
                }
            }
        );
    });

    // Ctrl+Enter submits comment
    $(document).on("keydown", ".btask-comment-input", function (e) {
        if (e.ctrlKey && e.key === "Enter") {
            $(this).closest(".btask-add-comment")
                   .find(".btask-comment-save").trigger("click");
        }
    });

    /* ================================================================== */
    /*  Upload attachment                                                  */
    /* ================================================================== */
    $(document).on("click", ".btask-attach-save", function () {
        var $btn    = $(this),
            taskNum = $btn.data("task-number"),
            $panel  = $btn.closest(".btask-panel"),
            $fileIn = $panel.find(".btask-file-input"),
            files   = $fileIn[0].files;

        if (!files || !files.length) {
            showError("Please select a file first.");
            return;
        }

        var file = files[0];

        // 10 MB guard
        if (file.size > 10 * 1024 * 1024) {
            showError("File exceeds 10 MB limit.");
            return;
        }

        $btn.prop("disabled", true)
            .find(".fa-upload").removeClass("fa-upload")
            .addClass("fa-refresh fa-anim-spin");

        // Read as base64
        var reader = new FileReader();
        reader.onload = function (evt) {
            var b64 = evt.target.result.split(",")[1] || "";

            // Chunk base64 into f01 array (30 KB per element, well under
            // the VARCHAR2(32767) limit of apex_application.g_f01)
            var chunks = [], chunkSize = 30000;
            for (var i = 0; i < b64.length; i += chunkSize) {
                chunks.push(b64.substring(i, i + chunkSize));
            }

            apex.server.process("ADD_TASK_ATTACHMENT", {
                x01: String(taskNum),
                x02: file.name,
                x03: file.type || "application/octet-stream",
                f01: chunks
            }, {
                dataType: "json",
                success: function (data) {
                    if (data.status === "OK") {
                        fetchData(taskNum, $panel.data("task-state") || "", $panel);
                    } else {
                        showError(data.message || "Error uploading attachment.");
                        resetBtn($btn, "fa-upload");
                    }
                },
                error: function () {
                    showError("Error uploading attachment.");
                    resetBtn($btn, "fa-upload");
                }
            });
        };
        reader.onerror = function () {
            showError("Error reading file.");
            resetBtn($btn, "fa-upload");
        };
        reader.readAsDataURL(file);
    });

    /* ================================================================== */
    /*  Download attachment                                                */
    /* ================================================================== */
    $(document).on("click", ".btask-attach-download", function (e) {
        e.preventDefault();
        e.stopPropagation();

        var $link      = $(this),
            taskNum    = $link.data("task-number"),
            attachName = $link.data("attach-name"),
            mimeType   = $link.data("mime-type") || "application/octet-stream",
            origHtml   = $link.html();

        $link.html('<span class="fa fa-refresh fa-anim-spin"></span> Downloading\u2026');

        apex.server.process("DOWNLOAD_TASK_ATTACHMENT", {
            x01: String(taskNum),
            x02: attachName,
            x03: mimeType
        }, {
            dataType: "json",
            success: function (data) {
                $link.html(origHtml);
                if (data.status === "OK" && data.data) {
                    var blob = base64ToBlob(data.data, data.mimeType || mimeType);
                    var url  = URL.createObjectURL(blob);
                    var a    = document.createElement("a");
                    a.href     = url;
                    a.download = data.fileName || attachName;
                    document.body.appendChild(a);
                    a.click();
                    a.remove();
                    URL.revokeObjectURL(url);
                } else {
                    showError(data.message || "Error downloading attachment.");
                }
            },
            error: function () {
                $link.html(origHtml);
                showError("Error downloading attachment.");
            }
        });
    });

    /* ================================================================== */
    /*  Fusion deeplink — fetch TaskDisplayURL via atkPopupItems           */
    /* ================================================================== */
    $(document).on("click", ".bpm-fusion-link", function (e) {
        e.preventDefault();
        var $link    = $(this),
            taskId   = $link.data("task-id"),
            taskNum  = $link.closest("tr").find(".btask-toggle").data("task-number"),
            origHtml = $link.html();

        if (!taskId) return;

        apex.message.clearErrors();
        $link.html('<span class="fa fa-refresh fa-anim-spin"></span>');

        apex.server.process("GET_FUSION_DEEPLINK",
            { x01: taskId, x02: String(taskNum || "") },
        {
            dataType: "json",
            success: function (data) {
                $link.html(origHtml);
                if (data.url) {
                    (window.top || window).open(data.url, "fusion_task");
                } else {
                    showError("No Fusion link found for this task. You may not have access.");
                }
            },
            error: function () {
                $link.html(origHtml);
                showError("Error fetching Fusion link.");
            }
        });
    });

    /* ================================================================== */
    /*  History toggle — separate column                                   */
    /* ================================================================== */
    $(document).on("click", ".btask-history-toggle", function (e) {
        e.preventDefault();
        e.stopPropagation();

        var $btn    = $(this),
            taskNum = $btn.data("task-number"),
            $tr     = $btn.closest("tr"),
            $exist  = $tr.next(".btask-history-row");

        // Collapse if already open
        if ($exist.length) {
            collapseHistory($exist, $btn);
            return;
        }

        // Close any other open history panel
        $(".btask-history-row").each(function () {
            var $prev = $(this).prev("tr").find(".btask-history-toggle");
            collapseHistory($(this), $prev);
        });

        $btn.addClass("is-open")
            .find(".fa-clock-o")
            .removeClass("fa-clock-o")
            .addClass("fa-calendar-clock");

        var colSpan    = $tr.children("td").length,
            $histRow = $(
                '<tr class="btask-history-row">' +
                '<td colspan="' + colSpan + '" class="btask-detail-td">' +
                '<div class="btask-history-panel">' +
                '<div class="btask-loading">' +
                '<span class="fa fa-refresh fa-anim-spin"></span> Loading&hellip;' +
                '</div></div></td></tr>'
            );

        $tr.after($histRow);
        $histRow.hide().slideDown(200);

        fetchHistory(taskNum, $histRow.find(".btask-history-panel"));
    });

    function fetchHistory(taskNum, $panel) {
        apex.server.process("GET_TASK_HISTORY", { x01: String(taskNum) }, {
            dataType: "json",
            success: function (data) { renderHistory(data, $panel); },
            error:   function ()     { renderHistory({ status: "ERROR" }, $panel); }
        });
    }

    function renderHistory(historyData, $panel) {
        var h = '';

        h += '<div class="btask-header btask-header-history">' +
             '<span class="btask-title">Approval History</span>' +
             '<button type="button" class="btask-history-close t-Button t-Button--icon ' +
             't-Button--tiny t-Button--noUI" aria-label="Close panel">' +
             '<span class="fa fa-times"></span></button></div>';

        h += '<div class="btask-body">';

        var history = (historyData.history || []).slice().reverse();
        if (history.length) {
            h += '<div class="btask-history-list">';
            for (var k = 0; k < history.length; k++) {
                var hi = history[k];
                var stateClass = hi.state === 'Future participant'
                    ? ' btask-history-future' : '';
                h += '<div class="btask-history-entry' + stateClass + '">' +
                     '<div class="btask-history-who">' +
                     escHtml(hi.displayName || hi.userId) +
                     (hi.actionName ? ' <span class="btask-history-action">' +
                     escHtml(hi.actionName) + '</span>' : '') +
                     '</div>' +
                     '<div class="btask-history-detail">' +
                     (hi.state ? '<span class="btask-history-state">' +
                     escHtml(hi.state) + '</span>' : '') +
                     (hi.reason ? ' &mdash; ' + escHtml(hi.reason) : '') +
                     (hi.updatedDate ? ' &mdash; ' + escHtml(hi.updatedDate) : '') +
                     '</div></div>';
            }
            h += '</div>';
        } else if (historyData.status === "ERROR") {
            h += '<div class="btask-error">Error loading history.</div>';
        } else {
            h += '<div class="btask-empty">No history.</div>';
        }

        h += '</div>';

        $panel.html(h);
    }

    /* ================================================================== */
    /*  History close button                                               */
    /* ================================================================== */
    $(document).on("click", ".btask-history-close", function () {
        var $histRow = $(this).closest(".btask-history-row"),
            $btn     = $histRow.prev("tr").find(".btask-history-toggle");
        collapseHistory($histRow, $btn);
    });

    /* ================================================================== */
    /*  Close button                                                       */
    /* ================================================================== */
    $(document).on("click", ".btask-close", function () {
        var $detailRow = $(this).closest(".btask-detail-row"),
            $btn       = $detailRow.prev("tr").find(".btask-toggle");
        collapse($detailRow, $btn);
    });

    /* ================================================================== */
    /*  Collapse on report refresh (pagination, filter, etc.)              */
    /* ================================================================== */
    $(document).on("apexafterrefresh", function () {
        $(".btask-detail-row").remove();
        $(".btask-history-row").remove();
        $(".btask-toggle").removeClass("is-open")
            .find(".fa-folder-open")
            .removeClass("fa-folder-open")
            .addClass("fa-folder-o");
        $(".btask-history-toggle").removeClass("is-open")
            .find(".fa-calendar-clock")
            .removeClass("fa-calendar-clock")
            .addClass("fa-clock-o");
    });

    /* ================================================================== */
    /*  Helpers                                                            */
    /* ================================================================== */
    function collapse($detailRow, $btn) {
        $detailRow.slideUp(150, function () { $detailRow.remove(); });
        if ($btn && $btn.length) {
            $btn.removeClass("is-open")
                .find(".fa-folder-open")
                .removeClass("fa-folder-open")
                .addClass("fa-folder-o");
        }
    }

    function collapseHistory($histRow, $btn) {
        $histRow.slideUp(150, function () { $histRow.remove(); });
        if ($btn && $btn.length) {
            $btn.removeClass("is-open")
                .find(".fa-calendar-clock")
                .removeClass("fa-calendar-clock")
                .addClass("fa-clock-o");
        }
    }

    function resetBtn($btn, iconClass) {
        $btn.prop("disabled", false)
            .find(".fa-refresh")
            .removeClass("fa-refresh fa-anim-spin")
            .addClass(iconClass);
    }

    function showError(msg) {
        apex.message.showErrors([{
            type: "error", location: "page", message: msg
        }]);
    }

    function escHtml(s) {
        if (!s) return "";
        if (apex.util && apex.util.escapeHTML) return apex.util.escapeHTML(s);
        var d = document.createElement("div");
        d.appendChild(document.createTextNode(s));
        return d.innerHTML;
    }

    function base64ToBlob(b64, mimeType) {
        var byteChars = atob(b64);
        var chunks = [], sliceSize = 512;
        for (var i = 0; i < byteChars.length; i += sliceSize) {
            var slice = byteChars.slice(i, i + sliceSize);
            var bytes = new Uint8Array(slice.length);
            for (var j = 0; j < slice.length; j++) {
                bytes[j] = slice.charCodeAt(j);
            }
            chunks.push(bytes);
        }
        return new Blob(chunks, { type: mimeType || "application/octet-stream" });
    }

    function formatFileSize(bytes) {
        if (!bytes) return "0 B";
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB";
        return (bytes / 1048576).toFixed(1) + " MB";
    }

})();

/* ================================================================== */
/*  Page-level facet helpers (global scope for DA / button use)        */
/* ================================================================== */
function setFacetFilter(facetItem, value) {
    var val = Array.isArray(value) ? value.join("|||") : value;
    apex.item(facetItem).setValue(val);
    apex.region("facet-search").refresh();
}

function clearFacetFilter(facetItem) {
    apex.item(facetItem).setValue("");
    apex.region("facet-search").refresh();
}

function toggleMyTasks(facetItem, value) {
    var current = apex.item(facetItem).getValue();
    if (current && current === value) {
        clearFacetFilter(facetItem);
    } else {
        setFacetFilter(facetItem, value);
    }
}

// Re-label the menu item every time the popup menu opens
$(document).on("menubeforeopen", function () {
    setTimeout(function () {
        var isSet = apex.item("P6204_ASSIGNEE_ID").getValue() !== "";
        $(".a-Menu-label").filter(function () {
            var t = $(this).text();
            return t === "Show my Tasks" || t === "Clear my Tasks";
        }).text(isSet ? "Clear my Tasks" : "Show my Tasks")
          .siblings("[class*='fa-filter']")
          .removeClass("fa-filter fa-filter-remove")
          .addClass(isSet ? "fa-filter-remove" : "fa-filter");
    }, 0);
})
