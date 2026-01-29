---
name: ck-orchestrator
description: Team lead for codebase knowledge acquisition. Coordinates autonomous specialist skills to build deep, persistent expertise. Use when asked to "learn the codebase", "build expertise", "understand the project", when starting work on unfamiliar code, or when evaluating requirements across multiple domains.
---

# Codebase Knowledge Orchestrator

Coordinate a team of autonomous specialists that evaluate, research, guard, and evolve codebase knowledge.

## Team Structure

| Skill | Role | Capabilities |
|-------|------|--------------|
| `ck-orchestrator` (this) | Team lead | Routes, coordinates, maintains index |
| `ck-architect` | Technical expert | Architecture, patterns, cross-cutting concerns |
| `ck-domain-{name}` | Domain specialists | Evaluate, research, guard, evolve their domain |
| `ck-domain-creator` | Spawns experts | Creates new domain specialists on demand |

## What Domain Experts Do

Domain experts are NOT passive documentation. They are autonomous specialists that:

1. **Evaluate** - Assess new requirements against domain principles
2. **Research** - Investigate domain questions systematically
3. **Guard** - Prevent violations of domain rules
4. **Evolve** - Track improvements and technical debt

## Directory Structure

```
.claude/
├── ck-orchestrator/          # This skill (team lead)
├── ck-architect/             # Technical expert (singleton)
├── ck-domain-creator/        # Creates domain experts
├── ck-domain-{name}/         # Autonomous domain specialists
│   ├── SKILL.md              # Expert behavior
│   └── references/
│       ├── current-state.md  # Facts
│       ├── principles.md     # Rules
│       └── evolution.md      # Roadmap
└── experts/
    └── _index.md             # Team registry
```

## Workflows

### Initial Learning ("learn the codebase")

1. Create `.claude/experts/_index.md` if missing
2. Analyze codebase to identify major domains
3. For each significant domain:
   - Invoke `ck-domain-creator` to spawn specialist
   - Have specialist bootstrap its knowledge (investigate, not just document)
4. Invoke `ck-architect` to capture architecture
5. Update `_index.md` with team registry

### Route to Specialists

**Before working on code**:
1. Identify which domain(s) are involved
2. Invoke relevant domain expert(s) to:
   - Brief you on current state
   - Warn about principles/constraints
   - Flag known issues

**When evaluating a requirement**:
1. Route to relevant domain expert for evaluation
2. If cross-domain: gather evaluations from each, then synthesize
3. If architectural: include `ck-architect` assessment

**After completing work**:
1. Route learnings to appropriate specialist:
   - Domain-specific → `ck-domain-{name}` to evolve
   - Cross-cutting → `ck-architect`
2. Have specialist decide what to update

### Spawn New Expert

When encountering unfamiliar territory:
1. Check if domain expert exists
2. If not, assess: Is this domain complex enough?
   - Has its own rules/patterns → yes, create expert
   - Just a few files, no special rules → no, note in architect
3. Invoke `ck-domain-creator` if needed

### Cross-Domain Coordination

When work spans multiple domains:
1. Identify all involved domain experts
2. Gather each expert's evaluation/concerns
3. Check `ck-architect` for integration patterns
4. Synthesize a coordinated approach
5. After work: have each expert evolve their knowledge

### Periodic Team Review

When asked to "review expertise" or "sync team":
1. For each domain expert:
   - Run self-improvement workflow
   - Check for stale knowledge
   - Verify principles still hold
2. Check architect for pattern updates
3. Identify knowledge gaps
4. Update `_index.md`

## Index Template

Create `.claude/experts/_index.md`:

```markdown
---
name: _index
description: Codebase knowledge team registry
last_updated: [TODAY]
---

# Knowledge Team Index

## Project Overview
[One paragraph about what this project does]

## Team Registry

### Domain Experts
| Domain | Specialist | Capabilities | Last Active | Health |
|--------|------------|--------------|-------------|--------|
| [domain] | `ck-domain-{name}` | evaluate, research, guard, evolve | [date] | 🟢/🟡/🔴 |

### Technical Expert
- **Specialist**: `ck-architect`
- **Owns**: Architecture, patterns, cross-cutting, tech debt

## Coverage Gaps
- [ ] [Domains needing specialists]

## Cross-Domain Insights
- [Date]: [Insight that spans multiple domains]
```

## Coordination Rules

1. **One domain = one expert**: Never duplicate coverage
2. **Experts are autonomous**: They decide what to learn, not just store
3. **Architect owns technical**: All cross-cutting concerns → architect
4. **Evaluate before implement**: Route requirements through experts first
5. **Evolve after every task**: Specialists learn from every interaction
