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

    func scan() async throws -> [Drive] {
        let output = try await run(["-m", "drive_rescue", "scan", "--json"])
        return try JSONDecoder().decode([Drive].self, from: Data(output.utf8))
    }

    func extract(source: String, destination: String, dryRun: Bool, scope: ExtractionScope, compress: Bool) async throws -> String {
        var args = ["-m", "drive_rescue", "extract", source, "--to", destination]
        if dryRun {
            args.append("--dry-run")
        }
        args.append(contentsOf: ["--scope", scope.rawValue])
        if compress {
            args.append("--compress")
        }
        return try await run(args)
    }

    private func run(_ arguments: [String]) async throws -> String {
        let python = pythonExecutable()
        guard FileManager.default.fileExists(atPath: python) else {
            throw CLIError.missingPython
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: python)
            process.arguments = arguments
            process.currentDirectoryURL = projectRoot
            process.environment = [
                "PYTHONPATH": projectRoot.appendingPathComponent("src").path,
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"
            ]
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            process.terminationHandler = { process in
                let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    let message = error.isEmpty ? output : error
                    continuation.resume(throwing: CLIError.failed(message.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func pythonExecutable() -> String {
        let bundled = "/Users/ayodele/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3"
        if FileManager.default.fileExists(atPath: bundled) {
            return bundled
        }
        return "/usr/bin/python3"
    }
}
