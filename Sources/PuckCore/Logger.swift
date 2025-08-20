import Foundation
import Logging

public enum PuckLogger {
    private static var configured = false
    private static var label = "com.puck"

    public static var shared: Logger = {
        Logger(label: label)
    }()

    public static func configure(level: Logger.Level, toFile filePath: String?) {
        guard !configured else {
            shared.logLevel = level
            return
        }
        configured = true
        if let filePath = filePath {
            FileLogHandler.installGlobal(to: filePath)
        }
        shared.logLevel = level
    }
}

// File-backed LogHandler for swift-log
final class FileLogHandler: LogHandler {
    private static var fileHandle: FileHandle?
    private static let queue = DispatchQueue(label: "com.puck.logger")

    static func installGlobal(to path: String) {
        queue.sync {
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            let directoryURL = url.deletingLastPathComponent()
            let fm = FileManager.default
            if !fm.fileExists(atPath: directoryURL.path) {
                try? fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }
            if !fm.fileExists(atPath: url.path) {
                fm.createFile(atPath: url.path, contents: nil)
            }
            do {
                fileHandle = try FileHandle(forWritingTo: url)
                try fileHandle?.seekToEnd()
            } catch {
                fileHandle = nil
            }
        }
        LoggingSystem.bootstrap { label in FileLogHandler(label: label) }
    }

    var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level = .info
    private let label: String

    init(label: String) {
        self.label = label
    }

    subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get { metadata[metadataKey] }
        set { metadata[metadataKey] = newValue }
    }

    func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let metaString = metadata?.map { "\($0)=\($1)" }.joined(separator: " ") ?? ""
        let line = "[\(timestamp)] [\(level)] [\(label)] \(message) \(metaString)\n"
        if let fh = FileLogHandler.fileHandle {
            FileLogHandler.queue.async {
                if let data = line.data(using: .utf8) {
                    try? fh.write(contentsOf: data)
                }
            }
        } else {
            fputs(line, stderr)
        }
    }
}


