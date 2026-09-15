# Getting started

## Build and start

Use macOS 26 or later with a logged-in desktop session. Build with Swift 6.2 or later:

```sh
make build
.build/debug/sborders start
```

The daemon stays in the foreground. Press Ctrl-C to stop it, or run `sborders stop` from another terminal using the same binary. It has no Dock icon and does not activate its border windows.

For an optimised binary:

```sh
make release
.build/release/sborders start
```

You can copy that binary to a directory on your PATH. When using a service manager, run `sborders start` as your desktop user in the graphical login session. Do not run it as root. A Homebrew formula is not published by this checkout.

## Configuration

At startup, sborders looks for `~/.config/sborders/config.jsonc`, then `config.json`. If neither exists, it starts with built-in defaults and watches `config.json`. To create a JSONC file after that first startup, restart the daemon so it selects the new path.

Create the configuration directory and copy the example before starting:

```sh
mkdir -p ~/.config/sborders
cp examples/sample/config.jsonc ~/.config/sborders/config.jsonc
.build/debug/sborders validate
.build/debug/sborders start
```

To select a different file:

```sh
.build/debug/sborders start --config /path/to/config.jsonc
```

A missing explicit file or invalid startup configuration stops startup. During operation, invalid edits keep the last valid settings. [Configuration](configuration.md) explains precedence and reloads.

## Permissions and compatibility

The default `windowServer` focus mode tracks windows through private WindowServer APIs. It does not request Accessibility permission. The optional `accessibility` focus mode uses the focused Accessibility window and requires permission in System Settings > Privacy & Security > Accessibility.

Private APIs can change between macOS releases. Missing required functions produce a startup error. Read [the validation record](development.md#validation-record) before relying on an untested OS version.

For initial testing, stop any other border daemon to avoid drawing two borders around the same windows.

## Mission Control

Borders hide temporarily while Mission Control is open and return after it closes. This also applies when the daemon starts during Mission Control. Configuration reloads and runtime settings respect the temporary suppression. No additional permission or configuration option is needed.
