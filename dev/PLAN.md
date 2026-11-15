# pubflow v0.1 — open work

One PR per session, from a branch off `main`. Read `../AGENTS.md` and the decisions in
`DESIGN.md` that touch the work first. Remove items here once they are done or settled
(DESIGN.md keeps the decisions, NEWS.md what each version added). If DESIGN.md
contradicts what pipeflow, huxtable or pandoc do, stop and ask, and record the outcome
in the decision log in the same PR.

**Definition of done** (every PR): the checks of "Before opening a PR" in `AGENTS.md`,
a NEWS entry and the development version bumped by one, see
`.github/workflows/version-bump.yaml`; label PRs that change only documentation or CI
`no-version-bump`.

## Release v0.1.0 (first CRAN version)

- [ ] pubflow validated in a real project; findings fixed.
- [ ] pipeflow 0.6.0 on CRAN; `Remotes` and the pin removed.
- [ ] R CMD check 0/0/0, version 0.1.0 with a NEWS heading, tag `v0.1.0`, GitHub
  release, CRAN submission.

---

## Later

Later versions: see `DESIGN.md` §1. Deferred ideas are GitHub issues labelled `maybe`
(`gh issue list --label maybe`): mention the ones that touch the current work.
