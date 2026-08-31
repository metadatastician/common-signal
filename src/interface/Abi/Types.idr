-- SPDX-License-Identifier: MPL-2.0
||| Authoritative Common Signal boundary vocabulary.
|||
||| This is a language-neutral wire/API contract implemented natively by Zig.
||| It is deliberately not a C memory-layout specification.
module Abi.Types

import Data.Bits
import Data.Vect

%default total

public export
data ProtocolSlot
  = Rest | GraphQL | GRPC | MCP | JsonRPC | WebSocket | ServerSentEvents
  | MessagePackRPC | CapNProto | Thrift | SOAP | OData | ActivityPub
  | NATS | AMQP | Kafka

public export
protocolSlots : Vect 16 ProtocolSlot
protocolSlots =
  [ Rest, GraphQL, GRPC, MCP, JsonRPC, WebSocket, ServerSentEvents
  , MessagePackRPC, CapNProto, Thrift, SOAP, OData, ActivityPub
  , NATS, AMQP, Kafka
  ]

public export
data Operation
  = Health
  | QuerySignals
  | ReadGovernance
  | DiscoverSources
  | SubmitFieldObservation
  | ProduceActionBrief

public export
operationCode : Operation -> Bits16
operationCode Health = 1
operationCode QuerySignals = 2
operationCode ReadGovernance = 3
operationCode DiscoverSources = 4
operationCode SubmitFieldObservation = 5
operationCode ProduceActionBrief = 6

public export
data Capability = ImplementedReadOnly | GovernedPlanned | ContractOnly | Unsupported

public export
operationCapability : Operation -> Capability
operationCapability Health = ImplementedReadOnly
operationCapability QuerySignals = ImplementedReadOnly
operationCapability ReadGovernance = ImplementedReadOnly
operationCapability DiscoverSources = GovernedPlanned
operationCapability SubmitFieldObservation = GovernedPlanned
operationCapability ProduceActionBrief = GovernedPlanned

public export
data ProfessionalContext = Journalism | PublicRelations | Communications | CrossMedia

public export
data EvidencePurpose
  = PublicInterestResearch
  | WorkerLedResearch
  | CollectiveBargainingEvidence
  | PublicAccountabilityReporting

public export
data SourceClass
  = PublicRecord
  | PublishedMedia
  | WorkerSubmitted
  | UnionSubmitted
  | ResearchDataset
  | PlatformAggregate
  | VendorOrEmployerClaim

||| Reconnaissance describes sources and systems, never covert observation of
||| workers, representatives, organising, sources, or industrial action.
public export
data ReconnaissanceTarget
  = SourceAvailability
  | SchemaDrift
  | CoverageGap
  | PublicInstitutionalClaim
  | PublishedMediaPattern

public export
data CollectionRisk
  = AggregatePublicEvidence
  | OrganisationLevelEvidence
  | VoluntaryFieldEvidence
  | IdentifiableWorkerMonitoring
  | UnionActivityMonitoring
  | IndustrialActionMonitoring
  | ProtectedSourceExposure
  | CollectiveSentimentInference

public export
data AdmissionDecision = Admit | Quarantine | Reject

||| Default-deny intake decision. Purpose never overrides a prohibited risk.
public export
admissionDecision : EvidencePurpose -> CollectionRisk -> AdmissionDecision
admissionDecision _ IdentifiableWorkerMonitoring = Reject
admissionDecision _ UnionActivityMonitoring = Reject
admissionDecision _ IndustrialActionMonitoring = Reject
admissionDecision _ ProtectedSourceExposure = Reject
admissionDecision _ CollectiveSentimentInference = Reject
admissionDecision _ VoluntaryFieldEvidence = Quarantine
admissionDecision _ AggregatePublicEvidence = Admit
admissionDecision _ OrganisationLevelEvidence = Quarantine

public export
data FieldAuthority
  = PersonalExperience
  | WorkplaceMandate
  | RecognisedUnionMandate
  | OtherCollectiveMandate

public export
data FieldStage
  = Received
  | ConsentAndAuthorityReview
  | Quarantined
  | Corroboration
  | Admitted
  | Challenged
  | Withdrawn
  | Rejected

public export
data ConnectorGate = Closed | ScopedReview | OpenForScopedSource
