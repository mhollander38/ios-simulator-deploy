---
name: ios-simulator-deploy
description: Deploy and launch an iOS app on a simulator. Use when the user says "deploy to simulator", "launch on sim", "launch on simulator", "launch locally", "run on simulator", "deploy current changes", or similar phrases indicating intent to test on an iOS simulator.
---

# iOS Simulator Deploy

## Step 1: Verify iOS Project

Run:
```bash
find . -maxdepth 1 \( -name "*.xcodeproj" -o -name "*.xcworkspace" -o -name "Package.swift" \) 2>/dev/null \
  | grep -v ".xcodeproj/project.xcworkspace"
```

If nothing is returned, tell the user:
> "This skill requires an iOS app project. No `.xcodeproj`, `.xcworkspace`, or `Package.swift` was found in the current directory."

Then stop — do not continue.

Note the project type found for later use:
- A standalone `.xcworkspace` (not inside a `.xcodeproj`) → use `-workspace` flag with xcodebuild
- Only a `.xcodeproj` → use `-project` flag with xcodebuild

## Step 2: Select Simulator

List all available iOS simulators and separate booted from available:
```bash
xcrun simctl list devices --json | python3 -c "
import json, sys
d = json.load(sys.stdin)['devices']
booted, available = [], []
for runtime, devs in d.items():
    if 'iOS' not in runtime:
        continue
    version = runtime.split('.')[-1].replace('-', '.')
    for dev in devs:
        if not dev['isAvailable']:
            continue
        entry = (dev['udid'], dev['name'], version, dev['state'])
        if dev['state'] == 'Booted':
            booted.append(entry)
        else:
            available.append(entry)
print('BOOTED')
for i, (u,n,v,s) in enumerate(booted, 1):
    print(f'{i}. {n} (iOS {v}) [{u}]')
print('AVAILABLE')
for i, (u,n,v,s) in enumerate(available, 1):
    print(f'{i}. {n} (iOS {v}) [{u}]')
"
```

Handle the output:

**One booted simulator:** Ask the user:
> "**`<name>`** (iOS `<version>`) is already running.
> 1. Use `<name>` (running)
> 2. Pick a different simulator"

**Multiple booted simulators:** Present the numbered booted list and ask the user to type a number.

**No booted simulators, but available ones exist:** Present the numbered available list and ask the user to type a number.

**No simulators at all:** Tell the user, then offer to create one:
```bash
xcrun simctl list devicetypes | grep iPhone | head -10
xcrun simctl list runtimes | grep iOS
```
Present device types and runtimes, ask the user to choose, then:
```bash
xcrun simctl create "<chosen-name>" "<device-type-identifier>" "<runtime-identifier>"
```
Use the new simulator's UDID going forward.

**Booting the chosen simulator (if not already Booted):**
```bash
xcrun simctl boot <udid>
open -a Simulator
```

Then poll every 2 seconds for up to 60 seconds:
```bash
xcrun simctl list devices | grep <udid>
```
Wait until the output line contains `(Booted)`. If 60 seconds pass without reaching Booted, tell the user and stop.
