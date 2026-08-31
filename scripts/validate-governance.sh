#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail

status_file="${1:-.machine_readable/governance/STATUS.json}"

jq empty "$status_file" schemas/v1/governance-*.schema.json

jq -e '
  . as $doc |
  $doc.liveConnectorsGate == "closed" and
  ([
      "draft-not-consulted", "consultation-open", "revision-open",
      "decision-pending", "ratified-with-conditions", "ratified", "disputed",
      "withdrawn", "expired"
    ] | index($doc.status)) != null and
  (
    ($doc.status == "draft-not-consulted" | not) or
    (
      $doc.authority == "project-draft-only" and
      $doc.consultationSessions == 0 and
      $doc.recordedReviews == 0 and
      $doc.ratificationRecords == 0
    )
  )
' "$status_file" >/dev/null

jq -e '
  if .status == "ratified" or .status == "ratified-with-conditions" then
    .authority == "authorised-worker-and-collective-process" and
    .consultationSessions > 0 and
    .recordedReviews > 0 and
    .ratificationRecords > 0
  else
    true
  end
' "$status_file" >/dev/null

echo "Worker-governance status: internally consistent"
