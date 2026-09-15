# Configuration

Both `.json` and `.jsonc` files accept JSON with `//` comments, block comments, and trailing commas. Strings retain comment-like text. Unknown keys, duplicate keys, invalid types, and invalid values produce errors.

The decoder, CLI validator, and runtime share the same validation. The [JSON schema](../config.schema.json) supports editor completion.

## Settings

| Property | Default | Accepted values |
| --- | --- | --- |
| `enabled` | `true` | Boolean; false removes border windows |
| `width` | `4` | Number from 0.5 to 64 points |
| `style` | `"round"` | `"round"` or `"square"` |
| `activeColor` | `"#E1E3E4"` | `#RRGGBB` or `#RRGGBBAA` |
| `inactiveColor` | `"#00000000"` | `#RRGGBB` or `#RRGGBBAA` |
| `focusMode` | `"windowServer"` | `"windowServer"` or `"accessibility"` |
| `includeApps` | `[]` | Application matchers; empty allows all eligible apps |
| `excludeApps` | `[]` | Application matchers; exclusion takes precedence |
| `$schema` | Absent | Optional schema URL for editors |

Colours use alpha last. `#45475A80` is translucent; `#00000000` is transparent. Border width is measured in points. Rendering uses each window's display scale automatically.

Round borders use the window's reported corner radius, falling back to nine points when the API is unavailable. Very small windows clamp the radius to fit; windows smaller than two points in either dimension receive no border. Borders sit immediately below their target, with the same level and sublevel.

## Application matching

Each matcher contains exactly one nonempty `bundleID` or `processName`. Matches are exact and case-sensitive. Use `query --windows` to find the identifiers reported for an application. `processName` matches the reported application name, which can be localised.

```jsonc
{
  "includeApps": [
    { "bundleID": "com.apple.Terminal" },
    { "bundleID": "com.mitchellh.ghostty" }
  ],
  "excludeApps": [
    { "processName": "Example utility" }
  ]
}
```

Inclusion does not override the window eligibility checks. Attached windows, windows excluded from normal window cycling, and the daemon's own windows are ignored. Hidden, minimised, and native fullscreen windows receive no visible border.

## Reload and overrides

The daemon watches the selected file and its parent directory. Atomic editor saves work. After an invalid edit or file removal, it retains the last valid settings and reports `configurationError` in diagnostics. Restoring a valid file clears that error.

Runtime commands change the effective settings without writing the file:

```sh
sborders set width 6
sborders set activeColor '#A6E3A1'
sborders set includeApps '[{"bundleID":"com.apple.Terminal"}]'
```

Defaults supply missing properties, file values override defaults, and runtime changes override the file. A successful reload adopts the complete file and clears runtime overrides. A failed reload leaves both intact.

```sh
sborders reload
sborders query --config
sborders query --diagnostics
```

An unrelated change to the configuration directory does not clear overrides when the file's contents remain identical. Explicit `reload` always reloads the file.
