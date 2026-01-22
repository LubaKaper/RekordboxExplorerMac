//
//  PDFExportService.swift
//  RekordboxExploreriOS
//
//  Created by Liubov Kaper  on 1/20/26.
//

import Foundation
import CoreGraphics

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum PDFExportError: Error {
    case failedToCreateContext
}

struct PDFTrackRow: Sendable {
    let title: String
    let artist: String
    let album: String
    let bpm: Double
    let duration: Int
}

struct PDFExportService {

    /// Builds a simple paginated PDF table of tracks.
    /// Columns: Title, Artist, Album, BPM, Duration
    /// (No Key, no FilePath)
    static func makeTracksPDF(
        title: String,
        subtitle: String? = nil,
        tracks: [Track]
    ) throws -> Data {

        // US Letter: 8.5 x 11 in @ 72 dpi
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)

        #if os(iOS)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { ctx in
            renderPDF(
                pageRect: pageRect,
                beginPage: { ctx.beginPage() },
                drawText: { text, rect, style in
                    let attrs = style.uiAttributes
                    (text as NSString).draw(in: rect, withAttributes: attrs)
                },
                title: title,
                subtitle: subtitle,
                tracks: tracks
            )
        }
        #elseif os(macOS)
        let data = NSMutableData()

        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let pdf = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            throw PDFExportError.failedToCreateContext
        }

        renderPDF(
            pageRect: pageRect,

            beginPage: {
                pdf.beginPDFPage([kCGPDFContextMediaBox as String: pageRect] as CFDictionary)

                // ✅ Important: save state so the flip doesn’t accumulate across pages
                pdf.saveGState()

                // ✅ Flip once per page (top-left origin)
                pdf.translateBy(x: 0, y: pageRect.height)
                pdf.scaleBy(x: 1, y: -1)
            },

            drawText: { text, rect, style in
                NSGraphicsContext.saveGraphicsState()
                let gc = NSGraphicsContext(cgContext: pdf, flipped: true)
                NSGraphicsContext.current = gc

                (text as NSString).draw(in: rect, withAttributes: style.nsAttributes)

                NSGraphicsContext.restoreGraphicsState()
            },

            endPage: {
                // ✅ Undo the flip for the next page
                pdf.restoreGState()
                pdf.endPDFPage()
            },

            endDocument: {
                pdf.closePDF()
            },

            title: title,
            subtitle: subtitle,
            tracks: tracks
        )

        return data as Data
        #endif
    }
    
    static func exportTracksPDF(
        title: String,
        subtitle: String? = nil,
        tracks: [Track]
    ) throws -> URL {
        let data = try makeTracksPDF(title: title, subtitle: subtitle, tracks: tracks)

        let filename = safeFileName(title.isEmpty ? "rekordbox-library" : title)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(filename).pdf")

        try data.write(to: url, options: .atomic)
        return url
    }
    
    static func exportSectionedTracksPDF(
      title: String,
      subtitle: String?,
      sections: [(name: String, tracks: [PDFTrackRow])]
    ) throws -> URL {

        let data = try makeSectionedTracksPDF(title: title, subtitle: subtitle, sections: sections)

        let filename = safeFileName(title.isEmpty ? "rekordbox-library" : title)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(filename).pdf")

        try data.write(to: url, options: .atomic)
        return url
    }
    
    static func makeSectionedTracksPDF(
        title: String,
        subtitle: String? = nil,
        sections: [(name: String, tracks: [PDFTrackRow])]
    ) throws -> Data {

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)

        #if os(iOS)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { ctx in
            renderSectionedPDF(
                pageRect: pageRect,
                beginPage: { ctx.beginPage() },
                drawText: { text, rect, style in
                    (text as NSString).draw(in: rect, withAttributes: style.uiAttributes)
                },
                title: title,
                subtitle: subtitle,
                sections: sections
            )
        }
        #elseif os(macOS)
        let data = NSMutableData()

        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let pdf = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            throw PDFExportError.failedToCreateContext
        }

        renderSectionedPDF(
            pageRect: pageRect,
            beginPage: { pdf.beginPDFPage([kCGPDFContextMediaBox as String: pageRect] as CFDictionary) },
            drawText: { text, rect, style in
                let gc = NSGraphicsContext(cgContext: pdf, flipped: true) // keep TRUE
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = gc
                (text as NSString).draw(in: rect, withAttributes: style.nsAttributes)
                NSGraphicsContext.restoreGraphicsState()
            },
            endPage: { pdf.endPDFPage() },
            endDocument: { pdf.closePDF() },
            title: title,
            subtitle: subtitle,
            sections: sections
        )

        return data as Data
        #endif
    }
    
    private static func renderSectionedPDF(
        pageRect: CGRect,
        beginPage: () -> Void,
        drawText: (String, CGRect, TextStyle) -> Void,
        endPage: (() -> Void)? = nil,
        endDocument: (() -> Void)? = nil,
        title: String,
        subtitle: String?,
        sections: [(name: String, tracks: [PDFTrackRow])]
    ) {
        let margin: CGFloat = 36
        let headerHeight: CGFloat = 72
        let sectionHeaderHeight: CGFloat = 20
        let rowHeight: CGFloat = 16
        let colGap: CGFloat = 8

        let usableWidth = pageRect.width - margin * 2
        let titleW: CGFloat = usableWidth * 0.30
        let artistW: CGFloat = usableWidth * 0.20
        let albumW: CGFloat = usableWidth * 0.30
        let bpmW: CGFloat = usableWidth * 0.10
        let durW: CGFloat = usableWidth * 0.10

        func colX(_ idx: Int) -> CGFloat {
            var x = margin
            if idx > 0 { x += titleW + colGap }
            if idx > 1 { x += artistW + colGap }
            if idx > 2 { x += albumW + colGap }
            if idx > 3 { x += bpmW + colGap }
            return x
        }

        func formatDuration(_ seconds: Int) -> String {
            let m = seconds / 60
            let s = seconds % 60
            return String(format: "%d:%02d", m, s)
        }

        enum Item {
            case section(String, Int) // name, count
            case track(PDFTrackRow)
        }

        var items: [Item] = []
        for s in sections {
            items.append(.section(s.name, s.tracks.count))
            for t in s.tracks { items.append(.track(t)) }
        }

        let tableTop = margin + headerHeight
        let startY = tableTop + 18
        let availableHeight = pageRect.height - margin - startY
        let maxRowsPerPage = Int(availableHeight / rowHeight)

        var page = 1
        var i = 0

        func drawPageHeader() {
            drawText(title, CGRect(x: margin, y: margin, width: usableWidth, height: 28),
                     TextStyle(fontSize: 18, isBold: true, isSecondary: false))

            var headerY = margin + 26
            if let subtitle, !subtitle.isEmpty {
                drawText(subtitle, CGRect(x: margin, y: headerY, width: usableWidth, height: 18),
                         TextStyle(fontSize: 12, isBold: false, isSecondary: true))
                headerY += 18
            }

            drawText("Page \(page)", CGRect(x: margin, y: headerY, width: usableWidth, height: 18),
                     TextStyle(fontSize: 10, isBold: false, isSecondary: true))

            // Column header
            drawText("Title",  CGRect(x: colX(0), y: tableTop, width: titleW, height: 16), TextStyle(fontSize: 11, isBold: true, isSecondary: false))
            drawText("Artist", CGRect(x: colX(1), y: tableTop, width: artistW, height: 16), TextStyle(fontSize: 11, isBold: true, isSecondary: false))
            drawText("Album",  CGRect(x: colX(2), y: tableTop, width: albumW, height: 16), TextStyle(fontSize: 11, isBold: true, isSecondary: false))
            drawText("BPM",    CGRect(x: colX(3), y: tableTop, width: bpmW, height: 16), TextStyle(fontSize: 11, isBold: true, isSecondary: false))
            drawText("Dur",    CGRect(x: colX(4), y: tableTop, width: durW, height: 16), TextStyle(fontSize: 11, isBold: true, isSecondary: false))
        }

        while i < items.count {
            beginPage()
            drawPageHeader()

            var row = 0
            while row < maxRowsPerPage && i < items.count {
                let y = startY + CGFloat(row) * rowHeight

                switch items[i] {
                case .section(let name, let count):
                    // If section header would be last visible line, push to next page
                    if row >= maxRowsPerPage - 1 {
                        break
                    }
                    let text = "\(name)  —  \(count) tracks"
                    drawText(text,
                             CGRect(x: margin, y: y, width: usableWidth, height: sectionHeaderHeight),
                             TextStyle(fontSize: 11, isBold: true, isSecondary: false))
                    row += 1
                    i += 1

                case .track(let t):
                    drawText(t.title,
                             CGRect(x: colX(0), y: y, width: titleW, height: rowHeight),
                             TextStyle(fontSize: 10, isBold: false, isSecondary: false))

                    drawText(t.artist,
                             CGRect(x: colX(1), y: y, width: artistW, height: rowHeight),
                             TextStyle(fontSize: 10, isBold: false, isSecondary: true))

                    drawText(t.album.isEmpty ? "—" : t.album,
                             CGRect(x: colX(2), y: y, width: albumW, height: rowHeight),
                             TextStyle(fontSize: 10, isBold: false, isSecondary: true))

                    drawText(String(format: "%.1f", t.bpm),
                             CGRect(x: colX(3), y: y, width: bpmW, height: rowHeight),
                             TextStyle(fontSize: 10, isBold: false, isSecondary: true))

                    drawText(formatDuration(t.duration),
                             CGRect(x: colX(4), y: y, width: durW, height: rowHeight),
                             TextStyle(fontSize: 10, isBold: false, isSecondary: true))

                    row += 1
                    i += 1
                }
            }

            endPage?()
            page += 1
        }

        // If there were no sections at all, still output a single page
        if items.isEmpty {
            beginPage()
            drawPageHeader()
            endPage?()
        }

        endDocument?()
    }

    private static func safeFileName(_ s: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return s.components(separatedBy: bad).joined(separator: "_")
    }

    // MARK: - Shared layout

    private struct TextStyle {
        let fontSize: CGFloat
        let isBold: Bool
        let isSecondary: Bool

        #if os(iOS)
        var uiAttributes: [NSAttributedString.Key: Any] {
            let font: UIFont = isBold ? .boldSystemFont(ofSize: fontSize) : .systemFont(ofSize: fontSize)
            let color: UIColor = isSecondary ? UIColor.darkGray : UIColor.black
            return [.font: font, .foregroundColor: color]
        }
        #elseif os(macOS)
        var nsAttributes: [NSAttributedString.Key: Any] {
            let font: NSFont = isBold ? .boldSystemFont(ofSize: fontSize) : .systemFont(ofSize: fontSize)
            let color: NSColor = isSecondary ? NSColor.darkGray : NSColor.black
            return [.font: font, .foregroundColor: color]
        }
        #endif
    }

    private static func renderPDF(
        pageRect: CGRect,
        beginPage: () -> Void,
        drawText: (String, CGRect, TextStyle) -> Void,
        endPage: (() -> Void)? = nil,
        endDocument: (() -> Void)? = nil,
        title: String,
        subtitle: String?,
        tracks: [Track]
    ) {
        let margin: CGFloat = 36
        let headerHeight: CGFloat = 72
        let rowHeight: CGFloat = 16
        let colGap: CGFloat = 8

        // Columns: Title | Artist | Album | BPM | Dur
        let usableWidth = pageRect.width - margin * 2
        let titleW: CGFloat = usableWidth * 0.30
        let artistW: CGFloat = usableWidth * 0.20
        let albumW: CGFloat = usableWidth * 0.30
        let bpmW: CGFloat = usableWidth * 0.10
        let durW: CGFloat = usableWidth * 0.10

        func colX(_ idx: Int) -> CGFloat {
            var x = margin
            if idx > 0 { x += titleW + colGap }
            if idx > 1 { x += artistW + colGap }
            if idx > 2 { x += albumW + colGap }
            if idx > 3 { x += bpmW + colGap }
            return x
        }

        func formatDuration(_ seconds: Int) -> String {
            let m = seconds / 60
            let s = seconds % 60
            return String(format: "%d:%02d", m, s)
        }

        let rowsPerPage = Int((pageRect.height - margin - headerHeight - margin) / rowHeight)
        var index = 0
        var page = 1

        while index < tracks.count || (tracks.isEmpty && page == 1) {
            beginPage()

            // Header
            drawText(title, CGRect(x: margin, y: margin, width: usableWidth, height: 28),
                     TextStyle(fontSize: 18, isBold: true, isSecondary: false))

            var headerY = margin + 26
            if let subtitle, !subtitle.isEmpty {
                drawText(subtitle, CGRect(x: margin, y: headerY, width: usableWidth, height: 18),
                         TextStyle(fontSize: 12, isBold: false, isSecondary: true))
                headerY += 18
            }

            drawText("Page \(page)", CGRect(x: margin, y: headerY, width: usableWidth, height: 18),
                     TextStyle(fontSize: 10, isBold: false, isSecondary: true))

            // Table header
            let tableTop = margin + headerHeight
            drawText("Title",   CGRect(x: colX(0), y: tableTop, width: titleW, height: 16),  TextStyle(fontSize: 11, isBold: true, isSecondary: false))
            drawText("Artist",  CGRect(x: colX(1), y: tableTop, width: artistW, height: 16), TextStyle(fontSize: 11, isBold: true, isSecondary: false))
            drawText("Album",   CGRect(x: colX(2), y: tableTop, width: albumW, height: 16),  TextStyle(fontSize: 11, isBold: true, isSecondary: false))
            drawText("BPM",     CGRect(x: colX(3), y: tableTop, width: bpmW, height: 16),    TextStyle(fontSize: 11, isBold: true, isSecondary: false))
            drawText("Dur",     CGRect(x: colX(4), y: tableTop, width: durW, height: 16),    TextStyle(fontSize: 11, isBold: true, isSecondary: false))

            // Rows
            let startRowY = tableTop + 18
            for r in 0..<rowsPerPage {
                guard index < tracks.count else { break }
                let t = tracks[index]
                let y = startRowY + CGFloat(r) * rowHeight

                drawText(t.title,  CGRect(x: colX(0), y: y, width: titleW, height: rowHeight), TextStyle(fontSize: 10, isBold: false, isSecondary: false))
                drawText(t.artist, CGRect(x: colX(1), y: y, width: artistW, height: rowHeight), TextStyle(fontSize: 10, isBold: false, isSecondary: true))
                drawText(t.album.isEmpty ? "—" : t.album,
                         CGRect(x: colX(2), y: y, width: albumW, height: rowHeight),
                         TextStyle(fontSize: 10, isBold: false, isSecondary: true))
                drawText(String(format: "%.1f", t.bpm),
                         CGRect(x: colX(3), y: y, width: bpmW, height: rowHeight),
                         TextStyle(fontSize: 10, isBold: false, isSecondary: true))
                drawText(formatDuration(t.duration),
                         CGRect(x: colX(4), y: y, width: durW, height: rowHeight),
                         TextStyle(fontSize: 10, isBold: false, isSecondary: true))

                index += 1
            }

            endPage?()
            page += 1

            // If empty list, only render 1 page
            if tracks.isEmpty { break }
        }

        endDocument?()
    }
}
