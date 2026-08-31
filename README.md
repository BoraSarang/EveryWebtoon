# 모두의 웹툰 (Every Webtoon)

> 네이버·카카오 웹툰을 **네이티브 macOS 앱**으로. 검색·감상·다운로드를 한 곳에서.

[🌐 방문하기](https://borasarang.github.io/EveryWebtoon/) · macOS 전용 (SwiftUI)

네이버와 카카오 웹툰을 TV처럼 모아서 담고, 오프라인으로 이어서 감상하는 macOS 데스크톱 앱입니다. 브라우저 탭 대신 네이티브 창에서 웹툰을 보고, 회차를 내려받아 언제 어디서든 봅니다.

**번들 ID**: `com.borasarang.everywebtoon`
**저장 경로**: `~/Documents/EveryWebtoon/`
**기술 스택**: SwiftUI (macOS 14+) + Python (urllib / BeautifulSoup)

---

## 기능

| 영역 | 내용 |
|---|---|
| **디스커버리** | 전체보기 · 요일별 · 랭킹 · 장르 · 베스트 도전 · 신작 · 완결 |
| **뷰어** | 세로 스크롤 · 폭 맞춤 토글 · 화살표 회차 이동 · 비동기 이미지 + 메모리 캐시 |
| **다운로드** | 회차별 병렬 다운로드 · 진행률/속도/ETA · 즉시 취소 · 재다운로드 스킵 |
| **보관함** | 다운로드 목록 · 최근 본 · SQLite 메타데이터 캐싱 |
| **컬렉션** | 맞춤 모음 · 다운로드 여부 배지 · 업데이트 감지 |
| **이어보기** | 스크롤 위치 저장/복원 · 98% 자동 다음화 |
| **내보내기** | 회차별 **CBZ / EPUB** 파일로 저장 |
| **백업/복원** | 메뉴바 Cmd+S / Cmd+Shift+S |
| **설정** | 저장 위치 · 캐시 TTL · 신규 회차 알림 |

---

## 빌드 & 실행

```bash
./scripts/install_python_deps.sh          # 최초 1회 — venv + 의존성
./scripts/build_and_run.sh debug macos     # 빌드 → 배포 → 실행
./scripts/build_and_run.sh release macos
```

### 의존성
- macOS 14+ (Sequoia 권장)
- Python 3.11+

---

## 프로젝트 구조

```
EveryWebtoon/
├── Sources/EveryWebtoon/          # Swift 앱 (macOS 전용)
│   ├── App/                       # @main, Debug 메뉴, Settings Scene
│   ├── Models/                    # Webtoon, Episode, DownloadTask, SidebarNode
│   ├── Services/                  # PythonBridge, WebtoonDB, DiscoveryCache, Managers
│   ├── ViewModels/                # Discover, Download, Reader, Detail, Search
│   ├── Views/                     # 전체 UI
│   └── Utils/                     # DebugLogger, DebugPanel, AppPaths, AppSettings
├── backend/                       # Python JSON-RPC 백엔드
│   ├── main.py                    # 요청 루프 · 태스크 관리
│   ├── api.py                     # 액션 디스패처
│   ├── downloader.py              # 병렬 다운로드 · 재시도 · .done 스킵
│   ├── exporter.py                # CBZ/EPUB 내보내기
│   ├── discovery/  fetcher/       # 네이버 · 카카오 어댑터
├── scripts/                       # 빌드 · 아이콘 · 파이썬 의존성
└── Package.swift                  # macOS 타깃
```

---

## 저장 구조

```
~/Documents/EveryWebtoon/
├── {제목}/                        # 웹툰별 폴더
│   └── 001/…002/…                 # 회차 — 001.jpg … + .done 마커
├── webtoons.db                    # 메타데이터 SQLite (WAL)
├── _cache/images/                 # 썸네일 디스크 캐시
└── python_call.log                # 브리지 디버그 로그
```

---

## 참고
- 설계 노트: [`PLAN.md`](PLAN.md) · `docs/plans/`
- 버전 이력: [`CHANGELOG.md`](CHANGELOG.md)
- 디버그 패널: 메뉴바 `Debug` → `⌘⇧D`
- 카카오 회차 이미지 다운로드는 로그인 정책으로 불가 — 네이버만 지원
