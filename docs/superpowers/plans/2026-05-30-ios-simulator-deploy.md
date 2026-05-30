# iOS Simulator Deploy — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a Claude Code skill that guides Claude through detecting an iOS project, selecting a simulator, optionally building, and deploying + launching the app.

**Architecture:** A single `skill.md` file containing step-by-step instructions for Claude, plus a shell `install.sh` that copies the skill into `~/.claude/skills/`. No helper scripts — Claude runs `xcrun simctl` and `xcodebuild` commands directly, using its conversational ability to handle user choices at each decision point.

**Tech Stack:** Bash, xcrun simctl, xcodebuild, Python 3 (JSON parsing, available on all macOS), Claude Code skill format (YAML frontmatter + Markdown)

---

### Task 1: Repo structure and install script

**Files:**
- Create: `skills/ios-simulator-deploy/skill.md` (placeholder)
- Create: `install.sh`

- [ ] **Step 1: Create the skills directory**

```bash
mkdir -p skills/ios-simulator-deploy
```

- [ ] **Step 2: Create a placeholder skill.md**

```bash
cat > skills/ios-simulator-deploy/skill.md << 'EOF'
---
name: ios-simulator-deploy
description: Deploy and launch an iOS app on a simulator. Use when the user says "deploy to simulator", "launch on sim", "launch on simulator", "launch locally", "run on simulator", "deploy current changes", or similar phrases indicating intent to test on an iOS simulator.
---

# iOS Simulator Deploy

(Implementation in progress)
EOF
```

- [ ] **Step 3: Write install.sh**

```bash
cat > install.sh << 'SCRIPT'
#!/bin/bash
set -euo pipefail

SKILL_NAME="ios-simulator-deploy"
SKILL_SRC="$(cd "$(dirname "$0")" && pwd)/skills/$SKILL_NAME/skill.md"
SKILL_DEST="$HOME/.claude/skills/$SKILL_NAME"

if [ ! -f "$SKILL_SRC" ]; then
  echo "Error: skill.md not found at $SKILL_SRC" >&2
  exit 1
fi

mkdir -p "$SKILL_DEST"
cp "$SKILL_SRC" "$SKILL_DEST/skill.md"

echo "Installed $SKILL_NAME to $SKILL_DEST/skill.md"
echo "Restart Claude Code to activate the skill."
SCRIPT
chmod +x install.sh
```

- [ ] **Step 4: Verify install.sh works**

```bash
bash install.sh
```

Expected output:
```
Installed ios-simulator-deploy to /Users/<you>/.claude/skills/ios-simulator-deploy/skill.md
Restart Claude Code to activate the skill.
```

Also verify the file was copied:
```bash
cat ~/.claude/skills/ios-simulator-deploy/skill.md
```
Expected: the placeholder content is printed.

- [ ] **Step 5: Commit**

```bash
git add skills/ios-simulator-deploy/skill.md install.sh
git commit -m "Add repo structure and install script"
```

---

### Task 2: Write skill.md — Step 1 (project detection) + Step 2 (simulator selection)

**Files:**
- Modify: `skills/ios-simulator-deploy/skill.md`

- [ ] **Step 1: Replace placeholder with Step 1 content**

Overwrite `skills/ios-simulator-deploy/skill.md` with:

````markdown
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
````

- [ ] **Step 2: Append Step 2 (simulator selection) to skill.md**

Append the following to `skills/ios-simulator-deploy/skill.md`:

````markdown

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
````

- [ ] **Step 3: Re-run install.sh and verify the updated skill is in place**

```bash
bash install.sh
cat ~/.claude/skills/ios-simulator-deploy/skill.md | grep "Step 2"
```

Expected: `## Step 2: Select Simulator` appears in the output.

- [ ] **Step 4: Commit**

```bash
git add skills/ios-simulator-deploy/skill.md
git commit -m "Add project detection and simulator selection steps"
```

---

### Task 3: Write skill.md — Step 3 (build intent) + Step 4 (build fresh)

**Files:**
- Modify: `skills/ios-simulator-deploy/skill.md`

- [ ] **Step 1: Append Step 3 (build intent) to skill.md**

Append to `skills/ios-simulator-deploy/skill.md`:

````markdown

## Step 3: Build Intent

Ask the user:
> "What would you like to do?
> 1. Build fresh and deploy
> 2. Deploy the last build (skip building)"

**If option 2 — Deploy last build:**

Search for the most recently modified simulator `.app`, checking the project folder first then global DerivedData:
```bash
find . -maxdepth 6 -name "*.app" -path "*iphonesimulator*" 2>/dev/null
find ~/Library/Developer/Xcode/DerivedData -name "*.app" -path "*iphonesimulator*" 2>/dev/null
```

Combine all results, pick the one with the most recent modification time. Show the user:
> "Found: `<path>`
> Last modified: `<date and time>`"

Then skip to Step 5.

If no `.app` is found at all, tell the user:
> "No previous simulator build found. Would you like to build fresh instead?"

If yes, continue to Step 4. If no, stop.

**If option 1 — Build fresh:** Continue to Step 4.
````

- [ ] **Step 2: Append Step 4 (build fresh) to skill.md**

Append to `skills/ios-simulator-deploy/skill.md`:

````markdown

## Step 4: Build Fresh

List available schemes:
```bash
xcodebuild -list 2>/dev/null
```

If only one scheme is listed, use it. If multiple, present them and ask the user to choose.

Get the bundle identifier and product name for the chosen scheme:
```bash
xcodebuild -scheme <scheme> -showBuildSettings 2>/dev/null \
  | grep -E "^\s+(PRODUCT_BUNDLE_IDENTIFIER|PRODUCT_NAME)\s*="
```

Note both values — `PRODUCT_BUNDLE_IDENTIFIER` is needed in Step 5 and `PRODUCT_NAME` is used to locate the `.app` after the build.

Run the build (use `-workspace <name>.xcworkspace` instead of `-project <name>.xcodeproj` if a workspace was found in Step 1):
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
````

- [ ] **Step 3: Re-run install.sh and verify**

```bash
bash install.sh
grep -c "Step" ~/.claude/skills/ios-simulator-deploy/skill.md
```

Expected: `4` (Steps 1–4 are now present).

- [ ] **Step 4: Commit**

```bash
git add skills/ios-simulator-deploy/skill.md
git commit -m "Add build intent and build fresh steps"
```

---

### Task 4: Write skill.md — Step 5 (install and launch)

**Files:**
- Modify: `skills/ios-simulator-deploy/skill.md`

- [ ] **Step 1: Append Step 5 to skill.md**

Append to `skills/ios-simulator-deploy/skill.md`:

````markdown

## Step 5: Install and Launch

With `<app-path>`, `<udid>`, and `<bundle-id>` confirmed, run each command in sequence. Stop and report the error output if any command fails.

Install the app:
```bash
xcrun simctl install <udid> <app-path>
```

Launch the app:
```bash
xcrun simctl launch <udid> <bundle-id>
```

Bring the Simulator window to the foreground:
```bash
open -a Simulator
```

Report success to the user:
> "Launched **`<AppName>`** on **`<simulator name>`** (iOS `<version>`)."
````

- [ ] **Step 2: Re-run install.sh and verify the complete skill**

```bash
bash install.sh
grep -c "Step" ~/.claude/skills/ios-simulator-deploy/skill.md
```

Expected: `5`

- [ ] **Step 3: Commit**

```bash
git add skills/ios-simulator-deploy/skill.md
git commit -m "Add install and launch step — skill complete"
```

---

### Task 5: Push to GitHub and verify

**Files:** none (git operations only)

- [ ] **Step 1: Verify the remote is set correctly**

```bash
git remote -v
```

Expected:
```
origin  https://github.com/mhollander38/ios-simulator-deploy.git (fetch)
origin  https://github.com/mhollander38/ios-simulator-deploy.git (push)
```

- [ ] **Step 2: Push main branch to GitHub**

```bash
git push -u origin main
```

Expected: all commits push without error. GitHub will report the branch as `main`.

- [ ] **Step 3: Confirm on GitHub**

Open `https://github.com/mhollander38/ios-simulator-deploy` and verify:
- The `main` branch exists and is the default
- All files are present: `skills/ios-simulator-deploy/skill.md`, `install.sh`, `docs/`
- Commit history matches what was built locally

- [ ] **Step 4: Smoke-test the install script from a clean state**

```bash
rm -rf ~/.claude/skills/ios-simulator-deploy
bash install.sh
ls -la ~/.claude/skills/ios-simulator-deploy/skill.md
```

Expected: file re-appears, install script prints confirmation.
