//
//  TodoLocationViews.swift
//  TaskBell
//

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
            Marker("위치", coordinate: coordinate.clLocationCoordinate)
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .allowsHitTesting(false)
    }
}

struct TodoLocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCoordinate: TodoLocationCoordinate
    @State private var searchText = ""
    @State private var searchResults: [TodoLocationSearchResult] = []
    @State private var isSearching = false
    @State private var didSearch = false
    let onSelect: (TodoLocationCoordinate) -> Void

    init(
        initialCoordinate: TodoLocationCoordinate?,
        onSelect: @escaping (TodoLocationCoordinate) -> Void
    ) {
        _selectedCoordinate = State(
            initialValue: initialCoordinate
                ?? TodoLocationCoordinate(latitude: 37.5665, longitude: 126.9780)
        )
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            TappableMapView(coordinate: $selectedCoordinate)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("위치 선택")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "장소 또는 주소 검색"
                )
                .onSubmit(of: .search) {
                    Task {
                        await searchLocations()
                    }
                }
                .onChange(of: searchText) { _, newValue in
                    if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        searchResults = []
                        didSearch = false
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("선택") {
                            onSelect(selectedCoordinate)
                            dismiss()
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        searchResultList

                        Text("지도를 탭하거나 장소를 검색해서 위치를 찍으세요.")
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
            ProgressView("검색 중")
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
            Text("검색 결과가 없습니다.")
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
            region: searchRegion(around: selectedCoordinate)
        )
        request.resultTypes = [.address, .pointOfInterest]

        do {
            let response = try await MKLocalSearch(request: request).start()
            searchResults = response.mapItems.map { item in
                TodoLocationSearchResult(mapItem: item)
            }
        } catch {
            searchResults = []
        }
    }

    private func searchRegion(
        around coordinate: TodoLocationCoordinate
    ) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate.clLocationCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
    }
}

private struct TappableMapView: UIViewRepresentable {
    @Binding var coordinate: TodoLocationCoordinate

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.pointOfInterestFilter = .includingAll

        let tapRecognizer = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        mapView.addGestureRecognizer(tapRecognizer)

        mapView.setRegion(region(for: coordinate), animated: false)
        context.coordinator.refreshAnnotation(on: mapView, coordinate: coordinate)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
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
            parent.coordinate = TodoLocationCoordinate(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            refreshAnnotation(on: mapView, coordinate: parent.coordinate)
        }

        func refreshAnnotation(
            on mapView: MKMapView,
            coordinate: TodoLocationCoordinate
        ) {
            if !mapView.annotations.contains(where: { $0 === annotation }) {
                mapView.addAnnotation(annotation)
            }

            annotation.title = "선택한 위치"
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

    init(mapItem: MKMapItem) {
        title = mapItem.name ?? "이름 없는 위치"
        subtitle = mapItem.placemark.title ?? ""
        coordinate = TodoLocationCoordinate(
            latitude: mapItem.placemark.coordinate.latitude,
            longitude: mapItem.placemark.coordinate.longitude
        )
    }
}
