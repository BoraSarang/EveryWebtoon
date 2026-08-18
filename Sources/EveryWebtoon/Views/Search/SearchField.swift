import SwiftUI

struct SearchField: View {
    @ObservedObject var searchVM: SearchViewModel
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundColor(.secondary)
            TextField("내 보관함 검색", text: searchBinding)
                .textFieldStyle(.plain)
                .focused(isFocused)
            if !searchVM.query.isEmpty {
                Button {
                    searchVM.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("검색 지우기")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.12))
        )
        .frame(maxWidth: .infinity)
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { searchVM.query },
            set: { searchVM.updateQuery($0) }
        )
    }
}
