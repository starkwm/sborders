# Source provenance

This repository retains its BSD-3-Clause licence and Stark Software copyright.

The Swift border backend, rendering, lifecycle, configuration model, CLI, and tests are an original implementation. The JankyBorders source review informed the implementation plan and private API investigation. No JankyBorders implementation files were copied or mechanically translated into Swift.

The following files were adapted from the BSD-3-Clause `starkwm/sbar` checkout at commit `aa5e36c69fa52e9bc4cab8922b0dbc4427ed6886`:

- `Configuration/ConfigurationDecoder.swift`, including its string-safe comment and trailing-comma normalisation. Sborders adds duplicate-key rejection.
- `Configuration/ConfigurationWatcher.swift`, for atomic replacement and first-creation watching.
- `IPC/ControlServer.swift`, `IPC/ControlMessage.swift`, and `IPC/LocalSocket.swift`. Sborders removes subscription support and adds socket-path validation.

Those paths are relative to `Sources/SbordersCore`. The source project has the same Stark Software copyright and BSD-3-Clause licence as this repository.

The private API declarations describe system interfaces. The exported sublevel query was tested against a known sublevel on macOS 27, avoiding JankyBorders' internal connection-port lookup and packed Mach-message implementation. AppKit supplies the native event loop.
