#!/usr/bin/env python3
"""
Create a new domain expert skill for codebase knowledge.

Usage:
    python create_domain_expert.py <domain-name> --path <project-root>

Examples:
    python create_domain_expert.py user-auth --path /path/to/project
    python create_domain_expert.py payments --path .
"""

import argparse
from pathlib import Path
from datetime import datetime


SKILL_TEMPLATE = '''---
name: ck-domain-{name}
description: Domain expert for {display_name}. Autonomous specialist that evaluates requirements, researches questions, guards quality, and evolves knowledge about {name}. Use when working on {name} code, evaluating {name} requirements, researching {name} questions, or planning {name} improvements.
---

# {display_name} Domain Expert

Autonomous specialist for the {name} domain.

## Capabilities

1. **Evaluate** - Assess changes/requirements against domain principles
2. **Research** - Investigate domain-related questions systematically
3. **Guard** - Identify violations of domain rules and patterns
4. **Evolve** - Track and plan domain improvements

## Scope

**Owns**: [TODO: Define primary responsibilities]

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
'''

CURRENT_STATE_TEMPLATE = '''---
name: {name}-current-state
last_updated: {date}
confidence: low
---

# {display_name} - Current State

## Overview
[TODO: What this domain does - factual description]

## Key Components
| Component | Location | Purpose | Health |
|-----------|----------|---------|--------|
| [TODO] | `path/` | [purpose] | 🟢/🟡/🔴 |

## Data Flow
[TODO: How data moves through this domain - consider adding a diagram]

## Dependencies
- **Depends on**: [TODO: what this domain needs]
- **Depended by**: [TODO: what needs this domain]

## Known Issues
| Issue | Severity | Location | Notes |
|-------|----------|----------|-------|
| [TODO] | low/med/high | `path` | [notes] |

## Recent Changes
- {date}: Domain expert created
'''

PRINCIPLES_TEMPLATE = '''---
name: {name}-principles
last_updated: {date}
---

# {display_name} - Domain Principles

## Core Rules
Rules that MUST be followed in this domain:

1. **[TODO: Rule Name]**: [Description]
   - Why: [Rationale]
   - Violation: [What happens if broken]

## Patterns
Established patterns in this domain:

### [TODO: Pattern Name]
- **When**: [When to use]
- **How**: [Implementation approach]
- **Example**: [Reference to code]

## Anti-patterns
What to avoid:

- **[TODO: Anti-pattern]**: [Why it's bad here]

## Quality Criteria
How to judge changes in this domain:

- [ ] [TODO: Criterion 1]
- [ ] [TODO: Criterion 2]
'''

EVOLUTION_TEMPLATE = '''---
name: {name}-evolution
last_updated: {date}
---

# {display_name} - Evolution Roadmap

## Vision
[TODO: Where this domain should be heading]

## Technical Debt
| Debt | Impact | Effort | Priority |
|------|--------|--------|----------|
| [TODO] | low/med/high | S/M/L | P1/P2/P3 |

## Improvement Opportunities
| Opportunity | Benefit | Complexity | Status |
|-------------|---------|------------|--------|
| [TODO] | [benefit] | S/M/L | planned/in-progress/done |

## Blocked By
- [TODO: What's preventing improvements]

## Recently Completed
- {date}: Domain expert created - initial learning phase
'''


def to_display_name(name: str) -> str:
    """Convert kebab-case to Display Name."""
    return ' '.join(word.capitalize() for word in name.split('-'))


def update_decisions_log(
    decisions_file: Path,
    name: str,
    display_name: str,
    date: str,
    rationale: str = "[TODO: Add rationale]",
    covers: str = "[TODO: Define scope]"
) -> bool:
    """Add new domain expert to decisions log."""
    if not decisions_file.exists():
        return False
    
    try:
        content = decisions_file.read_text()
        lines = content.split('\n')
        new_lines = []
        
        new_entry = f"| {name} | {date} | {rationale} | {covers} |"
        
        # Find the Active Domain Experts section and add after the table header separator
        found_section = False
        added = False
        
        for i, line in enumerate(lines):
            new_lines.append(line)
            if "## Active Domain Experts" in line:
                found_section = True
            elif found_section and not added and line.startswith("|--"):
                # Add after the table header separator
                new_lines.append(new_entry)
                added = True
            elif found_section and line.startswith("## ") and not line.startswith("## Active"):
                # Moved past the section, stop looking
                found_section = False
        
        if added:
            content = '\n'.join(new_lines)
            decisions_file.write_text(content)
            return True
        
        return False
    except Exception:
        return False


def create_domain_expert(name: str, project_root: Path, rationale: str = None, covers: str = None) -> int:
    """Create a new domain expert skill."""
    
    # Validate name
    if not name.replace('-', '').replace('_', '').isalnum():
        print(f"❌ Error: Name should be kebab-case (letters, numbers, hyphens)")
        return 1
    
    # Paths
    skill_dir = project_root / ".claude" / f"ck-domain-{name}"
    refs_dir = skill_dir / "references"
    skill_file = skill_dir / "SKILL.md"
    current_state_file = refs_dir / "current-state.md"
    principles_file = refs_dir / "principles.md"
    evolution_file = refs_dir / "evolution.md"
    
    # Check if already exists
    if skill_dir.exists():
        print(f"❌ Error: Domain expert already exists: {skill_dir}")
        return 1
    
    # Create directories
    try:
        refs_dir.mkdir(parents=True)
        print(f"✅ Created: {skill_dir}")
    except Exception as e:
        print(f"❌ Error creating directory: {e}")
        return 1
    
    # Generate content
    display_name = to_display_name(name)
    today = datetime.now().strftime("%Y-%m-%d")
    
    skill_content = SKILL_TEMPLATE.format(
        name=name,
        display_name=display_name
    )
    
    current_state_content = CURRENT_STATE_TEMPLATE.format(
        name=name,
        display_name=display_name,
        date=today
    )
    
    principles_content = PRINCIPLES_TEMPLATE.format(
        name=name,
        display_name=display_name,
        date=today
    )
    
    evolution_content = EVOLUTION_TEMPLATE.format(
        name=name,
        display_name=display_name,
        date=today
    )
    
    # Write files
    try:
        skill_file.write_text(skill_content)
        print(f"✅ Created: SKILL.md")
        
        current_state_file.write_text(current_state_content)
        print(f"✅ Created: references/current-state.md")
        
        principles_file.write_text(principles_content)
        print(f"✅ Created: references/principles.md")
        
        evolution_file.write_text(evolution_content)
        print(f"✅ Created: references/evolution.md")
    except Exception as e:
        print(f"❌ Error writing files: {e}")
        return 1
    
    # Update decisions log
    decisions_file = project_root / ".claude" / "ck-domain-creator" / "references" / "decisions.md"
    if decisions_file.exists():
        updated = update_decisions_log(
            decisions_file,
            name,
            display_name,
            today,
            rationale or "[TODO: Add rationale]",
            covers or "[TODO: Define scope]"
        )
        if updated:
            print(f"✅ Updated: decisions.md")
        else:
            print(f"⚠️  Could not update decisions.md - please add manually")
    else:
        print(f"⚠️  decisions.md not found - please record decision manually")
    
    # Success message
    print(f"\n✅ Domain expert 'ck-domain-{name}' created successfully!")
    print(f"\n📁 Structure:")
    print(f"   .claude/ck-domain-{name}/")
    print(f"   ├── SKILL.md                    # Expert behavior")
    print(f"   └── references/")
    print(f"       ├── current-state.md        # Facts about the domain")
    print(f"       ├── principles.md           # Rules and patterns")
    print(f"       └── evolution.md            # Roadmap and debt")
    print(f"\n🚀 Next steps:")
    print(f"   1. Investigate the codebase to bootstrap current-state.md")
    print(f"   2. Identify core rules and add to principles.md")
    print(f"   3. Note technical debt and opportunities in evolution.md")
    print(f"   4. Update rationale and scope in decisions.md")
    print(f"   5. Register in .claude/experts/_index.md")
    
    return 0


def main():
    parser = argparse.ArgumentParser(
        description="Create a new autonomous domain expert skill"
    )
    parser.add_argument(
        "name",
        help="Domain name in kebab-case (e.g., 'user-auth', 'payments')"
    )
    parser.add_argument(
        "--path",
        type=Path,
        default=Path.cwd(),
        help="Project root directory (default: current directory)"
    )
    parser.add_argument(
        "--rationale",
        type=str,
        default=None,
        help="Why this domain expert is being created"
    )
    parser.add_argument(
        "--covers",
        type=str,
        default=None,
        help="What this domain expert covers (scope)"
    )
    
    args = parser.parse_args()
    
    if not args.path.exists():
        print(f"❌ Error: Path does not exist: {args.path}")
        return 1
    
    print(f"🚀 Creating domain expert: ck-domain-{args.name}")
    print(f"   Location: {args.path / '.claude'}")
    print()
    
    return create_domain_expert(
        args.name,
        args.path.resolve(),
        rationale=args.rationale,
        covers=args.covers
    )


if __name__ == "__main__":
    exit(main())
