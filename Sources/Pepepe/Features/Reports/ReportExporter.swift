import AppKit
import SwiftUI

@MainActor
struct ReportExporter {
    static func exportCSV(
        results: [PingResult],
        wifiSnapshots: [WiFiSnapshot],
        from: Date,
        to: Date,
        window: NSWindow?
    ) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        let fromStr = df.string(from: from)
        let toStr = df.string(from: to)
        panel.nameFieldStringValue = "pepepe_report_\(fromStr)-\(toStr).csv"
        
        guard let win = window else { return }
        
        panel.beginSheetModal(for: win) { response in
            if response == .OK, let url = panel.url {
                let rows = ReportFields.buildRows(pings: results, wifiSnapshots: wifiSnapshots)
                var csvText = ReportFields.csvHeader()
                for row in rows {
                    csvText.append(ReportFields.csvRow(for: row) + "\n")
                }
                try? csvText.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}
