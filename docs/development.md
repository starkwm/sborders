# Development

## Structure

`Sborders` contains ArgumentParser commands. `SbordersCore` contains configuration, IPC, platform access, the runtime, and drawing. Tests mirror those areas.

All native window state and drawing belong to the main actor. Socket work runs on a private serial queue and sends commands to that actor. WindowServer callbacks copy their small payloads before queueing work. The runtime coalesces updates by window ID and queries current state when processing them.

AppKit's native event loop delivers WindowServer notifications. A bare `CFRunLoopRun` did not deliver updates in live testing. The daemon uses a prohibited activation policy, without a Dock icon or interactive application window.

Mission Control temporarily suppresses rendering without changing `enabled`. WindowServer event 1204 covers the older Dock path. Window creation and focus events also check for macOS 27's WindowManager overview. Detection uses the owning process and window layer, so it needs no window titles or additional permissions. Entry checks are bounded; while the overview is active, a 100 ms timer watches for its disappearance. Exit requires two absent samples and triggers fresh window reconciliation. Shutdown cancels the timer.

Movement reads current bounds and updates only the affected border, preserving its drawing and avoiding focus and metadata queries. Crossing displays refreshes metadata and backing scale. Duplicate geometry does not submit a transaction. Size and scale changes recreate the drawing context before painting; colour and radius changes redraw. Resize notifications schedule a cancellable final bounds check after 32 ms without another resize. Space-scoped removal hides the border while a complete window inventory establishes liveness; a still-live window retains its border during the bounded transfer retries. Missing windows are released when that grace period expires, since closed AppKit windows can retain server IDs. The coordinator tracks application windows separately from notification subscriptions so hiding a window does not prevent its later return.

## Build and tests

```sh
make build
make format
make lint
make test
make release
```

`make test` uses Swift Testing with XCTest disabled. It tests strict JSONC decoding, configuration precedence and reload failures, eligibility and lifecycle state, border geometry and offscreen pixels, CLI arguments, and local socket behaviour.

Desktop checks require a logged-in macOS session. Check movement, resizing, focus, hide/show, minimise/restore, fullscreen, Mission Control, configuration reloads, and shutdown with ordinary application windows.

## Validation record

See [validation](validation.md) for the checks run during the first implementation.

macOS 26 is the deployment target. A deployment target alone does not prove compatibility. The current development machine runs macOS 27.0 build `26A428` with Swift 6.4. CI is configured for a macOS 26 runner, but its remote result is not available from this local implementation.

## Remaining validation

Test a macOS 26 desktop and compiler, mixed-scale multi-display layouts, sticky windows, Mission Control on macOS 26, Stage Manager, sleep/wake and login/logout before treating those combinations as verified. The optional Accessibility focus mode also needs a live permission and application compatibility pass.

Private APIs can change. Required missing symbols stop startup; optional corner-radius discovery uses a fixed fallback. Keep declarations and ownership rules inside `Platform/SkyLight`. The callback destination lives for the process lifetime so late callbacks cannot dereference a released runtime.

Gradient and glow styles, per-window overrides, and yabai animation-proxy compatibility are later work in the [implementation plan](implementation-plan.md). Ordinary window-manager move and resize events are supported; no animation-proxy protocol is implemented.

## Release build

```sh
make release
.build/release/sborders --version
```

The standalone binary is `.build/release/sborders`.
