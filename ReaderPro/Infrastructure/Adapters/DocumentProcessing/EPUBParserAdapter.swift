import Foundation
import AppKit
import ZIPFoundation

/// Adaptador para parsear documentos EPUB
/// Descomprime el archivo, parsea la estructura OPF/spine, y extrae texto de cada capítulo
final class EPUBParserAdapter: DocumentParserPort {

    // MARK: - DocumentParserPort

    var supportedExtensions: [String] { ["epub"] }

    func extractSections(from url: URL) async throws -> [DocumentSection] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DocumentParserError.fileNotFound(url.path)
        }

        // 1. Create temp directory and unzip
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("epub_\(UUID().uuidString)")

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        do {
            try FileManager.default.unzipItem(at: url, to: tempDir)
        } catch {
            throw DocumentParserError.invalidDocument("Failed to unzip EPUB: \(error.localizedDescription)")
        }

        // 2. Parse container.xml to find OPF path
        let containerURL = tempDir
            .appendingPathComponent("META-INF")
            .appendingPathComponent("container.xml")

        guard FileManager.default.fileExists(atPath: containerURL.path) else {
            throw DocumentParserError.epubParsingFailed("META-INF/container.xml not found")
        }

        let containerData = try Data(contentsOf: containerURL)
        let opfRelativePath = try parseContainerXML(data: containerData)

        // 3. Parse OPF to get spine order and manifest
        let opfURL = tempDir.appendingPathComponent(opfRelativePath)
        let opfBaseURL = opfURL.deletingLastPathComponent()

        guard FileManager.default.fileExists(atPath: opfURL.path) else {
            throw DocumentParserError.epubParsingFailed("OPF file not found: \(opfRelativePath)")
        }

        let opfData = try Data(contentsOf: opfURL)
        let spineItems = try parseOPF(data: opfData)

        guard !spineItems.isEmpty else {
            throw DocumentParserError.noTextContent
        }

        // 4. Extract text from each spine item
        var sections: [DocumentSection] = []
        var chapterNumber = 0

        for item in spineItems {
            let contentURL = opfBaseURL.appendingPathComponent(item.href)

            guard FileManager.default.fileExists(atPath: contentURL.path) else {
                continue
            }

            do {
                let htmlData = try Data(contentsOf: contentURL)
                let text = extractTextFromHTML(data: htmlData)

                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continue
                }

                chapterNumber += 1
                let title = item.title.isEmpty ? "Chapter \(chapterNumber)" : item.title

                let section = try DocumentSection(
                    title: title,
                    text: text,
                    pageNumber: chapterNumber
                )
                sections.append(section)
            } catch {
                // Skip sections that fail
                continue
            }
        }

        guard !sections.isEmpty else {
            throw DocumentParserError.noTextContent
        }

        return sections
    }

    // MARK: - Private: Container XML Parsing

    /// Parses container.xml to extract the OPF file path
    private func parseContainerXML(data: Data) throws -> String {
        let parser = ContainerXMLParser(data: data)
        guard let opfPath = parser.parse() else {
            throw DocumentParserError.epubParsingFailed("Could not find rootfile in container.xml")
        }
        return opfPath
    }

    // MARK: - Private: OPF Parsing

    /// Parses OPF file to extract spine items with their content hrefs
    private func parseOPF(data: Data) throws -> [SpineItem] {
        let parser = OPFParser(data: data)
        let items = parser.parse()
        guard !items.isEmpty else {
            throw DocumentParserError.epubParsingFailed("No spine items found in OPF")
        }
        return items
    }

    // MARK: - Private: HTML Text Extraction

    /// Extracts plain text from HTML/XHTML data
    private func extractTextFromHTML(data: Data) -> String {
        // Try NSAttributedString HTML conversion
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributedString.string
        }

        // Fallback: basic tag stripping
        if let htmlString = String(data: data, encoding: .utf8) {
            return stripHTMLTags(htmlString)
        }

        return ""
    }

    /// Basic HTML tag stripping as fallback
    private func stripHTMLTags(_ html: String) -> String {
        var result = html
        // Remove script and style blocks
        result = result.replacingOccurrences(
            of: "<(script|style)[^>]*>[\\s\\S]*?</\\1>",
            with: "",
            options: .regularExpression
        )
        // Remove HTML tags
        result = result.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )
        // Clean up whitespace
        result = result.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - SpineItem

/// Represents a content item from the EPUB spine
struct SpineItem {
    let href: String
    let title: String
}

// MARK: - ContainerXMLParser

/// XMLParser delegate for container.xml
private class ContainerXMLParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var opfPath: String?

    init(data: Data) {
        self.data = data
    }

    func parse() -> String? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return opfPath
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "rootfile" || elementName.hasSuffix(":rootfile") {
            opfPath = attributeDict["full-path"]
        }
    }
}

// MARK: - OPFParser

/// XMLParser delegate for OPF package files
private class OPFParser: NSObject, XMLParserDelegate {
    private let data: Data

    // Manifest: id -> href mapping
    private var manifest: [String: String] = [:]
    // Spine: ordered list of idref values
    private var spineIdrefs: [String] = []
    // Metadata: title extracted from dc:title
    private var titles: [String: String] = [:]

    private var currentElement = ""
    private var currentText = ""
    private var insideMetadata = false

    init(data: Data) {
        self.data = data
    }

    func parse() -> [SpineItem] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        return spineIdrefs.compactMap { idref in
            guard let href = manifest[idref] else { return nil }
            return SpineItem(href: href, title: "")
        }
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName

        if localName == "item" {
            if let id = attributeDict["id"], let href = attributeDict["href"] {
                let mediaType = attributeDict["media-type"] ?? ""
                // Only include XHTML/HTML content
                if mediaType.contains("html") || mediaType.contains("xml") {
                    manifest[id] = href
                }
            }
        } else if localName == "itemref" {
            if let idref = attributeDict["idref"] {
                spineIdrefs.append(idref)
            }
        }
    }
}
