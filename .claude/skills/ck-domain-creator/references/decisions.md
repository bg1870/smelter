---
name: domain-creator-decisions
description: Decision log for domain expert creation
last_updated: 2026-01-29
---

# Domain Expert Decisions

Record of all decisions about domain expert creation - both created and rejected.

## Active Domain Experts

| Domain | Created | Rationale | Covers |
|--------|---------|-----------|--------|

## Rejected Domains

| Domain | Evaluated | Reason | Alternative |
|--------|-----------|--------|-------------|

## Domain Boundaries

Clarifications on what belongs where when domains overlap:

| Topic | Belongs To | NOT To | Rationale |
|-------|------------|--------|-----------|

## Pending Evaluations

Domains flagged for future evaluation:

- <!-- Example: `notifications` - mentioned but not yet evaluated (2026-01-20) -->

## Decision Criteria Reference

Quick reference for consistent decisions:

### Create domain expert when:
- [ ] Domain has 3+ related files
- [ ] Domain has its own rules/principles
- [ ] Changes need specialized evaluation
- [ ] Knowledge needs to persist across sessions

### Do NOT create when:
- [ ] Trivial (< 3 files, no special rules)
- [ ] Already covered by existing expert
- [ ] Cross-cutting concern (→ ck-architect)
- [ ] Too generic (utils, helpers, common)
