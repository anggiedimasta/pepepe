import SwiftUI
import Charts

struct ReportView: View {
    let store: PingStore
    
    @State private var fromDate = Calendar.current.startOfDay(for: Date())
    @State private var toDate = Date()
    @State private var results: [PingResult] = []
    @State private var wifiSnapshots: [WiFiSnapshot] = []
    @State private var reportRows: [ReportRow] = []
    @State private var totalDowntime: TimeInterval = 0
    @State private var isLoading = false
    
    private var latestWifi: WiFiSnapshot? { wifiSnapshots.last }
    private var chartResults: [PingResult] { ReportFields.sampledChartPings(from: results) }
    private var visibleRows: [ReportRow] {
        if reportRows.count <= ReportFields.maxTableRows { return reportRows }
        return Array(reportRows.suffix(ReportFields.maxTableRows))
    }
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading report data…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                reportContent
            }
        }
        .frame(minWidth: 900, minHeight: 700)
        .task { loadData() }
    }
    
    private var reportContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                controlsSection
                summarySection
                networkInfoSection
                chartSection
                dataTableSection
            }
            .padding()
        }
    }
    
    private var controlsSection: some View {
        HStack {
            DatePicker("From", selection: $fromDate)
            DatePicker("To", selection: $toDate)
            Button("Load Data") { loadData() }
                .disabled(isLoading)
            Spacer()
            Button("Export CSV") { exportCSV() }
                .disabled(isLoading || results.isEmpty)
        }
    }
    
    private var summarySection: some View {
        HStack(spacing: 24) {
            statBlock("Total Pings", "\(results.count)")
            statBlock("Successful", "\(results.filter { $0.isSuccess }.count)")
            statBlock("Failed", "\(results.filter { !$0.isSuccess }.count)")
            statBlock("Downtime", TimeFormatter.formatDuration(totalDowntime))
            if !results.isEmpty {
                let errors = Dictionary(grouping: results.filter { !$0.isSuccess }, by: { $0.errorType.rawValue })
                ForEach(errors.keys.sorted(), id: \.self) { key in
                    if !key.isEmpty {
                        statBlock("Error: \(key)", "\(errors[key]?.count ?? 0)")
                    }
                }
            }
            Spacer()
        }
    }
    
    private func statBlock(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.body.monospacedDigit())
        }
    }
    
    private var networkInfoSection: some View {
        GroupBox("Network Info (latest in range)") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                ForEach(ReportFields.networkInfoItems(for: latestWifi), id: \.label) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text(item.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 110, alignment: .leading)
                        Text(item.value.isEmpty ? "—" : item.value)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var chartSection: some View {
        GroupBox("Latency Chart") {
            Chart {
                ForEach(chartResults, id: \.id) { result in
                    if result.isSuccess, let lat = result.latencyMs {
                        PointMark(
                            x: .value("Time", result.timestamp),
                            y: .value("Latency", lat)
                        )
                        .foregroundStyle(by: .value("Target", result.target))
                    } else {
                        PointMark(
                            x: .value("Time", result.timestamp),
                            y: .value("Latency", 0)
                        )
                        .foregroundStyle(.red)
                        .symbol(.cross)
                    }
                }
            }
            .frame(height: 200)
            .padding(.vertical, 4)
            
            if results.count > ReportFields.maxChartPoints {
                Text("Chart shows \(chartResults.count) sampled points of \(results.count) total.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var dataTableSection: some View {
        GroupBox("Ping Data") {
            if reportRows.isEmpty {
                Text("No data in selected range.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if reportRows.count > ReportFields.maxTableRows {
                        Text("Showing latest \(ReportFields.maxTableRows) of \(reportRows.count) rows. Export CSV for full data.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    ScrollView([.horizontal, .vertical]) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            tableRow(columns: ReportFields.csvColumns.map(\.label), isHeader: true)
                            Divider()
                            ForEach(visibleRows) { row in
                                tableRow(
                                    columns: ReportFields.csvColumns.map {
                                        displayValue(ReportFields.tableValue(for: $0.key, row: row))
                                    }
                                )
                                Divider()
                            }
                        }
                    }
                    .frame(height: 280)
                }
            }
        }
    }
    
    private func tableRow(columns: [String], isHeader: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(columns.enumerated()), id: \.offset) { index, value in
                let key = ReportFields.csvColumns[index].key
                tableCell(value, columnKey: key, isHeader: isHeader)
            }
        }
    }
    
    private func tableCell(_ text: String, columnKey: String, isHeader: Bool) -> some View {
        Text(text)
            .font(isHeader ? .caption.bold() : .caption.monospaced())
            .lineLimit(isHeader ? 2 : 1)
            .truncationMode(.tail)
            .frame(width: columnWidth(for: columnKey), alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, isHeader ? 4 : 3)
            .background(isHeader ? Color(nsColor: .controlBackgroundColor) : Color.clear)
            .textSelection(.enabled)
    }
    
    private func columnWidth(for key: String) -> CGFloat {
        switch key {
        case "timestamp": return 172
        case "target": return 88
        case "success": return 64
        case "pingError": return 120
        case "latency": return 88
        case "ssid": return 140
        case "ipv4": return 112
        case "gateway": return 112
        case "bssid": return 148
        case "rssi", "noise", "snr", "channel": return 56
        case "band": return 72
        case "txRate": return 88
        case "phy": return 80
        case "interface": return 64
        case "ipv6": return 280
        case "dns": return 320
        default: return 80
        }
    }
    
    private func displayValue(_ value: String) -> String {
        value.isEmpty ? "—" : value
    }
    
    private func loadData() {
        guard !isLoading else { return }
        isLoading = true
        
        let from = fromDate
        let to = toDate
        
        DispatchQueue.global(qos: .userInitiated).async {
            let data = store.fetchReportData(from: from, to: to)
            let rows = ReportFields.buildRows(pings: data.results, wifiSnapshots: data.wifiSnapshots)
            
            DispatchQueue.main.async {
                results = data.results
                wifiSnapshots = data.wifiSnapshots
                reportRows = rows
                totalDowntime = data.totalDowntime
                isLoading = false
            }
        }
    }
    
    private func exportCSV() {
        ReportExporter.exportCSV(
            results: results,
            wifiSnapshots: wifiSnapshots,
            from: fromDate,
            to: toDate,
            window: NSApp.keyWindow
        )
    }
}
