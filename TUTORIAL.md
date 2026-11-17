# Agent Skills as First-Class Unity Catalog Securables (Beta)

**Video goal:** take agent skills from GitHub, publish them into Unity Catalog as governed
`catalog.schema.skill` objects, share them with permissions, and use them from a coding
agent through the Unity Gateway CLI (`ug`). Then do the same with a brand-new skill live.

| | |
|---|---|
| Workspace | `https://<workspace-host>` |
| Catalog | `<catalog>` |
| CLI profile | `<profile>` |
| Sample skills | [databricks/databricks-agent-skills](https://github.com/databricks/databricks-agent-skills), [RamVegiraju/central-skill-repo](https://github.com/RamVegiraju/central-skill-repo) |
| Docs | [Use UC skills](https://docs.databricks.com/aws/en/agents/uc-skills/use-uc-skills) · [Create & share](https://docs.databricks.com/aws/en/agents/uc-skills/create-share-uc-skills) · [`ug` CLI reference](https://docs.databricks.com/aws/en/ai-gateway/coding-agent-ug-cli) |

---

## 0. The idea, in 30 seconds (talking points)

- A **skill** is a folder with a `SKILL.md` (YAML frontmatter `name` + `description`, then
  Markdown instructions) plus optional supporting files like `references/*.md`.
- Today skills live scattered in `~/.claude/skills`, random repos, Slack threads. No
  ownership, no access control, no audit trail.
- With UC Skills (Beta), a skill becomes a **first-class Unity Catalog securable** named
  `catalog.schema.skill`, with the same permissions, tags, and audit logging as a table.
- Agents discover them through a **Skills MCP server**
  (`https://<host>/ai-gateway/skills/?schema=<catalog>.<schema>`), and only see the
  skills they have privileges on.
- The `ug` (Unity Gateway) CLI wires your coding agent (Claude Code, Codex, Gemini,
  OpenCode, Copilot) to that registry.

**Lifecycle we'll show:** write → `create-skill` → upload bundle → `finalize-skill` →
grant → discover/use from the agent → update.

---

## 1. Prerequisites

- Workspace admin turned on **Unity Gateway skills in Genie** under **Settings → Previews**.
- Unity Catalog workspace (not on the compliance security profile — that blocks creating skills).
- Python 3.12+ and [`uv`](https://docs.astral.sh/uv/) (uv will fetch Python for you).
- Databricks CLI **v1.21+** (has `databricks ai-gateway *-skill` commands and `dbfs:/Skills` paths).
- Privileges to publish: `USE CATALOG` on the catalog, `USE SCHEMA` + `CREATE VOLUME` on the schema.

```bash
# Check the Databricks CLI is v1.21+ (needed for the ai-gateway skill commands)
databricks --version

# Check uv is installed (it installs ug and fetches Python 3.12+ for it)
uv --version
```

---

## 2. Install the Unity Gateway CLI

```bash
# Install the Unity Gateway CLI straight from GitHub as an isolated uv tool
uv tool install git+https://github.com/databricks/unity-gateway

# Confirm it's on your PATH
ug --version

# List the top-level commands (configure, skills, mcp, claude, ...)
ug --help
```

> On camera: point out that it installs two binaries, `ug` and `ucode`.

---

## 3. Authenticate

**Databricks CLI** (used for publishing):

```bash
# Sign in with OAuth in the browser and save the credentials as profile "<profile>"
databricks auth login \
  --host https://<workspace-host> \
  --profile <profile>

# Make that profile the default for this shell, so later commands can skip --profile
export DATABRICKS_CONFIG_PROFILE=<profile>

# Confirm who you're signed in as
databricks current-user me
```

**Unity Gateway CLI** (connects your coding agent to the skills registry):

**Recommended: keep using your own Claude subscription.** An admin creates a model provider
service that relays each caller's Claude login (it stores no credential), following
[Create a model provider service](https://docs.databricks.com/aws/en/ai-gateway/create-model-provider-services#use-each-callers-claude-or-chatgpt-subscription)
(UI: **Unity Gateway → Providers → Provider**, type *Anthropic*, auth *Claude Max / Enterprise*).
Then point `ug` at it ([Use Claude Code with Unity Gateway](https://docs.databricks.com/aws/en/ai-gateway/coding-agent-claude)):

```bash
# Create a UC model provider service for Anthropic in "relayed" mode: it stores no API key and
# forwards each caller's own Claude login. allow_all_targets exposes every Claude model.
databricks ai-gateway create-model-provider-service schemas/<catalog>.default claude_subscription \
  --json '{"config":{"provider_type":"EXTERNAL_MODEL_PROVIDER_TYPE_ANTHROPIC","anthropic":{"relayed":{}},"allow_all_targets":true}}'

# Point Claude Code at that service. --user writes user-level settings only (no machine-wide
# changes); --provider sends requests through the service, billed to your Claude subscription.
ug configure --user --agents claude --provider <catalog>.default.claude_subscription --profile <profile>

# Check the install, workspace, auth and agent config, and offer fixes
ug doctor
```

Docs: requests are "billed against the caller's Anthropic subscription and are subject to that
subscription's rate limits" ([Claude Max / Enterprise support](https://docs.databricks.com/aws/en/ai-gateway/claude-max-anthropic-enterprise-support)).
Works with Pro, Max, Team or Enterprise plans.

**Default (Databricks-hosted models, billed to the workspace):**

```bash
# Sign in and route Claude Code to Databricks-hosted Claude models through the workspace gateway
ug configure --agents claude --workspace https://<workspace-host>
```

A browser window opens for sign-in. Swap `claude` for `codex`, `gemini`, `opencode` or
`copilot` as needed.

> **Heads-up (verified with `--dry-run`):** `ug configure` routes the agent's model traffic
> through your workspace's AI Gateway (`ANTHROPIC_BASE_URL=https://<host>/ai-gateway/anthropic`,
> `system.ai.claude-*` models, WebSearch denied). It writes `~/.claude/ucode-settings.json`
> **and** machine-wide `/Library/Application Support/ClaudeCode/managed-settings.json` (via
> `sudo`), and configures Claude Desktop too. Preview first with
> `ug configure --dry-run --agents claude --workspace <url>`; undo with `ug revert`.
> Every `ug skills` command requires this step first.

---

## 4. Set up schemas in the catalog

A schema is the unit of discovery and sharing for skills, so organize by audience/source:

| Schema | Contents |
|---|---|
| `<catalog>.databricks_skills` | Official skills from `databricks/databricks-agent-skills` |
| `<catalog>.central_skills` | Curated picks from `RamVegiraju/central-skill-repo` |
| `<catalog>.demo_skills` | The skill we write live |

```bash
# Create three schemas in the <catalog> catalog (usage: schemas create <schema> <catalog>)
databricks schemas create databricks_skills <catalog> --comment "Official Databricks agent skills"
databricks schemas create central_skills    <catalog> --comment "Curated ML/DE skills from central-skill-repo"
databricks schemas create demo_skills       <catalog> --comment "Skills authored live for the YT demo"
```

SQL equivalent (note the backticks — the catalog name has a hyphen):

```sql
CREATE SCHEMA IF NOT EXISTS `<catalog>`.databricks_skills;
```

---

## 5. Get the sample skills

```bash
# Make a folder for the sample repos and download them (--depth 1 = latest commit only)
mkdir -p sources && cd sources
git clone --depth 1 https://github.com/databricks/databricks-agent-skills.git
git clone --depth 1 https://github.com/RamVegiraju/central-skill-repo.git
cd ..

# List the skills: each folder is one skill
ls sources/databricks-agent-skills/skills

# Show the frontmatter (name + description) at the top of one SKILL.md
head -8 sources/databricks-agent-skills/skills/databricks-dbsql/SKILL.md
```

> On camera: show the frontmatter. `name` + `description` are required; `description` is
> what the agent uses to decide *when* to load the skill, so it matters a lot.

**Rules the platform enforces at finalize time**

- `SKILL.md` must start with `---` YAML frontmatter.
- `name`: lowercase letters, digits, hyphens; 1–64 chars; can't start/end with a hyphen.
- `description`: non-empty, ≤ 1024 bytes.
- No symlinks. The **folder name** (the `SKILL_ID` you pass) becomes the UC identifier,
  not the frontmatter `name`.

---

## 6. Publish one skill — the three primitive calls

Do this one by hand so viewers see what's really happening.

```bash
# 1) Register the skill as a UC securable (<catalog>.databricks_skills.databricks-dbsql)
#    and set up its managed storage. You become the owner; no files are sent yet.
databricks ai-gateway create-skill schemas/<catalog>.databricks_skills databricks-dbsql \
  --comment "DBSQL features and SQL warehouse guidance"

# 2) Upload the local folder (SKILL.md + supporting files) into that storage.
#    -r copies the whole folder; --overwrite replaces files already there.
databricks fs cp -r --overwrite \
  sources/databricks-agent-skills/skills/databricks-dbsql \
  dbfs:/Skills/<catalog>/databricks_skills/databricks-dbsql

# List what landed remotely
databricks fs ls dbfs:/Skills/<catalog>/databricks_skills/databricks-dbsql

# 3) Validate SKILL.md's frontmatter and publish the name/description,
#    which makes the skill discoverable to agents
databricks ai-gateway finalize-skill skills/<catalog>.databricks_skills.databricks-dbsql

# Show the skill's metadata (owner, description, finalize time) as JSON
databricks ai-gateway get-skill skills/<catalog>.databricks_skills.databricks-dbsql -o json
```

> On camera: switch to **Catalog Explorer → <catalog> → databricks_skills** and open the
> skill. Show Overview, the files, and the **Permissions** tab. Point out you are the
> owner and it's **private until shared**.

---

## 7. Publish in bulk with the helper scripts

`scripts/publish-skill.sh` wraps the three calls above (skips `create` if the skill already
exists, strips `.git`/`.DS_Store`). `scripts/publish-repo.sh` loops over a folder.

```bash
# Make the helper scripts executable
chmod +x scripts/*.sh

# Publish every skill folder in the official Databricks repo into databricks_skills
./scripts/publish-repo.sh sources/databricks-agent-skills/skills <catalog>.databricks_skills

# Publish only the named skills from central-skill-repo (it has 100+) into central_skills
./scripts/publish-repo.sh sources/central-skill-repo <catalog>.central_skills \
  system-design api-design-reviewer database-designer slo-architect \
  langgraph-human-in-the-loop huggingface-papers

# List the skills now in the central_skills schema
databricks ai-gateway list-skills schemas/<catalog>.central_skills -o json
```

---

## 8. Share (govern) a skill

Skills are private to the owner until granted. A consumer needs:

- `USE CATALOG` on `<catalog>`
- `USE SCHEMA` on the schema
- `READ VOLUME` on the skill

**UI (documented path):** Catalog → `<catalog>` → schema → skill → **Permissions** →
**Grant** → user or group → check `READ VOLUME` → **OK**. Revoke from the same tab.

**CLI:** skills are their own securable type, `skill`:

```bash
# Show who has access to the skill. {} means nobody but the owner, so it's private.
databricks grants get skill <catalog>.central_skills.system-design

# Give the data-team group READ VOLUME, which lets them read and use the skill
databricks grants update skill <catalog>.central_skills.system-design \
  --json '{"changes":[{"principal":"data-team","add":["READ_VOLUME"]}]}'
```

**SQL for the catalog/schema part:**

```sql
GRANT USE CATALOG ON CATALOG `<catalog>` TO `data-team`;
GRANT USE SCHEMA  ON SCHEMA  `<catalog>`.central_skills TO `data-team`;
```

> Talking points: grants work across every workspace on the same metastore. Cross-metastore
> / cross-account sharing goes through OpenSharing (Beta, read-only) or Marketplace. Every
> read is in the UC audit log, just like a table.

---

## 9. Use the skills from a coding agent

**List / discover**

```bash
# Show the skills ug has configured for your agents, and how each was added (download or MCP)
ug skills list
```

Then inside the agent (`ug claude`):

> "List the skills in `<catalog>.central_skills`."

Only skills you have privileges on come back. Empty list = no privileges or nothing published.

**Three ways to consume**

| Method | Command | Persists | Offline | Updates |
|---|---|---|---|---|
| One session | ask the agent: *"use `<catalog>.central_skills.system-design`"* | No | No | Current version |
| Download | `ug skills add --names <catalog>.central_skills.system-design` | Yes | Yes | Re-download |
| Live (MCP) | `ug skills add --location <catalog>.central_skills --via mcp` | Yes | No | Always latest |

```bash
# Download two specific skills into the agent's skill folders (comma-separated, full names)
ug skills add --names <catalog>.central_skills.system-design,<catalog>.central_skills.slo-architect

# Download every skill in a schema
ug skills add --location <catalog>.databricks_skills

# Or connect a whole schema live over MCP instead of downloading: the agent always gets
# the latest published version, but needs a network connection
ug skills add --location <catalog>.central_skills --via mcp

# Start (or restart) Claude Code through Unity Gateway so it loads the new skills
ug claude
```

Downloaded skills land in `.claude/skills/` and `.agents/skills/`.

Clean up locally (the published skills in UC are untouched):

```bash
# Pick downloaded skills to delete from your local skill folders
ug skills remove

# Pick schemas to disconnect from the agent's skills MCP connection
ug skills remove --via mcp
```

---

## 10. Live demo: author and publish a brand-new skill

The demo skill lives in `skills/yt-commit-style/`. It's deliberately easy to verify on
camera: any commit message the agent writes gets an emoji type prefix and a
`Reviewed-by: uc-skills-demo` footer.

```
skills/yt-commit-style/
├── SKILL.md
└── references/examples.md
```

```bash
# Show the skill's instructions
cat skills/yt-commit-style/SKILL.md

# Publish it: the script runs create-skill, then fs cp, then finalize-skill
./scripts/publish-skill.sh skills/yt-commit-style <catalog>.demo_skills.yt-commit-style

# Confirm it's registered and finalized in UC
databricks ai-gateway get-skill skills/<catalog>.demo_skills.yt-commit-style -o json

# Download it into Claude Code's skill folders, then start Claude Code through Unity Gateway
ug skills add --names <catalog>.demo_skills.yt-commit-style
ug claude
#   > "write a commit message for adding a README"
#   → 📝 docs(readme): ... + Reviewed-by: uc-skills-demo
```

**Update loop (show versioning-by-republish):** edit `SKILL.md` (e.g. change the footer to
`Reviewed-by: uc-skills-demo-v2`), re-run the same publish command. Ownership and grants
are kept. An agent using `--via mcp` picks up the new version on its next session; a
downloaded copy needs `ug skills add` again.

> Heads-up: re-publishing doesn't delete remote files you removed locally. Delete them with
> `databricks fs rm dbfs:/Skills/<catalog>/<schema>/<skill>/<file>` before finalizing.

---

## 11. Bonus: publish from GitHub automatically

For a team repo, the `databricks/unity-gateway` GitHub Action publishes every
`skills/<name>/SKILL.md` on merge to `main`, using a service principal over OIDC (no
secrets). Minimal workflow (`.github/workflows/publish-skills.yml`):

```yaml
name: Publish skills to Databricks
on:
  push:
    branches: [main]
    paths: ['skills/**', '.github/workflows/publish-skills.yml']
permissions:
  contents: read
  id-token: write
jobs:
  publish:
    runs-on: ubuntu-latest
    environment: production
    env:
      DATABRICKS_AUTH_TYPE: github-oidc
      DATABRICKS_HOST: ${{ vars.DATABRICKS_HOST }}
      DATABRICKS_CLIENT_ID: ${{ vars.DATABRICKS_CLIENT_ID }}
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4.3.1
        with:
          persist-credentials: false
      - uses: databricks/unity-gateway/actions/publish-skills@main
        with:
          skills-directory: skills
          target-schema: <catalog>.central_skills
```

Can't add a workflow to the source repo? Use the "Sync a Git repo of skills to a Unity
Catalog schema" notebook on a schedule instead (it creates/updates, never deletes).

---

## 12. Cleanup

```bash
# Delete the skill from UC (its stored files are removed in the background)
databricks ai-gateway delete-skill skills/<catalog>.demo_skills.yt-commit-style

# Delete the schema; --force deletes it even if it still contains objects
databricks schemas delete <catalog>.demo_skills --force
```

---

## Command cheat sheet

| Task | Command |
|---|---|
| Install ug | `uv tool install git+https://github.com/databricks/unity-gateway` |
| Connect agent (your Claude plan) | `ug configure --user --agents claude --provider <cat>.<sch>.<service>` |
| Connect agent (workspace-billed) | `ug configure --agents claude --workspace https://<host>` |
| Create skill | `databricks ai-gateway create-skill schemas/<cat>.<sch> <skill>` |
| Upload bundle | `databricks fs cp -r --overwrite <dir> dbfs:/Skills/<cat>/<sch>/<skill>` |
| Finalize | `databricks ai-gateway finalize-skill skills/<cat>.<sch>.<skill>` |
| List | `databricks ai-gateway list-skills schemas/<cat>.<sch>` |
| Get | `databricks ai-gateway get-skill skills/<cat>.<sch>.<skill>` |
| Delete | `databricks ai-gateway delete-skill skills/<cat>.<sch>.<skill>` |
| Download to agent | `ug skills add --names <cat>.<sch>.<skill>` |
| Live via MCP | `ug skills add --location <cat>.<sch> --via mcp` |
| MCP URL | `https://<host>/ai-gateway/skills/?schema=<cat>.<sch>` |
