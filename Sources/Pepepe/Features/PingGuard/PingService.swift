import Foundation

final class PingService: @unchecked Sendable {
    private var timerQueue = DispatchQueue(label: "com.anggiedimasta.pepepe.pingtimer")
    private var timer: DispatchSourceTimer?
    private var isRunning = false
    private var targets: [PingTarget] = []
    
    var onResult: (@MainActor @Sendable (PingResult) -> Void)?
    
    init() {}
    
    func setTargets(_ targets: [PingTarget]) {
        self.targets = targets
    }
    
    func start(sessionId: String) {
        guard !isRunning else { return }
        isRunning = true
        
        timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer?.schedule(deadline: .now(), repeating: Constants.PingGuard.pingIntervalSeconds)
        timer?.setEventHandler { [weak self] in
            self?.pingAll(sessionId: sessionId)
        }
        timer?.resume()
    }
    
    func stop() {
        isRunning = false
        timer?.cancel()
        timer = nil
    }
    
    private func pingAll(sessionId: String) {
        let activeTargets = targets.filter { $0.isEnabled }
        for target in activeTargets {
            DispatchQueue.global(qos: .background).async {
                self.ping(target: target, sessionId: sessionId)
            }
        }
    }
    
    private func ping(target: PingTarget, sessionId: String) {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "1", "-W", "\(Constants.PingGuard.pingTimeoutSeconds * 1000)", target.host]
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        let startTime = Date()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let output = stdout + stderr
            
            var latency: Double? = nil
            var success = false
            var errorType = PingErrorType.unknown
            
            if process.terminationStatus == 0 {
                if let range = output.range(of: "time=([0-9.]+) ms", options: .regularExpression) {
                    let matchString = String(output[range])
                    let numberString = matchString.replacingOccurrences(of: "time=", with: "").replacingOccurrences(of: " ms", with: "")
                    if let val = Double(numberString) {
                        latency = val
                        success = true
                        errorType = .none
                    }
                } else {
                    errorType = PingErrorType.parse(from: output, exitCode: process.terminationStatus)
                }
            } else {
                errorType = PingErrorType.parse(from: output, exitCode: process.terminationStatus)
                if errorType == .unknown {
                    errorType = .timeout
                }
            }
            
            let result = PingResult(
                id: UUID(),
                sessionId: sessionId,
                target: target.host,
                timestamp: startTime,
                latencyMs: latency,
                isSuccess: success,
                errorType: errorType
            )
            
            let onResultClosure = self.onResult
            DispatchQueue.main.async {
                onResultClosure?(result)
            }
            
        } catch {
            print("Failed to run ping process: \(error)")
        }
    }
}
