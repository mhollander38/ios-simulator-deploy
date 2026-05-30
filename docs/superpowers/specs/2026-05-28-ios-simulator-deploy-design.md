# iOS Simulator Deploy Skill — Design Spec

**Date:** 2026-05-28 (revised 2026-05-30)
**Status:** Approved

---

## Overview

A Claude Code skill that detects an iOS project, selects a simulator, builds the app targeting that simulator, installs it, and launches it. Packaged as a `skill.md` plus a shell install script.

---

## Trigger

The skill's `description` field causes it to auto-invoke when the user says phrases like:
- "deploy to simulator"
- "launch on sim / simulator"
- "launch locally"
- "run on simulator"
- "deploy current changes"
- similar intent phrases

---

## Step 1: iOS Project Detection

Check the current working directory for at least one of:
- `*.xcodeproj`
- `*.xcworkspace`
- `Package.swift`

If none are found, tell the user the skill cannot be used in a non-iOS project directory and stop immediately.

---

## Step 2: Simulator Selection

Run `xcrun simctl list devices --json` and handle four cases:

| State | Action |
|-------|--------|
| One simulator already booted | Ask: "Use the running `<name>` or pick a different one?" |
| Multiple simulators booted | Show numbered list of booted devices, ask user to pick one |
| Simulators exist but none booted | Show numbered list of all available devices (name + iOS version), ask user to pick |
| No simulators exist | Offer to create one — list device types (`xcrun simctl list devicetypes`) and runtimes (`xcrun simctl list runtimes`), ask user to choose, then `xcrun simctl create` |

The **UDID of the chosen simulator** is used in Step 3 as the build destination.

If the chosen simulator is not yet booted, boot it with `xcrun simctl boot <udid>` and open Simulator.app (`open -a Simulator`). Poll `xcrun simctl list devices` every 2 seconds until it reaches `Booted`, with a 60-second timeout.

---

## Step 3: Build Intent

Ask the user:
> "Build fresh and deploy, or deploy the last build?"

**If "deploy last build":**
Search for the most recently modified `.app` in:
1. Project-relative paths: `./build/**/*.app`, `./DerivedData/**/*.app`
2. `~/Library/Developer/Xcode/DerivedData/**/Build/Products/**-iphonesimulator/*.app`

If no previous build is found, inform the user and offer to build fresh instead. If they decline, stop.

**If "build fresh":**
Detect the scheme and bundle identifier by running:
```
xcodebuild -showBuildSettings 2>/dev/null | grep -E "PRODUCT_NAME|PRODUCT_BUNDLE_IDENTIFIER"
```

If multiple schemes exist (from `xcodebuild -list`), present them and ask the user to choose.

Build targeting the chosen simulator:
```
xcodebuild \
  -project <name>.xcodeproj \
  -scheme <scheme> \
  -destination 'platform=iOS Simulator,id=<udid>' \
  -configuration Debug \
  build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

Stream build output. On `** BUILD FAILED **`, show the last 30 lines of output and stop.

---

## Step 4: Install and Launch

Locate the `.app` to deploy (either the one just built, or the most recently modified one found in Step 3):
```
~/Library/Developer/Xcode/DerivedData/<project-hash>/Build/Products/Debug-iphonesimulator/<AppName>.app
```
(use `find` filtered to the project's DerivedData folder, pick most recently modified)

Execute in order, stopping and reporting on any failure:
1. `xcrun simctl install <udid> <path-to.app>`
2. `xcrun simctl launch <udid> <bundle-id>` (bundle ID from Step 3)
3. `open -a Simulator` — bring Simulator window to foreground (if not already open)

---

## Packaging

The repository contains:
- `skills/ios-simulator-deploy/skill.md` — the skill file
- `install.sh` — copies `skill.md` into `~/.claude/skills/ios-simulator-deploy/skill.md`, creating the directory if needed, and prints a confirmation

---

## Error Handling

- Not an iOS project → inform user, stop
- Build fails → show last 30 lines of xcodebuild output, stop
- Simulator boot timeout (60s) → report timeout, stop
- `xcrun simctl install` or `launch` fails → report specific error, stop

No silent failures. Each step either succeeds or produces a clear, actionable message.
