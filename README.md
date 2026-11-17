# UC Skills demo

Publish agent skills to Unity Catalog as governed `catalog.schema.skill` objects, then use them
in Claude Code through the Unity Gateway CLI (`ug`). Unity Gateway skills are in Beta.

## Contents

| Path | What it is |
|---|---|
| [`LIVE_DEMO.md`](LIVE_DEMO.md) | The on-camera run: upload `yt-commit-style`, use it via `ug` |
| [`REHEARSAL.md`](REHEARSAL.md) | Automated end-to-end check (`./scripts/rehearse.sh`) |
| [`TUTORIAL.md`](TUTORIAL.md) | Full reference: bulk publishing, sharing, GitHub Action, cheat sheet |
| `skills/` | Demo skills: `yt-commit-style` (live), `uc-rehearsal-check` (rehearsal) |
| `scripts/` | `publish-skill.sh`, `publish-repo.sh`, `rehearse.sh` |

## Two CLIs, two directions

| | Databricks CLI (`databricks`) | Unity Gateway CLI (`ug`) |
|---|---|---|
| Direction | Your machine → **into** Unity Catalog | Unity Catalog → **out to** your coding agent |
| Use it to | Create schemas, publish skills (create, upload, finalize), update, delete, grant access, list what's published | Connect your agent to the workspace, download skills or connect them over MCP, launch the agent |
| Key commands | `ai-gateway create-skill`, `fs cp`, `ai-gateway finalize-skill`, `ai-gateway list-skills`, `grants update skill` | `ug configure`, `ug skills add`, `ug skills list`, `ug skills remove`, `ug claude` |
| Who runs it | Skill authors and admins | Anyone using skills in their agent |

`ug` can't publish skills, and `databricks` doesn't configure agents. Rule of thumb: **changing
what's in UC → `databricks`; changing what your agent sees → `ug`.**

Two listing commands, easy to mix up:

```bash
# databricks: what's PUBLISHED in a UC schema (only skills you have access to)
databricks ai-gateway list-skills schemas/<catalog>.demo_skills

# ug: what's CONFIGURED for your agents on THIS machine, and how each was added
ug skills list
```

## Setup

1. **Enable the preview:** a workspace admin turns on *Unity Gateway skills in Genie*
   ([Manage previews](https://docs.databricks.com/aws/en/admin/workspace-settings/manage-previews)).
2. **Install the CLIs:** Databricks CLI v1.21+ and `ug`
   ([ug CLI reference](https://docs.databricks.com/aws/en/ai-gateway/coding-agent-ug-cli)).
   ```bash
   # Install the Unity Gateway CLI (ug) from GitHub as an isolated uv tool
   uv tool install git+https://github.com/databricks/unity-gateway

   # Sign in to the workspace in the browser and save the credentials as profile "<profile>"
   databricks auth login --host https://<workspace-host> --profile <profile>
   ```
3. **Create a model provider service for your Claude subscription** (one-time, admin)
   ([Create a model provider service](https://docs.databricks.com/aws/en/ai-gateway/create-model-provider-services#use-each-callers-claude-or-chatgpt-subscription),
   [Claude Max / Enterprise support](https://docs.databricks.com/aws/en/ai-gateway/claude-max-anthropic-enterprise-support)).
   ```bash
   # Anthropic provider in "relayed" mode: stores no API key and forwards each caller's own
   # Claude login. allow_all_targets exposes every Claude model.
   databricks ai-gateway create-model-provider-service schemas/<catalog>.default claude_subscription \
     --json '{"config":{"provider_type":"EXTERNAL_MODEL_PROVIDER_TYPE_ANTHROPIC","anthropic":{"relayed":{}},"allow_all_targets":true}}'
   ```
4. **Connect Claude Code** ([Use Claude Code with Unity Gateway](https://docs.databricks.com/aws/en/ai-gateway/coding-agent-claude)).
   ```bash
   # Point Claude Code at the service. --user writes user-level settings only;
   # --provider bills model requests to your Claude subscription.
   ug configure --user --agents claude --provider <catalog>.default.claude_subscription --profile <profile>
   ```

> **Billing:** with `--provider`, model requests are billed to your Claude subscription. A plain
> `ug configure` routes Claude Code to Databricks-hosted models billed to the workspace, and
> writes machine-wide settings. Undo either with `ug revert`.

## Publish and use a skill

```bash
# Use your Databricks CLI profile for every databricks command in this shell
export DATABRICKS_CONFIG_PROFILE=<profile>

# Create a schema to hold the skill (usage: <schema> <catalog>)
databricks schemas create demo_skills <catalog>

# Register the skill as a UC securable and set up its storage (empty, private, you own it)
databricks ai-gateway create-skill schemas/<catalog>.demo_skills yt-commit-style

# Upload the skill folder (SKILL.md + supporting files) into that storage
databricks fs cp -r --overwrite skills/yt-commit-style dbfs:/Skills/<catalog>/demo_skills/yt-commit-style

# Validate SKILL.md and publish it, so agents can discover it
databricks ai-gateway finalize-skill skills/<catalog>.demo_skills.yt-commit-style

# Download the published skill into Claude Code's skill folders
ug skills add --names <catalog>.demo_skills.yt-commit-style

# Confirm the agent has it: shows NAME, LOCATION (UC schema), VIA (local = downloaded), AGENTS
ug skills list

# Start Claude Code through Unity Gateway; it loads the skill at startup
ug claude
```

## Docs

- [Unity Gateway skills overview](https://docs.databricks.com/aws/en/agents/uc-skills/)
- [Create and share skills](https://docs.databricks.com/aws/en/agents/uc-skills/create-share-uc-skills)
- [Use skills from a coding agent](https://docs.databricks.com/aws/en/agents/uc-skills/use-uc-skills)
- [Model provider services](https://docs.databricks.com/aws/en/ai-gateway/model-provider-services)
- [unity-gateway on GitHub](https://github.com/databricks/unity-gateway)
- Sample skills: [databricks-agent-skills](https://github.com/databricks/databricks-agent-skills), [central-skill-repo](https://github.com/RamVegiraju/central-skill-repo)
