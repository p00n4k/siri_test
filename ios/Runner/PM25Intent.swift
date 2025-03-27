import AppIntents
import CoreLocation

// Location helper class that handles requesting and receiving location updates
class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    private let manager = CLLocationManager()
    
    private var locationPromise: ((Result<CLLocationCoordinate2D, Error>) -> Void)?
    
    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    @available(iOS 16.0, *)
    func requestLocation() async throws -> CLLocationCoordinate2D {
        // Return the most recent location if available
        if let location = manager.location?.coordinate {
            return location
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.locationPromise = { result in
                switch result {
                case .success(let coordinate):
                    continuation.resume(returning: coordinate)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            // Request when in use permission if not already granted
            let status = CLLocationManager.authorizationStatus()
            if status == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else {
                manager.requestLocation()
            }
        }
    }
    
    // CLLocationManagerDelegate methods
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last?.coordinate {
            locationPromise?(.success(location))
            locationPromise = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationPromise?(.failure(error))
        locationPromise = nil
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = CLLocationManager.authorizationStatus()
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            locationPromise?(.failure(NSError(domain: "LocationError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Location access denied"])))
            locationPromise = nil
        default:
            break
        }
    }
}

enum PMIntentError: Error, CustomStringConvertible {
    case locationError(String)
    case networkError(String)
    case dataError(String)
    
    var description: String {
        switch self {
        case .locationError(let message):
            return "Location error: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .dataError(let message):
            return "Data error: \(message)"
        }
    }
}

@available(iOS 16.0, *)
struct PM25Intent: AppIntent {
    static var title: LocalizedStringResource = "เช็คค่าฝุ่นปัจจุบัน"
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Request user location
        let userLocation: CLLocationCoordinate2D
        do {
            userLocation = try await LocationManager.shared.requestLocation()
        } catch {
            throw PMIntentError.locationError("ไม่สามารถระบุตำแหน่งของคุณได้")
        }
        
        // Fetch PM data using the user's location
        let pmData = try await fetchPMData(latitude: userLocation.latitude, longitude: userLocation.longitude)
        
        // Get the PM2.5 value
        let pm25Value = getPM25Value(from: pmData.pm25)
        
        // Determine the air quality level
        let airQualityLevel = getAirQualityLevel(pm25: pm25Value)
        
        return .result(dialog: "ระดับ PM2.5 ที่ตำแหน่งของคุณอยู่ที่ \(String(format: "%.1f", pm25Value)) µg/m³ ซึ่งอยู่ในเกณฑ์\(airQualityLevel)")
    }
    @available(iOS 16.0, *)
    private func fetchPMData(latitude: CLLocationDegrees, longitude: CLLocationDegrees) async throws -> PMData {
        let lat = String(format: "%.6f", latitude)
        let lng = String(format: "%.6f", longitude)
        
        let urlString = "https://pm25.gistda.or.th/rest/pred/getPm25byLocation?lat=\(lat)&lng=\(lng)"
        guard let url = URL(string: urlString) else {
            throw PMIntentError.networkError("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw PMIntentError.networkError("Server returned an error")
        }
        
        do {
            return try JSONDecoder().decode(PMResponse.self, from: data).data
        } catch {
            throw PMIntentError.dataError("Unable to parse response data")
        }
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
        case 0.0..<12.0:
            return "ดี"
        case 12.0..<35.5:
            return "ปานกลาง"
        case 35.5..<55.5:
            return "เริ่มมีผลต่อสุขภาพ"
        case 55.5..<150.5:
            return "มีผลต่อสุขภาพ"
        case 150.5..<250.5:
            return "มีผลต่อสุขภาพมาก"
        default:
            return "อันตราย"
        }
    }
}

@available(iOS 16.0, *)
struct PM25EnglishIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Current PM2.5 Level"
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Request user location
        let userLocation: CLLocationCoordinate2D
        do {
            userLocation = try await LocationManager.shared.requestLocation()
        } catch {
            throw PMIntentError.locationError("Unable to determine your location")
        }
        
        // Fetch PM data using the user's location
        let pmData = try await fetchPMData(latitude: userLocation.latitude, longitude: userLocation.longitude)
        
        // Get the PM2.5 value
        let pm25Value = getPM25Value(from: pmData.pm25)
        
        // Determine the air quality level
        let airQualityLevel = getAirQualityLevel(pm25: pm25Value)
        
        return .result(dialog: "Current PM2.5 level at your location is \(String(format: "%.1f", pm25Value)) µg/m³, which is in the \(airQualityLevel) range")
    }
    
    private func fetchPMData(latitude: CLLocationDegrees, longitude: CLLocationDegrees) async throws -> PMData {
        let lat = String(format: "%.6f", latitude)
        let lng = String(format: "%.6f", longitude)
        
        let urlString = "https://pm25.gistda.or.th/rest/pred/getPm25byLocation?lat=\(lat)&lng=\(lng)"
        guard let url = URL(string: urlString) else {
            throw PMIntentError.networkError("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw PMIntentError.networkError("Server returned an error")
        }
        
        do {
            return try JSONDecoder().decode(PMResponse.self, from: data).data
        } catch {
            throw PMIntentError.dataError("Unable to parse response data")
        }
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
        case 0.0..<12.0:
            return "good"
        case 12.0..<35.5:
            return "moderate"
        case 35.5..<55.5:
            return "unhealthy for sensitive groups"
        case 55.5..<150.5:
            return "unhealthy"
        case 150.5..<250.5:
            return "very unhealthy"
        default:
            return "hazardous"
        }
    }
}



// Supporting structures
struct PMResponse: Decodable {
    let status: Int
    let errMsg: String
    let data: PMData
}

enum Pm25: Codable {
    case double(Double)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(Double.self) {
            self = .double(x)
            return
        }
        if let x = try? container.decode(String.self) {
            self = .string(x)
            return
        }
        throw DecodingError.typeMismatch(Pm25.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for Pm25"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .double(let x):
            try container.encode(x)
        case .string(let x):
            try container.encode(x)
        }
    }
}

struct PMData: Codable {
    let pm25: [Pm25]
    let datetimeThai: DateTimeThai
    let graphPredictByHrs: [[Pm25]]
}

struct DateTimeThai: Codable {
    // Add properties here if needed
}
