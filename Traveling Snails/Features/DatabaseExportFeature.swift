import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct DatabaseExportFeature {
    enum ExportFormat: String, CaseIterable, Equatable {
        case json = "JSON"
        case csv = "CSV"

        var fileExtension: String {
            switch self {
            case .json: return "json"
            case .csv: return "csv"
            }
        }
    }

    struct ExportSnapshot {
        var trips: [Trip]
        var transportation: [Transportation]
        var lodging: [Lodging]
        var activities: [Activity]
        var organizations: [Organization]
        var addresses: [Address]
        var attachments: [EmbeddedFileAttachment]
    }

    @ObservableState
    struct State: Equatable {
        var exportData = ""
        var isGenerating = false
        var exportFormat: ExportFormat = .json
        var includeAttachments = false
    }

    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case generateTapped(ExportSnapshot)
        case exportGenerated(String)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .generateTapped(let snapshot):
                state.isGenerating = true
                let format = state.exportFormat
                let includeAttachments = state.includeAttachments
                return .run { send in
                    let export = generateExport(
                        snapshot: snapshot,
                        format: format,
                        includeAttachments: includeAttachments
                    )
                    await send(.exportGenerated(export))
                }
            case .exportGenerated(let data):
                state.exportData = data
                state.isGenerating = false
                return .none
            }
        }
    }

    private func generateExport(
        snapshot: ExportSnapshot,
        format: ExportFormat,
        includeAttachments: Bool
    ) -> String {
        switch format {
        case .json:
            generateJSONExport(snapshot: snapshot, includeAttachments: includeAttachments)
        case .csv:
            generateCSVExport(snapshot: snapshot)
        }
    }

    private func generateJSONExport(snapshot: ExportSnapshot, includeAttachments: Bool) -> String {
        let payload: [String: Any] = [
            "exportInfo": [
                "version": "2.0",
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "format": "json",
                "includesAttachments": includeAttachments,
            ],
            "trips": snapshot.trips.map { ["id": $0.id.uuidString, "name": $0.name, "notes": $0.notes] },
            "organizations": snapshot.organizations.map { ["id": $0.id.uuidString, "name": $0.name] },
            "addresses": snapshot.addresses.map { ["id": $0.id.uuidString, "formattedAddress": $0.formattedAddress] },
            "attachments": includeAttachments
                ? snapshot.attachments.map { ["id": $0.id.uuidString, "fileName": $0.fileName] }
                : [],
        ]

        do {
            let json = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
            return String(data: json, encoding: .utf8) ?? "Export failed"
        } catch {
            return "Export failed"
        }
    }

    private func generateCSVExport(snapshot: ExportSnapshot) -> String {
        var csv = "Export Generated: \(Date().formatted())\n\n"
        csv += "=== TRIPS ===\n"
        csv += "ID,Name,Notes\n"
        for trip in snapshot.trips {
            csv += "\"\(trip.id)\",\"\(trip.name)\",\"\(trip.notes)\"\n"
        }
        csv += "\n=== ORGANIZATIONS ===\n"
        csv += "ID,Name\n"
        for organization in snapshot.organizations {
            csv += "\"\(organization.id)\",\"\(organization.name)\"\n"
        }
        return csv
    }
}
