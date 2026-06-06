# Workflow Triggers

All workflows in `.github/workflows/`. Grouped by function, with every trigger listed.

> Plain-text version: [`docs/workflow-triggers.txt`](workflow-triggers.txt)  
> Auto-generated on 2026-06-06 from `.github/workflows/`

---

## Mirror Chain

| Workflow | File | Schedule | Also triggers on |
|---|---|---|---|
| Mirror Artifacts | `mirror-artifacts.yml` | Every 4h at :10 | dispatch |
| Mirror Orgs | `mirror-orgs-full.yml` | Daily 02:00 | dispatch |
| Mirror Watchdog | `mirror-orgs-watchdog.yml` | — | `Mirror Interested-Deving-1896 → OSP` completes · `Mirror Orgs` completes · `Mirror OSP → GitLab` completes · `Mirror Releases` completes · `Mirror Artifacts` completes |
| Mirror OSP → GitLab | `mirror-osp-to-gitlab.yml` | Every 4h at :30 | `Add Mirror Repo` completes · dispatch |
| Mirror to OpenOS-Project-Ecosystem-OOC | `mirror-osp-to-ooc.yaml` | Every 6h at :15 | dispatch |
| Mirror Releases | `mirror-releases.yml` | Every 6h at :03 | dispatch |
| Mirror Interested-Deving-1896 → OSP | `mirror-to-osp.yml` | Every 6h at :00 | dispatch |

---

## OSP-Bound Repo Management

| Workflow | File | Schedule | Also triggers on |
|---|---|---|---|
| Add Mirror Repo | `add-mirror-repo.yml` | — | dispatch |
| Check OSP-Bound CI Status | `check-osp-ci.yml` | Daily 09:05 | `Mirror Interested-Deving-1896 → OSP` completes · `Add Mirror Repo` completes · dispatch |
| Setup OSP Mirror Workflows | `setup-osp-mirrors.yml` | Every 6h at :45 | dispatch |

---

## Fork & Import Sync

| Workflow | File | Schedule | Also triggers on |
|---|---|---|---|
| Import Repository | `import-repo.yml` | — | dispatch |
| Sync btrfs-devel Branches | `sync-btrfs-devel-branches.yml` | Every 6h at :02 | dispatch |
| Sync All Forks | `sync-forks.yml` | Daily 06:07 | dispatch |
| Sync from GitLab | `sync-from-gitlab.yml` | Daily 04:22 | dispatch |
| Sync pieroproietti Forks | `sync-pieroproietti-forks.yml` | Every 4h at :07 | dispatch |
| Sync Registered Imports | `sync-registered-imports.yml` | Every 6h at :55 | dispatch |
| Sync Registry Sources | `sync-registry-sources.yml` | Daily 03:05 | dispatch |
| Sync Upstream Sources | `sync-upstream-sources.yml` | Daily 01:30 | dispatch |
| Upstream Direct Commits from OSP + OOC | `upstream-commits.yml` | Every 6h at :47 | dispatch |
| Upstream PRs from OSP + OOC | `upstream-prs.yml` | Every 6h at :33 | dispatch |

---

## GitLab Sync

| Workflow | File | Schedule | Also triggers on |
|---|---|---|---|
| Sync to GitLab Variant | `sync-to-gitlab-variant.yml` | Every 4h at :50 | push to `config/ota-registry.yml`, `config/ota-blocklist.yml`, `.ota/schema.yml` (+2 more) · dispatch |
| Sync to GitLab | `sync-to-gitlab.yml` | Daily 09:17 | dispatch |

---

## README Management

| Workflow | File | Schedule | Also triggers on |
|---|---|---|---|
| Create Missing READMEs | `create-readmes.yml` | Daily 07:08 | `Add Mirror Repo` completes · `Import Repository` completes · `Clone Org` completes · `Merge Repos into Monorepo` completes · dispatch |
| Inject Built-with-Ona Badges | `inject-badges.yml` | Daily 08:15 | `Mirror OSP → GitLab` completes · dispatch |
| LTS README Standardisation | `lts-readmes.yml` | Monthly 1st 03:00 | `Rebuild LTS Branch (penguins-eggs)` completes · dispatch |
| README Wizard | `readme-wizard.yml` | — | dispatch |
| Translate READMEs | `translate-readmes.yml` | Daily 10:30 | `Update READMEs` completes · `Add Mirror Repo` completes · `Import Repository` completes · `Clone Org` completes · `Merge Repos into Monorepo` completes · `Sync All Forks` completes · `Sync Registered Imports` completes · `Sync from GitLab` completes · `Sync pieroproietti Forks` completes · `Sync Upstream Sources` completes · `Sync penguins-eggs docs to penguins-eggs-book` completes · dispatch |
| Update READMEs | `update-readmes.yml` | Daily 03:15 | push to `config/gitlab-subgroups.yml`, `config/template-manifest.yml` · `Sync Registered Imports` completes · dispatch |
| Validate README Render | `validate-readme-render.yml` | — | push to `README.md` · `Update READMEs` completes · dispatch |

---

## CI & Failure Resolution

| Workflow | File | Schedule | Also triggers on |
|---|---|---|---|
| Check GitLab CI Sync | `check-gitlab-sync.yml` | — | dispatch |
| Notification Poller | `notify-poller.yml` | Every 2h at :32 | dispatch |
| PR Automation | `pr-automation.yml` | — | pull_request |
| Rate-Limit Re-trigger | `rate-limit-rerun.yml` | Every 2h at :05 | dispatch |
| Rate Limit Status | `rate-limit-status.yml` | — | dispatch |
| Rebuild LTS Branch (penguins-eggs) | `rebase-lts.yml` | — | `Sync pieroproietti Forks` completes · dispatch |
| Resolve CI Failures | `resolve-failures.yml` | Daily 07:30 | dispatch |

---

## Maintenance & Housekeeping

| Workflow | File | Schedule | Also triggers on |
|---|---|---|---|
| Cancel Runs After Token Rotation | `cancel-post-rotation.yml` | — | `Rotate Secret Token` completes |
| Cleanup Stale Branches | `cleanup-branches.yml` | Monthly 1st 04:00 | dispatch |
| Cleanup Template Pollution | `cleanup-pollution.yml` | — | dispatch |
| Generate OSP Dependency Graph | `generate-dep-graph.yml` | Weekly Sun 03:10 | dispatch |
| Reconcile Org References | `reconcile-org-refs.yml` | Daily 05:50 | dispatch |
| Rotate Secret Token | `rotate-token.yml` | — | dispatch |
| Sync Template | `sync-template.yml` | — | push to `.devcontainer/**`, `.ona/**`, `config/template-manifest.yml` · dispatch |
| Token Health Monitor | `token-health.yml` | Weekly Mon 09:00 | dispatch |
| Update Infrastructure Dependencies | `update-infra-deps.yml` | Weekly Mon 06:11 | dispatch |
| Update Workflow Triggers Doc | `update-workflow-triggers-doc.yml` | — | push to `.github/workflows/**` · dispatch |
| Upstream Workflow Proposal | `upstream-workflow-proposal.yml` | Weekly Mon 06:06 | dispatch |
| Validate Config | `validate-config.yml` | — | push to `config/gitlab-subgroups.yml`, `config/workflow-sync.yml`, `config/workflow-cost-profiles.yml` (+14 more) · pull_request · dispatch |

---

## Full Pipeline

| Workflow | File | Schedule | Also triggers on |
|---|---|---|---|
| Critical Deploy | `critical-deploy.yml` | — | dispatch |
| Full Chain Flush | `full-chain-flush.yml` | Monthly 1st 05:00 | dispatch |
| Pre-Flush Prep | `pre-flush-prep.yml` | — | dispatch |

---

## Utility / On-Demand

| Workflow | File | Trigger |
|---|---|---|
| Cancel Stale Runs | `cancel-stale-runs.yml` | dispatch |
| Clone Org | `clone-org.yml` | dispatch |
| Docker → Incus Migration | `docker-to-incus.yml` | `Add Mirror Repo` completes · dispatch |
| Fork KDE Neon Repos | `fork-neon-repos.yml` | dispatch |
| GitLab Storage Scan | `gl-storage-scan.yml` | dispatch |
| List Chromium GitLab Repos | `list-chromium-repos.yml` | dispatch |
| Merge Repos into Monorepo | `merge-to-monorepo.yml` | dispatch |
| OTA Discover | `ota-discover.yml` | dispatch |
| Queue Manager | `queue-manager.yml` | dispatch |
| Quota Monitor | `quota-monitor.yml` | dispatch |
| Quota Reserve | `quota-reserve.yml` | dispatch |
| Rebase PRs | `rebase-prs.yml` | `CI` completes · `Validate Config` completes · dispatch |
| Repo Manifest | `repo-manifest.yml` | dispatch |
| Setup GitLab CI Schedules | `setup-gitlab-schedules.yml` | dispatch |
| Shallow Reclone Large GitLab Mirrors | `shallow-reclone-chromium.yml` | dispatch |
| Sync penguins-eggs docs to penguins-eggs-book | `sync-eggs-docs-to-book.yml` | dispatch |
| Trigger Artifact Mirror | `trigger-artifact-mirror.yml` | — |

---

## Schedule Summary (UTC)

| Time | Frequency | Workflow |
|---|---|---|
| 01:30 | Daily | Sync Upstream Sources |
| 02:00 | Daily | Mirror Orgs |
| at :05 | Every 2h | Rate-Limit Re-trigger |
| at :32 | Every 2h | Notification Poller |
| 1st 03:00 | Monthly | LTS README Standardisation |
| 03:05 | Daily | Sync Registry Sources |
| Sun 03:08 | Weekly | Docker → Incus Migration |
| Sun 03:10 | Weekly | Generate OSP Dependency Graph |
| 03:15 | Daily | Update READMEs |
| 1st 04:00 | Monthly | Cleanup Stale Branches |
| at :07 | Every 4h | Sync pieroproietti Forks |
| at :10 | Every 4h | Mirror Artifacts |
| 04:22 | Daily | Sync from GitLab |
| at :30 | Every 4h | Mirror OSP → GitLab |
| at :50 | Every 4h | Sync to GitLab Variant |
| 1st 05:00 | Monthly | Full Chain Flush |
| 05:10 | Daily | Rebase PRs |
| 05:50 | Daily | Reconcile Org References |
| at :00 | Every 6h | Mirror Interested-Deving-1896 → OSP |
| at :02 | Every 6h | Sync btrfs-devel Branches |
| at :03 | Every 6h | Mirror Releases |
| Mon 06:06 | Weekly | Upstream Workflow Proposal |
| 06:07 | Daily | Sync All Forks |
| Mon 06:11 | Weekly | Update Infrastructure Dependencies |
| at :15 | Every 6h | Mirror to OpenOS-Project-Ecosystem-OOC |
| at :33 | Every 6h | Upstream PRs from OSP + OOC |
| 06:45 | Daily | OTA Discover |
| at :45 | Every 6h | Setup OSP Mirror Workflows |
| at :47 | Every 6h | Upstream Direct Commits from OSP + OOC |
| at :55 | Every 6h | Sync Registered Imports |
| 07:08 | Daily | Create Missing READMEs |
| 07:30 | Daily | Resolve CI Failures |
| 08:15 | Daily | Inject Built-with-Ona Badges |
| Mon 09:00 | Weekly | Token Health Monitor |
| 09:05 | Daily | Check OSP-Bound CI Status |
| 09:17 | Daily | Sync to GitLab |
| 10:30 | Daily | Translate READMEs |
|  | Every 15 min | Queue Manager |
|  | Every 10 min | Quota Reserve |
