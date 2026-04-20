# Code & Scripting Workflow Troubleshooting

## Git Merge Strategies Gone Wrong
**Symptoms:** Unexpected merge conflicts, lost commits after merge, wrong content after resolution.
**Steps:**
1. Check merge strategy used: `git log --merges --oneline` to see merge commits
2. For lost commits: `git reflog` to find and recover lost HEAD positions
3. To redo a bad merge: `git reset --hard ORIG_HEAD` (before any new commits)
4. Use `git merge --abort` to cancel an in-progress merge
5. For complex conflicts: use `git rerere` to record and replay resolutions
6. Consider rebase workflow for linear history: `git pull --rebase`
7. Use `git merge --no-ff` to always create merge commits (easier to revert)
8. When in doubt: `git diff HEAD...branch` to preview changes before merge

## CI/CD Pipeline YAML Syntax Issues
**Symptoms:** Pipeline fails to parse, jobs not triggered, unexpected behavior.
**Steps:**
1. Validate YAML syntax with a linter: `yamllint .gitlab-ci.yml` or online validators
2. GitHub Actions: use `actionlint` for comprehensive validation
3. Check indentation - YAML is whitespace-sensitive (spaces only, no tabs)
4. Verify anchor/alias usage: `&anchor` and `*anchor` must match
5. Quote strings containing special YAML characters: `:`, `{`, `}`, `[`, `]`, `,`, `#`
6. For multiline strings: use `|` (literal) or `>` (folded) block scalars
7. Check environment variable expansion syntax (varies by CI system)
8. Use CI system's built-in linting endpoint (GitLab: `POST /ci/lint`)

## Pre-commit Hook Failures
**Symptoms:** Commit rejected by hooks, hooks running on wrong files, slow hook execution.
**Steps:**
1. Check installed hooks: `pre-commit run --all-files` to test all hooks
2. Update hooks: `pre-commit autoupdate`
3. Skip hooks temporarily: `git commit --no-verify` (use sparingly)
4. Check `.pre-commit-config.yaml` for correct hook versions and args
5. For slow hooks: use `stages` to run heavy checks only on push
6. Clear hook cache: `pre-commit clean` then `pre-commit install`
7. Verify Python/Node versions match hook requirements
8. Check file patterns in `files:` and `exclude:` regex

## Branch Protection Bypass
**Symptoms:** Direct push to protected branch, missing required reviews, checks not enforced.
**Steps:**
1. Verify branch protection rules in repository settings
2. Check for admin bypass: admins may have "include administrators" unchecked
3. Ensure required status checks are configured and names match exactly
4. Verify CODEOWNERS file syntax and team membership
5. Check if force push is allowed (should be disabled on protected branches)
6. For GitHub: verify "Require pull request reviews" is enabled with correct count
7. Audit bypass events in repository audit log
8. Use rulesets (GitHub) or push rules (GitLab) for more granular control

## Makefile/Taskfile Debugging
**Symptoms:** Make target fails, wrong variables, recipes not executing.
**Steps:**
1. Debug with `make -n target` (dry run) to see what would execute
2. Print variables: `make -p` or add `$(info VAR=$(VAR))` in Makefile
3. Use `make -d target` for full debug output
4. Check for tabs vs spaces: recipes MUST start with a tab character
5. Verify `.PHONY` declarations for targets that are not files
6. Check variable assignment: `=` (recursive), `:=` (simple), `?=` (conditional)
7. For Taskfile (task): validate with `task --list` and `task --dry target`
8. Ensure shell is set correctly: `.SHELL: /bin/bash` if using bash features

## Python Virtualenv Conflicts
**Symptoms:** Wrong package versions, import errors, conflicting dependencies.
**Steps:**
1. Verify active environment: `which python` and `pip --version`
2. Check for conflicting envs: deactivate all (`deactivate`, `conda deactivate`)
3. Recreate env: `rm -rf .venv && python -m venv .venv && source .venv/bin/activate`
4. Use `pip freeze` to compare with `requirements.txt`
5. Check for system Python leaking into venv: verify `sys.path`
6. Use `pip install --no-cache-dir` to avoid stale cached packages
7. Consider `pipenv`, `poetry`, or `uv` for deterministic dependency resolution
8. Check `PYTHONPATH` for unexpected entries overriding venv packages

## Go Module Proxy Issues
**Symptoms:** `go mod download` fails, checksum mismatch, private module access denied.
**Steps:**
1. Check proxy setting: `go env GOPROXY` (default: `https://proxy.golang.org,direct`)
2. For private repos: set `GONOSUMCHECK` and `GOPRIVATE` for your domain
3. Example: `go env -w GOPRIVATE=github.com/myorg/*`
4. Checksum mismatch: `go clean -modcache` then retry
5. For corporate proxy: set `GONOSUMCHECK` to bypass sum.golang.org
6. Use `go mod verify` to check local cache integrity
7. In CI: cache `GOPATH/pkg/mod` for faster builds
8. For vendor mode: `go mod vendor` and build with `-mod=vendor`

## Shell Script Portability (bash vs sh vs zsh)
**Symptoms:** Script works locally but fails in CI, syntax errors on different OS, behavior differences.
**Steps:**
1. Check shebang: `#!/usr/bin/env bash` for bash, `#!/bin/sh` for POSIX sh
2. Use `shellcheck` to identify portability issues
3. Common bashisms to avoid in sh: `[[ ]]`, `(( ))`, arrays, `{a,b}` expansion
4. macOS ships old bash (3.2): avoid bash 4+ features (associative arrays, `${var,,}`)
5. Use `printf` instead of `echo -e` for portable escape sequences
6. Alpine/Docker: default shell is ash (BusyBox) - many bash features unavailable
7. Use `command -v` instead of `which` for portable command checking
8. Prefer `$(cmd)` over backticks for command substitution
