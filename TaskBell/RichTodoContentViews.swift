//
//  RichTodoContentViews.swift
//  TaskBell
//

import SwiftUI

struct RichTodoEditor: View {
    @Environment(\.appLanguage) private var appLanguage
    @Binding var content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RichTodoToolBar { tool in
                append(tool.template(in: appLanguage))
            }

            ZStack(alignment: .topLeading) {
                if content.isEmpty {
                    Text(appLanguage.text(korean: "내용", english: "Content"))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                }

                TextEditor(text: $content)
                    .frame(minHeight: 150)
            }

            if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label(appLanguage.text(korean: "미리보기", english: "Preview"), systemImage: "eye")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    RichTodoContentView(content: content, compact: false) { lineIndex in
                        content = RichTodoContentFormatter.toggledCheckbox(
                            in: content,
                            lineIndex: lineIndex
                        )
                    }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func append(_ template: String) {
        if !content.isEmpty, !content.hasSuffix("\n") {
            content.append("\n")
        }

        content.append(template)
    }
}

private struct RichTodoToolBar: View {
    @Environment(\.appLanguage) private var appLanguage
    let onSelect: (RichTodoTool) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RichTodoTool.allCases) { tool in
                    Button {
                        onSelect(tool)
                    } label: {
                        Label(tool.title(in: appLanguage), systemImage: tool.systemImage)
                            .font(.caption.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.secondary.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tool.title(in: appLanguage))
                }
            }
        }
    }
}

private enum RichTodoTool: String, CaseIterable, Identifiable {
    case paragraph
    case strongParagraph
    case checkbox
    case underline
    case bullet
    case quote

    var id: Self { self }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .paragraph:
            language.text(korean: "문단", english: "Paragraph")
        case .strongParagraph:
            language.text(korean: "강조", english: "Emphasis")
        case .checkbox:
            language.text(korean: "체크박스", english: "Checkbox")
        case .underline:
            language.text(korean: "밑줄", english: "Underline")
        case .bullet:
            language.text(korean: "목록", english: "List")
        case .quote:
            language.text(korean: "인용", english: "Quote")
        }
    }

    var systemImage: String {
        switch self {
        case .paragraph:
            "text.alignleft"
        case .strongParagraph:
            "bold"
        case .checkbox:
            "checklist"
        case .underline:
            "underline"
        case .bullet:
            "list.bullet"
        case .quote:
            "quote.opening"
        }
    }

    func template(in language: AppLanguage) -> String {
        switch self {
        case .paragraph:
            language.text(korean: "내용을 입력하세요", english: "Enter content")
        case .strongParagraph:
            "##"
        case .checkbox:
            "- [ ]"
        case .underline:
            language.text(korean: "__밑줄 텍스트__", english: "__Underlined text__")
        case .bullet:
            language.text(korean: "- 목록 항목", english: "- List item")
        case .quote:
            language.text(korean: "> 메모", english: "> Note")
        }
    }
}

struct RichTodoContentView: View {
    @Environment(\.appLanguage) private var appLanguage
    let content: String
    var compact: Bool = false
    var onToggleCheckbox: ((Int) -> Void)?

    private var blocks: [RichTodoContentBlock] {
        RichTodoContentParser.blocks(from: content)
    }

    private var visibleBlocks: [RichTodoContentBlock] {
        compact ? Array(blocks.prefix(3)) : blocks
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 7) {
            ForEach(visibleBlocks) { block in
                blockView(block)
            }

            if compact, blocks.count > visibleBlocks.count {
                Text("...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: RichTodoContentBlock) -> some View {
        switch block.kind {
        case .paragraph:
            RichInlineText(
                text: block.text,
                style: .init(compact: compact)
            )
                .font(compact ? .caption : .body)
                .lineLimit(compact ? 2 : nil)
        case .strongParagraph:
            RichInlineText(
                text: block.text,
                style: .init(compact: compact, emphasized: true)
            )
                .font(compact ? .caption.weight(.semibold) : .headline)
                .lineLimit(compact ? 2 : nil)
        case .checkbox(let isChecked):
            HStack(alignment: .top, spacing: compact ? 4 : 7) {
                Button {
                    onToggleCheckbox?(block.id)
                } label: {
                    Group {
                        if isChecked {
                            Image(systemName: "checkmark.square.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .green)
                        } else {
                            Image(systemName: "square")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(compact ? .body : .title2)
                    .frame(width: compact ? 28 : 44, height: compact ? 28 : 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(onToggleCheckbox == nil)
                .accessibilityLabel(isChecked ? appLanguage.text(korean: "체크 해제", english: "Uncheck") : appLanguage.text(korean: "체크", english: "Check"))

                if !block.text.isEmpty {
                    RichInlineText(
                        text: block.text,
                        style: .init(compact: compact, strikethrough: isChecked)
                    )
                        .font(compact ? .caption : .body)
                        .lineLimit(compact ? 1 : nil)
                        .padding(.top, compact ? 6 : 11)
                }
            }
        case .bullet:
            HStack(alignment: .top, spacing: 7) {
                Text("•")
                    .font(compact ? .caption : .body)
                    .foregroundStyle(.secondary)

                RichInlineText(
                    text: block.text,
                    style: .init(compact: compact)
                )
                    .font(compact ? .caption : .body)
                    .lineLimit(compact ? 1 : nil)
            }
        case .quote:
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.secondary.opacity(0.35))
                    .frame(width: 3)

                RichInlineText(
                    text: block.text,
                    style: .init(compact: compact, italic: true)
                )
                    .font(compact ? .caption : .body)
                    .lineLimit(compact ? 1 : nil)
            }
        }
    }
}

enum RichTodoContentFormatter {
    static func toggledCheckbox(in content: String, lineIndex: Int) -> String {
        var lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        guard lines.indices.contains(lineIndex) else {
            return content
        }

        let line = lines[lineIndex]
        let leadingWhitespace = line.prefix { $0 == " " || $0 == "\t" }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let lowercased = trimmed.lowercased()

        if lowercased.hasPrefix("- [ ]") {
            lines[lineIndex] = "\(leadingWhitespace)- [x]\(String(trimmed.dropFirst(5)))"
        } else if lowercased.hasPrefix("- [x]") {
            lines[lineIndex] = "\(leadingWhitespace)- [ ]\(String(trimmed.dropFirst(5)))"
        }

        return lines.joined(separator: "\n")
    }
}

private struct RichInlineTextStyle {
    var compact = false
    var emphasized = false
    var italic = false
    var strikethrough = false
}

private struct RichInlineText: View {
    let text: String
    var style: RichInlineTextStyle = .init()

    var body: some View {
        RichTodoContentParser.inlineText(from: text, style: style)
    }
}

private struct RichTodoContentBlock: Identifiable {
    let id: Int
    let kind: Kind
    let text: String

    enum Kind {
        case paragraph
        case strongParagraph
        case checkbox(isChecked: Bool)
        case bullet
        case quote
    }
}

private enum RichTodoContentParser {
    static func blocks(from content: String) -> [RichTodoContentBlock] {
        content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .compactMap { offset, rawLine in
                let line = String(rawLine)
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                guard !trimmed.isEmpty else {
                    return nil
                }

                if let checkbox = checkboxBlock(from: trimmed, id: offset) {
                    return checkbox
                }

                if trimmed.hasPrefix("## ") {
                    return RichTodoContentBlock(
                        id: offset,
                        kind: .strongParagraph,
                        text: String(trimmed.dropFirst(3))
                    )
                }

                if trimmed.hasPrefix("> ") {
                    return RichTodoContentBlock(
                        id: offset,
                        kind: .quote,
                        text: String(trimmed.dropFirst(2))
                    )
                }

                if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                    return RichTodoContentBlock(
                        id: offset,
                        kind: .bullet,
                        text: String(trimmed.dropFirst(2))
                    )
                }

                return RichTodoContentBlock(id: offset, kind: .paragraph, text: line)
            }
    }

    static func inlineText(from source: String, style: RichInlineTextStyle = .init()) -> Text {
        var attributed = AttributedString()
        let baseColor: Color = style.compact ? .secondary : .primary

        for segment in inlineSegments(from: source) {
            appendSegment(segment, baseColor: baseColor, style: style, to: &attributed)
        }

        guard !attributed.characters.isEmpty else {
            return Text("")
        }

        return Text(attributed)
    }

    private static func appendSegment(
        _ segment: RichInlineSegment,
        baseColor: Color,
        style: RichInlineTextStyle,
        to attributed: inout AttributedString
    ) {
        if let linkURL = segment.linkURL {
            var linkAttributed = AttributedString(segment.text)
            applyPresentationStyle(to: &linkAttributed, segment: segment, style: style)
            linkAttributed.link = linkURL
            linkAttributed.foregroundColor = .blue
            if !segment.isUnderlined {
                linkAttributed.underlineStyle = .single
            }
            attributed.append(linkAttributed)
            return
        }

        appendTextWithDetectedLinks(
            segment.text,
            segment: segment,
            baseColor: baseColor,
            style: style,
            to: &attributed
        )
    }

    private static func appendTextWithDetectedLinks(
        _ text: String,
        segment: RichInlineSegment,
        baseColor: Color,
        style: RichInlineTextStyle,
        to attributed: inout AttributedString
    ) {
        let matches = linkMatches(in: text)

        guard !matches.isEmpty else {
            var plain = AttributedString(text)
            applyPresentationStyle(to: &plain, segment: segment, style: style)
            plain.foregroundColor = baseColor
            attributed.append(plain)
            return
        }

        var cursor = text.startIndex

        for match in matches {
            if cursor < match.range.lowerBound {
                var prefix = AttributedString(String(text[cursor..<match.range.lowerBound]))
                applyPresentationStyle(to: &prefix, segment: segment, style: style)
                prefix.foregroundColor = baseColor
                attributed.append(prefix)
            }

            var linkPart = AttributedString(String(text[match.range]))
            applyPresentationStyle(to: &linkPart, segment: segment, style: style)
            linkPart.link = match.url
            linkPart.foregroundColor = .blue
            if !segment.isUnderlined {
                linkPart.underlineStyle = .single
            }
            attributed.append(linkPart)

            cursor = match.range.upperBound
        }

        if cursor < text.endIndex {
            var suffix = AttributedString(String(text[cursor...]))
            applyPresentationStyle(to: &suffix, segment: segment, style: style)
            suffix.foregroundColor = baseColor
            attributed.append(suffix)
        }
    }

    private static func applyPresentationStyle(
        to attributed: inout AttributedString,
        segment: RichInlineSegment,
        style: RichInlineTextStyle
    ) {
        if segment.isBold || style.emphasized {
            attributed.inlinePresentationIntent = .stronglyEmphasized
        }

        if segment.isUnderlined {
            attributed.underlineStyle = .single
        }

        if style.italic {
            attributed.inlinePresentationIntent = .emphasized
        }

        if style.strikethrough {
            attributed.strikethroughStyle = .single
        }
    }

    private static func linkMatches(in text: String) -> [LinkMatch] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }

        return detector
            .matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
            .compactMap { match in
                guard let range = Range(match.range, in: text), let url = match.url else {
                    return nil
                }

                return LinkMatch(range: range, url: url)
            }
    }

    private static func normalizedURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        return URL(string: "https://\(trimmed)")
    }

    private static func checkboxBlock(from line: String, id: Int) -> RichTodoContentBlock? {
        let lowercased = line.lowercased()

        if lowercased.hasPrefix("- [ ] ") {
            return RichTodoContentBlock(
                id: id,
                kind: .checkbox(isChecked: false),
                text: String(line.dropFirst(6))
            )
        }

        if lowercased == "- [ ]" {
            return RichTodoContentBlock(id: id, kind: .checkbox(isChecked: false), text: "")
        }

        if lowercased.hasPrefix("- [x] ") {
            return RichTodoContentBlock(
                id: id,
                kind: .checkbox(isChecked: true),
                text: String(line.dropFirst(6))
            )
        }

        if lowercased == "- [x]" {
            return RichTodoContentBlock(id: id, kind: .checkbox(isChecked: true), text: "")
        }

        return nil
    }

    private static func inlineSegments(from source: String) -> [RichInlineSegment] {
        var segments: [RichInlineSegment] = []
        var current = ""
        var isBold = false
        var isUnderlined = false
        var index = source.startIndex

        func flush() {
            guard !current.isEmpty else {
                return
            }

            segments.append(
                RichInlineSegment(
                    text: current,
                    isBold: isBold,
                    isUnderlined: isUnderlined
                )
            )
            current = ""
        }

        while index < source.endIndex {
            if let markdownLink = parseMarkdownLink(
                at: &index,
                in: source,
                isBold: isBold,
                isUnderlined: isUnderlined
            ) {
                flush()
                segments.append(markdownLink)
            } else if source[index...].hasPrefix("**") {
                flush()
                isBold.toggle()
                index = source.index(index, offsetBy: 2)
            } else if source[index...].hasPrefix("__") {
                flush()
                isUnderlined.toggle()
                index = source.index(index, offsetBy: 2)
            } else {
                current.append(source[index])
                index = source.index(after: index)
            }
        }

        flush()
        return segments.isEmpty ? [RichInlineSegment(text: source)] : segments
    }

    private static func parseMarkdownLink(
        at index: inout String.Index,
        in source: String,
        isBold: Bool,
        isUnderlined: Bool
    ) -> RichInlineSegment? {
        guard source[index] == "[",
              let closeBracket = source[index...].firstIndex(of: "]")
        else {
            return nil
        }

        let afterBracket = source.index(after: closeBracket)
        guard afterBracket < source.endIndex, source[afterBracket] == "(" else {
            return nil
        }

        let urlStart = source.index(after: afterBracket)
        guard let closeParen = source[urlStart...].firstIndex(of: ")") else {
            return nil
        }

        let labelStart = source.index(after: index)
        let label = String(source[labelStart..<closeBracket])
        let urlString = String(source[urlStart..<closeParen])
        guard let url = normalizedURL(from: urlString) else {
            return nil
        }

        index = source.index(after: closeParen)
        return RichInlineSegment(
            text: label,
            isBold: isBold,
            isUnderlined: isUnderlined,
            linkURL: url
        )
    }

}

private struct LinkMatch {
    let range: Range<String.Index>
    let url: URL
}

private struct RichInlineSegment {
    let text: String
    var isBold = false
    var isUnderlined = false
    var linkURL: URL? = nil
}
