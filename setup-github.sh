#!/usr/bin/env bash
# setup-github.sh
# Run this once from inside the Glance/ folder to:
#   1. Initialise a local git repo
#   2. Make an initial commit
#   3. Create a private GitHub repo and push to it
#
# Prerequisites:
#   - GitHub CLI installed: brew install gh
#   - Authenticated:        gh auth login
#
# Usage:
#   cd "/path/to/iOS App/Glance"
#   chmod +x setup-github.sh
#   ./setup-github.sh

set -euo pipefail

REPO_NAME="glance-ios"
REPO_DESCRIPTION="Glance — a calm iOS home-screen widget app for tiny, pressure-free task lists"
VISIBILITY="private"   # change to "public" if you want it public

echo "→ Initialising git repository…"
git init
git add .
git commit -m "feat: initial project scaffold

- SwiftData models: Theme + Step
- CloudKit private database sync via GlanceStore
- App Group shared store for widget data bridge
- iPhone app: Themes, Steps, Edit, Settings screens
- Home-screen widget (small/medium/large) with interactive theme chips (AppIntents)
- Lock-screen widget (rectangular/inline/circular)
- Apple Watch stub target (v2 placeholder)
- Starter templates: Take meds, Leave the house, Morning
- Design system: GlanceColors, GlanceFonts, ThemePalette (WCAG AA)
- XcodeGen project.yml
- Unit tests scaffold"

echo ""
echo "→ Creating GitHub repository '$REPO_NAME' ($VISIBILITY)…"
gh repo create "$REPO_NAME" \
    --description "$REPO_DESCRIPTION" \
    --"$VISIBILITY" \
    --source=. \
    --remote=origin \
    --push

echo ""
echo "✅  Done! Your repo is live at: https://github.com/$(gh api user --jq .login)/$REPO_NAME"
echo ""
echo "Next steps:"
echo "  1. Replace YOUR_TEAM in project.yml and GlanceStore.swift with your Apple Developer Team ID"
echo "  2. Install XcodeGen:  brew install xcodegen"
echo "  3. Generate the project: xcodegen generate"
echo "  4. Open Glance.xcodeproj in Xcode"
echo "  5. In Signing & Capabilities, add your App Group and CloudKit container"
