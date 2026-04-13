import SwiftUI
import WebKit

struct EmbeddedWebView: View {
    @Binding var url: URL?

    var body: some View {
        Group {
#if os(macOS) || targetEnvironment(macCatalyst)
            if let url {
                WebViewContainer(url: url)
            } else {
                placeholder
            }
#else
            placeholder
#endif
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("動画を選択するとここに表示します")
                .font(.headline)
            Text("WebView は常時表示です")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
    }
}

#if os(macOS)
private struct WebViewContainer: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard nsView.url != url else { return }
        nsView.load(URLRequest(url: url))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {}
}
#elseif targetEnvironment(macCatalyst)
private struct WebViewContainer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard uiView.url != url else { return }
        uiView.load(URLRequest(url: url))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {}
}
#endif
