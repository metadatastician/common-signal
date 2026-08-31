// SPDX-License-Identifier: MPL-2.0
//! Native Zig mirror of the authoritative Idris2 ABI contract.

const std = @import("std");

pub const abi_version: u16 = 1;
pub const max_payload_kib: usize = 1024;

pub const Protocol = enum(u4) {
    rest = 0,
    graphql = 1,
    grpc = 2,
    mcp = 3,
    json_rpc = 4,
    websocket = 5,
    server_sent_events = 6,
    message_pack_rpc = 7,
    capn_proto = 8,
    thrift = 9,
    soap = 10,
    odata = 11,
    activity_pub = 12,
    nats = 13,
    amqp = 14,
    kafka = 15,
};

pub const Operation = enum(u16) {
    health = 1,
    query_signals = 2,
    read_governance = 3,
    discover_sources = 4,
    submit_field_observation = 5,
    produce_action_brief = 6,
};

pub const Capability = enum { implemented_read_only, governed_planned, contract_only, unsupported };

pub fn operationCapability(operation: Operation) Capability {
    return switch (operation) {
        .health, .query_signals, .read_governance => .implemented_read_only,
        .discover_sources, .submit_field_observation, .produce_action_brief => .governed_planned,
    };
}

pub const EvidencePurpose = enum { public_interest_research, worker_led_research, collective_bargaining_evidence, public_accountability_reporting };
pub const CollectionRisk = enum {
    aggregate_public_evidence,
    organisation_level_evidence,
    voluntary_field_evidence,
    identifiable_worker_monitoring,
    union_activity_monitoring,
    industrial_action_monitoring,
    protected_source_exposure,
    collective_sentiment_inference,
};
pub const AdmissionDecision = enum { admit, quarantine, reject };

pub fn admissionDecision(_: EvidencePurpose, risk: CollectionRisk) AdmissionDecision {
    return switch (risk) {
        .aggregate_public_evidence => .admit,
        .organisation_level_evidence, .voluntary_field_evidence => .quarantine,
        .identifiable_worker_monitoring,
        .union_activity_monitoring,
        .industrial_action_monitoring,
        .protected_source_exposure,
        .collective_sentiment_inference,
        => .reject,
    };
}

pub fn payloadInBounds(payload_bytes: usize) bool {
    const kib_ceiling = std.math.divCeil(usize, payload_bytes, 1024) catch return false;
    return kib_ceiling <= max_payload_kib;
}

pub const Projection = struct { protocol: Protocol, operation: Operation, route: []const u8 };
pub const ProjectionError = error{UnsupportedProtocol};

pub fn project(protocol: Protocol, operation: Operation) ProjectionError!Projection {
    return switch (protocol) {
        .rest => .{ .protocol = protocol, .operation = operation, .route = switch (operation) {
            .health => "/health",
            .query_signals => "/v1/signals",
            .read_governance => "/v1/governance",
            .discover_sources => "/v1/source-candidates",
            .submit_field_observation => "/v1/field-observations",
            .produce_action_brief => "/v1/action-briefs",
        } },
        .graphql => .{ .protocol = protocol, .operation = operation, .route = "contract-only:GraphQL" },
        .grpc => .{ .protocol = protocol, .operation = operation, .route = "contract-only:gRPC" },
        else => ProjectionError.UnsupportedProtocol,
    };
}

test "Idris2 operation codes and capability states are mirrored" {
    try std.testing.expectEqual(@as(u16, 1), abi_version);
    try std.testing.expectEqual(@as(u16, 3), @intFromEnum(Operation.read_governance));
    try std.testing.expectEqual(Capability.implemented_read_only, operationCapability(.read_governance));
    try std.testing.expectEqual(Capability.governed_planned, operationCapability(.submit_field_observation));
}

test "positive controls reject surveillance and quarantine field evidence" {
    try std.testing.expectEqual(AdmissionDecision.reject, admissionDecision(.worker_led_research, .union_activity_monitoring));
    try std.testing.expectEqual(AdmissionDecision.reject, admissionDecision(.collective_bargaining_evidence, .industrial_action_monitoring));
    try std.testing.expectEqual(AdmissionDecision.quarantine, admissionDecision(.worker_led_research, .voluntary_field_evidence));
}

test "frame bound has passing and failing controls" {
    try std.testing.expect(payloadInBounds(1024 * 1024));
    try std.testing.expect(!payloadInBounds(1024 * 1024 + 1));
}

test "unsupported protocol remains explicit" {
    try std.testing.expectError(ProjectionError.UnsupportedProtocol, project(.mcp, .query_signals));
}
