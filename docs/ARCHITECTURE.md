# Implementation

## App lifecycle

`TomalesApp` owns a single `NSStatusItem` and an arrowless `FloatingPanel` subclass of `NSPanel`. Its borderless window hosts a rounded SwiftUI surface over native vibrancy, with the system window shadow. It clamps its position and height to the status item's screen. The status button toggles it on mouse-down; outside-click handlers exclude the button, and app deactivation during that press leaves the toggle to the button. Outside mouse clicks, Escape, app deactivation/hiding, session deactivation, desktop changes, and screen changes dismiss it. Presentation state is tracked separately from native visibility so cleanup still runs after system-driven hiding. Mouse monitors and panel notification observers exist only while shown. An accessory activation policy and `LSUIElement` keep the app out of the Dock. A second instance with the same bundle identifier terminates rather than creating another status item. A custom template mark combines mountains, a wave, and a sun; the sun fills while the awake assertion is active. Images are cached for the two states.

`AppModel` owns the visible panel state and polling task. `MetricsReader` serializes collection in an actor; UUID session tokens prevent an old cancelled collector from replacing a newer panel's data or clearing its baselines. Closing the panel cancels polling and clears snapshots. System sleep pauses sampling. Waking resumes sampling only if the overview is still visible.

`DisplayPreferences` stores a versioned Codable configuration in UserDefaults, with defaults for missing fields. Settings occupy the same panel, split into Display, Graphs, and More. Chart controls are absent from the overview. Graph style maps to the existing chart/bar flags, preserving per-metric chart preferences; optional chart and process controls use progressive disclosure. Opening Settings pauses collection but retains the last snapshot and history until returning; reopening a closed panel starts a fresh history. Hidden process and fan sections are not sampled. Display-default reset is separate from awake duration preferences.

The awake timer uses five preset segments and a separate custom-time button. A native sheet lets people choose hours and minutes with sliders or steppers, without typing or changing the overview's height. Draft changes remain local until Set timer; Cancel discards them. The range is 1 minute through 24 hours. Collection and overview motion pause while editing, preserving the last snapshot/history; returning resets rate baselines. Hiding the parent also closes the sheet. No pointed secondary popover is needed. Changing a timer during an active session still replaces its assertion; selecting a timer while off does not enable the switch.

`AdaptiveScrollView` measures content and viewport height during layout. It disables scrolling and hides indicators when content fits. Overflow enables scrolling with visible indicators; macOS 13.3 and later also use size-based bounce. The content is mounted once, avoiding duplicate icon/graph animation trees. Measurement requires no polling timer.

## Artwork and animations

`GenerateIcon.swift` draws the app icon with AppKit paths, gradients, restrained shadows, and a transparent outer margin. The generated `.icns` serves Finder and the app bundle; a 256-pixel PNG serves the panel badge. No image-generation service or animation library is needed at runtime.

`IconViews` uses macOS 13-compatible SwiftUI transitions. Icon pulses are finite tasks cancelled by visibility or Reduce Motion changes. Memory motion triggers on 5-percentage-point buckets or pressure changes; CPU motion triggers on 10-percentage-point buckets. This avoids triggering a pulse for every small numeric fluctuation. The process-sort icon changes with the selected category.

Only a fan with a valid positive RPM mounts the repeating rotation view, and only while the panel is visible and Reduce Motion is off. Closing the panel removes that view from the animation graph. The menu-bar bounce is a single 350 ms Core Animation sequence on a user-visible awake-state change; closing the panel removes it. There is no frame-generation task, display link, or extra system polling for motion.

History keeps at most 151 timestamped readings and five minutes. CPU/memory use a fixed percentage domain; swap uses a labelled adaptive byte domain. Missing readings and sampling gaps split the trace. Paths use a fixed-size VectorArithmetic representation to interpolate geometry over 650 ms between actual samples; number labels display measured values rather than interpolated readings. Scale changes interpolate over 300 ms and usage bars over 550 ms. Native SwiftUI renders these finite transitions; charts add no sampling or frame timer. Motion can be disabled in display preferences and always respects Reduce Motion.

## Display awake

`AwakeController` uses `IOPMAssertionCreateWithDescription` with `PreventUserIdleDisplaySleep`. No persistent power settings are changed. A timed assertion also has a native power-daemon timeout, so a busy app thread cannot indefinitely extend the requested duration. Timeout action turns the assertion off while retaining a releasable ID.

Deadlines use `mach_continuous_time`, which includes system sleep. A one-shot expiry timer releases the assertion, and wake notifications reconcile overdue sessions. A replacement assertion is created before releasing the old one; errors preserve the previous session and are displayed. The active state is not saved in preferences. The system owns assertion cleanup when a process dies.

## System readings

| Reading | Source and interpretation |
| --- | --- |
| Physical RAM | `hw.memsize` |
| Used RAM | `host_statistics64`: nonpurgeable internal pages + wired pages + compressor storage, clamped to physical RAM |
| Cached files | External pages + purgeable pages; shown separately |
| Swap | `vm.swapusage`; used bytes rather than historical swap traffic |
| Pressure | `kern.memorystatus_vm_pressure_level`; unknown or denied values remain unavailable |
| Overall CPU | Delta of `HOST_CPU_LOAD_INFO` ticks; busy / total, 0–100% across all cores |
| Process memory | `proc_pid_rusage`, physical footprint |
| Process CPU | Delta of user + system nanoseconds, with PID + process start time identity; 100% equals one logical core |
| Process power | When compiled with V6 support and returned by macOS, delta of `ri_energy_nj` divided by elapsed time; displayed as an estimate in mW/W |
| Fan RPM | Read-only AppleSMC keys `FNum` and `F#Ac`; supports known integer, fixed-point and float encodings |

CPU tick subtraction handles 32-bit wraparound. Process counters that regress or belong to a reused PID do not generate rates. Process buffers, Mach port references, and IOKit connections are released after each collection. Energy sampling falls back to V4 resource usage when V6 is unavailable. An energy counter that remains unsupported/zero does not claim a measured zero-watt process.

SMC is an undocumented hardware interface. The app checks packet size, key size, result status, finite values, fan count, and plausible RPM. A successful fan count of zero is distinct from unavailable access. No root helper, fan writes, or permission-prompt workaround is included.

## Polling and limits

Memory/CPU refresh every 2 seconds. Processes and fans refresh every 6 seconds after initial readings; processes get an initial rate sample at 2 seconds. Values in the panel represent a sampling interval, not instantaneous power. Sleeping and reopening reset rate baselines. A read already in progress may finish after the panel closes, but its result is discarded and no new polling is scheduled.

The top-process list contains 3, 5, or 8 individual PIDs according to display preferences, rather than an Activity Monitor-style grouping of an app and all its children. Kernel permissions can hide processes. Memory values may differ from Activity Monitor because of sampling time, units, and accounting details. Per-process energy is neither wall power nor a promise of complete device attribution.

## Distribution

`VERSION` is the single version source. `build.sh` creates a conventional `.app` bundle, a generated icon, and a local ad-hoc or Developer ID signature. Current Homebrew distribution uses a formula that compiles a checksummed, versioned source archive for the user's own Mac. The native bundle lives in the formula prefix, and its launcher uses Homebrew's stable `opt` path. Formula builds embed their update command in Settings; `tomales --restart` quits an older instance before launching the current app.

The release workflow guards the personal repository, validates its tag/version, publishes the source archive and checksums, then commits the generated formula to `main` in the same repository. It needs no Apple credentials or separate tap token. The app and Homebrew keep one update authority; no Sparkle or second updater runs in the background.

Optional signed binary packaging remains available through `package.sh --release`: it requires Developer ID/notarization credentials, builds universal binaries, checks notarization is Accepted, staples the app and DMG, and hashes the final downloads. `generate-cask.py` prepares a cask for those downloads. The previous signing workflow is retained only as an inactive example under `docs/examples`.

## References

- [Apple IOKit power management](https://developer.apple.com/documentation/iokit/iopmlib_h)
- [Apple memory terminology](https://support.apple.com/guide/activity-monitor/view-memory-usage-actmntr1004/mac)
- [Apple Activity Monitor energy terminology](https://support.apple.com/guide/activity-monitor/view-energy-consumption-actmntr43697/mac)
- [Stats AppleSMC adapter](https://github.com/exelban/stats/blob/master/SMC/smc.swift)
- [Apple notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- [Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)
- [Apple layout guidelines](https://developer.apple.com/design/human-interface-guidelines/layout)
- [Apple design foundations](https://developer.apple.com/videos/play/wwdc2025/359/)
- [Apple slider guidelines](https://developer.apple.com/design/human-interface-guidelines/sliders)
