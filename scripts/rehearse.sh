#!/usr/bin/env bash
# End-to-end rehearsal of the UC skills flow, with a check after every step.
# Publishes skills/uc-rehearsal-check into $CATALOG.rehearsal, verifies it,
# then deletes the skill and schema (set KEEP=1 to leave them in place).
#
#   CATALOG=<catalog> DATABRICKS_CONFIG_PROFILE=<profile> ./scripts/rehearse.sh
set -uo pipefail

export DATABRICKS_CONFIG_PROFILE="${DATABRICKS_CONFIG_PROFILE:-DEFAULT}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
CATALOG="${CATALOG:?set CATALOG to the target catalog, e.g. CATALOG=main}"
SCHEMA=rehearsal
SKILL=uc-rehearsal-check
SRC="$HERE/skills/$SKILL"
FQN="$CATALOG.$SCHEMA.$SKILL"
REMOTE="dbfs:/Skills/$CATALOG/$SCHEMA/$SKILL"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0; skip=0
ok()   { echo "  PASS  $1"; pass=$((pass + 1)); }
bad()  { echo "  FAIL  $1"; fail=$((fail + 1)); }
skp()  { echo "  SKIP  $1"; skip=$((skip + 1)); }
field() { python3 -c "import json,sys; print(json.load(sys.stdin).get('$1') or '')"; }

echo "== 0. preflight"
user="$(databricks current-user me -o json 2>/dev/null | field userName)"
[[ -n "$user" ]] && ok "authenticated as $user" || { bad "databricks auth (profile $DATABRICKS_CONFIG_PROFILE)"; exit 1; }

echo "== 1. schema"
databricks schemas get "$CATALOG.$SCHEMA" >/dev/null 2>&1 \
  || databricks schemas create "$SCHEMA" "$CATALOG" --comment "Throwaway schema for rehearsals" >/dev/null
databricks schemas get "$CATALOG.$SCHEMA" >/dev/null 2>&1 && ok "$CATALOG.$SCHEMA exists" || bad "create schema"

echo "== 2. create-skill"
databricks ai-gateway get-skill "skills/$FQN" >/dev/null 2>&1 \
  && databricks ai-gateway delete-skill "skills/$FQN" >/dev/null   # start from a clean slate
databricks ai-gateway create-skill "schemas/$CATALOG.$SCHEMA" "$SKILL" --comment "rehearsal" >/dev/null \
  && ok "created $FQN" || bad "create-skill"
[[ -z "$(databricks ai-gateway get-skill "skills/$FQN" -o json | field finalize_time)" ]] \
  && ok "not finalized yet (expected)" || bad "unexpected finalize_time before finalize"

echo "== 3. upload"
databricks fs cp -r --overwrite "$SRC" "$REMOTE" >/dev/null && ok "fs cp -> $REMOTE" || bad "fs cp"
databricks fs ls "$REMOTE/references" 2>/dev/null | grep -q checklist.md \
  && ok "nested file present remotely" || bad "references/checklist.md missing remotely"

echo "== 4. finalize-skill"
out="$(databricks ai-gateway finalize-skill "skills/$FQN" -o json)"
[[ "$(echo "$out" | field bundle_name)" == "$SKILL" ]] && ok "bundle_name=$SKILL" || bad "bundle_name"
[[ -n "$(echo "$out" | field finalize_time)" ]] && ok "finalize_time set" || bad "finalize_time"
databricks ai-gateway list-skills "schemas/$CATALOG.$SCHEMA" -o json | grep -q "\"skills/$FQN\"" \
  && ok "list-skills shows it" || bad "list-skills"

echo "== 5. governance"
grants="$(databricks grants get skill "$FQN" -o json 2>&1)"
[[ "$grants" == "{}" ]] && ok "private until shared (no grants)" || bad "grants get: $grants"

echo "== 6. round trip"
databricks fs cp -r "$REMOTE" "$TMP/roundtrip" >/dev/null
diff -r "$SRC" "$TMP/roundtrip" >/dev/null && ok "downloaded bundle is byte-identical" || bad "bundle differs"

echo "== 7. republish (update)"
cp -R "$SRC" "$TMP/v2"
sed -i '' 's/^  Rehearsal-only skill/  [v2] Rehearsal-only skill/' "$TMP/v2/SKILL.md"
databricks fs cp -r --overwrite "$TMP/v2" "$REMOTE" >/dev/null
desc="$(databricks ai-gateway finalize-skill "skills/$FQN" -o json | field description)"
[[ "$desc" == "[v2]"* ]] && ok "description updated in place" || bad "description not updated: $desc"
[[ "$(databricks ai-gateway get-skill "skills/$FQN" -o json | field comment)" == "rehearsal" ]] \
  && ok "comment preserved across republish" || bad "comment lost"

echo "== 8. ug skills add"
if ug skills add --names "$FQN" --path "$TMP" </dev/null >"$TMP/ug.log" 2>&1; then
  found="$(find "$TMP" -path '*uc-rehearsal-check/SKILL.md' -not -path "$TMP/v2/*" -not -path "$TMP/roundtrip/*" | head -1)"
  [[ -n "$found" ]] && ok "ug downloaded skill to ${found#$TMP/}" || bad "ug ran but no SKILL.md found"
elif grep -q "not configured" "$TMP/ug.log"; then
  skp "ug not configured - run 'ug configure' then re-run"
else
  bad "ug skills add: $(tail -1 "$TMP/ug.log")"
fi

echo "== 9. cleanup"
if [[ "${KEEP:-0}" == "1" ]]; then
  skp "KEEP=1 - leaving $FQN in place"
else
  databricks ai-gateway delete-skill "skills/$FQN" >/dev/null && ok "deleted $FQN" || bad "delete-skill"
  databricks schemas delete "$CATALOG.$SCHEMA" --force >/dev/null && ok "deleted $CATALOG.$SCHEMA" || bad "delete schema"
fi

echo
echo "Result: $pass passed, $fail failed, $skip skipped"
[[ $fail -eq 0 ]]
