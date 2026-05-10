import SwiftData
import SwiftUI

@main
struct DelaydApp: App {
    private let modelContainer = Self.makeModelContainer()

    /// Read the stored theme synchronously so the very first SwiftUI frame
    /// already applies the right colour scheme — no dark-background flash in
    /// light mode (or vice-versa).
    @State private var appTheme: AppTheme = {
        let stored = UserDefaults.standard.string(forKey: AppTheme.defaultsKey) ?? ""
        return AppTheme(rawValue: stored) ?? .system
    }()

    init() {
        ProEntitlementService.configure()
        DelaydWidgetSync.bootstrapTrialIfNeeded()
        DelaydWidgetSync.syncProState(isUnlocked: ProEntitlementService.isUnlocked)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(appTheme.colorScheme)
                .task {
                    await ProEntitlementService.refreshCustomerInfo()
                    ProEntitlementService.startCustomerInfoListener()
                }
                // When SettingsViewModel calls updateTheme() it posts to
                // UserDefaults AND triggers this notification so the running
                // app reacts immediately without needing a restart.
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: .delaydThemeChanged
                    )
                ) { _ in
                    let stored = UserDefaults.standard.string(forKey: AppTheme.defaultsKey) ?? ""
                    let parsed = AppTheme(rawValue: stored) ?? .system
                    if parsed != appTheme { appTheme = parsed }
                }
        }
        .modelContainer(modelContainer)
    }

    static var previewModelContainer: ModelContainer {
        makeModelContainer(isStoredInMemoryOnly: true)
    }

    private static func makeModelContainer(isStoredInMemoryOnly: Bool = false) -> ModelContainer {
        let schema = Schema([
            Goal.self,
            DreamContribution.self,
            Expense.self,
            ImpactEvent.self,
            UserSettings.self
        ])

        if !isStoredInMemoryOnly {
            ensureApplicationSupportDirectory()
        }

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isStoredInMemoryOnly)

        // First attempt: open the store as-is.
        if let container = try? ModelContainer(
            for: schema,
            migrationPlan: DelaydMigrationPlan.self,
            configurations: [configuration]
        ) {
            return container
        }

        // The schema changed (e.g. we added `appTheme` to UserSettings) and the
        // existing on-disk store can't be opened. Until we ship a proper
        // `SchemaMigrationPlan`, the safest recovery is to wipe the legacy
        // store so the app launches with a fresh DB. SeedDataService will
        // re-populate demo content on next launch.
        if !isStoredInMemoryOnly {
            wipeLegacyStore()
        }

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: DelaydMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            fatalError("Unable to create SwiftData container: \(error)")
        }
    }

    /// Removes the SwiftData SQLite files from the Application Support
    /// directory. Called only when the existing store fails to open due to a
    /// schema mismatch; safe no-op if the files don't exist.
    private static func wipeLegacyStore() {
        let fm = FileManager.default
        guard let appSupport = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return }

        // SwiftData places the store at "default.store" (+ "-shm" and "-wal")
        // inside Application Support by default.
        let storeNames = ["default.store", "default.store-shm", "default.store-wal"]
        for name in storeNames {
            let url = appSupport.appendingPathComponent(name)
            try? fm.removeItem(at: url)
        }

        // Also reset onboarding so the user sees a coherent fresh state
        // instead of "no goals" with onboarding marked complete.
        UserDefaults.standard.removeObject(forKey: "delayd.onboarding.completed")
    }

    private static func ensureApplicationSupportDirectory() {
        let fm = FileManager.default
        _ = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        if let appGroup = fm.containerURL(forSecurityApplicationGroupIdentifier: "group.com.delayd.shared") {
            let appSupport = appGroup
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
            try? fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }
    }
}

enum DelaydSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Goal.self,
            DreamContribution.self,
            Expense.self,
            ImpactEvent.self,
            UserSettings.self
        ]
    }
}

enum DelaydMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [DelaydSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

#Preview("Delayd App Root") {
    RootView()
        .modelContainer(PreviewContainer.shared)
}
