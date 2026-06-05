import Foundation

struct TimeFormatter {
    private static let displayDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    static func formatDisplayDateTime(_ date: Date) -> String {
        displayDateTimeFormatter.string(from: date)
    }
    
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "0s"
    }
    
    static func formatLatency(_ ms: Double?) -> String {
        if let ms = ms {
            return String(format: "%.0f ms", ms)
        } else {
            return "— ms"
        }
    }
    
    static func funDowntimeComparison(_ seconds: TimeInterval) -> String {
        switch seconds {
        case 0..<60:
            return "Basically perfect 🎯"
        case 60..<300:
            return "Like missing half a coffee break ☕"
        case 300..<900:
            return "That's one TikTok scroll session 📱"
        case 900..<1800:
            return "You could've taken a power nap 😴"
        case 1800..<3600:
            return "That's a whole lunch break 🍕"
        default:
            return "Time to call your ISP 📞"
        }
    }
}
