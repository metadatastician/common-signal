-- SPDX-License-Identifier: MPL-2.0
||| Bounded Zig wire-frame contract. No C struct layout is involved.
module Abi.Layout

import Abi.Types
import Data.Bits
import Data.Nat

%default total

public export
abiVersion : Bits16
abiVersion = 1

public export
maxPayloadKiB : Nat
maxPayloadKiB = 1024

public export
record FrameHeader where
  constructor MkFrameHeader
  version : Bits16
  operation : Operation
  payloadKiBCeiling : Nat

||| Evidence that a frame can be admitted to the bounded Zig decoder.
public export
data BoundedFrame : FrameHeader -> Type where
  InBounds : LTE header.payloadKiBCeiling Abi.Layout.maxPayloadKiB -> BoundedFrame header

public export
admitFrame : (header : FrameHeader) -> Dec (BoundedFrame header)
admitFrame header =
  case isLTE header.payloadKiBCeiling maxPayloadKiB of
    Yes prf => Yes (InBounds prf)
    No contra => No (\(InBounds prf) => contra prf)

public export
data WireEncoding = JsonUtf8 | LengthPrefixedBinary

public export
encodingFor : Operation -> WireEncoding
encodingFor Health = JsonUtf8
encodingFor QuerySignals = JsonUtf8
encodingFor ReadGovernance = JsonUtf8
encodingFor DiscoverSources = JsonUtf8
encodingFor SubmitFieldObservation = JsonUtf8
encodingFor ProduceActionBrief = JsonUtf8
