#!/usr/bin/env bash
# Push Linux kernel content to all distro kernel-base repos.
#
# For each architecture, pushes the upstream kernel tree to:
#   debian-{arch}-kernel-base
#   devuan-{arch}-kernel-base
#   ubuntu-{arch}-kernel-base
#   {arch}-deb-linux-kernel-base
#
# The local kernel clone at /workspaces/linux-kernel is used as the source.
# Each repo gets a 'main' branch with the upstream kernel HEAD.
#
# Usage:
#   ./push-kernel-content.sh [--arch amd64 arm64 ...]  # default: all
#   ./push-kernel-content.sh --dry-run
set -euo pipefail

KERNEL_DIR="/workspaces/linux-kernel"
USER="Interested-Deving-1896"
export GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"

ARCHS=(amd64 arm64 armhf riscv64 s390x armel ppc64el mips64el loong64 i686)
DRY_RUN=false

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
  echo "Run: git clone --depth=1 --branch v6.9 https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git $KERNEL_DIR"
  exit 1
fi

echo "=== Push kernel content to kernel-base repos ==="
echo "Kernel source: $KERNEL_DIR ($(git -C "$KERNEL_DIR" describe --tags 2>/dev/null || echo 'unknown'))"
echo "Architectures: ${ARCHS[*]}"
echo "Dry run: $DRY_RUN"
echo "Started: $(date -u)"
echo ""

total=0
failed=0

push_to_repo() {
  local repo="$1"
  local remote="https://x-access-token:${GH_TOKEN}@github.com/${USER}/${repo}.git"

  if $DRY_RUN; then
    echo "  [dry-run] push main → ${USER}/${repo}"
    return 0
  fi

  # Add remote, push, remove remote
  git -C "$KERNEL_DIR" remote add "push-${repo}" "$remote" 2>/dev/null || \
    git -C "$KERNEL_DIR" remote set-url "push-${repo}" "$remote"

  if git -C "$KERNEL_DIR" push "push-${repo}" "HEAD:refs/heads/main" --force-with-lease 2>&1; then
    echo "  ✓ pushed: ${repo}"
  else
    echo "  ✗ failed: ${repo}"
    ((failed++)) || true
  fi

  git -C "$KERNEL_DIR" remote remove "push-${repo}" 2>/dev/null || true
}

for arch in "${ARCHS[@]}"; do
  echo "--- ${arch} ---"
  repos=(
    "debian-${arch}-kernel-base"
    "devuan-${arch}-kernel-base"
    "ubuntu-${arch}-kernel-base"
    "${arch}-deb-linux-kernel-base"
  )
  for repo in "${repos[@]}"; do
    push_to_repo "$repo"
    ((total++)) || true
    # Pace: avoid secondary rate limits on git pushes
    if ! $DRY_RUN; then sleep 2; fi
  done
  echo ""
done

echo "=== Done ==="
echo "Pushed: $((total - failed))  Failed: ${failed}"
echo "Finished: $(date -u)"
