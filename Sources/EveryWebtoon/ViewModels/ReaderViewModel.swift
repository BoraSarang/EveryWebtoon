import Foundation
import Combine

@MainActor
final class ReaderViewModel: ObservableObject {
    @Published var pages: [String] = []
    @Published var currentEpisodeNo: Int
    @Published var fitWidth = true
    @Published var showBars = true
    @Published var brightness: Double = 0
    @Published var contrast: Double = 1
    @Published var showMagnifier = false
    @Published var isLoading = false
    @Published var downloadProgress: Double = 0
    @Published var downloadCurrentPage = 0
    @Published var downloadTotalPages = 0
    @Published var downloadCurrentBytes = 0
    @Published var downloadTotalBytes = 0
    @Published var downloadSpeed = ""
    @Published var errorMessage: String?
    @Published var restoreFraction: Double = 0
    @Published var autoScroll = false
    @Published var autoScrollSpeed: Double = 0.5
    @Published var scrollStep: Double = 1.0
    @Published var horizontalPadding: CGFloat = 0

    let webtoon: Webtoon
    let episodes: [Episode]
    let localManager = LocalWebtoonManager.shared
    private var downloadTask: Task<Void, Never>?

    private var currentEpisode: Episode? {
        episodes.first(where: { $0.episodeNo == currentEpisodeNo })
    }

    var hasPrevious: Bool {
        guard let current = currentEpisode else { return false }
        return episodes.contains { $0.episodeNo < current.episodeNo }
    }

    var hasNext: Bool {
        guard let current = currentEpisode else { return false }
        return episodes.contains { $0.episodeNo > current.episodeNo }
    }

    init(webtoon: Webtoon, episodes: [Episode], startEpisode: Int) {
        self.webtoon = webtoon
        self.episodes = episodes
        self.currentEpisodeNo = startEpisode
    }

    func loadEpisode(_ episodeNo: Int) {
        downloadTask?.cancel()
        var targetNo = episodeNo
        if targetNo <= 0, let first = episodes.first {
            targetNo = first.episodeNo
        }
        currentEpisodeNo = targetNo
        guard targetNo > 0 else {
            errorMessage = "회차 번호를 찾을 수 없습니다 (episodeNo=\(episodeNo))"
            return
        }
        pages = localManager.pagePaths(webtoonTitle: webtoon.title, episodeNo: targetNo)
        restoreFraction = ReadHistoryManager.shared.lastPosition(webtoonId: webtoon.id, episodeNo: targetNo) ?? 0
        let incomplete = localManager.isDownloadIncomplete(webtoonTitle: webtoon.title, episodeNo: targetNo)
        if pages.isEmpty || incomplete {
            if let task = DownloadViewModel.shared.activeTask(webtoon: webtoon, episodeNo: targetNo) {
                waitForTask(task.id, episodeNo: targetNo)
            } else {
                downloadAndLoad(targetNo)
            }
        } else {
            recordView(targetNo)
        }
    }

    private func waitForTask(_ taskId: UUID, episodeNo: Int) {
        isLoading = true
        errorMessage = nil
        downloadTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard let task = DownloadViewModel.shared.tasks.first(where: { $0.id == taskId }) else {
                    errorMessage = "다운로드가 취소되었습니다"
                    isLoading = false
                    return
                }
                switch task.status {
                case .done:
                    pages = localManager.pagePaths(webtoonTitle: webtoon.title, episodeNo: episodeNo)
                    restoreFraction = ReadHistoryManager.shared.lastPosition(webtoonId: webtoon.id, episodeNo: episodeNo) ?? 0
                    isLoading = false
                    recordView(episodeNo)
                    return
                case .failed:
                    errorMessage = "다운로드 실패: \(task.errorMessage ?? "알 수 없는 오류")"
                    isLoading = false
                    return
                default:
                    downloadProgress = task.progress
                }
            }
            if Task.isCancelled {
                isLoading = false
            }
        }
    }

    private func recordView(_ episodeNo: Int) {
        ReadHistoryManager.shared.record(webtoonId: webtoon.id, episodeNo: episodeNo)
        LocalWebtoonManager.shared.saveWebtoon(webtoon)
    }

    private func downloadAndLoad(_ episodeNo: Int) {
        isLoading = true
        errorMessage = nil
        downloadProgress = 0

        let externalId = DownloadViewModel.shared.registerExternal(webtoon: webtoon, episodeNo: episodeNo)

        downloadTask = Task {
            do {
                _ = try await PythonBridge.shared.call(
                    action: "download_episode",
                    params: [
                        "platform": webtoon.platform.rawValue,
                        "title_id": webtoon.platformId,
                        "title_name": webtoon.title,
                        "episode_no": episodeNo,
                    ],
                    onProgress: { [weak self] progress in
                        DispatchQueue.main.async {
                            guard let self else { return }
                            self.downloadProgress = Double(progress.currentPage) / Double(max(progress.totalPages, 1))
                            self.downloadCurrentPage = progress.currentPage
                            self.downloadTotalPages = progress.totalPages
                            self.downloadCurrentBytes = progress.currentBytes
                            self.downloadTotalBytes = progress.totalBytes
                            self.downloadSpeed = progress.speed
                            if let externalId {
                                DownloadViewModel.shared.handleProgress(id: externalId, progress: progress)
                            }
                        }
                    },
                    taskId: externalId?.uuidString,
                    timeout: 180
                )
                if let externalId {
                    DownloadViewModel.shared.finishExternal(id: externalId, success: true)
                }
                if !Task.isCancelled {
                    pages = localManager.pagePaths(webtoonTitle: webtoon.title, episodeNo: episodeNo)
                    restoreFraction = ReadHistoryManager.shared.lastPosition(webtoonId: webtoon.id, episodeNo: episodeNo) ?? 0
                    isLoading = false
                    recordView(episodeNo)
                }
            } catch {
                if let externalId {
                    DownloadViewModel.shared.finishExternal(id: externalId, success: false)
                }
                if !Task.isCancelled {
                    errorMessage = "다운로드 실패: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    func goPrevious() {
        guard let current = currentEpisode else { return }
        guard let prev = episodes
            .filter({ $0.episodeNo < current.episodeNo })
            .max(by: { $0.episodeNo < $1.episodeNo })
        else { return }
        loadEpisode(prev.episodeNo)
    }

    func goNext() {
        guard let current = currentEpisode else { return }
        guard let next = episodes
            .filter({ $0.episodeNo > current.episodeNo })
            .min(by: { $0.episodeNo < $1.episodeNo })
        else { return }
        loadEpisode(next.episodeNo)
    }

    func savePosition(fraction: Double) {
        ReadHistoryManager.shared.recordPosition(
            webtoonId: webtoon.id,
            episodeNo: currentEpisodeNo,
            fraction: fraction
        )
    }

    func setAutoScroll(_ on: Bool) {
        autoScroll = on
    }

    deinit {
        downloadTask?.cancel()
    }
}
