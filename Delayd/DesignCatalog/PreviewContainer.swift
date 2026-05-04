import SwiftData

enum PreviewContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            Goal.self,
            DreamContribution.self,
            Expense.self,
            ImpactEvent.self,
            UserSettings.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            SeedDataService.seed(modelContext: ModelContext(container))
            return container
        } catch {
            fatalError("Unable to create preview container: \(error)")
        }
    }()

    static var empty: ModelContainer {
        let schema = Schema([
            Goal.self,
            DreamContribution.self,
            Expense.self,
            ImpactEvent.self,
            UserSettings.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create empty preview container: \(error)")
        }
    }
}
