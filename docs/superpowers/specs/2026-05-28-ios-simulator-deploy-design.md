# iOS Simulator Deploy Skill — Design Spec

**Date:** 2026-05-28  
**Status:** Approved

---

## Overview

A Claude Code skill that finds the latest iOS simulator build, selects or creates a simulator, deploys the app, and launches it. Packaged as a `skill.md` plus a shell install script.

---

## Trigger

The skill's `description` field causes it to auto-invoke when the user says phrases like:
- "deploy to simulator"
- "launch on sim / simulator"
- "launch locally"
- "run on simulator"
- similar intent phrases

---

## Section 1: iOS Project Detection

Before doing anything else the skill checks the current working directory for at least one of:
- `*.xcodeproj`
- `*.xcworkspace`
- `Package.swift`

If none are found, the skill tells the user it cannot be used in a non-iOS project directory and stops immediately.

---

## Section 2: Finding the Latest Build

Search two locations in order, collect all `.app` bundles found, then pick the one with the **most recent modification time** (covers both Debug and Release automatically):

1. **Project-relative paths** — `./build/**/*.app`, `./DerivedData/**/*.app`, `./Products/**/*.app`
2. **Xcode DerivedData** — `~/Library/Developer/Xcode/DerivedData/**/Build/Products/**-iphonesimulator/*.app`

**If no `.app` is found:**
- Offer to trigger a build via `xcodebuild -scheme <detected-scheme> -destination 'platform=iOS Simulator' build`
- If the user agrees, run the build then re-run the find step
- If the user declines, stop with a clear message

---

## Section 3: Simulator Detection and Selection

Run `xcrun simctl list devices available` and handle three cases:

| State | Action |
|-------|--------|
| One simulator already booted | Use it directly, no prompt |
| Multiple simulators booted | Show numbered list, ask user to pick one |
| Simulators exist but none booted | Show numbered list of all available, ask user to pick, then `xcrun simctl boot <udid>` |
| No simulators exist | Offer to create one — query `xcrun simctl list devicetypes` and `xcrun simctl list runtimes`, present options, then `xcrun simctl create` |

After booting, poll `xcrun simctl list devices` until the chosen device reaches `Booted` state before proceeding.

---

## Section 4: Deploy and Launch

Execute in order, stopping and reporting on any failure:

1. `xcrun simctl install <udid> <path-to.app>`
2. `defaults read <path-to.app>/Info.plist CFBundleIdentifier` — extract bundle ID
3. `xcrun simctl launch <udid> <bundle-id>`
4. `open -a Simulator` — bring the Simulator window to the foreground

---

## Packaging

The repository contains:
- `skills/ios-simulator-deploy/skill.md` — the skill file
- `install.sh` — copies `skill.md` into `~/.claude/skills/ios-simulator-deploy/skill.md`

The install script creates the target directory if it doesn't exist and prints a confirmation message.

---

## Error Handling

- iOS project check fails → inform user, stop
- No build found + user declines build → inform user, stop
- `xcrun simctl` command fails → report the specific error output, stop
- `defaults read` fails (missing Info.plist) → report that the `.app` bundle appears malformed, stop

No silent failures. Each step either succeeds or produces a clear, actionable message.
