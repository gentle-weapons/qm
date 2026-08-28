---
name: merge-upstream
description: Merge upstream qm (yc-software) into the current branch of a private fork. Use when asked to "merge upstream", "pull in upstream qm", "sync from yc-software", or merge upstream into a feature branch.
---

# merge-upstream

Merge upstream qm into the branch you are on. For syncing `main` and opening a
production sync PR, use the `update-qm` skill instead.

## Preconditions

```bash
git remote -v
git status
```

If `origin` is `yc-software/qm`, stop: upstream qm cannot merge from itself.

Ensure a clean working tree. If `package-lock.json` has local drift from an
`npm install`, restore it before merging:

```bash
git restore package-lock.json
```

Add the upstream remote when it is missing:

```bash
git remote add upstream git@github.com:yc-software/qm
```

## Merge, never rebase

```bash
git fetch upstream
git log --oneline HEAD..upstream/main
git merge upstream/main
```

Record the commit range (`git log --oneline HEAD..upstream/main` before the
merge) so you can report what landed.

If the merge reports "Already up to date", say so and stop.

## Resolving conflicts

Conflicts outside `deploy/layers/<org>/` mean core was edited in the private
fork. For each file:

- Organization-specific edits belong in `deploy/layers/<org>/`; take upstream's
  side and move the customization there.
- Fixes that belong in core for everyone: resolve to keep the tree working, then
  use the `upstream-pr` skill so the next sync stops conflicting.

When both sides changed the same logic, combine the intent rather than picking
one side wholesale. List conflicted core files in your summary.

## Verify

```bash
npm install
npm run typecheck
npm run lint
```

Run tests covering anything you touched resolving conflicts. For a full sync of
`main` before a production PR, follow the broader checks in `update-qm`.

## After the merge

Push when the branch should be shared:

```bash
git push -u origin HEAD
```

Pass `--repo` to every `gh` command in a private fork so GitHub targets the
fork, not upstream.
