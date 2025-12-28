---
description: Cherry-pick commit(s) to a new branch from master and create a MR
---

# Cherry-Pick and Create MR

Cherry-pick the following commit(s) to a new branch from master and create a Merge Request.

## Input

**Commits**: $ARGUMENTS

Parse the arguments:
- `$1` - First commit hash (required)
- `$2`, `$3`, etc. - Additional commit hashes (optional)
- If an argument is `--branch`, the next argument is the branch name

## Current Git Status

!`git status --short`

## Workflow

Execute the following steps in order:

### Step 1: Parse Arguments
- Extract commit hash(es) from $ARGUMENTS
- If `--branch <name>` is provided, use that as the branch name
- Otherwise, generate a branch name from the first commit message

### Step 2: Fetch Latest Changes
```bash
git fetch origin master
```

### Step 3: Create New Branch from Master
```bash
git checkout -b <branch-name> origin/master
```

### Step 4: Cherry-Pick the Commit(s)

For single commit:
```bash
git cherry-pick <commit-hash>
```

For multiple commits (oldest first):
```bash
git cherry-pick <commit1> <commit2> ...
```

If there are conflicts:
- Stop and inform the user which commit caused the conflict
- Show the conflicting files
- DO NOT auto-resolve - ask the user how to proceed

### Step 5: Push the Branch
```bash
git push -u origin <branch-name>
```

### Step 6: Create Merge Request with glab
```bash
glab mr create --fill --target-branch master
```

## Error Handling

- If any step fails, stop and report the error
- If the commit hash is invalid, inform the user
- If the branch already exists, ask if they want a different name

## Success Output

Report:
- The new branch name
- Number of commits cherry-picked
- The MR URL
