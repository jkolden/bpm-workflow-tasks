declare
    l_url       varchar2(4000) :=
        'https://ibzsjb-dev4.fa.ocs.oraclecloud.com'
        || '/bpm/api/3.0/tasks/353153/attachments';

    l_boundary  varchar2(100) := '----OracleBpmBoundary7MA4YWxk';
    l_crlf      varchar2(2)   := chr(13) || chr(10);

    l_body      blob;
    l_response  clob;

    ------------------------------------------------------------------
    -- Append VARCHAR2 text to the multipart BLOB.
    ------------------------------------------------------------------
    procedure append_text (
        p_blob in out nocopy blob,
        p_text in            varchar2
    )
    is
        l_raw raw(32767);
    begin
        l_raw := utl_raw.cast_to_raw(p_text);

        dbms_lob.writeappend(
            lob_loc => p_blob,
            amount  => utl_raw.length(l_raw),
            buffer  => l_raw
        );
    end append_text;

begin
    dbms_lob.createtemporary(
        lob_loc => l_body,
        cache   => true
    );

    ------------------------------------------------------------------
    -- Part 1: attachment metadata
    ------------------------------------------------------------------
    append_text(l_body, '--' || l_boundary || l_crlf);

    append_text(
        l_body,
        'Content-Disposition: form-data; '
        || 'name="part1"; filename="request.json"'
        || l_crlf
    );

    append_text(
        l_body,
        'Content-Type: application/json'
        || l_crlf
        || l_crlf
    );

    append_text(
        l_body,
        '{"attachmentName":"apex-test.txt","mimeType":"text/plain"}'
        || l_crlf
    );

    ------------------------------------------------------------------
    -- Part 2: actual text-file content
    ------------------------------------------------------------------
    append_text(l_body, '--' || l_boundary || l_crlf);

    append_text(
        l_body,
        'Content-Disposition: form-data; '
        || 'name="part2"; filename="apex-test.txt"'
        || l_crlf
    );

    append_text(
        l_body,
        'Content-Type: text/plain'
        || l_crlf
        || l_crlf
    );

    append_text(
        l_body,
        'This is a test attachment created from Oracle APEX PL/SQL.'
        || l_crlf
        || 'Task ID: 353153'
        || l_crlf
    );

    ------------------------------------------------------------------
    -- Closing boundary
    ------------------------------------------------------------------
    append_text(
        l_body,
        '--' || l_boundary || '--' || l_crlf
    );

    ------------------------------------------------------------------
    -- Request headers
    ------------------------------------------------------------------
    apex_web_service.g_request_headers.delete;

    apex_web_service.g_request_headers(1).name  := 'Content-Type';
    apex_web_service.g_request_headers(1).value :=
        'multipart/mixed; boundary="' || l_boundary || '"';

    apex_web_service.g_request_headers(2).name  := 'Accept';
    apex_web_service.g_request_headers(2).value := 'application/json';

    ------------------------------------------------------------------
    -- Send request
    ------------------------------------------------------------------
    l_response := apex_web_service.make_rest_request(
        p_url         => l_url,
        p_http_method => 'POST',
        p_username    => 'gcs_reports',
        p_password    => 'Gcsd*#SC543!',
        p_body_blob   => l_body
    );

    dbms_output.put_line(
        'HTTP status: ' || apex_web_service.g_status_code
    );

    dbms_output.put_line(
        dbms_lob.substr(l_response, 32767, 1)
    );

    dbms_lob.freetemporary(l_body);

exception
    when others then
        if dbms_lob.istemporary(l_body) = 1 then
            dbms_lob.freetemporary(l_body);
        end if;

        raise;
end;
/