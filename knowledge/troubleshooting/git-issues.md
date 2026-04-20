# Git Troubleshooting

## Merge Conflicts

**Steps:**
1. `git status` -- see conflicted files
2. Open files, look for `<<<<<<<`, `=======`, `>>>>>>>` markers
3. Resolve manually or use: `git mergetool`
4. After resolving: `git add <file>` then `git commit`
5. To abort: `git merge --abort`
6. Prevent future conflicts: rebase regularly, keep branches short-lived

## Detached HEAD

**Symptoms:** "You are in detached HEAD state" warning.
**Steps:**
1. If you want to keep changes: `git checkout -b <new-branch>`
2. If you want to go back to a branch: `git checkout <branch>`
3. Common causes: checking out a tag, commit hash, or remote branch directly
4. To recover lost work from detached HEAD: `git reflog` to find the commit

## Lost Commits (Reflog Recovery)

**Steps:**
1. `git reflog` -- shows all recent HEAD movements
2. Find the commit hash you need
3. `git checkout <hash>` or `git cherry-pick <hash>`
4. To restore a deleted branch: `git branch <name> <hash>`
5. Reflog entries expire after 90 days (30 for unreachable commits)
6. If reflog is empty: `git fsck --lost-found` to find dangling commits

## Force Push Recovery

**Someone force-pushed and overwrote your commits:**
1. `git reflog` on any machine that had the old commits
2. `git push origin <hash>:<branch>` to restore
3. Prevention: enable branch protection rules (no force push to main)
4. Use `--force-with-lease` instead of `--force` to prevent overwrites

## Large File Mistakes

**Accidentally committed a large file:**
1. Remove from future commits: add to `.gitignore`, `git rm --cached <file>`
2. Remove from history with BFG: `bfg --delete-files <file> --no-blob-protection`
3. Or with git-filter-repo: `git filter-repo --path <file> --invert-paths`
4. After rewriting: `git push --force-with-lease`
5. All collaborators must re-clone or `git fetch && git reset --hard origin/<branch>`
6. Prevention: use `.gitattributes` with Git LFS for large files

## Submodule Issues

### Submodule not initialized
```bash
git submodule update --init --recursive
```

### Submodule points to wrong commit
```bash
cd <submodule-dir>
git checkout <correct-branch>
cd ..
git add <submodule-dir>
git commit -m "Update submodule to correct ref"
```

### Submodule URL changed
```bash
git submodule sync --recursive
git submodule update --init --recursive
```

## Credential Caching

**Tired of typing passwords:**
1. SSH keys: `ssh-keygen -t ed25519` then add to GitHub/GitLab
2. Credential helper (cache 1h): `git config --global credential.helper 'cache --timeout=3600'`
3. Credential store (permanent, plaintext): `git config --global credential.helper store`
4. macOS keychain: `git config --global credential.helper osxkeychain`
5. For HTTPS with tokens: use personal access token as password

## GPG Signing Failures

**Symptoms:** `error: gpg failed to sign the data`
**Steps:**
1. Check GPG key: `gpg --list-secret-keys --keyid-format=long`
2. Set signing key: `git config --global user.signingkey <KEY_ID>`
3. Verify GPG agent: `echo "test" | gpg --clearsign`
4. If TTY issue: `export GPG_TTY=$(tty)`
5. Add to shell profile: `echo 'export GPG_TTY=$(tty)' >> ~/.bashrc`
6. For pinentry issues: `gpgconf --kill gpg-agent` and retry
7. macOS: `brew install pinentry-mac` and configure `~/.gnupg/gpg-agent.conf`
