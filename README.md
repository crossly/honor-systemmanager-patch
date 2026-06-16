# HONOR System Manager Patch

KernelSU/Magisk style module for disabling selected HONOR System Manager services on MagicOS.

This module was built for an HONOR BKQ-AN90 running Android 16 / MagicOS 10.0.0 with KernelSU root. It targets `com.hihonor.systemmanager` and patches Android per-user `package-restrictions.xml` so PackageManager treats selected HONOR System Manager components as disabled.

## What It Disables

The block mode disables these components for user `0` and user `128`:

- `com.hihonor.securitycenter.mainservice.HwSecService`
- `com.hihonor.systemmanager.appcontrol.service.SmartControlResidentService`
- `com.hihonor.systemmanager.service.MainService`
- `com.hihonor.systemmanager.spacecleanner.service.AppCleanUpService`
- `com.hihonor.antivirus.AntiVirusService`
- `com.hihonor.android.security.analyzer.AppBehaviorDataAnalyzerService`
- `com.hihonor.android.security.inspection.AppBASMngService`
- `com.hihonor.securitycenter.blockads.BlockAdsService`
- `com.hihonor.securitycenter.antifraud.aigc.AigcDetectService`
- `com.hihonor.securitycenter.antifraud.fakedetect.FakeDetectService`
- `com.hihonor.securitycenter.antifraud.audioevent.AudioDetectService`
- `com.hihonor.securitycenter.privacy.monthlyreport.service.YoyoCardService`

It intentionally does not disable:

- `com.hihonor.permission.HoldService`
- `.netassistant.CoreService`
- `.power.service.BgPowerManagerService`
- `.power.service.SavePowerManagerService`
- `.spacecleanner.service.StorageMonitorService`

Those are left enabled to reduce the chance of breaking permission management, network statistics, storage UI, and battery settings.

## Install

Flash the zip from KernelSU Manager:

```text
dist/honor-systemmanager-patch-v1.1.0.zip
```

During install:

- Volume Up: block selected services
- Volume Down: restore selected services
- No key within 15 seconds: default to block mode

Reboot after flashing. PackageManager only reloads component restrictions cleanly during framework startup.

## Switch Mode Later

The module includes a KernelSU WebUI. Use the module's Open button to access:

- Test Status
- Block Services
- Restore Services

The module also includes `action.sh`. Running the module action toggles between:

- `block`
- `restore`

Reboot after toggling for a clean PackageManager reload.

## Uninstall / Restore

Uninstalling the module runs `uninstall.sh`, which attempts to restore the selected services by removing this module's component entries from `disabled-components`.

Manual restore:

```sh
adb shell su -c 'MODDIR=/data/adb/modules/honor-systemmanager-patch /data/adb/modules/honor-systemmanager-patch/common/patch.sh restore'
```

Then reboot.

## How It Works

HONOR blocks normal `pm disable-user` for this privileged package:

```text
Error: not allowed to disable this package
```

The module instead edits:

```text
/data/system/users/0/package-restrictions.xml
/data/system/users/128/package-restrictions.xml
```

These files are Android Binary XML. The module uses the system tools:

```text
/system/bin/abx2xml
/system/bin/xml2abx
```

The flow is:

1. Convert the current ABX file to XML.
2. Find the `com.hihonor.systemmanager` package node.
3. Insert or remove selected component names in `disabled-components`.
4. Convert XML back to ABX.
5. Replace the package restriction file atomically.

The module does not modify `/system`, the system APK, or boot/vendor partitions.

## Risk

This is a root-level system behavior patch. It can affect HONOR security center, app startup management, antivirus, behavior detection, background cleanup, anti-fraud detection, and privacy reports.

If Settings, permission prompts, battery pages, or system manager pages behave badly, switch to restore mode or uninstall the module.

## Files

- `module/`: module source
- `dist/`: flashable zip
- `docs/context.md`: investigation notes and rationale
- `scripts/build.sh`: rebuild flashable zip from `module/`

## Status Check

From ADB:

```sh
adb shell su -c 'MODDIR=/data/adb/modules/honor-systemmanager-patch /data/adb/modules/honor-systemmanager-patch/common/status.sh'
```

The status check reports per-user package restriction state and whether any target service is currently running.
