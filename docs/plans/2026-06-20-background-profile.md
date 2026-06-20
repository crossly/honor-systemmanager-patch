# Background Profile Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add independently controllable HONOR background-killing and PowerKit profiles to the KernelSU module.

**Architecture:** Keep the package-restrictions patcher as the only enforcement mechanism, but move targets into a structured `profile|package|component` file. WebUI writes one saved mode per profile and invokes the patcher for that profile only.

**Tech Stack:** POSIX shell, KernelSU WebUI JavaScript, Android ABX tools (`abx2xml`, `xml2abx`), zip-based KernelSU module packaging.

### Task 1: Target Registry

**Files:**
- Create: `module/common/targets.txt`
- Modify: `module/common/patch.sh`

**Steps:**
1. Move the original System Manager target list into `security` rows.
2. Add `background` rows for `BgPowerManagerService`, `SavePowerManagerService`, and related power receivers.
3. Add conservative `powerkit` rows for selected PowerGenie/PowerKit services.
4. Update `patch.sh` to accept `block|restore [profile]`.
5. Verify only selected profile components are inserted or removed.

### Task 2: Status And Persistence

**Files:**
- Modify: `module/common/status.sh`
- Modify: `module/post-fs-data.sh`
- Modify: `module/service.sh`
- Modify: `module/customize.sh`
- Modify: `module/uninstall.sh`

**Steps:**
1. Store modes under `modes/security`, `modes/background`, and `modes/powerkit`.
2. Keep the old `mode` file as a fallback for v1.2.0 upgrades.
3. Reapply each profile during early and late boot.
4. Restore every profile on uninstall.
5. Report status per profile, package, user, and running service.

### Task 3: WebUI

**Files:**
- Modify: `module/webroot/index.html`
- Modify: `module/webroot/scripts.js`
- Modify: `module/webroot/styles.css`

**Steps:**
1. Keep a single all-profile status button.
2. Add block/restore controls for each profile.
3. Display saved profile modes in the version line.
4. Run status for the changed profile after each action.

### Task 4: Verification

**Files:**
- Create: `tests/test_profiles.sh`
- Create: `tests/fixtures/package-restrictions.xml`
- Create: `tests/fakebin/abx2xml`
- Create: `tests/fakebin/xml2abx`

**Steps:**
1. Simulate Android user restriction files under a temporary data root.
2. Use fake ABX tools that copy XML so the patcher can be tested locally.
3. Assert `background` block does not touch `security` or `powerkit`.
4. Assert `powerkit` block targets `com.hihonor.powergenie`.
5. Assert `background` restore preserves unrelated disabled components.
6. Run shell syntax checks and module build.
