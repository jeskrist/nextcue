# Architecture

> Keep this current. If the structure below no longer matches the repo, update it as part of your task (see Rules).

## Overview

One or two sentences: what this project does and the overall shape (e.g. "A REST API + worker service. Requests come in through `src/api/`, get validated, then queued for `src/workers/` to process asynchronously.").

## Top-level layout

| Path | Purpose |
|---|---|
| `src/api/` | HTTP route handlers. Thin — validation + calling services, no business logic here. |
| `src/services/` | Business logic. This is where most feature work happens. |
| `src/models/` | Database models / ORM schemas. |
| `src/workers/` | Background job processors. |
| `src/lib/` | Shared utilities (logging, auth helpers, etc). |
| `tests/` | Mirrors `src/` structure — see Rules for naming convention. |
| `docs/` | Deep-dive docs (deployment, data flow diagrams, ADRs). |
| `scripts/` | One-off / maintenance scripts, not part of the app itself. |

*(Replace this table with your actual folders — this is just a shape to copy.)*

## Entry points for common tasks

- **New API endpoint** → add route in `src/api/`, logic in `src/services/`, model changes (if any) in `src/models/`.
- **New background job** → add to `src/workers/`, register it in `src/workers/index.ts`.
- **New CLI flag / config option** → `src/config.ts`, then update `README.md` Usage section.

*(This section is the highest-value part — it tells the agent exactly where to go instead of searching.)*

## Data flow (optional, for non-trivial systems)

Briefly describe how a request/event moves through the system end to end. A short paragraph or simple diagram is enough — this isn't meant to replace `docs/`.

## Conventions worth knowing

- Naming conventions, error-handling patterns, or anything a newcomer (human or agent) would otherwise have to infer by reading multiple files.
