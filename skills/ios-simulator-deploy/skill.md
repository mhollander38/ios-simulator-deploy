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
- Only a `Package.swift` (no `.xcodeproj` or `.xcworkspace`) → use `xcodebuild` with `-scheme` only (no `-project` or `-workspace` flag)

If both a `.xcworkspace` and a `.xcodeproj` are found at the root, prefer the `.xcworkspace`.

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
    version = '.'.join(runtime.split('.')[-1].split('-')[1:])
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

**No simulators at all** (both `BOOTED` and `AVAILABLE` sections are empty — only the two header lines appear): Tell the user, then offer to create one:
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

## Step 3: Build Intent

Ask the user:
> "What would you like to do?
> 1. Build fresh and deploy
> 2. Deploy the last build (skip building)"

**If option 2 — Deploy last build:**

Search for the most recently modified simulator `.app`, checking the project folder first then global DerivedData:
```bash
{ find . -maxdepth 6 -name "*.app" -path "*iphonesimulator*" 2>/dev/null; \
  find ~/Library/Developer/Xcode/DerivedData -name "*.app" -path "*iphonesimulator*" 2>/dev/null; } \
  | xargs ls -dt 2>/dev/null | head -1
```

Run the combined search to find the most recently modified `.app`. Show the user:
> "Found: `<path>`
> Last modified: `<date and time>`"

Then skip to Step 5.

If no `.app` is found at all, tell the user:
> "No previous simulator build found. Would you like to build fresh instead?"

If yes, continue to Step 4. If no, stop.

**If option 1 — Build fresh:** Continue to Step 4.

## Step 4: Build Fresh

List available schemes:
```bash
xcodebuild [<-project ProjectName.xcodeproj | -workspace Name.xcworkspace>] -list 2>/dev/null
```
(Use the `-project` or `-workspace` flag determined in Step 1)

If only one scheme is listed, use it. If multiple, present them and ask the user to choose.

Get the bundle identifier and product name for the chosen scheme:
```bash
xcodebuild [<-project ProjectName.xcodeproj | -workspace Name.xcworkspace>] -scheme <scheme> -showBuildSettings 2>/dev/null \
  | grep -E "^\s+(PRODUCT_BUNDLE_IDENTIFIER|PRODUCT_NAME)\s*="
```
(Use the same `-project`/`-workspace` flag determined in Step 1)

Note both values — `PRODUCT_BUNDLE_IDENTIFIER` is needed in Step 5 and `PRODUCT_NAME` is used to locate the `.app` after the build.

Run the build using the project type determined in Step 1. Examples for each case:

**For .xcodeproj:**
```bash
xcodebuild \
  -project <ProjectName>.xcodeproj \
  -scheme <scheme> \
  -destination "platform=iOS Simulator,id=<udid>" \
  -configuration Debug \
  build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee /tmp/xcodebuild-output.txt | tail -5
```

**For .xcworkspace:**
```bash
xcodebuild \
  -workspace <WorkspaceName>.xcworkspace \
  -scheme <scheme> \
  -destination "platform=iOS Simulator,id=<udid>" \
  -configuration Debug \
  build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee /tmp/xcodebuild-output.txt | tail -5
```

**For Package.swift only:**
```bash
xcodebuild \
  -scheme <scheme> \
  -destination "platform=iOS Simulator,id=<udid>" \
  -configuration Debug \
  build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee /tmp/xcodebuild-output.txt | tail -5
```

After the command finishes, check the result:
```bash
tail -5 /tmp/xcodebuild-output.txt
```

- If the output contains `** BUILD SUCCEEDED **`: continue.
- If the output contains `** BUILD FAILED **`: run `tail -30 /tmp/xcodebuild-output.txt`, show those lines to the user, and stop.

Locate the built `.app`:
```bash
find ~/Library/Developer/Xcode/DerivedData -name "<ProductName>.app" \
  -path "*iphonesimulator*" 2>/dev/null \
  | xargs ls -dt 2>/dev/null | head -1
```
