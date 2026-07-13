//
//  ProfileWidgetsView.swift
//  Talking Fingers
//
//  Created by Assistant on 4/19/26.
//

import SwiftUI

#if os(iOS)
struct ProfileWidgetsView: View {
    enum PresentationStyle {
        case profile
        case embedded
    }

    private enum ScreenMode {
        case regular
        case edit
        case add
    }

    @State private var vm = ProfileWidgetsVM()
    @State private var mode: ScreenMode = .regular
    @Environment(AuthenticationViewModel.self) var authVM
    @Environment(SwiftDataVM.self) private var dataVM
    @State private var showProfile = false

    private let presentation: PresentationStyle

    init(presentation: PresentationStyle = .profile) {
        self.presentation = presentation
    }

    var body: some View {
        ZStack {
            TFColors.white.ignoresSafeArea()

            VStack(spacing: 0) {
                switch mode {
                case .add:
                    AddWidgetsScreen(
                        vm: vm,
                        onBack: { mode = .edit },
                        onDone: { mode = .edit }
                    )
                case .regular, .edit:
                    topBar
                    actionRow

                    Rectangle()
                        .fill(TFColors.border)
                        .frame(height: 1)
                        .padding(.horizontal, 16)

                    List {
                        ForEach(widgetRows, id: \.id) { row in
                            switch row.kind {
                            case .pair(let left, let right):
                                HStack(spacing: 12) {
                                    WidgetCardView(
                                        widget: left,
                                        isEditMode: isEditMode,
                                        onRemove: { remove(left) }
                                    )
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 96)

                                    WidgetCardView(
                                        widget: right,
                                        isEditMode: isEditMode,
                                        onRemove: { remove(right) }
                                    )
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 96)
                                }
                                .listRowInsets(.init(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)

                            case .single(let widget):
                                WidgetCardView(
                                    widget: widget,
                                    isEditMode: isEditMode,
                                    onRemove: { remove(widget) }
                                )
                                .listRowInsets(.init(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        }
                        .onMove(perform: moveRows)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .environment(\.editMode, .constant(isEditMode ? .active : .inactive))
                    .padding(.vertical, 8)
                }
            }

            if showProfile {
                ZStack {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { showProfile = false } }
                    profileSheet(onClose: { withAnimation(.easeInOut(duration: 0.2)) { showProfile = false } })
                        .background(TFColors.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
                        .transition(.scale.combined(with: .opacity))
                }
                .animation(.easeInOut(duration: 0.2), value: showProfile)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Text("Profile")
                .font(.system(size: 34, weight: .bold))
                .fontWeight(.bold)
            Spacer()
            Button {showProfile.toggle()} label : {
                Image(systemName: "person.circle")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(TFColors.black)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }
    struct profileSheet: View {
        let onClose: () -> Void
        @Environment(AuthenticationViewModel.self) var authVM
        var body: some View {
            VStack(spacing: 0) {
                // Header with dismiss button on the top-right
                HStack {
                    Spacer()
                    Button(action: { onClose() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(TFColors.black)
                            .padding(8)
                            .background(TFColors.pill)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding([.top, .horizontal], 12)

                // Content
                VStack(spacing: 12) {
                    Text(authVM.currentUser?.name ?? "Loading...")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(TFColors.black)

                    Button(action: { authVM.signOut(); onClose() }) {
                        Text("Log Out")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(TFColors.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            .frame(width: 280)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 16)
        }
    }

    private var actionRow: some View {
        HStack {
            if isEditMode {
                Button(action: { mode = .add }) {
                    Text("Add Widgets")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(TFColors.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(TFColors.pill)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                Spacer()
                Button(action: { mode = .regular }) {
                    Text("Done")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(TFColors.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(TFColors.pill)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { mode = .edit }) {
                    Text("Edit Widgets")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(TFColors.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(TFColors.pill)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                Spacer()
                Text(formattedToday)
                    .font(.subheadline)
                    .foregroundStyle(TFColors.darkerGray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private struct WidgetRow: Identifiable {
        enum Kind {
            case single(ProfileWidget)
            case pair(ProfileWidget, ProfileWidget)
        }

        let id: String
        let kind: Kind
    }

    private var widgetRows: [WidgetRow] {
        buildWidgetRows(from: vm.displayedWidgets.sorted(by: { $0.order < $1.order }))
    }

    private func buildWidgetRows(from widgets: [ProfileWidget]) -> [WidgetRow] {
        var rows: [WidgetRow] = []
        var i = 0

        while i < widgets.count {
            let w = widgets[i]

            if w.type == .streak, i + 1 < widgets.count, widgets[i + 1].type == .wordsLearned {
                let left = w
                let right = widgets[i + 1]
                rows.append(
                    WidgetRow(
                        id: "pair:\(left.id.uuidString):\(right.id.uuidString)",
                        kind: .pair(left, right)
                    )
                )
                i += 2
                continue
            }

            rows.append(WidgetRow(id: "single:\(w.id.uuidString)", kind: .single(w)))
            i += 1
        }

        return rows
    }

    private func expandedWidgets(from rows: [WidgetRow]) -> [ProfileWidget] {
        var out: [ProfileWidget] = []
        out.reserveCapacity(rows.count * 2)

        for row in rows {
            switch row.kind {
            case .single(let w):
                out.append(w)
            case .pair(let a, let b):
                out.append(a)
                out.append(b)
            }
        }

        return out
    }

    private func moveRows(from source: IndexSet, to destination: Int) {
        var rows = widgetRows
        rows.move(fromOffsets: source, toOffset: destination)

        let newWidgets = expandedWidgets(from: rows)
        guard newWidgets.count == vm.displayedWidgets.count else { return }

        vm.applyOrderedWidgets(newWidgets)
    }

    private func widget(_ type: WidgetType) -> ProfileWidget? {
        vm.displayedWidgets.first { $0.type == type }
    }

    private var isEditMode: Bool { mode == .edit }

    private func remove(_ widget: ProfileWidget) {
        guard let index = vm.displayedWidgets.firstIndex(where: { $0.id == widget.id }) else { return }
        vm.removeWidget(at: IndexSet([index]))
    }

    private var formattedToday: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
}

#Preview {
    ProfileWidgetsView()
}
#endif
