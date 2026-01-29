#!/usr/bin/env python3
"""
Analyze a codebase to identify potential domains that need expert skills.

Usage:
    python analyze_domains.py --path <project-root>

Outputs:
    - List of potential domains based on directory structure
    - Existing domain experts
    - Suggested new domain experts to create
"""

import argparse
from pathlib import Path
from collections import Counter
import subprocess


# Directories to skip during analysis
SKIP_DIRS = {
    "node_modules", ".git", "__pycache__", ".next", "dist", "build",
    ".cache", "coverage", ".pytest_cache", "venv", ".venv", "env",
    ".claude", ".cursor", ".idea", ".vscode"
}

# Common feature directory patterns
FEATURE_DIRS = {
    "src", "lib", "app", "packages", "modules", "features",
    "components", "services", "api", "routes", "handlers"
}

# Code extensions to consider
CODE_EXTENSIONS = {".ts", ".tsx", ".js", ".jsx", ".py", ".go", ".rs", ".java", ".rb"}


def find_potential_domains(root: Path) -> dict:
    """Identify potential domains from directory structure."""
    domains = {}
    
    for feature_dir in FEATURE_DIRS:
        dir_path = root / feature_dir
        if dir_path.exists():
            for item in dir_path.iterdir():
                if item.is_dir() and item.name not in SKIP_DIRS:
                    # Count code files
                    code_files = sum(
                        1 for f in item.rglob("*")
                        if f.is_file() and f.suffix in CODE_EXTENSIONS
                    )
                    if code_files >= 3:  # Only suggest if substantial
                        domains[item.name] = {
                            "path": str(item.relative_to(root)),
                            "files": code_files
                        }
    
    return domains


def get_existing_domain_experts(root: Path) -> set:
    """Find existing ck-domain-* skills."""
    claude_dir = root / ".claude"
    if not claude_dir.exists():
        return set()
    
    experts = set()
    for item in claude_dir.iterdir():
        if item.is_dir() and item.name.startswith("ck-domain-"):
            domain_name = item.name.replace("ck-domain-", "")
            experts.add(domain_name)
    
    return experts


def get_git_activity(root: Path) -> Counter:
    """Get file modification frequency from git history."""
    try:
        result = subprocess.run(
            ["git", "log", "--name-only", "--pretty=format:", "-n", "100"],
            cwd=root,
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            files = [f for f in result.stdout.split("\n") if f.strip()]
            # Extract top-level directory for each file
            dirs = []
            for f in files:
                parts = f.split("/")
                if len(parts) > 1:
                    dirs.append(parts[0] if parts[0] not in SKIP_DIRS else parts[1] if len(parts) > 1 else None)
            return Counter(d for d in dirs if d)
    except Exception:
        pass
    return Counter()


def analyze(root: Path):
    """Run analysis and print results."""
    print(f"🔍 Analyzing codebase: {root}\n")
    
    # Find potential domains
    domains = find_potential_domains(root)
    
    # Get existing experts
    existing = get_existing_domain_experts(root)
    
    # Get git activity
    activity = get_git_activity(root)
    
    # Print results
    print("=" * 60)
    print("POTENTIAL DOMAINS (from directory structure)")
    print("=" * 60)
    
    if domains:
        for name, info in sorted(domains.items(), key=lambda x: -x[1]["files"]):
            status = "✓ has expert" if name in existing else "○ needs expert"
            activity_count = activity.get(name, 0)
            print(f"  {name:25} {info['files']:3} files  {activity_count:3} commits  {status}")
    else:
        print("  No clear feature domains found in standard locations")
    
    print("\n" + "=" * 60)
    print("EXISTING DOMAIN EXPERTS")
    print("=" * 60)
    
    if existing:
        for name in sorted(existing):
            in_codebase = "✓ maps to code" if name in domains else "? no matching dir"
            print(f"  ck-domain-{name:20} {in_codebase}")
    else:
        print("  No domain experts created yet")
    
    print("\n" + "=" * 60)
    print("SUGGESTED NEW DOMAIN EXPERTS")
    print("=" * 60)
    
    suggestions = [
        (name, info) for name, info in domains.items()
        if name not in existing
    ]
    suggestions.sort(key=lambda x: -x[1]["files"])
    
    if suggestions:
        print("\nRun these commands to create domain experts:\n")
        for name, info in suggestions[:10]:
            print(f"  python create_domain_expert.py {name} --path {root}")
    else:
        print("  All identified domains have experts!")
    
    # Check for orphaned experts
    orphaned = existing - set(domains.keys())
    if orphaned:
        print("\n" + "=" * 60)
        print("POTENTIALLY ORPHANED EXPERTS")
        print("=" * 60)
        for name in orphaned:
            print(f"  ck-domain-{name} - no matching directory found")


def main():
    parser = argparse.ArgumentParser(
        description="Analyze codebase to identify domains needing experts"
    )
    parser.add_argument(
        "--path",
        type=Path,
        default=Path.cwd(),
        help="Project root directory (default: current directory)"
    )
    
    args = parser.parse_args()
    
    if not args.path.exists():
        print(f"❌ Error: Path does not exist: {args.path}")
        return 1
    
    analyze(args.path.resolve())
    return 0


if __name__ == "__main__":
    exit(main())
