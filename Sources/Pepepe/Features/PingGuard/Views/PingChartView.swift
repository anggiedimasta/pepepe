import SwiftUI
import Charts

struct PingChartView: View {
    @ObservedObject var pingGuard: PingGuardModule
    
    var body: some View {
        if pingGuard.isRunning {
            Chart {
                if let target = pingGuard.rollingWindows.keys.sorted().first {
                    let results = pingGuard.rollingWindows[target] ?? []
                    ForEach(results, id: \.id) { result in
                        if result.isSuccess, let lat = result.latencyMs {
                            BarMark(
                                x: .value("Time", result.timestamp),
                                y: .value("Latency", lat)
                            )
                            .foregroundStyle(gradientForLatency(lat))
                            .cornerRadius(2)
                        } else {
                            PointMark(
                                x: .value("Time", result.timestamp),
                                y: .value("Latency", maxLatency(for: pingGuard.rollingWindows) * 1.2)
                            )
                            .foregroundStyle(.red)
                            .symbol(.cross)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: chartXValues) { value in
                    AxisGridLine()
                    AxisTick()
                    if let date = value.as(Date.self) {
                        AxisValueLabel(anchor: .topLeading) {
                            Text(timeFormatter.string(from: date))
                                .font(.system(size: 9))
                                .fixedSize()
                                .rotationEffect(.degrees(-45))
                                .offset(x: -8, y: 4)
                        }
                    }
                }
            }
            .chartXScale(domain: chartDomain)
            .animation(.linear(duration: 0.3), value: pingGuard.rollingWindows.values.map { $0.count })
        } else {
            Rectangle()
                .fill(Color.black.opacity(0.1))
                .overlay(Text("Start monitoring to see data").foregroundColor(.secondary))
        }
    }
    
    private var chartXValues: [Date] {
        guard let target = pingGuard.rollingWindows.keys.sorted().first else { return [] }
        return pingGuard.rollingWindows[target]?.map { $0.timestamp } ?? []
    }
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.timeZone = .current
        f.dateFormat = "m:ss"
        return f
    }()
    
    private func maxLatency(for windows: [String: [PingResult]]) -> Double {
        let maxVal = windows.values.flatMap { $0 }.compactMap { $0.latencyMs }.max() ?? 100.0
        return max(maxVal, 100.0)
    }
    
    private var chartDomain: ClosedRange<Date> {
        let results = pingGuard.rollingWindows.values.flatMap { $0 }
        let latest = results.map { $0.timestamp }.max() ?? Date()
        let oldest = results.map { $0.timestamp }.min() ?? latest
        
        let maxBars = Constants.PingGuard.rollingWindowSize
        let span = TimeInterval(maxBars) * Constants.PingGuard.pingIntervalSeconds
        let expectedEnd = oldest.addingTimeInterval(span)
        
        return oldest.addingTimeInterval(-1)...expectedEnd.addingTimeInterval(1)
    }
    
    private func gradientForLatency(_ lat: Double) -> LinearGradient {
        let colors: [Color]
        let neonGreen = Color(red: 0.2, green: 1.0, blue: 0.0)
        let deepPurple = Color(red: 0.3, green: 0.0, blue: 0.6)
        if lat < 30 {
            colors = [neonGreen, .green]
        } else if lat < 80 {
            colors = [neonGreen, .green, .yellow, .orange]
        } else {
            colors = [neonGreen, .green, .yellow, .orange, .red, deepPurple]
        }
        return LinearGradient(
            colors: colors,
            startPoint: .bottom,
            endPoint: .top
        )
    }
}
