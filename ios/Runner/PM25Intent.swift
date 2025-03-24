import AppIntents

@available(iOS 16.0, *)
struct PM25Intent: AppIntent {
    static var title: LocalizedStringResource = "เช็คค่าฝุ่นปัจจุบัน"
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        return .result(dialog: "ระดับ PM2.5 ในปัจจุบันอยู่ที่ 35 µg/m³ ซึ่งอยู่ในเกณฑ์ปานกลาง")
    }
}

@available(iOS 16.0, *)
struct PM25EnglishIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Current PM2.5 Level"
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        return .result(dialog: "Current PM2.5 level is 35 µg/m³, which is in the moderate range")
    }
}
