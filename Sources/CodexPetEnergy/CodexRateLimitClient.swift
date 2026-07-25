import Foundation

final class CodexRateLimitClient {
    var onSnapshot: ((RateLimitReadResult) -> Void)?
    var onUnavailable: (() -> Void)?

    private let ioQueue = DispatchQueue(label: "codex.pet.energy.rpc")
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var outputBuffer = Data()
    private var refreshTimer: DispatchSourceTimer?
    private var reconnectWorkItem: DispatchWorkItem?
    private var stopped = false
    private var reconnectAttempt = 0
    private var nextSnapshotRequestID = 2
    private var pendingSnapshotRequestIDs: Set<Int> = []
    private var latestReadResult: RateLimitReadResult?

    func start() {
        ioQueue.async { [weak self] in
            self?.stopped = false
            self?.connect()
        }
    }

    func stop() {
        ioQueue.async { [weak self] in
            guard let self else { return }
            self.stopped = true
            self.reconnectWorkItem?.cancel()
            self.refreshTimer?.cancel()
            let runningProcess = self.process
            runningProcess?.terminationHandler = nil
            self.cleanupProcess()
            runningProcess?.terminate()
        }
    }

    private func connect() {
        guard !stopped, process == nil else { return }
        guard let executable = Self.findCodexExecutable() else {
            publishUnavailable()
            scheduleReconnect()
            return
        }

        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.executableURL = executable
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        self.process = process
        input = stdinPipe.fileHandleForWriting
        output = stdoutPipe.fileHandleForReading
        outputBuffer.removeAll(keepingCapacity: true)

        output?.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.ioQueue.async { self?.consume(data) }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
        process.terminationHandler = { [weak self] _ in
            self?.ioQueue.async {
                guard let self, !self.stopped else { return }
                self.cleanupProcess()
                self.publishUnavailable()
                self.scheduleReconnect()
            }
        }

        do {
            try process.run()
            send([
                "method": "initialize",
                "id": 1,
                "params": [
                    "clientInfo": [
                        "name": "codex-pet-energy",
                        "title": "Codex 算力条",
                        "version": "1.0.0",
                    ],
                    "capabilities": [
                        "experimentalApi": false,
                        "requestAttestation": false,
                    ],
                ],
            ])
        } catch {
            cleanupProcess()
            publishUnavailable()
            scheduleReconnect()
        }
    }

    private func consume(_ data: Data) {
        outputBuffer.append(data)
        while let newline = outputBuffer.firstIndex(of: 0x0A) {
            let line = outputBuffer[..<newline]
            outputBuffer.removeSubrange(...newline)
            guard !line.isEmpty,
                  let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any]
            else { continue }
            handle(object)
        }
    }

    private func handle(_ message: [String: Any]) {
        if (message["id"] as? Int) == 1, message["result"] != nil {
            send(["method": "initialized"])
            requestSnapshot()
            startRefreshTimer()
            return
        }

        if (message["id"] as? Int) == 1, message["error"] != nil {
            handleConnectionFailure()
            return
        }

        if let id = message["id"] as? Int, pendingSnapshotRequestIDs.remove(id) != nil {
            guard message["error"] == nil,
                  let result = message["result"],
                  let decoded: RateLimitReadResult = decode(result)
            else {
                publishUnavailable()
                return
            }
            reconnectAttempt = 0
            latestReadResult = decoded
            publish(decoded)
            return
        }

        if (message["method"] as? String) == "account/rateLimits/updated",
           let params = message["params"] as? [String: Any],
           let snapshotObject = params["rateLimits"],
           let update: RateLimitSnapshot = decode(snapshotObject) {
            guard let latestReadResult else {
                requestSnapshot()
                return
            }
            guard let merged = EnergyLogic.mergingSparseUpdate(
                update,
                into: latestReadResult
            ) else {
                requestSnapshot()
                return
            }
            self.latestReadResult = merged
            publish(merged)
            return
        }
    }

    private func requestSnapshot() {
        let requestID = nextSnapshotRequestID
        nextSnapshotRequestID += 1
        pendingSnapshotRequestIDs.insert(requestID)
        send(["method": "account/rateLimits/read", "id": requestID])
    }

    private func startRefreshTimer() {
        refreshTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: ioQueue)
        timer.schedule(deadline: .now() + 60, repeating: 60)
        timer.setEventHandler { [weak self] in self?.requestSnapshot() }
        timer.resume()
        refreshTimer = timer
    }

    private func send(_ object: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object),
              let input
        else { return }
        var line = data
        line.append(0x0A)
        do {
            try input.write(contentsOf: line)
        } catch {
            handleConnectionFailure()
        }
    }

    private func decode<T: Decodable>(_ object: Any) -> T? {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object)
        else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func publish(_ result: RateLimitReadResult) {
        DispatchQueue.main.async { [weak self] in self?.onSnapshot?(result) }
    }

    private func publishUnavailable() {
        DispatchQueue.main.async { [weak self] in self?.onUnavailable?() }
    }

    private func scheduleReconnect() {
        guard !stopped else { return }
        reconnectWorkItem?.cancel()
        reconnectAttempt += 1
        let delays: [TimeInterval] = [2, 5, 15, 30]
        let delay = delays[min(reconnectAttempt - 1, delays.count - 1)]
        let item = DispatchWorkItem { [weak self] in self?.connect() }
        reconnectWorkItem = item
        ioQueue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func cleanupProcess() {
        refreshTimer?.cancel()
        refreshTimer = nil
        output?.readabilityHandler = nil
        output = nil
        input = nil
        process = nil
        latestReadResult = nil
        pendingSnapshotRequestIDs.removeAll(keepingCapacity: true)
        outputBuffer.removeAll(keepingCapacity: true)
    }

    private func handleConnectionFailure() {
        guard !stopped else { return }
        let failedProcess = process
        failedProcess?.terminationHandler = nil
        cleanupProcess()
        failedProcess?.terminate()
        publishUnavailable()
        scheduleReconnect()
    }

    static func findCodexExecutable() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/codex"),
            home.appendingPathComponent(".codex/packages/standalone/current/codex"),
            home.appendingPathComponent(".local/bin/codex"),
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
