#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Regression tests for scripts/prune-dependabot-ecosystems.sh (Bash port of
# the former Python script): keep-set pruning, unconditional `nix` removal,
# comments travelling with their own entry, and every refuse/no-op path.

set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/prune-dependabot-ecosystems.sh"
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

cat > "$W/fixture.yml" <<'EOF'
# SPDX-License-Identifier: MPL-2.0
version: 2
updates:
  # GitHub Actions - always include
  - package-ecosystem: "github-actions"
    directory: "/"
  # Rust/Cargo
  - package-ecosystem: cargo
    directory: "/"
  # npm comment travels with npm
  - package-ecosystem: 'npm'
    directory: "/"
  - package-ecosystem: "nix"
    directory: "/"
EOF

# ── 1. Keep github-actions + cargo (+ nix, which must still go). ──────────
cp "$W/fixture.yml" "$W/a.yml"
out=$(bash "$SCRIPT" "$W/a.yml" github-actions cargo nix)
[ "$out" = "  dependabot: kept github-actions, cargo / dropped npm, nix" ] \
    || fail "case 1 report: $out"
cat > "$W/a.expected" <<'EOF'
# SPDX-License-Identifier: MPL-2.0
version: 2
updates:
  # GitHub Actions - always include
  - package-ecosystem: "github-actions"
    directory: "/"
  # Rust/Cargo
EOF
# The "# npm comment" line belongs to the CARGO entry (it precedes npm's
# `- package-ecosystem:` line), matching the original split semantics.
cat >> "$W/a.expected" <<'EOF'
  - package-ecosystem: cargo
    directory: "/"
  # npm comment travels with npm
EOF
cmp -s "$W/a.yml" "$W/a.expected" || { diff "$W/a.expected" "$W/a.yml" >&2; fail "case 1 content"; }

# ── 2. Nothing to prune. ─────────────────────────────────────────────────
cp "$W/a.yml" "$W/b.yml"
out=$(bash "$SCRIPT" "$W/b.yml" github-actions cargo)
[ "$out" = "  dependabot: nothing to prune" ] || fail "case 2: $out"
cmp -s "$W/a.yml" "$W/b.yml" || fail "case 2: file changed"

# ── 3. Refuse to empty `updates:` (keep-set matches nothing / only nix). ──
for keep in bogus nix; do
    cp "$W/fixture.yml" "$W/c.yml"
    out=$(bash "$SCRIPT" "$W/c.yml" "$keep")
    [ "$out" = "  dependabot: refusing to prune every entry; left unchanged" ] || fail "case 3 ($keep): $out"
    cmp -s "$W/fixture.yml" "$W/c.yml" || fail "case 3 ($keep): file changed"
done

# ── 4. Absent file, no entries, usage. ───────────────────────────────────
out=$(bash "$SCRIPT" "$W/missing.yml" cargo)
[ "$out" = "  dependabot: $W/missing.yml absent, nothing to prune" ] || fail "case 4 absent: $out"
printf 'version: 2\nupdates: []\n' > "$W/d.yml"
out=$(bash "$SCRIPT" "$W/d.yml" cargo)
[ "$out" = "  dependabot: no ecosystem entries found" ] || fail "case 4 no-entries: $out"
if bash "$SCRIPT" "$W/d.yml" 2>"$W/usage.err"; then fail "case 4: usage should exit non-zero"; fi
grep -q '^Usage: prune-dependabot-ecosystems.sh' "$W/usage.err" || fail "case 4: usage text"

# ── 5. Final entry without a trailing newline is preserved byte-for-byte. ─
printf 'updates:\n  - package-ecosystem: npm\n  - package-ecosystem: "cargo"\n    directory: "/"' > "$W/e.yml"
bash "$SCRIPT" "$W/e.yml" cargo >/dev/null
[ "$(cat "$W/e.yml"; printf x)" = "$(printf 'updates:\n  - package-ecosystem: "cargo"\n    directory: "/"x')" ] \
    || fail "case 5: trailing-newline handling"

# ── 6. A failed write exits non-zero and does not report success. Root
#       ignores file modes, so this runs only unprivileged (as in CI). ────
if [ "$(id -u)" -ne 0 ]; then
    cp "$W/fixture.yml" "$W/ro.yml"
    chmod 444 "$W/ro.yml"
    if out=$(bash "$SCRIPT" "$W/ro.yml" cargo 2>"$W/ro.err"); then
        fail "case 6: write failure exited 0"
    fi
    case $out in *kept*) fail "case 6: reported success on a failed write" ;; esac
    grep -q 'failed to write' "$W/ro.err" || fail "case 6: write failure not reported"
    echo "PASS: prune-dependabot-ecosystems.sh (6 cases)"
else
    echo "PASS: prune-dependabot-ecosystems.sh (5 cases; case 6 skipped as root)"
fi
