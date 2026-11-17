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
# Admin: a model provider service that relays each caller's own Claude subscription
databricks ai-gateway create-model-provider-service schemas/<catalog>.default claude_subscription \
  --json '{"config":{"provider_type":"EXTERNAL_MODEL_PROVIDER_TYPE_ANTHROPIC","anthropic":{"relayed":{}},"allow_all_targets":true}}'

# You: point ug at it — user-level only, no machine-wide settings, no Databricks-billed models
ug configure --user --agents claude --provider <catalog>.default.claude_subscription --profile <profile>
```

> Why this matters: a plain `ug configure` routes Claude Code to Databricks-hosted models
> (billed to the workspace) through machine-wide settings. With `--provider`, requests are
> **billed to your Claude subscription**.

Before recording:

```bash
export DATABRICKS_CONFIG_PROFILE=<profile>
cd uc-skills-sample
ug skills list          # should say "No skills configured"
```

---

## 1. Show the skill (30s)

```bash
cat skills/yt-commit-style/SKILL.md
```

Point out: a folder + `SKILL.md` with `name` and `description` in the frontmatter, plus an
optional `references/` file.

## 2. Create a schema for it

```bash
databricks schemas create demo_skills <catalog>
```

## 3. Upload it to Unity Catalog: three commands

```bash
# Register the securable
databricks ai-gateway create-skill schemas/<catalog>.demo_skills yt-commit-style

# Upload the files
databricks fs cp -r --overwrite skills/yt-commit-style dbfs:/Skills/<catalog>/demo_skills/yt-commit-style

# Validate SKILL.md and publish
databricks ai-gateway finalize-skill skills/<catalog>.demo_skills.yt-commit-style
```

Line to use on camera: *"create the shell, fill it with files, seal it."*

## 4. Show it in Catalog Explorer

Open **Catalog → <catalog> → demo_skills → yt-commit-style**. Show the files and the
**Permissions** tab: you're the owner, and the skill is private until shared.

## 5. Add it to Claude Code with `ug`

```bash
ug skills add --names <catalog>.demo_skills.yt-commit-style
ug skills list
ug claude
```

If Claude Code asks you to log in, pick **Option 1 – Claude account with subscription**.

In the session:

> write a commit message for adding a README

Expected: `📝 docs(readme): ...` ending with `Reviewed-by: uc-skills-demo`.

## 6. (Optional) Update it

Change the footer in `SKILL.md` to `uc-skills-demo-v2`, then:

```bash
databricks fs cp -r --overwrite skills/yt-commit-style dbfs:/Skills/<catalog>/demo_skills/yt-commit-style
databricks ai-gateway finalize-skill skills/<catalog>.demo_skills.yt-commit-style
ug skills add --names <catalog>.demo_skills.yt-commit-style    # re-download
```

Restart `ug claude` and ask again. The new footer shows up.

---

## Reset (to film again)

```bash
ug skills remove --names <catalog>.demo_skills.yt-commit-style
databricks ai-gateway delete-skill skills/<catalog>.demo_skills.yt-commit-style
databricks schemas delete <catalog>.demo_skills --force
```

## Undo the ug setup entirely

```bash
ug revert
```
