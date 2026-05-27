#!/usr/bin/env bash
# Seed patchset branches across all architecture kernel-base repos.
#
# For each architecture, creates branches in {arch}-deb-linux-kernel-base:
#
#   patchset/xanmod/{distro}/{release}     (where support matrix = True)
#   patchset/liquorix/{distro}/{release}
#   patchset/liqxanmod/{distro}/{release}
#
# Branches are created from the 'main' branch (upstream kernel HEAD).
# Architectures with support=False get a scaffold branch with a README only.
#
# Usage:
#   ./seed-patchset-branches.sh [--arch amd64 arm64 ...]
#   ./seed-patchset-branches.sh --dry-run
set -euo pipefail

KERNEL_DIR="/workspaces/linux-kernel"
USER="Interested-Deving-1896"
export GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"

ARCHS=(amd64 arm64 armhf riscv64 s390x armel ppc64el mips64el loong64 i686)
DRY_RUN=false

# Patchset support matrix (mirrors create-arch-repos.py)
declare -A XANMOD_SUPPORT=(
  [amd64]=true  [arm64]=true  [armhf]=false [armel]=false
  [riscv64]=false [ppc64el]=false [s390x]=false
  [mips64el]=false [loong64]=false [i686]=false [i386]=true
)
declare -A LIQUORIX_SUPPORT=(
  [amd64]=true  [arm64]=true  [armhf]=true  [armel]=false
  [riscv64]=false [ppc64el]=false [s390x]=false
  [mips64el]=false [loong64]=false [i686]=false [i386]=true
)
declare -A LIQXANMOD_SUPPORT=(
  [amd64]=true  [arm64]=true  [armhf]=false [armel]=false
  [riscv64]=false [ppc64el]=false [s390x]=false
  [mips64el]=false [loong64]=false [i686]=false [i386]=true
)

DEBIAN_RELEASES=(trixie forky sid)
DEVUAN_RELEASES=(excalibur forky ceres)
UBUNTU_RELEASES=(resolute stonking devel)

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --arch) shift; ARCHS=("$@"); break ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$GH_TOKEN" ]]; then
  echo "ERROR: GH_TOKEN not set" >&2
  exit 1
fi

if [[ ! -d "$KERNEL_DIR/.git" ]]; then
  echo "ERROR: Kernel not cloned at $KERNEL_DIR" >&2
  exit 1
fi

echo "=== Seed patchset branches ==="
echo "Architectures: ${ARCHS[*]}"
echo "Dry run: $DRY_RUN"
echo "Started: $(date -u)"
echo ""

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

total=0
failed=0

create_scaffold_readme() {
  local patchset="$1" arch="$2" distro="$3" release="$4" supported="$5"
  local readme="$WORK_DIR/README.md"

  if [[ "$supported" == "true" ]]; then
    cat > "$readme" <<EOF
# ${patchset^} — ${arch} / ${distro^} ${release^}

Patchset branch for applying ${patchset} patches to the ${distro^} ${release^} kernel on ${arch}.

## Status

Active — real patchset content.

## Upstream

- Patchset: https://github.com/xanmod/linux (xanmod) / https://liquorix.net (liquorix)
- Base: \`main\` branch of this repo (upstream kernel v6.9)

## Usage

\`\`\`bash
git checkout patchset/${patchset}/${distro}/${release}
git rebase main
\`\`\`
EOF
  else
    cat > "$readme" <<EOF
# ${patchset^} — ${arch} / ${distro^} ${release^} (scaffold)

Scaffold branch — ${patchset} does not officially support ${arch}.

This branch exists as a placeholder for future porting work.

## Status

Scaffold only — no real patchset content yet.
EOF
  fi
}

seed_branch() {
  local repo="$1" branch="$2" patchset="$3" arch="$4" distro="$5" release="$6" supported="$7"
  local remote="https://x-access-token:${GH_TOKEN}@github.com/${USER}/${repo}.git"
  local clone_dir="$WORK_DIR/repo-clone"

  if $DRY_RUN; then
    echo "  [dry-run] branch ${branch} → ${USER}/${repo} (supported=${supported})"
    return 0
  fi

  # Clone repo if not already cloned for this iteration
  if [[ ! -d "$clone_dir/.git" ]]; then
    git clone --depth=1 "$remote" "$clone_dir" --quiet 2>&1 || {
      echo "  ✗ clone failed: ${repo}"
      ((failed++)) || true
      return 1
    }
  fi

  # Create branch from main
  git -C "$clone_dir" checkout -b "$branch" "origin/main" --quiet 2>/dev/null || \
    git -C "$clone_dir" checkout "$branch" --quiet 2>/dev/null || {
      echo "  ✗ branch checkout failed: ${branch}"
      ((failed++)) || true
      return 1
    }

  # Add scaffold README
  create_scaffold_readme "$patchset" "$arch" "$distro" "$release" "$supported"
  cp "$WORK_DIR/README.md" "$clone_dir/PATCHSET.md"
  git -C "$clone_dir" add "PATCHSET.md"
  git -C "$clone_dir" commit -m "scaffold: ${patchset} patchset for ${distro}/${release} on ${arch}" \
    --quiet --allow-empty 2>/dev/null || true

  git -C "$clone_dir" push origin "${branch}" --quiet 2>&1 && \
    echo "  ✓ ${branch}" || { echo "  ✗ push failed: ${branch}"; ((failed++)) || true; }

  # Reset for next branch
  git -C "$clone_dir" checkout main --quiet 2>/dev/null || true
}

for arch in "${ARCHS[@]}"; do
  echo "--- ${arch} ---"
  repo="${arch}-deb-linux-kernel-base"
  clone_dir="$WORK_DIR/repo-clone"
  rm -rf "$clone_dir"

  declare -A patchset_support=(
    [xanmod]="${XANMOD_SUPPORT[$arch]:-false}"
    [liquorix]="${LIQUORIX_SUPPORT[$arch]:-false}"
    [liqxanmod]="${LIQXANMOD_SUPPORT[$arch]:-false}"
  )

  for patchset in xanmod liquorix liqxanmod; do
    supported="${patchset_support[$patchset]}"

    # Debian releases
    for release in "${DEBIAN_RELEASES[@]}"; do
      branch="patchset/${patchset}/debian/${release}"
      seed_branch "$repo" "$branch" "$patchset" "$arch" "debian" "$release" "$supported"
      ((total++)) || true
    done

    # Devuan releases
    for release in "${DEVUAN_RELEASES[@]}"; do
      branch="patchset/${patchset}/devuan/${release}"
      seed_branch "$repo" "$branch" "$patchset" "$arch" "devuan" "$release" "$supported"
      ((total++)) || true
    done

    # Ubuntu releases
    for release in "${UBUNTU_RELEASES[@]}"; do
      branch="patchset/${patchset}/ubuntu/${release}"
      seed_branch "$repo" "$branch" "$patchset" "$arch" "ubuntu" "$release" "$supported"
      ((total++)) || true
    done
  done

  rm -rf "$clone_dir"
  echo ""
done

echo "=== Done ==="
echo "Branches seeded: $((total - failed))  Failed: ${failed}"
echo "Finished: $(date -u)"
