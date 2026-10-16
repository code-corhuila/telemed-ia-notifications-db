User story
code-corhuila/telemed-ia-docs#<!-- issue number --> (HU-<!-- two digits --> — <!-- title -->)

What changes and why
<!-- A few lines. -->

How it was tested

- [ ] db-ci.yml green
- [ ] `bash tests/run-db-tests.sh` ends with `ALL NOTIFICATIONS DB TESTS PASSED`
- [ ] Update on an empty database applies every changeset
- [ ] Second update applies 0 changesets
- [ ] Rollback of every changeset leaves the schema empty
- [ ] Update rebuilds after the rollback

Promotion trail

<!-- Only for PRs targeting qa or main. -->
<!-- List of cherry-picked commits, each with its (cherry picked from commit <sha>) line. -->

Checklist

- [ ] No secrets versioned
- [ ] No schema changes outside this -db repository
- [ ] New changesets only; no applied changeset was edited
- [ ] PR <= 400 lines (tests and generated files excluded)
- [ ] Conventional Commit in the title
