# Apple Notes Exporter

Apple Notes Exporter is a macOS application designed to export notes from the Apple Notes app to a specified directory on your computer. The application is built using Swift and provides a simple interface to select an export location and manage permissions.

## Features

- **Export Notes**: Export all your notes from the Apple Notes app to a directory of your choice as text files.
- **Directory Selection**: Easily select the export directory using a macOS-native directory picker.
- **Permission Management**: Check and manage directory permissions to ensure successful exports.
- **Logging**: Utilizes `OSLog` for logging export activities and errors.

## Project Structure

- **apple-notes-expoerter**: Main application directory containing source files.

  - **ContentView.swift**: The main view of the application, handling UI interactions and export logic.
  - **Services**: Contains service classes.
    - **NotesExporter.swift**: Handles the logic for exporting notes, including AppleScript execution to fetch notes.
    - **PermissionChecker.swift**: Checks and manages directory permissions.
  - **Assets.xcassets**: Contains image and other asset resources.
  - **Preview Content**: Contains preview assets for SwiftUI previews.
  - **apple_notes_expoerter.entitlements**: Defines app entitlements for accessing user data.

- **apple-notes-expoerter.xcodeproj**: Xcode project file.
- **apple-notes-expoerterTests**: Contains unit tests for the application.
- **apple-notes-expoerterUITests**: Contains UI tests for the application.

## Requirements

- macOS 11.0 or later
- Xcode 12.0 or later

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/mrsarac/apple-notes-expoerter.git
   ```

2. Open the project in Xcode:

   ```bash
   open apple-notes-expoerter.xcodeproj
   ```

3. Build and run the application on your Mac.

## Usage

1. Launch the application.
2. Click "Select Export Location" to choose a directory where you want to save your exported notes.
3. Click "Export Notes" to start the export process.

## Troubleshooting

- Ensure you have the necessary permissions to write to the selected export directory.
- If you encounter permission errors, try adjusting the directory permissions using the terminal.
- The `PermissionChecker` class checks directory permissions to ensure the selected export location is writable.
- The `checkAndCreateDirectory` method in `NotesExporter.swift` handles specific permission errors and provides detailed error messages.

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request for any improvements or bug fixes. If you encounter any issues, please submit them via the repository's issue tracker.

## License

This project is licensed under the MIT License.

## Update Log

### Version 1.1.0
- Added onboarding to grant permissions.
- Improved error handling for permission errors.
- Updated UI to follow the latest Apple design guidelines.
- Enhanced logging for better troubleshooting.
- Updated README with the latest instructions and logs.
