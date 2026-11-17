#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# strip-instruction-blocks.sh — delete the RSR template's "TEMPLATE
# INSTRUCTIONS" comment blocks.
#
# Bash port of the former scripts/strip-instruction-blocks.py (removed: Python
# is banned estate-wide, standards 3-practice/LANGUAGE-POLICY.adoc §3, and
# Hypatia's cicd_rules/banned_language_file flagged it critical). Behaviour is
# kept byte-for-byte on UTF-8 LF text; tests/workflows/strip_instruction_blocks_test.sh
# pins it.
#
# Why this exists: the community-health templates open with an HTML comment
# headed "TEMPLATE INSTRUCTIONS (delete this block before publishing)". Nothing
# in the mint ever deleted it. Measured 2026-08-04 across 423 estate checkouts:
# 211 repos still carry it — 206 in CODE_OF_CONDUCT.md, 106 in SECURITY.md.
#
# It is self-detonating, which is why substitution cannot save you. The block's
# own first line says to replace all values using a LITERAL doubled-brace token.
# That is metasyntax, not a real token, so the mint's sed pass has nothing to
# match and leaves it intact. Every placeholder gate in the estate then greps a
# doubled-brace SHOUTY_SNAKE pattern and finds it, so a repo whose every genuine
# token was substituted correctly still trips its own gate. That is the
# mechanism behind metadatastician/688-attack-hub#11 and f19-stealth-glider#12.
#
# Worse, the block carries the DONOR's substituted values. squisher-corpus
# filled its own name into the instruction table instead of deleting the block,
# and its root CODE_OF_CONDUCT.md was then copied outward: 58 repos now name
# "Squisher Corpus" as the project they protect and route conduct reports to
# the wrong repo.
#
# Run AFTER substitution: any real token the operator supplied is already
# filled in, so only the instructions go.
#
# Usage: strip-instruction-blocks.sh [root]      (default ".")
# Exit 0 always; prints one line per file changed. Idempotent.

set -uo pipefail
export LC_ALL=C   # byte semantics: the marker and delimiters are ASCII

MARKER="TEMPLATE INSTRUCTIONS"
OPEN='<!--'
CLOSE='-->'

# strip_text: read $1, write the result to the global STRIPPED.
#
# A block is an HTML comment — `<!--` up to the FIRST `-->` after it — whose
# body contains the marker. The match never crosses a comment terminator. That
# is load-bearing: a pattern that can cross one starts at the file's FIRST
# `<!--` — which in most of these files is a multi-line SPDX and copyright
# header — skips over that header's `-->`, and takes the licence header and
# the `# Code of Conduct` H1 with it. Caught on metadatastician/boj-server-mk2
# while testing; it looks correct on any file whose SPDX header happens to be
# a single line.
#
# Anchoring on the comment rather than the line also means prose that merely
# MENTIONS the marker survives — documentation about this defect would
# otherwise be deleted by the fix for it.
#
# Trailing spaces/tabs and one newline after the `-->` go with the block.
strip_text() {
    local rest=$1 out='' pre body inner ws
    while [[ $rest == *"$OPEN"* ]]; do
        pre=${rest%%"$OPEN"*}
        out+=$pre
        body=${rest:${#pre}+${#OPEN}}
        # No terminator after this opener means none after any later one.
        [[ $body == *"$CLOSE"* ]] || { out+=$OPEN; rest=$body; break; }
        inner=${body%%"$CLOSE"*}
        if [[ $inner == *"$MARKER"* ]]; then
            rest=${body:${#inner}+${#CLOSE}}
            ws=${rest%%[!$' \t']*}
            rest=${rest:${#ws}}
            [[ $rest == $'\n'* ]] && rest=${rest:1}
        else
            # Not a block. Any opener nested before this comment's terminator
            # shares that terminator and a subset of the body, so it cannot
            # hold the marker either; resume right after this opener.
            out+=$OPEN
            rest=$body
        fi
    done
    STRIPPED=$out$rest
}

# strip_file: rewrite $1 in place; return 0 iff it changed.
strip_file() {
    local path=$1 text new
    grep -qF -- "$MARKER" "$path" 2>/dev/null || return 1
    # Text files only: NUL bytes cannot survive a shell string, and non-UTF-8
    # input was skipped by the original too.
    [ "$(tr -d '\000' < "$path" | wc -c)" -eq "$(wc -c < "$path")" ] || return 1
    if command -v iconv >/dev/null 2>&1; then
        iconv -f UTF-8 -t UTF-8 "$path" >/dev/null 2>&1 || return 1
    fi
    # The sentinel keeps trailing newlines that $(...) would otherwise eat.
    text=$(cat -- "$path" && printf x) || return 1
    text=${text%x}
    strip_text "$text"
    new=$STRIPPED
    [[ $new == "$text" ]] && return 1
    # Collapse the gap the deletion leaves (file-wide, as before).
    while [[ $new == *$'\n\n\n'* ]]; do
        new=${new//$'\n\n\n'/$'\n\n'}
    done
    printf '%s' "$new" > "$path"
}

main() {
    local root=${1:-.} changed=0 f shown
    while IFS= read -r -d '' f; do
        if strip_file "$f"; then
            shown=$f
            [ "$root" = "." ] && shown=${f#./}
            echo "  instruction block: stripped from $shown"
            changed=$((changed + 1))
        fi
    done < <(find "$root" \
                 \( -type d \( -name .git -o -name node_modules -o -name .venv \
                               -o -name target -o -name dist \) -prune \) \
                 -o -type f -print0 | sort -z)
    if [ "$changed" -gt 0 ]; then
        echo "  instruction blocks: $changed file(s) cleaned"
    else
        echo "  instruction blocks: none found"
    fi
    return 0
}

# Allow `source`-ing for tests without running main.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
