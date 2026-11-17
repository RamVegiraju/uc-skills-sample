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

## Setup

1. **Enable the preview:** a workspace admin turns on *Unity Gateway skills in Genie*
   ([Manage previews](https://docs.databricks.com/aws/en/admin/workspace-settings/manage-previews)).
2. **Install the CLIs:** Databricks CLI v1.21+ and `ug`
   ([ug CLI reference](https://docs.databricks.com/aws/en/ai-gateway/coding-agent-ug-cli)).
   ```bash
   uv tool install git+https://github.com/databricks/unity-gateway
   databricks auth login --host https://<workspace-host> --profile <profile>
   ```
3. **Create a model provider service for your Claude subscription** (one-time, admin)
   ([Create a model provider service](https://docs.databricks.com/aws/en/ai-gateway/create-model-provider-services#use-each-callers-claude-or-chatgpt-subscription),
   [Claude Max / Enterprise support](https://docs.databricks.com/aws/en/ai-gateway/claude-max-anthropic-enterprise-support)).
   ```bash
   databricks ai-gateway create-model-provider-service schemas/<catalog>.default claude_subscription \
     --json '{"config":{"provider_type":"EXTERNAL_MODEL_PROVIDER_TYPE_ANTHROPIC","anthropic":{"relayed":{}},"allow_all_targets":true}}'
   ```
4. **Connect Claude Code** ([Use Claude Code with Unity Gateway](https://docs.databricks.com/aws/en/ai-gateway/coding-agent-claude)).
   ```bash
   ug configure --user --agents claude --provider <catalog>.default.claude_subscription --profile <profile>
   ```

> **Billing:** with `--provider`, model requests are billed to your Claude subscription. A plain
> `ug configure` routes Claude Code to Databricks-hosted models billed to the workspace, and
> writes machine-wide settings. Undo either with `ug revert`.

## Publish and use a skill

```bash
export DATABRICKS_CONFIG_PROFILE=<profile>
databricks schemas create demo_skills <catalog>
databricks ai-gateway create-skill schemas/<catalog>.demo_skills yt-commit-style
databricks fs cp -r --overwrite skills/yt-commit-style dbfs:/Skills/<catalog>/demo_skills/yt-commit-style
databricks ai-gateway finalize-skill skills/<catalog>.demo_skills.yt-commit-style

ug skills add --names <catalog>.demo_skills.yt-commit-style
ug claude
```

## Docs

- [Unity Gateway skills overview](https://docs.databricks.com/aws/en/agents/uc-skills/)
- [Create and share skills](https://docs.databricks.com/aws/en/agents/uc-skills/create-share-uc-skills)
- [Use skills from a coding agent](https://docs.databricks.com/aws/en/agents/uc-skills/use-uc-skills)
- [Model provider services](https://docs.databricks.com/aws/en/ai-gateway/model-provider-services)
- [unity-gateway on GitHub](https://github.com/databricks/unity-gateway)
- Sample skills: [databricks-agent-skills](https://github.com/databricks/databricks-agent-skills), [central-skill-repo](https://github.com/RamVegiraju/central-skill-repo)
