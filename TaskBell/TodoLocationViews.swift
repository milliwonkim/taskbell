//
//  TodoLocationViews.swift
//  TaskBell
//

import Combine
import CoreLocation
import MapKit
import SwiftUI

struct TodoLocationCoordinate: Identifiable, Equatable {
    let latitude: Double
    let longitude: Double

    var id: String {
        "\(latitude),\(longitude)"
    }

    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct TodoLocationSummaryView: View {
    let coordinate: TodoLocationCoordinate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TodoLocationMapPreview(coordinate: coordinate)

            Label(
                "\(coordinate.latitude.formatted(.number.precision(.fractionLength(5)))), \(coordinate.longitude.formatted(.number.precision(.fractionLength(5))))",
                systemImage: "mappin.and.ellipse"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

struct TodoLocationMapPreview: View {
    @Environment(\.appLanguage) private var appLanguage
    let coordinate: TodoLocationCoordinate

    private var position: MapCameraPosition {
        .region(
            MKCoordinateRegion(
                center: coordinate.clLocationCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )
    }

    var body: some View {
        Map(initialPosition: position) {
            Marker(appLanguage.text(korean: "위치", english: "Location"), coordinate: coordinate.clLocationCoordinate)
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .allowsHitTesting(false)
    }
}

struct TodoLocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var appLanguage
    @StateObject private var currentLocationProvider = CurrentLocationProvider()
    @State private var selectedCoordinate: TodoLocationCoordinate?
    @State private var searchText = ""
    @State private var searchResults: [TodoLocationSearchResult] = []
    @State private var isSearching = false
    @State private var didSearch = false
    private let shouldUseCurrentLocation: Bool
    let onSelect: (TodoLocationCoordinate) -> Void

    init(
        initialCoordinate: TodoLocationCoordinate?,
        onSelect: @escaping (TodoLocationCoordinate) -> Void
    ) {
        self.shouldUseCurrentLocation = initialCoordinate == nil
        _selectedCoordinate = State(initialValue: initialCoordinate)
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            TappableMapView(
                coordinate: $selectedCoordinate,
                shouldTrackUserLocation: shouldUseCurrentLocation,
                selectedLocationTitle: appLanguage.text(korean: "선택한 위치", english: "Selected Location")
            )
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(appLanguage.text(korean: "위치 선택", english: "Select Location"))
                .navigationBarTitleDisplayMode(.inline)
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: appLanguage.text(korean: "장소 또는 주소 검색", english: "Search for a place or address")
                )
                .onSubmit(of: .search) {
                    Task {
                        await searchLocations()
                    }
                }
                .onAppear {
                    guard shouldUseCurrentLocation else {
                        return
                    }

                    currentLocationProvider.requestCurrentLocation()
                }
                .onChange(of: currentLocationProvider.coordinate) { _, coordinate in
                    guard shouldUseCurrentLocation, let coordinate else {
                        return
                    }

                    selectedCoordinate = coordinate
                }
                .onChange(of: searchText) { _, newValue in
                    if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        searchResults = []
                        didSearch = false
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(appLanguage.text(korean: "취소", english: "Cancel")) {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button(appLanguage.text(korean: "선택", english: "Select")) {
                            guard let selectedCoordinate else {
                                return
                            }

                            onSelect(selectedCoordinate)
                            dismiss()
                        }
                        .disabled(selectedCoordinate == nil)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        searchResultList

                        Text(appLanguage.text(korean: "지도를 탭하거나 장소를 검색해서 위치를 찍으세요.", english: "Tap the map or search for a place to set a location."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                    }
                    .background(.regularMaterial)
                }
        }
    }

    @ViewBuilder
    private var searchResultList: some View {
        if isSearching {
            ProgressView(appLanguage.text(korean: "검색 중", english: "Searching"))
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
        } else if !searchResults.isEmpty {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(searchResults) { result in
                        Button {
                            selectedCoordinate = result.coordinate
                            searchText = result.title
                            searchResults = []
                            didSearch = false
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(result.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        Divider()
                    }
                }
            }
            .frame(maxHeight: 220)
        } else if didSearch {
            Text(appLanguage.text(korean: "검색 결과가 없습니다.", english: "No search results."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
        }
    }

    private func searchLocations() async {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            searchResults = []
            didSearch = false
            return
        }

        isSearching = true
        didSearch = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request(
            naturalLanguageQuery: trimmedQuery,
            region: searchRegion(
                around: selectedCoordinate ?? currentLocationProvider.coordinate
            )
        )
        request.resultTypes = [.address, .pointOfInterest]

        do {
            let response = try await MKLocalSearch(request: request).start()
            searchResults = response.mapItems.map { item in
                TodoLocationSearchResult(mapItem: item, language: appLanguage)
            }
        } catch {
            searchResults = []
        }
    }

    private func searchRegion(
        around coordinate: TodoLocationCoordinate?
    ) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: (coordinate ?? defaultSearchCoordinate).clLocationCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
    }

    private var defaultSearchCoordinate: TodoLocationCoordinate {
        TodoLocationCoordinate(latitude: 37.5665, longitude: 126.9780)
    }
}

private final class CurrentLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var coordinate: TodoLocationCoordinate?

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestCurrentLocation() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse else {
            return
        }

        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }

        coordinate = TodoLocationCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        assertionFailure("Failed to fetch current location: \(error)")
    }
}

private struct TappableMapView: UIViewRepresentable {
    @Binding var coordinate: TodoLocationCoordinate?
    let shouldTrackUserLocation: Bool
    let selectedLocationTitle: String

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.pointOfInterestFilter = .includingAll
        mapView.showsUserLocation = shouldTrackUserLocation

        let tapRecognizer = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        mapView.addGestureRecognizer(tapRecognizer)

        if shouldTrackUserLocation {
            mapView.setUserTrackingMode(.follow, animated: false)
        } else if let coordinate {
            mapView.setRegion(region(for: coordinate), animated: false)
            context.coordinator.refreshAnnotation(on: mapView, coordinate: coordinate)
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self

        guard let coordinate else {
            return
        }

        mapView.setUserTrackingMode(.none, animated: false)
        context.coordinator.refreshAnnotation(on: mapView, coordinate: coordinate)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func region(for coordinate: TodoLocationCoordinate) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate.clLocationCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TappableMapView
        private let annotation = MKPointAnnotation()
        private var lastCenteredCoordinate: TodoLocationCoordinate?

        init(parent: TappableMapView) {
            self.parent = parent
            super.init()
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let mapView = recognizer.view as? MKMapView else {
                return
            }

            let point = recognizer.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            mapView.setUserTrackingMode(.none, animated: true)
            parent.coordinate = TodoLocationCoordinate(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )

            if let selectedCoordinate = parent.coordinate {
                refreshAnnotation(on: mapView, coordinate: selectedCoordinate)
            }
        }

        func refreshAnnotation(
            on mapView: MKMapView,
            coordinate: TodoLocationCoordinate
        ) {
            if !mapView.annotations.contains(where: { $0 === annotation }) {
                mapView.addAnnotation(annotation)
            }

            annotation.title = parent.selectedLocationTitle
            annotation.coordinate = coordinate.clLocationCoordinate

            if lastCenteredCoordinate != coordinate {
                mapView.setCenter(coordinate.clLocationCoordinate, animated: true)
                lastCenteredCoordinate = coordinate
            }
        }
    }
}

private struct TodoLocationSearchResult: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let coordinate: TodoLocationCoordinate

    init(mapItem: MKMapItem, language: AppLanguage) {
        title = mapItem.name ?? language.text(korean: "이름 없는 위치", english: "Unnamed Location")
        subtitle = mapItem.placemark.title ?? ""
        coordinate = TodoLocationCoordinate(
            latitude: mapItem.placemark.coordinate.latitude,
            longitude: mapItem.placemark.coordinate.longitude
        )
    }
}
