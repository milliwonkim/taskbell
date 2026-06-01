//
//  RichTodoContentViews.swift
//  TaskBell
//

import SwiftUI

struct RichTodoEditor: View {
    @Binding var content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RichTodoToolBar { tool in
                append(tool.template)
            }

            ZStack(alignment: .topLeading) {
                if content.isEmpty {
                    Text("내용")
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                }

                TextEditor(text: $content)
                    .frame(minHeight: 150)
            }

            if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("미리보기", systemImage: "eye")
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
    let onSelect: (RichTodoTool) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RichTodoTool.allCases) { tool in
                    Button {
                        onSelect(tool)
                    } label: {
                        Label(tool.title, systemImage: tool.systemImage)
                            .font(.caption.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.secondary.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tool.title)
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

    var title: String {
        switch self {
        case .paragraph:
            "문단"
        case .strongParagraph:
            "강조"
        case .checkbox:
            "체크박스"
        case .underline:
            "밑줄"
        case .bullet:
            "목록"
        case .quote:
            "인용"
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

    var template: String {
        switch self {
        case .paragraph:
            "내용을 입력하세요"
        case .strongParagraph:
            "## 강조 문단"
        case .checkbox:
            "- [ ] 체크할 일"
        case .underline:
            "__밑줄 텍스트__"
        case .bullet:
            "- 목록 항목"
        case .quote:
            "> 메모"
        }
    }
}

struct RichTodoContentView: View {
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
            RichInlineText(text: block.text)
                .font(compact ? .caption : .body)
                .foregroundStyle(compact ? .secondary : .primary)
                .lineLimit(compact ? 2 : nil)
        case .strongParagraph:
            RichInlineText(text: block.text)
                .font(compact ? .caption.weight(.semibold) : .headline)
                .foregroundStyle(compact ? .secondary : .primary)
                .lineLimit(compact ? 2 : nil)
        case .checkbox(let isChecked):
            HStack(alignment: .top, spacing: compact ? 6 : 7) {
                Button {
                    onToggleCheckbox?(block.id)
                } label: {
                    Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                        .foregroundStyle(isChecked ? .green : .secondary)
                        .font(compact ? .title3 : .title2)
                        .frame(width: compact ? 32 : 44, height: compact ? 32 : 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(onToggleCheckbox == nil)
                .accessibilityLabel(isChecked ? "체크 해제" : "체크")

                RichInlineText(text: block.text.isEmpty ? "체크할 일" : block.text)
                    .font(compact ? .caption : .body)
                    .foregroundStyle(compact ? .secondary : .primary)
                    .strikethrough(isChecked)
                    .lineLimit(compact ? 1 : nil)
                    .padding(.top, compact ? 8 : 11)
            }
        case .bullet:
            HStack(alignment: .top, spacing: 7) {
                Text("•")
                    .font(compact ? .caption : .body)
                    .foregroundStyle(.secondary)

                RichInlineText(text: block.text)
                    .font(compact ? .caption : .body)
                    .foregroundStyle(compact ? .secondary : .primary)
                    .lineLimit(compact ? 1 : nil)
            }
        case .quote:
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.secondary.opacity(0.35))
                    .frame(width: 3)

                RichInlineText(text: block.text)
                    .font(compact ? .caption : .body)
                    .foregroundStyle(.secondary)
                    .italic()
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

private struct RichInlineText: View {
    let text: String

    var body: some View {
        RichTodoContentParser.inlineText(from: text)
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

    static func inlineText(from source: String) -> Text {
        let segments = inlineSegments(from: source)
        guard let first = segments.first else {
            return Text("")
        }

        return segments.dropFirst().reduce(text(for: first)) { partial, segment in
            partial + text(for: segment)
        }
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
            if source[index...].hasPrefix("**") {
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

    private static func text(for segment: RichInlineSegment) -> Text {
        var text = Text(segment.text)

        if segment.isBold {
            text = text.bold()
        }

        if segment.isUnderlined {
            text = text.underline()
        }

        return text
    }
}

private struct RichInlineSegment {
    let text: String
    var isBold = false
    var isUnderlined = false
}
