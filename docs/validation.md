# First-version validation

Checked on 15 September 2026 with macOS 27.0 build `26A428`, Apple Silicon, and Swift 6.4. The package deployment target is macOS 26.

## Automated checks

- `make lint` checks Swift formatting.
- `swift test --parallel --disable-xctest` passes 25 tests across two test targets, including parameterised invalid-configuration and rendering cases.
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

## Initial resource sample

With two fixture windows after the interaction checks, the release daemon reported 42,688 KiB resident memory, approximately 41.7 MiB. Process CPU time read `0:00.37` before and after a one-second idle interval. Reconciliation and repaint counts also stayed unchanged in that interval.

This is a short sample on one machine. Sustained movement, larger window counts, and comparison with other border implementations still need measurement.

## Remaining platform coverage

The following have not been established by this run:

- A macOS 26 desktop and the Swift 6.2 compiler.
- Multiple displays, mixed display scales, and sticky windows.
- Mission Control and Stage Manager transitions.
- Sleep/wake and login/logout.
- Live Accessibility permission handling and focus compatibility across applications.
- Window-manager animation proxies, which are outside the first version.

The local test processes were stopped after validation. No login service was installed and no release was published.
