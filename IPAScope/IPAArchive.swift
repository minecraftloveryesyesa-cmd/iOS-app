
import Foundation
import ZIPFoundation

struct IPAFile: Identifiable, Hashable {
    let id: String
    let path: String
    let size: Int

    var name: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var isDirectory: Bool {
        path.hasSuffix("/")
    }
}

struct AppMetadata {
    var name = "—"
    var bundleID = "—"
    var version = "—"
    var build = "—"
}

enum IPAArchiveError: LocalizedError {
    case invalidArchive
    case missingInfoPlist
    case unreadablePlist

    var errorDescription: String? {
        switch self {
        case .invalidArchive:
            return "IPAをZIPとして開けませんでした。"
        case .missingInfoPlist:
            return "Payload内にInfo.plistが見つかりませんでした。"
        case .unreadablePlist:
            return "Info.plistを読み取れませんでした。"
        }
    }
}

final class IPAArchive {
    let url: URL
    private let archive: Archive
    let files: [IPAFile]
    let metadata: AppMetadata

    init(url: URL) throws {
        self.url = url

        guard let zip = Archive(
            url: url,
            accessMode: .read
        ) else {
            throw IPAArchiveError.invalidArchive
        }

        self.archive = zip

        self.files = zip.map { entry in
            IPAFile(
                id: entry.path,
                path: entry.path,
                size: Int(entry.uncompressedSize)
            )
        }.sorted {
            $0.path.localizedStandardCompare($1.path)
                == .orderedAscending
        }

        self.metadata = try Self.readMetadata(from: zip)
    }

    private static func readMetadata(
        from archive: Archive
    ) throws -> AppMetadata {
        guard let entry = archive.first(where: {
            $0.path.hasPrefix("Payload/")
            && $0.path.hasSuffix(".app/Info.plist")
            && !$0.path.contains("/PlugIns/")
            && !$0.path.contains("/Watch/")
        }) else {
            throw IPAArchiveError.missingInfoPlist
        }

        var data = Data()

        _ = try archive.extract(entry) {
            data.append($0)
        }

        guard let dict = try PropertyListSerialization
            .propertyList(
                from: data,
                options: [],
                format: nil
            ) as? [String: Any] else {
            throw IPAArchiveError.unreadablePlist
        }

        var result = AppMetadata()

        result.name =
            (dict["CFBundleDisplayName"] as? String)
            ?? (dict["CFBundleName"] as? String)
            ?? "—"

        result.bundleID =
            dict["CFBundleIdentifier"] as? String ?? "—"

        result.version =
            dict["CFBundleShortVersionString"] as? String ?? "—"

        result.build =
            dict["CFBundleVersion"] as? String ?? "—"

        return result
    }

    func readTextFile(
        path: String,
        maximumBytes: Int = 1_500_000
    ) throws -> String {
        guard let entry = archive[path] else {
            throw CocoaError(.fileNoSuchFile)
        }

        guard entry.uncompressedSize <= maximumBytes else {
            throw CocoaError(.fileReadTooLarge)
        }

        var data = Data()

        _ = try archive.extract(entry) {
            data.append($0)
        }

        guard let text =
            String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16) else {
            throw CocoaError(
                .fileReadInapplicableStringEncoding
            )
        }

        return text
    }
}
