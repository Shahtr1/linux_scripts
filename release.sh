#!/bin/bash
set -euo pipefail

BRANCH="main"

usage() {
  echo "Usage: release [patch|minor|major]"
  echo
  echo "Release a new npm version."
  echo
  echo "Arguments:"
  echo "  patch    Bug fixes"
  echo "  minor    Backward-compatible features"
  echo "  major    Breaking changes"
  echo
  echo "Options:"
  echo "  -h, --help   Show this help message"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ -z "${1:-}" ]]; then
  echo "❌ Missing version type."
  usage
  exit 1
fi

TYPE="$1"

case "$TYPE" in
  patch|minor|major)
    ;;
  *)
    echo "❌ Invalid version type: $TYPE"
    usage
    exit 1
    ;;
esac

echo "🔎 Checking branch..."
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" != "$BRANCH" ]]; then
  echo "❌ Must release from '$BRANCH' branch (current: $CURRENT_BRANCH)"
  exit 1
fi

echo "🔎 Checking git status..."
if [[ -n $(git status --porcelain) ]]; then
  echo "❌ Working directory not clean."
  exit 1
fi

echo "🔐 Checking npm authentication..."
if ! npm whoami &> /dev/null; then
  echo "❌ Not authenticated with npm."
  echo "Run: npm login"
  exit 1
fi

echo "🧪 Running tests..."
npm test

echo "🏗 Building project..."
npm run build

PACKAGE_NAME=$(node -p "require('./package.json').name")
CURRENT_VERSION=$(node -p "require('./package.json').version")

if npm view "$PACKAGE_NAME@$CURRENT_VERSION" version &> /dev/null; then
  echo "❌ Version $CURRENT_VERSION already exists on npm."
  exit 1
fi

echo "📦 Bumping version ($TYPE)..."
npm version "$TYPE"

NEW_VERSION=$(node -p "require('./package.json').version")
echo "New version: $NEW_VERSION"

echo "🚀 Pushing commits and tags..."
git push origin "$BRANCH" --follow-tags

echo "📤 Publishing..."
npm publish --access public

echo "✅ Release complete: $NEW_VERSION"