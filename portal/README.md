# portal — self-service one-click UI

Single-user web app that takes a "client" from credentials to a running,
cached AEM site on AWS by driving the platform's own GitHub workflows. It
automates the entire `docs/runbooks/new-client-setup.md` flow behind two tabs:

- **First-time setup:** validate GitHub token + AWS key → run the AWS account
  bootstrap (`bootstrap-aws` workflow, with the key held as a *temporary* repo
  secret and removed right after) → upload the client's **own** licensed AEM
  binaries (file upload or URL) to *their* private S3 seed bucket → wire the
  Actions variables (`BINARIES_SEED_BUCKET`, per-env `AWS_ROLE_ARN`, optional
  admin-password secret).
- **Deploy:** readiness checklist, then one **Deploy** button that dispatches
  the `provision` workflow and renders a live step timeline (infra → AEM boot →
  app → configure/harden → verify). When the run finishes, the public site URL
  appears. **Destroy** tears the environment down the same way.

## Run

```bash
cd portal
npm install
PORTAL_USER=admin PORTAL_PASS=change-me npm start
# → http://localhost:3210   (defaults to demo/demo if PORTAL_PASS is unset)
```

Requires Node ≥ 18 and the `aws` CLI on PATH (used for the seed-bucket upload
and identity checks — the deploy itself runs on GitHub runners via OIDC).

## Security model (demo scope)

- Single user; session cookie; credentials kept **in memory only** (re-enter
  after a restart, nothing persisted to disk).
- The AWS access key is used for first-time setup only; the pipelines
  authenticate via OIDC. Delete the key in IAM after setup.
- Licensed binaries go straight to the client's private bucket — the portal
  never stores them beyond a temp file during upload, and they are never in git.
- Production-grade multi-tenant version (user accounts, encrypted vault, cost
  dashboards) is documented as future work in the report.
