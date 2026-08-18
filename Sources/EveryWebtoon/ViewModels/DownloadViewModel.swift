import Foundation

@MainActor
final class DownloadViewModel: ObservableObject {
    static let shared = DownloadViewModel()

    @Published var tasks: [DownloadTask] = []

    var doneCount: Int { tasks.filter { $0.status == .done }.count }

    private var activeCount = 0

    func registerExternal(webtoon: Webtoon, episodeNo: Int) -> UUID? {
        if tasks.contains(where: { $0.webtoon.id == webtoon.id && $0.episodeNo == episodeNo }) {
            return nil
        }
        let task = DownloadTask(
            webtoon: webtoon,
            episodeNo: episodeNo,
            progress: 0,
            currentPage: 0,
            totalPages: 0,
            speed: "",
            eta: "",
            status: .downloading
        )
        tasks.append(task)
        return task.id
    }

    func handleProgress(id: UUID, progress: DownloadProgress) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].currentPage = progress.currentPage
        tasks[idx].totalPages = progress.totalPages
        tasks[idx].speed = progress.speed
        tasks[idx].eta = progress.eta
        tasks[idx].currentBytes = progress.currentBytes
        tasks[idx].totalBytes = progress.totalBytes
        tasks[idx].progress = Double(progress.currentPage) / Double(max(progress.totalPages, 1))
        if progress.status == "done" {
            tasks[idx].status = .done
            tasks[idx].progress = 1.0
        }
    }

    func finishExternal(id: UUID, success: Bool) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].status = success ? .done : .failed
        if success {
            tasks[idx].progress = 1.0
        }
    }

    var activeTasks: [DownloadTask] {
        tasks.filter { $0.status == .downloading }
    }

    var queuedTasks: [DownloadTask] {
        tasks.filter { $0.status == .none }
    }

    var completedTasks: [DownloadTask] {
        tasks.filter { $0.status == .done }
    }

    func activeTask(webtoon: Webtoon, episodeNo: Int) -> DownloadTask? {
        tasks.first {
            $0.webtoon.id == webtoon.id && $0.episodeNo == episodeNo
                && ($0.status == .downloading || $0.status == .none)
        }
    }

    func startDownload(webtoon: Webtoon, episodeNos: [Int]) {
        LocalWebtoonManager.shared.saveWebtoon(webtoon)
        for ep in episodeNos {
            if activeTask(webtoon: webtoon, episodeNo: ep) != nil { continue }
            let task = DownloadTask(
                webtoon: webtoon,
                episodeNo: ep,
                progress: 0,
                currentPage: 0,
                totalPages: 0,
                speed: "",
                eta: "",
                status: .none
            )
            tasks.append(task)
            DispatchQueue.main.async {
                self.processQueue()
            }
        }
    }

    private func processQueue() {
        guard activeCount < C.maxConcurrentDownloads else { return }

        for i in tasks.indices where tasks[i].status == .none {
            guard activeCount < C.maxConcurrentDownloads else { break }
            activeCount += 1
            tasks[i].status = .downloading

            let task = tasks[i]
            Task {
                await executeDownload(task, index: i)
            }
        }
    }

    private func executeDownload(_ task: DownloadTask, index: Int) async {
        do {
            _ = try await PythonBridge.shared.call(
                action: "download_episode",
                params: [
                    "platform": task.webtoon.platform.rawValue,
                    "title_id": task.webtoon.platformId,
                    "title_name": task.webtoon.title,
                    "episode_no": task.episodeNo,
                ],
                onProgress: { [weak self] progress in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        self.handleProgress(id: task.id, progress: progress)
                    }
                },
                taskId: task.id.uuidString,
                timeout: 180
            )
        } catch {
            DispatchQueue.main.async {
                guard let idx = self.tasks.firstIndex(where: { $0.id == task.id }) else { return }
                if self.tasks[idx].status != .paused {
                    self.tasks[idx].status = .failed
                    self.tasks[idx].errorMessage = error.localizedDescription
                }
            }
        }

        activeCount -= 1
        processQueue()
    }

    func cancelTask(id: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        let task = tasks[idx]
        tasks.remove(at: idx)
        PythonBridge.shared.cancel(taskId: task.id.uuidString)
        processQueue()
    }

    func pauseTask(id: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }), tasks[idx].status == .downloading else { return }
        tasks[idx].status = .paused
        PythonBridge.shared.cancel(taskId: tasks[idx].id.uuidString)
        DebugLogger.shared.push(.ACTION, category: "Download",
            message: "일시정지 ep=\(tasks[idx].episodeNo)",
            meta: tasks[idx].webtoon.title)
    }

    func resumeTask(id: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }), tasks[idx].status == .paused else { return }
        tasks[idx].status = .none
        processQueue()
        DebugLogger.shared.push(.ACTION, category: "Download",
            message: "재개 ep=\(tasks[idx].episodeNo)",
            meta: tasks[idx].webtoon.title)
    }
}
