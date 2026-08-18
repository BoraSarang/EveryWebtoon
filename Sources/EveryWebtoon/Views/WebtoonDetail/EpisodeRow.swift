import SwiftUI

struct EpisodeRow: View {
    let webtoon: Webtoon
    let episode: Episode
    var onRead: ((Int) -> Void)? = nil

    @EnvironmentObject private var downloadVM: DownloadViewModel
    @ObservedObject private var history = ReadHistoryManager.shared

    private var isDownloaded: Bool {
        LocalWebtoonManager.shared.isEpisodeDownloaded(webtoonTitle: webtoon.title, episodeNo: episode.episodeNo)
    }

    private var isDownloading: Bool {
        currentTask != nil
    }

    private var currentTask: DownloadTask? {
        downloadVM.tasks.first {
            $0.webtoon.id == webtoon.id && $0.episodeNo == episode.episodeNo && $0.status == .downloading
        }
    }

    private var pausedTask: DownloadTask? {
        downloadVM.tasks.first {
            $0.webtoon.id == webtoon.id && $0.episodeNo == episode.episodeNo && $0.status == .paused
        }
    }

    private var isFailed: Bool {
        downloadVM.tasks.contains { $0.webtoon.id == webtoon.id && $0.episodeNo == episode.episodeNo && $0.status == .failed }
    }

    private var isViewed: Bool {
        history.isViewed(webtoonId: webtoon.id, episodeNo: episode.episodeNo)
    }

    var body: some View {
        HStack(spacing: 12) {
            if !episode.thumbnailUrl.isEmpty {
                CachedAsyncImage(url: episode.thumbnailUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                }
                .frame(width: 72, height: 46)
                .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(episode.displayTitle)
                        .font(.subheadline)
                        .lineLimit(1)
                        .foregroundColor(isViewed ? .secondary : .primary)
                        .strikethrough(false)

                    if isViewed {
                        Text("본")
                            .font(.caption2.bold())
                            .foregroundColor(.green)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.12))
                            .cornerRadius(3)
                    }
                }
                if !episode.date.isEmpty {
                    Text(episode.date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Button {
                    onRead?(episode.episodeNo)
                } label: {
                    Label("보기", systemImage: "book")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if isDownloaded {
                    Menu {
                        Button("CBZ (이미지 묶음)") { export(format: "cbz") }
                        Button("EPUB (전자책)") { export(format: "epub") }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .foregroundColor(.secondary)
                    .help("내보내기 (CBZ/EPUB)")
                }

                downloadButton
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }

    @ViewBuilder
    private var downloadButton: some View {
        if isDownloaded {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .help("다운로드됨")
        } else if let task = currentTask {
            HStack(spacing: 6) {
                ProgressView(value: task.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 48)
                    .scaleEffect(x: 1, y: 0.5)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(Int(task.progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                    Text(task.pagesText)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.7))
                        .monospacedDigit()
                }
                .frame(width: 34, alignment: .trailing)

                Button {
                    downloadVM.pauseTask(id: task.id)
                } label: {
                    Image(systemName: "pause.circle")
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                .help("다운로드 일시정지")
            }
            .help("다운로드 중 \(task.sizeText) · \(task.speed)")
        } else if let task = pausedTask {
            HStack(spacing: 4) {
                Text("일시정지됨")
                    .font(.caption2)
                    .foregroundColor(.orange)
                Button {
                    downloadVM.resumeTask(id: task.id)
                } label: {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                .help("다운로드 재개")
            }
        } else {
            Button {
                downloadVM.startDownload(webtoon: webtoon, episodeNos: [episode.episodeNo])
            } label: {
                Image(systemName: isFailed ? "arrow.clockwise.circle" : "arrow.down.circle")
                    .foregroundColor(isFailed ? .red : .secondary)
            }
            .buttonStyle(.plain)
            .help(isFailed ? "다운로드 재시도" : "다운로드")
        }
    }

    private func export(format: String) {
        Task {
            do {
                let result = try await PythonBridge.shared.call(
                    action: "export_episode",
                    params: [
                        "title_name": webtoon.title,
                        "episode_no": episode.episodeNo,
                        "format": format,
                    ],
                    timeout: 120
                )
                guard let dict = result as? [String: Any],
                      let path = dict["path"] as? String else {
                    throw PythonBridge.PythonBridgeError.invalidOutput
                }
                let fmt = format.uppercased()
                DebugLogger.shared.push(.ACTION, category: "Export",
                    message: "\(fmt) 내보내기 완료",
                    meta: path)
                presentExportResult(fmt: fmt, path: path)
            } catch {
                DebugLogger.shared.push(.ERROR, category: "Export",
                    message: "내보내기 실패",
                    meta: error.localizedDescription)
                presentExportFailure(error)
            }
        }
    }
}
