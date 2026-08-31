// SPDX-License-Identifier: MPL-2.0
//! Worker-governance, collective-consultation, and prohibited-use contracts.

/// Machine-readable policy embedded at compile time so packaging cannot omit it.
pub const PROHIBITED_USE_POLICY_JSON: &str = include_str!("../../../policies/prohibited-uses.json");

/// Public authority state embedded from the repository's canonical machine
/// record. Packaging therefore cannot silently replace “not consulted” with a
/// more permissive runtime default.
pub const GOVERNANCE_STATUS_JSON: &str =
    include_str!("../../../.machine_readable/governance/STATUS.json");

/// Distinct professional settings within the media industries.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(u8)]
pub enum ProfessionalContext {
    /// Journalism and editorial production.
    Journalism = 1,
    /// Public relations and reputation work.
    PublicRelations = 2,
    /// Organisational, civic, political, or public communications.
    Communications = 3,
    /// A workflow spanning more than one professional setting.
    CrossMedia = 4,
}

/// Context-specific duties and risks that must not be collapsed into one score.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct ContextProfile {
    /// Professional setting.
    pub context: ProfessionalContext,
    /// Duties or public-interest commitments relevant to interpretation.
    pub duties: &'static [&'static str],
    /// Worker risks requiring explicit attention.
    pub worker_risks: &'static [&'static str],
}

/// Canonical professional profiles used by schemas and interfaces.
pub const CONTEXT_PROFILES: &[ContextProfile] = &[
    ContextProfile {
        context: ProfessionalContext::Journalism,
        duties: &[
            "editorial independence",
            "source protection",
            "verification and correction",
            "plurality and public accountability",
        ],
        worker_risks: &[
            "legal and ethical liability without effective control",
            "source exposure",
            "verification burden displacement",
            "deskilling and loss of editorial discretion",
        ],
    },
    ContextProfile {
        context: ProfessionalContext::PublicRelations,
        duties: &[
            "truthful and attributable communication",
            "professional judgement",
            "client and public accountability",
            "clear authorship and approval",
        ],
        worker_risks: &[
            "volume and availability intensification",
            "automated reputation monitoring",
            "liability without authorship control",
            "client surveillance and uncompensated revision work",
        ],
    },
    ContextProfile {
        context: ProfessionalContext::Communications,
        duties: &[
            "accessible and accurate communication",
            "public or organisational accountability",
            "audience inclusion",
            "professional independence",
        ],
        worker_risks: &[
            "centralised message control",
            "monitoring of staff and audiences",
            "emergency workload escalation",
            "loss of local and specialist knowledge",
        ],
    },
    ContextProfile {
        context: ProfessionalContext::CrossMedia,
        duties: &[
            "preserve context-specific professional duties",
            "make hand-offs and accountability visible",
        ],
        worker_risks: &[
            "responsibility falling between organisations",
            "one sector's metrics being imposed on another",
        ],
    },
];

/// Stages of collective information, consultation, negotiation, and review.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(u8)]
pub enum ConsultationStage {
    /// The available record does not say whether consultation occurred.
    NotRecorded = 1,
    /// A technology or work-system change has been proposed.
    Proposed = 2,
    /// Workers or representatives have received relevant information.
    InformationShared = 3,
    /// Consultation is open and the outcome is not predetermined.
    ConsultationOpen = 4,
    /// Collective negotiation is taking place.
    Negotiation = 5,
    /// A collective agreement has been recorded.
    AgreementReached = 6,
    /// The process or outcome is disputed.
    Disputed = 7,
    /// A previously agreed deployment is due for collective review.
    ReviewDue = 8,
}

/// How workers participate in governance.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(u8)]
pub enum ParticipationRoute {
    /// No participation route appears in the evidence.
    NotRecorded = 1,
    /// Direct individual consultation.
    Direct = 2,
    /// A recognised trade union represents affected workers.
    RecognisedUnion = 3,
    /// An elected workplace or staff body represents affected workers.
    ElectedWorkerBody = 4,
    /// More than one route is in use.
    Mixed = 5,
}

/// Inspectable record of worker information, consultation, and negotiation.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct ConsultationRecord {
    /// Current stage; `NotRecorded` is not evidence that consultation did not occur.
    pub stage: ConsultationStage,
    /// Participation route evidenced by the record.
    pub participation: ParticipationRoute,
    /// Named worker body when disclosure and consent permit it.
    pub worker_body: Option<&'static str>,
    /// Scope supplied to affected workers or their representatives.
    pub scope: &'static str,
    /// Evidence reference, not the evidence itself.
    pub evidence_reference: Option<&'static str>,
    /// Matters still unresolved or expressly reserved.
    pub unresolved: &'static [&'static str],
}

/// Status of a challenge to a claim, record, classification, or data use.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(u8)]
pub enum ChallengeStatus {
    /// A challenge was received.
    Submitted = 1,
    /// Evidence and authority are under review.
    UnderReview = 2,
    /// The challenged material was corrected.
    Corrected = 3,
    /// The challenge was upheld and use stopped or removed.
    Upheld = 4,
    /// The challenge was rejected with reasons and an appeal route.
    RejectedWithReasons = 5,
    /// The challenge remains unresolved.
    Unresolved = 6,
}

/// Collective or individual remedy attached to a challenge.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct ChallengeRecord {
    /// Non-identifying challenge reference.
    pub reference: &'static str,
    /// Current state.
    pub status: ChallengeStatus,
    /// Whether the challenger has collective representation.
    pub collectively_represented: bool,
    /// Remedy or next review step.
    pub remedy: &'static str,
}

/// Permitted high-level purposes. A permitted purpose does not override a
/// prohibited processing characteristic.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(u8)]
pub enum PermittedPurpose {
    /// Public-interest research with declared inference boundaries.
    PublicInterestResearch = 1,
    /// Worker-led research or workplace assessment.
    WorkerLedResearch = 2,
    /// Evidence prepared for consultation or collective bargaining.
    CollectiveBargainingEvidence = 3,
    /// Public accountability reporting using appropriately governed evidence.
    PublicAccountability = 4,
}

/// Uses that Common Signal must reject regardless of requester.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(u8)]
pub enum ProhibitedUse {
    /// Ranking or scoring an identifiable worker's performance.
    IndividualPerformanceScoring = 1,
    /// Disciplinary or dismissal decision support.
    DisciplineOrDismissal = 2,
    /// Identifying or monitoring union membership or activity.
    UnionSurveillance = 3,
    /// Monitoring industrial action or preparations for it.
    StrikeMonitoring = 4,
    /// Inferring the sentiment or legitimacy of a workforce or union.
    WorkforceSentimentInference = 5,
    /// Making an editorial or professional decision without accountable review.
    AutomatedEditorialDecision = 6,
}

/// Auditable characteristics of a proposed data use.
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct UseCharacteristics(u8);

impl UseCharacteristics {
    /// No prohibited characteristic is present.
    pub const NONE: Self = Self(0);
    /// An identifiable worker is evaluated or ranked.
    pub const EVALUATES_INDIVIDUAL: Self = Self(1 << 0);
    /// Employment discipline or dismissal could result.
    pub const DISCIPLINARY_CONSEQUENCE: Self = Self(1 << 1);
    /// Union membership or activity is identified or monitored.
    pub const MONITORS_UNION_ACTIVITY: Self = Self(1 << 2);
    /// Industrial action is identified or monitored.
    pub const MONITORS_INDUSTRIAL_ACTION: Self = Self(1 << 3);
    /// Workforce or union sentiment is inferred.
    pub const INFERS_COLLECTIVE_SENTIMENT: Self = Self(1 << 4);
    /// An editorial/professional decision is made without accountable review.
    pub const UNREVIEWED_AUTOMATED_DECISION: Self = Self(1 << 5);

    /// Combine independently declared characteristics for policy review.
    #[must_use]
    pub const fn union(self, other: Self) -> Self {
        Self(self.0 | other.0)
    }

    const fn contains(self, other: Self) -> bool {
        self.0 & other.0 != 0
    }
}

/// Characteristics and declared purpose of a proposed data use.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct UseRequest {
    /// Declared high-level purpose.
    pub purpose: PermittedPurpose,
    /// Independently reviewable processing characteristics.
    pub characteristics: UseCharacteristics,
}

/// Reject prohibited uses. The first returned reason is deterministic; callers
/// should still present all applicable policy rules in user-facing review.
///
/// # Errors
///
/// Returns the first applicable [`ProhibitedUse`] when any prohibited
/// processing characteristic is present. No declared purpose overrides it.
pub const fn validate_use(request: UseRequest) -> Result<(), ProhibitedUse> {
    if request
        .characteristics
        .contains(UseCharacteristics::EVALUATES_INDIVIDUAL)
    {
        return Err(ProhibitedUse::IndividualPerformanceScoring);
    }
    if request
        .characteristics
        .contains(UseCharacteristics::DISCIPLINARY_CONSEQUENCE)
    {
        return Err(ProhibitedUse::DisciplineOrDismissal);
    }
    if request
        .characteristics
        .contains(UseCharacteristics::MONITORS_UNION_ACTIVITY)
    {
        return Err(ProhibitedUse::UnionSurveillance);
    }
    if request
        .characteristics
        .contains(UseCharacteristics::MONITORS_INDUSTRIAL_ACTION)
    {
        return Err(ProhibitedUse::StrikeMonitoring);
    }
    if request
        .characteristics
        .contains(UseCharacteristics::INFERS_COLLECTIVE_SENTIMENT)
    {
        return Err(ProhibitedUse::WorkforceSentimentInference);
    }
    if request
        .characteristics
        .contains(UseCharacteristics::UNREVIEWED_AUTOMATED_DECISION)
    {
        return Err(ProhibitedUse::AutomatedEditorialDecision);
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn permitted_request() -> UseRequest {
        UseRequest {
            purpose: PermittedPurpose::CollectiveBargainingEvidence,
            characteristics: UseCharacteristics::NONE,
        }
    }

    #[test]
    fn collective_bargaining_evidence_is_permitted() {
        assert_eq!(validate_use(permitted_request()), Ok(()));
    }

    #[test]
    fn positive_control_rejects_union_surveillance() {
        let request = UseRequest {
            characteristics: UseCharacteristics::MONITORS_UNION_ACTIVITY,
            ..permitted_request()
        };
        assert_eq!(validate_use(request), Err(ProhibitedUse::UnionSurveillance));
    }

    #[test]
    fn contexts_remain_distinct() {
        assert_eq!(CONTEXT_PROFILES.len(), 4);
        assert_ne!(CONTEXT_PROFILES[0].duties, CONTEXT_PROFILES[1].duties);
    }

    #[test]
    fn executable_rules_remain_named_in_machine_policy() {
        for code in [
            "individual-performance-scoring",
            "discipline-or-dismissal",
            "union-surveillance",
            "strike-monitoring",
            "workforce-sentiment-inference",
            "automated-editorial-decision",
        ] {
            assert!(PROHIBITED_USE_POLICY_JSON.contains(code), "missing {code}");
        }
        assert!(PROHIBITED_USE_POLICY_JSON.contains("\"override\": \"none\""));
    }

    #[test]
    fn embedded_governance_status_cannot_claim_unrecorded_authority() {
        assert!(GOVERNANCE_STATUS_JSON.contains("\"status\": \"draft-not-consulted\""));
        assert!(GOVERNANCE_STATUS_JSON.contains("\"authority\": \"project-draft-only\""));
        assert!(GOVERNANCE_STATUS_JSON.contains("\"consultationSessions\": 0"));
        assert!(GOVERNANCE_STATUS_JSON.contains("\"ratificationRecords\": 0"));
        assert!(GOVERNANCE_STATUS_JSON.contains("\"liveConnectorsGate\": \"closed\""));
    }
}
