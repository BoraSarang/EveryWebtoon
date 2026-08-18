# TODO — 작업 추적

> 플랫폼 라벨: macos

## 진행중

### [macos] v0.3.3 — macOS 전용 정리 + 번들 ID 변경 (PLAN_v0.3.3_macos.md)

| T | 작업 | 파일 | 상태 |
|---|---|---|---|
| T-417 | CHANGELOG에 정리 이력 추가 (macOS 전용화 + 번들 ID 변경) | CHANGELOG.md | 완료 |
| T-418 | 구 번들 ID 흔적 제거 — CHANGELOG/세션 로그 문자열 + 옛 캐시(Caches/EveryWebtoon)·데이터(EveryWebtoonData) 삭제 | CHANGELOG.md, 세션 로그, ~/Library/Caches, ~/Documents | 완료 |
| T-419 | 구 번들 ID 잔재 최종 정리 — 세션 로그/PLAN 문구 치환 + 옛 HTTPStorages·CrashReporter·Preferences 삭제 + 옛 프로세스 종료 | 세션 로그, PLAN_v0.3.3, ~/Library | 완료 |

### [macos] v0.3.2 — 사이드바 트리 수정 (PLAN_v0.3.2_macos.md)

| T | 작업 | 파일 | 상태 |
|---|---|---|---|
| T-411 | 스크린샷으로 글자 크기 확정 | - | 완료 |
| T-412 | 사이드바 OutlineGroup 교체 | SidebarView | 완료 |
| T-413 | row 폰트 통일 (HStack .body) | SidebarView | 완료 |
| T-414 | 그룹 클릭 → 플랫폼 목록 로드 | SidebarNode, DiscoverViewModel | 완료 |
| T-415 | 빌드 + AX 클릭 검증 | - | 완료 |
| T-416 | 자식 노드 인덴트 추가 + 나의 모음 섹션 분리 | SidebarView | 완료 |

### [macos] v0.3.1 — 앱 이름 로케일 지역화 (PLAN_v0.3.1_macos.md)

| T | 작업 | 파일 | 상태 |
|---|---|---|---|
| T-401 | Info.plist: CFBundleDisplayName/Name/DevelopmentRegion 설정 | scripts/resources/Info.plist | 완료 |
| T-402 | ko/en InfoPlist.strings 생성 (모두의 웹툰 / Every Webtoon) | scripts/resources/*.lproj | 완료 |
| T-403 | build_and_run.sh lproj 복사 추가 | scripts/build_and_run.sh | 완료 |

### [macos] v0.3 — 코드 리팩토링 (PLAN_v0.3_refactor_macos.md)

| T | 작업 | 파일 | 상태 |
|---|---|---|---|
| T-301 | isDownloaded(id:) + Webtoon.isDownloaded 제거 | LocalWebtoonManager, Webtoon | 완료 |
| T-302 | PythonBridge 동일 분기/fputs/log 정리 | PythonBridge | 완료 |
| T-303 | 미사용 C.appName/bundleId 제거 | Constants | 완료 |
| T-304 | VisualEffectView 공용화 | Common 신설 + 2곳 | 완료 |
| T-305 | ReaderView 파일 분리 | Views/Reader | 완료 |
| T-306 | LibraryCell 분리 | Views/Library | 완료 |
| T-307 | BackupAction 분리 | BackupManager + Settings | 완료 |
| T-308 | ByteFormat 공용화 | Utils 신설 + 3곳 | 완료 |
| T-309 | Webtoon.merged(with:) 통합 | Webtoon + 2 VM | 완료 |
| T-310 | 캐시 키 생성 헬퍼 | DiscoverViewModel | 완료 |
| T-311 | onProgress 공용화 | DownloadViewModel + ReaderViewModel | 완료 |
| T-312 | LibraryView episodeCount 배치 캐시 | LibraryView | 완료 |
| T-313 | LibraryView reload 딕셔너리 조회 | LibraryView | 완료 |
| T-314 | UpdateChecker 스캔 병렬화 | UpdateChecker | 완료 |

### [macos] v0.2 — 앱 전체 리디자인 (PLAN_v0.2_macos.md)

| T | 작업 | 파일 | 상태 |
|---|---|---|---|
| T-201 | 문서화 (PLAN/TODO/DESIGN) | docs/* | 완료 |
| T-202 | Package.swift macOS 15 + AppScene (unified/SceneStorage/메뉴/Settings) | Package.swift, EveryWebtoonApp.swift | 완료 |
| T-203 | SidebarView List(.sidebar) 전환 + 검색 제거 | SidebarView.swift | 완료 |
| T-204 | ContentView NavigationStack + 툴바 back + 검색 연동 | ContentView.swift | 완료 |
| T-205 | DetailTopBar 제거 및 back 대체 | Discover/Library/Search | 완료 |
| T-206 | 그리드/셀/배지 폴리시 | WebtoonGrid/Cell/PlatformBadge/LibraryCell | 완료 |
| T-207 | 디테일/에피소드 폴리시 | WebtoonDetailView/EpisodeRow | 완료 |
| T-208 | 리더 몰입 바 + 단축키 | ReaderView | 완료 |
| T-209 | 설정 Scene + 폭 | EveryWebtoonApp/SettingsView | 완료 |
| T-210 | 디버그 패널 리디자인 | DebugPanelWindowManager | 완료 |
| T-211 | 빌드/검증/CHANGELOG | — | 완료 |
| T-212 | 단축키 충돌 해결 (⌘D 시스템 Dock 가로챔 → ⌘⇧D, Auto Scroll ⌘⇧S→⌘⇧L, Debug 메뉴→View 직접 버튼) | EveryWebtoonApp.swift | 완료 |
| T-213 | ⌘K 커맨드 팔레트 (PLAN_v0.2.1_macos.md) + DiscoveryCache 비동기화 | CommandPaletteManager/View + EveryWebtoonApp + DiscoveryCache | 완료 |

## 완료

- [macos] v0.2 Phase 2~3 + T-211 — 화면 폴리시(그리드/셀/배지/디테일/리더/설정), 디버그 패널 재작성, 리더(SPACE/⌘0/호버 바) 검증, 설정 600×480(defaultSize), 산출물 저장, CHANGELOG 갱신 — 2026-08-18
- [macos] v0.2 단축키 충돌 수정 — 시스템 "자동으로 Dock 가리기"(⌘D)가 디버그 패널 ⌘D를 가로챔 → ⌘⇧D로 변경(동작 검증), Auto Scroll ⌘⇧S→⌘⇧L(백업 복원과 충돌), Debug 항목은 View 메뉴 직접 버튼으로 이동(서브메뉴 키 등록 불가 확인), Dock autohide 원복 — 2026-08-18
- [macos] v0.2 Phase 1 — 구조 전환 (unified 툴바/List sidebar/NavigationStack/툴바 검색/DetailTopBar 제거), 빌드 성공 + TC-01~05 검증 — 2026-08-18
- [macos] 기존 UI 전수 조사 (메인/사이드바/디스커버/라이브러리/상세/리더/설정/검색/디버그 패널) — 2026-08-18