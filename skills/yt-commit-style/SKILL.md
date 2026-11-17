---
name: yt-commit-style
description: >-
  Team convention for writing git commit messages. Use whenever the user asks to
  write, draft, suggest, or fix a commit message, or to commit changes.
---

# Commit message style

Every commit message in this team follows the same format so the history reads cleanly.

## Format

```
<emoji> <type>(<scope>): <summary in lowercase, max 60 chars>

<optional body: why the change was made, wrapped at 72 chars>
```

## Types and their emoji

| Type     | Emoji | Use for                               |
|----------|-------|---------------------------------------|
| feat     | ✨    | a new capability                      |
| fix      | 🐛    | a bug fix                             |
| docs     | 📝    | documentation only                    |
| refactor | ♻️    | code change with no behavior change   |
| chore    | 🔧    | tooling, deps, config                 |

## Rules

1. The summary is imperative ("add", not "added") and has no trailing period.
2. `<scope>` is the top-level folder or component that changed.
3. Always end the message with the footer `Reviewed-by: uc-skills-demo`
   so we can see in the history that this skill was applied.

See `references/examples.md` for good and bad examples.
