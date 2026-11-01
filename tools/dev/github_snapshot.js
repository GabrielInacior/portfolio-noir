// Snapshot público do GitHub no build (sem token no cliente): perfil, repos públicos, estrelas,
// linguagens e último commit. Repositórios privados entram só com dados aprovados em projects.json.
// Uso: node tools/dev/github_snapshot.js  (usa `gh` autenticado só para montar o snapshot local)
const { execSync } = require("child_process");
const fs = require("fs");
const USER = "GabrielInacior";
function gh(path) { return JSON.parse(execSync(`gh api "${path}"`, { encoding: "utf8", maxBuffer: 1 << 24 })); }
const prof = gh(`users/${USER}`);
const repos = gh(`users/${USER}/repos?per_page=100&sort=updated`);
const pick = repos.filter((r) => !r.fork).slice(0, 30).map((r) => ({
  name: r.name, desc: r.description || "", stars: r.stargazers_count,
  lang: r.language || "", private: r.private, updated: (r.updated_at || "").slice(0, 10),
  url: r.private ? null : r.html_url, homepage: r.homepage || null,
}));
const langCount = {};
for (const r of repos) if (r.language) langCount[r.language] = (langCount[r.language] || 0) + 1;
const langs = Object.entries(langCount).sort((a, b) => b[1] - a[1]).slice(0, 10).map(([k, v]) => ({ lang: k, count: v }));
const out = {
  generated: new Date().toISOString().slice(0, 10),
  login: prof.login, name: prof.name, bio: prof.bio,
  public_repos: prof.public_repos, followers: prof.followers,
  total_stars: repos.reduce((s, r) => s + (r.stargazers_count || 0), 0),
  languages: langs, repos: pick,
};
fs.writeFileSync("data/github_snapshot.json", JSON.stringify(out, null, 2));
fs.writeFileSync("game/assets/data/github_snapshot.json", JSON.stringify(out));
console.log("ok", pick.length, "repos,", out.total_stars, "estrelas,", langs.length, "linguagens");
