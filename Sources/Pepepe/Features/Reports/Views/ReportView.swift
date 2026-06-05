import AppKit
import SwiftUI
import Charts

struct ReportView: View {
    let store: PingStore
    
    @State private var fromDate = Calendar.current.startOfDay(for: Date())
    @State private var toDate = Date()
    @State private var loadedFromDate = Calendar.current.startOfDay(for: Date())
    @State private var loadedToDate = Date()
    @State private var didInitialLoad = false
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
    
    private var successCount: Int { results.filter(\.isSuccess).count }
    private var failedCount: Int { results.count - successCount }
    private var successRate: Double {
        guard !results.isEmpty else { return 0 }
        return Double(successCount) / Double(results.count) * 100
    }
    private var failedRate: Double {
        guard !results.isEmpty else { return 0 }
        return Double(failedCount) / Double(results.count) * 100
    }
    private var downtimeRate: Double {
        let span = loadedToDate.timeIntervalSince(loadedFromDate)
        guard span > 0 else { return 0 }
        return totalDowntime / span * 100
    }
    
    var body: some View {
        ZStack {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading report data…")
                        .foregroundStyle(.secondary)
                }
            } else {
                reportContent
            }
        }
        .frame(minWidth: 980, minHeight: 760)
        .onAppear {
            guard !didInitialLoad else { return }
            didInitialLoad = true
            resetFilterRange()
            loadData()
        }
    }
    
    private var reportContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                controlsSection
                summarySection
                if !errorBreakdown.isEmpty {
                    errorBreakdownSection
                }
                networkInfoSection
                chartSection
                dataTableSection
                footerSection
            }
            .padding(20)
        }
    }
    
    private var errorBreakdown: [(String, Int)] {
        Dictionary(grouping: results.filter { !$0.isSuccess }, by: { $0.errorType.rawValue })
            .compactMap { key, group in
                guard !key.isEmpty else { return nil }
                return (key, group.count)
            }
            .sorted { $0.0 < $1.0 }
    }
    
    private var errorBreakdownSection: some View {
        HStack(spacing: 16) {
            ForEach(errorBreakdown, id: \.0) { key, count in
                HStack(spacing: 6) {
                    Text("Error: \(key)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(count)")
                        .font(.caption.bold().monospacedDigit())
                }
            }
            Spacer()
        }
    }
    
    private var controlsSection: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Text("From:")
                    .foregroundStyle(.secondary)
                DatePicker("", selection: $fromDate)
                    .labelsHidden()
            }
            HStack(spacing: 8) {
                Text("To:")
                    .foregroundStyle(.secondary)
                DatePicker("", selection: $toDate)
                    .labelsHidden()
            }
            Spacer()
            Button("Refresh") { loadData() }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
        }
    }
    
    private var summarySection: some View {
        HStack(spacing: 12) {
            SummaryStatCard(
                icon: "waveform.path.ecg",
                iconColor: .blue,
                label: "Total Pings",
                value: formatCount(results.count),
                subtitle: nil,
                statusColor: nil
            )
            SummaryStatCard(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                label: "Successful",
                value: "\(formatCount(successCount)) (\(formatPercent(successRate)))",
                subtitle: nil,
                statusColor: .green
            )
            SummaryStatCard(
                icon: "xmark.circle.fill",
                iconColor: .red,
                label: "Failed",
                value: "\(formatCount(failedCount)) (\(formatPercent(failedRate)))",
                subtitle: nil,
                statusColor: .red
            )
            SummaryStatCard(
                icon: "clock.fill",
                iconColor: .secondary,
                label: "Downtime",
                value: "\(TimeFormatter.formatDuration(totalDowntime)) (\(formatPercent(downtimeRate)))",
                subtitle: nil,
                statusColor: nil
            )
        }
    }
    
    private var networkInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Network Info (latest in range)")
                .font(.headline)
            
            GlassCard {
                LazyVGrid(
                    columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(networkInfoItems, id: \.label) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(item.value)
                                .font(.subheadline.monospaced())
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
    
    private var networkInfoItems: [(label: String, value: String)] {
        var items = ReportFields.networkInfoItems(for: latestWifi).map { item in
            (label: item.label, value: displayValue(item.value))
        }
        items.append((label: "Last Updated", value: lastUpdatedText))
        return items
    }
    
    private var chartYDomain: ClosedRange<Double> {
        let maxLatency = chartResults.compactMap { $0.isSuccess ? $0.latencyMs : nil }.max() ?? 100
        let upper = max(100, maxLatency * 1.12)
        return 0...upper
    }
    
    private var failedChartY: Double {
        chartYDomain.upperBound * 0.94
    }
    
    private var chartXDomain: ClosedRange<Date> {
        guard let first = chartResults.map(\.timestamp).min(),
              let last = chartResults.map(\.timestamp).max(),
              first < last else {
            return loadedFromDate...max(loadedFromDate, loadedToDate)
        }
        let span = last.timeIntervalSince(first)
        let pad = max(span * 0.04, 30)
        let lower = max(loadedFromDate, first.addingTimeInterval(-pad))
        let upper = min(loadedToDate, last.addingTimeInterval(pad))
        guard lower < upper else { return loadedFromDate...max(loadedFromDate, loadedToDate) }
        return lower...upper
    }
    
    private var chartXAxisFormat: Date.FormatStyle {
        let span = chartXDomain.upperBound.timeIntervalSince(chartXDomain.lowerBound)
        if span < 3600 {
            return .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits)
        }
        if span < 86_400 {
            return .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
        }
        if span < 604_800 {
            return .dateTime.month(.abbreviated).day().hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
        }
        return .dateTime.month(.abbreviated).day()
    }
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Latency (ms)")
                .font(.headline)
            
            GlassCard {
                VStack(spacing: 8) {
                    Chart {
                        ForEach(chartResults, id: \.id) { result in
                            if result.isSuccess, let lat = result.latencyMs {
                                PointMark(
                                    x: .value("Time", result.timestamp),
                                    y: .value("Latency", min(lat, chartYDomain.upperBound))
                                )
                                .foregroundStyle(Color.blue)
                                .symbolSize(18)
                            } else {
                                PointMark(
                                    x: .value("Time", result.timestamp),
                                    y: .value("Latency", failedChartY)
                                )
                                .foregroundStyle(Color.red)
                                .symbolSize(20)
                            }
                        }
                    }
                    .chartXScale(domain: chartXDomain)
                    .chartYScale(domain: chartYDomain)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 6)) { value in
                            AxisGridLine()
                            AxisTick()
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(date.formatted(chartXAxisFormat))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartPlotStyle { plotArea in
                        plotArea.clipShape(Rectangle())
                    }
                    .frame(height: 200)
                    .clipped()
                    
                    HStack(spacing: 20) {
                        legendItem(color: .blue, label: "Success")
                        legendItem(color: .red, label: "Failed")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                    if results.count > ReportFields.maxChartPoints {
                        Text("Chart shows \(chartResults.count) sampled points of \(results.count) total.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
    
    private var dataTableSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ping Data")
                .font(.headline)
            
            GlassCard {
                if reportRows.isEmpty {
                    Text("No data in selected range.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                } else {
                    ScrollView(.horizontal) {
                        VStack(alignment: .leading, spacing: 0) {
                            tableHeader
                                .background(.ultraThinMaterial)
                                .zIndex(1)
                            Divider().opacity(0.3)
                            ScrollView(.vertical) {
                                LazyVStack(spacing: 0) {
                                    ForEach(Array(visibleRows.enumerated()), id: \.element.id) { index, row in
                                        tableDataRow(row, striped: index.isMultiple(of: 2))
                                    }
                                }
                            }
                            .frame(height: 200)
                        }
                        .frame(minWidth: tableContentWidth, alignment: .leading)
                    }
                    .frame(maxHeight: 240)
                }
            }
        }
    }
    
    private var footerSection: some View {
        HStack {
            Button("Export…") { exportCSV() }
                .disabled(isLoading || results.isEmpty)
            Button("Clear All…") { confirmClearAllData() }
                .disabled(isLoading)
            Spacer()
            Text(recordCountText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("·")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text("Auto-clear after \(Constants.DataRetention.retentionDays) days")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
    
    private var tableContentWidth: CGFloat {
        ReportFields.csvColumns.reduce(0) { $0 + columnWidth(for: $1.key) }
    }
    
    private var tableHeader: some View {
        HStack(spacing: 0) {
            ForEach(ReportFields.csvColumns, id: \.key) { col in
                tableHeaderCell(col.label, width: columnWidth(for: col.key))
            }
        }
        .padding(.vertical, 8)
    }
    
    private func tableDataRow(_ row: ReportRow, striped: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(ReportFields.csvColumns, id: \.key) { col in
                tableCell(for: col.key, row: row, width: columnWidth(for: col.key))
            }
        }
        .background(striped ? Color.primary.opacity(0.04) : Color.clear)
    }
    
    @ViewBuilder
    private func tableCell(for key: String, row: ReportRow, width: CGFloat) -> some View {
        if key == "success" {
            successCell(row.ping.isSuccess)
                .frame(width: width, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        } else {
            Text(displayValue(ReportFields.tableValue(for: key, row: row)))
                .font(.caption.monospaced())
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: width, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .textSelection(.enabled)
        }
    }
    
    private func columnWidth(for key: String) -> CGFloat {
        switch key {
        case "timestamp": return 158
        case "target": return 88
        case "success": return 88
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
    
    private func tableHeaderCell(_ title: String, width: CGFloat?) -> some View {
        Group {
            if let width {
                Text(title)
                    .frame(width: width, alignment: .leading)
            } else {
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
    }
    
    private func successCell(_ success: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(success ? .green : .red)
            Text(success ? "Yes" : "No")
                .font(.caption)
        }
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
    
    private var lastUpdatedText: String {
        guard let ts = latestWifi?.timestamp else { return "—" }
        return TimeFormatter.formatDisplayDateTime(ts)
    }
    
    private var recordCountText: String {
        if reportRows.count > ReportFields.maxTableRows {
            return "Showing latest \(ReportFields.maxTableRows) of \(formatCount(reportRows.count)) records"
        }
        return "Showing \(formatCount(reportRows.count)) records"
    }
    
    private func formatCount(_ n: Int) -> String {
        Self.countFormatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
    
    private func formatPercent(_ value: Double) -> String {
        String(format: "%.2f%%", value)
    }
    
    private static let countFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()
    
    private func resetFilterRange() {
        let now = Date()
        fromDate = Calendar.current.startOfDay(for: now)
        toDate = now
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
                loadedFromDate = from
                loadedToDate = to
                isLoading = false
            }
        }
    }
    
    private func exportCSV() {
        let from = fromDate
        let to = toDate
        let window = NSApp.keyWindow
        
        DispatchQueue.global(qos: .userInitiated).async {
            let data = store.fetchReportData(from: from, to: to)
            DispatchQueue.main.async {
                ReportExporter.exportCSV(
                    results: data.results,
                    wifiSnapshots: data.wifiSnapshots,
                    from: from,
                    to: to,
                    window: window
                )
            }
        }
    }
    
    private func confirmClearAllData() {
        let alert = NSAlert()
        alert.messageText = "Clear all data?"
        alert.informativeText = "Permanently deletes all ping, Wi‑Fi, and downtime records. Export first if you need a backup."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        
        store.clearAllData()
        loadData()
    }
}

private struct SummaryStatCard: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let subtitle: String?
    let statusColor: Color?
    
    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 36, height: 36)
                    .background(iconColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if let statusColor {
                            Circle().fill(statusColor).frame(width: 6, height: 6)
                        }
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(value)
                        .font(.title3.bold().monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct GlassCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        content()
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    }
            }
    }
}
