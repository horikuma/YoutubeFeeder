import Foundation

struct ChannelRegistryCSVImportRow: Hashable {
    let channelID: String
    let channelURL: String
    let channelTitle: String
}

enum ChannelRegistryCSVImportError: LocalizedError, Equatable {
    case emptyFile
    case invalidEncoding
    case invalidHeader
    case invalidRowFormat(rowNumber: Int)
    case missingChannelID(rowNumber: Int)

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "CSV に登録チャンネルが見つかりませんでした。"
        case .invalidEncoding:
            return "CSV を UTF-8 として読み込めませんでした。"
        case .invalidHeader:
            return "CSV ヘッダが想定と一致しません。`チャンネル ID`,`チャンネルの URL`,`チャンネルのタイトル` を確認してください。"
        case let .invalidRowFormat(rowNumber):
            return "CSV \(rowNumber) 行目の列数が不正です。"
        case let .missingChannelID(rowNumber):
            return "CSV \(rowNumber) 行目にチャンネル ID がありません。"
        }
    }
}

enum ChannelRegistryCSVImportParser {
    static let expectedHeader = [
        "チャンネル ID",
        "チャンネルの URL",
        "チャンネルのタイトル"
    ]

    static func parse(data: Data) throws -> [ChannelRegistryCSVImportRow] {
        guard !data.isEmpty else {
            throw ChannelRegistryCSVImportError.emptyFile
        }
        guard var text = String(data: data, encoding: .utf8) else {
            throw ChannelRegistryCSVImportError.invalidEncoding
        }
        if text.hasPrefix("\u{FEFF}") {
            text.removeFirst()
        }

        let rows = parseRows(text)
        guard let header = rows.first?.map(normalizeField), !header.isEmpty else {
            throw ChannelRegistryCSVImportError.emptyFile
        }
        guard header == expectedHeader else {
            throw ChannelRegistryCSVImportError.invalidHeader
        }

        var importedRows: [ChannelRegistryCSVImportRow] = []
        for (offset, rawRow) in rows.dropFirst().enumerated() {
            let rowNumber = offset + 2
            let row = rawRow.map(normalizeField)
            if row.allSatisfy(\.isEmpty) {
                continue
            }
            guard row.count == expectedHeader.count else {
                throw ChannelRegistryCSVImportError.invalidRowFormat(rowNumber: rowNumber)
            }

            let channelID = row[0]
            guard !channelID.isEmpty else {
                throw ChannelRegistryCSVImportError.missingChannelID(rowNumber: rowNumber)
            }

            importedRows.append(
                ChannelRegistryCSVImportRow(
                    channelID: channelID,
                    channelURL: row[1],
                    channelTitle: row[2]
                )
            )
        }

        guard !importedRows.isEmpty else {
            throw ChannelRegistryCSVImportError.emptyFile
        }
        return importedRows
    }

    private static func normalizeField(_ field: String) -> String {
        field.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseRows(_ text: String) -> [[String]] {
        let characters = Array(text)
        var index = 0
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var isInsideQuotes = false

        func finishField() {
            currentRow.append(currentField)
            currentField = ""
        }

        func finishRow() {
            finishField()
            rows.append(currentRow)
            currentRow = []
        }

        while index < characters.count {
            let character = characters[index]
            switch character {
            case "\"":
                if isInsideQuotes {
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        currentField.append("\"")
                        index += 1
                    } else {
                        isInsideQuotes = false
                    }
                } else {
                    isInsideQuotes = true
                }
            case ",":
                if isInsideQuotes {
                    currentField.append(character)
                } else {
                    finishField()
                }
            case "\n":
                if isInsideQuotes {
                    currentField.append(character)
                } else {
                    finishRow()
                }
            case "\r":
                if isInsideQuotes {
                    currentField.append(character)
                } else {
                    finishRow()
                    if index + 1 < characters.count, characters[index + 1] == "\n" {
                        index += 1
                    }
                }
            default:
                currentField.append(character)
            }
            index += 1
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            finishRow()
        }

        return rows
    }
}

struct ChannelRegistryCSVImportResult: Hashable {
    let fileURL: URL
    let totalRowCount: Int
    let importedCount: Int
    let alreadyRegisteredCount: Int
    let importedChannelIDs: [String]
}

enum ChannelRegistryCSVImportService {
    static func importChannels(
        data: Data,
        fileURL: URL,
        fileManager: FileManager = .default
    ) throws -> ChannelRegistryCSVImportResult {
        let rows = try ChannelRegistryCSVImportParser.parse(data: data)
        var importedChannelIDs: [String] = []

        for row in rows where try ChannelRegistryStore.addChannelID(row.channelID, fileManager: fileManager, source: "csv_import") {
            importedChannelIDs.append(row.channelID)
        }

        return ChannelRegistryCSVImportResult(
            fileURL: fileURL,
            totalRowCount: rows.count,
            importedCount: importedChannelIDs.count,
            alreadyRegisteredCount: rows.count - importedChannelIDs.count,
            importedChannelIDs: importedChannelIDs
        )
    }
}
