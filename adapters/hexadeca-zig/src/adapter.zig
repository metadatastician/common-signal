// SPDX-License-Identifier: MPL-2.0
//! Public Zig adapter surface: Idris2 contract mirror plus native router.

pub const contract = @import("contract.zig");
pub const router = @import("router.zig");

test {
    _ = contract;
    _ = router;
}
