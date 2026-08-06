import Foundation

enum LocalProcessRunner {
    struct Result: Sendable {
        let status: Int32
        let stdout: Data
    }

    static func run(_ executable: String, arguments: [String]) throws -> Result {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Result(status: process.terminationStatus, stdout: data)
    }
}
