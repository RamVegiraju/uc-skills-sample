---
name: databricks-sql-guide
description: Review and improve Databricks SQL for readability, efficiency, and team conventions. Use when writing or reviewing Databricks SQL queries; do not use for non-SQL code or changing business requirements.
---

# Databricks SQL guide

Write or revise the query without changing its intended business meaning.

For a review, read [references/review-checklist.md](references/review-checklist.md),
then:

1. Identify concrete issues, prioritizing correctness and avoidable scan cost.
2. Return a corrected query in a `sql` code block.
3. Follow it with a concise findings list explaining material changes.
4. Call out assumptions or missing schema information instead of inventing columns,
   partition keys, or table properties.

When authoring a new query, apply the same checklist while preserving the requested
output grain, filters, and null behavior.
