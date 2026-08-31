// SPDX-License-Identifier: MPL-2.0
//! Canonical, protocol-neutral domain model for Common Signal.
//!
//! The model treats labour conditions and collective voice as first-class
//! evidence dimensions. It does not infer the views of workers, unions, or the
//! public from sampled expressions.

pub mod governance;
pub mod http;

use governance::{ConsultationRecord, ConsultationStage, ParticipationRoute, ProfessionalContext};

/// Media-industry occupational groups represented by a signal.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(u8)]
pub enum OccupationalGroup {
    /// Journalists, reporters, editors, photographers, and production staff.
    Journalism = 1,
    /// Public-relations practitioners.
    PublicRelations = 2,
    /// Communications practitioners outside narrowly defined PR roles.
    Communications = 3,
    /// Workers spanning several media occupations.
    CrossMedia = 4,
}

/// Employment relationship relevant to power and remedy.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(u8)]
pub enum EmploymentRelationship {
    /// Direct employee.
    Employee = 1,
    /// Freelance or self-employed worker.
    Freelance = 2,
    /// Agency, outsourced, or contracted worker.
    Contracted = 3,
    /// Mixed or undisclosed relationship.
    MixedOrUnknown = 4,
}

/// Worker-centred impact dimensions.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(u8)]
pub enum LabourImpact {
    /// Total work and work intensification, including displaced checking work.
    Workload = 1,
    /// Editorial or professional independence.
    EditorialIndependence = 2,
    /// Discretion over tools, pace, process, and refusal.
    WorkerControl = 3,
    /// Collective consultation, negotiation, and bargaining power.
    CollectiveBargaining = 4,
    /// Monitoring, scoring, tracking, or performance management.
    Surveillance = 5,
    /// Credit, bylines, authorship, and responsibility.
    Attribution = 6,
    /// Skill formation, deskilling, reskilling, and professional judgement.
    Skills = 7,
    /// Source diversity, framing plurality, and whose voices travel.
    Plurality = 8,
}

/// Direction of an observed or claimed effect.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Direction {
    /// Conditions or public-interest outcomes improved.
    Improved,
    /// Conditions or public-interest outcomes worsened.
    Worsened,
    /// Effects moved in more than one direction.
    Mixed,
    /// Available evidence cannot establish direction.
    Unknown,
}

/// Evidence carried with every signal.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct EvidencePassport {
    /// Kind of evidence, kept distinct rather than collapsed into one score.
    pub source_class: &'static str,
    /// Unit actually observed.
    pub unit: &'static str,
    /// Boundary beyond which the record must not be inferred.
    pub inference_boundary: &'static str,
    /// Whether affected workers consented to this evidential use.
    pub worker_consent: bool,
    /// Whether a collective worker body participated in governance.
    pub collective_governance: bool,
    /// Whether the record is synthetic rather than an observation of people.
    pub synthetic: bool,
}

/// A protocol-neutral signal about AI and communicative work.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct SignalRecord {
    /// Stable record identifier.
    pub id: &'static str,
    /// Occupational context.
    pub occupation: OccupationalGroup,
    /// Employment context.
    pub employment: EmploymentRelationship,
    /// Professional context, kept separate from occupational group for
    /// cross-organisational workflows.
    pub professional_context: ProfessionalContext,
    /// Labour or public-interest dimension affected.
    pub impact: LabourImpact,
    /// Direction of the effect within the evidence boundary.
    pub direction: Direction,
    /// Short claim written without population inference.
    pub claim: &'static str,
    /// Evidence and limitations travelling with the claim.
    pub evidence: EvidencePassport,
    /// Inspectable worker information, consultation, and negotiation record.
    pub consultation: ConsultationRecord,
}

/// Filters for the canonical query algebra.
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct SignalQuery {
    /// Optional occupational filter.
    pub occupation: Option<OccupationalGroup>,
    /// Optional labour-impact filter.
    pub impact: Option<LabourImpact>,
}

/// Synthetic fixtures inherited conceptually from the design prototype.
///
/// They prove query behavior only. They are not evidence about real workplaces.
pub const SYNTHETIC_SIGNALS: &[SignalRecord] = &[
    SignalRecord {
        id: "synthetic-workload-001",
        occupation: OccupationalGroup::Journalism,
        employment: EmploymentRelationship::Employee,
        professional_context: ProfessionalContext::Journalism,
        impact: LabourImpact::Workload,
        direction: Direction::Worsened,
        claim: "Checking, correction, and coordination exceeded first-draft time saved.",
        evidence: EvidencePassport {
            source_class: "synthetic workflow diary",
            unit: "illustrative workflow episode",
            inference_boundary: "Cannot estimate prevalence or effects in any real newsroom.",
            worker_consent: true,
            collective_governance: false,
            synthetic: true,
        },
        consultation: ConsultationRecord {
            stage: ConsultationStage::ConsultationOpen,
            participation: ParticipationRoute::RecognisedUnion,
            worker_body: Some("synthetic recognised union chapel"),
            scope: "illustrative workflow and workload assessment",
            evidence_reference: Some("synthetic-consultation-001"),
            unresolved: &["staffing consequences", "review threshold governance"],
        },
    },
    SignalRecord {
        id: "synthetic-control-001",
        occupation: OccupationalGroup::PublicRelations,
        employment: EmploymentRelationship::Contracted,
        professional_context: ProfessionalContext::PublicRelations,
        impact: LabourImpact::WorkerControl,
        direction: Direction::Mixed,
        claim: "Faster production coincided with less discretion over ranking and review thresholds.",
        evidence: EvidencePassport {
            source_class: "synthetic work-system trace",
            unit: "illustrative production workflow",
            inference_boundary: "Describes a scenario, not a PR workplace or workforce.",
            worker_consent: true,
            collective_governance: false,
            synthetic: true,
        },
        consultation: ConsultationRecord {
            stage: ConsultationStage::InformationShared,
            participation: ParticipationRoute::Direct,
            worker_body: None,
            scope: "illustrative production tooling change",
            evidence_reference: Some("synthetic-consultation-002"),
            unresolved: &["contractor voice", "availability expectations"],
        },
    },
    SignalRecord {
        id: "synthetic-bargaining-001",
        occupation: OccupationalGroup::CrossMedia,
        employment: EmploymentRelationship::MixedOrUnknown,
        professional_context: ProfessionalContext::CrossMedia,
        impact: LabourImpact::CollectiveBargaining,
        direction: Direction::Unknown,
        claim: "No collective consultation evidence was supplied with the deployment record.",
        evidence: EvidencePassport {
            source_class: "synthetic deployment register",
            unit: "illustrative technology deployment",
            inference_boundary: "Absence in the record does not prove consultation did not occur.",
            worker_consent: false,
            collective_governance: false,
            synthetic: true,
        },
        consultation: ConsultationRecord {
            stage: ConsultationStage::NotRecorded,
            participation: ParticipationRoute::NotRecorded,
            worker_body: None,
            scope: "not supplied in the synthetic deployment record",
            evidence_reference: None,
            unresolved: &["whether consultation occurred"],
        },
    },
];

/// Return signals satisfying every supplied filter.
#[must_use]
pub fn query_signals(query: SignalQuery) -> Vec<&'static SignalRecord> {
    SYNTHETIC_SIGNALS
        .iter()
        .filter(|signal| {
            query
                .occupation
                .is_none_or(|value| signal.occupation == value)
        })
        .filter(|signal| query.impact.is_none_or(|value| signal.impact == value))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn filters_on_worker_impact() {
        let result = query_signals(SignalQuery {
            occupation: None,
            impact: Some(LabourImpact::CollectiveBargaining),
        });
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].id, "synthetic-bargaining-001");
    }

    #[test]
    fn fixtures_cannot_masquerade_as_real_observations() {
        assert!(SYNTHETIC_SIGNALS.iter().all(|item| item.evidence.synthetic));
    }
}
