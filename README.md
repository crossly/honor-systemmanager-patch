# HONOR System Manager Patch

KernelSU/Magisk style module for disabling selected HONOR System Manager services on MagicOS.

This module was built for an HONOR BKQ-AN90 running Android 16 / MagicOS 10.0.0 with KernelSU root. It targets `com.hihonor.systemmanager` and patches Android per-user `package-restrictions.xml` so PackageManager treats selected HONOR System Manager components as disabled.

## Profiles

The module now has three independently controlled profiles:

- `security`: Security Center, antivirus, anti-fraud, app behavior inspection, and the original System Manager service targets.
- `background`: System Manager smart background/battery cleanup services. This is the first profile to try for aggressive app killing.
- `powerkit`: selected PowerGenie/PowerKit services. This is experimental and more likely to affect Bluetooth wearables, thermal policy, battery pages, or system power APIs.

The install-time volume key choice only controls `security`. `background` and `powerkit` default to `restore` and can be toggled from WebUI.

## What It Disables

The `security` profile disables these components for user `0` and user `128`:

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

The `background` profile disables:

- `com.hihonor.systemmanager.power.service.BgPowerManagerService`
- `com.hihonor.systemmanager.power.service.SavePowerManagerService`
- `com.hihonor.systemmanager.power.receiver.BootBroadcastReceiver`
- `com.hihonor.systemmanager.power.receiver.ScheduleRecordPowerConsumeReceiver`
- `com.hihonor.systemmanager.power.receiver.ScheduleRecordRemainTimeSceneReceiver`
- `com.hihonor.systemmanager.power.receiver.UsageStatusReceiver`

The `powerkit` profile disables:

- `com.hihonor.powergenie.core.hibernation.PGASHStateService`
- `com.hihonor.powergenie.core.contextaware.BrainNotifyService`
- `com.hihonor.android.powerkit.PowerCheckerKitService`
- `com.hihonor.android.powerkit.PowerKitService`

It intentionally does not disable:

- `com.hihonor.permission.HoldService`
- `.netassistant.CoreService`
- `.spacecleanner.service.StorageMonitorService`

Those are left enabled to reduce the chance of breaking permission management, network statistics, and storage UI.

## Install

Flash the zip from KernelSU Manager:

```text
dist/honor-systemmanager-patch-v1.3.1.zip
```

During install:

- Volume Up: block `security`
- Volume Down: restore `security`
- No key within 15 seconds: default to block `security`

The `background` and `powerkit` profiles default to restore during install.

Reboot after flashing. PackageManager only reloads component restrictions cleanly during framework startup.

## Switch Mode Later

The module includes a KernelSU WebUI. Use the module's Open button to access all runtime functions:

- Test all profile status
- Block or restore `security`
- Block or restore `background`
- Block or restore `powerkit`

Reboot after toggling for a clean PackageManager reload.

On MagicOS 10, online restore is more direct than online block. The module calls
`cmd package enable` during restore so PackageManager's in-memory state is
updated immediately. For block mode, HONOR rejects the matching
`disable-user` command for this privileged package, so v1.3.1 first clears any
explicit enabled override with `cmd package default-state`, then writes the
restriction file. Reboot after switching modes when you want the cleanest
PackageManager reload.

## Uninstall / Restore

Uninstalling the module runs `uninstall.sh`, which attempts to restore the selected services by removing this module's component entries from `disabled-components`.

Manual restore:

```sh
adb shell su -c 'MODDIR=/data/adb/modules/honor-systemmanager-patch /data/adb/modules/honor-systemmanager-patch/common/patch.sh restore'
```

Then reboot.

Restore one profile:

```sh
adb shell su -c 'MODDIR=/data/adb/modules/honor-systemmanager-patch /data/adb/modules/honor-systemmanager-patch/common/patch.sh restore background'
```

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
2. Find the target package node, such as `com.hihonor.systemmanager` or `com.hihonor.powergenie`.
3. During block, clear explicit enabled overrides with `cmd package default-state`.
4. Insert or remove selected component names in `disabled-components`.
5. Remove conflicting selected names from `enabled-components` during block.
6. Convert XML back to ABX.
7. Replace the package restriction file atomically.

Status checks only count names under `disabled-components`. A component can
legitimately appear under `enabled-components` after restore and must not be
reported as blocked.

## Recents / Multitasking Notes

Testing on the BKQ-AN90 showed that the basic Recents swipe-up dismissal is
handled by HONOR Launcher / Quickstep:

```text
com.hihonor.android.launcher/.quickstep.RecentsActivity
com.hihonor.android.launcher/.quickstep.TouchInteractionService
```

With all profiles restored, swiping a Recents card upward removed the task. With
`background` blocked and `powerkit` restored, the same swipe-up dismissal still
worked. With both `security` and `background` blocked, the tested swipe-up
dismissal also removed the task. Based on those tests, the current
`background` profile is not a confirmed cause of Recents swipe-up failure.

If Recents dismissal fails after toggling profiles online, reboot first and run
the WebUI status check again. If it still fails, restore `security` before
`background`; `security` contains the higher-risk System Manager cleanup targets
such as `MainService` and `AppCleanUpService`.

The module does not modify `/system`, the system APK, or boot/vendor partitions.

## Risk

This is a root-level system behavior patch. It can affect HONOR security center, app startup management, antivirus, behavior detection, background cleanup, anti-fraud detection, privacy reports, and power management.

Recommended order:

1. Keep `security` blocked if the phone is stable.
2. Try `background` next for aggressive background killing.
3. Only try `powerkit` if `background` is not enough.

If Settings, permission prompts, battery pages, Bluetooth wearables, thermal behavior, or system manager pages behave badly, restore the last profile you blocked or uninstall the module.

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

Check one profile:

```sh
adb shell su -c 'MODDIR=/data/adb/modules/honor-systemmanager-patch /data/adb/modules/honor-systemmanager-patch/common/status.sh background'
```
