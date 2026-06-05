import SwiftUI
import Charts

struct ReportLatencyChart: View {
    let results: [PingResult]
    let totalCount: Int
    let loadedFromDate: Date
    let loadedToDate: Date
    
    @State private var zoom: Double = 1
    @State private var pan: TimeInterval = 0
    @State private var lastPan: TimeInterval = 0
    @GestureState private var magnifyBy: CGFloat = 1
    
    private var effectiveZoom: Double {
        min(max(zoom * Double(magnifyBy), 1), 64)
    }
    
    private var isZoomed: Bool {
        effectiveZoom > 1.001 || abs(pan) > 1
    }
    
    private var chartYDomain: ClosedRange<Double> {
        let maxLatency = results.compactMap { $0.isSuccess ? $0.latencyMs : nil }.max() ?? 100
        let upper = max(100, maxLatency * 1.12)
        return 0...upper
    }
    
    private var failedChartY: Double {
        chartYDomain.upperBound * 0.94
    }
    
    private var fullXDomain: ClosedRange<Date> {
        guard let first = results.map(\.timestamp).min(),
              let last = results.map(\.timestamp).max(),
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
    
    private var visibleXDomain: ClosedRange<Date> {
        let full = fullXDomain
        let fullSpan = full.upperBound.timeIntervalSince(full.lowerBound)
        guard fullSpan > 0 else { return full }
        
        let visibleSpan = fullSpan / effectiveZoom
        if visibleSpan >= fullSpan {
            return full
        }
        
        let center = full.lowerBound.addingTimeInterval(fullSpan / 2 + pan)
        var lower = center.addingTimeInterval(-visibleSpan / 2)
        var upper = center.addingTimeInterval(visibleSpan / 2)
        
        if lower < full.lowerBound {
            upper = min(full.upperBound, upper + full.lowerBound.timeIntervalSince(lower))
            lower = full.lowerBound
        }
        if upper > full.upperBound {
            lower = max(full.lowerBound, lower - upper.timeIntervalSince(full.upperBound))
            upper = full.upperBound
        }
        guard lower < upper else { return full }
        return lower...upper
    }
    
    private var xAxisFormat: Date.FormatStyle {
        let span = visibleXDomain.upperBound.timeIntervalSince(visibleXDomain.lowerBound)
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
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                if isZoomed {
                    Button("Reset zoom") {
                        resetZoom()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                Spacer()
                if isZoomed {
                    Text(zoomLabel)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(height: isZoomed ? nil : 0)
            .clipped()
            
            GeometryReader { geometry in
                chart
                    .contentShape(Rectangle())
                    .gesture(magnifyGesture)
                    .simultaneousGesture(panGesture(chartWidth: geometry.size.width))
                    .onTapGesture(count: 2) {
                        resetZoom()
                    }
            }
            .frame(height: 200)
            
            HStack(spacing: 20) {
                legendItem(color: .blue, label: "Success")
                legendItem(color: .red, label: "Failed")
                Spacer()
                Text("Pinch to zoom · drag to pan")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            if totalCount > ReportFields.maxChartPoints {
                Text("Chart shows \(results.count) sampled points of \(totalCount) total.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .onChange(of: loadedFromDate) { _, _ in resetZoom() }
        .onChange(of: loadedToDate) { _, _ in resetZoom() }
        .onChange(of: totalCount) { _, _ in resetZoom() }
    }
    
    private var chart: some View {
        Chart {
            ForEach(results, id: \.id) { result in
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
        .chartXScale(domain: visibleXDomain)
        .chartYScale(domain: chartYDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisGridLine()
                AxisTick()
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date.formatted(xAxisFormat))
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
        .clipped()
        .animation(.easeOut(duration: 0.15), value: visibleXDomain.lowerBound)
        .animation(.easeOut(duration: 0.15), value: effectiveZoom)
    }
    
    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .updating($magnifyBy) { value, state, _ in
                state = value
            }
            .onEnded { value in
                zoom = min(max(zoom * Double(value), 1), 64)
                if zoom <= 1 {
                    pan = 0
                } else {
                    clampPan()
                }
            }
    }
    
    private func panGesture(chartWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard effectiveZoom > 1, chartWidth > 0 else { return }
                let fullSpan = fullXDomain.upperBound.timeIntervalSince(fullXDomain.lowerBound)
                let visibleSpan = fullSpan / effectiveZoom
                let secondsPerPoint = visibleSpan / Double(chartWidth)
                pan = lastPan - Double(value.translation.width) * secondsPerPoint
            }
            .onEnded { _ in
                clampPan()
                lastPan = pan
            }
    }
    
    private var zoomLabel: String {
        String(format: "%.1f×", effectiveZoom)
    }
    
    private func resetZoom() {
        zoom = 1
        pan = 0
        lastPan = 0
    }
    
    private func clampPan() {
        let fullSpan = fullXDomain.upperBound.timeIntervalSince(fullXDomain.lowerBound)
        let visibleSpan = fullSpan / zoom
        guard visibleSpan < fullSpan else {
            pan = 0
            lastPan = 0
            return
        }
        let maxPan = (fullSpan - visibleSpan) / 2
        pan = min(max(pan, -maxPan), maxPan)
        lastPan = pan
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
}
