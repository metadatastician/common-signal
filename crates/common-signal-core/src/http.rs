// SPDX-License-Identifier: MPL-2.0
//! Read-only HTTP projection over the canonical synthetic query.

use std::fmt::Write as _;

use crate::governance::{
    ConsultationStage, GOVERNANCE_STATUS_JSON, ParticipationRoute, ProfessionalContext,
};
use crate::{
    Direction, EmploymentRelationship, LabourImpact, OccupationalGroup, SignalQuery, SignalRecord,
    query_signals,
};

/// Result of routing one HTTP request.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct HttpResponse {
    /// HTTP status code.
    pub status: u16,
    /// Response content type.
    pub content_type: &'static str,
    /// Complete response body.
    pub body: String,
}

impl HttpResponse {
    /// Encode the response as HTTP/1.1 bytes with defensive headers.
    #[must_use]
    pub fn to_http1(&self) -> Vec<u8> {
        let reason = match self.status {
            200 => "OK",
            400 => "Bad Request",
            404 => "Not Found",
            405 => "Method Not Allowed",
            _ => "Error",
        };
        let headers = format!(
            "HTTP/1.1 {} {}\r\nContent-Type: {}\r\nContent-Length: {}\r\nContent-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'\r\nReferrer-Policy: no-referrer\r\nX-Content-Type-Options: nosniff\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n",
            self.status,
            reason,
            self.content_type,
            self.body.len()
        );
        let mut encoded = headers.into_bytes();
        encoded.extend_from_slice(self.body.as_bytes());
        encoded
    }
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
struct ParsedQuery {
    query: SignalQuery,
    has_parameters: bool,
}

fn parse_query(target: &str) -> Result<(&str, ParsedQuery), &'static str> {
    let (path, raw_query) = target.split_once('?').unwrap_or((target, ""));
    let mut parsed = ParsedQuery::default();
    for parameter in raw_query.split('&').filter(|part| !part.is_empty()) {
        parsed.has_parameters = true;
        let (key, value) = parameter
            .split_once('=')
            .ok_or("query parameters must use key=value")?;
        match key {
            "occupation" => {
                if value.is_empty() {
                    continue;
                }
                parsed.query.occupation = Some(match value {
                    "journalism" => OccupationalGroup::Journalism,
                    "public-relations" => OccupationalGroup::PublicRelations,
                    "communications" => OccupationalGroup::Communications,
                    "cross-media" => OccupationalGroup::CrossMedia,
                    _ => return Err("unknown occupation filter"),
                });
            }
            "impact" => {
                if value.is_empty() {
                    continue;
                }
                parsed.query.impact = Some(match value {
                    "workload" => LabourImpact::Workload,
                    "editorial-independence" => LabourImpact::EditorialIndependence,
                    "worker-control" => LabourImpact::WorkerControl,
                    "collective-bargaining" => LabourImpact::CollectiveBargaining,
                    "surveillance" => LabourImpact::Surveillance,
                    "attribution" => LabourImpact::Attribution,
                    "skills" => LabourImpact::Skills,
                    "plurality" => LabourImpact::Plurality,
                    _ => return Err("unknown impact filter"),
                });
            }
            _ => return Err("unknown query parameter"),
        }
    }
    Ok((path, parsed))
}

/// Route one read-only request without opening a socket.
#[must_use]
pub fn route(method: &str, target: &str) -> HttpResponse {
    if method != "GET" && method != "HEAD" {
        return problem(
            405,
            "read_only",
            "Common Signal currently accepts GET and HEAD only.",
        );
    }
    let Ok((path, parsed)) = parse_query(target) else {
        return problem(
            400,
            "invalid_query",
            "The supplied filter is not part of the canonical query algebra.",
        );
    };
    let response = match path {
        "/" => html_response(parsed.query),
        "/v1/signals" => json_response(parsed.query),
        "/governance" if !parsed.has_parameters => governance_html_response(),
        "/v1/governance" if !parsed.has_parameters => governance_json_response(),
        "/governance" | "/v1/governance" => problem(
            400,
            "invalid_query",
            "The governance status routes do not accept query parameters.",
        ),
        "/health" => HttpResponse {
            status: 200,
            content_type: "application/json; charset=utf-8",
            body:
                "{\"status\":\"ok\",\"mode\":\"synthetic-read-only\",\"schemaVersion\":\"1.0.0\"}"
                    .to_owned(),
        },
        _ => problem(404, "not_found", "No read-only route exists at this path."),
    };
    if method == "HEAD" {
        HttpResponse {
            body: String::new(),
            ..response
        }
    } else {
        response
    }
}

fn problem(status: u16, code: &str, message: &str) -> HttpResponse {
    HttpResponse {
        status,
        content_type: "application/problem+json; charset=utf-8",
        body: format!(
            "{{\"type\":\"urn:common-signal:problem:{code}\",\"title\":\"{}\",\"status\":{status}}}",
            json_escape(message)
        ),
    }
}

fn json_response(query: SignalQuery) -> HttpResponse {
    let signals = query_signals(query);
    let mut body = String::from(
        "{\"schemaVersion\":\"1.0.0\",\"mode\":\"synthetic-read-only\",\"warnings\":[\"Synthetic fixtures\",\"No population inference\",\"Not an employee scoring service\"],\"data\":[",
    );
    for (index, signal) in signals.iter().enumerate() {
        if index > 0 {
            body.push(',');
        }
        write_json_signal(&mut body, signal);
    }
    let _ = write!(body, "],\"count\":{}}}", signals.len());
    HttpResponse {
        status: 200,
        content_type: "application/json; charset=utf-8",
        body,
    }
}

fn governance_json_response() -> HttpResponse {
    HttpResponse {
        status: 200,
        content_type: "application/json; charset=utf-8",
        body: GOVERNANCE_STATUS_JSON.trim().to_owned(),
    }
}

fn governance_html_response() -> HttpResponse {
    let status = html_escape(GOVERNANCE_STATUS_JSON.trim());
    let body = format!(
        "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>Common Signal — governance authority</title><style>body{{font:1rem/1.6 system-ui,sans-serif;max-width:62rem;margin:auto;padding:1rem;color:#172026;background:#f6f4ee}}main,aside{{background:#fffdf8;padding:1rem;margin-block:1rem;border:1px solid #d7d5cd}}pre{{white-space:pre-wrap;overflow-wrap:anywhere;background:#edf1f2;padding:1rem;border-left:.35rem solid #0067c5}}:focus-visible{{outline:.2rem solid #0067c5;outline-offset:.15rem}}</style></head><body><a href=\"#main\">Skip to main content</a><header><h1>Governance authority</h1><p><a href=\"/\">Common Signal home</a></p></header><aside aria-labelledby=\"meaning\"><h2 id=\"meaning\">How to read this status</h2><p>A prepared review pack, invitation, meeting, or individual opinion is not collective ratification. Project maintainers cannot issue worker, workplace, NUJ, or trade-union authority.</p></aside><main id=\"main\"><h2>Current machine-readable record</h2><pre aria-label=\"Current governance status as JSON\">{status}</pre><p><a href=\"/v1/governance\">Retrieve the canonical JSON record</a>.</p><h2>Review materials</h2><p>The repository contains a co-design protocol, invitation template, review form, change-and-dissent matrix, and versioned session, review, status, and ratification schemas. No document alone authorises live collection.</p></main><footer><p>No NUJ or trade-union endorsement is implied.</p></footer></body></html>"
    );
    HttpResponse {
        status: 200,
        content_type: "text/html; charset=utf-8",
        body,
    }
}

fn write_json_signal(body: &mut String, signal: &SignalRecord) {
    let worker_body = signal.consultation.worker_body.map_or_else(
        || "null".to_owned(),
        |value| format!("\"{}\"", json_escape(value)),
    );
    let evidence_reference = signal.consultation.evidence_reference.map_or_else(
        || "null".to_owned(),
        |value| format!("\"{}\"", json_escape(value)),
    );
    let unresolved = json_string_array(signal.consultation.unresolved);
    let _ = write!(
        body,
        "{{\"id\":\"{}\",\"occupation\":\"{}\",\"professionalContext\":\"{}\",\"employment\":\"{}\",\"impact\":\"{}\",\"direction\":\"{}\",\"claim\":\"{}\",\"evidence\":{{\"sourceClass\":\"{}\",\"unit\":\"{}\",\"inferenceBoundary\":\"{}\",\"workerConsent\":{},\"collectiveGovernance\":{},\"synthetic\":{}}},\"consultation\":{{\"stage\":\"{}\",\"participation\":\"{}\",\"workerBody\":{},\"scope\":\"{}\",\"evidenceReference\":{},\"unresolved\":{}}}}}",
        json_escape(signal.id),
        occupation_name(signal.occupation),
        context_name(signal.professional_context),
        employment_name(signal.employment),
        impact_name(signal.impact),
        direction_name(signal.direction),
        json_escape(signal.claim),
        json_escape(signal.evidence.source_class),
        json_escape(signal.evidence.unit),
        json_escape(signal.evidence.inference_boundary),
        signal.evidence.worker_consent,
        signal.evidence.collective_governance,
        signal.evidence.synthetic,
        consultation_name(signal.consultation.stage),
        participation_name(signal.consultation.participation),
        worker_body,
        json_escape(signal.consultation.scope),
        evidence_reference,
        unresolved,
    );
}

fn json_string_array(values: &[&str]) -> String {
    let mut encoded = String::from("[");
    for (index, value) in values.iter().enumerate() {
        if index > 0 {
            encoded.push(',');
        }
        let _ = write!(encoded, "\"{}\"", json_escape(value));
    }
    encoded.push(']');
    encoded
}

fn html_response(query: SignalQuery) -> HttpResponse {
    let signals = query_signals(query);
    let mut rows = String::new();
    for signal in &signals {
        let _ = write!(
            rows,
            "<tr><th scope=\"row\">{}</th><td>{}</td><td>{}</td><td>{}</td><td>{}</td><td>{}</td></tr>",
            html_escape(signal.id),
            html_escape(occupation_name(signal.occupation)),
            html_escape(impact_name(signal.impact)),
            html_escape(signal.claim),
            html_escape(consultation_name(signal.consultation.stage)),
            html_escape(signal.evidence.inference_boundary),
        );
    }
    let body = format!(
        "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>Common Signal — synthetic worker-centred signals</title><style>body{{font:1rem/1.55 system-ui,sans-serif;max-width:76rem;margin:auto;padding:1rem;color:#172026;background:#f6f4ee}}main,aside{{background:#fffdf8;padding:1rem;margin-block:1rem;border:1px solid #d7d5cd}}label{{display:inline-block;margin:.4rem}}select,button{{font:inherit;padding:.45rem}}table{{border-collapse:collapse;width:100%}}th,td{{border:1px solid #aab3b6;padding:.55rem;text-align:left;vertical-align:top}}caption{{font-weight:700;text-align:left;margin-block:.5rem}}:focus-visible{{outline:.2rem solid #0067c5;outline-offset:.15rem}}@media(max-width:55rem){{table{{display:block;overflow-x:auto}}}}</style></head><body><a href=\"#main\">Skip to main content</a><header><h1>Common Signal</h1><p>Worker-centred evidence about AI in journalism, PR, communications, and media work.</p><p><a href=\"/governance\">Check the current governance authority</a>.</p></header><aside aria-labelledby=\"boundary\"><h2 id=\"boundary\">Prototype boundary</h2><p><strong>Synthetic, read-only, and non-predictive.</strong> These records describe no real worker, workplace, union, organisation, or population. Common Signal is not an employee-scoring or workforce-sentiment service.</p></aside><main id=\"main\"><h2>Explore synthetic signals</h2><form method=\"get\" action=\"/\"><label>Occupation <select name=\"occupation\"><option value=\"\">All</option><option value=\"journalism\">Journalism</option><option value=\"public-relations\">Public relations</option><option value=\"communications\">Communications</option><option value=\"cross-media\">Cross-media</option></select></label><label>Impact <select name=\"impact\"><option value=\"\">All</option><option value=\"workload\">Workload</option><option value=\"editorial-independence\">Editorial independence</option><option value=\"worker-control\">Worker control</option><option value=\"collective-bargaining\">Collective bargaining</option><option value=\"surveillance\">Surveillance</option><option value=\"attribution\">Attribution</option><option value=\"skills\">Skills</option><option value=\"plurality\">Plurality</option></select></label><button type=\"submit\">Apply filters</button></form><p aria-live=\"polite\">{} synthetic signal(s).</p><table><caption>Signals and evidence boundaries</caption><thead><tr><th>Record</th><th>Occupation</th><th>Impact</th><th>Claim</th><th>Consultation stage</th><th>Inference boundary</th></tr></thead><tbody>{rows}</tbody></table><p><a href=\"/v1/signals\">View the canonical JSON response</a></p></main><footer><p>Code: MPL-2.0 · Documentation: CC-BY-SA-4.0 · No NUJ or union endorsement is implied.</p></footer></body></html>",
        signals.len()
    );
    HttpResponse {
        status: 200,
        content_type: "text/html; charset=utf-8",
        body,
    }
}

fn occupation_name(value: OccupationalGroup) -> &'static str {
    match value {
        OccupationalGroup::Journalism => "journalism",
        OccupationalGroup::PublicRelations => "public-relations",
        OccupationalGroup::Communications => "communications",
        OccupationalGroup::CrossMedia => "cross-media",
    }
}

fn context_name(value: ProfessionalContext) -> &'static str {
    match value {
        ProfessionalContext::Journalism => "journalism",
        ProfessionalContext::PublicRelations => "public-relations",
        ProfessionalContext::Communications => "communications",
        ProfessionalContext::CrossMedia => "cross-media",
    }
}

fn employment_name(value: EmploymentRelationship) -> &'static str {
    match value {
        EmploymentRelationship::Employee => "employee",
        EmploymentRelationship::Freelance => "freelance",
        EmploymentRelationship::Contracted => "contracted",
        EmploymentRelationship::MixedOrUnknown => "mixed-or-unknown",
    }
}

fn impact_name(value: LabourImpact) -> &'static str {
    match value {
        LabourImpact::Workload => "workload",
        LabourImpact::EditorialIndependence => "editorial-independence",
        LabourImpact::WorkerControl => "worker-control",
        LabourImpact::CollectiveBargaining => "collective-bargaining",
        LabourImpact::Surveillance => "surveillance",
        LabourImpact::Attribution => "attribution",
        LabourImpact::Skills => "skills",
        LabourImpact::Plurality => "plurality",
    }
}

fn direction_name(value: Direction) -> &'static str {
    match value {
        Direction::Improved => "improved",
        Direction::Worsened => "worsened",
        Direction::Mixed => "mixed",
        Direction::Unknown => "unknown",
    }
}

fn consultation_name(value: ConsultationStage) -> &'static str {
    match value {
        ConsultationStage::NotRecorded => "not-recorded",
        ConsultationStage::Proposed => "proposed",
        ConsultationStage::InformationShared => "information-shared",
        ConsultationStage::ConsultationOpen => "consultation-open",
        ConsultationStage::Negotiation => "negotiation",
        ConsultationStage::AgreementReached => "agreement-reached",
        ConsultationStage::Disputed => "disputed",
        ConsultationStage::ReviewDue => "review-due",
    }
}

fn participation_name(value: ParticipationRoute) -> &'static str {
    match value {
        ParticipationRoute::NotRecorded => "not-recorded",
        ParticipationRoute::Direct => "direct",
        ParticipationRoute::RecognisedUnion => "recognised-union",
        ParticipationRoute::ElectedWorkerBody => "elected-worker-body",
        ParticipationRoute::Mixed => "mixed",
    }
}

fn json_escape(value: &str) -> String {
    value
        .chars()
        .flat_map(|character| match character {
            '"' => "\\\"".chars().collect::<Vec<_>>(),
            '\\' => "\\\\".chars().collect(),
            '\n' => "\\n".chars().collect(),
            '\r' => "\\r".chars().collect(),
            '\t' => "\\t".chars().collect(),
            other if other.is_control() => "�".chars().collect(),
            other => vec![other],
        })
        .collect()
}

fn html_escape(value: &str) -> String {
    value
        .replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&#39;")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rest_filter_uses_canonical_query() {
        let response = route("GET", "/v1/signals?occupation=journalism&impact=workload");
        assert_eq!(response.status, 200);
        assert!(response.body.contains("synthetic-workload-001"));
        assert!(!response.body.contains("synthetic-control-001"));
        assert!(response.body.contains("\"count\":1"));
    }

    #[test]
    fn server_rendered_page_has_landmarks_and_boundary() {
        let response = route("GET", "/");
        assert_eq!(response.content_type, "text/html; charset=utf-8");
        assert!(response.body.contains("<main id=\"main\">"));
        assert!(
            response
                .body
                .contains("Synthetic, read-only, and non-predictive.")
        );
        assert!(
            response
                .body
                .contains("No NUJ or union endorsement is implied.")
        );
    }

    #[test]
    fn governance_api_exposes_canonical_non_authority() {
        let response = route("GET", "/v1/governance");
        assert_eq!(response.status, 200);
        assert_eq!(response.body, GOVERNANCE_STATUS_JSON.trim());
        assert!(
            response
                .body
                .contains("\"status\": \"draft-not-consulted\"")
        );
        assert!(response.body.contains("\"liveConnectorsGate\": \"closed\""));
    }

    #[test]
    fn governance_page_preserves_accessibility_and_authority_boundary() {
        let response = route("GET", "/governance");
        assert_eq!(response.status, 200);
        assert!(response.body.contains("<main id=\"main\">"));
        assert!(response.body.contains("draft-not-consulted"));
        assert!(
            response
                .body
                .contains("cannot issue worker, workplace, NUJ")
        );
        assert!(response.body.contains("No NUJ or trade-union endorsement"));
    }

    #[test]
    fn governance_routes_reject_query_parameters() {
        let response = route("GET", "/v1/governance?occupation=journalism");
        assert_eq!(response.status, 400);
        assert!(response.body.contains("invalid_query"));
    }

    #[test]
    fn positive_control_rejects_unknown_filters() {
        let response = route("GET", "/v1/signals?worker=alice");
        assert_eq!(response.status, 400);
        assert!(response.body.contains("invalid_query"));
    }

    #[test]
    fn form_all_values_map_to_unfiltered_query() {
        let response = route("GET", "/?occupation=&impact=");
        assert_eq!(response.status, 200);
        assert!(response.body.contains("3 synthetic signal(s)."));
    }

    #[test]
    fn consultation_json_includes_unresolved_matters() {
        let response = route("GET", "/v1/signals?occupation=journalism");
        assert!(response.body.contains("\"unresolved\":["));
        assert!(response.body.contains("staffing consequences"));
    }

    #[test]
    fn positive_control_rejects_mutation_methods() {
        let response = route("POST", "/v1/signals");
        assert_eq!(response.status, 405);
        assert!(response.body.contains("read_only"));
    }

    #[test]
    fn response_carries_defensive_headers() {
        let encoded = String::from_utf8(route("GET", "/health").to_http1())
            .expect("ASCII and UTF-8 response");
        assert!(encoded.contains("Content-Security-Policy:"));
        assert!(encoded.contains("Cache-Control: no-store"));
    }
}
