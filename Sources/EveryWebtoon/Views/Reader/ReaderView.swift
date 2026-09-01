import SwiftUI
import AppKit

struct ReaderView: View {
    let webtoon: Webtoon
    let episodes: [Episode]
    let startEpisode: Int
    var onClose: (() -> Void)? = nil

    @StateObject private var viewModel: ReaderViewModel
    @State private var scrollViewRef: NSScrollView?
    @State private var keyMonitor: Any?
    @State private var boundsObserver: (any NSObjectProtocol)?
    @State private var lastFraction: Double = 0
    @State private var lastSavedFraction: Double = -1
    @State private var restorePending = false
    @State private var showFilterPopover = false
    @State private var positionSaveTimer: Timer?
    @State private var windowObservers: [NSObjectProtocol] = []
    @State private var barHideTask: DispatchWorkItem?
    @State private var autoScrollTimer: Timer?
    @State private var showSettingsPopover = false

    init(webtoon: Webtoon, episodes: [Episode], startEpisode: Int, onClose: (() -> Void)? = nil) {
        self.webtoon = webtoon
        self.episodes = episodes
        self.startEpisode = startEpisode
        self.onClose = onClose
        _viewModel = StateObject(wrappedValue: ReaderViewModel(
            webtoon: webtoon,
            episodes: episodes,
            startEpisode: startEpisode
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .opacity(viewModel.showBars ? 1 : 0)

            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else if viewModel.pages.isEmpty {
                emptyView
            } else {
                readerContent
            }

            bottomBar
                .opacity(viewModel.showBars ? 1 : 0)
        }
        .frame(minWidth: 360, minHeight: 640)
        .background(.black)
        .animation(.easeInOut(duration: 0.15), value: viewModel.showBars)
        .onAppear {
            installKeyMonitor()
            viewModel.loadEpisode(startEpisode)
            startPositionSaveTimer()
        }
        .onDisappear {
            stopAutoScroll()
            removeKeyMonitor()
            saveCurrentPosition()
            positionSaveTimer?.invalidate()
            positionSaveTimer = nil
        }
        .onChange(of: viewModel.currentEpisodeNo) { _, newNo in
            ReaderWindowManager.shared.updateTitle("\(webtoon.title) - \(newNo)화")
            if viewModel.autoScroll, autoScrollTimer == nil {
                startAutoScroll()
            }
        }
    }

    // MARK: - 이어보기 fraction 로직

    private func handleFractionChange(_ fraction: Double) {
        let delta = fraction - lastFraction

        if fraction >= 0.98, delta > 0.0005, !viewModel.isLoading, viewModel.hasNext {
            viewModel.goNext()
            lastFraction = 1
            return
        }
        if abs(delta) >= 0.0005 {
            restorePending = false
            saveFractionIfChanged(fraction)
        }
        lastFraction = fraction
    }

    // MARK: - 자동 스크롤 (Auto Scroll)

    private func toggleAutoScroll() {
        if autoScrollTimer != nil {
            stopAutoScroll()
        } else {
            startAutoScroll()
        }
    }

    private func startAutoScroll() {
        stopAutoScroll()
        guard scrollViewRef != nil, !viewModel.pages.isEmpty else {
            viewModel.setAutoScroll(true)
            return
        }
        viewModel.setAutoScroll(true)
        DebugLogger.shared.push(.INFO, category: "Reader", message: "[FEATURE] auto scroll start", meta: "speed=\(viewModel.autoScrollSpeed)")
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard let sv = self.scrollViewRef, self.viewModel.autoScroll else { return }
            self.advanceAutoScroll(in: sv)
        }
    }

    private func advanceAutoScroll(in scrollView: NSScrollView) {
        let clip = scrollView.contentView
        let doc = scrollView.documentView?.frame.height ?? 0
        let viewport = clip.bounds.height
        guard doc > viewport else {
            handleFractionChange(1)
            return
        }
        let maxY = doc - viewport
        // 초당 fraction 이동 (0.05s/tick). 하한을 둬서 최저 스크롤도 0으로 안 끊기게 함
        let perSecondFraction = 0.001 + viewModel.autoScrollSpeed * 0.004
        let step = max(maxY * perSecondFraction * 0.05, 0.5)
        let current = clip.bounds.origin.y
        let target = min(maxY, current + step)
        if target >= maxY * 0.98 {
            if !viewModel.hasNext {
                handleFractionChange(1)
                stopAutoScroll()
            } else {
                handleFractionChange(1)
            }
        } else {
            smoothlyScroll(in: scrollView, to: target, duration: 0.08)
            handleFractionChange(Double(target / maxY))
        }
    }

    private func smoothlyScroll(in scrollView: NSScrollView, to target: CGFloat, duration: TimeInterval) {
        let clip = scrollView.contentView
        guard clip.bounds.origin.y != target else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: .linear)
            clip.animator().setBoundsOrigin(NSPoint(x: clip.bounds.origin.x, y: target))
            scrollView.reflectScrolledClipView(clip)
        }
    }

    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
        viewModel.setAutoScroll(false)
    }

    private func saveFractionIfChanged(_ fraction: Double) {
        if abs(fraction - lastSavedFraction) >= 0.0005 {
            lastSavedFraction = fraction
            viewModel.savePosition(fraction: fraction)
            DebugLogger.shared.push(.INFO, category: "Reader", message: "saved \(viewModel.currentEpisodeNo)화 fraction=\(fraction)")
        }
    }

    private func saveCurrentPosition() {
        guard let sv = scrollViewRef, !viewModel.pages.isEmpty else { return }
        viewModel.savePosition(fraction: fraction(of: sv))
    }

    // MARK: - macOS 전용: 키보드/스크롤뷰 계측

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.window != nil, event.window?.isKeyWindow == true {
                if event.modifierFlags.contains(.command) {
                    if event.keyCode == 29 { // ⌘0
                        viewModel.fitWidth.toggle()
                        return nil
                    }
                    return event
                }
                switch event.keyCode {
                case 53: // ESC
                    onClose?()
                    return nil
                case 49: // Space
                    stopAutoScroll()
                    viewModel.goNext()
                    return nil
                case 123: // ←
                    stopAutoScroll()
                    viewModel.goPrevious()
                    return nil
                case 124: // →
                    stopAutoScroll()
                    viewModel.goNext()
                    return nil
                case 126: // ↑
                    stopAutoScroll()
                    scrollBy(-1)
                    return nil
                case 125: // ↓
                    stopAutoScroll()
                    scrollBy(1)
                    return nil
                default:
                    break
                }
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func scrollBy(_ direction: CGFloat) {
        guard let sv = scrollViewRef else { return }
        let clip = sv.contentView
        let viewport = clip.bounds.height
        let current = clip.bounds.origin.y
        let documentHeight = sv.documentView?.frame.height ?? 0
        let maxY = max(0, documentHeight - viewport)
        let target = min(maxY, max(0, current + viewport * direction * CGFloat(viewModel.scrollStep)))

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            clip.animator().setBoundsOrigin(NSPoint(x: 0, y: target))
            sv.reflectScrolledClipView(clip)
        }
    }

    private func setupScrollObservation(for scrollView: NSScrollView) {
        if let old = boundsObserver {
            NotificationCenter.default.removeObserver(old)
            boundsObserver = nil
        }
        restorePending = false
        lastSavedFraction = -1
        let clip = scrollView.contentView
        clip.postsBoundsChangedNotifications = true
        DebugLogger.shared.push(
            .INFO, category: "Reader",
            message: "scrollview found, restoreFraction=\(viewModel.restoreFraction)",
            meta: "doc=\(scrollView.documentView?.frame.height ?? 0) viewport=\(clip.bounds.height)"
        )
        windowObservers.forEach(NotificationCenter.default.removeObserver)
        windowObservers.removeAll()
        if let win = scrollView.window {
            windowObservers.append(NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: win,
                queue: .main
            ) { _ in
                DispatchQueue.main.async { self.windowClosed() }
            })
            windowObservers.append(NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: win,
                queue: .main
            ) { _ in
                DispatchQueue.main.async { self.saveCurrentPosition() }
            })
        }
        boundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clip,
            queue: .main
        ) { _ in
            handleScrollChange(scrollView)
        }
        lastFraction = fraction(of: scrollView)
        if viewModel.restoreFraction > 0 {
            restoreScroll(in: scrollView, fraction: viewModel.restoreFraction)
        }
    }

    private func fraction(of scrollView: NSScrollView) -> Double {
        let clip = scrollView.contentView
        let doc = scrollView.documentView?.frame.height ?? 0
        let viewport = clip.bounds.height
        guard doc > viewport else { return 0 }
        return Double(clip.bounds.origin.y / (doc - viewport))
    }

    private func handleScrollChange(_ scrollView: NSScrollView) {
        handleFractionChange(fraction(of: scrollView))
    }

    private func startPositionSaveTimer() {
        positionSaveTimer?.invalidate()
        positionSaveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard let sv = self.scrollViewRef, !self.viewModel.pages.isEmpty else { return }
            self.saveFractionIfChanged(self.fraction(of: sv))
        }
    }

    private func windowClosed() {
        saveCurrentPosition()
        positionSaveTimer?.invalidate()
        positionSaveTimer = nil
        windowObservers.forEach(NotificationCenter.default.removeObserver)
        windowObservers.removeAll()
    }

    private func restoreScroll(in scrollView: NSScrollView, fraction: Double) {
        restorePending = true
        let apply: () -> Bool = {
            guard self.restorePending, let sv = self.scrollViewRef else { return false }
            let clip = sv.contentView
            let doc = sv.documentView?.frame.height ?? 0
            let viewport = clip.bounds.height
            guard doc > viewport else {
                DebugLogger.shared.push(.WARN, category: "Reader", message: "restore skipped: layout not ready", meta: "doc=\(doc) viewport=\(viewport)")
                return false
            }
            let target = max(0, min((doc - viewport) * CGFloat(fraction), doc - viewport))
            self.lastFraction = fraction
            clip.setBoundsOrigin(NSPoint(x: 0, y: target))
            sv.reflectScrolledClipView(clip)
            DebugLogger.shared.push(.INFO, category: "Reader", message: "restore applied", meta: "fraction=\(fraction) target=\(target)")
            return true
        }
        _ = apply()
        for delay in [0.1, 0.2, 0.4, 0.6, 1.0, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                _ = apply()
            }
        }
    }

    // MARK: - 상단/하단 바 (공용)

    private var topBar: some View {
        HStack {
            Button(action: { onClose?() }) {
                Label("닫기", systemImage: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
            .help("닫기 (ESC)")

            Text("\(webtoon.title) - \(viewModel.currentEpisodeNo)화")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundColor(.white)

            Spacer()

            Button {
                toggleAutoScroll()
            } label: {
                Image(systemName: viewModel.autoScroll ? "pause.fill" : "play.fill")
                    .foregroundColor(viewModel.autoScroll ? .yellow : .white)
            }
            .buttonStyle(.plain)
            .help(viewModel.autoScroll ? "자동 스크롤 정지" : "자동 스크롤 시작")

            Button {
                showSettingsPopover.toggle()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
            .help("뷰어 설정 (자동 스크롤 속도/스크롤 보폭/여백)")
            .popover(isPresented: $showSettingsPopover, arrowEdge: .bottom) {
                readerSettingsPopover
            }

            Button {
                viewModel.showMagnifier.toggle()
            } label: {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(viewModel.showMagnifier ? .yellow : .white)
            }
            .buttonStyle(.plain)
            .help(viewModel.showMagnifier
                ? "확대경 켜짐: 페이지에 마우스를 올리면 확대됩니다"
                : "확대경 꺼짐 (기본)")

            Button {
                showFilterPopover.toggle()
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
            .help("이미지 필터 (밝기/대비)")
            .popover(isPresented: $showFilterPopover, arrowEdge: .bottom) {
                filterPopover
            }

            Button(action: { viewModel.fitWidth.toggle() }) {
                Image(systemName: viewModel.fitWidth
                    ? "rectangle.compress.vertical"
                    : "rectangle.expand.vertical")
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
            .help(viewModel.fitWidth
                ? "폭 맞춤 켜짐: 페이지 전체가 보이도록 표시"
                : "폭 맞춤 꺼짐: 이미지가 화면을 꽉 채움")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.8))
    }

    private var filterPopover: some View {
        VStack(spacing: 12) {
            Text("이미지 필터")
                .font(.headline)
            HStack {
                Text("밝기")
                Slider(value: $viewModel.brightness, in: -0.5...0.5)
                Text(String(format: "%+.0f%%", viewModel.brightness * 100))
                    .font(.caption.monospacedDigit())
                    .frame(width: 48, alignment: .trailing)
            }
            HStack {
                Text("대비")
                Slider(value: $viewModel.contrast, in: 0.5...1.8)
                Text(String(format: "%.2f", viewModel.contrast))
                    .font(.caption.monospacedDigit())
                    .frame(width: 48, alignment: .trailing)
            }
            HStack {
                Spacer()
                Button("초기화") {
                    viewModel.brightness = 0
                    viewModel.contrast = 1
                }
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 260)
    }

    private var readerSettingsPopover: some View {
        VStack(spacing: 12) {
            Text("뷰어 설정")
                .font(.headline)
            HStack {
                Text("자동 스크롤 속도")
                Slider(value: $viewModel.autoScrollSpeed, in: 0.1...2.0)
                Text(String(format: "%.1fx", viewModel.autoScrollSpeed))
                    .font(.caption.monospacedDigit())
                    .frame(width: 44, alignment: .trailing)
            }
            HStack {
                Text("스크롤 보폭")
                Picker("", selection: $viewModel.scrollStep) {
                    Text("세밀").tag(0.5)
                    Text("기본").tag(1.0)
                    Text("크게").tag(2.0)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            HStack {
                Text("좌우 여백")
                Slider(value: $viewModel.horizontalPadding, in: 0...20)
                Text("\(Int(viewModel.horizontalPadding))pt")
                    .font(.caption.monospacedDigit())
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private var bottomBar: some View {
        HStack {
            Button(action: { viewModel.goPrevious() }) {
                Label("이전화", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)
            .foregroundColor(viewModel.hasPrevious ? .white : .gray)
            .disabled(!viewModel.hasPrevious)
            .help("이전화 (←)")

            Spacer()

            Menu {
                ForEach(episodes.sorted { $0.episodeNo > $1.episodeNo }, id: \.episodeNo) { ep in
                    Button {
                        viewModel.loadEpisode(ep.episodeNo)
                    } label: {
                        if ep.episodeNo == viewModel.currentEpisodeNo {
                            Label("\(ep.episodeNo)화", systemImage: "checkmark")
                        } else {
                            Text("\(ep.episodeNo)화")
                        }
                    }
                }
            } label: {
                Text("\(viewModel.currentEpisodeNo)화")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .underline(true, color: .gray)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("회차 선택")

            Spacer()

            Button(action: { viewModel.goNext() }) {
                Label("다음화", systemImage: "chevron.right")
                    .labelStyle(.trailingIcon)
            }
            .buttonStyle(.plain)
            .foregroundColor(viewModel.hasNext ? .white : .gray)
            .disabled(!viewModel.hasNext)
            .help("다음화 (→)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.8))
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(.white)
            Text("다운로드 중... \(Int(viewModel.downloadProgress * 100))%")
                .font(.subheadline)
                .foregroundColor(.gray)
            if viewModel.downloadTotalPages > 0 || viewModel.downloadTotalBytes > 0 {
                Text("\(viewModel.downloadCurrentPage)/\(viewModel.downloadTotalPages) 페이지 · \(ByteFormat.string(bytes: viewModel.downloadCurrentBytes)) / \(ByteFormat.string(bytes: viewModel.downloadTotalBytes))")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.8))
                    .monospacedDigit()
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.yellow)
            Text(error)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("다시 시도") {
                viewModel.loadEpisode(viewModel.currentEpisodeNo)
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "photo.on.rectangle")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text("불러올 페이지가 없습니다")
                .font(.body)
                .foregroundColor(.gray)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 뷰어 콘텐츠

    private var readerContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.pages.enumerated()), id: \.offset) { index, path in
                    ReaderPageView(
                        path: path,
                        fitWidth: viewModel.fitWidth,
                        brightness: viewModel.brightness,
                        contrast: viewModel.contrast,
                        magnifierEnabled: viewModel.showMagnifier
                    )
                    .padding(.horizontal, viewModel.horizontalPadding)
                }
            }
            .background(ScrollViewFinder { scrollView in
                scrollViewRef = scrollView
                setupScrollObservation(for: scrollView)
            })
        }
        .id("reader-scroll-\(viewModel.currentEpisodeNo)")
        .background(.black)
        .scrollIndicators(.visible)
        .onContinuousHover { phase in
            switch phase {
            case .active:
                DebugLogger.shared.push(.INFO, category: "Reader", message: "hover active")
                barHideTask?.cancel()
                if !viewModel.showBars {
                    viewModel.showBars = true
                }
            case .ended:
                DebugLogger.shared.push(.INFO, category: "Reader", message: "hover ended, hiding in 1.6s")
                let task = DispatchWorkItem { viewModel.showBars = false }
                barHideTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: task)
            }
        }
    }
}
