import ComposableArchitecture
import Foundation
import SQLiteData
import SwiftUI

struct IsolatedTripDetailView: View {
    let trip: Trip
    @Binding private var externalPath: [TripRoute]
    private let resetToken: Int

    @FetchAll private var lodgingActivities: [Lodging]
    @FetchAll private var transportationActivities: [Transportation]
    @FetchAll private var activityActivities: [Activity]

    @State private var store: StoreOf<TripDetailFeature>

    init(
        trip: Trip,
        path: Binding<[TripRoute]>,
        resetToken: Int,
        store: StoreOf<TripDetailFeature>
    ) {
        self.trip = trip
        self._externalPath = path
        self.resetToken = resetToken

        let tripID = trip.id
        self._lodgingActivities = FetchAll(
            Lodging.where { $0.tripID.eq(tripID) }.order { $0.start }
        )
        self._transportationActivities = FetchAll(
            Transportation.where { $0.tripID.eq(tripID) }.order { $0.start }
        )
        self._activityActivities = FetchAll(
            Activity.where { $0.tripID.eq(tripID) }.order { $0.start }
        )

        self._store = State(initialValue: store)
    }

    private var allActivities: [ActivityWrapper] {
        let lodgingWrappers = lodgingActivities.map { ActivityWrapper($0) }
        let transportationWrappers = transportationActivities.map { ActivityWrapper($0) }
        let activityWrappers = activityActivities.map { ActivityWrapper($0) }

        return (lodgingWrappers + transportationWrappers + activityWrappers)
            .sorted { $0.tripActivity.start < $1.tripActivity.start }
    }

    var body: some View {
        Group {
            if store.needsAuthentication {
                lockScreenView
            } else {
                tripContentView
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .onChange(of: externalPath) { _, newPath in
            store.send(.externalPathChanged(newPath))
        }
        .onChange(of: resetToken) { _, newToken in
            store.send(.resetTokenChanged(newToken))
        }
        .onChange(of: store.path) { _, newPath in
            guard externalPath != newPath else { return }
            externalPath = newPath
        }
        .sheet(item: activeSheetBinding) { activeSheet in
            NavigationStack {
                switch activeSheet {
                case .addActivity:
                    AddTripActivityView.forActivity(trip: store.trip)
                case .addLodging:
                    AddTripActivityView.forLodging(trip: store.trip)
                case .addTransportation:
                    AddTripActivityView.forTransportation(trip: store.trip)
                case .editTrip:
                    EditTripView(
                        store: StoreOf<EditTripFeature>.init(initialState: EditTripFeature.State(trip: store.trip)) {
                            EditTripFeature()
                        }
                    )
                }
            }
        }
        #if os(iOS)
        .sheet(
            item: Binding(
                get: { store.sharedRecord },
                set: { _ in store.send(.shareDismissed) }
            )
        ) { sharedRecord in
            NavigationStack {
                CloudSharingView(sharedRecord: sharedRecord)
            }
        }
        #endif
        .alert(
            "Sharing Error",
            isPresented: Binding(
                get: { store.shareError != nil },
                set: { if !$0 { store.send(.shareDismissed) } }
            )
        ) {
            Button("OK") { store.send(.shareDismissed) }
        } message: {
            Text(store.shareError ?? "")
        }
        .sheet(isPresented: showingCalendarBinding) {
            TripCalendarRootView(
                store: StoreOf<CalendarFeature>.init(initialState: CalendarFeature.State(trip: store.trip)) {
                    CalendarFeature()
                }
            )
        }
        .confirmationDialog(
            "Remove Protection",
            isPresented: removeProtectionDialogBinding,
            titleVisibility: .visible
        ) {
            Button("Remove Protection", role: .destructive) {
                store.send(.removeProtectionConfirmed)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Removing protection means this trip will no longer require \(store.biometricDisplayName) authentication to access. Anyone with access to your device will be able to view trip details, activities, and attachments.")
        }
    }

    private var lockScreenView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: store.isFaceID ? "faceid" : "touchid")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("This trip is protected")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Authenticate to view trip details")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                store.send(.authenticateTapped)
            } label: {
                HStack {
                    if store.isAuthenticating {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: store.isFaceID ? "faceid" : "touchid")
                    }

                    Text("Authenticate with \(store.biometricDisplayName)")
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isAuthenticating)
            .padding(.horizontal)

            Spacer()
        }
        .background(Color.systemBackground)
        .navigationTitle(store.trip.name)
        .inlineNavigationBarTitle()
    }

    private var tripContentView: some View {
        VStack(spacing: 0) {
            if !allActivities.isEmpty {
                VStack(spacing: 12) {
                    Picker("View Mode", selection: Binding(
                        get: { store.viewMode },
                        set: { store.send(.viewModeChanged($0)) }
                    )) {
                        ForEach(TripDetailFeature.ViewMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.icon)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    TripSummaryView(trip: store.trip, activities: allActivities)
                }
                .padding(.vertical)
                .background(Color.systemGray6)
            }

            Group {
                switch store.viewMode {
                case .list:
                    listView
                case .calendar:
                    calendarView
                }
            }
        }
        .navigationTitle(store.trip.name)
        .inlineNavigationBarTitle()
        .toolbar {
            ToolbarItem(placement: .platformLeading) {
                Button {
                    store.send(.editTripTapped)
                } label: {
                    Image(systemName: "pencil")
                }
            }

            ToolbarItem(placement: .platformTrailing) {
                Menu {
                    Button {
                        store.send(.addActivityTapped)
                    } label: {
                        Label("Add Activity", systemImage: "ticket")
                    }

                    Button {
                        store.send(.addLodgingTapped)
                    } label: {
                        Label("Add Lodging", systemImage: "bed.double")
                    }

                    Button {
                        store.send(.addTransportationTapped)
                    } label: {
                        Label("Add Transportation", systemImage: "airplane")
                    }

                    Divider()

                    Button {
                        store.send(.fullCalendarTapped)
                    } label: {
                        Label("Full Calendar View", systemImage: "calendar.badge.plus")
                    }

                    Divider()

                    Button {
                        store.send(.shareTripTapped)
                    } label: {
                        if store.isPreparingShare {
                            Label("Preparing Share...", systemImage: "hourglass")
                        } else {
                            Label("Share Trip", systemImage: "person.2.badge.plus")
                        }
                    }
                    .disabled(store.isTripProtected || store.isPreparingShare)

                    Divider()

                    if store.canUseBiometrics && store.biometricAuthEnabled {
                        if store.isTripProtected && store.isLocallyAuthenticated {
                            Button {
                                store.send(.lockTripTapped)
                            } label: {
                                Label("Lock Trip Now", systemImage: "lock.fill")
                            }
                        }

                        Button {
                            store.send(.protectTapped)
                        } label: {
                            if store.isTripProtected {
                                Label("Remove Protection", systemImage: "lock.open")
                            } else {
                                Label("Protect Trip", systemImage: "lock")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private var listView: some View {
        Group {
            if allActivities.isEmpty {
                ContentUnavailableView(
                    "No Activities Yet",
                    systemImage: "calendar.badge.plus",
                    description: Text("Add transportation, lodging, or activities to get started")
                )
            } else {
                List {
                    ForEach(allActivities) { wrapper in
                        Button {
                            guard let route = TripRouteMapper.route(from: wrapper.tripActivity) else {
                                return
                            }
                            store.send(.activitySelected(route))
                        } label: {
                            ActivityRowView(wrapper: wrapper)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var calendarView: some View {
        CompactCalendarView(trip: store.trip, activities: allActivities) { activity in
            guard let route = TripRouteMapper.route(from: activity) else {
                return
            }
            store.send(.activitySelected(route))
        }
    }

    private var activeSheetBinding: Binding<TripDetailFeature.ActiveSheet?> {
        Binding(
            get: { store.activeSheet },
            set: { store.send(.activeSheetChanged($0)) }
        )
    }

    private var showingCalendarBinding: Binding<Bool> {
        Binding(
            get: { store.showingCalendarView },
            set: { store.send(.calendarPresentationChanged($0)) }
        )
    }

    private var removeProtectionDialogBinding: Binding<Bool> {
        Binding(
            get: { store.showingRemoveProtectionConfirmation },
            set: { store.send(.removeProtectionDialogChanged($0)) }
        )
    }
}
