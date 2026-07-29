import Foundation

public struct RussianWorkCalendarCacheEntry: Sendable, Equatable {
    public let rawData: Data
    public let fetchedAt: Date

    public init(rawData: Data, fetchedAt: Date) {
        self.rawData = rawData
        self.fetchedAt = fetchedAt
    }
}

public protocol RussianWorkCalendarCaching: Sendable {
    func load(year: Int) async throws -> RussianWorkCalendarCacheEntry?
    func save(rawData: Data, for year: Int, fetchedAt: Date) async throws
}

public actor RussianWorkCalendarCache: RussianWorkCalendarCaching {
    public enum CacheError: Error, Equatable, Sendable {
        case invalidYear(Int)
        case cachesDirectoryUnavailable
    }

    private let directory: URL
    private let fileManager: FileManager

    public init(
        directory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.directory = directory
            ?? fileManager.urls(
                for: .cachesDirectory,
                in: .userDomainMask
            ).first?
                .appendingPathComponent("QuickCal", isDirectory: true)
                .appendingPathComponent("work-calendar", isDirectory: true)
            ?? fileManager.temporaryDirectory
                .appendingPathComponent("QuickCal", isDirectory: true)
                .appendingPathComponent("work-calendar", isDirectory: true)
    }

    public func load(
        year: Int
    ) async throws -> RussianWorkCalendarCacheEntry? {
        let fileURL = try fileURL(for: year)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let rawData = try Data(contentsOf: fileURL)
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        let fetchedAt = attributes[.modificationDate] as? Date
            ?? .distantPast
        return RussianWorkCalendarCacheEntry(
            rawData: rawData,
            fetchedAt: fetchedAt
        )
    }

    public func save(
        rawData: Data,
        for year: Int,
        fetchedAt: Date
    ) async throws {
        let fileURL = try fileURL(for: year)
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try rawData.write(to: fileURL, options: .atomic)
        try fileManager.setAttributes(
            [.modificationDate: fetchedAt],
            ofItemAtPath: fileURL.path
        )
    }

    private func fileURL(for year: Int) throws -> URL {
        guard (1...9999).contains(year) else {
            throw CacheError.invalidYear(year)
        }
        return directory.appendingPathComponent(
            "\(year).txt",
            isDirectory: false
        )
    }
}
