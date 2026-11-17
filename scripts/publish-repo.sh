#!/usr/bin/env bash
# Publish every skill folder (immediate children containing SKILL.md) under a directory
# into one UC schema. Optionally pass skill folder names to publish only those.
#
#   ./scripts/publish-repo.sh <skills-dir> <catalog.schema> [skill-name ...]
set -euo pipefail

DIR="${1:?usage: publish-repo.sh <skills-dir> <catalog.schema> [skill-name ...]}"
SCHEMA_FQN="${2:?usage: publish-repo.sh <skills-dir> <catalog.schema> [skill-name ...]}"
shift 2
HERE="$(cd "$(dirname "$0")" && pwd)"

if [[ $# -gt 0 ]]; then
  names=("$@")
else
  names=()
  for f in "$DIR"/*/SKILL.md; do names+=("$(basename "$(dirname "$f")")"); done
fi

ok=0; failed=()
for name in "${names[@]}"; do
  if "$HERE/publish-skill.sh" "$DIR/$name" "$SCHEMA_FQN.$name"; then
    ok=$((ok + 1))
  else
    failed+=("$name")
  fi
done

echo
echo "Published $ok/${#names[@]} skills to $SCHEMA_FQN"
[[ ${#failed[@]} -eq 0 ]] || { echo "Failed: ${failed[*]}"; exit 1; }
