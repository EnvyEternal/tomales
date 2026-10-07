# Tomales

Keep awake. Know your Mac.

A native macOS menu-bar app with a display-awake switch, timer, and a compact system monitor. SwiftUI + AppKit, with a small C adapter for system counters. No third-party runtime dependencies, privileged helper, background service, or account.

## Install with Homebrew

Requires macOS 13 or later, Homebrew, and current Apple Command Line Tools or Xcode with Swift 5.9 or newer. Install and open with one terminal line:

```sh
brew tap EnvyEternal/tomales https://github.com/EnvyEternal/tomales && brew install EnvyEternal/tomales/tomales && tomales --restart
```

Update and reopen with one line:

```sh
brew update && brew upgrade EnvyEternal/tomales/tomales && tomales --restart
```

The explicit tap URL is needed because this repository is named `tomales`, rather than `homebrew-tomales`. Both installation and upgrades compile for the Mac's own architecture. No Xcode GUI or paid developer account is needed. Homebrew and suitable compiler tools must already be installed; Homebrew's usual trust prompts may apply to a custom tap.

Launch later with `tomales`. Homebrew owns the app inside `$(brew --prefix tomales)/Tomales.app`; no files are copied over an existing app in Applications. `--restart` quits the old instance before opening the current version, ends any active awake session, and keeps preferences. Normal `brew uninstall EnvyEternal/tomales/tomales` keeps preferences too.

## Local version

Requires macOS 13 or later. Building requires Xcode 15 or later, or compatible Command Line Tools with Swift 5.9 and a macOS SDK. A recent SDK exposes additional process energy counters; older SDKs build with those counters unavailable.

From the project directory, install and open with one command:

```sh
./scripts/install-local.sh
```

This builds the app and installs it in `~/Applications/Tomales.app`. Run the same command to update a local installation. It quits the previous instance before replacement and keeps preferences. It does not enable Keep display awake after restarting.

To build without installing or opening:

```sh
./scripts/build.sh
```

The result is `dist/Tomales.app`. Open it in Finder, or use `open dist/Tomales.app`. Its icon appears in the menu bar, with no Dock icon. Click the icon to open the panel.

To package a universal Apple Silicon + Intel build:

```sh
./scripts/package.sh --universal
```

Local packages use an ad-hoc signature. Public downloads need Developer ID signing and notarization before sharing as a smooth installation experience.

## What it does

- **Keep display awake:** a switch with unlimited, 15, 30, 60, 120, or custom 1–1440 minute sessions. Turning it off releases the app's power assertion; existing macOS display sleep preferences apply again. Changing duration during a session restarts its timer.
- **Memory:** used and total RAM, memory pressure, swap, compressed memory, app memory, wired memory, and cached files. Binary units are labelled GiB/MiB.
- **CPU:** overall load and the highest processes by CPU or memory. Choose 3, 5, or 8 process rows. A process can exceed 100% CPU when it uses multiple logical cores.
- **Energy:** top processes by estimated power from kernel energy-counter deltas, where available. This is not Activity Monitor's Energy Impact or whole-Mac power.
- **Fans:** reported RPM through read-only AppleSMC access, where supported. No fan control.

The switch does not edit `pmset` or System Settings. Other apps can independently prevent sleep. Manual sleep and closing a laptop's lid still follow macOS behavior. Timed sessions include elapsed sleep time and expire on wake if their deadline passed. Quitting, crashing, updating, or restarting does not preserve an active session.

Energy counters and fan sensors vary by OS and hardware. Missing readings say unavailable rather than showing fabricated values. Processes that exit or cannot be read are skipped and counted. Process rows are individual PIDs, including helper processes, rather than aggregated application totals.

## Appearance and motion

The app icon combines pale coastal ridges, teal bay water, and a warm sun. It is drawn from native paths and gradients in `Tools/GenerateIcon.swift`, exported at all macOS icon sizes, and reused in the panel. The menu bar uses a matching monochrome mountain/wave/sun mark that adapts to the system appearance.

The awake switch has a brief sun transition and menu-bar bounce. Memory and CPU icons pulse on meaningful reading changes; process icons transition when changing sort; icons respond to hover. The fan icon rotates slowly only while a positive RPM is reported. Progress bars ease between samples without changing their numeric readings.

The arrowless panel uses native vibrancy, rounded corners, and the system window shadow. A timer strip replaces a duration menu, with a separate custom-time button. A compact native dialog offers hours/minutes sliders and steppers for mouse selection; the overview does not expand. Set timer applies the draft, and Cancel discards it. Memory/CPU, swap, and compression share one aligned surface; each top-process row shows the value for the selected resource. All chart controls live in Settings. Scrolling is disabled when content fits; longer content has visible scroll indicators. Chart lines morph smoothly between actual readings, usage bars ease to their new values, and process order/page changes use short transitions. Panel motion stops when the panel closes and respects macOS Reduce Motion. There are no animated app-icon frames, background animation timers, or additional polling loops. The icon preview is in `Resources/Artwork/TomalesIcon.png`.

## Display settings

Open the gear in the panel header, or press Command-comma. Preferences persist across restarts and updates.

- **Display:** show or hide memory, CPU, swap/compression, top processes, and fans.
- **Graphs:** choose Numbers only, Bars, Graphs, or Graphs & bars, and a 1-, 3-, or 5-minute history. Optional per-metric charts and axis labels are behind Customize graphs.
- **More:** spacing, animations, detailed memory, process row count, optional process IDs/default sorting, version/update information, and restore defaults. Awake-session preferences are not reset.

History uses actual timestamps, collects only in the overview, and resets when the panel closes or the Mac sleeps. Missing readings and pauses leave gaps. It is not a recording of time before the panel was opened.

CPU and memory charts use a fixed 0–100% scale. Swap uses an adaptive byte scale with a minimum range of 1 GiB; optional axis labels show the current range. Default display is compact with memory/CPU charts and three process rows. The swap chart, usage bars, axis labels, and detailed breakdown are optional.

## Resource use

System readings run only while the overview is open: memory/CPU every 2 seconds; processes and fans every 6 seconds, with a second process sample after 2 seconds to establish rates. Sampling pauses in Settings, the timer editor, and for system sleep, and stops when the panel closes. Hidden process/fan sections are not polled. Collection runs outside the main UI actor. History is bounded to five minutes and 151 samples. A closed panel retains no snapshots, history, or rate baselines.

An active timed awake session needs one expiry timer; an unlimited session needs no repeating timer. The app itself makes no network requests and stores only duration and display preferences. These are implementation choices to limit overhead, not measured CPU/RAM guarantees.

## Releases

Source and the Homebrew tap share the public [EnvyEternal/tomales](https://github.com/EnvyEternal/tomales) repository. Releases build the app locally on the user's Mac, so an Apple Developer subscription is not required. The app stays native and has no additional runtime dependencies. A future prebuilt download can use Developer ID signing and notarization.

Pushing a version tag publishes a checksummed source archive and updates `Formula/tomales.rb` on `main`. Versions below 1.0 are marked as prereleases. No tests run in the release workflow.

See [release setup](docs/RELEASE.md), [implementation details](docs/ARCHITECTURE.md), and [current release notes](docs/RELEASE_NOTES.md).

## Verification status

Compiler/build checks are separate from runtime checks. The panel, Settings, and custom-timer dialog layout were inspected locally. No automated tests, display-awake behavior checks, fan/energy compatibility checks, or resource measurements were run. Hardware compatibility and resource usage still need a user-authorized runtime check before the first public release.

## License

MIT. AppleSMC implementation notes and upstream attribution are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
