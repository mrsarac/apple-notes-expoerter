import Foundation

struct FilePermissions {
    let path: String
    let isReadable: Bool
    let isWritable: Bool
    let isExecutable: Bool
    let owner: String
    let group: String
    let permissions: String
    
    var description: String {
        """
        📁 Path: \(path)
        📝 Permissions: \(permissions) (\(getPermissionDescription()))
        👤 Owner: \(owner)\(owner == NSUserName() ? " (You)" : "")
        👥 Group: \(group)
        ✅ Readable: \(isReadable)
        ✅ Writable: \(isWritable)
        ✅ Executable: \(isExecutable)
        
        🔍 Troubleshooting:
        \(generateTroubleshootingInfo())
        """
    }
    
    private func getPermissionDescription() -> String {
        guard permissions.count == 3 else { return "unknown" }
        
        let chars = Array(permissions)
        var desc = ""
        
        // Owner
        desc += "u="
        desc += Int(String(chars[0]))! & 4 != 0 ? "r" : "-"
        desc += Int(String(chars[0]))! & 2 != 0 ? "w" : "-"
        desc += Int(String(chars[0]))! & 1 != 0 ? "x" : "-"
        
        // Group
        desc += ",g="
        desc += Int(String(chars[1]))! & 4 != 0 ? "r" : "-"
        desc += Int(String(chars[1]))! & 2 != 0 ? "w" : "-"
        desc += Int(String(chars[1]))! & 1 != 0 ? "x" : "-"
        
        // Others
        desc += ",o="
        desc += Int(String(chars[2]))! & 4 != 0 ? "r" : "-"
        desc += Int(String(chars[2]))! & 2 != 0 ? "w" : "-"
        desc += Int(String(chars[2]))! & 1 != 0 ? "x" : "-"
        
        return desc
    }
    
    private func generateTroubleshootingInfo() -> String {
        var info = [String]()
        
        if !isWritable {
            if owner == NSUserName() {
                info.append("- You are the owner but don't have write permission. Try: chmod u+w '\(path)'")
            } else {
                info.append("- Directory is owned by \(owner). You might need to:")
                info.append("  1. Ask \(owner) to grant you write permission")
                info.append("  2. Or use: sudo chown \(NSUserName()) '\(path)'")
            }
        }
        
        if !isReadable {
            info.append("- Read permission is missing. Try: chmod +r '\(path)'")
        }
        
        if info.isEmpty {
            info.append("- Permissions look correct but still having issues?")
            info.append("  1. Check parent directory permissions")
            info.append("  2. Verify disk mounting options")
            info.append("  3. Check for extended attributes: ls -le '\(path)'")
            info.append("  4. Ensure the directory is not locked: chflags nouchg '\(path)'")
            info.append("  5. Check for ACLs: ls -le '\(path)' and remove if necessary: chmod -N '\(path)'")
        }
        
        return info.joined(separator: "\n")
    }
}

class PermissionChecker {
    static func checkPermissions(path: String) -> FilePermissions {
        let fileManager = FileManager.default
        
        let isReadable = fileManager.isReadableFile(atPath: path)
        let isWritable = fileManager.isWritableFile(atPath: path)
        let isExecutable = fileManager.isExecutableFile(atPath: path)
        
        var owner = "Unknown"
        var group = "Unknown"
        var permissions = "Unknown"
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            owner = attributes[.ownerAccountName] as? String ?? "Unknown"
            group = attributes[.groupOwnerAccountName] as? String ?? "Unknown"
            
            if let posixPermissions = attributes[.posixPermissions] as? NSNumber {
                permissions = String(format: "%o", posixPermissions.int16Value)
            }
        } catch {
            print("❌ Error getting file attributes: \(error.localizedDescription)")
        }
        
        return FilePermissions(
            path: path,
            isReadable: isReadable,
            isWritable: isWritable,
            isExecutable: isExecutable,
            owner: owner,
            group: group,
            permissions: permissions
        )
    }
} 
