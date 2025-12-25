---
description: Create feature-based commits and bump version (major/minor/patch)
argument-hint: "[major|minor|patch] - optional, auto-detected if not provided"
model: opencode/big-pickle
---

# Release: Feature-Based Commits and Version Bump

Create semantic commits grouped by features and bump the version.

## Input

**Version Bump Type**: $1

- If `$1` is `major`, `minor`, or `patch` - use that bump type
- If `$1` is empty or not provided - analyze commits and decide automatically

## Current State

### Unstaged/Uncommitted Changes
!`git status --short`

### Recent Commits (for context)
!`git log --oneline -10`

### Current Version
!`cat package.json 2>/dev/null | grep '"version"' | head -1 || echo "No package.json found"`

## Workflow

### Step 1: Analyze Changes

Review all uncommitted changes using `git diff` and `git status`.

Group changes by feature/purpose:
- **feat**: New features
- **fix**: Bug fixes
- **refactor**: Code refactoring
- **docs**: Documentation changes
- **style**: Formatting, styling changes
- **test**: Adding/updating tests
- **chore**: Maintenance tasks, dependencies

### Step 2: Create Feature-Based Commits

For each logical group of changes:

1. Stage only the related files:
   ```bash
   git add <files-for-this-feature>
   ```

2. Create a conventional commit:
   ```bash
   git commit -m "<type>(<scope>): <description>"
   ```

Commit message guidelines:
- Use conventional commit format: `type(scope): description`
- Keep subject line under 72 characters
- Be specific about what changed and why
- One commit per logical change/feature

### Step 3: Determine Version Bump

**If `$1` is provided** (`major`, `minor`, or `patch`):
- Use the specified bump type

**If `$1` is NOT provided**:
- Analyze all commits since last version tag
- Use semver rules:
  - **major**: Breaking changes (commits with `BREAKING CHANGE` or `!` after type)
  - **minor**: New features (`feat` commits)
  - **patch**: Bug fixes, refactors, docs, etc.
- Default to the highest applicable bump

### Step 4: Bump Version

Determine the version file(s) in the project:
- `package.json` for Node.js projects
- `pyproject.toml` for Python projects
- `Cargo.toml` for Rust projects
- Other version files as applicable

Update the version following semver:
- Current: `X.Y.Z`
- major: `X+1.0.0`
- minor: `X.Y+1.0`
- patch: `X.Y.Z+1`

### Step 5: Commit Version Bump

```bash
git add <version-files>
git commit -m "chore(release): bump version to <new-version>"
```

## Error Handling

- If no changes to commit, inform the user
- If version file not found, ask user which file to update
- If git operations fail, stop and report the error

## Success Output

Report:
- Number of feature commits created
- List of commits with their types
- Previous version -> New version
- Version bump type used (and reasoning if auto-detected)
