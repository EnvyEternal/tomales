import SwiftUI

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct AdaptiveScrollView<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        GeometryReader { viewport in
            let needsScrolling = contentHeight > viewport.size.height + 1
            scrollContent(needsScrolling: needsScrolling)
                .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
        }
    }

    @ViewBuilder
    private func scrollContent(needsScrolling: Bool) -> some View {
        if #available(macOS 13.3, *) {
            scrollView(needsScrolling: needsScrolling).scrollBounceBehavior(.basedOnSize, axes: .vertical)
        } else {
            scrollView(needsScrolling: needsScrolling)
        }
    }

    private func scrollView(needsScrolling: Bool) -> some View {
        ScrollView(.vertical) {
            content()
                .frame(maxWidth: .infinity)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: ContentHeightKey.self, value: geometry.size.height)
                    }
                }
                .padding(.bottom, needsScrolling ? 16 : 0)
        }
        .scrollDisabled(!needsScrolling)
        .scrollIndicators(needsScrolling ? .visible : .hidden)
    }
}
