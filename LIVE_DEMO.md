# Live demo: upload a skill to UC, use it from Claude Code via `ug`

**Story:** write a tiny skill → publish it to Unity Catalog → pull it into Claude Code with `ug` → watch it work.

| | |
|---|---|
| Skill | `skills/yt-commit-style/` |
| Target | `<catalog>.demo_skills.yt-commit-style` |
| Models | Your own Claude subscription, via `<catalog>.default.claude_subscription` |

---

## 0. One-time setup (already done, off camera)

Docs: [Create a model provider service](https://docs.databricks.com/aws/en/ai-gateway/create-model-provider-services#use-each-callers-claude-or-chatgpt-subscription) ·
[Claude Max / Enterprise support](https://docs.databricks.com/aws/en/ai-gateway/claude-max-anthropic-enterprise-support) ·
[Use Claude Code with Unity Gateway](https://docs.databricks.com/aws/en/ai-gateway/coding-agent-claude)

```bash
# Admin: create a UC model provider service for Anthropic in "relayed" mode. It stores no
# API key; it forwards each caller's own Claude login. allow_all_targets exposes all Claude models.
databricks ai-gateway create-model-provider-service schemas/<catalog>.default claude_subscription \
  --json '{"config":{"provider_type":"EXTERNAL_MODEL_PROVIDER_TYPE_ANTHROPIC","anthropic":{"relayed":{}},"allow_all_targets":true}}'

# You: point Claude Code at that service. --user keeps the settings user-level (nothing
# machine-wide); --provider bills model requests to your Claude subscription.
ug configure --user --agents claude --provider <catalog>.default.claude_subscription --profile <profile>
```

> Why this matters: a plain `ug configure` routes Claude Code to Databricks-hosted models
> (billed to the workspace) through machine-wide settings. With `--provider`, requests are
> **billed to your Claude subscription**.

Before recording:

```bash
# Use your Databricks CLI profile for every databricks command in this shell
export DATABRICKS_CONFIG_PROFILE=<profile>

# Go to the project folder (the scripts and skill paths are relative to it)
cd uc-skills-sample

# Confirm no skills are configured yet, so the demo starts clean
ug skills list
```

---

## 1. Show the skill (30s)

```bash
# Print the skill: YAML frontmatter (name, description), then the instructions
cat skills/yt-commit-style/SKILL.md
```

Point out: a folder + `SKILL.md` with `name` and `description` in the frontmatter, plus an
optional `references/` file.

## 2. Create a schema for it

```bash
# Create the demo_skills schema in the <catalog> catalog (usage: <schema> <catalog>)
databricks schemas create demo_skills <catalog>
```

## 3. Upload it to Unity Catalog: three commands

```bash
# 1) Register <catalog>.demo_skills.yt-commit-style as a UC securable and set up its
#    managed storage. You become the owner; it's private and empty for now.
databricks ai-gateway create-skill schemas/<catalog>.demo_skills yt-commit-style

# 2) Upload the local folder (SKILL.md + references/) into that storage.
#    -r copies the whole folder; --overwrite replaces files already there.
databricks fs cp -r --overwrite skills/yt-commit-style dbfs:/Skills/<catalog>/demo_skills/yt-commit-style

# 3) Validate SKILL.md's frontmatter and publish the name/description,
#    which makes the skill discoverable to agents
databricks ai-gateway finalize-skill skills/<catalog>.demo_skills.yt-commit-style
```

Line to use on camera: *"create the shell, fill it with files, seal it."*

## 4. Show it in Catalog Explorer

Open **Catalog → <catalog> → demo_skills → yt-commit-style**. Show the files and the
**Permissions** tab: you're the owner, and the skill is private until shared.

## 5. Add it to Claude Code with `ug`

```bash
# Download the skill from UC into Claude Code's skill folders (~/.claude/skills, ~/.agents/skills)
ug skills add --names <catalog>.demo_skills.yt-commit-style

# Confirm it's configured, and see how it was added (downloaded)
ug skills list

# Start Claude Code through Unity Gateway; it loads the new skill at startup
ug claude
```

If Claude Code asks you to log in, pick **Option 1 – Claude account with subscription**.

In the session:

> write a commit message for adding a README

Expected: `📝 docs(readme): ...` ending with `Reviewed-by: uc-skills-demo`.

## 6. (Optional) Update it

Change the footer in `SKILL.md` to `uc-skills-demo-v2`, then:

```bash
# Re-upload the edited files over the published copy
databricks fs cp -r --overwrite skills/yt-commit-style dbfs:/Skills/<catalog>/demo_skills/yt-commit-style

# Re-finalize so UC reads the new SKILL.md (ownership and grants stay the same)
databricks ai-gateway finalize-skill skills/<catalog>.demo_skills.yt-commit-style

# Downloaded copies are snapshots, so download again to get the new version
ug skills add --names <catalog>.demo_skills.yt-commit-style
```

Restart `ug claude` and ask again. The new footer shows up.

---

## Reset (to film again)

```bash
# Delete the downloaded copy from Claude Code's skill folders (UC is untouched)
ug skills remove --names <catalog>.demo_skills.yt-commit-style

# Delete the skill from UC
databricks ai-gateway delete-skill skills/<catalog>.demo_skills.yt-commit-style

# Delete the schema; --force deletes it even if it still contains objects
databricks schemas delete <catalog>.demo_skills --force
```

## Undo the ug setup entirely

```bash
# Restore the agent config files ug backed up, and clear ug's saved setup
ug revert
```
