# Laxus SSH

A Termius-style SSH and SFTP connection manager built with Flutter.

## Features

- **SSH Connection Management**
  - Store and manage multiple SSH configurations
  - Support for password and private key authentication
  - Group connections by category
  - Track last connection times

- **SSH Terminal**
  - Interactive SSH terminal using xterm
  - Full terminal emulation support
  - Copy/paste functionality
  - Resizable terminal

- **SFTP File Browser**
  - Browse remote files and directories
  - Upload and download files
  - Create and delete directories
  - File operations (rename, delete)

- **SQLite Storage**
  - Secure local storage of SSH configurations
  - Fast indexing and searching
  - Group-based organization

## Dependencies

- `dartssh2` - SSH and SFTP protocol implementation
- `sqflite` - SQLite database for local storage
- `xterm` - Terminal emulation
- `file_picker` - File selection for uploads/downloads
- `encrypt` - Encryption utilities
- `uuid` - Unique identifier generation

## Getting Started

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd laxus_ssh
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

## Usage

### Adding a Connection

1. Tap the **+** button on the home screen
2. Fill in the connection details:
   - Connection name
   - Host (IP or domain)
   - Port (default: 22)
   - Username
   - Authentication (Password or Private Key)
   - Optional: Group name

3. Tap the checkmark to save

### Connecting via SSH

1. Tap on a connection in the list or select **SSH** from the menu
2. The terminal will open and automatically connect
3. Use the terminal as you would a normal SSH session

### Using SFTP

1. Select **SFTP** from the connection menu
2. Browse files and directories
3. Use the toolbar to:
   - Upload files
   - Create directories
   - Navigate up
   - Refresh the view

### Managing Connections

- **Edit**: Select Edit from the connection menu
- **Delete**: Select Delete from the connection menu
- **Filter by Group**: Use the filter icon in the app bar

## Project Structure

```
lib/
├── models/
│   └── ssh_config.dart          # SSH configuration model
├── services/
│   ├── database_helper.dart     # SQLite database operations
│   ├── ssh_service.dart         # SSH connection service
│   └── sftp_service.dart        # SFTP file operations
├── screens/
│   ├── home_screen.dart         # Connection list screen
│   ├── add_edit_connection_screen.dart  # Add/edit connection
│   ├── terminal_screen.dart     # SSH terminal UI
│   └── sftp_screen.dart         # SFTP file browser
└── main.dart                    # App entry point
```

## Security Notes

- Passwords and private keys are stored in the local SQLite database
- Consider implementing encryption for sensitive data in production
- Always use secure connections and verify host keys

## Platform Support

- ✅ Android
- ✅ iOS
- ✅ Linux
- ✅ macOS
- ✅ Windows

## License

This project is licensed under the MIT License.
