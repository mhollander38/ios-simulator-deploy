# ios-simulator-deploy

A Claude Code skill that deploys and launches an iOS app on a simulator. Say "deploy to simulator" (or similar) and Claude handles the rest — selecting a simulator, optionally building, installing, and launching your app.

## Requirements

- macOS with Xcode and Simulator installed
- Claude Code
- An iOS project (`.xcodeproj`, `.xcworkspace`, or `Package.swift`) in the current working directory

## Install

```bash
git clone https://github.com/mhollander38/ios-simulator-deploy.git
cd ios-simulator-deploy
bash install.sh
```

Then restart Claude Code to activate the skill.

## Usage

From inside your iOS project directory, say anything like:

- "deploy to simulator"
- "launch on sim"
- "launch locally"
- "run on simulator"
- "deploy current changes"

Claude will walk through the following steps automatically.

## What it does

**1. Verifies the project** — confirms a `.xcodeproj`, `.xcworkspace`, or `Package.swift` exists in the current directory. Stops immediately if not found.

**2. Asks your intent** — before doing anything else:
> 1. Build fresh and deploy
> 2. Deploy the last build (skip building)

**3. Selects a simulator** — lists all available iOS simulators. If one is already running, asks whether to use it or pick a different one. If none exist, offers to create one.

**4. Builds (if requested)** — fetches the scheme and bundle ID from `xcodebuild -showBuildSettings`, then runs a Debug build targeting the chosen simulator with code signing disabled (safe for simulators). Shows the last 30 lines of output on failure.

**5. Installs and launches** — runs `xcrun simctl install` and `xcrun simctl launch`, then brings Simulator.app to the foreground.

## Supported project types

| Project type | xcodebuild flag |
|---|---|
| `.xcodeproj` | `-project` |
| `.xcworkspace` (CocoaPods, etc.) | `-workspace` |
| `Package.swift` only | `-scheme` (no project/workspace flag) |

If both `.xcworkspace` and `.xcodeproj` exist, the workspace is preferred.
