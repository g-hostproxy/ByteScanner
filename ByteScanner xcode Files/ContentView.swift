import SwiftUI

// --- CYBERPUNK THEME COLOR SYSTEM ---
enum ThemeColor: String, CaseIterable, Identifiable {
    case green = "Green"
    case purple = "Purple"
    case teal = "Teal"
    case pink = "Pink"

    var id: String { rawValue }

    var primary: Color {
        switch self {
        case .green: return Color(red: 0.0, green: 1.0, blue: 0.4)
        case .purple: return Color(red: 0.75, green: 0.25, blue: 1.0)
        case .teal: return Color(red: 0.0, green: 0.85, blue: 1.0)
        case .pink: return Color(red: 1.0, green: 0.2, blue: 0.65)
        }
    }

    var dim: Color {
        switch self {
        case .green: return Color(red: 0.0, green: 0.35, blue: 0.14)
        case .purple: return Color(red: 0.3, green: 0.1, blue: 0.4)
        case .teal: return Color(red: 0.0, green: 0.3, blue: 0.38)
        case .pink: return Color(red: 0.4, green: 0.08, blue: 0.25)
        }
    }
}

extension ScanMode {
    var iconName: String {
        switch self {
        case .closestDevice: return "scope"
        case .allDevices: return "antenna.radiowaves.left.and.right"
        case .categories: return "square.grid.2x2.fill"
        case .airTags: return "tag.fill"
        case .unknownNodes: return "questionmark.square.dashed"
        }
    }

    var shortTitle: String {
        switch self {
        case .closestDevice: return "[ CLOSEST SCAN ]"
        case .allDevices: return "[ ALL DEVICES ]"
        case .categories: return "[ CATEGORIES ]"
        case .airTags: return "[ AIRTAGS ]"
        case .unknownNodes: return "[ UNKNOWN ]"
        }
    }
}

extension Color {
    static let darkBg = Color(red: 0.05, green: 0.05, blue: 0.07)
}

// --- REFINED IMPERIAL DISTANCE CALCULATIONS ---
extension DiscoveredDevice {
    var smoothedRSSI: Double {
        guard !rssiHistory.isEmpty else { return Double(rssi) }
        let recentSamples = rssiHistory.suffix(5)
        let sum = recentSamples.reduce(0, +)
        return Double(sum) / Double(recentSamples.count)
    }

    var rawDistanceFeet: Double {
        if !isOnline { return 999.0 }
        let referenceTx = txPowerLevel != nil ? Double(txPowerLevel!) : -59.0
        let pathLossExponent = 2.8
        let ratio = (referenceTx - smoothedRSSI) / (10.0 * pathLossExponent)
        let distanceMeters = pow(10.0, ratio)
        return distanceMeters * 3.28084
    }

    var estimatedDistanceRange: String {
        if !isOnline { return "OUT OF RANGE" }
        let feet = rawDistanceFeet
        switch feet {
        case 0..<3.0:
            return "1 - 3 FEET (IMMEDIATE)"
        case 3.0..<6.0:
            return "3 - 6 FEET (VERY CLOSE)"
        case 6.0..<12.0:
            return "6 - 12 FEET (SAME ROOM)"
        case 12.0..<20.0:
            return "12 - 20 FEET (NEARBY ROOM)"
        default:
            return "20+ FEET (FAR / FRINGE)"
        }
    }

    var signalPercentage: Int {
        if !isOnline { return 0 }
        let avgRssi = Int(smoothedRSSI)
        if avgRssi <= -100 { return 0 }
        if avgRssi >= -50 { return 100 }
        return Int((Double(avgRssi + 100) / 50.0) * 100.0)
    }

    var proximityBand: String {
        if !isOnline { return "DISCONNECTED" }
        switch Int(smoothedRSSI) {
        case -60...0: return "IMMEDIATE"
        case -75..<(-60): return "NEAR"
        case -90..<(-75): return "FAR"
        default: return "VERY FAR / FRINGE"
        }
    }
}

// --- SUBTLE BOTTOM MATRIX DIGITAL RAIN VIEW ---
struct BottomMatrixRainView: View {
    let themeColor: Color
    let isEnabled: Bool

    private struct Column: Identifiable {
        let id = UUID()
        var xRatio: CGFloat
        var speed: CGFloat
        var characters: [String]
    }

    @State private var columns: [Column] = []

    var body: some View {
        if isEnabled {
            VStack {
                Spacer()
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        let font = Font.system(size: 10, weight: .bold, design: .monospaced)
                        
                        for col in columns {
                            let x = col.xRatio * size.width
                            let totalHeight = size.height
                            let yOffset = (CGFloat(time) * col.speed).truncatingRemainder(dividingBy: totalHeight + 80)
                            
                            for (charIdx, char) in col.characters.enumerated() {
                                let y = (yOffset + CGFloat(charIdx * 14)).truncatingRemainder(dividingBy: totalHeight + 80) - 20
                                let alpha = Double(y / totalHeight) * (charIdx == 0 ? 0.75 : 0.25)
                                
                                if alpha > 0 {
                                    context.opacity = alpha
                                    context.draw(
                                        Text(char).font(font).foregroundColor(charIdx == 0 ? .white : themeColor),
                                        at: CGPoint(x: x, y: y)
                                    )
                                }
                            }
                        }
                    }
                }
                .frame(height: 200)
                .mask(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.8), .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()
            .onAppear {
                setupColumns()
            }
        }
    }

    private func setupColumns() {
        let glyphs = ["0", "1", "X", "F", "9", "A", "C", "7", "E", "3", ">", "_", "B", "L", "E"]
        columns = (0..<18).map { _ in
            Column(
                xRatio: CGFloat.random(in: 0.02...0.98),
                speed: CGFloat.random(in: 20...45),
                characters: (0..<7).map { _ in glyphs.randomElement()! }
            )
        }
    }
}

// --- BOTTOM AMBIENT ANIMATED GLOW GRADIENT ---
struct BottomAmbientGlowView: View {
    let themeColor: Color
    let isEnabled: Bool
    @State private var pulse: Bool = false

    var body: some View {
        VStack {
            Spacer()
            LinearGradient(
                colors: [
                    themeColor.opacity(pulse && isEnabled ? 0.35 : 0.18),
                    themeColor.opacity(pulse && isEnabled ? 0.12 : 0.05),
                    Color.clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 180)
            .blur(radius: 20)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .onAppear {
            if isEnabled {
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    pulse.toggle()
                }
            }
        }
    }
}

// --- FLOWING GLOW BORDER ANIMATION ---
struct FlowingGlowBorderView: View {
    let color: Color
    let isEnabled: Bool
    @State private var rotation: Double = 0

    var body: some View {
        GeometryReader { _ in
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            color,
                            color.opacity(0.2),
                            color,
                            color.opacity(0.2),
                            color
                        ]),
                        center: .center,
                        startAngle: .degrees(rotation),
                        endAngle: .degrees(rotation + 360)
                    ),
                    lineWidth: 2
                )
                .shadow(color: color.opacity(isEnabled ? 0.8 : 0.2), radius: isEnabled ? 8 : 2)
        }
        .onAppear {
            if isEnabled {
                withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
        }
    }
}

// --- NEON GLOW MODIFIER ---
struct NeonGlowModifier: ViewModifier {
    var color: Color
    var radius: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .foregroundColor(color)
            .shadow(color: color.opacity(0.8), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(0.4), radius: radius * 2, x: 0, y: 0)
    }
}

extension View {
    func neonGlow(color: Color, radius: CGFloat = 8) -> some View {
        self.modifier(NeonGlowModifier(color: color, radius: radius))
    }
}

// --- FLOATING BACKGROUND PARTICLES ---
struct FloatingParticlesView: View {
    let themeColor: Color

    private struct Particle: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let opacity: Double
        let speed: Double
    }

    @State private var particles: [Particle] = (0..<24).map { _ in
        Particle(
            x: CGFloat.random(in: 0...1),
            y: CGFloat.random(in: 0...1),
            size: CGFloat.random(in: 2...4),
            opacity: Double.random(in: 0.15...0.45),
            speed: Double.random(in: 8...20)
        )
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for particle in particles {
                    let yOffset = (now * particle.speed).truncatingRemainder(dividingBy: size.height + 20)
                    let currentY = (particle.y * size.height - yOffset + size.height + 20).truncatingRemainder(dividingBy: size.height + 20)
                    let currentX = particle.x * size.width

                    let rect = CGRect(x: currentX, y: currentY, width: particle.size, height: particle.size)
                    context.opacity = particle.opacity
                    context.fill(Path(ellipseIn: rect), with: .color(themeColor))
                }
            }
        }
        .ignoresSafeArea()
    }
}

// --- BRIGHTENED MODERN MODE BUTTON CARD ---
struct ModeCardView: View {
    let mode: ScanMode
    let isSelected: Bool
    let deviceCount: Int
    let theme: ThemeColor
    let animationsEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(theme.primary.opacity(isSelected ? 0.35 : 0.2))
                            .frame(width: 36, height: 36)

                        Image(systemName: mode.iconName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(theme.primary)
                            .neonGlow(color: theme.primary, radius: animationsEnabled ? (isSelected ? 8 : 4) : 0)
                    }

                    Spacer()

                    Text("[\(deviceCount)]")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(theme.primary.opacity(isSelected ? 0.35 : 0.18))
                        )
                        .foregroundColor(theme.primary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(theme.primary.opacity(0.5), lineWidth: 1)
                        )
                }

                Text(mode.shortTitle)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.black)
                    .tracking(1.0)
                    .foregroundColor(.white)
                    .neonGlow(color: isSelected ? theme.primary : .clear, radius: 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.65))

                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.primary.opacity(isSelected ? 0.30 : 0.14),
                                    theme.primary.opacity(isSelected ? 0.15 : 0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                FlowingGlowBorderView(color: theme.primary, isEnabled: animationsEnabled && isSelected)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        LinearGradient(
                            colors: [
                                theme.primary.opacity(isSelected ? 0.9 : 0.45),
                                theme.primary.opacity(isSelected ? 0.5 : 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: theme.primary.opacity(animationsEnabled ? (isSelected ? 0.5 : 0.2) : 0), radius: isSelected ? 10 : 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// --- MAIN CONTENT VIEW ---
struct ContentView: View {
    @StateObject private var engine = ScannerEngine()
    @AppStorage("selectedTheme") private var selectedTheme: ThemeColor = .green
    @AppStorage("watchlistUUIDs") private var watchlistUUIDsData: Data = Data()
    @AppStorage("animationsEnabled") private var animationsEnabled: Bool = true
    
    @State private var activeMode: ScanMode? = nil
    @State private var showSettings = false
    @State private var selectedDevice: DiscoveredDevice? = nil
    @State private var foxhuntTarget: DiscoveredDevice? = nil
    @State private var gattAuditTarget: DiscoveredDevice? = nil

    private var watchlistSet: Set<String> {
        (try? JSONDecoder().decode(Set<String>.self, from: watchlistUUIDsData)) ?? []
    }

    private func toggleWatchlist(uuid: String) {
        var current = watchlistSet
        if current.contains(uuid) {
            current.remove(uuid)
        } else {
            current.insert(uuid)
        }
        if let data = try? JSONEncoder().encode(current) {
            watchlistUUIDsData = data
        }
    }

    private func deviceCount(for mode: ScanMode) -> Int {
        switch mode {
        case .closestDevice:
            return engine.sortedDevices.filter { $0.isOnline && !$0.isUnknownNode }.isEmpty ? 0 : 1
        case .allDevices, .categories:
            return engine.sortedDevices.filter { !$0.isUnknownNode }.count
        case .airTags:
            return engine.sortedDevices.filter { $0.category == .airTag }.count
        case .unknownNodes:
            return engine.sortedDevices.filter { $0.isUnknownNode }.count
        }
    }

    var filteredDevices: [DiscoveredDevice] {
        guard let mode = activeMode else { return [] }
        switch mode {
        case .closestDevice:
            let online = engine.sortedDevices.filter { $0.isOnline && !$0.isUnknownNode }
            return Array(online.prefix(1))
        case .allDevices, .categories:
            return engine.sortedDevices.filter { !$0.isUnknownNode }
        case .airTags:
            return engine.sortedDevices.filter { $0.category == .airTag }
        case .unknownNodes:
            return engine.sortedDevices.filter { $0.isUnknownNode }
        }
    }

    var body: some View {
        ZStack {
            Color.darkBg.ignoresSafeArea()

            // Background Grid Pattern
            GeometryReader { geo in
                Path { path in
                    let step: CGFloat = 40
                    for x in stride(from: 0, to: geo.size.width, by: step) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                    for y in stride(from: 0, to: geo.size.height, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                .stroke(selectedTheme.primary.opacity(0.04), lineWidth: 1)
            }
            .ignoresSafeArea()

            if animationsEnabled {
                FloatingParticlesView(themeColor: selectedTheme.primary)
            }

            // Bottom Matrix Digital Rain Layer
            BottomMatrixRainView(themeColor: selectedTheme.primary, isEnabled: animationsEnabled)

            // Bottom Ambient Glow Accent
            BottomAmbientGlowView(themeColor: selectedTheme.primary, isEnabled: animationsEnabled)

            VStack(spacing: 16) {
                // Header Bar with Hacker Digital Font Styling
                HStack {
                    if activeMode != nil {
                        Button(action: {
                            if animationsEnabled {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    activeMode = nil
                                }
                            } else {
                                activeMode = nil
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("HUBS")
                            }
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(selectedTheme.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(selectedTheme.primary.opacity(0.4), lineWidth: 1)
                                    .background(Color.darkBg.opacity(0.8))
                            )
                        }
                    } else {
                        Spacer().frame(width: 40)
                    }

                    Spacer()

                    VStack(spacing: 4) {
                        Text(">_ BLE.SCANNER //")
                            .font(.system(.title2, design: .monospaced))
                            .fontWeight(.black)
                            .tracking(2.0)
                            .neonGlow(color: selectedTheme.primary, radius: animationsEnabled ? 8 : 0)

                        Text("SYS_MONITOR :: FREQ_802.15.1")
                            .font(.system(.caption2, design: .monospaced))
                            .tracking(1.0)
                            .foregroundColor(selectedTheme.primary.opacity(0.8))
                    }

                    Spacer()

                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .bold))
                            .neonGlow(color: selectedTheme.primary, radius: animationsEnabled ? 4 : 0)
                            .padding(10)
                            .background(
                                Circle()
                                    .stroke(selectedTheme.primary.opacity(0.4), lineWidth: 1)
                                    .background(Color.darkBg.opacity(0.8))
                                    .clipShape(Circle())
                            )
                    }
                    .frame(width: 40)
                }
                .padding(.horizontal)
                .padding(.top)

                // BLE SPAM ALERT BANNER
                if engine.isSpamDetected {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ANOMALY ALERT")
                                .font(.system(.caption2, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                            
                            Text(engine.spamWarningMessage)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        
                        Text("\(engine.packetsPerSecond) P/S")
                            .font(.system(.footnote, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                    .padding(10)
                    .background(Color.red.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.red, lineWidth: 1.5)
                    )
                    .cornerRadius(6)
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // MAIN SENSOR HUB MODE CARDS (VISIBLE ONLY ON HOME STATE)
                if activeMode == nil {
                    VStack(spacing: 12) {
                        // Prominent Full-Width Closest Device Feature Card
                        ModeCardView(
                            mode: .closestDevice,
                            isSelected: false,
                            deviceCount: deviceCount(for: .closestDevice),
                            theme: selectedTheme,
                            animationsEnabled: animationsEnabled
                        ) {
                            selectMode(.closestDevice)
                        }

                        // 2x2 Grid for Other Modes
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(ScanMode.allCases.filter { $0 != .closestDevice }) { mode in
                                ModeCardView(
                                    mode: mode,
                                    isSelected: false,
                                    deviceCount: deviceCount(for: mode),
                                    theme: selectedTheme,
                                    animationsEnabled: animationsEnabled
                                ) {
                                    selectMode(mode)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))

                    Spacer()

                    // BRIGHTENED SYSTEM PROMPT
                    Text("[ SELECT SENSOR HUB MODE ABOVE ]")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(selectedTheme.primary)
                        .neonGlow(color: selectedTheme.primary, radius: animationsEnabled ? 4 : 0)

                    Spacer()
                } else {
                    // ISOLATED CATEGORY VIEW HEADER & DEVICE LIST
                    HStack {
                        Image(systemName: activeMode!.iconName)
                            .foregroundColor(selectedTheme.primary)
                        Text(activeMode!.shortTitle)
                            .font(.system(.headline, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(selectedTheme.primary)
                            .neonGlow(color: selectedTheme.primary, radius: 2)

                        Spacer()

                        Text("TOTAL: \(filteredDevices.count)")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(selectedTheme.primary)
                    }
                    .padding(.horizontal)

                    ScrollView {
                        VStack(spacing: 12) {
                            if filteredDevices.isEmpty {
                                VStack(spacing: 8) {
                                    Text(engine.isScanning ? "[ SCANNING SIGNALS... ]" : "[ STANDBY - TAP REFRESH ]")
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.bold)
                                        .foregroundColor(selectedTheme.primary)
                                        .neonGlow(color: selectedTheme.primary, radius: engine.isScanning && animationsEnabled ? 4 : 0)
                                }
                                .padding(.top, 40)
                            } else if activeMode == .categories {
                                let watchlistedDevices = filteredDevices.filter { watchlistSet.contains($0.uuid) }
                                if !watchlistedDevices.isEmpty {
                                    CategoryGroupView(
                                        category: .watchlist,
                                        devices: watchlistedDevices,
                                        theme: selectedTheme,
                                        watchlistSet: watchlistSet,
                                        onToggleWatchlist: toggleWatchlist,
                                        onSelectDevice: { device in selectedDevice = device }
                                    )
                                }

                                ForEach(DeviceCategory.allCases.filter { $0 != .watchlist }) { category in
                                    let categoryDevices = filteredDevices.filter { $0.category == category }
                                    if !categoryDevices.isEmpty {
                                        CategoryGroupView(
                                            category: category,
                                            devices: categoryDevices,
                                            theme: selectedTheme,
                                            watchlistSet: watchlistSet,
                                            onToggleWatchlist: toggleWatchlist,
                                            onSelectDevice: { device in selectedDevice = device }
                                        )
                                    }
                                }
                            } else {
                                ForEach(filteredDevices) { device in
                                    DeviceRowView(
                                        device: device,
                                        theme: selectedTheme,
                                        isBookmarked: watchlistSet.contains(device.uuid),
                                        onToggleBookmark: { toggleWatchlist(uuid: device.uuid) }
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if device.isOnline {
                                            selectedDevice = device
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Action Switch Button (Refresh Scan Trigger)
                VStack {
                    Button(action: {
                        engine.refreshScan()
                    }) {
                        HStack {
                            if engine.isScanning {
                                ProgressView()
                                    .tint(selectedTheme.primary)
                                    .padding(.trailing, 4)
                                Text(">_ SCANNING SIGNALS...")
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text(">_ REFRESH SCAN")
                            }
                        }
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .tracking(1.0)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(selectedTheme.primary, lineWidth: 2)
                                .background(engine.isScanning ? selectedTheme.primary.opacity(0.15) : Color.clear)
                        )
                        .foregroundColor(selectedTheme.primary)
                        .neonGlow(color: selectedTheme.primary, radius: animationsEnabled ? 6 : 0)
                    }
                    .disabled(engine.isScanning)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(selectedTheme: $selectedTheme, animationsEnabled: $animationsEnabled)
        }
        .sheet(item: $selectedDevice) { device in
            DeviceDetailView(
                device: device,
                theme: selectedTheme,
                isBookmarked: watchlistSet.contains(device.uuid),
                onToggleBookmark: { toggleWatchlist(uuid: device.uuid) },
                onStartFoxhunt: { target in
                    selectedDevice = nil
                    engine.startFoxhunt(for: target)
                    foxhuntTarget = target
                },
                onStartGATT: { target in
                    selectedDevice = nil
                    engine.auditGATT(for: target)
                    gattAuditTarget = target
                }
            )
        }
        .sheet(item: $foxhuntTarget) { device in
            FoxhuntView(
                engine: engine,
                theme: selectedTheme,
                onClose: {
                    engine.stopFoxhunt()
                    foxhuntTarget = nil
                }
            )
        }
        .sheet(item: $gattAuditTarget) { device in
            GATTInspectView(
                engine: engine,
                device: device,
                theme: selectedTheme,
                onClose: {
                    engine.disconnectGATT()
                    gattAuditTarget = nil
                }
            )
        }
    }

    private func selectMode(_ mode: ScanMode) {
        if animationsEnabled {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                activeMode = mode
            }
        } else {
            activeMode = mode
        }
    }
}

// --- CATEGORY GROUP ACCORDION ---
struct CategoryGroupView: View {
    let category: DeviceCategory
    let devices: [DiscoveredDevice]
    let theme: ThemeColor
    let watchlistSet: Set<String>
    let onToggleWatchlist: (String) -> Void
    let onSelectDevice: (DiscoveredDevice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.iconName)
                    .foregroundColor(theme.primary)
                Text("[ \(category.rawValue.uppercased()) ]")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(theme.primary)
                    .neonGlow(color: theme.primary, radius: 2)

                Spacer()

                Text("COUNT: \(devices.count)")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(theme.primary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(devices) { device in
                    DeviceRowView(
                        device: device,
                        theme: theme,
                        isBookmarked: watchlistSet.contains(device.uuid),
                        onToggleBookmark: { onToggleWatchlist(device.uuid) }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if device.isOnline {
                            onSelectDevice(device)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .stroke(theme.primary.opacity(0.35), lineWidth: 1)
                .background(Color.black.opacity(0.3))
        )
    }
}

// --- DEVICE ROW VIEW WITH BRIGHTENED DBM NUMBERS ---
struct DeviceRowView: View {
    let device: DiscoveredDevice
    let theme: ThemeColor
    let isBookmarked: Bool
    let onToggleBookmark: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(device.name)
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(device.isOnline ? theme.primary : .gray)
                    .neonGlow(color: device.isOnline ? theme.primary : .clear, radius: 3)

                Spacer()

                Button(action: onToggleBookmark) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.subheadline)
                        .foregroundColor(isBookmarked ? theme.primary : theme.primary.opacity(0.4))
                }

                if device.isOnline {
                    Text("\(device.rssi) dBm")
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.heavy)
                        .foregroundColor(.white)
                        .neonGlow(color: theme.primary, radius: 4)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(theme.primary.opacity(0.25))
                        )
                } else {
                    Text("[ OUT OF RANGE ]")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
            }

            HStack {
                Text("SIG: \(device.uuid)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(device.isOnline ? theme.primary.opacity(0.8) : .gray.opacity(0.6))
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 4) {
                    Text(device.timestamp)
                    if device.isOnline {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(device.isOnline ? theme.primary.opacity(0.8) : .gray.opacity(0.6))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 4)
                .stroke(device.isOnline ? theme.primary.opacity(0.35) : Color.gray.opacity(0.2), lineWidth: 1)
                .background(device.isOnline ? Color.darkBg.opacity(0.6) : Color.black.opacity(0.8))
        )
        .opacity(device.isOnline ? 1.0 : 0.55)
    }
}

// --- DETAILED SIGNAL ANALYZER MODAL ---
struct DeviceDetailView: View {
    let device: DiscoveredDevice
    let theme: ThemeColor
    let isBookmarked: Bool
    let onToggleBookmark: () -> Void
    let onStartFoxhunt: (DiscoveredDevice) -> Void
    let onStartGATT: (DiscoveredDevice) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(">_ SIGNAL_ANALYZER_v2.0")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(theme.primary.opacity(0.8))
                            Text(device.name)
                                .font(.system(.title3, design: .monospaced))
                                .fontWeight(.bold)
                                .neonGlow(color: theme.primary)
                        }

                        Spacer()

                        Button(action: onToggleBookmark) {
                            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                                .font(.title3)
                                .foregroundColor(theme.primary)
                                .padding(8)
                        }

                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(theme.primary)
                                .padding(8)
                                .background(
                                    Circle()
                                        .stroke(theme.primary.opacity(0.4), lineWidth: 1)
                                )
                        }
                    }

                    Divider().overlay(theme.primary.opacity(0.3))

                    // Live Spectrum Graph
                    VStack(alignment: .leading, spacing: 6) {
                        Text("LIVE RSSI SPECTRUM GRAPH")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(theme.primary.opacity(0.8))

                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black.opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(theme.primary.opacity(0.3), lineWidth: 1)
                                )

                            if device.rssiHistory.count > 1 {
                                GeometryReader { geo in
                                    Path { path in
                                        let minRssi: CGFloat = -100
                                        let maxRssi: CGFloat = -40
                                        let stepX = geo.size.width / CGFloat(device.rssiHistory.count - 1)

                                        for (index, rssiVal) in device.rssiHistory.enumerated() {
                                            let clamped = max(minRssi, min(maxRssi, CGFloat(rssiVal)))
                                            let normY = (clamped - minRssi) / (maxRssi - minRssi)
                                            let yPoint = geo.size.height - (normY * geo.size.height)
                                            let xPoint = CGFloat(index) * stepX

                                            if index == 0 {
                                                path.move(to: CGPoint(x: xPoint, y: yPoint))
                                            } else {
                                                path.addLine(to: CGPoint(x: xPoint, y: yPoint))
                                            }
                                        }
                                    }
                                    .stroke(theme.primary, lineWidth: 2)
                                    .shadow(color: theme.primary, radius: 4)
                                }
                                .padding(8)
                            }
                        }
                        .frame(height: 80)
                    }

                    // Metrics Grid
                    VStack(spacing: 8) {
                        MetricRow(label: "CATEGORY", value: device.category.rawValue.uppercased(), theme: theme)
                        MetricRow(label: "RAW RSSI POWER", value: "\(device.rssi) dBm", theme: theme)
                        MetricRow(label: "REF TX POWER", value: device.txPowerLevel != nil ? "\(device.txPowerLevel!) dBm" : "UNADVERTISED", theme: theme)
                        MetricRow(label: "PROXIMITY BAND", value: device.proximityBand, theme: theme)
                        MetricRow(label: "ESTIMATED RANGE", value: device.estimatedDistanceRange, theme: theme)
                    }

                    if let beacon = device.beaconInfo {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("DECODED IBEACON TELEMETRY")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(theme.primary)
                            MetricRow(label: "BEACON UUID", value: beacon.uuid, theme: theme)
                            MetricRow(label: "MAJOR / MINOR", value: "\(beacon.major) / \(beacon.minor)", theme: theme)
                            MetricRow(label: "CALIBRATED PWR", value: "\(beacon.measuredPower) dBm", theme: theme)
                        }
                    }

                    if let mfgHex = device.manufacturerHex {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("RAW MANUFACTURER DATA PAYLOAD")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(theme.primary.opacity(0.8))

                            Text(mfgHex)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(theme.primary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(4)
                        }
                    }

                    // Action Switches
                    HStack(spacing: 12) {
                        Button(action: { onStartFoxhunt(device) }) {
                            HStack {
                                Image(systemName: "cross.circle.fill")
                                Text("FOXHUNT")
                            }
                            .font(.system(.footnote, design: .monospaced))
                            .fontWeight(.bold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(theme.primary, lineWidth: 2)
                                    .background(theme.primary.opacity(0.15))
                            )
                            .foregroundColor(theme.primary)
                        }

                        Button(action: { onStartGATT(device) }) {
                            HStack {
                                Image(systemName: "shield.checkerboard")
                                Text("AUDIT GATT")
                            }
                            .font(.system(.footnote, design: .monospaced))
                            .fontWeight(.bold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(theme.primary, lineWidth: 2)
                                    .background(theme.primary.opacity(0.15))
                            )
                            .foregroundColor(theme.primary)
                        }
                    }

                    Spacer()
                }
                .padding()
            }
        }
    }
}

// --- GATT SERVICES & CHARACTERISTIC INSPECTOR SHEET ---
struct GATTInspectView: View {
    @ObservedObject var engine: ScannerEngine
    let device: DiscoveredDevice
    let theme: ThemeColor
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.darkBg.ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(">_ ATT_ATTRIBUTES_INSPECTOR")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(theme.primary.opacity(0.8))
                        Text(device.name)
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                            .neonGlow(color: theme.primary)
                    }

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(theme.primary)
                            .padding(8)
                            .background(
                                Circle()
                                    .stroke(theme.primary.opacity(0.4), lineWidth: 1)
                            )
                    }
                }

                Divider().overlay(theme.primary.opacity(0.3))

                Text(engine.gattStatusLog)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(theme.primary)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(4)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(engine.auditedServices) { service in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("SERVICE: \(service.uuid)")
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(theme.primary)

                                ForEach(service.characteristics) { char in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("CHAR: \(char.uuid)")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundColor(.white)

                                        HStack {
                                            Text("PROPERTIES:")
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundColor(theme.primary.opacity(0.8))
                                            Text(char.properties.joined(separator: ", "))
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundColor(theme.primary)
                                        }
                                    }
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(4)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(theme.primary.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }

                Button(action: onClose) {
                    Text("DISCONNECT ATT SERVER")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.red, lineWidth: 2)
                                .background(Color.red.opacity(0.15))
                        )
                        .foregroundColor(.red)
                }
            }
            .padding()
        }
    }
}

// --- FOXHUNT VIEW ---
struct FoxhuntView: View {
    @ObservedObject var engine: ScannerEngine
    let theme: ThemeColor
    let onClose: () -> Void

    var currentDevice: DiscoveredDevice? {
        engine.activeFoxhuntDevice
    }

    var body: some View {
        ZStack {
            Color.darkBg.ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(">_ FOXHUNT_TRACKER")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(theme.primary.opacity(0.8))
                        Text(currentDevice?.name ?? "TARGET NODE")
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                            .neonGlow(color: theme.primary)
                    }

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(theme.primary)
                            .padding(8)
                            .background(
                                Circle()
                                    .stroke(theme.primary.opacity(0.4), lineWidth: 1)
                            )
                    }
                }

                Divider().overlay(theme.primary.opacity(0.3))

                ZStack {
                    Circle()
                        .stroke(theme.primary.opacity(0.2), lineWidth: 1)
                        .frame(width: 220, height: 220)

                    Circle()
                        .stroke(theme.primary.opacity(0.4), lineWidth: 1)
                        .frame(width: 150, height: 150)

                    Circle()
                        .stroke(theme.primary.opacity(0.8), lineWidth: 2)
                        .frame(width: max(20, CGFloat(currentDevice?.signalPercentage ?? 0) * 2.0), height: max(20, CGFloat(currentDevice?.signalPercentage ?? 0) * 2.0))
                        .shadow(color: theme.primary, radius: 8)

                    VStack(spacing: 4) {
                        Text("\(currentDevice?.rssi ?? 0) dBm")
                            .font(.system(.title, design: .monospaced))
                            .fontWeight(.bold)
                            .neonGlow(color: theme.primary)

                        Text(currentDevice?.proximityBand ?? "UNKNOWN")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(theme.primary.opacity(0.8))
                    }
                }

                VStack(spacing: 12) {
                    MetricRow(label: "ESTIMATED RANGE", value: currentDevice?.estimatedDistanceRange ?? "--", theme: theme)
                    MetricRow(label: "SIGNAL INTEGRITY", value: "\(currentDevice?.signalPercentage ?? 0)%", theme: theme)
                }

                Button(action: onClose) {
                    Text("ABORT FOXHUNT")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.red, lineWidth: 2)
                                .background(Color.red.opacity(0.15))
                        )
                        .foregroundColor(.red)
                }

                Spacer()
            }
            .padding()
        }
    }
}

// --- METRIC ROW ---
struct MetricRow: View {
    let label: String
    let value: String
    let theme: ThemeColor

    var body: some View {
        HStack {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(theme.primary.opacity(0.8))
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(theme.primary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .stroke(theme.primary.opacity(0.15), lineWidth: 1)
                .background(Color.black.opacity(0.2))
        )
    }
}

// --- SETTINGS SHEET ---
struct SettingsView: View {
    @Binding var selectedTheme: ThemeColor
    @Binding var animationsEnabled: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.darkBg.ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Text(">_ SYSTEM_CONFIG")
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.bold)
                        .neonGlow(color: selectedTheme.primary, radius: animationsEnabled ? 6 : 0)

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(selectedTheme.primary)
                            .padding(8)
                            .background(
                                Circle()
                                    .stroke(selectedTheme.primary.opacity(0.4), lineWidth: 1)
                            )
                    }
                }

                Divider().overlay(selectedTheme.primary.opacity(0.3))

                // ANIMATIONS & GLOW TOGGLE
                VStack(alignment: .leading, spacing: 12) {
                    Text("[ INTERFACE GRAPHICS & FX ]")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(selectedTheme.primary.opacity(0.8))

                    Toggle(isOn: $animationsEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .foregroundColor(selectedTheme.primary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("DYNAMIC GLOW & FX")
                                    .font(.system(.subheadline, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("Enable matrix rain, glowing borders & accents")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(selectedTheme.primary.opacity(0.8))
                            }
                        }
                    }
                    .tint(selectedTheme.primary)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(selectedTheme.primary.opacity(0.3), lineWidth: 1)
                            .background(Color.black.opacity(0.3))
                    )
                }

                // COLOR MATRIX PALETTE
                VStack(alignment: .leading, spacing: 12) {
                    Text("[ COLOR MATRIX PALETTE ]")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(selectedTheme.primary.opacity(0.8))

                    VStack(spacing: 12) {
                        ForEach(ThemeColor.allCases) { theme in
                            Button(action: {
                                withAnimation(.easeInOut) {
                                    selectedTheme = theme
                                }
                            }) {
                                HStack {
                                    Circle()
                                        .fill(theme.primary)
                                        .frame(width: 14, height: 14)
                                        .shadow(color: theme.primary, radius: animationsEnabled ? 4 : 0)

                                    Text(theme.rawValue.uppercased())
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.bold)
                                        .foregroundColor(selectedTheme == theme ? theme.primary : .gray)

                                    Spacer()

                                    if selectedTheme == theme {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(theme.primary)
                                            .neonGlow(color: theme.primary, radius: animationsEnabled ? 2 : 0)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(selectedTheme == theme ? theme.primary : Color.white.opacity(0.1), lineWidth: selectedTheme == theme ? 2 : 1)
                                        .background(selectedTheme == theme ? theme.primary.opacity(0.1) : Color.black.opacity(0.3))
                                )
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
