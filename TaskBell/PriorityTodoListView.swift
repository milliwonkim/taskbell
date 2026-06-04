//
//  PriorityTodoListView.swift
//  TaskBell
//

import SwiftData
import SwiftUI

struct PriorityTodoListView: View {
    @Environment(\.appLanguage) private var appLanguage
    let todos: [TodoItem]
    let onToggleCompletion: (TodoItem) -> Void
    let onToggleContentCheckbox: (TodoItem, Int) -> Void
    let onUpdateTodo: (TodoItem, TodoDraft) -> Void
    let onDelete: (IndexSet, [TodoItem]) -> Void

    @State private var selectedTodo: TodoItem?
    @State private var editingTodo: TodoItem?

    var body: some View {
        Group {
            if todos.isEmpty {
                ContentUnavailableView(
                    appLanguage.text(korean: "분류할 할 일이 없습니다", english: "No Todos to Categorize"),
                    systemImage: "square.grid.2x2",
                    description: Text(appLanguage.text(korean: "오른쪽 위 + 버튼으로 할 일을 만들고 우선순위를 선택하세요.", english: "Use the + button at the top right to create a todo and choose a priority."))
                )
            } else {
                List {
                    ForEach(TodoPriorityQuadrant.allCases) { priority in
                        prioritySection(priority)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle(appLanguage.text(korean: "우선순위", english: "Priority"))
        .sheet(item: $selectedTodo) { todo in
            TodoDetailSheet(
                todo: todo,
                onToggleCompletion: {
                    onToggleCompletion(todo)
                },
                onToggleContentCheckbox: { lineIndex in
                    onToggleContentCheckbox(todo, lineIndex)
                },
                onUpdateTodo: { draft in
                    onUpdateTodo(todo, draft)
                }
            )
            .presentationDetents([.large])
        }
        .sheet(item: $editingTodo) { todo in
            TodoEditorSheet(
                title: appLanguage.text(korean: "할 일 수정", english: "Edit Todo"),
                initialDraft: TodoDraft(todo: todo),
                allowsRoutineBulkCreation: false
            ) { draft in
                onUpdateTodo(todo, draft)
            }
            .presentationDetents([.large])
        }
    }

    private func prioritySection(_ priority: TodoPriorityQuadrant) -> some View {
        let sectionTodos = todos(for: priority)

        return Section {
            if sectionTodos.isEmpty {
                Text(appLanguage.text(korean: "이 분류의 할 일이 없습니다.", english: "No todos in this category."))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sectionTodos) { todo in
                    priorityRow(todo, in: sectionTodos)
                }
                .onDelete { offsets in
                    onDelete(offsets, sectionTodos)
                }
            }
        } header: {
            HStack(spacing: 8) {
                Image(systemName: priority.systemImage)
                    .foregroundStyle(Color.accentColor)
                Text(priority.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(sectionTodos.filter(\.isCompleted).count)/\(sectionTodos.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .textCase(nil)
        }
    }

    private func priorityRow(_ todo: TodoItem, in visibleTodos: [TodoItem]) -> some View {
        HStack(alignment: .top, spacing: TodoRowMetrics.checkboxContentSpacing) {
            TodoCompletionButton(
                isCompleted: todo.isCompleted,
                action: {
                    onToggleCompletion(todo)
                }
            )

            TodoRowView(
                todo: todo,
                onToggleContentCheckbox: { lineIndex in
                    onToggleContentCheckbox(todo, lineIndex)
                }
            ) {
                selectedTodo = todo
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTodo = todo
        }
        .contextMenu {
            Button {
                editingTodo = todo
            } label: {
                Label(appLanguage.text(korean: "수정", english: "Edit"), systemImage: "pencil")
            }

            Button(role: .destructive) {
                delete(todo, from: visibleTodos)
            } label: {
                Label(appLanguage.text(korean: "삭제", english: "Delete"), systemImage: "trash")
            }
        }
    }

    private func todos(for priority: TodoPriorityQuadrant) -> [TodoItem] {
        todos
            .filter { $0.priority == priority }
            .sorted { first, second in
                if first.isCompleted != second.isCompleted {
                    return !first.isCompleted
                }

                return first.createdAt > second.createdAt
            }
    }

    private func delete(_ todo: TodoItem, from visibleTodos: [TodoItem]) {
        guard let index = visibleTodos.firstIndex(where: {
            $0.persistentModelID == todo.persistentModelID
        }) else {
            return
        }

        onDelete(IndexSet(integer: index), visibleTodos)
    }
}
