#!/usr/bin/env python3
"""
Record a domain evaluation decision (create or reject).

Usage:
    python record_decision.py reject <domain-name> --reason <reason> [--alternative <alt>] --path <project-root>
    python record_decision.py pending <domain-name> [--note <note>] --path <project-root>
    python record_decision.py boundary <topic> --belongs-to <domain> --not-to <domain> --reason <reason> --path <project-root>
    python record_decision.py list --path <project-root>

Examples:
    python record_decision.py reject utils --reason "Too generic, no domain rules" --alternative "ck-architect patterns" --path .
    python record_decision.py pending notifications --note "Evaluate after email integration" --path .
    python record_decision.py boundary "rate limiting" --belongs-to api --not-to user-auth --reason "API-level concern" --path .
    python record_decision.py list --path .
"""

import argparse
from pathlib import Path
from datetime import datetime


def get_decisions_file(project_root: Path) -> Path:
    return project_root / ".claude" / "ck-domain-creator" / "references" / "decisions.md"


def record_rejection(decisions_file: Path, domain: str, reason: str, alternative: str, date: str) -> bool:
    """Record a rejected domain."""
    if not decisions_file.exists():
        print(f"❌ Error: decisions.md not found at {decisions_file}")
        return False
    
    try:
        content = decisions_file.read_text()
        
        new_entry = f"| {domain} | {date} | {reason} | {alternative or 'N/A'} |"
        
        # Find Rejected Domains section and add entry
        marker = "## Rejected Domains"
        if marker in content:
            # Find the table and add after header
            lines = content.split('\n')
            new_lines = []
            found_section = False
            added = False
            
            for i, line in enumerate(lines):
                new_lines.append(line)
                if line.startswith("## Rejected Domains"):
                    found_section = True
                elif found_section and not added and line.startswith("|---"):
                    new_lines.append(new_entry)
                    added = True
            
            content = '\n'.join(new_lines)
            decisions_file.write_text(content)
            return True
        
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False


def record_pending(decisions_file: Path, domain: str, note: str, date: str) -> bool:
    """Record a domain for future evaluation."""
    if not decisions_file.exists():
        print(f"❌ Error: decisions.md not found at {decisions_file}")
        return False
    
    try:
        content = decisions_file.read_text()
        
        new_entry = f"- `{domain}` - {note or 'needs evaluation'} ({date})"
        
        # Find Pending Evaluations section
        marker = "## Pending Evaluations"
        if marker in content:
            content = content.replace(
                "## Pending Evaluations\n\nDomains flagged for future evaluation:\n",
                f"## Pending Evaluations\n\nDomains flagged for future evaluation:\n{new_entry}\n"
            )
            decisions_file.write_text(content)
            return True
        
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False


def record_boundary(decisions_file: Path, topic: str, belongs_to: str, not_to: str, reason: str) -> bool:
    """Record a domain boundary clarification."""
    if not decisions_file.exists():
        print(f"❌ Error: decisions.md not found at {decisions_file}")
        return False
    
    try:
        content = decisions_file.read_text()
        
        new_entry = f"| {topic} | {belongs_to} | {not_to} | {reason} |"
        
        # Find Domain Boundaries section
        marker = "## Domain Boundaries"
        if marker in content:
            # Check if table exists or needs to be created
            if "| Topic | Belongs To |" not in content:
                # Add table header
                table = "\n| Topic | Belongs To | NOT To | Rationale |\n|-------|------------|--------|-----------|"
                content = content.replace(
                    "## Domain Boundaries\n\nClarifications on what belongs where when domains overlap:",
                    f"## Domain Boundaries\n\nClarifications on what belongs where when domains overlap:{table}"
                )
            
            # Add entry after table header
            lines = content.split('\n')
            new_lines = []
            found_section = False
            added = False
            
            for i, line in enumerate(lines):
                new_lines.append(line)
                if "## Domain Boundaries" in line:
                    found_section = True
                elif found_section and not added and line.startswith("|---"):
                    new_lines.append(new_entry)
                    added = True
            
            if added:
                content = '\n'.join(new_lines)
                decisions_file.write_text(content)
                return True
        
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False


def list_decisions(decisions_file: Path) -> bool:
    """List all domain decisions."""
    if not decisions_file.exists():
        print(f"❌ Error: decisions.md not found at {decisions_file}")
        return False
    
    try:
        content = decisions_file.read_text()
        
        # Parse and display sections
        print("=" * 60)
        print("DOMAIN EXPERT DECISIONS")
        print("=" * 60)
        
        # Simple extraction - just print relevant sections
        in_section = None
        for line in content.split('\n'):
            if line.startswith("## Active Domain Experts"):
                in_section = "active"
                print("\n📦 ACTIVE DOMAIN EXPERTS:")
            elif line.startswith("## Rejected Domains"):
                in_section = "rejected"
                print("\n❌ REJECTED DOMAINS:")
            elif line.startswith("## Domain Boundaries"):
                in_section = "boundaries"
                print("\n🔀 DOMAIN BOUNDARIES:")
            elif line.startswith("## Pending"):
                in_section = "pending"
                print("\n⏳ PENDING EVALUATIONS:")
            elif line.startswith("## Decision Criteria"):
                in_section = None
            elif line.startswith("##"):
                in_section = None
            elif in_section and line.startswith("|") and not line.startswith("|--") and not line.startswith("| Domain") and not line.startswith("| Topic"):
                # Table row
                print(f"   {line}")
            elif in_section and line.startswith("- `"):
                # List item
                print(f"   {line}")
        
        return True
    except Exception as e:
        print(f"❌ Error: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Record domain evaluation decisions"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)
    
    # Reject command
    reject_parser = subparsers.add_parser("reject", help="Record a rejected domain")
    reject_parser.add_argument("domain", help="Domain name that was rejected")
    reject_parser.add_argument("--reason", required=True, help="Why it was rejected")
    reject_parser.add_argument("--alternative", help="Alternative (e.g., which expert covers it)")
    reject_parser.add_argument("--path", type=Path, default=Path.cwd())
    
    # Pending command
    pending_parser = subparsers.add_parser("pending", help="Flag domain for future evaluation")
    pending_parser.add_argument("domain", help="Domain name to evaluate later")
    pending_parser.add_argument("--note", help="Note about when/why to evaluate")
    pending_parser.add_argument("--path", type=Path, default=Path.cwd())
    
    # Boundary command
    boundary_parser = subparsers.add_parser("boundary", help="Record domain boundary clarification")
    boundary_parser.add_argument("topic", help="The topic/concern being clarified")
    boundary_parser.add_argument("--belongs-to", required=True, help="Domain that owns this")
    boundary_parser.add_argument("--not-to", required=True, help="Domain that does NOT own this")
    boundary_parser.add_argument("--reason", required=True, help="Why this boundary exists")
    boundary_parser.add_argument("--path", type=Path, default=Path.cwd())
    
    # List command
    list_parser = subparsers.add_parser("list", help="List all domain decisions")
    list_parser.add_argument("--path", type=Path, default=Path.cwd())
    
    args = parser.parse_args()
    
    decisions_file = get_decisions_file(args.path.resolve())
    today = datetime.now().strftime("%Y-%m-%d")
    
    if args.command == "reject":
        if record_rejection(decisions_file, args.domain, args.reason, args.alternative, today):
            print(f"✅ Recorded rejection: {args.domain}")
            return 0
        return 1
    
    elif args.command == "pending":
        if record_pending(decisions_file, args.domain, args.note, today):
            print(f"✅ Flagged for evaluation: {args.domain}")
            return 0
        return 1
    
    elif args.command == "boundary":
        if record_boundary(decisions_file, args.topic, args.belongs_to, args.not_to, args.reason):
            print(f"✅ Recorded boundary: {args.topic}")
            return 0
        return 1
    
    elif args.command == "list":
        return 0 if list_decisions(decisions_file) else 1
    
    return 1


if __name__ == "__main__":
    exit(main())
