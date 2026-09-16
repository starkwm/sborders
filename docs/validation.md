# First-version validation

Checked on 15 and 16 September 2026 with macOS 27.0 build `26A428`, Apple Silicon, and Swift 6.4. The package deployment target is macOS 26.

## Automated checks

- `make lint` checks Swift formatting.
- `swift test --parallel --disable-xctest` passes 30 tests across two test targets, including parameterised invalid-configuration and rendering cases.
- The JSON schema parses successfully.
- Documentation examples pass the real configuration validator.
- `otool -L` lists system frameworks and system Swift libraries. The binary does not require a sibling checkout or a SwiftPM resource bundle.

## Desktop checks

The release binary passed the following desktop checks during implementation:

1. Initial border bounds, relative window ordering, sublevels, and focus.
2. Movement follows the actual target frame without repainting.
3. Resizing updates the border dimensions.
4. Focus switches between windows in the same application.
5. Windows created after daemon startup receive borders and are removed on closure.
6. Hide and show.
7. Minimise and restore.
8. Native fullscreen Space entry and return.
9. Runtime settings and rejection of invalid updates.
10. Invalid file edits retain the last valid configuration and runtime overrides.
11. Atomic replacement reloads the file and clears overrides.
12. Disabling and enabling borders.
13. Idle state performs no additional reconciliation or repainting during the sample.
14. A duplicate daemon using the same socket is rejected.
15. Window closure and daemon shutdown remove borders and the socket.

The fixture compares border geometry with fresh WindowServer data. Its ordering check uses the visible window stack. An offscreen bitmap test also verifies that both border styles leave the window interior and outer padding transparent. A captured live border was inspected during implementation.

## Mission Control follow-up

Checked on 16 September 2026 on the same macOS 27 build. The interactive Mission Control checks passed:

- Entry hides both fixture borders. Reloading and changing settings while the overview is open keeps them hidden.
- Restarting the daemon during Mission Control starts with borders hidden.
- Exit restores borders with current geometry and focus, without changing the configured `enabled` value.

This machine uses WindowManager's overview shield at layer 19. The implementation also recognises Dock's layer 18 overview and entry notification for older macOS versions, but that path still needs a macOS 26 desktop test. Window titles are not used for detection.

The interactive and fullscreen runs passed their functional checks but failed later idle assertions. A separate quiet-desktop run passed all 14 baseline checks, including idle behaviour, duplicate startup, and cleanup. During that idle sample, the event count stayed at 24 and the reconciliation count at 18; CPU time and repaint counts also stayed unchanged.

## Initial resource sample

With two fixture windows after the interaction checks, the release daemon reported 42,688 KiB resident memory, approximately 41.7 MiB. Process CPU time read `0:00.37` before and after a one-second idle interval. Reconciliation and repaint counts also stayed unchanged in that interval.

This is a short sample on one machine. Sustained movement, larger window counts, and comparison with other border implementations still need measurement.

## Remaining platform coverage

The following have not been established by this run:

- A macOS 26 desktop and the Swift 6.2 compiler.
- Multiple displays, mixed display scales, and sticky windows.
- Stage Manager transitions and Mission Control on macOS 26.
- Sleep/wake and login/logout.
- Live Accessibility permission handling and focus compatibility across applications.
- Window-manager animation proxies, which are outside the first version.

The local test processes were stopped after validation. No login service was installed and no release was published.

## Tracking improvements

Checked on 16 September 2026 with the debug build:

- Swift Testing passed all 34 tests across both targets, including event classification, transfer recovery, failed liveness queries, and expiration of retained closed windows.
- Strict Swift formatting, whitespace checks, and the CLI smoke script passed.
- The tracking-only desktop fixture passed seven checks: initial geometry and ordering; movement without metadata/focus queries, repainting, context recreation, or unrelated border transactions; resize context recreation and final bounds; combined move/resize; hide/show; no idle queries or transactions; and closed-window removal.

The full desktop fixture stopped at initial focus on both the unchanged `72b058b` baseline and the modified build. The tracking-only mode does not require activation and does not establish focus behavior. Multi-display transfers, mixed backing scales, and presented-pixel synchronization still need live verification. Context counters establish recreation, not visual correctness of every resized pixel.

Checked again on 17 September 2026 after giving each pending transfer an independent 380 ms expiry. All 37 Swift tests and strict formatting passed. The added tests cover repeated notifications without extending retention, cancellation followed by a new transfer for the same window, and shutdown cancellation. Desktop checks were not rerun.
