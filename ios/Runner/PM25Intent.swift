import AppIntents

@available(iOS 16.0, *)
struct PM25Intent: AppIntent {
    static var title: LocalizedStringResource = "เช็คค่าฝุ่นปัจจุบัน"
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let pmData = try await fetchPMData()
        
        // Get the first PM2.5 value from the response
        let pm25Value = getPM25Value(from: pmData.pm25)
        
        // Determine the air quality level based on PM2.5 value
        let airQualityLevel = getAirQualityLevel(pm25: pm25Value)
        
        return .result(dialog: "ระดับ PM2.5 ในปัจจุบันอยู่ที่ \(String(format: "%.1f", pm25Value)) µg/m³ ซึ่งอยู่ในเกณฑ์\(airQualityLevel)")
    }
    
    private func fetchPMData() async throws -> PMData {
        // Use static coordinates
        let lat = "13"
        let lng = "100"

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
        let pmData = try await fetchPMData()
        
        // Get the first PM2.5 value from the response
        let pm25Value = getPM25Value(from: pmData.pm25)
        
        // Determine the air quality level based on PM2.5 value
        let airQualityLevel = getAirQualityLevel(pm25: pm25Value)
        
        return .result(dialog: "Current PM2.5 level is \(String(format: "%.1f", pm25Value)) µg/m³, which is in the \(airQualityLevel) range")
    }
    
    private func fetchPMData() async throws -> PMData {
        // Use static coordinates
        let lat = "13"
        let lng = "100"

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
