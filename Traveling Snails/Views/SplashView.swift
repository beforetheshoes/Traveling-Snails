import SwiftUI
import WebKit

struct SplashView: View {
    @Binding var isVisible: Bool
    
    var body: some View {
        ZStack {
            // Background color matching your SVG
            Color(red: 135/255, green: 206/255, blue: 235/255)
                .edgesIgnoringSafeArea(.all)
            
            AnimatedSVGView()
                .edgesIgnoringSafeArea(.all)
        }
        .onAppear {
            // Auto-dismiss after 4 seconds (adjust as needed)
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isVisible = false
                }
            }
        }
        .onTapGesture {
            // Allow tap to dismiss early
            withAnimation(.easeInOut(duration: 0.3)) {
                isVisible = false
            }
        }
    }
}

struct AnimatedSVGView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Optimize for performance
        configuration.suppressesIncrementalRendering = false
        configuration.allowsAirPlayForMediaPlayback = false
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        
        // Configure webview for optimal SVG display
        webView.backgroundColor = UIColor.clear
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        // Disable context menu
        webView.allowsLinkPreview = false
        
        // Set navigation delegate for error handling
        webView.navigationDelegate = context.coordinator
        
        loadAnimatedSVG(in: webView)
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    private func loadAnimatedSVG(in webView: WKWebView) {
        guard let svgURL = Bundle.main.url(forResource: "traveling-snails-animation", withExtension: "svg"),
              let svgData = try? Data(contentsOf: svgURL),
              let svgString = String(data: svgData, encoding: .utf8) else {
            print("❌ Failed to load animated SVG file")
            return
        }
        
        let optimizedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
            <meta charset="UTF-8">
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                
                html, body {
                    width: 100vw;
                    height: 100vh;
                    background: transparent;
                    overflow: hidden;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    -webkit-user-select: none;
                    user-select: none;
                }
                
                .svg-container {
                    width: 100%;
                    height: 100%;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    background: transparent;
                }
                
                svg {
                    max-width: 95%;
                    max-height: 95%;
                    width: auto;
                    height: auto;
                }
                
                /* Ensure animations run smoothly */
                svg * {
                    animation-play-state: running !important;
                }
                
                /* Optimize rendering */
                svg {
                    shape-rendering: optimizeSpeed;
                    text-rendering: optimizeSpeed;
                }
            </style>
        </head>
        <body>
            <div class="svg-container">
                \(svgString)
            </div>
            
            <script>
                // Optimize for performance and ensure animations start
                document.addEventListener('DOMContentLoaded', function() {
                    const svg = document.querySelector('svg');
                    if (svg) {
                        // Ensure SVG is visible and animations are running
                        svg.style.visibility = 'visible';
                        svg.style.opacity = '1';
                        
                        // Force reflow to ensure animations start
                        svg.getBoundingClientRect();
                        
                        console.log('✅ Animated SVG loaded successfully');
                    } else {
                        console.error('❌ SVG element not found');
                    }
                });
                
                // Prevent any interactions that might interfere
                document.addEventListener('touchmove', function(e) {
                    e.preventDefault();
                }, { passive: false });
                
                document.addEventListener('gesturestart', function(e) {
                    e.preventDefault();
                });
                
                document.addEventListener('contextmenu', function(e) {
                    e.preventDefault();
                });
            </script>
        </body>
        </html>
        """
        
        webView.loadHTMLString(optimizedHTML, baseURL: nil)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Animation loaded successfully
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ SVG WebView failed to load: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ SVG WebView navigation failed: \(error.localizedDescription)")
        }
    }
}

// Alternative: If you want to customize the splash duration or add fade effects
struct CustomizableSplashView: View {
    @Binding var isVisible: Bool
    let splashDuration: TimeInterval
    let fadeOutDuration: TimeInterval
    
    @State private var svgOpacity: Double = 0
    
    init(isVisible: Binding<Bool>,
         splashDuration: TimeInterval = 4.0,
         fadeOutDuration: TimeInterval = 0.5) {
        self._isVisible = isVisible
        self.splashDuration = splashDuration
        self.fadeOutDuration = fadeOutDuration
    }
    
    var body: some View {
        ZStack {
            Color(red: 135/255, green: 206/255, blue: 235/255)
                .edgesIgnoringSafeArea(.all)
            
            AnimatedSVGView()
                .opacity(svgOpacity)
                .edgesIgnoringSafeArea(.all)
        }
        .onAppear {
            // Fade in the SVG
            withAnimation(.easeIn(duration: 0.5)) {
                svgOpacity = 1.0
            }
            
            // Auto-dismiss after specified duration
            DispatchQueue.main.asyncAfter(deadline: .now() + splashDuration) {
                dismissSplash()
            }
        }
        .onTapGesture {
            dismissSplash()
        }
    }
    
    private func dismissSplash() {
        withAnimation(.easeOut(duration: fadeOutDuration)) {
            svgOpacity = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration) {
            isVisible = false
        }
    }
}

#Preview {
    SplashView(isVisible: .constant(true))
}
