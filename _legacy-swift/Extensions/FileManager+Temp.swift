import Foundation

extension FileManager {
    /// Returns a unique, empty temporary directory for a single export session.
    func makeUniqueTemporaryDirectory() throws -> URL {
        let url = temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
