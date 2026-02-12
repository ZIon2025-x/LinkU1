import SwiftUI
import MapKit
import CoreLocation

// MARK: - Color & Style Constants (替代原生项目的 AppColors)

private enum PickerColors {
    static let primary = Color(red: 0.0, green: 0.478, blue: 1.0)       // #007AFF
    static let primaryLight = Color(red: 0.0, green: 0.478, blue: 1.0).opacity(0.1)
    static let textPrimary = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)
    static let background = Color(UIColor.systemBackground)
    static let cardBackground = Color(UIColor.secondarySystemBackground)
    static let separator = Color(UIColor.separator)
    static let error = Color.red
}

private enum PickerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
}

private enum PickerSpacing {
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
}

// MARK: - LocationPickerView

/// 地图选点视图 — 移植自原生 iOS 项目
/// 支持搜索和拖动选点（兼容 iOS 16）
struct LocationPickerView: View {
    /// 完成回调：返回 (address, latitude, longitude)，取消返回 nil
    var onComplete: ((_ address: String, _ latitude: Double, _ longitude: Double) -> Void)?
    var onCancel: (() -> Void)?

    var initialAddress: String?
    var initialLatitude: Double?
    var initialLongitude: Double?

    @ObservedObject private var locationService = LocationService.shared
    @StateObject private var searchCompleter = LocationSearchCompleter()

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    @State private var currentAddress = ""
    @State private var isLoadingAddress = false
    @State private var isLoadingLocation = false
    @State private var locationError: String?
    @State private var searchText = ""
    @State private var showSearchResults = false
    @State private var isSelectingResult = false
    @State private var isDragging = false
    @State private var lastUpdateTime = Date()
    @State private var searchDebounceTask: DispatchWorkItem?
    @State private var waitingForInitialLocation = false
    @State private var isInitializing = false
    @State private var mapRefreshId = UUID()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                PickerColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    searchBar
                    ZStack {
                        mapView
                        centerPinView
                        mapControlButtons
                        locationButton
                        if showSearchResults && !searchCompleter.searchResults.isEmpty {
                            searchResultsList
                        }
                    }
                    bottomPanel
                }
            }
            .navigationTitle(NSLocalizedString("Select Location", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "")) {
                        onCancel?()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Confirm", comment: "")) {
                        confirmSelection()
                    }
                    .fontWeight(.semibold)
                    .disabled(currentAddress.isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.async { initializeLocation() }
            }
            .onChange(of: locationService.currentLocation) { newLocation in
                if waitingForInitialLocation, let location = newLocation {
                    waitingForInitialLocation = false
                    isLoadingLocation = false
                    let coord = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                    region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isInitializing = false
                        updateAddressForCurrentCenter()
                    }
                }
            }
            .onTapGesture {
                isSearchFocused = false
                showSearchResults = false
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(isSearchFocused ? PickerColors.primary : PickerColors.textSecondary)
                    .font(.system(size: 16, weight: .medium))

                TextField(NSLocalizedString("Search place", comment: ""), text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 15))
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { newValue in
                        searchDebounceTask?.cancel()
                        if !newValue.isEmpty {
                            let task = DispatchWorkItem {
                                searchCompleter.search(query: newValue)
                                showSearchResults = true
                            }
                            searchDebounceTask = task
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
                        } else {
                            showSearchResults = false
                            searchCompleter.searchResults = []
                        }
                    }

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        showSearchResults = false
                        searchCompleter.searchResults = []
                        isSearchFocused = false
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(PickerColors.textSecondary)
                            .font(.system(size: 18))
                    }
                }

                if searchCompleter.isSearching || isSelectingResult {
                    ProgressView().scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(PickerColors.cardBackground)
            .cornerRadius(PickerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: PickerRadius.medium)
                    .stroke(isSearchFocused ? PickerColors.primary.opacity(0.5) : PickerColors.separator.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: isSearchFocused ? PickerColors.primary.opacity(0.1) : .clear, radius: 4, x: 0, y: 2)
        }
        .padding(.horizontal, PickerSpacing.md)
        .padding(.vertical, PickerSpacing.sm)
        .background(PickerColors.background)
        .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
    }

    // MARK: - Map View

    private var mapView: some View {
        Map(coordinateRegion: $region, interactionModes: .all)
            .id(mapRefreshId)
            .onChange(of: region.center.latitude) { _ in handleRegionChange() }
            .onChange(of: region.center.longitude) { _ in handleRegionChange() }
            .gesture(
                TapGesture().onEnded { _ in
                    showSearchResults = false
                    isSearchFocused = false
                }
            )
    }

    // MARK: - Map Control Buttons

    private var mapControlButtons: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                HStack(spacing: 0) {
                    Button(action: { zoomOut() }) {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(PickerColors.textPrimary)
                            .frame(width: 32, height: 32)
                    }
                    Divider().frame(height: 20)
                    Button(action: { zoomIn() }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(PickerColors.textPrimary)
                            .frame(width: 32, height: 32)
                    }
                }
                .background(PickerColors.cardBackground.opacity(0.9))
                .cornerRadius(PickerRadius.small)
                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
            }
            .padding(.trailing, PickerSpacing.sm)
            .padding(.bottom, PickerSpacing.sm)
        }
    }

    // MARK: - Location Button

    private var locationButton: some View {
        VStack {
            Spacer()
            HStack {
                Button(action: { useCurrentLocation() }) {
                    ZStack {
                        if isLoadingLocation {
                            ProgressView().scaleEffect(0.7).tint(.white)
                        } else {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(PickerColors.primary)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .background(PickerColors.cardBackground.opacity(0.9))
                    .cornerRadius(PickerRadius.small)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                }
                .disabled(isLoadingLocation)
                Spacer()
            }
            .padding(.leading, PickerSpacing.sm)
            .padding(.bottom, PickerSpacing.sm)
        }
    }

    // MARK: - Center Pin

    private var centerPinView: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(PickerColors.primary.opacity(0.15))
                    .frame(width: 70, height: 70)
                    .scaleEffect(isDragging ? 1.4 : 1.0)
                Circle()
                    .fill(PickerColors.primary.opacity(0.25))
                    .frame(width: 50, height: 50)
                    .scaleEffect(isDragging ? 1.2 : 1.0)
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [PickerColors.primary, PickerColors.primary.opacity(0.85)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 36, height: 36)
                        Circle()
                            .fill(.white)
                            .frame(width: 14, height: 14)
                            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                    }
                    Triangle()
                        .fill(LinearGradient(colors: [PickerColors.primary, PickerColors.primary.opacity(0.9)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 18, height: 22)
                        .offset(y: -5)
                }
                .shadow(color: PickerColors.primary.opacity(0.4), radius: 6, x: 0, y: 4)
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
            }
            .offset(y: isDragging ? -18 : -10)
            Ellipse()
                .fill(RadialGradient(colors: [Color.black.opacity(isDragging ? 0.2 : 0.35), Color.clear], center: .center, startRadius: 0, endRadius: isDragging ? 12 : 16))
                .frame(width: isDragging ? 20 : 32, height: isDragging ? 6 : 10)
                .offset(y: isDragging ? 6 : 0)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isDragging)
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundColor(PickerColors.textSecondary)
                    Text(NSLocalizedString("Search Results", comment: "")).font(.system(size: 12, weight: .medium)).foregroundColor(PickerColors.textSecondary)
                    if searchCompleter.isSearching || isSelectingResult {
                        ProgressView().scaleEffect(0.6)
                    } else {
                        Text("(\(searchCompleter.searchResults.count))").font(.system(size: 11)).foregroundColor(PickerColors.textSecondary.opacity(0.7))
                    }
                }
                Spacer()
                Button(action: {
                    showSearchResults = false
                    searchText = ""
                    searchCompleter.searchResults = []
                    isSearchFocused = false
                }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundColor(PickerColors.textSecondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(PickerColors.cardBackground)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(searchCompleter.searchResults.prefix(8).enumerated()), id: \.element) { index, result in
                        Button(action: { selectSearchResult(result) }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(isUKLocation(result) ? PickerColors.primary.opacity(0.15) : PickerColors.background)
                                        .frame(width: 36, height: 36)
                                    Image(systemName: isUKLocation(result) ? "mappin.circle.fill" : "mappin.and.ellipse")
                                        .foregroundColor(isUKLocation(result) ? PickerColors.primary : PickerColors.textSecondary)
                                        .font(.system(size: 16))
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(result.title).font(.system(size: 15, weight: .medium)).foregroundColor(PickerColors.textPrimary).lineLimit(1)
                                        if isUKLocation(result) {
                                            Text("UK").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                                                .padding(.horizontal, 5).padding(.vertical, 2)
                                                .background(PickerColors.primary).cornerRadius(3)
                                        }
                                    }
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle).font(.system(size: 13)).foregroundColor(PickerColors.textSecondary).lineLimit(1)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium)).foregroundColor(PickerColors.textSecondary.opacity(0.5))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(PickerColors.cardBackground)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        if index < min(searchCompleter.searchResults.count, 8) - 1 {
                            Divider().padding(.leading, 62)
                        }
                    }
                }
            }
            .frame(maxHeight: 320)
            .background(PickerColors.cardBackground)
            .cornerRadius(PickerRadius.medium)
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal, PickerSpacing.md)
        .padding(.top, 4)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(spacing: PickerSpacing.md) {
            // Current address
            HStack(spacing: 12) {
                if isLoadingAddress {
                    ProgressView().frame(width: 28, height: 28)
                } else {
                    ZStack {
                        Circle()
                            .fill(currentAddress.isEmpty ? PickerColors.background : PickerColors.primary.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: currentAddress.isEmpty ? "mappin.slash" : "mappin.circle.fill")
                            .foregroundColor(currentAddress.isEmpty ? PickerColors.textSecondary : PickerColors.primary)
                            .font(.system(size: 20))
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    if isLoadingAddress {
                        Text(NSLocalizedString("Getting address...", comment: "")).font(.system(size: 15, weight: .medium)).foregroundColor(PickerColors.textSecondary)
                    } else if currentAddress.isEmpty {
                        Text(NSLocalizedString("Drag map to select", comment: "")).font(.system(size: 15, weight: .medium)).foregroundColor(PickerColors.textSecondary)
                    } else {
                        Text(currentAddress).font(.system(size: 15, weight: .medium)).foregroundColor(PickerColors.textPrimary).lineLimit(2)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "location").font(.system(size: 10))
                        Text(formatCoordinate(region.center)).font(.system(size: 12))
                    }.foregroundColor(PickerColors.textSecondary)
                }
                Spacer()
                if isDragging {
                    Text(NSLocalizedString("Moving...", comment: "")).font(.system(size: 11, weight: .medium)).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(PickerColors.primary).cornerRadius(PickerRadius.small)
                }
            }
            .padding(14)
            .background(PickerColors.cardBackground)
            .cornerRadius(PickerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: PickerRadius.medium)
                    .stroke(currentAddress.isEmpty ? Color.clear : PickerColors.primary.opacity(0.3), lineWidth: 1)
            )

            // UK cities
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(popularUKCities, id: \.name) { city in
                        Button(action: { selectPopularCity(city) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "building.2").font(.system(size: 11))
                                Text(city.name).font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(PickerColors.textPrimary)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(PickerColors.background)
                            .cornerRadius(PickerRadius.small)
                            .overlay(RoundedRectangle(cornerRadius: PickerRadius.small).stroke(PickerColors.separator, lineWidth: 1))
                        }
                    }
                }
            }

            // Action buttons
            HStack(spacing: 10) {
                Button(action: { useCurrentLocation() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill").font(.system(size: 14))
                        Text(NSLocalizedString("Current Location", comment: "")).font(.system(size: 13, weight: .semibold))
                        if isLoadingLocation { ProgressView().scaleEffect(0.6).tint(.white) }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient(colors: [PickerColors.primary, PickerColors.primary.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .cornerRadius(PickerRadius.medium)
                    .shadow(color: PickerColors.primary.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .disabled(isLoadingLocation)

                Button(action: { selectOnlineLocation() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "globe").font(.system(size: 14))
                        Text(NSLocalizedString("Online", comment: "")).font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(PickerColors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PickerColors.primaryLight)
                    .cornerRadius(PickerRadius.medium)
                    .overlay(RoundedRectangle(cornerRadius: PickerRadius.medium).stroke(PickerColors.primary.opacity(0.2), lineWidth: 1))
                }
            }

            // Error message
            if let error = locationError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(PickerColors.error)
                    Text(error).font(.system(size: 13)).foregroundColor(PickerColors.error)
                    Spacer()
                    Button(action: { locationError = nil }) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundColor(PickerColors.error)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(PickerColors.error.opacity(0.1)).cornerRadius(PickerRadius.small)
            }
        }
        .padding(PickerSpacing.md)
        .background(PickerColors.cardBackground.shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5))
    }

    // MARK: - Data

    private var popularUKCities: [(name: String, lat: Double, lon: Double)] {
        [
            ("London", 51.5074, -0.1278),
            ("Birmingham", 52.4862, -1.8904),
            ("Manchester", 53.4808, -2.2426),
            ("Leeds", 53.8008, -1.5491),
            ("Liverpool", 53.4084, -2.9916),
            ("Bristol", 51.4545, -2.5879),
            ("Edinburgh", 55.9533, -3.1883),
            ("Glasgow", 55.8642, -4.2518)
        ]
    }

    // MARK: - Actions

    private func handleRegionChange() {
        guard !isInitializing else { return }
        isDragging = true
        lastUpdateTime = Date()
        let captured = lastUpdateTime
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if captured == lastUpdateTime && !isInitializing {
                isDragging = false
                updateAddressForCurrentCenter()
            }
        }
    }

    private func zoomIn() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation {
            region.span = MKCoordinateSpan(
                latitudeDelta: max(region.span.latitudeDelta / 2, 0.001),
                longitudeDelta: max(region.span.longitudeDelta / 2, 0.001)
            )
        }
    }

    private func zoomOut() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation {
            region.span = MKCoordinateSpan(
                latitudeDelta: min(region.span.latitudeDelta * 2, 180),
                longitudeDelta: min(region.span.longitudeDelta * 2, 180)
            )
        }
    }

    private func formatCoordinate(_ c: CLLocationCoordinate2D) -> String {
        String(format: "%.6f, %.6f", c.latitude, c.longitude)
    }

    private func isUKLocation(_ result: MKLocalSearchCompletion) -> Bool {
        let text = (result.title + " " + result.subtitle).lowercased()
        return text.contains("uk") || text.contains("united kingdom") ||
               text.contains("england") || text.contains("scotland") ||
               text.contains("wales") || text.contains("northern ireland")
    }

    private func selectPopularCity(_ city: (name: String, lat: Double, lon: Double)) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isInitializing = true
        let coord = CLLocationCoordinate2D(latitude: city.lat, longitude: city.lon)
        withAnimation(.easeInOut(duration: 0.5)) {
            region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
        }
        currentAddress = city.name
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { mapRefreshId = UUID() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isInitializing = false
            updateAddressForCurrentCenter()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func initializeLocation() {
        isInitializing = true
        if let lat = initialLatitude, let lon = initialLongitude {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                mapRefreshId = UUID()
                region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            }
            currentAddress = initialAddress ?? ""
            if currentAddress.isEmpty || currentAddress.lowercased() == "online" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isInitializing = false
                    updateAddressForCurrentCenter()
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { isInitializing = false }
            }
        } else if let addr = initialAddress, !addr.isEmpty, addr.lowercased() != "online" {
            currentAddress = addr
            let geocoder = CLGeocoder()
            geocoder.geocodeAddressString(addr) { placemarks, _ in
                DispatchQueue.main.async {
                    if let loc = placemarks?.first?.location {
                        region = MKCoordinateRegion(center: loc.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isInitializing = false }
                }
            }
        } else {
            if !locationService.isAuthorized { locationService.requestAuthorization() }
            locationService.requestLocation()
            if let loc = locationService.currentLocation {
                let coord = CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
                region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInitializing = false
                    updateAddressForCurrentCenter()
                }
            } else {
                waitingForInitialLocation = true
                isLoadingLocation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if waitingForInitialLocation {
                        waitingForInitialLocation = false
                        isLoadingLocation = false
                        isInitializing = false
                        updateAddressForCurrentCenter()
                    }
                }
            }
        }
    }

    private func updateAddressForCurrentCenter() {
        isLoadingAddress = true
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            DispatchQueue.main.async {
                isLoadingAddress = false
                if let pm = placemarks?.first {
                    var parts: [String] = []
                    if let name = pm.name, name != pm.locality, name != pm.subLocality { parts.append(name) }
                    if let street = pm.thoroughfare { parts.append(street) }
                    if let sub = pm.subLocality { parts.append(sub) }
                    if let city = pm.locality { parts.append(city) }
                    if let postal = pm.postalCode { parts.append(postal) }
                    if parts.isEmpty, let admin = pm.administrativeArea { parts.append(admin) }
                    if parts.isEmpty, let country = pm.country { parts.append(country) }
                    currentAddress = parts.isEmpty ? "Unknown location" : parts.joined(separator: ", ")
                } else {
                    currentAddress = formatCoordinate(region.center)
                }
            }
        }
    }

    private func selectSearchResult(_ result: MKLocalSearchCompletion) {
        isSelectingResult = true
        showSearchResults = false
        isSearchFocused = false
        searchText = result.title
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isInitializing = true
        let req = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: req)
        search.start { response, _ in
            DispatchQueue.main.async {
                isSelectingResult = false
                if let item = response?.mapItems.first {
                    let coord = item.placemark.coordinate
                    let pm = item.placemark
                    withAnimation {
                        region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                    }
                    var parts: [String] = [result.title]
                    if !result.subtitle.isEmpty { parts.append(result.subtitle) }
                    if let postal = pm.postalCode, !parts.contains(postal) { parts.append(postal) }
                    currentAddress = parts.joined(separator: ", ")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { mapRefreshId = UUID() }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { isInitializing = false }
            }
        }
    }

    private func useCurrentLocation() {
        if !locationService.isAuthorized {
            locationService.requestAuthorization()
            locationError = NSLocalizedString("Location permission required", comment: "")
            return
        }
        isLoadingLocation = true
        locationError = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        locationService.requestLocation()
        if let loc = locationService.currentLocation {
            let coord = CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
            withAnimation {
                region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
            }
            updateAddressForCurrentCenter()
            isLoadingLocation = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let loc = locationService.currentLocation {
                    let coord = CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
                    withAnimation {
                        region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
                    }
                    updateAddressForCurrentCenter()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                isLoadingLocation = false
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if isLoadingLocation {
                isLoadingLocation = false
                locationError = NSLocalizedString("Location timeout, please retry", comment: "")
            }
        }
    }

    private func selectOnlineLocation() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onComplete?("Online", 0, 0)
    }

    private func confirmSelection() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if currentAddress == "Online" {
            onComplete?("Online", 0, 0)
        } else {
            onComplete?(currentAddress, region.center.latitude, region.center.longitude)
        }
    }
}

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Location Search Completer

class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchResults: [MKLocalSearchCompletion] = []
    @Published var isSearching = false

    private let completer = MKLocalSearchCompleter()

    private static let ukRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 54.0, longitude: -2.0),
        span: MKCoordinateSpan(latitudeDelta: 12.0, longitudeDelta: 10.0)
    )

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        completer.region = Self.ukRegion
    }

    func search(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        completer.queryFragment = query
    }

    func cancel() {
        completer.cancel()
        isSearching = false
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async { [weak self] in
            self?.isSearching = false
            self?.searchResults = completer.results.sorted { a, b in
                let aUK = self?.isUK(a) ?? false
                let bUK = self?.isUK(b) ?? false
                if aUK && !bUK { return true }
                if !aUK && bUK { return false }
                return false
            }
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in self?.isSearching = false }
    }

    private func isUK(_ result: MKLocalSearchCompletion) -> Bool {
        let text = (result.title + " " + result.subtitle).lowercased()
        return text.contains("uk") || text.contains("united kingdom") ||
               text.contains("england") || text.contains("scotland") ||
               text.contains("wales") || text.contains("northern ireland")
    }
}
