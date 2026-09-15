# sborders

Window borders for macOS.

`sborders` draws configurable borders around application windows, follows focus and window movement, and reloads JSONC configuration while running. It works alongside `swm`, `skbd`, and `sbar` without requiring a particular window manager.

## Quick start

Requires macOS 26 or later. Building requires Swift 6.2 or later.

```sh
make build
.build/debug/sborders
```

The default border is four points wide, with a light active colour and transparent inactive colour. Create `~/.config/sborders/config.jsonc` to change it:

```jsonc
{
  "width": 4,
  "activeColor": "#89B4FA",
  "inactiveColor": "#45475A80"
}
```

Start with `--config` to use another file. The default focus mode does not request Accessibility permission. See [getting started](docs/getting-started.md) for configuration paths and [development](docs/development.md) for the current validation record and private API limitations.

## Documentation

- [Documentation index](docs/index.md)
- [Configuration](docs/configuration.md)
- [Command line](docs/cli.md)
- [Development and validation](docs/development.md)
- [Sample configuration](examples/sample/config.jsonc)
