# Contributing to CalcSathi

This repo has one human maintainer (Harsh) and an AI technical partner (Claude) doing most of
the day-to-day implementation. This doc is the actual process both of us follow — not
aspirational, just what we do.

**Branching model: Git Flow.** Two permanent branches (`main`, `develop`), short-lived
`feature/*` and `release/*` branches, `hotfix/*` for urgent production fixes. This is a
deliberate choice over the simpler "everything merges straight into main" model — it gives a
clean separation between "what's actually shipped" (`main`, always tagged, always deployable)
and "what's being integrated for the next release" (`develop`), and it produces a real audit
trail: you can always answer "what shipped in v0.3.0?" by looking at one release branch's merge.

**Branches are never deleted — not `feature/*`, not `release/*`, not `hotfix/*`, ever.** Every
branch stays in the repo permanently as a historical record, on GitHub and locally. This changes
a couple of the usual GitHub defaults — called out explicitly below so it doesn't get
re-enabled by accident.

## The branches

- **`main`** — always reflects the latest released version. Every commit on `main` is tagged.
  Nothing merges into `main` except a `release/*` branch (normal case) or a `hotfix/*` branch
  (emergency case). Protected — no direct pushes, ever.
- **`develop`** — the integration branch. This is where finished features accumulate between
  releases. Protected — no direct pushes; every change lands via a `feature/*` PR.
- **`feature/<short-description>`** — one feature/screen/fix-that-can-wait-for-the-next-release
  per branch. Always branched from the current tip of `develop`. Merges back into `develop` via
  PR. Examples: `feature/custom-formula-builder`, `feature/coin-wallet-ui`.
- **`release/vX.Y.Z`** — cut from `develop` when its contents are ready to stabilize for a
  release. Only bug fixes go on a release branch from this point — no new features. When it's
  ready to ship: PR into `main` (tag `vX.Y.Z` there), **then merge back into `develop`** so any
  fixes made on the release branch aren't lost to future feature work.
- **`hotfix/vX.Y.Z`** — for a bug found in production that can't wait for the next normal
  release. Branched from `main` (not `develop` — you're fixing what's actually deployed, which
  may be ahead of what a release branch would give you). PR into `main` (tag the new patch
  version there), **then merge into `develop`** (and into the current `release/*` branch too, if
  one happens to be in flight) so the fix carries forward.

```
feature/*  →  develop  →  release/vX.Y.Z  →  main  (tag vX.Y.Z)
                 ↑                              │
                 └──────────── back-merge ───────┘
                 ↑
       hotfix/vX.Y.Z ←──────────────────────── main  (tag vX.Y.Z, urgent path)
```

## Commit messages — Conventional Commits

Every commit uses the [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<optional scope>): <short summary>

<optional body — the "why", not just the "what">
```

Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `perf`. Example:

```
feat(calc_core): add compound-interest formula preset

Adds the CI calculator's default formula as a built-in preset so users
don't have to build it from scratch in the custom formula builder.
```

This isn't bureaucracy for its own sake — it's what lets a release's notes be drafted straight
from commit/PR history instead of hand-written from memory.

## Pull request & merge policy

1. **`feature/*` → `develop`:** open a PR, describe what changed and why (screenshots for
   anything UI-visible). CI must be green. **Merge with a merge commit — do not squash, do not
   delete the branch.** A real merge commit is what makes `git log --graph` on `develop` show
   "this feature landed here," and the branch has to still exist afterward, so squashing away its
   individual commits is off the table by definition of the no-delete rule.
2. **`release/vX.Y.Z` → `main`:** open a PR once the release branch is stable. This PR *is* the
   release — its diff is exactly what's about to ship. CI must be green. Merge with a merge
   commit, don't delete the branch.
3. **Tag `main`** at the merge commit: `git tag -a vX.Y.Z -m "..."` then `git push origin vX.Y.Z`
   (exact steps in "Versioning & releases" below).
4. **Back-merge `main` → `develop`** right after tagging (a direct merge is fine here — this is
   just resyncing, not new review-worthy work; open a small PR instead if you'd rather have the
   CI gate on it too).
5. **`hotfix/*` → `main`:** same as a release PR — review the diff, CI green, merge commit, tag,
   then merge the hotfix into `develop` (and into any in-flight `release/*` branch) so the fix
   isn't lost to the next release.

**No merging on red CI, no exceptions** — even for "it's just a docs change." If it's truly
docs-only, CI passes trivially anyway, so the rule costs nothing in that case and catches real
mistakes in every other case.

## Branch protection setup (one-time, done in the GitHub UI)

This can only be configured by a repo admin in the GitHub UI/API — Claude can't set this from a
CLI session. Go to **Settings → Branches → Add branch protection rule** and apply this to *both*
`main` and `develop`:

- Require a pull request before merging
- Require status checks to pass before merging → select the CI jobs from `ci.yml`
  (`calc_core`, `mobile`, `admin`, `server`)
- Require branches to be up to date before merging
- Do not allow force pushes
- Do not allow deletions

**Leave "Automatically delete head branches" OFF** in Settings → General — branches stay around
permanently per the no-delete policy above. When merging a PR on GitHub, don't click the
"Delete branch" button GitHub offers after a merge — just leave it.

## Versioning & releases

CalcSathi uses [Semantic Versioning](https://semver.org/) (`vMAJOR.MINOR.PATCH`) for the whole
monorepo — one version number across `apps/`, `packages/calc_core`, and `server/`, rather than
independent per-package versions. That's a deliberate simplification while this is a
single-team, single-deploy-cadence project; revisit if `server/` ever needs to ship
independently of the mobile app.

- Pre-1.0 (`v0.x.y`): anything can change, including breaking changes, without a MAJOR bump —
  standard pre-release semantics. We're here now.
- Bump MINOR for a new user-visible feature or calculator (normal `release/*` flow).
- Bump PATCH for a bug fix (either a normal release, or a `hotfix/*` if it's urgent).
- Bump MAJOR once past 1.0 for anything that breaks a previously-shipped contract (e.g. a stored
  Firestore schema change that needs a migration).

**To cut a normal release**, once `develop` has what you want to ship:

```
git checkout develop
git pull
git checkout -b release/v0.2.0
# fix anything that only turns up during stabilization, commit directly on this branch
git push -u origin release/v0.2.0
# → open a PR: release/v0.2.0 into main. Once it's merged:
git checkout main
git pull
git tag -a v0.2.0 -m "v0.2.0: <one-line summary of what shipped>"
git push origin v0.2.0
# → back-merge:
git checkout develop
git pull
git merge main
git push origin develop
```

**For a hotfix**, same shape but branch from `main` instead of `develop`, and back-merge into
both `develop` and any in-flight `release/*` branch.

Then draft a GitHub Release from the new tag (**Releases → Draft a new release → choose the
tag**) with notes summarizing what merged — Claude will draft these notes for you each time from
the PR titles that went into the release branch, so this is mostly copy/paste.

## How Claude actually delivers changes (worth knowing, not just for Claude)

Claude's cloud workspace cannot push directly to this repo — GitHub blocks pushes from that
session's git proxy for security reasons unrelated to this project. In practice this means:

- Claude does the actual implementation work in its own workspace, on a properly named
  `feature/*` branch (branched from the latest `develop`), with real commits.
- Claude hands the finished branch to Harsh — directly into this connected local clone via the
  desktop bridge when it's connected that session, or as a `git bundle` file to import
  otherwise.
- **Harsh pushes the branch and opens the PR into `develop`** — this is also a good manual
  double-check step, not just a workaround for a technical limitation.
- Once CI is green, Harsh merges (merge commit, branch stays). Claude cuts and drafts
  `release/*` branches and their notes the same way when it's time to ship.

This is slightly different from a normal solo-dev flow (no bot user pushing branches directly),
but the branching/PR/CI/tagging policy above is otherwise exactly what a small team would run.
