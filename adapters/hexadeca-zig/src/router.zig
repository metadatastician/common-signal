// SPDX-License-Identifier: MPL-2.0
//! Allocation-free native Zig REST projection of the Idris2 operation contract.

const std = @import("std");
const contract = @import("contract.zig");
const governance_status = @embedFile("governance-status.json");

pub const RouteError = error{BufferTooSmall};

const Signal = struct { occupation: []const u8, impact: []const u8, json: []const u8, row: []const u8 };
const signals = [_]Signal{
    .{
        .occupation = "journalism",
        .impact = "workload",
        .json = "{\"id\":\"synthetic-workload-001\",\"occupation\":\"journalism\",\"professionalContext\":\"journalism\",\"employment\":\"employee\",\"impact\":\"workload\",\"direction\":\"worsened\",\"claim\":\"Checking, correction, and coordination exceeded first-draft time saved.\",\"evidence\":{\"sourceClass\":\"synthetic workflow diary\",\"unit\":\"illustrative workflow episode\",\"inferenceBoundary\":\"Cannot estimate prevalence or effects in any real newsroom.\",\"workerConsent\":true,\"collectiveGovernance\":false,\"synthetic\":true},\"consultation\":{\"stage\":\"consultation-open\",\"participation\":\"recognised-union\",\"workerBody\":\"synthetic recognised union chapel\",\"scope\":\"illustrative workflow and workload assessment\",\"evidenceReference\":\"synthetic-consultation-001\",\"unresolved\":[\"staffing consequences\",\"review threshold governance\"]}}",
        .row = "<tr><th scope=\"row\">synthetic-workload-001</th><td>journalism</td><td>workload</td><td>Checking, correction, and coordination exceeded first-draft time saved.</td><td>consultation-open</td><td>Cannot estimate prevalence or effects in any real newsroom.</td></tr>",
    },
    .{
        .occupation = "public-relations",
        .impact = "worker-control",
        .json = "{\"id\":\"synthetic-control-001\",\"occupation\":\"public-relations\",\"professionalContext\":\"public-relations\",\"employment\":\"contracted\",\"impact\":\"worker-control\",\"direction\":\"mixed\",\"claim\":\"Faster production coincided with less discretion over ranking and review thresholds.\",\"evidence\":{\"sourceClass\":\"synthetic work-system trace\",\"unit\":\"illustrative production workflow\",\"inferenceBoundary\":\"Describes a scenario, not a PR workplace or workforce.\",\"workerConsent\":true,\"collectiveGovernance\":false,\"synthetic\":true},\"consultation\":{\"stage\":\"information-shared\",\"participation\":\"direct\",\"workerBody\":null,\"scope\":\"illustrative production tooling change\",\"evidenceReference\":\"synthetic-consultation-002\",\"unresolved\":[\"contractor voice\",\"availability expectations\"]}}",
        .row = "<tr><th scope=\"row\">synthetic-control-001</th><td>public-relations</td><td>worker-control</td><td>Faster production coincided with less discretion over ranking and review thresholds.</td><td>information-shared</td><td>Describes a scenario, not a PR workplace or workforce.</td></tr>",
    },
    .{
        .occupation = "cross-media",
        .impact = "collective-bargaining",
        .json = "{\"id\":\"synthetic-bargaining-001\",\"occupation\":\"cross-media\",\"professionalContext\":\"cross-media\",\"employment\":\"mixed-or-unknown\",\"impact\":\"collective-bargaining\",\"direction\":\"unknown\",\"claim\":\"No collective consultation evidence was supplied with the deployment record.\",\"evidence\":{\"sourceClass\":\"synthetic deployment register\",\"unit\":\"illustrative technology deployment\",\"inferenceBoundary\":\"Absence in the record does not prove consultation did not occur.\",\"workerConsent\":false,\"collectiveGovernance\":false,\"synthetic\":true},\"consultation\":{\"stage\":\"not-recorded\",\"participation\":\"not-recorded\",\"workerBody\":null,\"scope\":\"not supplied in the synthetic deployment record\",\"evidenceReference\":null,\"unresolved\":[\"whether consultation occurred\"]}}",
        .row = "<tr><th scope=\"row\">synthetic-bargaining-001</th><td>cross-media</td><td>collective-bargaining</td><td>No collective consultation evidence was supplied with the deployment record.</td><td>not-recorded</td><td>Absence in the record does not prove consultation did not occur.</td></tr>",
    },
};

const Filter = struct { occupation: ?[]const u8 = null, impact: ?[]const u8 = null };
fn append(output: []u8, cursor: *usize, value: []const u8) RouteError!void {
    if (value.len > output.len - cursor.*) return RouteError.BufferTooSmall;
    @memcpy(output[cursor.*..][0..value.len], value);
    cursor.* += value.len;
}
fn appendFmt(output: []u8, cursor: *usize, comptime format: []const u8, args: anytype) RouteError!void {
    const written = std.fmt.bufPrint(output[cursor.*..], format, args) catch return RouteError.BufferTooSmall;
    cursor.* += written.len;
}
fn validOccupation(value: []const u8) bool {
    return value.len == 0 or std.mem.eql(u8, value, "journalism") or std.mem.eql(u8, value, "public-relations") or std.mem.eql(u8, value, "communications") or std.mem.eql(u8, value, "cross-media");
}
fn validImpact(value: []const u8) bool {
    return value.len == 0 or std.mem.eql(u8, value, "workload") or std.mem.eql(u8, value, "editorial-independence") or std.mem.eql(u8, value, "worker-control") or std.mem.eql(u8, value, "collective-bargaining") or std.mem.eql(u8, value, "surveillance") or std.mem.eql(u8, value, "attribution") or std.mem.eql(u8, value, "skills") or std.mem.eql(u8, value, "plurality");
}
fn parseFilter(raw: []const u8) ?Filter {
    var filter = Filter{};
    if (raw.len == 0) return filter;
    var parameters = std.mem.splitScalar(u8, raw, '&');
    while (parameters.next()) |parameter| {
        if (parameter.len == 0) continue;
        const equals = std.mem.indexOfScalar(u8, parameter, '=') orelse return null;
        const key = parameter[0..equals];
        const value = parameter[equals + 1 ..];
        if (std.mem.eql(u8, key, "occupation")) {
            if (!validOccupation(value)) return null;
            if (value.len > 0) filter.occupation = value;
        } else if (std.mem.eql(u8, key, "impact")) {
            if (!validImpact(value)) return null;
            if (value.len > 0) filter.impact = value;
        } else return null;
    }
    return filter;
}
fn matches(signal: Signal, filter: Filter) bool {
    if (filter.occupation) |value| if (!std.mem.eql(u8, value, signal.occupation)) return false;
    if (filter.impact) |value| if (!std.mem.eql(u8, value, signal.impact)) return false;
    return true;
}

const BodyResponse = struct { status: u16, content_type: []const u8, body: []const u8 };
fn problem(buffer: []u8, status: u16, code: []const u8, title: []const u8) RouteError!BodyResponse {
    var cursor: usize = 0;
    try appendFmt(buffer, &cursor, "{{\"type\":\"urn:common-signal:problem:{s}\",\"title\":\"{s}\",\"status\":{d}}}", .{ code, title, status });
    return .{ .status = status, .content_type = "application/problem+json; charset=utf-8", .body = buffer[0..cursor] };
}
fn signalsJson(buffer: []u8, filter: Filter) RouteError!BodyResponse {
    var cursor: usize = 0;
    var count: usize = 0;
    try append(buffer, &cursor, "{\"schemaVersion\":\"1.0.0\",\"mode\":\"synthetic-read-only\",\"warnings\":[\"Synthetic fixtures\",\"No population inference\",\"Not an employee scoring service\"],\"data\":[");
    for (signals) |signal| {
        if (!matches(signal, filter)) continue;
        if (count > 0) try append(buffer, &cursor, ",");
        try append(buffer, &cursor, signal.json);
        count += 1;
    }
    try appendFmt(buffer, &cursor, "],\"count\":{d}}}", .{count});
    return .{ .status = 200, .content_type = "application/json; charset=utf-8", .body = buffer[0..cursor] };
}
fn homeHtml(buffer: []u8, filter: Filter) RouteError!BodyResponse {
    var cursor: usize = 0;
    var count: usize = 0;
    try append(buffer, &cursor, "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>Common Signal</title></head><body><a href=\"#main\">Skip to main content</a><header><h1>Common Signal</h1><p>Worker-centred evidence about AI in journalism, PR, communications, and media work.</p><p><a href=\"/governance\">Check the current governance authority</a>.</p></header><aside><h2>Prototype boundary</h2><p><strong>Synthetic, read-only, and non-predictive.</strong> No employee scoring or workforce sentiment inference.</p></aside><main id=\"main\"><h2>Explore synthetic signals</h2><table><caption>Signals and evidence boundaries</caption><thead><tr><th>Record</th><th>Occupation</th><th>Impact</th><th>Claim</th><th>Consultation stage</th><th>Inference boundary</th></tr></thead><tbody>");
    for (signals) |signal| {
        if (!matches(signal, filter)) continue;
        try append(buffer, &cursor, signal.row);
        count += 1;
    }
    try appendFmt(buffer, &cursor, "</tbody></table><p aria-live=\"polite\">{d} synthetic signal(s).</p><p><a href=\"/v1/signals\">View JSON</a></p></main><footer><p>No NUJ or union endorsement is implied.</p></footer></body></html>", .{count});
    return .{ .status = 200, .content_type = "text/html; charset=utf-8", .body = buffer[0..cursor] };
}
fn appendHtmlEscaped(buffer: []u8, cursor: *usize, value: []const u8) RouteError!void {
    for (value) |character| switch (character) {
        '&' => try append(buffer, cursor, "&amp;"),
        '<' => try append(buffer, cursor, "&lt;"),
        '>' => try append(buffer, cursor, "&gt;"),
        '"' => try append(buffer, cursor, "&quot;"),
        else => try append(buffer, cursor, &.{character}),
    };
}
fn governanceHtml(buffer: []u8) RouteError!BodyResponse {
    var cursor: usize = 0;
    try append(buffer, &cursor, "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>Common Signal — governance authority</title></head><body><a href=\"#main\">Skip to main content</a><header><h1>Governance authority</h1><p><a href=\"/\">Common Signal home</a></p></header><aside><h2>How to read this status</h2><p>Maintainers cannot issue worker, workplace, NUJ, or trade-union authority.</p></aside><main id=\"main\"><h2>Current machine-readable record</h2><pre>");
    try appendHtmlEscaped(buffer, &cursor, std.mem.trim(u8, governance_status, "\r\n"));
    try append(buffer, &cursor, "</pre><p><a href=\"/v1/governance\">Retrieve canonical JSON</a>.</p><p>No document alone authorises live collection.</p></main><footer><p>No NUJ or trade-union endorsement is implied.</p></footer></body></html>");
    return .{ .status = 200, .content_type = "text/html; charset=utf-8", .body = buffer[0..cursor] };
}
fn routeBody(method: []const u8, target: []const u8, buffer: []u8) RouteError!BodyResponse {
    if (!std.mem.eql(u8, method, "GET") and !std.mem.eql(u8, method, "HEAD")) return problem(buffer, 405, "read_only", "Common Signal currently accepts GET and HEAD only.");
    const question = std.mem.indexOfScalar(u8, target, '?');
    const path = if (question) |index| target[0..index] else target;
    const raw_query = if (question) |index| target[index + 1 ..] else "";
    if (std.mem.eql(u8, path, "/") or std.mem.eql(u8, path, "/v1/signals")) {
        const filter = parseFilter(raw_query) orelse return problem(buffer, 400, "invalid_query", "The supplied filter is not part of the canonical query algebra.");
        if (std.mem.eql(u8, path, "/")) return homeHtml(buffer, filter);
        return signalsJson(buffer, filter);
    }
    if (raw_query.len > 0) return problem(buffer, 400, "invalid_query", "This route does not accept query parameters.");
    if (std.mem.eql(u8, path, "/health")) return .{ .status = 200, .content_type = "application/json; charset=utf-8", .body = "{\"status\":\"ok\",\"mode\":\"synthetic-read-only\",\"abiAuthority\":\"Idris2\",\"apiImplementation\":\"Zig\",\"schemaVersion\":\"1.0.0\"}" };
    if (std.mem.eql(u8, path, "/v1/governance")) return .{ .status = 200, .content_type = "application/json; charset=utf-8", .body = std.mem.trim(u8, governance_status, "\r\n") };
    if (std.mem.eql(u8, path, "/governance")) return governanceHtml(buffer);
    return problem(buffer, 404, "not_found", "No read-only route exists at this path.");
}
pub fn routeHttp1(method: []const u8, target: []const u8, output: []u8) RouteError![]const u8 {
    if (!contract.payloadInBounds(target.len)) return RouteError.BufferTooSmall;
    var body_buffer: [96 * 1024]u8 = undefined;
    var response = try routeBody(method, target, &body_buffer);
    if (std.mem.eql(u8, method, "HEAD")) response.body = "";
    const reason = switch (response.status) {
        200 => "OK",
        400 => "Bad Request",
        404 => "Not Found",
        405 => "Method Not Allowed",
        else => "Error",
    };
    var cursor: usize = 0;
    try appendFmt(output, &cursor, "HTTP/1.1 {d} {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nContent-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'\r\nReferrer-Policy: no-referrer\r\nX-Content-Type-Options: nosniff\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n", .{ response.status, reason, response.content_type, response.body.len });
    try append(output, &cursor, response.body);
    return output[0..cursor];
}

test "native Zig router filters synthetic signals" {
    var output: [16 * 1024]u8 = undefined;
    const response = try routeHttp1("GET", "/v1/signals?occupation=journalism&impact=workload", &output);
    try std.testing.expect(std.mem.indexOf(u8, response, "synthetic-workload-001") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "synthetic-control-001") == null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"count\":1") != null);
}
test "native Zig router exposes governance and rejects mutation" {
    var output: [16 * 1024]u8 = undefined;
    const governance = try routeHttp1("GET", "/v1/governance", &output);
    try std.testing.expect(std.mem.indexOf(u8, governance, "draft-not-consulted") != null);
    const mutation = try routeHttp1("POST", "/v1/signals", &output);
    try std.testing.expect(std.mem.startsWith(u8, mutation, "HTTP/1.1 405"));
}
test "positive control rejects unknown filter" {
    var output: [16 * 1024]u8 = undefined;
    const response = try routeHttp1("GET", "/v1/signals?worker=alice", &output);
    try std.testing.expect(std.mem.startsWith(u8, response, "HTTP/1.1 400"));
}
