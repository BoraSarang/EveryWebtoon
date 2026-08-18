import SwiftUI

struct CollectionAddMenu: View {
    let webtoonId: String
    var onCreate: (() -> Void)? = nil

    @ObservedObject private var collections = CollectionsManager.shared
    @State private var showCreateAlert = false
    @State private var newName = ""

    var body: some View {
        ForEach(collections.names, id: \.self) { name in
            Button {
                collections.toggle(webtoonId, in: name)
            } label: {
                Label(
                    collections.isIn(webtoonId, name: name) ? "\(name)에서 제거" : "\(name)에 추가",
                    systemImage: collections.isIn(webtoonId, name: name) ? "checkmark" : "plus"
                )
            }
        }
        Divider()
        Button("새 모음 만들기…") {
            newName = ""
            showCreateAlert = true
        }
        .alert("새 모음 만들기", isPresented: $showCreateAlert) {
            TextField("모음 이름", text: $newName)
            Button("만들기") {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty, collections.create(name) {
                    collections.toggle(webtoonId, in: name)
                }
                newName = ""
                onCreate?()
            }
            Button("취소", role: .cancel) {
                newName = ""
            }
        } message: {
            Text("새 모음에 이 웹툰을 추가합니다.")
        }
    }
}
