#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Regression tests for scripts/strip-instruction-blocks.sh (Bash port of the
# former Python script). Each case pins a behaviour the original documented:
# the match never crosses a comment terminator, prose that merely mentions the
# marker survives, the gap is collapsed, the pass is idempotent, and build /
# vendored trees and binary files are left alone.

set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/strip-instruction-blocks.sh"
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
M='TEMPLATE'' INSTRUCTIONS'   # split so the repo-wide leftover-block grep does not match this file

# ── 1. Multi-line SPDX header survives; block, its trailing blanks and one
#       newline go; the file-wide gap is collapsed. ─────────────────────────
mkdir -p "$W/repo/.github" "$W/repo/node_modules/pkg" "$W/repo/target" "$W/repo/docs"
cat > "$W/repo/CODE_OF_CONDUCT.md" <<EOF
<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) 2026 Example
-->

<!-- $M (delete this block before publishing)
| Placeholder | Replace with |
| {{PLACEHOLDER}} | Squisher Corpus |
-->${M:0:0}

# Code of Conduct

Body text.
EOF
cat > "$W/expected_coc.md" <<'EOF'
<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) 2026 Example
-->

# Code of Conduct

Body text.
EOF

# ── 2. Prose that only MENTIONS the marker (outside any comment) survives,
#       and a plain comment before it is not swallowed. ────────────────────
cat > "$W/repo/docs/defect.md" <<EOF
<!-- ordinary comment -->
The $M block used to ship in 211 repos.
EOF
cp "$W/repo/docs/defect.md" "$W/expected_defect.md"

# ── 3. A comment without the marker followed by one with it: only the second
#       goes. A pattern able to cross \`-->\` would eat both. ────────────────
printf '<!-- keep me -->\nA\n<!-- %s -->\nB' "$M" > "$W/repo/.github/SECURITY.md"
printf '<!-- keep me -->\nA\nB' > "$W/expected_security.md"   # no trailing NL kept as-is

# ── 4. Skipped trees and binary files are never touched. ──────────────────
for d in node_modules/pkg target; do
    printf '<!-- %s -->\n' "$M" > "$W/repo/$d/README.md"
done
printf '<!-- %s -->\0binary\n' "$M" > "$W/repo/blob.bin"
cp "$W/repo/blob.bin" "$W/expected_blob.bin"

# ── Run ───────────────────────────────────────────────────────────────────
out=$(cd "$W/repo" && bash "$SCRIPT" .) || fail "script exited non-zero"

cmp -s "$W/repo/CODE_OF_CONDUCT.md" "$W/expected_coc.md" \
    || { diff "$W/expected_coc.md" "$W/repo/CODE_OF_CONDUCT.md" >&2; fail "case 1: header/block/gap handling"; }
cmp -s "$W/repo/docs/defect.md" "$W/expected_defect.md" \
    || fail "case 2: prose mentioning the marker was altered"
cmp -s "$W/repo/.github/SECURITY.md" "$W/expected_security.md" \
    || { diff "$W/expected_security.md" "$W/repo/.github/SECURITY.md" >&2; fail "case 3: match crossed a comment terminator"; }
for d in node_modules/pkg target; do
    grep -qF "$M" "$W/repo/$d/README.md" || fail "case 4: skipped dir $d was modified"
done
cmp -s "$W/repo/blob.bin" "$W/expected_blob.bin" || fail "case 4: binary file was modified"

expected_out="  instruction block: stripped from .github/SECURITY.md
  instruction block: stripped from CODE_OF_CONDUCT.md
  instruction blocks: 2 file(s) cleaned"
[ "$out" = "$expected_out" ] || { printf 'got:\n%s\n' "$out" >&2; fail "report lines"; }

# ── 5. Idempotent: a second pass changes nothing. ────────────────────────
out2=$(cd "$W/repo" && bash "$SCRIPT")
[ "$out2" = "  instruction blocks: none found" ] || fail "case 5: second pass not idempotent: $out2"
cmp -s "$W/repo/CODE_OF_CONDUCT.md" "$W/expected_coc.md" || fail "case 5: second pass changed a file"

# ── 6. A root other than "." is reported with its prefix. ────────────────
printf '<!-- %s -->\n' "$M" > "$W/repo/docs/again.md"
out3=$(bash "$SCRIPT" "$W/repo")
grep -qF "stripped from $W/repo/docs/again.md" <<<"$out3" || fail "case 6: report path for explicit root"
[ ! -s "$W/repo/docs/again.md" ] || fail "case 6: block-only file should be empty"

echo "PASS: strip-instruction-blocks.sh (6 cases)"
