#!/usr/bin/env bash
set -euo pipefail

BRANCH="main"

usage() {
  cat <<'EOF'
Usage: release [patch|minor|major]

Release a new npm version.

Arguments:
  patch    Bug fixes
  minor    Backward-compatible features
  major    Breaking changes

Options:
  -h, --help   Show this help message
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ -z "${1:-}" ]]; then
  echo "Missing version type."
  usage
  exit 1
fi

TYPE="$1"
case "$TYPE" in
  patch|minor|major) ;;
  *)
    echo "Invalid version type: $TYPE"
    usage
    exit 1
    ;;
esac

if [[ ! -f package.json ]]; then
  echo "package.json not found. Run this from the package root."
  exit 1
fi

echo "Checking branch..."
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$CURRENT_BRANCH" != "$BRANCH" ]]; then
  echo "Must release from '$BRANCH' branch (current: $CURRENT_BRANCH)"
  exit 1
fi

echo "Checking git status..."
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working directory is not clean."
  exit 1
fi

echo "Checking npm authentication..."
if ! npm whoami >/dev/null 2>&1; then
  echo "Not authenticated with npm. Run: npm login"
  exit 1
fi

echo "Running tests..."
npm test

echo "Building project..."
npm run build

PACKAGE_NAME="$(node -p "require('./package.json').name")"

echo "Bumping version ($TYPE)..."
npm version "$TYPE"

NEW_VERSION="$(node -p "require('./package.json').version")"
echo "New version: $NEW_VERSION"

if npm view "$PACKAGE_NAME@$NEW_VERSION" version >/dev/null 2>&1; then
  echo "Version $NEW_VERSION already exists on npm."
  exit 1
fi

echo "Publishing to npm..."
npm publish --access public

echo "Pushing commits and tags..."
git push origin "$BRANCH" --follow-tags

echo "Release complete: $PACKAGE_NAME@$NEW_VERSION"