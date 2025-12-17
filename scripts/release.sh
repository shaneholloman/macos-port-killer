#!/bin/bash

# Simple version bump and release script
# Usage: ./scripts/release.sh [patch|minor|major]

set -e

# Get current version from git tags
CURRENT=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0")
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

# Determine bump type
BUMP=${1:-patch}

case $BUMP in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
  *) echo "Usage: $0 [patch|minor|major]"; exit 1 ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"
TAG="v$NEW_VERSION"

echo "Current: v$CURRENT"
echo "New:     $TAG"
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi

# Create and push tag
git tag "$TAG"
git push origin "$TAG"

echo ""
echo "✅ Released $TAG"
echo "   https://github.com/productdevbook/port-killer/releases/tag/$TAG"
