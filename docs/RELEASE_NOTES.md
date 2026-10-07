# Tomales 0.2.2

Source release for Homebrew; compilation happens on the user's Mac with Apple compiler tools.

- Toggle the panel on mouse-down so clicking the menu-bar icon again closes it.
- Exclude the status-button click from outside-click dismissal and app deactivation handling during the press.
- Add source-based Homebrew installation and tagged releases without an Apple Developer subscription.
- Keep preferences across upgrades and offer the matching update command in Settings.

Compilation and packaging checks only. No test suites or runtime behavior checks were run.

## Tomales 0.2.1

- Replace the pointed popover with a rounded, arrowless native panel below the menu bar.
- Replace the Duration menu with a compact timer strip and a separate custom-time button.
- Choose custom hours/minutes with native sliders and steppers in a compact dialog, keeping the overview's size unchanged.
- Group memory, CPU, swap, and compression in one aligned surface.
- Show one relevant value per process according to the selected resource.
- Keep all chart controls in Settings; remove the history picker from the overview.
- Split Settings into Display, Graphs, and More, with optional details collapsed.
- Offer Numbers only, Bars, Graphs, or Graphs & bars as a single presentation choice.
- Use native vibrancy, balanced spacing, restrained color, and finite transitions.
- Enable scrolling only when content exceeds the available height, and show indicators for overflow.
- Pause collection and overview motion while the timer dialog is open.

Build and packaging checks do not establish power, sensor, or performance behavior. No test suites were run.

## Tomales 0.2.0

Compact native overview, configurable display, and smooth history charts.

- Keep display awake with a switch, preset timers, or a custom duration.
- View memory usage, pressure, swap, compression, wired memory, and cached files.
- View smooth memory/CPU/swap history over 1, 3, or 5 minutes.
- Choose visible sections, individual charts, usage bars, and axis labels in the gear menu.
- Choose 3/5/8 process rows, default sorting, process IDs, and optional memory details.
- Use compact or comfortable spacing with native light/dark appearance.
- See overall CPU and processes by memory, CPU, or estimated process power where supported.
- Read fan RPM where the Mac exposes compatible sensors.
- Pause collection in Settings and stop monitoring/history when the panel is closed.
- Use a custom coastal app icon and matching monochrome menu-bar mark.
- Animate the awake switch, metric icons, process-sort changes, and supported running fans, with Reduce Motion support.
- Prepare universal app/ZIP/DMG packaging and personal Homebrew release automation.

Active awake sessions end on quit or update; duration preferences are retained. Energy and fan availability depend on the Mac and macOS version. Runtime behavior and resource usage require an explicitly authorized check before public release.
