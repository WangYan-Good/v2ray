# Documentation

This directory is organized by product and engineering concern. Keep active, decision-useful documents in the numbered folders, and move historical notes or superseded drafts to `11-archive`.

Chinese documents are the canonical active docs for this project. English mirror drafts are intentionally not kept unless they contain unique content.

## Directory Map

| Directory | Purpose |
| --- | --- |
| `00-overview` | Project entry points, glossary, and high-level summaries. |
| `01-product` | PRDs, requirements, user journeys, and scope decisions. |
| `02-ui` | UI or interaction notes. Mostly unused while this project remains CLI-first. |
| `03-architecture` | System design, runtime model, and major technical boundaries. |
| `04-backend` | Core implementation notes for the CLI, installers, config generation, and service integration. |
| `05-ai` | AI-related design notes. Currently reserved. |
| `06-frontend` | Frontend or web console notes. Currently reserved. |
| `07-data` | Data model, config schema, generated artifacts, and migration notes. |
| `08-ops` | Release, deployment, certificate, systemd, and server operations docs. |
| `09-testing` | Test strategy, CI contracts, and manual verification playbooks. |
| `10-project-management` | Roadmaps, refactor plans, decisions, and project tracking. |
| `11-archive` | Historical logs, old drafts, and context retained for reference only. |

## Current Key Documents

- Product requirements: `01-product/prd-zh.md`
- System design: `03-architecture/system-design-zh.md`
- Command matrix: `04-backend/command-matrix.md`
- Protocol contracts: `07-data/protocol-contracts.md`
- Release guide: `08-ops/release-guide.md`
- Test strategy: `09-testing/test-strategy.md`
- Go refactor plan: `10-project-management/go-refactor-plan.md`
- Phase 0 baseline plan: `10-project-management/phase-0-baseline-plan.md`

## Maintenance Rules

- Prefer one canonical Chinese document for active project work. Keep English versions only when they are actively useful.
- Archive dated logs and one-off investigation notes after their conclusions are reflected in active docs or code.
- Empty folders are intentional placeholders for future work; do not fill them with low-signal notes.
