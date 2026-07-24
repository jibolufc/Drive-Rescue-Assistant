import Foundation

struct DriveRescueCLI {
    enum CLIError: Error, LocalizedError {
        case missingPython
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .missingPython:
                return "Python could not be found."
            case .failed(let message):
                return message
            }
        }
    }

    let projectRoot: URL

    final class ProcessRunner {
        private let process: Process
        private let outputPipe = Pipe()
        private let errorPipe = Pipe()
        private let acceptedExitCodes: Set<Int32>
        private let outputLock = NSLock()
        private var outputText = ""
        private var pendingLineText = ""

        init(
            executableURL: URL,
            arguments: [String],
            currentDirectoryURL: URL,
            environment: [String: String],
            acceptedExitCodes: Set<Int32> = [0]
        ) {
            process = Process()
            process.executableURL = executableURL
            process.arguments = arguments
            process.currentDirectoryURL = currentDirectoryURL
            process.environment = environment
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            self.acceptedExitCodes = acceptedExitCodes
        }

        func run(onOutputLine: ((String) -> Void)? = nil) async throws -> String {
            try await withCheckedThrowingContinuation { continuation in
                outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                    guard let self else { return }
                    let data = handle.availableData
                    guard !data.isEmpty else { return }
                    self.consumeOutput(data, onOutputLine: onOutputLine)
                }

                process.terminationHandler = { process in
                    self.outputPipe.fileHandleForReading.readabilityHandler = nil
                    let remainingOutput = self.outputPipe.fileHandleForReading.readDataToEndOfFile()
                    self.consumeOutput(remainingOutput, onOutputLine: onOutputLine)
                    self.flushPendingLine(onOutputLine: onOutputLine)
                    let output = self.collectedOutput()
                    let error = String(data: self.errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

                    if self.acceptedExitCodes.contains(process.terminationStatus) {
                        continuation.resume(returning: output)
                    } else {
                        let message = error.isEmpty ? output : error
                        continuation.resume(throwing: CLIError.failed(message.trimmingCharacters(in: .whitespacesAndNewlines)))
                    }
                }

                do {
                    try process.run()
                } catch {
                    self.outputPipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        }

        func cancel() {
            guard process.isRunning else { return }
            process.terminate()
        }

        private func consumeOutput(_ data: Data, onOutputLine: ((String) -> Void)?) {
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            var completedLines: [String] = []

            outputLock.lock()
            outputText += text
            pendingLineText += text
            while let newline = pendingLineText.firstIndex(of: "\n") {
                completedLines.append(String(pendingLineText[..<newline]))
                pendingLineText.removeSubrange(...newline)
            }
            outputLock.unlock()

            completedLines.forEach { onOutputLine?($0) }
        }

        private func flushPendingLine(onOutputLine: ((String) -> Void)?) {
            outputLock.lock()
            let pending = pendingLineText
            pendingLineText = ""
            outputLock.unlock()
            if !pending.isEmpty {
                onOutputLine?(pending)
            }
        }

        private func collectedOutput() -> String {
            outputLock.lock()
            defer { outputLock.unlock() }
            return outputText
        }
    }

    func scan() async throws -> [Drive] {
        let output = try await run(["-m", "drive_rescue", "scan", "--json"])
        return try JSONDecoder().decode([Drive].self, from: Data(output.utf8))
    }

    func extract(source: String, destination: String, dryRun: Bool, scope: ExtractionScope, compress: Bool) async throws -> String {
        let runner = try makeExtractionRunner(
            source: source,
            destination: destination,
            dryRun: dryRun,
            scope: scope,
            compress: compress,
            selectionFile: nil
        )
        return try await runner.run()
    }

    func makeExtractionRunner(
        source: String,
        destination: String,
        dryRun: Bool,
        scope: ExtractionScope,
        compress: Bool,
        selectionFile: URL?
    ) throws -> ProcessRunner {
        var args = ["-m", "drive_rescue", "extract", source, "--to", destination, "--events-json"]
        if dryRun {
            args.append("--dry-run")
        }
        args.append(contentsOf: ["--scope", scope.rawValue])
        if compress {
            args.append("--compress")
        }
        if let selectionFile {
            args.append(contentsOf: ["--selection-file", selectionFile.path])
        }
        let command = try command(for: args)
        return ProcessRunner(
            executableURL: command.executableURL,
            arguments: command.arguments,
            currentDirectoryURL: projectRoot,
            environment: [
                "PYTHONPATH": projectRoot.appendingPathComponent("src").path,
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
                "PYTHONUNBUFFERED": "1"
            ],
            acceptedExitCodes: [0, 2, 130]
        )
    }

    private func run(_ arguments: [String]) async throws -> String {
        let command = try command(for: arguments)
        let runner = ProcessRunner(
            executableURL: command.executableURL,
            arguments: command.arguments,
            currentDirectoryURL: projectRoot,
            environment: [
                "PYTHONPATH": projectRoot.appendingPathComponent("src").path,
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"
            ]
        )
        return try await runner.run()
    }

    private func command(for pythonArguments: [String]) throws -> (executableURL: URL, arguments: [String]) {
        if let resourceURL = Bundle.main.resourceURL {
            let helperURL = resourceURL.appendingPathComponent("DriveRescueEngine")
            if FileManager.default.isExecutableFile(atPath: helperURL.path) {
                let helperArguments = Array(pythonArguments.dropFirst(2))
                return (helperURL, helperArguments)
            }
        }

        let python = pythonExecutable()
        guard FileManager.default.fileExists(atPath: python) else {
            throw CLIError.missingPython
        }
        return (URL(fileURLWithPath: python), pythonArguments)
    }

    private func pythonExecutable() -> String {
        let bundled = "/Users/ayodele/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3"
        if FileManager.default.fileExists(atPath: bundled) {
            return bundled
        }
        return "/usr/bin/python3"
    }
}

struct DriveRescueCLIEvent: Decodable {
    let event: String
    let phase: String?
    let status: String?
    let currentPath: String?
    let filesCompleted: Int?
    let filesTotal: Int?
    let bytesCompleted: Int64?
    let bytesTotal: Int64?
    let currentSize: Int64?
    let filesSeen: Int?
    let filesMatched: Int?
    let filesFiltered: Int?
    let filesCopied: Int?
    let filesSkipped: Int?
    let filesFailed: Int?
    let bytesPlanned: Int64?
    let bytesCopied: Int64?
    let archivePath: String?
    let reportPath: String?
    let code: String?
    let message: String?
    let requiredBytes: Int64?
    let availableBytes: Int64?

    enum CodingKeys: String, CodingKey {
        case event, phase, status, code, message
        case currentPath = "current_path"
        case filesCompleted = "files_completed"
        case filesTotal = "files_total"
        case bytesCompleted = "bytes_completed"
        case bytesTotal = "bytes_total"
        case currentSize = "current_size"
        case filesSeen = "files_seen"
        case filesMatched = "files_matched"
        case filesFiltered = "files_filtered"
        case filesCopied = "files_copied"
        case filesSkipped = "files_skipped"
        case filesFailed = "files_failed"
        case bytesPlanned = "bytes_planned"
        case bytesCopied = "bytes_copied"
        case archivePath = "archive_path"
        case reportPath = "report_path"
        case requiredBytes = "required_bytes"
        case availableBytes = "available_bytes"
    }
}
