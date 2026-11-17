# Rehearsal (Claude's dry run)

Verifies the whole flow end to end with a throwaway skill, so the live demo has no surprises.

| | |
|---|---|
| Skill | `skills/uc-rehearsal-check/` (SKILL.md + `references/checklist.md`) |
| Target | `<catalog>.rehearsal.uc-rehearsal-check` |
| Script | `CATALOG=<catalog> DATABRICKS_CONFIG_PROFILE=<profile> ./scripts/rehearse.sh` (`KEEP=1` to skip cleanup) |

## What it checks

| # | Step | Check |
|---|---|---|
| 0 | Preflight | Databricks CLI authenticated with profile `<profile>` |
| 1 | Schema | `<catalog>.rehearsal` exists (created if missing) |
| 2 | `create-skill` | Securable registered, **not** finalized yet |
| 3 | `fs cp -r` | Bundle uploaded to `dbfs:/Skills/...`, nested `references/` file present |
| 4 | `finalize-skill` | `bundle_name` + `finalize_time` set, shows in `list-skills` |
| 5 | Governance | `grants get skill` returns `{}`, so it's private until shared |
| 6 | Round trip | Downloaded bundle is byte-identical to the source |
| 7 | Republish | Description updates in place, `comment` preserved |
| 8 | `ug skills add` | Skill downloads into an agent skills folder |
| 9 | Cleanup | Skill and schema deleted |

## Last run — 2026-11-17

```
Result: 16 passed, 0 failed, 0 skipped
```

Ran with `ug` configured for **your own Claude subscription** (see `LIVE_DEMO.md` step 0).

## Not covered by the script

Launching `ug claude` and the agent actually *using* the skill needs an interactive terminal
and your Claude login, so that part is verified live in `LIVE_DEMO.md` step 5.
