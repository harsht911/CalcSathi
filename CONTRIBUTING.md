# Contributing to CalcSathi

This repo has one human maintainer (Harsh) and an AI technical partner (Claude) doing most of
the day-to-day implementation. This doc is the actual process both of us follow — not
aspirational, just what we do.

## Branching model

- **`main` is protected.** Nothing is committed to it directly — every change lands via a pull
  request. See "Branch protection setup" below for the GitHub-side settings that enforce this.
- Every change starts as a short-lived branch off the latest `main`, named by type:
  - `feat/<short-description>` — a new feature or screen
  - `fix/<short-description>` — a bug fix
  - `chore/<short-description>` — tooling, deps, CI, config
  - `docs/<short-description>` — documentation only
  - `refactor/<short-description>` — no behavior change
- Branches are deleted after merge (GitHub can do this automatically — see below).

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

This isn't bureaucracy for its own sake — it's what lets a release's changelog be generated
straight from commit history instead of hand-written from memory.

## Pull request & merge policy

1. Open a PR from your branch into `main`. Use the PR body to say what changed and why —
   screenshots for anything UI-visible.
2. **CI must be green** (`.github/workflows/ci.yml` — analyze + test for `calc_core`, both
   Flutter apps, and the `server/` service) before merging. No merging on red CI, no exceptions,
   even for "it's just a docs change" — if it's truly docs-only, CI will pass trivially anyway.
3. **Squash-merge into `main`.** Keeps `main`'s history one commit per PR/feature, which keeps
   the changelog readable — the individual "wip" / "fix typo" commits inside a branch don't need
   to survive into `main`'s history.
4. Delete the branch after merge.

## Branch protection setup (one-time, done in the GitHub UI)

This can only be configured by a repo admin in the GitHub UI/API — Claude can't set this from a
CLI session. Once you're ready to enforce the policy above (recommended before this repo has any
real users, i.e. soon), go to **Settings → Branches → Add branch protection rule** for `main` and
enable:

- Require a pull request before merging
- Require status checks to pass before merging → select the CI jobs from `ci.yml`
  (`calc_core`, `mobile`, `admin`, `server`)
- Require branches to be up to date before merging
- Do not allow force pushes
- Do not allow deletions

Also worth turning on separately: **Settings → General → Automatically delete head branches**
(handles step 4 above for you).

## Versioning & releases

CalcSathi uses [Semantic Versioning](https://semver.org/) (`vMAJOR.MINOR.PATCH`) for the whole
monorepo — one version number across `apps/`, `packages/calc_core`, and `server/`, rather than
independent per-package versions. That's a deliberate simplification while this is a single-team,
single-deploy-cadence project; revisit if `server/` ever needs to ship independently of the
mobile app.

- Pre-1.0 (`v0.x.y`): anything can change, including breaking changes, without a MAJOR bump —
  standard pre-release semantics. We're here now (`v0.1.0` once the first scaffold is tagged).
- Bump MINOR for a new user-visible feature or calculator.
- Bump PATCH for a bug fix or internal-only change.
- Bump MAJOR once past 1.0 for anything that breaks a previously-shipped contract (e.g. a stored
  Firestore schema change that needs a migration).

**To cut a release**, on `main` after a merge you want to ship:

```
git tag -a v0.1.0 -m "v0.1.0: initial scaffold — calc_core formula engine, app shells, server, CI"
git push origin v0.1.0
```

Then draft a GitHub Release from that tag (**Releases → Draft a new release → choose the tag**)
with notes summarizing what merged since the last tag — Claude will draft these notes for you
each time, from the merged PR titles, so this is mostly copy/paste.

## How Claude actually delivers changes (worth knowing, not just for Claude)

Claude's cloud workspace cannot push directly to this repo — GitHub blocks pushes from that
session's git proxy for security reasons unrelated to this project (see the repo's commit
history / conversation log around 2026-08-26 for the exact error if curious). In practice this
means:

- Claude does the actual implementation work in its own workspace, on a properly named branch,
  with real commits.
- Claude hands the finished branch to Harsh — either directly into this connected local clone
  (via the desktop bridge, as with this file) or as a `git bundle` file to import if the bridge
  isn't connected that session.
- **Harsh pushes the branch and opens the PR** — this is also a good manual double-check step,
  not just a workaround for a technical limitation.
- Once CI is green, Harsh merges (or asks Claude to review the diff first).

This is slightly different from a normal solo-dev flow (no bot user pushing branches directly),
but the PR/CI/merge policy above is otherwise exactly what a small team would do.
