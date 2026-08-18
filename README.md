# 모두의 웹툰 (EveryWebtoon)

macOS 전용 웹툰 뷰어 + 오프라인 다운로더. 네이버/카카오 웹툰을 검색·감상·다운로드할 수 있습니다.

**번들 ID**: `com.borasarang.everywebtoon`
**저장 경로**: `~/Documents/EveryWebtoon/`
**기술 스택**: SwiftUI (macOS 14+) + Python 3.11+ (urllib/beautifulsoup4)

---

## 주요 기능

- **디스커버리**: 전체보기, 요일별, 랭킹, 장르, 베스트 도전, 신작, 완결
- **뷰어**: 세로 스크롤, 폭 맞춤 토글, `←`/`→` 회차 이동, `↑`/`↓` 한 화면 스크롤, `ESC` 닫기, 비동기 이미지 로딩 + 메모리 캐시
- **다운로드**: 회차별 다운로드 (백엔드 병렬 6페이지), 진행률·속도·ETA·바이트, **즉시 취소**, `.done` 재다운로드 스킵
- **보관함**: 다운로드 목록, 최근 본, SQLite 메타데이터 캐싱
- **컬렉션**: 맞춤 모음 (팔로우 → 자동 마이그레이션)
- **이어보기**: 스크롤 비율 저장/복원, 98% 자동 다음화
- **백업/복원**: CMD+S / CMD+Shift+S
- **CBZ/EPUB 내보내기**: 회차별 파일 내보내기
- **설정**: 저장 위치, 캐시 TTL, 신규 회차 알림
- **디버그 패널**: 메뉴바 `Debug` → `Cmd+D`

---

## 빌드 및 실행

```bash
./scripts/build_and_run.sh debug macos   # swift build → 번들 구성 → ~/Applications 배포 → 자동 실행
./scripts/build_and_run.sh release macos
```

**의존성 (최초 1회)**:
```bash
./scripts/install_python_deps.sh        # venv + beautifulsoup4
```

**앱 아이콘 재생성**:
```bash
./scripts/generate_icon.sh              # images/EveryWebtoon.png → scripts/resources/EveryWebtoon.icns
```

---

## 프로젝트 구조

```
EveryWebtoon/
├── Sources/EveryWebtoon/               # Swift 앱 (macOS 전용)
│   ├── App/                            # EveryWebtoonApp.swift (@main, Debug 메뉴, Settings Scene)
│   ├── Models/                         # Webtoon, Episode, DownloadTask, SidebarNode
│   ├── Services/                       # PythonBridge, WebtoonDB, DiscoveryCache, Managers
│   ├── ViewModels/                     # Discover, Download, Reader, Detail, Search
│   ├── Views/                          # UI (App, Common, Content, Sidebar, Discover,
│   │                                   #      Library, Reader, WebtoonDetail, Search, Settings)
│   └── Utils/                          # DebugLogger, DebugPanel, AppPaths, AppSettings
├── backend/                            # Python JSON-RPC 백엔드
│   ├── main.py                         # 루프, active_tasks, cancel_download
│   ├── api.py                          # 액션 디스패처
│   ├── downloader.py                   # 병렬 다운로드, 재시도, .done 스킵
│   ├── exporter.py                     # CBZ/EPUB 내보내기
│   ├── httputil.py                     # urllib HTTP
│   ├── models.py                       # 데이터 클래스
│   ├── discovery/                      # naver_discovery, kakao_discovery
│   └── fetcher/                        # naver_fetcher, kakao_fetcher
├── scripts/                            # 빌드/아이콘/파이썬 의존성
│   ├── build_and_run.sh                # 빌드 → ~/Applications 배포 → 실행
│   ├── generate_icon.sh                # 아이콘 PNG → icns
│   ├── generate_icon.swift             # 아이콘 PNG 생성 (Swift/CGContext)
│   ├── make_icns.py                    # icns 직접 조립
│   ├── install_python_deps.sh          # venv + 의존성 설치
│   └── resources/                      # Info.plist, EveryWebtoon.icns
├── Package.swift                       # Swift Package (macOS 14+, .define("DEBUG"))
├── PLAN.md                             # 설계 노트
├── CHANGELOG.md                        # 버전 이력
└── images/                             # 아이콘 원본
```

---

## JSON-RPC 프로토콜 (stdin/stdout)

```
요청:  {"id": "...", "action": "discover", "params": {...}}
응답:  {"id": "...", "type": "result", "data": ...}
진행:  {"id": "...", "type": "progress", "data": {...}}   # 다운로드 진행률
에러:  {"id": "...", "type": "error", "data": {...}}
```

- action: `discover`, `get_episodes`, `latest_episode`, `download_episode`, `cancel_download`, `export_episode`
- 다운로드 요청은 백그라운드 태스크로 실행 → 진행 중에도 다른 요청(취소) 처리 가능

---

## 저장 구조

```
~/Documents/EveryWebtoon/
├── {제목}/                       # sanitize된 웹툰 제목
│   ├── 001/                      # 1화
│   │   ├── 001.jpg ...
│   │   └── .done                 # 완료 마커 (재다운로드 스킵)
│   └── 002/
├── webtoons.db                   # 메타데이터 SQLite (WAL)
├── _cache/images/                # 썸네일 디스크 캐시 (SHA256)
└── python_call.log               # 브리지 디버그 로그
```

---

## 참고

- 상세 규칙: `AGENTS.md` (공통 가이드) / `PLAN.md` (설계 노트)
- 카카오 회차 이미지 다운로드는 로그인 정책으로 불가. 네이버만 지원.
- 디버그 패널: `Debug` 메뉴 → `Cmd+D` (AGENTS.md v1.7 표준)
