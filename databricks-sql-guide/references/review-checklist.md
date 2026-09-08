# Databricks SQL review checklist

Apply only rules relevant to the query. Correctness and stated user requirements take
precedence over style.

## Correctness

- Preserve output grain, join semantics, filters, and null handling.
- Qualify ambiguous columns in joins.
- Flag potentially many-to-many joins and nondeterministic ordering when they affect
  the result.
- Do not guess column names, partition columns, or table properties. Inspect metadata
  when tools are available; otherwise state what must be confirmed.

## Readability

- Use `snake_case` for new aliases and CTE names.
- Prefer descriptive, named CTEs over deeply nested subqueries when they clarify the
  transformation.
- Use explicit join types and readable aliases.
- Keep comments for non-obvious business logic, not line-by-line narration.

## Efficiency

- List required columns instead of using `SELECT *` in production queries.
- Push selective filters close to the source when semantics allow.
- Filter on partition columns when known and relevant; never assert that a column is
  partitioned without metadata.
- Avoid repeated scans of the same expensive subquery when a reusable CTE or temporary
  result is clearer.
- Avoid unnecessary `DISTINCT`, global sorts, and cross joins.

## Databricks SQL conventions

- Use backticks for identifiers containing spaces, hyphens, reserved words, or other
  special characters.
- Prefer built-in Databricks SQL functions over Python UDFs for SQL-only work.
- Use `LIMIT` for exploratory previews, but do not add it when the complete result is
  required.

## Review response

Return the revised query first. Then report findings by severity:

- **Correctness**: changes needed to make results reliable.
- **Performance**: changes likely to reduce work or data scanned.
- **Maintainability**: naming, structure, and clarity improvements.

Omit empty categories and keep the explanation proportional to the query.
