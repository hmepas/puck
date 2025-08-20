# Puck  Puck - Your Swift Input Method Switching Daemon for macOS

Puck is a lightweight daemon for macOS designed to provide fast and configurable switching between input methods using keyboard shortcuts. Inspired by the simplicity and efficiency of [skhd](https://github.com/koekeishiya/skhd), Puck uses a similar configuration syntax for defining your keybindings.

## Features

*   **Background Operation:** Runs silently as a launchd service.
*   **Configurable Hotkeys:** Define custom keyboard shortcuts for specific input methods or groups.
*   **Input Method Cycling:** Assign the same shortcut to multiple input methods to cycle through them.
*   **Simple Configuration:** Uses an `skhd`-inspired text file for easy setup.
*   **Discoverability:** List available input methods and observe key presses directly from the CLI.
*   **Autostart:** Automatically configures itself to launch on login.
*   **Modern macOS:** Built with Swift for optimal performance and integration.

## CLI Usage

*   `puck`: Installs and starts the service if not already running.
*   `puck -l` or `puck --list`: Lists all available input source IDs configured on the system.
*   `puck -o` or `puck --observe`: Enters a mode to observe and print key presses (names and modifiers) to help with configuration.
*   `puck -f` or `puck --foreground`: Run in foreground mode without installing as a service.
*   `puck -s` or `puck --status`: Show service status (installed and running state).
*   `puck -u` or `puck --uninstall`: Uninstall the service.
*   `puck -c <path>` or `puck --config <path>`: Use a specific configuration file path.
*   `puck -v` or `puck --version`: Show version information.
*   `puck --log-level <level>`: Set log level (`trace|debug|info|notice|warning|error|critical`).
*   `puck --log-file <path>`: Log file path (default `~/Library/Logs/Puck/puck.log`).

The default configuration file location is `~/.config/puck/puckrc`. You need to create this file before running the service.

Note: The application requires accessibility permissions to function. You will be prompted to grant these permissions in System Settings -> Privacy & Security -> Accessibility when installing the service.

### Logging

By default, logs go to `~/Library/Logs/Puck/puck.log` (created automatically). You can change location with `--log-file` and verbosity with `--log-level`.

Examples:

```bash
# Run foreground with verbose logging
puck -f --log-level debug --log-file ~/.local/state/puck/puck-debug.log

# Check service status with additional logs
puck --status --log-level notice
```

## Configuration (`~/.config/puck/puckrc`)

Puck looks for its configuration file at `~/.config/puck/puckrc` by default. The syntax is straightforward:

### Define hotkeys using modifier symbols (cmd, ctrl, alt, shift) and key names.
### Map a hotkey to a specific input source ID.
### Example: Switch to U.S. layout with Cmd+Shift+Space
cmd + shift - space : com.apple.keylayout.US
### Example: Cycle between Russian and U.S. using Ctrl+Alt+P
ctrl + alt - p : com.apple.keylayout.Russian
ctrl + alt - p : com.apple.keylayout.US
### Find input source IDs using 'puck -l'
### Find key names using 'puck -o'

## Installation

### Via Homebrew

```bash
brew tap hmepas/puck
brew install puck
```

### Prerequisites

- macOS
- Xcode 14.0 or later (will be installed automatically via Homebrew if not present)
- Accessibility permissions (required for input source switching)

## Dependencies

*   Swift Package Manager
*   Xcode Command Line Tools

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

MIT License