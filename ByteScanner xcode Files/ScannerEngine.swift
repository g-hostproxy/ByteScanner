import Foundation
import CoreBluetooth
import AudioToolbox

// --- SCANNER MODES ---
enum ScanMode: String, CaseIterable, Identifiable {
    case allDevices = "All Devices"
    case categories = "Categories"
    case airTags = "AirTags"
    case unknownNodes = "Unknown Nodes"
    case closestDevice = "Closest Scan"

    var id: String { rawValue }
}

// --- DEVICE CATEGORY ENUM ---
enum DeviceCategory: String, CaseIterable, Identifiable, Codable {
    case watchlist = "Watchlist"
    case tv = "TVs & Displays"
    case airTag = "AirTag / Tracker"
    case smartDevices = "Smart Devices"
    case mouse = "Mouse"
    case keyboard = "Keyboard"
    case audio = "Audio & Headphones"
    case medical = "Medical Devices"
    case other = "Other BLE Devices"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .watchlist: return "bookmark.fill"
        case .tv: return "tv.fill"
        case .airTag: return "tag.fill"
        case .smartDevices: return "lightbulb.fill"
        case .mouse: return "magicmouse.fill"
        case .keyboard: return "keyboard.fill"
        case .audio: return "headphones"
        case .medical: return "heart.fill"
        case .other: return "antenna.radiowaves.left.and.right"
        }
    }
}

// --- GATT SERVICE MODEL ---
struct GATTCharacteristicInfo: Identifiable, Hashable {
    let id = UUID()
    let uuid: String
    let properties: [String]
    let isNotifying: Bool
}

struct GATTServiceInfo: Identifiable, Hashable {
    let id = UUID()
    let uuid: String
    var characteristics: [GATTCharacteristicInfo] = []
}

// --- IBEACON TELEMETRY ---
struct BeaconInfo: Hashable {
    let uuid: String
    let major: UInt16
    let minor: UInt16
    let measuredPower: Int8
}

// --- DISCOVERED DEVICE MODEL ---
struct DiscoveredDevice: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let uuid: String
    var rssi: Int
    var timestamp: String
    let category: DeviceCategory
    var rssiHistory: [Int] = []
    
    var isOnline: Bool = true
    var lastSeenDate: Date = Date()
    var txPowerLevel: Int? = nil
    var manufacturerHex: String? = nil
    var beaconInfo: BeaconInfo? = nil
    var serviceUUIDs: [String] = []
    var peripheral: CBPeripheral? = nil

    var isUnknownNode: Bool {
        return name == "UNKNOWN_NODE"
    }
}

// --- SCANNER ENGINE CLASS ---
class ScannerEngine: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var devices: [DiscoveredDevice] = []
    @Published var isScanning = false
    @Published var isFoxhunting = false
    
    @Published var packetsPerSecond: Int = 0
    @Published var isSpamDetected: Bool = false
    @Published var spamWarningMessage: String = ""
    private var packetCounter: Int = 0
    private var rateTimer: Timer?
    private var scanTimer: Timer?
    
    @Published var connectedPeripheral: CBPeripheral? = nil
    @Published var auditedServices: [GATTServiceInfo] = []
    @Published var isAuditingGATT = false
    @Published var gattStatusLog: String = "Idle"
    
    @Published var activeFoxhuntDevice: DiscoveredDevice? = nil
    private var beeperTimer: Timer?
    
    private var centralManager: CBCentralManager?
    
    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func refreshScan(duration: TimeInterval = 4.0) {
        guard let manager = centralManager, manager.state == .poweredOn else { return }
        
        stopFoxhunt()
        scanTimer?.invalidate()
        
        let scanStartTime = Date()
        isScanning = true
        packetCounter = 0
        startRateMonitoring()
        
        manager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        scanTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                manager.stopScan()
                self.isScanning = false
                self.stopRateMonitoring()
                
                for i in 0..<self.devices.count {
                    if self.devices[i].lastSeenDate < scanStartTime {
                        self.devices[i].isOnline = false
                    }
                }
            }
        }
    }
    
    var sortedDevices: [DiscoveredDevice] {
        devices.sorted { d1, d2 in
            if d1.isOnline != d2.isOnline {
                return d1.isOnline
            }
            return d1.rssi > d2.rssi
        }
    }
    
    private func startRateMonitoring() {
        packetCounter = 0
        rateTimer?.invalidate()
        rateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.packetsPerSecond = self.packetCounter
                
                if self.packetCounter > 150 {
                    self.isSpamDetected = true
                    self.spamWarningMessage = "HIGH DENSITY SPAM FLOOD (\(self.packetCounter) PKT/S)"
                } else if self.packetCounter < 80 {
                    self.isSpamDetected = false
                    self.spamWarningMessage = ""
                }
                
                self.packetCounter = 0
            }
        }
    }
    
    private func stopRateMonitoring() {
        rateTimer?.invalidate()
        rateTimer = nil
        packetsPerSecond = 0
        isSpamDetected = false
        spamWarningMessage = ""
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        packetCounter += 1
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let now = Date()
        let timeString = formatter.string(from: now)
        
        let rawName = peripheral.name ?? "UNKNOWN_NODE"
        let category = determineCategory(peripheralName: rawName, advertisementData: advertisementData)
        let uuid = peripheral.identifier.uuidString
        let currentRssi = RSSI.intValue
        
        let txPower = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? Int
        let mfgData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let mfgHex = mfgData?.map { String(format: "%02X", $0) }.joined(separator: " ")
        let beacon = parseIBeacon(mfgData: mfgData)
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.map { $0.uuidString } ?? []
        
        let displayName: String = {
            if category == .airTag && rawName == "UNKNOWN_NODE" {
                return "APPLE AIRTAG / FINDMY"
            }
            return rawName.uppercased()
        }()
        
        DispatchQueue.main.async {
            if let index = self.devices.firstIndex(where: { $0.uuid == uuid }) {
                self.devices[index].rssi = currentRssi
                self.devices[index].timestamp = timeString
                self.devices[index].isOnline = true
                self.devices[index].lastSeenDate = now
                self.devices[index].txPowerLevel = txPower ?? self.devices[index].txPowerLevel
                self.devices[index].manufacturerHex = mfgHex ?? self.devices[index].manufacturerHex
                self.devices[index].beaconInfo = beacon ?? self.devices[index].beaconInfo
                if !services.isEmpty { self.devices[index].serviceUUIDs = services }
                self.devices[index].peripheral = peripheral
                
                self.devices[index].rssiHistory.append(currentRssi)
                if self.devices[index].rssiHistory.count > 20 {
                    self.devices[index].rssiHistory.removeFirst()
                }
                
                if self.activeFoxhuntDevice?.uuid == uuid {
                    self.activeFoxhuntDevice = self.devices[index]
                    self.updateFoxhuntAudioInterval()
                }
            } else {
                let newDevice = DiscoveredDevice(
                    name: displayName,
                    uuid: uuid,
                    rssi: currentRssi,
                    timestamp: timeString,
                    category: category,
                    rssiHistory: [currentRssi],
                    isOnline: true,
                    lastSeenDate: now,
                    txPowerLevel: txPower,
                    manufacturerHex: mfgHex,
                    beaconInfo: beacon,
                    serviceUUIDs: services,
                    peripheral: peripheral
                )
                self.devices.append(newDevice)
            }
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            DispatchQueue.main.async {
                self.isScanning = false
                self.stopFoxhunt()
                self.stopRateMonitoring()
            }
        }
    }
    
    func auditGATT(for device: DiscoveredDevice) {
        guard let peripheral = device.peripheral, let manager = centralManager else {
            gattStatusLog = "PERIPHERAL HANDLE UNAVAILABLE"
            return
        }
        
        isAuditingGATT = true
        auditedServices.removeAll()
        gattStatusLog = "CONNECTING TO ATT SERVER..."
        connectedPeripheral = peripheral
        peripheral.delegate = self
        manager.connect(peripheral, options: nil)
    }
    
    func disconnectGATT() {
        if let peripheral = connectedPeripheral, let manager = centralManager {
            manager.cancelPeripheralConnection(peripheral)
        }
        isAuditingGATT = false
        connectedPeripheral = nil
        gattStatusLog = "DISCONNECTED"
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async {
            self.gattStatusLog = "CONNECTED. ENUMERATING GATT SERVICES..."
            peripheral.discoverServices(nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.isAuditingGATT = false
            self.gattStatusLog = "CONNECTION FAILED: \(error?.localizedDescription ?? "UNKNOWN")"
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services, error == nil else {
            DispatchQueue.main.async { self.gattStatusLog = "SERVICE DISCOVERY ERROR" }
            return
        }
        
        DispatchQueue.main.async {
            self.auditedServices = services.map { GATTServiceInfo(uuid: $0.uuid.uuidString) }
            self.gattStatusLog = "ENUMERATING CHARACTERISTICS (\(services.count) SERVICES)..."
        }
        
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics, error == nil else { return }
        
        let charInfos = characteristics.map { char -> GATTCharacteristicInfo in
            var props: [String] = []
            if char.properties.contains(.read) { props.append("READ") }
            if char.properties.contains(.write) { props.append("WRITE") }
            if char.properties.contains(.writeWithoutResponse) { props.append("WRITE_NO_RESP") }
            if char.properties.contains(.notify) { props.append("NOTIFY") }
            if char.properties.contains(.indicate) { props.append("INDICATE") }
            if char.properties.contains(.authenticatedSignedWrites) { props.append("AUTH_SIGNED") }
            
            return GATTCharacteristicInfo(
                uuid: char.uuid.uuidString,
                properties: props,
                isNotifying: char.isNotifying
            )
        }
        
        DispatchQueue.main.async {
            if let index = self.auditedServices.firstIndex(where: { $0.uuid == service.uuid.uuidString }) {
                self.auditedServices[index].characteristics = charInfos
            }
            self.gattStatusLog = "GATT TABLE ENUMERATION COMPLETE"
        }
    }
    
    func startFoxhunt(for device: DiscoveredDevice) {
        guard let manager = centralManager, manager.state == .poweredOn else { return }
        
        scanTimer?.invalidate()
        manager.stopScan()
        
        self.activeFoxhuntDevice = device
        self.isFoxhunting = true
        self.isScanning = true
        
        startRateMonitoring()
        
        manager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        
        updateFoxhuntAudioInterval()
    }
    
    func stopFoxhunt() {
        beeperTimer?.invalidate()
        beeperTimer = nil
        activeFoxhuntDevice = nil
        isFoxhunting = false
        
        if let manager = centralManager, manager.isScanning {
            manager.stopScan()
        }
        isScanning = false
        stopRateMonitoring()
    }
    
    private func updateFoxhuntAudioInterval() {
        guard let device = activeFoxhuntDevice else {
            stopFoxhunt()
            return
        }
        
        let clampedRssi = max(-100, min(-40, device.rssi))
        let normalized = Double(clampedRssi + 100) / 60.0
        let interval = 2.0 - (normalized * 1.88)
        
        beeperTimer?.invalidate()
        beeperTimer = Timer.scheduledTimer(withTimeInterval: max(0.12, interval), repeats: true) { _ in
            AudioServicesPlaySystemSound(1052)
        }
    }
    
    private func parseIBeacon(mfgData: Data?) -> BeaconInfo? {
        guard let data = mfgData, data.count >= 25 else { return nil }
        
        let companyID = UInt16(data[0]) | (UInt16(data[1]) << 8)
        let subType = data[2]
        let length = data[3]
        
        if companyID == 0x004C && subType == 0x02 && length == 0x15 {
            let uuidBytes = data.subdata(in: 4..<20)
            let uuidString = NSUUID(uuidBytes: (uuidBytes as NSData).bytes.bindMemory(to: UInt8.self, capacity: 16)).uuidString
            let major = UInt16(data[20]) << 8 | UInt16(data[21])
            let minor = UInt16(data[22]) << 8 | UInt16(data[23])
            let txPower = Int8(bitPattern: data[24])
            
            return BeaconInfo(uuid: uuidString, major: major, minor: minor, measuredPower: txPower)
        }
        return nil
    }
    
    private func determineCategory(peripheralName: String, advertisementData: [String : Any]) -> DeviceCategory {
        let name = peripheralName.lowercased()
        
        if let mfgData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data, mfgData.count >= 3 {
            let companyID = UInt16(mfgData[0]) | (UInt16(mfgData[1]) << 8)
            if companyID == 0x004C {
                let payloadType = mfgData[2]
                if payloadType == 0x12 || payloadType == 0x07 || payloadType == 0x10 || mfgData.count == 27 {
                    return .airTag
                }
            }
        }
        
        if name.contains("airtag") || name.contains("findmy") { return .airTag }
        
        if name.contains("tv") || name.contains("smarttv") || name.contains("television") ||
           name.contains("bravia") || name.contains("vizio") || name.contains("lg webos") ||
           name.contains("samsung") || name.contains("roku") || name.contains("firetv") ||
           name.contains("chromecast") || name.contains("apple tv") || name.contains("display") {
            return .tv
        }
        
        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            for uuid in serviceUUIDs {
                let uuidString = uuid.uuidString.lowercased()
                if uuidString.contains("1812") { return name.contains("mouse") ? .mouse : .keyboard }
                if uuidString.contains("180d") || uuidString.contains("1808") { return .medical }
                if uuidString.contains("184e") || uuidString.contains("1844") { return .audio }
            }
        }
        
        if name.contains("mouse") || name.contains("trackpad") { return .mouse }
        if name.contains("key") || name.contains("keyboard") { return .keyboard }
        if name.contains("airpods") || name.contains("buds") || name.contains("headphone") || name.contains("audio") || name.contains("speaker") { return .audio }
        if name.contains("health") || name.contains("pulse") || name.contains("fitbit") { return .medical }
        if name.contains("smart") || name.contains("plug") || name.contains("bulb") || name.contains("switch") { return .smartDevices }
        
        return .other
    }
}
