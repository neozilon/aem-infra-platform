// AEM Platform Portal — frontend. Plain JS, no build step.
const $ = (id) => document.getElementById(id);

const api = async (path, opts = {}) => {
  const res = await fetch(`/api${path}`, {
    headers: opts.body instanceof FormData ? {} : { "Content-Type": "application/json" },
    ...opts,
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(body.error || res.statusText);
  return body;
};

const msg = (id, text, ok = true) => {
  const el = $(id);
  el.textContent = text;
  el.className = `msg ${ok ? "ok" : "err"}`;
};

// --- Theme -------------------------------------------------------------------
$("btn-theme").onclick = () => {
  const root = document.documentElement;
  const dark = root.dataset.theme
    ? root.dataset.theme === "dark"
    : matchMedia("(prefers-color-scheme: dark)").matches;
  root.dataset.theme = dark ? "light" : "dark";
};

// --- Login -------------------------------------------------------------------
$("btn-login").onclick = async () => {
  try {
    await api("/login", { method: "POST", body: JSON.stringify({ user: $("login-user").value, pass: $("login-pass").value }) });
    $("view-login").classList.add("hidden");
    $("view-main").classList.remove("hidden");
    $("main-tabs").classList.remove("hidden");
    loadConfig(); refreshChecks();
  } catch (e) { msg("login-msg", e.message, false); }
};
$("login-pass").addEventListener("keydown", (e) => { if (e.key === "Enter") $("btn-login").click(); });

// --- Tabs ---------------------------------------------------------------------
const showTab = (name) => {
  $("pane-deploy").classList.toggle("hidden", name !== "deploy");
  $("pane-setup").classList.toggle("hidden", name !== "setup");
  $("tab-deploy").classList.toggle("active", name === "deploy");
  $("tab-setup").classList.toggle("active", name === "setup");
};
$("tab-deploy").onclick = () => { showTab("deploy"); refreshChecks(); };
$("tab-setup").onclick = () => showTab("setup");

// --- Config -------------------------------------------------------------------
async function loadConfig() {
  try {
    const c = await api("/config");
    if (c.owner) $("cf-owner").value = c.owner;
    if (c.repo) $("cf-repo").value = c.repo;
    if (c.region) $("cf-region").value = c.region;
  } catch { /* not logged in yet */ }
}

$("btn-config").onclick = async () => {
  try {
    msg("cf-msg", "validating…");
    const r = await api("/config", { method: "POST", body: JSON.stringify({
      owner: $("cf-owner").value.trim(), repo: $("cf-repo").value.trim(), region: $("cf-region").value.trim(),
      ghToken: $("cf-gh").value.trim(), awsKeyId: $("cf-key").value.trim(), awsSecret: $("cf-secret").value.trim(),
    })});
    const parts = [];
    if (r.githubUser) parts.push(`GitHub: @${r.githubUser}`);
    if (r.awsIdentity) parts.push(`AWS: ${r.awsIdentity}`);
    msg("cf-msg", `✓ saved. ${parts.join("  ·  ")}`);
    refreshChecks();
  } catch (e) { msg("cf-msg", e.message, false); }
};

// --- Readiness checklist --------------------------------------------------------
async function refreshChecks() {
  try {
    const { checks } = await api("/status");
    $("checks").innerHTML = checks.map((c) => `
      <div class="check">
        <span class="dot ${c.ok ? "ok" : "bad"}"></span>
        <span>${c.name}</span>
        <small>${c.detail || (c.ok ? "" : "pending")}</small>
      </div>`).join("");
  } catch (e) {
    $("checks").innerHTML = `<div class="msg err">${e.message}</div>`;
  }
}

// --- AWS bootstrap ---------------------------------------------------------------
$("btn-bootstrap").onclick = async () => {
  try {
    msg("bs-msg", "placing temporary secrets and dispatching bootstrap-aws…");
    const { runId, url } = await api("/aws-bootstrap", { method: "POST" });
    msg("bs-msg", `running… (${url})`);
    await pollRun(runId, (state) => msg("bs-msg", `bootstrap-aws: ${state}`));
    await api("/aws-bootstrap/cleanup", { method: "POST" });
    msg("bs-msg", "✓ AWS plumbing created; temporary secrets removed.");
    refreshChecks();
  } catch (e) { msg("bs-msg", e.message, false); }
};

// --- Binaries ---------------------------------------------------------------------
$("btn-binaries").onclick = async () => {
  try {
    const fd = new FormData();
    for (const [field, fileId, urlId] of [
      ["jar", "bin-jar", "bin-jar-url"],
      ["license", "bin-license", "bin-license-url"],
      ["dispatcher", "bin-dispatcher", "bin-dispatcher-url"],
    ]) {
      const f = $(fileId).files[0];
      if (f) fd.append(field, f);
      const u = $(urlId).value.trim();
      if (u) fd.append(`${field}Url`, u);
    }
    msg("bin-msg", "uploading to your private seed bucket… (the jar takes a few minutes)");
    const r = await api("/binaries", { method: "POST", body: fd });
    msg("bin-msg", `✓ uploaded: ${r.uploaded.join(", ")} → s3://${r.bucket}`);
    refreshChecks();
  } catch (e) { msg("bin-msg", e.message, false); }
};

// --- Variables ----------------------------------------------------------------------
$("btn-variables").onclick = async () => {
  try {
    msg("var-msg", "setting variables…");
    const r = await api("/variables", { method: "POST", body: JSON.stringify({
      adminPassword: $("var-pass").value || undefined, environment: "dev",
    })});
    msg("var-msg", `✓ wired (seed bucket: ${r.seedBucket})`);
    refreshChecks();
  } catch (e) { msg("var-msg", e.message, false); }
};

// --- Deploy / progress -----------------------------------------------------------------
const STEP_LABELS = [
  [/^terraform-/, "Provision infrastructure (VPC, EC2, ALB)"],
  [/^wait-aem-/, "Wait for AEM to boot"],
  [/^build-package$/, "Build the AEM application"],
  [/^deploy-/, "Install app on Author & Publish"],
  [/^configure-/, "Replication, cache flush & hardening"],
  [/^verify-/, "Smoke test & publish URL"],
];

function renderSteps(jobs) {
  const ul = $("dep-steps");
  ul.classList.remove("hidden");
  ul.innerHTML = jobs.map((j) => {
    const label = (STEP_LABELS.find(([re]) => re.test(j.name)) || [null, j.name])[1];
    let icon = `<span class="dot pend"></span>`, badge = "queued";
    if (j.status === "in_progress") { icon = `<span class="spin"></span>`; badge = "running"; }
    else if (j.conclusion === "success") { icon = `<span class="dot ok"></span>`; badge = "done"; }
    else if (j.conclusion && j.conclusion !== "success") { icon = `<span class="dot bad"></span>`; badge = j.conclusion; }
    return `<li>${icon}<span class="stepname">${label}</span><span class="badge">${badge}</span></li>`;
  }).join("");
}

async function pollRun(runId, onTick) {
  for (;;) {
    const r = await api(`/run/${runId}`);
    if (r.jobs?.length) renderSteps(r.jobs);
    onTick?.(r.status);
    if (r.status === "completed") {
      if (r.conclusion !== "success") throw new Error(`run finished: ${r.conclusion} — details: ${r.html_url}`);
      return r;
    }
    await new Promise((res) => setTimeout(res, 15000));
  }
}

$("btn-deploy").onclick = async () => {
  try {
    $("btn-deploy").disabled = true;
    $("live-wrap").classList.add("hidden");
    msg("dep-msg", "dispatching provision…");
    const { runId, url } = await api("/deploy", { method: "POST", body: JSON.stringify({
      environment: $("dep-env").value, harden: $("dep-harden").value === "true",
    })});
    msg("dep-msg", `provisioning — grab a coffee ☕ (${url})`);
    await pollRun(runId);
    const { url: site } = await api(`/site-url?run=${runId}`);
    msg("dep-msg", "✓ provision complete");
    if (site) {
      $("live-url").textContent = site;
      $("live-url").href = site;
      $("live-wrap").classList.remove("hidden");
    }
  } catch (e) { msg("dep-msg", e.message, false); }
  finally { $("btn-deploy").disabled = false; }
};

$("btn-destroy").onclick = async () => {
  if (!confirm(`Destroy the '${$("dep-env").value}' environment?`)) return;
  try {
    $("btn-destroy").disabled = true;
    msg("dep-msg", "dispatching destroy…");
    const { runId, url } = await api("/destroy", { method: "POST", body: JSON.stringify({ environment: $("dep-env").value }) });
    msg("dep-msg", `destroying… (${url})`);
    await pollRun(runId, (s) => msg("dep-msg", `destroy: ${s}`));
    $("live-wrap").classList.add("hidden");
    $("dep-steps").classList.add("hidden");
    msg("dep-msg", "✓ environment destroyed — nothing left running");
  } catch (e) { msg("dep-msg", e.message, false); }
  finally { $("btn-destroy").disabled = false; }
};
