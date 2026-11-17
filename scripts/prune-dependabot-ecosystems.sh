#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# prune-dependabot-ecosystems.sh — prune .github/dependabot.yml to the
# ecosystems this project actually uses.
#
# Bash port of the former scripts/prune-dependabot-ecosystems.py (removed:
# Python is banned estate-wide, standards 3-practice/LANGUAGE-POLICY.adoc §3,
# and Hypatia's cicd_rules/banned_language_file flagged it critical). Output
# and exit codes are unchanged; tests/workflows/prune_dependabot_ecosystems_test.sh
# pins them.
#
# Why this exists: the template ships every common ecosystem under the header
# "Covers common ecosystems - remove unused ones for your project". Nothing
# removed them. Measured 2026-08-04 across 423 estate checkouts — declared vs.
# manifest present at the repo root:
#
#     pip    206 declared / 206 with no Python manifest   (100%)
#     npm    231 declared / 222 with no package.json      ( 96%)
#     mix    207 declared / 197 with no mix.exs           ( 95%)
#     cargo  251 declared / 166 with no Cargo.toml        ( 66%)
#
# Each of those fails on every scheduled run with "Dependabot encountered an
# error performing the update". Same shape as the instruction block: the
# template documents a manual step and nothing performs it.
#
# Separately and much worse, 209 repos declare `package-ecosystem: "nix"`,
# which is not a valid Dependabot ecosystem value at all. An invalid enum makes
# GitHub reject the WHOLE config, so in those repos the github-actions and
# cargo entries beside it are inert too — Dependabot has been silently doing
# nothing. The template's own dependabot.yml already carries a comment
# forbidding `nix`; this script drops it if a stale copy reintroduces one.
#
# A freshly minted repo has no manifests yet, so pruning on file presence would
# delete everything. Pass the ecosystems to keep explicitly — the operator's
# archetype choice is better evidence than an empty tree.
#
# Usage: prune-dependabot-ecosystems.sh <file> <keep...>
#        prune-dependabot-ecosystems.sh .github/dependabot.yml github-actions cargo

set -uo pipefail
export LC_ALL=C

usage() {
    sed -n 's/^# \{0,1\}//; /^Usage:/,/^$/p' "${BASH_SOURCE[0]}" | sed '/^$/d' >&2
    exit 1
}

main() {
    [ $# -ge 2 ] || usage
    local path=$1; shift
    local -A keep=()
    local k
    for k in "$@"; do
        # Never valid for Dependabot, and rejects the entire file if present.
        [ "$k" = nix ] || keep[$k]=1
    done

    if [ ! -f "$path" ]; then
        echo "  dependabot: $path absent, nothing to prune"
        return 0
    fi

    local text
    text=$(cat -- "$path" && printf x) || return 1
    text=${text%x}

    # An entry runs from its `- package-ecosystem:` line to just before the
    # next one (or EOF), so trailing comments travel with their own entry.
    local start_re=$'^[ \t]*-[ \t]*package-ecosystem:'
    local name_re=$'package-ecosystem:[ \t]*["\']?([A-Za-z-]+)'
    local head='' line nl
    local -a entries=()
    while [ -n "$text" ]; do
        if [[ $text == *$'\n'* ]]; then
            line=${text%%$'\n'*}; nl=$'\n'
        else
            line=$text; nl=''
        fi
        text=${text:${#line}+${#nl}}
        if [[ $line =~ $start_re ]]; then
            entries+=("$line$nl")
        elif [ ${#entries[@]} -eq 0 ]; then
            head+=$line$nl
        else
            entries[-1]+=$line$nl
        fi
    done

    if [ ${#entries[@]} -eq 0 ]; then
        echo "  dependabot: no ecosystem entries found"
        return 0
    fi

    local entry name kept_text=''
    local -a kept=() dropped=()
    for entry in "${entries[@]}"; do
        name='?'
        [[ $entry =~ $name_re ]] && name=${BASH_REMATCH[1]}
        if [ -n "${keep[$name]+x}" ]; then
            kept+=("$name"); kept_text+=$entry
        else
            dropped+=("$name")
        fi
    done

    if [ ${#kept[@]} -eq 0 ]; then
        # Refuse to write a config with an empty `updates:` list — that is
        # invalid and would reject the file just as surely as a bad enum.
        echo "  dependabot: refusing to prune every entry; left unchanged"
        return 0
    fi
    if [ ${#dropped[@]} -eq 0 ]; then
        echo "  dependabot: nothing to prune"
        return 0
    fi

    printf '%s' "$head$kept_text" > "$path"
    local IFS=,
    local k_list="${kept[*]}" d_list="${dropped[*]}"
    echo "  dependabot: kept ${k_list//,/, } / dropped ${d_list//,/, }"
    return 0
}

main "$@"
