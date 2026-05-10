import SwiftUI

/// Drag-driven horizontal carousel inspired by Kavsoft's signature paging
/// transitions: as a page moves away from center it scales down, fades, and
/// blurs slightly. The active page snaps with a spring and its content
/// receives a small parallax offset so backgrounds/illustrations feel
/// layered against the foreground.
///
/// Compared to SwiftUI's built-in `TabView(.page)` style, this carousel:
/// - applies the scale/blur/opacity transform during the *drag itself*, not
///   only at snap points;
/// - exposes the live drag offset to children via `OnboardingDragProgress`
///   so they can drive their own parallax;
/// - matches programmatic `currentIndex` changes with a spring snap.
struct KavsoftCarousel<Data: RandomAccessCollection, Content: View>: View
where Data.Index == Int {
    @Binding var currentIndex: Int
    let data: Data
    let isDragEnabled: Bool
    let content: (Data.Element, Int) -> Content

    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging = false

    /// Min scale applied to the page furthest visible during drag.
    private let minScale: CGFloat = 0.92
    /// Min opacity applied to the page furthest visible during drag.
    private let minOpacity: Double = 0.55
    /// Max blur radius applied to the page furthest visible during drag.
    private let maxBlur: CGFloat = 6

    init(
        currentIndex: Binding<Int>,
        data: Data,
        isDragEnabled: Bool = true,
        @ViewBuilder content: @escaping (Data.Element, Int) -> Content
    ) {
        self._currentIndex = currentIndex
        self.data = data
        self.isDragEnabled = isDragEnabled
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let baseOffset = -CGFloat(currentIndex) * width

            carouselPages(width: width, height: height, baseOffset: baseOffset)
                .environment(
                    \.onboardingDragProgress,
                    OnboardingDragProgress(
                        activeIndex: currentIndex,
                        dragFraction: width > 0 ? Double(dragOffset / width) : 0
                    )
                )
        }
    }

    @ViewBuilder
    private func carouselPages(width: CGFloat, height: CGFloat, baseOffset: CGFloat) -> some View {
        let pages = ZStack {
            ForEach(Array(data.enumerated()), id: \.offset) { index, element in
                pageView(element: element, index: index, width: width, height: height)
                    .offset(x: CGFloat(index) * width)
            }
        }
        .frame(width: width, alignment: .leading)
        .offset(x: baseOffset + dragOffset)
        // Programmatic index changes (Continue tap) use this spring; the
        // drag-end branch wraps its own withAnimation so swipes still
        // settle with the same feel.
        .animation(.spring(response: 0.55, dampingFraction: 0.78), value: currentIndex)
        .contentShape(Rectangle())

        if isDragEnabled {
            pages.gesture(dragGesture(width: width))
        } else {
            pages
        }
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($isDragging) { _, state, _ in state = true }
            .onChanged { value in
                let raw = value.translation.width
                // Rubber-band at the ends so swiping past page 0 or
                // the last page resists rather than tearing off-screen.
                if (currentIndex == 0 && raw > 0) ||
                    (currentIndex == data.count - 1 && raw < 0) {
                    dragOffset = raw / 2.5
                } else {
                    dragOffset = raw
                }
            }
            .onEnded { value in
                let predicted = value.predictedEndTranslation.width
                let threshold = width * 0.22
                var newIndex = currentIndex

                if predicted < -threshold && currentIndex < data.count - 1 {
                    newIndex = currentIndex + 1
                } else if predicted > threshold && currentIndex > 0 {
                    newIndex = currentIndex - 1
                }

                withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                    currentIndex = newIndex
                    dragOffset = 0
                }
            }
    }

    private func pageView(element: Data.Element, index: Int, width: CGFloat, height: CGFloat) -> some View {
        // distance: 0 when this page is centered, 1 when fully off to the next slot.
        let distancePoints = CGFloat(index - currentIndex) * width - dragOffset
        let normalized = width > 0 ? min(abs(distancePoints) / width, 1) : 0

        let scale = 1 - (1 - minScale) * normalized
        let opacity = 1 - (1 - minOpacity) * normalized
        let blur = maxBlur * normalized

        return content(element, index)
            .frame(width: width, height: height)
            .scaleEffect(scale)
            .opacity(opacity)
            .blur(radius: blur)
            // Spring on programmatic step changes (Continue button taps) so
            // the off-center transform settles with the same bounce as the
            // page slide itself. easeOut here flattened the feel.
            .animation(.spring(response: 0.5, dampingFraction: 0.78), value: currentIndex)
    }
}

// MARK: - Drag progress environment

/// Snapshot of the live carousel drag so children can react with parallax
/// or other depth effects without observing the drag gesture themselves.
struct OnboardingDragProgress: Equatable {
    var activeIndex: Int
    /// Drag fraction in `[-1, 1]`; positive means dragging right (toward
    /// previous page), negative means dragging left (toward next page).
    var dragFraction: Double

    static let zero = OnboardingDragProgress(activeIndex: 0, dragFraction: 0)
}

private struct OnboardingDragProgressKey: EnvironmentKey {
    static let defaultValue: OnboardingDragProgress = .zero
}

extension EnvironmentValues {
    var onboardingDragProgress: OnboardingDragProgress {
        get { self[OnboardingDragProgressKey.self] }
        set { self[OnboardingDragProgressKey.self] = newValue }
    }
}
