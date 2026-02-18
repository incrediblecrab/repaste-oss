//
//  repasteApp.swift
//  Repaste
//

import SwiftUI
import SwiftData
import LocalAuthentication

@main
struct RepasteApp: App {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true
    @AppStorage("biometricLockEnabled") private var biometricLockEnabled = false

    @State private var isUnlocked = false

    init() {
        AppState.updateAppearance()
        updateDockIcon()
        cleanupTempFiles()
    }

    /// Remove old drag temp files from previous sessions
    private func cleanupTempFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        // Remove files matching our pattern (UUID_filename) older than 1 hour
        let cutoff = Date().addingTimeInterval(-3600)
        for file in files {
            // Check if it's our temp file (UUID pattern at start)
            let name = file.lastPathComponent
            let uuidPattern = #"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}_"#
            guard name.range(of: uuidPattern, options: .regularExpression) != nil else { continue }

            if let created = (try? file.resourceValues(forKeys: [.creationDateKey]))?.creationDate,
               created < cutoff {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Phrase.self,
            Tag.self,
            UsageEvent.self
        ])

        let iCloudEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: iCloudEnabled ? .automatic : .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        MenuBarExtra {
            if biometricLockEnabled && !isUnlocked {
                LockedView(onUnlock: authenticate)
                    .preferredColorScheme(appearanceMode.colorScheme)
                    .onChange(of: appearanceMode) { AppState.updateAppearance() }
            } else {
                ContentView()
                    .modelContainer(sharedModelContainer)
                    .preferredColorScheme(appearanceMode.colorScheme)
                    .onChange(of: appearanceMode) { AppState.updateAppearance() }
            }
        } label: {
            Image("MenuBarIcon")
        }
        .menuBarExtraStyle(.window)

        Window("Repaste", id: "paste-editor") {
            PasteEditSheet()
                .modelContainer(sharedModelContainer)
                .preferredColorScheme(appearanceMode.colorScheme)
        }
        .windowResizability(.automatic)

        Window("Repaste: Settings", id: "settings") {
            SettingsView()
                .modelContainer(sharedModelContainer)
                .preferredColorScheme(appearanceMode.colorScheme)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)

        Window("Repaste: Tag Manager", id: "tag-manager") {
            TagManagerView()
                .modelContainer(sharedModelContainer)
                .preferredColorScheme(appearanceMode.colorScheme)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)

        Window("Repaste: Usage Stats", id: "usage-stats") {
            StatsView()
                .modelContainer(sharedModelContainer)
                .preferredColorScheme(appearanceMode.colorScheme)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)

        Window("Repaste: Pop Out", id: "floating-paste") {
            FloatingContentView()
                .modelContainer(sharedModelContainer)
                .preferredColorScheme(appearanceMode.colorScheme)
        }
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(.suppressed)

    }

    private func updateDockIcon() {
        guard let app = NSApp else { return }
        let hideDock = UserDefaults.standard.object(forKey: "hideDockIcon") as? Bool ?? false
        app.setActivationPolicy(hideDock ? .accessory : .regular)
    }

    private func authenticate() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock Repaste") { success, _ in
                DispatchQueue.main.async {
                    isUnlocked = success
                }
            }
        } else {
            isUnlocked = true
        }
    }
}

struct LockedView: View {
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Repaste is Locked")
                .font(.headline)

            Button("Unlock") {
                onUnlock()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(minWidth: 280, idealWidth: 320, minHeight: 200)
        .onAppear {
            onUnlock()
        }
    }
}
