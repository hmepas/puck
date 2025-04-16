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

## Planned CLI Usage

*   `puck`: Installs the launch agent (if needed), starts the daemon, and detaches.
*   `puck -l` or `puck --list`: Lists all available input source IDs configured on the system.
*   `puck -o` or `puck --observe`: Enters a mode to observe and print key presses (names and modifiers) to help with configuration.
*   `puck --install-service`: Installs the launchd service file.
*   `puck --uninstall-service`: Removes the launchd service file.
*   `puck --start-service`: Starts the launchd service.
*   `puck --stop-service`: Stops the launchd service.
*   `puck --restart-service`: Restarts the launchd service.
*   `puck -c <path>` or `puck --config <path>`: Use a specific configuration file path.
*   `puck -v` or `puck --version`: Show version information.

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

## Installation (Planned)

Instructions for building from source using Swift Package Manager and potentially Homebrew will be added here.

## Dependencies

*   Swift Package Manager
*   Xcode Command Line Tools

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

MIT License