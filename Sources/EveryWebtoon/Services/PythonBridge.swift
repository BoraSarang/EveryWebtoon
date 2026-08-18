import Foundation

final class PythonBridge {
    static let shared = PythonBridge()

    private let queue = DispatchQueue(label: "com.everywebtoon.python", attributes: .concurrent)
    private let idLock = NSLock()
    private var requestId = 0
    private var activeProcesses: [String: Process] = [:]
    private let pythonPath: String
    private let scriptPath: String

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let devPath = "\(home)/Documents/Apps/EveryWebtoon"

        let venvPython = "\(devPath)/.venv/bin/python3"
        if FileManager.default.fileExists(atPath: venvPython) {
            pythonPath = venvPython
        } else {
            pythonPath = "/usr/bin/python3"
        }

        let backendScript = "\(devPath)/backend/main.py"
        scriptPath = backendScript

        DebugLogger.shared.push(.SYSTEM, category: "PythonBridge",
            message: "초기화",
            meta: ["python": pythonPath, "script": scriptPath])
    }

    func call(
        action: String,
        params: [String: Any] = [:],
        onProgress: ((DownloadProgress) -> Void)? = nil,
        taskId: String? = nil,
        timeout: TimeInterval = 30
    ) async throws -> Any {
        let id = taskId ?? nextId()
        let request: [String: Any] = ["id": id, "action": action, "params": params]
        let requestData = try JSONSerialization.data(withJSONObject: request)
        guard var requestStr = String(data: requestData, encoding: .utf8) else {
            throw PythonBridgeError.serializationFailed
        }
        requestStr += "\n"

        DebugLogger.shared.push(.API_REQ, category: "PythonBridge",
            message: "\(action)",
            meta: ["id": id])

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    do {
                        var lastError: Error?
                        let attempts = action == "download_episode" ? 1 : 2
                        for attempt in 1...attempts {
                            do {
                                let result = try self.syncCall(
                                    request: requestStr,
                                    id: "\(id)-\(attempt)",
                                    registerKey: id,
                                    onProgress: onProgress,
                                    timeout: timeout
                                )
                                DispatchQueue.main.async { continuation.resume(returning: result) }
                                return
                            } catch {
                                lastError = error
                                if attempt < attempts {
                                    DebugLogger.shared.push(.WARN, category: "PythonBridge",
                                        message: "\(action) 재시도 (\(attempt+1)/\(attempts))",
                                        meta: "\(error.localizedDescription)")
                                }
                            }
                        }
                        throw lastError ?? PythonBridgeError.noResult
                    } catch {
                        DispatchQueue.main.async { continuation.resume(throwing: error) }
                    }
                }
            }
        } onCancel: {
            self.idLock.lock()
            let process = self.activeProcesses[id]
            self.idLock.unlock()
            process?.terminate()
        }
    }

    func cancel(taskId: String) {
        idLock.lock()
        let process = activeProcesses[taskId]
        idLock.unlock()
        if let process, process.isRunning {
            DebugLogger.shared.push(.ACTION, category: "PythonBridge",
                message: "cancel \(taskId)")
            process.terminate()
        }
    }

    // MARK: - 공용 응답 파싱

    private func parseResponse(
        line: String,
        onProgress: ((DownloadProgress) -> Void)?
    ) -> (result: Any?, error: PythonBridgeError?) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return (nil, nil) }

        let type = json["type"] as? String ?? ""
        let dataObj = json["data"]

        if type == "progress", let onProgress, let d = dataObj as? [String: Any] {
            let progress = DownloadProgress(
                taskId: d["task_id"] as? String ?? "",
                episodeNo: d["episode_no"] as? Int ?? 0,
                currentPage: d["current_page"] as? Int ?? 0,
                totalPages: d["total_pages"] as? Int ?? 0,
                speed: d["speed"] as? String ?? "",
                eta: d["eta"] as? String ?? "",
                status: d["status"] as? String ?? "",
                currentBytes: d["current_bytes"] as? Int ?? 0,
                totalBytes: d["total_bytes"] as? Int ?? 0
            )
            DispatchQueue.main.async {
                onProgress(progress)
            }
        } else if type == "result" {
            return (dataObj, nil)
        } else if type == "error" {
            let msg = (dataObj as? [String: Any])?["message"] as? String ?? "Unknown error"
            if msg.contains("AdultVerification") {
                DebugLogger.shared.push(.WARN, category: "PythonBridge",
                    message: "adult webtoon skipped",
                    meta: msg)
            } else {
                DebugLogger.shared.push(.ERROR, category: "PythonBridge",
                    message: "failed",
                    meta: msg)
            }
            return (nil, PythonBridgeError.backendError(msg))
        }
        return (nil, nil)
    }

    // MARK: - macOS: Process-based synchronous call

    private func syncCall(
        request: String,
        id: String,
        registerKey: String? = nil,
        onProgress: ((DownloadProgress) -> Void)?,
        timeout: TimeInterval = 30
    ) throws -> Any {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [scriptPath]

        if let registerKey {
            idLock.lock()
            activeProcesses[registerKey] = process
            idLock.unlock()
        }
        defer {
            if let registerKey {
                idLock.lock()
                activeProcesses.removeValue(forKey: registerKey)
                idLock.unlock()
            }
        }

        process.environment = [
            "EVERYWEBTOON_OUTPUT": AppPaths.basePath,
            "PYTHONUNBUFFERED": "1",
        ]

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        inputPipe.fileHandleForWriting.write(request.data(using: .utf8)!)
        inputPipe.fileHandleForWriting.closeFile()

        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading

        var errorStr = ""
        var outStr = ""
        var lastResult: Any?
        var backendError: PythonBridgeError?

        let startTime = Date()
        let done = DispatchSemaphore(value: 0)
        let readQueue = DispatchQueue(label: "com.everywebtoon.read-\(id)", qos: .userInitiated)

        readQueue.async {
            var pending = Data()
            while true {
                let data = outputHandle.availableData
                if data.isEmpty { break }
                pending.append(data)

                while let nl = pending.firstIndex(of: 0x0A) {
                    let lineData = Data(pending[pending.startIndex..<nl])
                    pending.removeSubrange(pending.startIndex...nl)
                    if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
                        let parsed = self.parseResponse(line: line, onProgress: onProgress)
                        if let result = parsed.result { lastResult = result }
                        if let err = parsed.error { backendError = err }
                    }
                }
                if outStr.count < 2000 {
                    outStr += String(decoding: data, as: UTF8.self)
                }
            }
            if let rest = String(data: pending, encoding: .utf8), !rest.isEmpty {
                let parsed = self.parseResponse(line: rest, onProgress: onProgress)
                if let result = parsed.result { lastResult = result }
                if let err = parsed.error { backendError = err }
            }
            done.signal()
        }

        let errGroup = DispatchGroup()
        errGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            let data = errorHandle.readDataToEndOfFile()
            errorStr = String(data: data, encoding: .utf8) ?? ""
            errGroup.leave()
        }

        if done.wait(timeout: .now() + .seconds(Int(timeout))) == .timedOut {
            process.terminate()
            DebugLogger.shared.push(.ERROR, category: "PythonBridge",
                message: "timeout (\(id))")
            throw PythonBridgeError.timeout
        }

        if let backendError {
            process.terminate()
            throw backendError
        }

        process.waitUntilExit()

        if process.terminationStatus != 0 {
            errGroup.wait(timeout: .now() + .seconds(3))
            DebugLogger.shared.push(.ERROR, category: "PythonBridge",
                message: "exit code \(process.terminationStatus)",
                meta: errorStr)
            throw PythonBridgeError.processError(
                code: process.terminationStatus,
                stderr: errorStr
            )
        }

        if let result = lastResult {
            return result
        }
        let elapsedMs = Int(Date().timeIntervalSince(startTime) * 1000)
        DebugLogger.shared.push(.ERROR, category: "PythonBridge",
            message: "noResult (\(id)) exit=\(process.terminationStatus) elapsed=\(elapsedMs)ms",
            meta: ["out": String(outStr.prefix(500)), "err": String(errorStr.prefix(500))])
        throw PythonBridgeError.noResult
    }

    private func nextId() -> String {
        idLock.lock()
        defer { idLock.unlock() }
        requestId += 1
        return "swift-\(requestId)"
    }

    enum PythonBridgeError: Error, LocalizedError {
        case serializationFailed
        case invalidOutput
        case backendError(String)
        case noResult
        case timeout
        case processError(code: Int32, stderr: String)

        var errorDescription: String? {
            switch self {
            case .serializationFailed: return "Failed to serialize request"
            case .invalidOutput: return "Invalid output from Python backend"
            case .backendError(let msg): return msg
            case .noResult: return "No result from Python backend"
            case .timeout: return "Python backend timed out"
            case .processError(let code, let stderr): return "Python exited (\(code)): \(stderr)"
            }
        }
    }
}
