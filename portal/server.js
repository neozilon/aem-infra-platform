// AEM Platform Portal — single-user self-service UI over the platform pipelines.
// Drives the SAME GitHub workflows a human would (provision, deploy-infra,
// bootstrap-aws) and shells out to the aws CLI for the few account-side steps
// (seed-bucket upload, identity checks). Credentials live in MEMORY only.
import express from "express";
import multer from "multer";
import { createRequire } from "node:module";
import { execFile } from "node:child_process";
// libsodium-wrappers ships a broken ESM entry (missing libsodium.mjs); load CJS.
const sodium = createRequire(import.meta.url)("libsodium-wrappers");
import { randomBytes } from "node:crypto";
import { promisify } from "node:util";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const execFileP = promisify(execFile);

const PORT = process.env.PORT || 3210;
const USER = process.env.PORTAL_USER || "demo";
const PASS = process.env.PORTAL_PASS || "demo";
if (!process.env.PORTAL_PASS) {
  console.warn("⚠️  PORTAL_PASS not set — using demo/demo (fine for the university demo only)");
}

// --- In-memory state ---------------------------------------------------------
const sessions = new Set();
const cfg = {
  owner: process.env.GH_OWNER || "",
  repo: process.env.GH_REPO || "aem-infra-platform",
  region: process.env.AWS_REGION || "us-east-1",
  ghToken: "",
  awsKeyId: "",
  awsSecret: "",
  accountId: "",
};

const upload = multer({ dest: path.join(os.tmpdir(), "portal-uploads"), limits: { fileSize: 1024 * 1024 * 1024 } });

// --- Helpers -----------------------------------------------------------------
const gh = async (pathname, opts = {}) => {
  const res = await fetch(`https://api.github.com${pathname}`, {
    ...opts,
    headers: {
      Authorization: `Bearer ${cfg.ghToken}`,
      Accept: "application/vnd.github+json",
      "Content-Type": "application/json",
      ...(opts.headers || {}),
    },
  });
  if (opts.raw) return res;
  const text = await res.text();
  let body;
  try { body = text ? JSON.parse(text) : {}; } catch { body = { raw: text }; }
  if (!res.ok) throw new Error(`GitHub ${pathname} → ${res.status}: ${body.message || text}`);
  return body;
};

const aws = async (args, extraEnv = {}) => {
  const { stdout } = await execFileP("aws", args, {
    env: {
      ...process.env,
      AWS_ACCESS_KEY_ID: cfg.awsKeyId,
      AWS_SECRET_ACCESS_KEY: cfg.awsSecret,
      AWS_DEFAULT_REGION: cfg.region,
      ...extraEnv,
    },
    maxBuffer: 16 * 1024 * 1024,
  });
  return stdout.trim();
};

const repoPath = () => `/repos/${cfg.owner}/${cfg.repo}`;
const seedBucket = () => `aem-platform-binaries-seed-${cfg.accountId}`;

async function putSecret(name, value) {
  await sodium.ready;
  const { key, key_id } = await gh(`${repoPath()}/actions/secrets/public-key`);
  const sealed = sodium.crypto_box_seal(sodium.from_string(value), sodium.from_base64(key, sodium.base64_variants.ORIGINAL));
  await gh(`${repoPath()}/actions/secrets/${name}`, {
    method: "PUT",
    body: JSON.stringify({ encrypted_value: sodium.to_base64(sealed, sodium.base64_variants.ORIGINAL), key_id }),
  });
}

async function dispatch(workflow, inputs) {
  await gh(`${repoPath()}/actions/workflows/${workflow}/dispatches`, {
    method: "POST",
    body: JSON.stringify({ ref: "main", inputs }),
  });
  // find the run this dispatch created (newest run of that workflow)
  for (let i = 0; i < 15; i++) {
    await new Promise((r) => setTimeout(r, 3000));
    const { workflow_runs } = await gh(`${repoPath()}/actions/workflows/${workflow}/runs?per_page=1&event=workflow_dispatch`);
    if (workflow_runs?.length && new Date(workflow_runs[0].created_at) > new Date(Date.now() - 90_000)) {
      return workflow_runs[0];
    }
  }
  throw new Error("dispatched, but the run did not appear — check the Actions tab");
}

// --- App ---------------------------------------------------------------------
const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

app.post("/api/login", (req, res) => {
  const { user, pass } = req.body || {};
  if (user === USER && pass === PASS) {
    const token = randomBytes(24).toString("hex");
    sessions.add(token);
    res.cookie?.("s", token); // express without cookie-parser: set manually
    res.setHeader("Set-Cookie", `s=${token}; HttpOnly; SameSite=Strict; Path=/`);
    return res.json({ ok: true });
  }
  res.status(401).json({ error: "invalid credentials" });
});

const auth = (req, res, next) => {
  const token = (req.headers.cookie || "").split(";").map((c) => c.trim()).find((c) => c.startsWith("s="))?.slice(2);
  if (token && sessions.has(token)) return next();
  res.status(401).json({ error: "not logged in" });
};

app.get("/api/config", auth, (_req, res) => {
  res.json({
    owner: cfg.owner, repo: cfg.repo, region: cfg.region, accountId: cfg.accountId,
    ghTokenSet: !!cfg.ghToken, awsKeySet: !!cfg.awsKeyId,
  });
});

app.post("/api/config", auth, async (req, res) => {
  try {
    const { owner, repo, region, ghToken, awsKeyId, awsSecret } = req.body || {};
    if (owner) cfg.owner = owner;
    if (repo) cfg.repo = repo;
    if (region) cfg.region = region;
    if (ghToken) cfg.ghToken = ghToken;
    if (awsKeyId) cfg.awsKeyId = awsKeyId;
    if (awsSecret) cfg.awsSecret = awsSecret;

    const out = {};
    if (cfg.ghToken) {
      const me = await gh("/user");
      out.githubUser = me.login;
      if (!cfg.owner) cfg.owner = me.login;
    }
    if (cfg.awsKeyId && cfg.awsSecret) {
      const id = JSON.parse(await aws(["sts", "get-caller-identity", "--output", "json"]));
      cfg.accountId = id.Account;
      out.awsIdentity = id.Arn;
    }
    res.json({ ok: true, ...out });
  } catch (e) {
    res.status(400).json({ error: String(e.message || e) });
  }
});

// Overall readiness checklist for the dashboard
app.get("/api/status", auth, async (_req, res) => {
  const out = { checks: [] };
  const check = (name, ok, detail = "") => out.checks.push({ name, ok, detail });
  try {
    check("GitHub token", !!cfg.ghToken);
    check("AWS credentials", !!cfg.awsKeyId && !!cfg.accountId, cfg.accountId ? `account ${cfg.accountId}` : "");
    if (cfg.ghToken && cfg.owner) {
      try {
        await gh(`${repoPath()}`);
        check("Platform repository", true, `${cfg.owner}/${cfg.repo}`);
        const wf = await gh(`${repoPath()}/actions/workflows`);
        check("provision workflow", wf.workflows?.some((w) => w.path.endsWith("provision.yml")) || false);
      } catch (e) { check("Platform repository", false, String(e.message)); }
    }
    if (cfg.accountId) {
      try {
        const roles = await aws(["iam", "list-roles", "--query", "Roles[?starts_with(RoleName,`gha-aem`)].RoleName", "--output", "text"]);
        check("OIDC deploy roles", roles.split(/\s+/).filter(Boolean).length >= 3, roles);
      } catch { check("OIDC deploy roles", false, "run AWS bootstrap"); }
      try {
        const objs = await aws(["s3", "ls", `s3://${seedBucket()}/`]);
        const haveJar = /quickstart.*\.jar/.test(objs);
        const haveLic = /license\.properties/.test(objs);
        const haveDisp = /dispatcher-apache/.test(objs);
        check("Licensed binaries in seed bucket", haveJar && haveLic && haveDisp,
          `jar:${haveJar} license:${haveLic} dispatcher:${haveDisp}`);
      } catch { check("Licensed binaries in seed bucket", false, "bucket missing — run AWS bootstrap"); }
    }
    res.json(out);
  } catch (e) {
    res.status(500).json({ error: String(e.message || e), ...out });
  }
});

// One-time AWS plumbing: temp secrets → bootstrap-aws workflow → delete secrets
app.post("/api/aws-bootstrap", auth, async (_req, res) => {
  try {
    if (!cfg.awsKeyId || !cfg.ghToken) throw new Error("set GitHub token and AWS key first");
    await putSecret("AWS_BOOTSTRAP_ACCESS_KEY_ID", cfg.awsKeyId);
    await putSecret("AWS_BOOTSTRAP_SECRET_ACCESS_KEY", cfg.awsSecret);
    const run = await dispatch("bootstrap-aws.yml", {});
    res.json({ ok: true, runId: run.id, url: run.html_url });
  } catch (e) {
    res.status(400).json({ error: String(e.message || e) });
  }
});

// Called by the UI when bootstrap-aws finishes: remove the temporary secrets
app.post("/api/aws-bootstrap/cleanup", auth, async (_req, res) => {
  try {
    for (const s of ["AWS_BOOTSTRAP_ACCESS_KEY_ID", "AWS_BOOTSTRAP_SECRET_ACCESS_KEY"]) {
      await gh(`${repoPath()}/actions/secrets/${s}`, { method: "DELETE" }).catch(() => {});
    }
    res.json({ ok: true });
  } catch (e) {
    res.status(400).json({ error: String(e.message || e) });
  }
});

// Licensed binaries: upload (multipart) or fetch-from-URL → client's seed bucket
app.post("/api/binaries", auth,
  upload.fields([{ name: "jar" }, { name: "license" }, { name: "dispatcher" }]),
  async (req, res) => {
    const tmpFiles = [];
    try {
      if (!cfg.accountId) throw new Error("validate AWS credentials first");
      const items = [
        { field: "jar", url: req.body.jarUrl, key: "cq-quickstart-6.6.0.jar" },
        { field: "license", url: req.body.licenseUrl, key: "license.properties" },
        { field: "dispatcher", url: req.body.dispatcherUrl, key: "dispatcher-apache2.4-linux-x86_64-ssl3.0-4.3.8.tar.gz" },
      ];
      const uploaded = [];
      for (const item of items) {
        let file = req.files?.[item.field]?.[0]?.path;
        if (!file && item.url) {
          file = path.join(os.tmpdir(), `portal-dl-${item.field}`);
          await execFileP("curl", ["-sfL", "--max-time", "600", item.url, "-o", file]);
          tmpFiles.push(file);
        } else if (file) {
          tmpFiles.push(file);
        }
        if (!file) continue; // optional per-field: client may upload in stages
        await aws(["s3", "cp", file, `s3://${seedBucket()}/${item.key}`, "--no-progress"]);
        uploaded.push(item.key);
      }
      if (!uploaded.length) throw new Error("no file or URL provided");
      res.json({ ok: true, uploaded, bucket: seedBucket() });
    } catch (e) {
      res.status(400).json({ error: String(e.message || e) });
    } finally {
      for (const f of tmpFiles) fs.rm(f, { force: true }, () => {});
    }
  });

// Wire the GitHub Actions variables the pipelines expect
app.post("/api/variables", auth, async (req, res) => {
  try {
    if (!cfg.accountId) throw new Error("validate AWS credentials first");
    const putVar = async (scope, name, value) => {
      const base = scope === "repo"
        ? `${repoPath()}/actions/variables`
        : `${repoPath()}/environments/${scope}/variables`;
      const r = await fetch(`https://api.github.com${base}`, {
        method: "POST",
        headers: { Authorization: `Bearer ${cfg.ghToken}`, Accept: "application/vnd.github+json", "Content-Type": "application/json" },
        body: JSON.stringify({ name, value }),
      });
      if (r.status === 409) {
        await gh(`${base}/${name}`, { method: "PATCH", body: JSON.stringify({ name, value }) });
      } else if (!r.ok) throw new Error(`set ${name} → ${r.status}`);
    };
    await putVar("repo", "BINARIES_SEED_BUCKET", seedBucket());
    for (const env of ["dev", "stage", "prod"]) {
      await putVar(env, "AWS_ROLE_ARN", `arn:aws:iam::${cfg.accountId}:role/gha-aem-${env}`);
    }
    // Optional admin password → environment secret (needed for harden)
    if (req.body?.adminPassword) {
      await sodium.ready;
      const { key, key_id } = await gh(`${repoPath()}/actions/secrets/public-key`);
      const sealed = sodium.crypto_box_seal(sodium.from_string(req.body.adminPassword), sodium.from_base64(key, sodium.base64_variants.ORIGINAL));
      const repoInfo = await gh(repoPath());
      await gh(`/repositories/${repoInfo.id}/environments/${req.body.environment || "dev"}/secrets/AEM_ADMIN_PASSWORD`, {
        method: "PUT",
        body: JSON.stringify({ encrypted_value: sodium.to_base64(sealed, sodium.base64_variants.ORIGINAL), key_id }),
      });
    }
    res.json({ ok: true, seedBucket: seedBucket() });
  } catch (e) {
    res.status(400).json({ error: String(e.message || e) });
  }
});

// The one click.
app.post("/api/deploy", auth, async (req, res) => {
  try {
    const { environment = "dev", harden = false } = req.body || {};
    const run = await dispatch("provision.yml", { environment, harden: String(harden) });
    res.json({ ok: true, runId: run.id, url: run.html_url });
  } catch (e) {
    res.status(400).json({ error: String(e.message || e) });
  }
});

app.post("/api/destroy", auth, async (req, res) => {
  try {
    const { environment = "dev" } = req.body || {};
    const run = await dispatch("deploy-infra.yml", { environment, action: "destroy" });
    res.json({ ok: true, runId: run.id, url: run.html_url });
  } catch (e) {
    res.status(400).json({ error: String(e.message || e) });
  }
});

// Progress: run + its jobs (the UI renders the timeline from this)
app.get("/api/run/:id", auth, async (req, res) => {
  try {
    const run = await gh(`${repoPath()}/actions/runs/${req.params.id}`);
    const { jobs } = await gh(`${repoPath()}/actions/runs/${req.params.id}/jobs?per_page=30`);
    res.json({
      status: run.status, conclusion: run.conclusion, html_url: run.html_url,
      jobs: jobs.map((j) => ({ name: j.name, status: j.status, conclusion: j.conclusion, started: j.started_at })),
    });
  } catch (e) {
    res.status(400).json({ error: String(e.message || e) });
  }
});

// Site URL: grep the verify job's log of the given (or latest good) provision run
app.get("/api/site-url", auth, async (req, res) => {
  try {
    let runId = req.query.run;
    if (!runId) {
      const { workflow_runs } = await gh(`${repoPath()}/actions/workflows/provision.yml/runs?per_page=5&status=success`);
      runId = workflow_runs?.[0]?.id;
    }
    if (!runId) return res.json({ url: null });
    const { jobs } = await gh(`${repoPath()}/actions/runs/${runId}/jobs?per_page=30`);
    const verify = jobs.find((j) => j.name.startsWith("verify"));
    if (!verify) return res.json({ url: null });
    const logRes = await gh(`${repoPath()}/actions/jobs/${verify.id}/logs`, { raw: true });
    const text = await logRes.text();
    const m = text.match(/SITE URL: (\S+)/);
    res.json({ url: m ? m[1] : null });
  } catch (e) {
    res.status(400).json({ error: String(e.message || e) });
  }
});

app.listen(PORT, () => {
  console.log(`AEM Platform Portal → http://localhost:${PORT}  (login: ${USER}/${process.env.PORTAL_PASS ? "****" : "demo"})`);
});
