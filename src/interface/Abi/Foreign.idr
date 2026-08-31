-- SPDX-License-Identifier: MPL-2.0
||| Zig API surface governed by the Idris2 contract.
|||
||| There are intentionally no `%foreign "C:..."` declarations here. Idris2
||| specifies the total operation/capability contract; Zig implements the wire,
||| FFI, transport, connector, and codec surfaces natively.
module Abi.Foreign

import Abi.Types
import Abi.Layout
import Data.Vect

%default total

public export
data Mutation = ReadOnly | GovernedIntake | DerivedProduct

public export
record ZigApi where
  constructor MkZigApi
  operation : Operation
  route : String
  mutation : Mutation
  capability : Capability

public export
zigApis : Vect 6 ZigApi
zigApis =
  [ MkZigApi Health "/health" ReadOnly ImplementedReadOnly
  , MkZigApi QuerySignals "/v1/signals" ReadOnly ImplementedReadOnly
  , MkZigApi ReadGovernance "/v1/governance" ReadOnly ImplementedReadOnly
  , MkZigApi DiscoverSources "/v1/source-candidates" GovernedIntake GovernedPlanned
  , MkZigApi SubmitFieldObservation "/v1/field-observations" GovernedIntake GovernedPlanned
  , MkZigApi ProduceActionBrief "/v1/action-briefs" DerivedProduct GovernedPlanned
  ]

public export
boundaryGuarantees : Vect 6 String
boundaryGuarantees =
  [ "Idris2 is the authoritative operation and admission contract"
  , "Zig owns all executable API, FFI, codec, and transport boundaries"
  , "No C header, C shim, or C calling convention is required"
  , "Payloads are bounded before decoding"
  , "Field evidence is quarantined before admission"
  , "Worker, union, industrial-action, source, and collective-sentiment surveillance is rejected"
  ]
