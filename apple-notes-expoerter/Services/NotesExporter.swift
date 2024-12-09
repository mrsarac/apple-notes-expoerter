import Foundation
import OSLog
import AppKit

enum NotesExportError: Error, CustomStringConvertible {
    case accessDenied
    case exportFailed(String)
    case fetchFailed
    case permissionDenied(String)
    case noNotes
    case unknownError
    
    var description: String {
        switch self {
        case .accessDenied:
            return "Access to Apple Notes was denied"
        case .exportFailed(let message):
            return "Export failed: \(message)"
        case .fetchFailed:
            return "Failed to fetch notes"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .noNotes:
            return "No notes found to export"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}

class NotesExporter {
    private let logger = Logger(subsystem: "com.apple-notes-exporter", category: "NotesExporter")
    
    private func getDefaultExportDirectory() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportDirectory = documentsDirectory.appendingPathComponent("Exported Notes")
        
        do {
            try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        } catch {
            print("❌ Failed to create default export directory: \(error.localizedDescription)")
        }
        
        return exportDirectory
    }
    
    private func generateUniqueDirectoryPath(_ originalPath: URL) -> URL {
        var uniquePath = originalPath
        var counter = 1
        let fileManager = FileManager.default
        
        while fileManager.fileExists(atPath: uniquePath.path) {
            uniquePath = originalPath.deletingLastPathComponent()
                .appendingPathComponent("\(originalPath.lastPathComponent)_\(counter)")
            counter += 1
        }
        
        print("🔍 Generated unique directory path: \(uniquePath.path)")
        return uniquePath
    }
    
    private func checkAndCreateDirectory(at url: URL) throws {
        let fileManager = FileManager.default
        
        // İlk olarak parent dizinin yetkilerini kontrol et ve göster
        let parentDirectory = url.deletingLastPathComponent()
        let permissions = PermissionChecker.checkPermissions(path: parentDirectory.path)
        
        print("📊 Permission Check Results:")
        print(permissions.description)
        
        if !permissions.isWritable {
            print("❌ No write permission for parent directory: \(parentDirectory.path)")
            throw NotesExportError.permissionDenied("""
                Cannot create directory at \(url.path).
                Please ensure you have write permissions for the selected location,
                or try selecting a different export location.
                
                Current Permissions:
                \(permissions.description)
                """)
        }
        
        do {
            print("🔨 Attempting to create directory: \(url.path)")
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            print("✅ Directory created successfully: \(url.path)")
        } catch {
            print("❌ Directory creation error: \(error.localizedDescription)")
            logger.error("Directory creation error: \(error.localizedDescription)")
            
            if let nsError = error as NSError? {
                switch nsError.code {
                case CocoaError.fileWriteNoPermission.rawValue,
                     CocoaError.fileWriteVolumeReadOnly.rawValue,
                     CocoaError.fileWriteUnknown.rawValue:
                    throw NotesExportError.permissionDenied("""
                        Cannot create directory at \(url.path).
                        Please ensure you have write permissions for the selected location,
                        or try selecting a different export location.
                        """)
                default:
                    throw NotesExportError.exportFailed("Failed to create directory: \(error.localizedDescription)")
                }
            } else {
                throw NotesExportError.exportFailed("Unknown error creating directory")
            }
        }
    }
    
    func exportNotes(to directory: URL? = nil) throws -> Int {
        // Use provided directory or default to documents directory
        let exportDirectory = directory ?? getDefaultExportDirectory()
        
        print("📦 Starting export to directory: \(exportDirectory.path)")
        logger.debug("Starting export to directory: \(exportDirectory.path)")
        
        // Create unique directory if it doesn't exist
        let uniqueDirectory = generateUniqueDirectoryPath(exportDirectory)
        
        // Check and create directory with detailed permission checks
        try checkAndCreateDirectory(at: uniqueDirectory)
        
        // AppleScript to fetch all notes
        let scriptSource = """
        tell application "Notes"
            set noteList to every note
            set exportedNotes to {}
            repeat with aNote in noteList
                try
                    set noteTitle to name of aNote
                    set noteBody to body of aNote
                    set noteModDate to modification date of aNote
                    set end of exportedNotes to {title:(noteTitle as string), body:(noteBody as string), modDate:(noteModDate as string)}
                end try
            end repeat
            return exportedNotes
        end tell
        """
        
        var error: NSDictionary?
        let script = NSAppleScript(source: scriptSource)
        
        guard let script = script else {
            print("❌ Failed to create AppleScript")
            throw NotesExportError.fetchFailed
        }
        
        let result = script.executeAndReturnError(&error)
        if let err = error {
            print("❌ AppleScript error: \(err)")
            logger.error("AppleScript error: \(err)")
            throw NotesExportError.fetchFailed
        }
        
        // Convert AppleScript result to Swift array
        guard result.descriptorType == typeAEList else {
            print("❌ Failed to retrieve notes from AppleScript")
            throw NotesExportError.fetchFailed
        }
        
        var noteData: [[String: String]] = []
        
        // Iterate through the list and convert to Swift array
        for i in 1...result.numberOfItems {
            let recordDesc = result.atIndex(i)
            let titleDesc = recordDesc?.atIndex(1)
            let bodyDesc = recordDesc?.atIndex(2)
            let modDateDesc = recordDesc?.atIndex(3)
            
            if let title = titleDesc?.stringValue,
               let body = bodyDesc?.stringValue,
               let modDate = modDateDesc?.stringValue {
                let note = [
                    "title": title,
                    "body": body,
                    "modDate": modDate
                ]
                
                noteData.append(note)
            }
        }
        
        // Check if there are any notes
        guard !noteData.isEmpty else {
            print("❌ No notes found to export")
            throw NotesExportError.noNotes
        }
        
        // Export each note as a text file
        var exportedCount = 0
        var existingFiles = Set<String>()
        
        for note in noteData {
            guard let title = note["title"],
                  let body = note["body"],
                  let modDate = note["modDate"] else {
                continue
            }
            
            // Generate a safe filename
            var baseFilename = title
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: "\\", with: "-")
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            // Ensure filename is not empty
            if baseFilename.isEmpty {
                baseFilename = "Untitled Note"
            }
            
            var filename = baseFilename + ".txt"
            var counter = 1
            
            // Handle duplicate filenames
            while existingFiles.contains(filename) {
                filename = "\(baseFilename)_\(counter).txt"
                counter += 1
            }
            
            existingFiles.insert(filename)
            let fileURL = uniqueDirectory.appendingPathComponent(filename)
            
            // Prepare note details for export
            let noteDetails = """
            Title: \(title)
            Modified: \(modDate)

            Content:
            \(body)
            """
            
            do {
                try noteDetails.write(to: fileURL, atomically: true, encoding: .utf8)
                print("💾 Exported note: \(filename)")
                logger.debug("Exported note: \(filename)")
                exportedCount += 1
            } catch {
                print("❌ Failed to write file \(filename): \(error.localizedDescription)")
                logger.error("Failed to write file \(filename): \(error.localizedDescription)")
                // Continue with next note instead of stopping entire export
            }
        }
        
        print("✅ Export completed. Exported \(exportedCount) notes")
        logger.debug("Export completed. Exported \(exportedCount) notes")
        return exportedCount
    }
}
