import SwiftUI
import EventKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var exportPath: URL?
    @State private var isExporting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showingFilePicker = false
    @State private var permissionStatus: PermissionStatus = .notDetermined
    
    enum PermissionStatus {
        case notDetermined, granted, denied
    }
    
    var body: some View {
        if permissionStatus == .notDetermined {
            OnboardingView(permissionStatus: $permissionStatus)
        } else if permissionStatus == .denied {
            PermissionDeniedView()
        } else {
            mainView
        }
    }
    
    var mainView: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.and.arrow.up.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("Export Your Notes")
                .font(.title)
                .fontWeight(.bold)
            
            if let path = exportPath {
                HStack {
                    Text(path.lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Button(action: {
                        showingFilePicker = true
                    }) {
                        Text("Change")
                            .foregroundColor(.accentColor)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            } else {
                Button(action: {
                    showingFilePicker = true
                }) {
                    Label("Select Export Location", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)
            }
            
            Button(action: exportNotes) {
                if isExporting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .controlSize(.large)
                } else {
                    Text("Export Notes")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isExporting || exportPath == nil)
            .padding(.top)
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
        .onChange(of: showingFilePicker) { show in
            if show {
                let panel = NSOpenPanel()
                panel.title = "Select Export Location"
                panel.showsResizeIndicator = true
                panel.showsHiddenFiles = false
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.allowsMultipleSelection = false
                
                if panel.runModal() == .OK {
                    self.exportPath = panel.url
                }
                showingFilePicker = false
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Export Status"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func exportNotes() {
        guard let exportPath = exportPath else { return }
        
        isExporting = true
        let exporter = NotesExporter()
        
        Task {
            do {
                let exportedCount = try exporter.exportNotes(to: exportPath)
                await MainActor.run {
                    alertMessage = "Successfully exported \(exportedCount) notes!"
                    showAlert = true
                    isExporting = false
                }
            } catch NotesExportError.accessDenied {
                print("Error: Access denied to Apple Notes")
                await MainActor.run {
                    alertMessage = "Access to Apple Notes was denied. Please check your system permissions."
                    showAlert = true
                    permissionStatus = .denied
                    isExporting = false
                }
            } catch NotesExportError.noNotes {
                print("Error: No notes found")
                await MainActor.run {
                    alertMessage = "No notes found to export. Your Apple Notes might be empty."
                    showAlert = true
                    isExporting = false
                }
            } catch NotesExportError.permissionDenied(let message) {
                print("Error: Permission denied - \(message)")
                await MainActor.run {
                    alertMessage = "Permission denied: \(message)\nPlease ensure you have write permissions for the selected location, or try selecting a different export location."
                    showAlert = true
                    isExporting = false
                }
            } catch {
                print("Export error: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("Error domain: \(nsError.domain)")
                    print("Error code: \(nsError.code)")
                    print("Error user info: \(nsError.userInfo)")
                }
                await MainActor.run {
                    alertMessage = "Failed to export notes: \(error.localizedDescription)"
                    showAlert = true
                    isExporting = false
                }
            }
        }
    }
}

struct OnboardingView: View {
    @Binding var permissionStatus: ContentView.PermissionStatus
    @State private var currentStep = 0
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: onboardingSteps[currentStep].icon)
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text(onboardingSteps[currentStep].title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(onboardingSteps[currentStep].description)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: {
                requestNotesPermission()
            }) {
                Text(onboardingSteps[currentStep].buttonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
    
    private let onboardingSteps = [
        OnboardingStep(
            icon: "note.text",
            title: "Access Your Notes",
            description: "To export your notes, we need permission to access your Apple Notes.",
            buttonTitle: "Grant Access"
        )
    ]
    
    private func requestNotesPermission() {
        let eventStore = EKEventStore()
        eventStore.requestAccess(to: .reminder) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    permissionStatus = .granted
                } else {
                    permissionStatus = .denied
                }
            }
        }
    }
}

struct OnboardingStep {
    let icon: String
    let title: String
    let description: String
    let buttonTitle: String
}

struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Permission Denied")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Please enable Notes access in System Settings to use this app.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Open System Settings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders")!)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}

struct NotesDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.folder] }
    
    init() {}
    
    init(configuration: ReadConfiguration) throws {}
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: Data())
    }
}

#Preview {
    ContentView()
}
