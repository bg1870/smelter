---
name: ck-domain-creator
description: Create new domain expert skills for codebase knowledge. Use when a new feature area is discovered that needs its own specialist, when asked to "create domain expert for X", when checking what domains exist and why, or when ck-orchestrator identifies a gap in domain coverage. Maintains decision history for all domain evaluations.
---

# Domain Expert Creator

Spawn autonomous domain expert skills and maintain decision memory about domain coverage.

## What is a Domain Expert?

A domain expert is NOT just documentation. It's an **autonomous specialist** that:

1. **Knows the current state** - What's working, what's broken, what's technical debt
2. **Evaluates changes** - Assess new requirements against learned knowledge
3. **Researches** - Knows how to investigate domain-related questions
4. **Evolves** - Plans and tracks how the domain should grow over time
5. **Guards quality** - Identifies violations of domain principles

## Decision Memory

All decisions about domain experts are recorded in `references/decisions.md`:
- **Active experts**: What was created, when, why, and what it covers
- **Rejected domains**: What was NOT created and why
- **Domain boundaries**: Clarifications on overlapping concerns
- **Pending evaluations**: Domains flagged for future review

**Always consult decisions.md before evaluating a domain** to avoid re-deciding.

## When to Create a Domain Expert

Create when:
- Feature is complex enough to warrant dedicated reasoning
- Domain has its own principles, patterns, or constraints
- Changes in this area need specialized evaluation
- Knowledge needs to persist and evolve across sessions

**Do NOT create** when:
- Feature is trivial (< 3 files, no special rules)
- Already covered by existing domain expert
- It's a cross-cutting concern (→ use `ck-architect`)

## Core Workflows

### Evaluate a Domain (before creating)

When asked to create a domain expert OR when encountering a new area:

1. **Check decision history**
   - Read `references/decisions.md`
   - Has this domain been evaluated before?
   - If rejected: review reason, has context changed?
   - If exists: clarify what's covered, maybe update scope

2. **Apply decision criteria**
   - [ ] Has 3+ related files?
   - [ ] Has its own rules/principles?
   - [ ] Changes need specialized evaluation?
   - [ ] Knowledge needs to persist?
   
3. **Check for overlap**
   - Could an existing expert cover this?
   - Is this really cross-cutting (→ architect)?
   - Would this split an existing domain?

4. **Decide and record**
   - If YES: proceed to creation, record in "Active Domain Experts"
   - If NO: record in "Rejected Domains" with reason and alternative
   - If UNCERTAIN: add to "Pending Evaluations"

### Create Domain Expert

Once decision is YES:

1. **Determine domain name** (kebab-case, descriptive)
2. **Create skill structure** (see below)
3. **Bootstrap initial knowledge** through investigation
4. **Record decision** in `references/decisions.md`
5. **Register with orchestrator**

### Query Existing Experts

When asked "what domains exist?" or "what does X cover?":

1. Read `references/decisions.md`
2. Return relevant information:
   - Active experts and their coverage
   - Why certain domains were rejected
   - Where boundaries lie between domains

### Update Domain Boundaries

When domain overlap or confusion is discovered:

1. Read current decisions
2. Add clarification to "Domain Boundaries" section
3. Update relevant domain experts' scope descriptions

## Skill Structure

```
.claude/ck-domain-{name}/
├── SKILL.md                    # Expert behavior and workflows
└── references/
    ├── current-state.md        # What exists now (facts)
    ├── principles.md           # How it SHOULD work (rules)
    └── evolution.md            # Where it's heading (roadmap)
```

## SKILL.md Template

```markdown
---
name: ck-domain-{name}
description: Domain expert for {Display Name}. Autonomous specialist that evaluates, researches, and evolves knowledge about {scope}. Use when working on {name} code, evaluating {name} requirements, researching {name} questions, or planning {name} improvements.
---

# {Display Name} Domain Expert

Autonomous specialist for the {name} domain.

## Capabilities

1. **Evaluate** - Assess changes/requirements against domain principles
2. **Research** - Investigate domain-related questions systematically
3. **Guard** - Identify violations of domain rules and patterns
4. **Evolve** - Track and plan domain improvements

## Scope

**Owns**: [Primary responsibilities]

**Defers to**:
- Cross-cutting patterns → `ck-architect`
- Other features → respective domain experts

## Knowledge Base

- `references/current-state.md` - Factual state of the domain
- `references/principles.md` - Rules and patterns that govern this domain
- `references/evolution.md` - Improvement roadmap and technical debt

## Core Workflows

### Evaluate a Requirement

When asked to evaluate a new feature/change for {name}:

1. Read `references/principles.md` for domain rules
2. Read `references/current-state.md` for context
3. Assess requirement against:
   - [ ] Does it align with domain principles?
   - [ ] Does it conflict with existing implementation?
   - [ ] What's the impact on related components?
   - [ ] What technical debt does it introduce/resolve?
4. Provide evaluation with:
   - Alignment score (high/medium/low)
   - Concerns and risks
   - Suggested approach
   - Required changes to domain knowledge

### Research a Question

When asked to investigate something about {name}:

1. Define the question precisely
2. Check existing knowledge in references/
3. Investigate the codebase:
   - Identify relevant files
   - Trace data/control flow
   - Find related tests
   - Check git history for context
4. Synthesize findings
5. Update knowledge base with discoveries
6. Answer with confidence level

### Guard Domain Quality

Before/during changes to {name}:

1. Load `references/principles.md`
2. Check proposed changes against each principle
3. Flag violations with:
   - Which principle violated
   - Why it matters
   - Suggested alternative

### Evolve Domain Knowledge

After completing work:

1. Ask: "What did I learn?"
   - New facts → `current-state.md`
   - New rules discovered → `principles.md`
   - New debt/opportunities → `evolution.md`

2. Ask: "What changed?"
   - Update affected sections
   - Adjust confidence levels
   - Note relationships affected

3. Ask: "What should change next?"
   - Add to evolution roadmap
   - Prioritize improvements

### Self-Improve

Periodically review domain expertise:

1. **Accuracy check**: Verify facts still hold
2. **Completeness check**: Identify knowledge gaps
3. **Relevance check**: Remove stale information
4. **Principle refinement**: Are rules still valid?
```

## Reference File Templates

### current-state.md
```markdown
---
name: {name}-current-state
last_updated: {DATE}
confidence: low
---

# {Display Name} - Current State

## Overview
[What this domain does - factual description]

## Key Components
| Component | Location | Purpose | Health |
|-----------|----------|---------|--------|

## Data Flow
[How data moves through this domain]

## Dependencies
- **Depends on**: [what this domain needs]
- **Depended by**: [what needs this domain]

## Known Issues
| Issue | Severity | Location | Notes |
|-------|----------|----------|-------|

## Recent Changes
- [DATE]: [What changed]
```

### principles.md
```markdown
---
name: {name}-principles
last_updated: {DATE}
---

# {Display Name} - Domain Principles

## Core Rules
Rules that MUST be followed in this domain:

1. **[Rule Name]**: [Description]
   - Why: [Rationale]
   - Violation: [What happens if broken]

## Patterns
Established patterns in this domain:

### [Pattern Name]
- **When**: [When to use]
- **How**: [Implementation approach]
- **Example**: [Reference to code]

## Anti-patterns
What to avoid:

- **[Anti-pattern]**: [Why it's bad here]

## Quality Criteria
How to judge changes in this domain:

- [ ] [Criterion 1]
- [ ] [Criterion 2]
```

### evolution.md
```markdown
---
name: {name}-evolution
last_updated: {DATE}
---

# {Display Name} - Evolution Roadmap

## Vision
[Where this domain should be heading]

## Technical Debt
| Debt | Impact | Effort | Priority |
|------|--------|--------|----------|

## Improvement Opportunities
| Opportunity | Benefit | Complexity | Status |
|-------------|---------|------------|--------|

## Blocked By
- [What's preventing improvements]

## Recently Completed
- [DATE]: [What was improved]
```

## Naming Guidelines

| Feature Area | Suggested Name |
|--------------|----------------|
| User login, sessions, JWT | `user-auth` |
| Payments, billing, subscriptions | `payments` |
| Email, push, SMS | `notifications` |
| Search functionality | `search` |
| File uploads, storage | `file-storage` |
| API endpoints | `api` |
| Database layer | `data-layer` |
| Background jobs | `jobs` |

## Post-Creation Checklist

- [ ] SKILL.md defines all 4 capabilities (evaluate, research, guard, evolve)
- [ ] `current-state.md` bootstrapped with initial investigation
- [ ] `principles.md` has at least core rules identified
- [ ] `evolution.md` has known debt/opportunities
- [ ] Registered in orchestrator's `_index.md`
