# Governed Agent Skill with Unity Catalog

This sample shows the complete lifecycle of a small, portable
[Agent Skill](https://agentskills.io/home): develop it locally, publish it as a
governed `catalog.schema.skill`, share it with Unity Catalog permissions, and load
it into an MCP-capable coding agent.

The example skill reviews Databricks SQL for correctness, efficiency, and shared
team conventions. It contains no workspace URL, profile, catalog, schema, user, or
credential. You supply those values when configuring or publishing it.

> Unity Catalog Skills are currently in Beta. An account administrator must enable
> the Unity AI preview before skills can be created or used.

## Repository layout

```text
databricks-sql-guide/
├── SKILL.md
└── references/
    └── review-checklist.md
```

| Path | Purpose |
| --- | --- |
| `databricks-sql-guide/SKILL.md` | Skill metadata, activation description, and workflow |
| `databricks-sql-guide/references/review-checklist.md` | Detailed rules loaded only during a SQL review |

This separation demonstrates progressive disclosure: agents discover the skill from
its name and description, load `SKILL.md` when it matches a request, and read the
checklist only when needed.

## Try it locally

Copy or link `databricks-sql-guide/` into the skills directory used by your coding
agent. Agents that follow the open format commonly discover project skills from
`.agents/skills/`.

Then ask:

```text
Review this Databricks SQL using our SQL guide and return a corrected query:

SELECT *
FROM samples.nyctaxi.trips
WHERE trip_distance > 5
```

The skill should identify `SELECT *`, preserve the query's meaning, and return a
corrected query plus a short findings list. For a real table, it should inspect the
schema before expanding `*` rather than inventing column names.

## Publish to Unity Catalog

The current Databricks workflow uses the open-source `ucode` client and the
`databricks-skill-registry` MCP server.

### Prerequisites

- Python 3.12+ and `uv`
- An MCP-capable agent such as Codex
- A Unity Catalog-enabled workspace with the Unity AI preview enabled
- `USE SCHEMA` and `CREATE VOLUME` on the target schema

### Choose your values

| Placeholder | Example shape | Meaning |
| --- | --- | --- |
| `<workspace-host>` | `your-workspace.cloud.databricks.com` | Hostname only; do not include a path |
| `<catalog>` | `skills` | Standard Unity Catalog catalog with managed storage |
| `<schema>` | `sql_skills` | Schema that will govern the published skill |

Do not commit authentication tokens or replace these placeholders in this repository.
`ucode` performs interactive browser authentication on each user's machine.

### Connect your coding agent

Install and connect `ucode` (replace the host; browser sign-in is interactive):

```bash
uv tool install git+https://github.com/databricks/ucode
ucode configure --agents codex --workspaces https://<workspace-host>
ucode configure skills
```

Restart the agent with `ucode codex` so it loads the newly registered
`databricks-skill-registry` MCP server.

### Publish

Prompt the connected agent:

```text
Publish my ./databricks-sql-guide folder to the <catalog>.<schema> schema in Databricks.
```

The connected agent calls `create_skill`; future revisions use `update_skill`.
Publishing is intentionally not automated by this repository because catalog,
schema, workspace, and authorization are deployment choices.

## Share

The skill starts private to its owner. In Catalog Explorer, grant a consumer:

- `USE CATALOG` on the catalog
- `USE SCHEMA` on the schema
- `READ VOLUME` on the skill

Sharing is a grant, not a copy. The consumer always remains subject to Unity Catalog
authorization and audit.

## Consume

A consumer can ask a connected agent to load
`<catalog>.<schema>.databricks-sql-guide` for one session. To download a point-in-time
copy for future sessions, run:

```bash
ucode configure skills --location <catalog>.<schema> --skill databricks-sql-guide
```

To expose every skill in a schema live and always use the newest published version:

```bash
ucode configure skills --location <catalog>.<schema> --mcp
```

Restart the coding agent after changing its downloaded or live skill configuration.

## Expected behavior

Given a Databricks SQL query, the sample skill should:

1. Preserve the requested business meaning and output grain.
2. Return the revised SQL before its findings.
3. Prioritize correctness, then avoidable scan cost, then maintainability.
4. Inspect available metadata or clearly identify unknowns instead of inventing
   columns, partition keys, or table properties.

## Sources

- [Databricks: Skills support in Unity Gateway](https://docs.databricks.com/aws/en/agents/uc-skills/)
- [Agent Skills open format](https://agentskills.io/home)
