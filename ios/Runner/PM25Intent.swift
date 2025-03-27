import AppIntents
import CoreLocation
import Foundation
import Combine

@MainActor
@available(iOS 16.0, *)
class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        requestAuthorization()
    }
    
    func requestAuthorization() {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            startUpdatingLocation()
        } else {
            print("❌ Location access denied. Please enable it in settings.")
        }
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            currentLocation = location
            print("📍 Current location - Latitude: \(location.coordinate.latitude), Longitude: \(location.coordinate.longitude)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            startUpdatingLocation()
        }
    }
}

@available(iOS 16.0, *)
struct PM25Intent: AppIntent {
    static var title: LocalizedStringResource = "เช็คค่าฝุ่นปัจจุบัน"
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let locationManager = await LocationManager()
        
        guard let location = await getCurrentLocation(from: locationManager) else {
            return .result(dialog: "ไม่สามารถระบุตำแหน่งของคุณได้ กรุณาตรวจสอบการตั้งค่าอนุญาตให้ใช้ตำแหน่งที่ตั้ง")
        }

        let lat = location.coordinate.latitude
        let lng = location.coordinate.longitude
        print("📍 Using location - Latitude: \(lat), Longitude: \(lng)")

        let pmData = try await fetchPMData(lat: String(lat), lng: String(lng))
        let pm25Value = getPM25Value(from: pmData.pm25)
        let airQualityLevel = getAirQualityLevel(pm25: pm25Value)

        return .result(dialog: "ระดับ PM2.5 ในปัจจุบันอยู่ที่ \(String(format: "%.1f", pm25Value)) µg/m³ ซึ่งอยู่ในเกณฑ์\(airQualityLevel)")
    }
    
    private func getCurrentLocation(from locationManager: LocationManager) async -> CLLocation? {
        for _ in 0..<10 {
            if let location = await  locationManager.currentLocation {
                return location
            }
            try? await Task.sleep(nanoseconds: 500_000_000)  // Wait 0.5 seconds
        }
        return nil
    }

    private func fetchPMData(lat: String, lng: String) async throws -> PMData {
        let urlString = "https://pm25.gistda.or.th/rest/pred/getPm25byLocation?lat=\(lat)&lng=\(lng)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(PMResponse.self, from: data).data
    }
    
    private func getPM25Value(from pm25Array: [Pm25]) -> Double {
        guard let firstValue = pm25Array.first else { return 0.0 }
        switch firstValue {
        case .double(let value):
            return value
        case .string(let stringValue):
            return Double(stringValue) ?? 0.0
        }
    }
    
    private func getAirQualityLevel(pm25: Double) -> String {
        switch pm25 {
        case 0.0..<15.0:
            return "ดีมาก"
        case 15.1..<25.0:
            return "ดี"
        case 25.0..<37.5:
            return "ปานกลาง"
        case 37.5..<75.0:
            return "เริ่มมีผลต่อสุขภาพ"
        default:
            return "มีผลต่อสุขภาพ"
        }
    }
}
@available(iOS 16.0, *)
struct PM25IntentEnglish: AppIntent {
    static var title: LocalizedStringResource = "Check Current PM2.5 Level"
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let locationManager = await LocationManager()
        
        guard let location = await getCurrentLocation(from: locationManager) else {
            return .result(dialog: "Unable to determine your location. Please check location permissions in settings.")
        }

        let lat = location.coordinate.latitude
        let lng = location.coordinate.longitude
        print("📍 Using location - Latitude: \(lat), Longitude: \(lng)")

        let pmData = try await fetchPMData(lat: String(lat), lng: String(lng))
        let pm25Value = getPM25Value(from: pmData.pm25)
        let airQualityLevel = getAirQualityLevel(pm25: pm25Value)

        return .result(dialog: "The current PM2.5 level is \(String(format: "%.1f", pm25Value)) µg/m³, which is classified as \(airQualityLevel).")
    }
    
    private func getCurrentLocation(from locationManager: LocationManager) async -> CLLocation? {
        for _ in 0..<10 {
            if let location = await  locationManager.currentLocation {
                return location
            }
            try? await Task.sleep(nanoseconds: 500_000_000)  // Wait 0.5 seconds
        }
        return nil
    }

    private func fetchPMData(lat: String, lng: String) async throws -> PMData {
        let urlString = "https://pm25.gistda.or.th/rest/pred/getPm25byLocation?lat=\(lat)&lng=\(lng)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(PMResponse.self, from: data).data
    }
    
    private func getPM25Value(from pm25Array: [Pm25]) -> Double {
        guard let firstValue = pm25Array.first else { return 0.0 }
        switch firstValue {
        case .double(let value):
            return value
        case .string(let stringValue):
            return Double(stringValue) ?? 0.0
        }
    }
    
    private func getAirQualityLevel(pm25: Double) -> String {
        switch pm25 {
        case 0.0..<15.0:
            return "Very Good"
        case 15.1..<25.0:
            return "Good"
        case 25.0..<37.5:
            return "Moderate"
        case 37.5..<75.0:
            return "Beginning to affect health"
        default:
            return "Affects health"
        }
    }
}
// MARK: - Data Models for PM2.5 API Response
struct PMResponse: Codable {
    let data: PMData
}

struct PMData: Codable {
    let pm25: [Pm25]
}

// PM2.5 values can be strings or doubles, so we handle both
enum Pm25: Codable {
    case double(Double)
    case string(String)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
            return
        }
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }
        throw DecodingError.typeMismatch(Pm25.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "PM2.5 value is not a valid type"))
    }
}
