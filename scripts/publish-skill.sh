#!/usr/bin/env bash
# Publish one local skill folder to Unity Catalog as a first-class securable.
#
#   ./scripts/publish-skill.sh <local-skill-folder> <catalog.schema.skill>
#
# Flow (same as databricks/unity-gateway's publish-skills action):
#   1. ai-gateway create-skill    -> registers catalog.schema.skill + managed storage
#   2. fs cp -r dbfs:/Skills/...  -> uploads the bundle (SKILL.md + supporting files)
#   3. ai-gateway finalize-skill  -> validates SKILL.md frontmatter, makes it discoverable
#
# Uses DATABRICKS_CONFIG_PROFILE (default: DEFAULT).
set -euo pipefail

SRC="${1:?usage: publish-skill.sh <local-skill-folder> <catalog.schema.skill>}"
TARGET="${2:?usage: publish-skill.sh <local-skill-folder> <catalog.schema.skill>}"
export DATABRICKS_CONFIG_PROFILE="${DATABRICKS_CONFIG_PROFILE:-DEFAULT}"

IFS=. read -r CATALOG SCHEMA SKILL <<<"$TARGET"
[[ -n "$CATALOG" && -n "$SCHEMA" && -n "$SKILL" ]] || { echo "target must be catalog.schema.skill" >&2; exit 1; }
[[ -f "$SRC/SKILL.md" ]] || { echo "no SKILL.md in $SRC" >&2; exit 1; }
[[ "$(head -n1 "$SRC/SKILL.md")" == "---" ]] || { echo "SKILL.md must start with YAML frontmatter" >&2; exit 1; }

# Stage a clean copy (no .git, .DS_Store, symlinks) so only real bundle files are uploaded.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
rsync -a --no-links --exclude '.git' --exclude '.DS_Store' "$SRC/" "$STAGE/"

echo "==> [1/3] create-skill $TARGET"
if databricks ai-gateway get-skill "skills/$TARGET" >/dev/null 2>&1; then
  echo "    already exists - updating in place (ownership and grants are kept)"
else
  databricks ai-gateway create-skill "schemas/$CATALOG.$SCHEMA" "$SKILL" >/dev/null
fi

echo "==> [2/3] upload bundle -> dbfs:/Skills/$CATALOG/$SCHEMA/$SKILL"
databricks fs cp -r --overwrite "$STAGE" "dbfs:/Skills/$CATALOG/$SCHEMA/$SKILL"

echo "==> [3/3] finalize-skill"
databricks ai-gateway finalize-skill "skills/$TARGET" -o json \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print("    published:", d.get("full_name") or d.get("name"), "| bundle:", d.get("bundle_name"))'
