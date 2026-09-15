# Command line

`sborders` without a command is equivalent to `sborders start`.

| Command | Behaviour |
| --- | --- |
| `start [--config <path>]` | Run the daemon in the foreground |
| `validate [--config <path>]` | Validate an existing file without starting WindowServer access |
| `query [--windows \| --config \| --diagnostics]` | Print a JSON response; defaults to diagnostics |
| `reload` | Reload the file and clear runtime overrides after validation |
| `set <property> <value>` | Apply a runtime setting without changing the file |
| `stop` | Stop the daemon and remove its border windows and socket |
| `--help` | Show command help |
| `--version` | Show the binary version |

Help, version, and validation work without a desktop session. Invalid commands and configurations return a nonzero exit status.

## Target a daemon

Client commands accept `--socket`. The default is `~/.config/sborders/control.sock`. A daemon using `--config` creates `control.sock` beside that file:

```sh
sborders start --config /tmp/my-borders/config.jsonc
sborders query --socket /tmp/my-borders/control.sock
sborders set width 5 --socket /tmp/my-borders/control.sock
sborders stop --socket /tmp/my-borders/control.sock
```

Only one daemon can own a given socket. Socket permissions and peer checks restrict access to the same user. Clients never start another daemon implicitly.

## Inspect state

Queries return an object with `ok`, a `value` on successful queries, and `error` on failure.

`query --config` reports the effective configuration, including runtime changes.

`query --windows` includes discovered windows, their IDs, PID, application identity, frame, Spaces, focus state, and border diagnostics. A missing border can be expected for hidden, fullscreen, or filtered windows. Borders also hide while Mission Control is active or borders are disabled. `borderFrame` and `borderSublevel` query the actual WindowServer border state. `borderVisible` reports whether its window is ordered in. Frames use WindowServer coordinates, with their origin at the top left of the main display; other displays can have negative coordinates.

`query --diagnostics` includes the daemon PID, OS version, window and border counts, event and reconciliation counts, selected configuration path, runtime override status, and the latest configuration or backend error. `missionControlActive` reports temporary overview suppression; `enabled` in the configuration remains unchanged. Border count includes any retained hidden border windows.

## Stop

`stop` acknowledges the request before shutdown. The daemon unregisters notifications, cancels file watchers, closes borders, and removes its socket. SIGINT and SIGTERM use the same cleanup path. The lock file can remain on disk after exit; the operating system releases its lock when the descriptor closes.
