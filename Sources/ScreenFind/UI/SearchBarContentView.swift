import SwiftUI

struct SearchBarContentView: View {
    @ObservedObject var viewModel: SearchViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search screen...", text: $viewModel.query)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .font(.system(size: 16))
                .onSubmit { viewModel.navigateToNext() }

            if !viewModel.isOCRComplete {
                ProgressView()
                    .controlSize(.small)
            }

            if !viewModel.query.isEmpty && viewModel.isOCRComplete {
                Text("\(viewModel.totalMatches > 0 ? "\(viewModel.currentMatchIndex + 1)" : "0")/\(viewModel.totalMatches)")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .monospacedDigit()

                Button(action: viewModel.navigateToPrevious) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)

                Button(action: viewModel.navigateToNext) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .frame(width: 420, height: 44)
        .onAppear { isFocused = true }
    }
}
