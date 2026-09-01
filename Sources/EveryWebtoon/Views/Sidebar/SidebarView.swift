import SwiftUI

struct SidebarView: View {
    @Binding var selectedItem: SidebarItem?
    @State private var expandedIDs: Set<String> = ["naver", "kakao"]
    @State private var diskUsage: String = "계산 중..."
    @ObservedObject private var collections = CollectionsManager.shared
    @State private var showCreateAlert = false
    @State private var createName = ""
    @State private var renameTarget: String?
    @State private var renameName = ""
    @State private var deleteTarget: String?

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedItem) {
                Section("내 보관함") {
                    ForEach(SidebarItem.all.filter { $0.section == .library }) { item in
                        sidebarRow(item)
                    }
                }

                Section {
                    ForEach(collections.names, id: \.self) { name in
                        collectionRow(name)
                    }
                } header: {
                    HStack {
                        Text("나의 모음")
                        Spacer()
                        Button {
                            createName = ""
                            showCreateAlert = true
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("새 모음 만들기")
                    }
                    .padding(.trailing, 6)
                }

                Section("발견") {
                    ForEach(SidebarItem.all.filter { $0.section == .discover && !$0.isGroup }) { item in
                        sidebarRow(item)
                    }
                    ForEach(SidebarItem.all.filter { $0.section == .discover && $0.isGroup }) { item in
                        groupHeaderRow(item)
                        if expandedIDs.contains(item.id) {
                            ForEach(item.children) { child in
                                if child.isGroup {
                                    groupHeaderRow(child, indent: 14)
                                    if expandedIDs.contains(child.id) {
                                        ForEach(child.children) { leaf in
                                            sidebarRow(leaf, indent: 28)
                                        }
                                    }
                                } else {
                                    sidebarRow(child, indent: 14)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Divider()

            HStack(spacing: 6) {
                Image(systemName: "externaldrive")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(diskUsage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        .task {
            diskUsage = await calculateDiskUsage()
        }
        .alert("새 모음 만들기", isPresented: $showCreateAlert) {
            TextField("모음 이름", text: $createName)
            Button("만들기") {
                let name = createName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { _ = collections.create(name) }
                createName = ""
            }
            Button("취소", role: .cancel) {
                createName = ""
            }
        }
        .alert("모음 이름 변경", isPresented: renameBinding) {
            TextField("모음 이름", text: $renameName)
            Button("변경") {
                if let old = renameTarget {
                    _ = collections.rename(old, to: renameName)
                }
                renameTarget = nil
            }
            Button("취소", role: .cancel) {
                renameTarget = nil
            }
        }
        .alert("모음 삭제", isPresented: deleteBinding) {
            Button("삭제", role: .destructive) {
                if let name = deleteTarget {
                    collections.delete(name)
                }
                deleteTarget = nil
            }
            Button("취소", role: .cancel) {
                deleteTarget = nil
            }
        } message: {
            Text(deleteTarget.map { "'\($0)' 모음을 삭제합니다." } ?? "")
        }
    }

    private var renameBinding: Binding<Bool> {
        Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )
    }

    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )
    }

    private func collectionRow(_ name: String) -> some View {
        let item = SidebarItem(id: "collection-\(name)", title: name,
                               icon: "folder", section: .library)
        return HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.body)
                .frame(width: 20)
            Text(item.title)
                .font(.body)
                .lineLimit(1)
            Spacer()
            let count = collections.ids(in: name).count
            if count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .tag(item)
        .contextMenu {
            Button("이름 변경…") {
                renameTarget = name
                renameName = name
            }
            Button("모음 삭제…", role: .destructive) {
                deleteTarget = name
            }
        }
    }

    private func sidebarRow(_ item: SidebarItem, indent: CGFloat = 0) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.body)
                .frame(width: 20)
            Text(item.title)
                .font(.body)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.leading, indent)
        .tag(item)
    }

    private func groupHeaderRow(_ item: SidebarItem, indent: CGFloat = 0) -> some View {
        HStack(spacing: 6) {
            Image(systemName: item.icon)
                .font(.body)
                .frame(width: 20)
            Text(item.title)
                .font(.body)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button {
                toggle(item.id)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(expandedIDs.contains(item.id) ? 90 : 0))
                    .animation(.easeOut(duration: 0.15), value: expandedIDs.contains(item.id))
            }
            .buttonStyle(.plain)
            .help("펼치기/접기")
        }
        .padding(.leading, indent)
        .tag(item)
    }

    private func toggle(_ id: String) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }

    private func calculateDiskUsage() async -> String {
        let fm = FileManager.default
        let path = AppPaths.basePath
        guard fm.fileExists(atPath: path) else { return "0 KB" }

        return await Task.detached(priority: .background) {
            let enumerator = fm.enumerator(atPath: path)
            var totalSize: Int64 = 0

            while let file = enumerator?.nextObject() as? String {
                let filePath = (path as NSString).appendingPathComponent(file)
                if let attrs = try? fm.attributesOfItem(atPath: filePath),
                   let size = attrs[.size] as? Int64 {
                    totalSize += size
                }
            }
            return ByteFormat.string(bytes: totalSize)
        }.value
    }
}