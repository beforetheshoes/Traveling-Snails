//
//  ActivityEditForm.swift
//  Traveling Snails
//
//

import SQLiteData
import SwiftUI

// MARK: - Form Field Protocol

protocol FormField: Identifiable {
    var id: String { get }
    var title: String { get }
    var isRequired: Bool { get }
    var validationRules: [ValidationRule] { get }
    var sectionName: String? { get }

    func createView() -> AnyView
    func validate() -> ValidationResult
}

// MARK: - Validation

struct ValidationRule {
    let check: () -> Bool
    let errorMessage: String

    init(check: @escaping () -> Bool, errorMessage: String) {
        self.check = check
        self.errorMessage = errorMessage
    }
}

enum ValidationResult {
    case valid
    case invalid(String)

    var isValid: Bool {
        switch self {
        case .valid: return true
        case .invalid: return false
        }
    }

    var errorMessage: String? {
        switch self {
        case .valid: return nil
        case .invalid(let message): return message
        }
    }
}

// MARK: - Form Configuration

struct FormConfiguration {
    let title: String
    let saveButtonTitle: String
    let cancelButtonTitle: String
    let deleteButtonTitle: String?
    let allowsDelete: Bool
    let saveButtonColor: Color
    let deleteButtonColor: Color
    let showProgress: Bool

    init(
        title: String,
        saveButtonTitle: String = L(L10n.General.save),
        cancelButtonTitle: String = L(L10n.General.cancel),
        deleteButtonTitle: String? = L(L10n.General.delete),
        allowsDelete: Bool = false,
        saveButtonColor: Color = .blue,
        deleteButtonColor: Color = .red,
        showProgress: Bool = true
    ) {
        self.title = title
        self.saveButtonTitle = saveButtonTitle
        self.cancelButtonTitle = cancelButtonTitle
        self.deleteButtonTitle = deleteButtonTitle
        self.allowsDelete = allowsDelete
        self.saveButtonColor = saveButtonColor
        self.deleteButtonColor = deleteButtonColor
        self.showProgress = showProgress
    }
}

// MARK: - Form State

@Observable
final class FormState {
    var isLoading = false
    var validationErrors: [String: String] = [:]
    var hasUnsavedChanges = false
    var showingDeleteConfirmation = false
    var saveError: String?

    var isValid: Bool {
        validationErrors.isEmpty
    }

    var canSave: Bool {
        isValid && hasUnsavedChanges && !isLoading
    }

    func setError(for fieldId: String, message: String?) {
        if let message = message {
            validationErrors[fieldId] = message
        } else {
            validationErrors.removeValue(forKey: fieldId)
        }
    }

    func clearErrors() {
        validationErrors.removeAll()
        saveError = nil
    }

    func validateField(_ field: any FormField) {
        let result = field.validate()
        setError(for: field.id, message: result.errorMessage)
    }

    func validateAllFields(_ fields: [any FormField]) {
        for field in fields {
            validateField(field)
        }
    }
}

// MARK: - Activity Edit Form

struct ActivityEditForm: View {
    private enum RequestedAction: Equatable {
        case save
        case delete
    }

    // Configuration
    let configuration: FormConfiguration
    let fields: [any FormField]

    // State
    @State private var formState = FormState()
    @State private var requestedAction: RequestedAction?
    @Environment(\.dismiss) private var dismiss

    // Actions
    let onSave: () async throws -> Void
    let onDelete: (() async throws -> Void)?
    let onCancel: (() -> Void)?

    private var groupedFields: [String: [any FormField]] {
        Dictionary(grouping: fields) { field in
            field.sectionName ?? L(L10n.General.info)
        }
    }

    private var sectionOrder: [String] {
        var sections = Array(groupedFields.keys)

        // Put "General" or "Info" section first if it exists
        if let generalIndex = sections.firstIndex(where: { $0 == L(L10n.General.info) || $0.localizedStandardContains("general") }) {
            let general = sections.remove(at: generalIndex)
            sections.insert(general, at: 0)
        }

        return sections.sorted()
    }

    init(
        configuration: FormConfiguration,
        fields: [any FormField],
        onSave: @escaping () async throws -> Void,
        onDelete: (() async throws -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.configuration = configuration
        self.fields = fields
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(sectionOrder, id: \.self) { sectionName in
                        if let sectionFields = groupedFields[sectionName] {
                            FormSectionView(
                                title: sectionName,
                                fields: sectionFields,
                                formState: formState
                            )
                        }
                    }

                    // Delete button
                    if configuration.allowsDelete {
                        deleteButton
                    }
                }
                .padding()
            }
            .navigationTitle(configuration.title)
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .platformLeading) {
                    Button(configuration.cancelButtonTitle) {
                        handleCancel()
                    }
                    .disabled(formState.isLoading)
                }

                ToolbarItem(placement: .platformTrailing) {
                    Button(configuration.saveButtonTitle) {
                        requestedAction = .save
                    }
                    .disabled(!formState.canSave)
                    .foregroundStyle(configuration.saveButtonColor)
                }
            }
            .alert("Delete Confirmation", isPresented: $formState.showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    requestedAction = .delete
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action cannot be undone.")
            }
            .alert("Save Error", isPresented: .constant(formState.saveError != nil)) {
                Button("OK") {
                    formState.saveError = nil
                }
            } message: {
                if let error = formState.saveError {
                    Text(error)
                }
            }
            .disabled(formState.isLoading)
            .overlay {
                if formState.isLoading && configuration.showProgress {
                    LoadingOverlay()
                }
            }
        }
        .onAppear {
            validateAllFields()
        }
        .task(id: requestedAction) {
            await handleRequestedAction()
        }
        .handleLanguageChanges()
        .handleErrors()
    }

    @ViewBuilder
    private var deleteButton: some View {
        Button {
            formState.showingDeleteConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash.fill")
                Text(configuration.deleteButtonTitle ?? L(L10n.General.delete))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(configuration.deleteButtonColor.opacity(0.1))
            .foregroundStyle(configuration.deleteButtonColor)
            .clipShape(.rect(cornerRadius: 10))
        }
        .disabled(formState.isLoading)
    }

    private func handleCancel() {
        if formState.hasUnsavedChanges {
            // Could show unsaved changes alert here
        }
        onCancel?()
        dismiss()
    }

    private func handleSave() async {
        formState.isLoading = true
        formState.clearErrors()

        // Validate all fields
        formState.validateAllFields(fields)

        guard formState.isValid else {
            formState.isLoading = false
            return
        }

        do {
            try await onSave()
            Logger.shared.info("Form saved successfully", category: .ui)
            dismiss()
        } catch {
            formState.saveError = L(L10n.Save.failed)
            Logger.shared.logError(error, message: "Form save failed", category: .ui)
        }

        formState.isLoading = false
    }

    private func handleDelete() async {
        guard let onDelete = onDelete else { return }

        formState.isLoading = true

        do {
            try await onDelete()
            Logger.shared.info("Item deleted successfully", category: .ui)
            dismiss()
        } catch {
            formState.saveError = L(L10n.Delete.failed)
            Logger.shared.logError(error, message: "Delete failed", category: .ui)
        }

        formState.isLoading = false
    }

    private func validateAllFields() {
        formState.validateAllFields(fields)
    }

    @MainActor
    private func handleRequestedAction() async {
        guard let action = requestedAction else { return }
        requestedAction = nil

        switch action {
        case .save:
            await handleSave()
        case .delete:
            await handleDelete()
        }
    }
}

// MARK: - Form Section View

struct FormSectionView: View {
    let title: String
    let fields: [any FormField]
    let formState: FormState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }

            // Fields
            VStack(spacing: 12) {
                ForEach(fields, id: \.id) { field in
                    VStack(alignment: .leading, spacing: 4) {
                        // Field view
                        field.createView()

                        // Validation error
                        if let error = formState.validationErrors[field.id] {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .onChange(of: field.id) { _, _ in
                        formState.validateField(field)
                        formState.hasUnsavedChanges = true
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(.rect(cornerRadius: 12))
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)

                Text(L(L10n.General.loading))
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(24)
            .background(.regularMaterial)
            .clipShape(.rect(cornerRadius: 16))
        }
    }
}

// MARK: - Common Form Fields

struct TextFormField: FormField {
    let id: String
    let title: String
    let isRequired: Bool
    let sectionName: String?
    let placeholder: String
    @Binding var text: String
    let validationRules: [ValidationRule]
    let keyboardType: UIKeyboardType
    let multiline: Bool

    init(
        id: String,
        title: String,
        text: Binding<String>,
        placeholder: String = "",
        isRequired: Bool = false,
        sectionName: String? = nil,
        keyboardType: UIKeyboardType = .default,
        multiline: Bool = false,
        customValidation: [ValidationRule] = []
    ) {
        self.id = id
        self.title = title
        self.isRequired = isRequired
        self.sectionName = sectionName
        self.placeholder = placeholder
        self._text = text
        self.keyboardType = keyboardType
        self.multiline = multiline

        var rules = customValidation
        if isRequired {
            rules.append(ValidationRule(
                check: { !text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                errorMessage: L(L10n.Validation.required, title)
            ))
        }
        self.validationRules = rules
    }

    func createView() -> AnyView {
        AnyView.init(
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isRequired {
                        Text("*")
                            .foregroundStyle(.red)
                    }
                }

                if multiline {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                        .platformKeyboardType(keyboardType)
                } else {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(.roundedBorder)
                        .platformKeyboardType(keyboardType)
                }
            }
        )
    }

    func validate() -> ValidationResult {
        for rule in validationRules {
            if !rule.check() {
                return .invalid(rule.errorMessage)
            }
        }
        return .valid
    }
}

struct DecimalFormField: FormField {
    let id: String
    let title: String
    let isRequired: Bool
    let sectionName: String?
    @Binding var value: Decimal
    let validationRules: [ValidationRule]
    let currencyCode: String?

    init(
        id: String,
        title: String,
        value: Binding<Decimal>,
        isRequired: Bool = false,
        sectionName: String? = nil,
        currencyCode: String? = nil,
        customValidation: [ValidationRule] = []
    ) {
        self.id = id
        self.title = title
        self.isRequired = isRequired
        self.sectionName = sectionName
        self._value = value
        self.currencyCode = currencyCode
        self.validationRules = customValidation
    }

    func createView() -> AnyView {
        AnyView.init(
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isRequired {
                        Text("*")
                            .foregroundStyle(.red)
                    }
                }

                HStack {
                    if let currencyCode = currencyCode {
                        Text(currencyCode)
                            .foregroundStyle(.secondary)
                    }

                    TextField("0.00", value: $value, format: .number.precision(.fractionLength(2)))
                        .textFieldStyle(.roundedBorder)
                        .platformKeyboardType(.decimalPad)
                }
            }
        )
    }

    func validate() -> ValidationResult {
        for rule in validationRules {
            if !rule.check() {
                return .invalid(rule.errorMessage)
            }
        }
        return .valid
    }
}

struct DateFormField: FormField {
    let id: String
    let title: String
    let isRequired: Bool
    let sectionName: String?
    @Binding var date: Date
    let validationRules: [ValidationRule]
    let displayComponents: DatePickerComponents

    init(
        id: String,
        title: String,
        date: Binding<Date>,
        isRequired: Bool = false,
        sectionName: String? = nil,
        displayComponents: DatePickerComponents = [.date, .hourAndMinute],
        customValidation: [ValidationRule] = []
    ) {
        self.id = id
        self.title = title
        self.isRequired = isRequired
        self.sectionName = sectionName
        self._date = date
        self.displayComponents = displayComponents
        self.validationRules = customValidation
    }

    func createView() -> AnyView {
        AnyView.init(
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isRequired {
                        Text("*")
                            .foregroundStyle(.red)
                    }
                }

                DatePicker("", selection: $date, displayedComponents: displayComponents)
                    .labelsHidden()
            }
        )
    }

    func validate() -> ValidationResult {
        for rule in validationRules {
            if !rule.check() {
                return .invalid(rule.errorMessage)
            }
        }
        return .valid
    }
}

// MARK: - Form Builder Extensions

// MARK: - Custom Field Types

struct PickerFormField<T: Hashable & CaseIterable & RawRepresentable>: FormField where T.RawValue == String {
    let id: String
    let title: String
    let isRequired: Bool
    let sectionName: String?
    @Binding var selection: T
    let validationRules: [ValidationRule]

    init(
        id: String,
        title: String,
        selection: Binding<T>,
        isRequired: Bool = false,
        sectionName: String? = nil,
        customValidation: [ValidationRule] = []
    ) {
        self.id = id
        self.title = title
        self.isRequired = isRequired
        self.sectionName = sectionName
        self._selection = selection
        self.validationRules = customValidation
    }

    func createView() -> AnyView {
        AnyView.init(
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isRequired {
                        Text("*")
                            .foregroundStyle(.red)
                    }
                }

                Picker(title, selection: $selection) {
                    ForEach(Array(T.allCases), id: \.self) { option in
                        Text(option.rawValue.capitalized).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
        )
    }

    func validate() -> ValidationResult {
        for rule in validationRules {
            if !rule.check() {
                return .invalid(rule.errorMessage)
            }
        }
        return .valid
    }
}

struct ToggleFormField: FormField {
    let id: String
    let title: String
    let isRequired: Bool
    let sectionName: String?
    @Binding var isOn: Bool
    let validationRules: [ValidationRule]
    let subtitle: String?

    init(
        id: String,
        title: String,
        isOn: Binding<Bool>,
        subtitle: String? = nil,
        isRequired: Bool = false,
        sectionName: String? = nil,
        customValidation: [ValidationRule] = []
    ) {
        self.id = id
        self.title = title
        self.isRequired = isRequired
        self.sectionName = sectionName
        self._isOn = isOn
        self.subtitle = subtitle
        self.validationRules = customValidation
    }

    func createView() -> AnyView {
        AnyView.init(
            Toggle(isOn: $isOn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        )
    }

    func validate() -> ValidationResult {
        for rule in validationRules {
            if !rule.check() {
                return .invalid(rule.errorMessage)
            }
        }
        return .valid
    }
}
