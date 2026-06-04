import Foundation
import SQLite3

enum SQLiteError: Error {
    case openDatabase(message: String)
    case prepare(message: String)
    case step(message: String)
    case bind(message: String)
}

class PingStore: @unchecked Sendable {
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.anggiedimasta.pepepe.db")
    
    struct ReportFetchResult: Sendable {
        let results: [PingResult]
        let wifiSnapshots: [WiFiSnapshot]
        let totalDowntime: TimeInterval
    }
    
    init() throws {
        let fileManager = FileManager.default
        let appSupportUrl = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(Constants.App.appSupportDirectoryName)
        
        if !fileManager.fileExists(atPath: appSupportUrl.path) {
            try fileManager.createDirectory(at: appSupportUrl, withIntermediateDirectories: true, attributes: nil)
        }
        
        let dbUrl = appSupportUrl.appendingPathComponent(Constants.App.databaseName)
        
        if sqlite3_open(dbUrl.path, &db) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw SQLiteError.openDatabase(message: errmsg)
        }
        sqlite3_busy_timeout(db, 3_000)
        
        try createTables()
        try migrateSchema()
    }
    
    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }
    
    private func createTables() throws {
        let createSessions = """
        CREATE TABLE IF NOT EXISTS sessions (
            id TEXT PRIMARY KEY,
            started_at REAL NOT NULL,
            ended_at REAL,
            target TEXT NOT NULL
        );
        """
        
        let createPingResults = """
        CREATE TABLE IF NOT EXISTS ping_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            target TEXT NOT NULL,
            timestamp REAL NOT NULL,
            latency_ms REAL,
            is_success INTEGER NOT NULL,
            FOREIGN KEY (session_id) REFERENCES sessions(id)
        );
        """
        
        let createRtoEvents = """
        CREATE TABLE IF NOT EXISTS rto_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            target TEXT NOT NULL,
            started_at REAL NOT NULL,
            ended_at REAL,
            duration_seconds REAL,
            FOREIGN KEY (session_id) REFERENCES sessions(id)
        );
        """
        
        let createPingTargets = """
        CREATE TABLE IF NOT EXISTS ping_targets (
            id TEXT PRIMARY KEY,
            host TEXT NOT NULL,
            label TEXT NOT NULL,
            is_enabled INTEGER NOT NULL DEFAULT 1
        );
        """
        
        let createWifiSnapshots = """
        CREATE TABLE IF NOT EXISTS wifi_snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp REAL NOT NULL,
            ssid TEXT,
            rssi INTEGER,
            noise INTEGER,
            channel INTEGER,
            band TEXT,
            tx_rate REAL
        );
        """
        
        let indexPingTimestamp = "CREATE INDEX IF NOT EXISTS idx_ping_timestamp ON ping_results(timestamp);"
        let indexPingTarget = "CREATE INDEX IF NOT EXISTS idx_ping_target ON ping_results(target);"
        let indexRtoTimestamp = "CREATE INDEX IF NOT EXISTS idx_rto_timestamp ON rto_events(started_at);"
        let indexWifiTimestamp = "CREATE INDEX IF NOT EXISTS idx_wifi_timestamp ON wifi_snapshots(timestamp);"
        
        try execute(sql: createSessions)
        try execute(sql: createPingResults)
        try execute(sql: createRtoEvents)
        try execute(sql: createPingTargets)
        try execute(sql: createWifiSnapshots)
        
        try execute(sql: indexPingTimestamp)
        try execute(sql: indexPingTarget)
        try execute(sql: indexRtoTimestamp)
        try execute(sql: indexWifiTimestamp)
    }
    
    private func migrateSchema() throws {
        try addColumnIfMissing(table: "ping_results", column: "error_type", type: "TEXT")
        
        try addColumnIfMissing(table: "wifi_snapshots", column: "bssid", type: "TEXT")
        try addColumnIfMissing(table: "wifi_snapshots", column: "interface_name", type: "TEXT")
        try addColumnIfMissing(table: "wifi_snapshots", column: "phy_mode", type: "TEXT")
        try addColumnIfMissing(table: "wifi_snapshots", column: "ipv4", type: "TEXT")
        try addColumnIfMissing(table: "wifi_snapshots", column: "ipv6", type: "TEXT")
        try addColumnIfMissing(table: "wifi_snapshots", column: "gateway", type: "TEXT")
        try addColumnIfMissing(table: "wifi_snapshots", column: "dns_servers", type: "TEXT")
        try addColumnIfMissing(table: "wifi_snapshots", column: "client_mac", type: "TEXT")
        try addColumnIfMissing(table: "wifi_snapshots", column: "security_type", type: "TEXT")
    }
    
    private func addColumnIfMissing(table: String, column: String, type: String) throws {
        guard !columnExists(table: table, column: column) else { return }
        try execute(sql: "ALTER TABLE \(table) ADD COLUMN \(column) \(type);")
    }
    
    private func columnExists(table: String, column: String) -> Bool {
        let sql = "PRAGMA table_info(\(table));"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(statement) }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let name = sqlite3_column_text(statement, 1) {
                if String(cString: name) == column { return true }
            }
        }
        return false
    }
    
    private func execute(sql: String) throws {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw SQLiteError.prepare(message: errmsg)
        }
        
        if sqlite3_step(statement) != SQLITE_DONE {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            sqlite3_finalize(statement)
            throw SQLiteError.step(message: errmsg)
        }
        sqlite3_finalize(statement)
    }
    
    func createSession(target: String) throws -> String {
        try queue.sync {
        let id = UUID().uuidString
        let sql = "INSERT INTO sessions (id, started_at, target) VALUES (?, ?, ?);"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            throw SQLiteError.prepare(message: "Failed to prepare createSession")
        }
        
        sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)
        sqlite3_bind_double(statement, 2, Date().timeIntervalSince1970)
        sqlite3_bind_text(statement, 3, (target as NSString).utf8String, -1, nil)
        
        if sqlite3_step(statement) != SQLITE_DONE {
            sqlite3_finalize(statement)
            throw SQLiteError.step(message: "Failed to insert session")
        }
        sqlite3_finalize(statement)
        return id
        }
    }
    
    func endSession(id: String) throws {
        queue.sync {
        let sql = "UPDATE sessions SET ended_at = ? WHERE id = ?;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK { return }
        
        sqlite3_bind_double(statement, 1, Date().timeIntervalSince1970)
        sqlite3_bind_text(statement, 2, (id as NSString).utf8String, -1, nil)
        sqlite3_step(statement)
        sqlite3_finalize(statement)
        }
    }
    
    func insertPingResult(_ result: PingResult) throws {
        queue.sync {
        let sql = """
        INSERT INTO ping_results (session_id, target, timestamp, latency_ms, is_success, error_type)
        VALUES (?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK { return }
        
        sqlite3_bind_text(statement, 1, (result.sessionId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (result.target as NSString).utf8String, -1, nil)
        sqlite3_bind_double(statement, 3, result.timestamp.timeIntervalSince1970)
        
        if let latency = result.latencyMs {
            sqlite3_bind_double(statement, 4, latency)
        } else {
            sqlite3_bind_null(statement, 4)
        }
        
        sqlite3_bind_int(statement, 5, result.isSuccess ? 1 : 0)
        if result.isSuccess {
            bindOptionalText(statement, index: 6, value: nil)
        } else {
            let error = result.errorType == .none ? PingErrorType.unknown.rawValue : result.errorType.rawValue
            bindOptionalText(statement, index: 6, value: error)
        }
        
        sqlite3_step(statement)
        sqlite3_finalize(statement)
        }
    }
    
    func insertRTOEvent(sessionId: String, target: String, startedAt: Date) throws -> Int64 {
        queue.sync {
        let sql = "INSERT INTO rto_events (session_id, target, started_at) VALUES (?, ?, ?);"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK { return -1 }
        
        sqlite3_bind_text(statement, 1, (sessionId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (target as NSString).utf8String, -1, nil)
        sqlite3_bind_double(statement, 3, startedAt.timeIntervalSince1970)
        
        sqlite3_step(statement)
        sqlite3_finalize(statement)
        
        return sqlite3_last_insert_rowid(db)
        }
    }
    
    func updateRTOEvent(id: Int64, endedAt: Date, durationSeconds: TimeInterval) throws {
        queue.sync {
        let sql = "UPDATE rto_events SET ended_at = ?, duration_seconds = ? WHERE id = ?;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK { return }
        
        sqlite3_bind_double(statement, 1, endedAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 2, durationSeconds)
        sqlite3_bind_int64(statement, 3, id)
        
        sqlite3_step(statement)
        sqlite3_finalize(statement)
        }
    }
    
    func insertWiFiSnapshot(_ snapshot: WiFiSnapshot) throws {
        queue.sync {
        let sql = """
        INSERT INTO wifi_snapshots (
            timestamp, ssid, rssi, noise, channel, band, tx_rate,
            bssid, interface_name, phy_mode, ipv4, ipv6, gateway, dns_servers, client_mac, security_type
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK { return }
        
        sqlite3_bind_double(statement, 1, snapshot.timestamp.timeIntervalSince1970)
        bindOptionalText(statement, index: 2, value: snapshot.ssid)
        sqlite3_bind_int(statement, 3, Int32(snapshot.rssi))
        sqlite3_bind_int(statement, 4, Int32(snapshot.noise))
        sqlite3_bind_int(statement, 5, Int32(snapshot.channel))
        sqlite3_bind_text(statement, 6, (snapshot.band as NSString).utf8String, -1, nil)
        sqlite3_bind_double(statement, 7, snapshot.txRate)
        bindOptionalText(statement, index: 8, value: snapshot.bssid)
        sqlite3_bind_text(statement, 9, (snapshot.interfaceName as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 10, (snapshot.phyMode as NSString).utf8String, -1, nil)
        bindOptionalText(statement, index: 11, value: snapshot.ipv4)
        bindOptionalText(statement, index: 12, value: snapshot.ipv6)
        bindOptionalText(statement, index: 13, value: snapshot.gateway)
        bindOptionalText(statement, index: 14, value: snapshot.dnsServers)
        bindOptionalText(statement, index: 15, value: snapshot.clientMac)
        bindOptionalText(statement, index: 16, value: snapshot.securityType)
        
        sqlite3_step(statement)
        sqlite3_finalize(statement)
        }
    }
    
    private func bindOptionalText(_ statement: OpaquePointer?, index: Int32, value: String?) {
        if let value {
            sqlite3_bind_text(statement, index, (value as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }
    
    private func optionalText(from statement: OpaquePointer?, column: Int32) -> String? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
        return String(cString: sqlite3_column_text(statement, column))
    }
    
    func fetchReportData(from: Date, to: Date) -> ReportFetchResult {
        queue.sync {
            let results = (try? getPingResults(from: from, to: to)) ?? []
            let wifiSnapshots = (try? getWiFiSnapshots(from: from, to: to)) ?? []
            let rtos = (try? getRTOEvents(from: from, to: to)) ?? []
            let downtime = rtos.reduce(0) { $0 + $1.duration }
            return ReportFetchResult(results: results, wifiSnapshots: wifiSnapshots, totalDowntime: downtime)
        }
    }
    
    func getPingResults(from: Date, to: Date) throws -> [PingResult] {
        let sql = """
        SELECT id, session_id, target, timestamp, latency_ms, is_success, error_type
        FROM ping_results WHERE timestamp >= ? AND timestamp <= ? ORDER BY timestamp ASC;
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK { return [] }
        
        sqlite3_bind_double(statement, 1, from.timeIntervalSince1970)
        sqlite3_bind_double(statement, 2, to.timeIntervalSince1970)
        
        var results = [PingResult]()
        while sqlite3_step(statement) == SQLITE_ROW {
            let rowId = Int(sqlite3_column_int64(statement, 0))
            let sId = String(cString: sqlite3_column_text(statement, 1))
            let tgt = String(cString: sqlite3_column_text(statement, 2))
            let ts = Date(timeIntervalSince1970: sqlite3_column_double(statement, 3))
            
            var lat: Double? = nil
            if sqlite3_column_type(statement, 4) != SQLITE_NULL {
                lat = sqlite3_column_double(statement, 4)
            }
            
            let succ = sqlite3_column_int(statement, 5) != 0
            let errorRaw = optionalText(from: statement, column: 6) ?? ""
            let errorType: PingErrorType
            if succ {
                errorType = .none
            } else if errorRaw.isEmpty || errorRaw == PingErrorType.none.rawValue {
                errorType = .unknown
            } else {
                errorType = PingErrorType(rawValue: errorRaw) ?? .unknown
            }
            
            results.append(PingResult(
                id: stablePingId(rowId),
                sessionId: sId,
                target: tgt,
                timestamp: ts,
                latencyMs: lat,
                isSuccess: succ,
                errorType: errorType
            ))
        }
        sqlite3_finalize(statement)
        return results
    }
    
    private func stablePingId(_ rowId: Int) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        bytes[15] = UInt8(rowId & 0xFF)
        bytes[14] = UInt8((rowId >> 8) & 0xFF)
        bytes[13] = UInt8((rowId >> 16) & 0xFF)
        bytes[12] = UInt8((rowId >> 24) & 0xFF)
        bytes[11] = 0x70
        bytes[10] = 0x70
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
    
    func getRTOEvents(from: Date, to: Date) throws -> [(startedAt: Date, duration: TimeInterval, target: String)] {
        let sql = "SELECT started_at, duration_seconds, target FROM rto_events WHERE started_at >= ? AND started_at <= ? AND duration_seconds IS NOT NULL ORDER BY started_at ASC;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK { return [] }
        
        sqlite3_bind_double(statement, 1, from.timeIntervalSince1970)
        sqlite3_bind_double(statement, 2, to.timeIntervalSince1970)
        
        var results = [(Date, TimeInterval, String)]()
        while sqlite3_step(statement) == SQLITE_ROW {
            let ts = Date(timeIntervalSince1970: sqlite3_column_double(statement, 0))
            let dur = sqlite3_column_double(statement, 1)
            let tgt = String(cString: sqlite3_column_text(statement, 2))
            results.append((ts, dur, tgt))
        }
        sqlite3_finalize(statement)
        return results
    }
    
    func getWiFiSnapshots(from: Date, to: Date) throws -> [WiFiSnapshot] {
        let sql = """
        SELECT timestamp, ssid, rssi, noise, channel, band, tx_rate,
               bssid, interface_name, phy_mode, ipv4, ipv6, gateway, dns_servers, client_mac, security_type
        FROM wifi_snapshots WHERE timestamp >= ? AND timestamp <= ? ORDER BY timestamp ASC;
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK { return [] }
        
        sqlite3_bind_double(statement, 1, from.timeIntervalSince1970)
        sqlite3_bind_double(statement, 2, to.timeIntervalSince1970)
        
        var results = [WiFiSnapshot]()
        while sqlite3_step(statement) == SQLITE_ROW {
            let ts = Date(timeIntervalSince1970: sqlite3_column_double(statement, 0))
            let ssid = optionalText(from: statement, column: 1)
            let rssi = Int(sqlite3_column_int(statement, 2))
            let noise = Int(sqlite3_column_int(statement, 3))
            let channel = Int(sqlite3_column_int(statement, 4))
            let band = String(cString: sqlite3_column_text(statement, 5))
            let txRate = sqlite3_column_double(statement, 6)
            let bssid = optionalText(from: statement, column: 7)
            let interfaceName = optionalText(from: statement, column: 8) ?? "en0"
            let phyMode = optionalText(from: statement, column: 9) ?? ""
            let ipv4 = optionalText(from: statement, column: 10)
            let ipv6 = optionalText(from: statement, column: 11)
            let gateway = optionalText(from: statement, column: 12)
            let dnsServers = optionalText(from: statement, column: 13)
            let clientMac = optionalText(from: statement, column: 14)
            let securityType = optionalText(from: statement, column: 15)
            
            results.append(WiFiSnapshot(
                timestamp: ts,
                ssid: ssid,
                bssid: bssid,
                rssi: rssi,
                noise: noise,
                channel: channel,
                band: band,
                txRate: txRate,
                interfaceName: interfaceName,
                phyMode: phyMode,
                ipv4: ipv4,
                ipv6: ipv6,
                gateway: gateway,
                dnsServers: dnsServers,
                clientMac: clientMac,
                securityType: securityType
            ))
        }
        sqlite3_finalize(statement)
        return results
    }
}
