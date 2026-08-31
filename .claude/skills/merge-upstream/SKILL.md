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
one side wholesale. Capture the conflicted paths while the merge is still in
progress, and list them in your summary:

```bash
git diff --name-only --diff-filter=U
```

That list is the merge's human-decided surface. A reviewer should scope to it,
not to the hundreds of files upstream changed on its own.

## Upstream code is not the fork's to fix

Most of a sync is upstream files landing verbatim. They are upstream's work, and
the merge does not adopt responsibility for them:

- A defect in code that arrived unchanged from upstream is an upstream bug.
  Patching it here rewrites core, so every later sync conflicts on it. Send it
  with the `upstream-pr` skill and name it in the sync PR instead.
- Convention divergence is the same call. Upstream code carries explanatory
  comments that this repo's zero-comments rule would reject on a fork-authored
  diff; stripping them changes no behavior and guarantees conflicts forever.
  Leave them alone.

Only what you actually typed to resolve a conflict is the fork's to fix in the
sync branch.

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
