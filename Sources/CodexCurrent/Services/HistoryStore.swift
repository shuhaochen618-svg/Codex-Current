import Foundation

actor HistoryStore {
    struct Archive: Codable, Equatable, Sendable {
        var rateLimitSamples: [RateLimitSample] = []
        var dailyUsage: [DailyUsageBucket] = []
    }

    private let fileManager: FileManager
    private let fileURL: URL
    private let legacyFileURL: URL?
    private var archive: Archive

    init(
        fileManager: FileManager = .default,
        directory: URL? = nil,
        legacyDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        let applicationSupportDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let baseDirectory = directory ?? applicationSupportDirectory
            .appendingPathComponent("CodexCurrent", isDirectory: true)
        let resolvedLegacyDirectory: URL?
        if let legacyDirectory {
            resolvedLegacyDirectory = legacyDirectory
        } else if directory == nil {
            resolvedLegacyDirectory = applicationSupportDirectory
                .appendingPathComponent("CodexBar", isDirectory: true)
        } else {
            resolvedLegacyDirectory = nil
        }

        fileURL = baseDirectory.appendingPathComponent("history.json")
        legacyFileURL = resolvedLegacyDirectory?.appendingPathComponent("history.json")

        let sourceURL: URL
        if fileManager.fileExists(atPath: fileURL.path) {
            sourceURL = fileURL
        } else if let legacyFileURL, fileManager.fileExists(atPath: legacyFileURL.path) {
            sourceURL = legacyFileURL
        } else {
            sourceURL = fileURL
        }

        if
            let data = try? Data(contentsOf: sourceURL),
            let decoded = try? JSONDecoder.codexCurrent.decode(Archive.self, from: data)
        {
            archive = decoded
        } else {
            archive = Archive()
        }
    }

    func current() -> Archive {
        archive
    }

    func record(windows: [DisplayRateLimitWindow], usage: TokenUsageResponse?) throws {
        let now = Date()
        for window in windows {
            let sample = RateLimitSample(
                windowID: window.id,
                capturedAt: now,
                usedPercent: window.usedPercent,
                resetAt: window.resetAt
            )

            let last = archive.rateLimitSamples.last { $0.windowID == window.id }
            let isMeaningful = last == nil
                || last?.usedPercent != sample.usedPercent
                || last?.resetAt != sample.resetAt
                || now.timeIntervalSince(last?.capturedAt ?? .distantPast) >= 600
            if isMeaningful {
                archive.rateLimitSamples.append(sample)
            }
        }

        if let buckets = usage?.dailyUsageBuckets {
            var byDate = Dictionary(uniqueKeysWithValues: archive.dailyUsage.map { ($0.startDate, $0) })
            for bucket in buckets {
                byDate[bucket.startDate] = bucket
            }
            archive.dailyUsage = byDate.values.sorted { $0.startDate < $1.startDate }
        }
        try persist()
    }

    func clear() throws {
        archive = Archive()
        for url in [fileURL, legacyFileURL].compactMap({ $0 }) {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    private func persist() throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.codexCurrent.encode(archive)
        try data.write(to: fileURL, options: .atomic)
    }
}

private extension JSONEncoder {
    static var codexCurrent: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var codexCurrent: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
