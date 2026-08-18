# 모두의 웹툰 (EveryWebtoon) — 설계 노트

**번들 ID**: `com.borasarang.everywebtoon` | **저장 경로**: `~/Documents/EveryWebtoon/`
**기술 스택**: SwiftUI (macOS 14+) + Python 3.11+ (urllib/beautifulsoup4 다운로드 엔진)
**플랫폼**: macOS 전용 (Apple Silicon / Intel)

---

## 1. 아키텍처

```
SwiftUI 앱 ── Process (stdin/stdout JSON-RPC) ──▶ backend/main.py
                  ▲                                    │
                  └──── progress / result / error ────┘
```

- **PythonBridge** (Swift): 호출마다 Python 프로세스 1개 스폰. `taskId` 기반 프로세스 레지스트리로 **취소 지원**.
  - 응답 파싱: Data 바이트 버퍼 → `0x0A` 기준 줄 분리 (UTF-8 청크 경계 안전)
  - continuation resume은 항상 MainActor (레이스 방지)
  - `withTaskCancellationHandler` → Task 취소 시 프로세스 `terminate()`
- **main.py**: readline 루프 + 요청별 `asyncio.Task` 맵 (`active_tasks`). `cancel_download`은 즉시 처리.
- **downloader.py**: `PAGE_CONCURRENCY=6` 병렬, 최대 3회 재시도 (타임아웃/5xx만), `.done` 마커 스킵, 경로 검증.

---

## 2. JSON-RPC 스펙

| action | params | 응답 |
|---|---|---|
| `discover` | platform, category, week/order/... | `[Webtoon...]` 또는 `{top, list}` (kakao ranking/genre) |
| `get_episodes` | platform, title_id | `[Episode...]` |
| `latest_episode` | platform, title_id | `{episode_no}` (경량 — 24h 캐시) |
| `download_episode` | platform, title_id, title_name, episode_no | progress 스트림 + `{path, episode, pages}` |
| `cancel_download` | task_id | `{ok}` |
| `export_episode` | platform, title_id, episode_no, format(cbz/epub) | `{path}` |

---

## 3. 데이터 저장 구조

```
~/Documents/EveryWebtoon/
├── {제목}/                     # sanitize + 경로 검증
│   └── {회차:03d}/{페이지:03d}.{jpg}
│       └── .done               # {"episode_no": N, "pages": M}
├── webtoons.db                 # SQLite (WAL) — 메타데이터, weekday, episode_count, update_date
├── _cache/images/{sha256}.{ext} # 썸네일 디스크 캐시
└── python_call.log             # 브리지 디버그 로그
```

- SQLite 스키마 마이그레이션: `migrateAddUpdateDate()` (컬럼 존재 확인 후 ALTER)
- 레거시 `_metadata/*.json` → DB 1회 마이그레이션 (`migrateFromMetadata`)
- 저장 위치는 Settings에서 커스텀 변경 가능 (`AppSettings.storage_base_path`)

---

## 4. 디스커버리 캐시

- `DiscoveryCache` (UserDefaults): 키 `{item.id}-top-{key}` / `{item.id}-bottom-{order}` / kakao용 `-top-{day}-kakao`
- 전체보기: `오늘의 웹툰` (네이버 별점 TOP10, UP 우선 정렬) + 카카오 요일 TOP10 + 7일 전체 (TaskGroup 병렬 14요청)
- TTL: 설정에서 1/6/12/24시간 또는 사용 안 함 (기본 24h)
- `isUpdated`(UP): 네이버 weekday API `up` 필드 → 세션/캐시 전용, 상세 병합 시 `w.isUpdated || s.isUpdated`

---

## 5. 다운로드 상태 머신

```
.none ──(큐)──▶ .downloading ──▶ .done
                │   ▲
         pause ─┘   └── resume (큐 재투입)
                │
             cancel ──▶ .failed(제거됨)
```

- Swift 큐: `maxConcurrentDownloads = 2`, Python 내부: 페이지 6병렬
- 취소: `cancelTask` → tasks 제거 + PythonBridge `cancel(taskId:)` → 프로세스 terminate
- 일시정지/재개: `pauseTask` = status `.paused` + 프로세스 terminate (부분 파일·`.partial` 보존), `resumeTask` = 큐 재투입. 백엔드는 기존 파일 스킵(`getsize>0`) → 이어받기
- 외부 다운로드 (뷰어에서): `registerExternal` + `waitForTask` 폴링 (300ms)

---

## 6. 뷰어

- 창: `ReaderWindowManager` 싱글톤, `isReleasedWhenClosed=false` 재사용 (600×1200, 360×640 최소)
- 키보드: `NSEvent.addLocalMonitorForEvents(.keyDown)` — 53(ESC)/123(←)/124(→)/126(↑)/125(↓)
- 이미지: `ReaderPageView` `.task` 백그라운드 로딩 + `ReaderImageCache` (NSLock)
- 회차 전환 시 ScrollView `.id()` 재생성 → 맨 위로
- **이어보기**: `boundsDidChange` 관찰로 스크롤 비율(0~1) 저장(`read_history_position`), 회차 로드 후 볌원복 (LazyVStack 레이아웃 보정 재시도), 98% 도달 시 다음 회차 자동 로드
- **확대기**: `onContinuousHover` + 원형 렌즈 2.4x
- **이미지 필터**: 밝기(-0.5~0.5)/대비(0.5~1.8)

---

## 7. 디버그 패널 (AGENTS.md v1.7 표준)

- 메뉴바 `Debug` 메뉴 (Cmd+D 토글, 선택/전체 복사, 클리어, 📌 자동 스크롤)
- `DebugPanelWindowManager`: NSWindow 1회 생성 재사용, `.floating+100`, 600×320, 중앙, `orderOut`/`makeKeyAndOrderFront`
- `DebugLogger`: 7종 로그 레벨 (ACTION, API→, API←, INFO, WARN, ERROR, SYSTEM), 5000줄 FIFO, `print()` 동시 출력, `maskSecrets()` (token/password/keystore/secret/authorization 마스킹)
- NSTextView 금지, 순수 SwiftUI Text + `Set<UUID>` 선택
- `#if DEBUG` 컴파일 타임 제거 (release 미포함), `Package.swift` `.define("DEBUG", .when(configuration: .debug))`

---

## 8. 컬렉션 & 라이브러리 (v1.10)

- `CollectionsManager`: UserDefaults 기반 컬렉션 (create/rename/delete/add/remove/toggle)
- 기존 `followed_webtoon_ids` → "팔로우" 모음 자동 마이그레이션
- `ReadHistoryManager`: `lastRead`, `viewed`, `lastReadAt`, `positions` (fraction) 저장
- 정렬/필터: 최근 추가/제목/회차 수/최근 읽음 + 플랫폼/상태(연재·완결) 필터

---

## 9. 백업/내보내기

- **백업**: `BackupManager` — JSON (version=1, webtoons + history). 메뉴바 (Cmd+S / Cmd+Shift+S). 복원은 병합 (viewed는 합집합)
- **CBZ 내보내기**: 백엔드 `export_episode(format=cbz)` — `_export/{title}/{no}.cbz`, ZIP_STORED 원본 화질
- **EPUB 내보내기**: `export_episode(format=epub)` — EPUB3 (mimetype stored + container.xml + content.opf + nav.xhtml + toc.ncx)

---

## 10. 설정 (v1.11)

| 키 | 기본값 | 옵션 |
|---|---|---|
| `storage_base_path` | nil (=기본 위치) | 커스텀 경로 (NSOpenPanel) |
| `cache_ttl_hours` | 24 | 1 / 6 / 12 / 24 / 0(=없음) |
| `update_check_interval` | 300 | 60 / 300 / 600 / 1800 / 0(=수동) |
| `new_episode_alerts` | true | ON/OFF |

- 저장 위치 변경은 **재시작 후 적용**. 기존 데이터는 복사 방식으로 이동.
- 신규 회차 알림: `UNUserNotificationCenter` (권한 요청 + OFF 시 스킵)

---

## 11. 신규 회차 확인 최적화 (v1.11.1)

- **`latest_episode` 경량 액션**: 네이버 JSON API (약 10KB, HTML 320KB 대비 **32배 절감**), 카카오 `window_size=100` 1회 (기존 최대 10회 대비 1/3)
- `UpdateChecker`: 24h 인메모리 캐시 + 기존 에피소드 캐시 우선
- 검증: 네이버 361 / 카카오 14143759 / 성인 404→AdultVerificationError

---

## 12. 제약 사항

- 카카오 회차 이미지: 로그인/보안 정책 (`.cef` AES, API -500) → 다운로드 불가. 네이버만 지원.
- 네이버 이미지: `Referer: comic.naver.com/webtoon/detail?titleId={id}&no={no}` 필수 (403 방지)
- 카카오 썸네일: `asset_property.card_img` 없으면 `card_set.background_img` → `banner_set` fallback
- 성인 웹툰: `AdultVerificationError`로 구분, UpdateChecker 스킵, 상세 화면 배너

---

## 13. 배포

```bash
./scripts/build_and_run.sh debug macos   # swift build → ~/Applications/EveryWebtoon.app 구성 → pkill → open
./scripts/generate_icon.sh               # images/EveryWebtoon.png → scripts/resources/EveryWebtoon.icns
./scripts/install_python_deps.sh          # venv + beautifulsoup4
```

- 앱 번들: `scripts/resources/Info.plist` + `scripts/resources/EveryWebtoon.icns` + 빌드 바이너리
- Info.plist 주의: `<!ATTLIST>` 금지, `</plist>` 반드시 포함

---

## 14. 현재 버전 및 다음 단계

### v1.11.1 (2026-08-02) — 완료 ✅
- `latest_episode` 경량 액션 (32배/3분의 1 트래픽 감소)
- 24h 인메모리 캐시 + 에피소드 캐시 우선
- 설정 화면 (저장 위치, 캐시 TTL, 신규 회차 알림)

### 다음 단계 (v1.12) — 미정
- 사용자 피드백 반영
- macOS polish (UI 미세조정, 성능 개선)
- 새로운 기능 아이디어 검토 중
