# Context And Investigation Notes

## Device Context

- Device: HONOR BKQ-AN90
- Android: 16
- MagicOS: 10.0.0
- Root: KernelSU
- ADB root check: `uid=0(root) ... context=u:r:ksu:s0`
- Main package: `com.hihonor.systemmanager`
- APK path: `/system/priv-app/HnSystemManager/HnSystemManager.apk`

The original goal was to reduce aggressive background cleanup and domestic OEM optimization behavior on a rooted HONOR device used outside China.

## Earlier Baseline Tweaks

Before this module, the following lower-risk Android-level adjustments were applied:

- Removed current-user bundled HONOR/Baidu and HONOR/Sogou input methods.
- Set WeChat Input as the default IME.
- Created a KernelSU service script to start Shizuku after boot.
- Added selected always-on tools to Android Doze whitelist and active standby bucket:
  - `com.follow.clash`
  - `com.network.proxy`
  - `me.weishu.kernelsu`

Those changes helped but did not address HONOR's own System Manager policy layer.

## What System Manager Does

`com.hihonor.systemmanager` is not only a user-facing cleaner app. It is a privileged control hub with UI, policy databases, providers, and services for:

- app startup/background startup management
- battery and smart power policy
- background cleanup
- permission management
- notification management
- network assistant and traffic statistics
- antivirus and malicious behavior detection
- anti-fraud/audio/video/AIGC detection
- privacy reports and app lock
- harassment/call/SMS blocking

Important granted capabilities observed in package dumps included:

- `android.permission.FORCE_STOP_PACKAGES`
- `android.permission.CHANGE_COMPONENT_ENABLED_STATE`
- `android.permission.PACKAGE_USAGE_STATS`
- `android.permission.QUERY_ALL_PACKAGES`
- `android.permission.MANAGE_APP_OPS_MODES`
- `android.permission.REAL_GET_TASKS`

Runtime services observed before patching included:

- `.appcontrol.service.SmartControlResidentService`
- `com.hihonor.securitycenter.mainservice.HwSecService`
- `com.hihonor.permission.HoldService`
- `.service.MainService`
- `.spacecleanner.service.AppCleanUpService`
- `.netassistant.CoreService`
- `.power.service.BgPowerManagerService`
- `.power.service.SavePowerManagerService`

Additional background/power services observed during the background-killing investigation included:

- `com.hihonor.powergenie/com.hihonor.android.powerkit.PowerKitService`
- `com.hihonor.powergenie/.core.CoreService`
- `com.hihonor.powergenie/.core.hibernation.PGASHStateService`
- `com.hihonor.powergenie/com.hihonor.thermal.adapter.ThermalTraceService`

`com.hihonor.powergenie` was granted broad power-management capabilities including `android.permission.KILL_UID`, `android.permission.KILL_BACKGROUND_PROCESSES`, `android.permission.KILL_ALL_BACKGROUND_PROCESSES`, and `android.permission.DEVICE_POWER`. This makes it a plausible part of HONOR's background process enforcement layer, but also makes it riskier to disable wholesale.

## Relevant Databases

System Manager stores policy data under `/data/user_de/0/com.hihonor.systemmanager/databases/`.

Important files:

- `SmartControl.db`
- `smartpowerprovider.db`
- `behavior_bw_list.db`
- `notificationmgr.db`
- `traffic.db`
- `antivirus.db`
- `spacecleanner.db`

`SmartControl.db` contained `SmartControlRecordTable`, which records startup attempts:

- `packageName`
- `callerPackageName`
- `startupResult`
- `totalCount`
- `timeOfLastExact`

`smartpowerprovider.db` contained power policy tables:

- `unifiedpowerapps`
- `protectedapps`
- `forbiddenapps`
- `rogueapps`
- `wakeupapps`
- `superpowerapps`

For the target device, `unifiedpowerapps` showed that apps such as WeChat and Telegram were protected. GKD and the Samsung Watch7 plugin were also protected after manual tuning, while apps such as Samsung Wearable, Shizuku, and Clash were not consistently protected by HONOR's own power policy table. `forbiddenapps` was empty, so the observed issue looked more like HONOR's smart background/power policy layer than a standard Android appops restriction.

## Why Not Disable The Whole Package

Disabling all of `com.hihonor.systemmanager` is high-risk because the package also owns or mediates permission management, traffic management, battery UI, security center UI, notification controls, and other system integration points.

The chosen approach disables specific high-impact services while leaving selected infrastructure services active. In v1.3.0 this was split into profiles so the background-killing parts can be tested independently:

- `security`: original Security Center, antivirus, anti-fraud, behavior analysis, and System Manager targets.
- `background`: System Manager smart power/background cleanup services and receivers.
- `powerkit`: selected PowerGenie/PowerKit targets. This is intentionally experimental because PowerKit is coupled to system power APIs, thermal state, and Bluetooth/wearable behavior.

Kept enabled:

- `HoldService`: permission management
- `CoreService`: network assistant
- `StorageMonitorService`: storage monitor
- `com.hihonor.powergenie/.core.CoreService`: PowerGenie core service

Disabled:

- security center main service
- smart app startup resident service
- main system manager service
- app cleanup service
- antivirus and behavior analysis
- anti-fraud detection
- ad blocking
- privacy monthly report
- optional smart background/power cleanup profile
- optional selected PowerKit profile

## Why Package Restrictions

`pm disable-user` was tested first, including with root, but HONOR blocks disabling this privileged package and its components:

```text
Error: not allowed to disable this package
```

PackageManager stores per-user package and component state in:

```text
/data/system/users/0/package-restrictions.xml
/data/system/users/128/package-restrictions.xml
```

These files are ABX, Android Binary XML. The device provides:

```text
/system/bin/abx2xml
/system/bin/xml2abx
```

Patching those files successfully made PackageManager report the selected components under `disabledComponents` for both user `0` and user `128`.

## Verification Performed

After patching, verification used:

```sh
adb shell dumpsys package com.hihonor.systemmanager
adb shell dumpsys activity services com.hihonor.systemmanager
```

Observed results:

- Target components appeared under `disabledComponents` for both users.
- Target services no longer appeared in `dumpsys activity services`.
- Preserved services such as `HoldService` and `CoreService` still appeared.

## Module Behavior

The module supports two modes per profile:

- `block`: insert selected components into `disabled-components`
- `restore`: remove only this module's selected components from `disabled-components`

Flash-time selection:

- Volume Up: block `security`
- Volume Down: restore `security`
- Timeout: block `security`

`background` and `powerkit` default to restore. Runtime state is stored under:

```text
/data/adb/modules/honor-systemmanager-patch/modes/security
/data/adb/modules/honor-systemmanager-patch/modes/background
/data/adb/modules/honor-systemmanager-patch/modes/powerkit
```

The module applies at `post-fs-data` and does a late pass at `service.sh`. A reboot is still recommended after switching mode because PackageManager loads restrictions during framework startup.

## 2026-06-23 Recents And Runtime-State Follow-Up

After blocking the background-cleanup profile, Recents swipe-up dismissal was
suspected to be broken. A controlled check found two separate module issues
before testing Recents:

- `status.sh` was reading the whole package block and therefore counted
  components under `enabled-components` as blocked. The status check now only
  counts entries inside `disabled-components`.
- Online restore can add explicit `enabled-components` entries through
  `cmd package enable`. A later block must remove those entries from XML and
  clear PackageManager's explicit enabled state. MagicOS rejects
  `cmd package disable-user` for this privileged package, but accepts
  `cmd package default-state`, so block now applies `default-state` before
  patching XML.

Recents provider on this device:

```text
com.hihonor.android.launcher/.quickstep.RecentsActivity
com.hihonor.android.launcher/.quickstep.TouchInteractionService
```

The launcher has task-management permissions such as `REMOVE_TASKS`,
`MANAGE_ACTIVITY_TASKS`, and `START_TASKS_FROM_RECENTS`, so basic Recents card
dismissal should not depend on System Manager alone.

ADB gesture tests confirmed:

- With all profiles restored, swiping a Recents card upward removed the task.
- With `background` blocked and `powerkit` restored, swiping upward still
  removed the task.
- With both `security` and `background` blocked, swiping upward still removed
  the tested task.

Current conclusion: the `background` profile is not a confirmed cause of
Recents swipe-up failure. If the issue appears again, first reboot after the
mode change and re-run status. If it persists, restore `security` before
`background`, because `security` contains the higher-risk cleanup/System Manager
services (`MainService`, `AppCleanUpService`, and related policy services).
