# PLAN v0.2 — macOS 앱 전체 리디자인

**플랫폼**: macOS (SwiftUI, macOS 15+ 타깃)
**날짜**: 2026-08-18
**목표**: 모든 창(메인 윈도우, 리더, 디버그 패널)과 모든 UI/UX를 "아, 맥 앱이구나" 느낄 수준으로 재설계
**참고 스킬**: `macos-app-design`, `apple-design`(emil-design-eng), `ios-the-final-5-percent`
**검증**: `scripts/build_and_run.sh debug macos` → DebugPanel 전체 복사 → `scripts/a11y-dump.sh macos`

---

## 1. 개요

기존 앱은 커스텀 사이드바(비표준 행 스타일), 수동 상태 기반 내비게이션(`DetailTopBar`), 검정 배경의 디버그 패널 등 비표준 UI가 남아 있어 Mac 네이티브로 보이지 않는다. 이를 macOS 표준 관례(Sidebar `List(.sidebar)`, unified 툴바, `Settings` Scene, 메뉴 바, 툴바 검색, 재질/세만틱 색)로 전환한다.

## 2. 결정 사항 (사용자 확정)

| 항목 | 결정 |
|---|---|
| 최소 macOS | **15+ (Sequoia)** → `Package.swift` `.macOS(.v15)` |
| 사이드바 | **`List(selection:)` + `.listStyle(.sidebar)` 전환** (시스템 선택/타이핑 이동) |
| 검색 | **툴바(`.principal`) 이동 + `⌘F` 포커스** |
| 진행 순서 | **전체 순차 진행** (Phase 1 구조 → 2 화면 폴리시 → 3 디버그 패널) |
| 커맨드 팔레트 ⌘K | Phase 3 선택 항목 (필요 시 별도 승인) |

## 3. 아키텍처 (플랫폼별 변경)

### Phase 1 — 구조

**`App/EveryWebtoonApp.swift`**
- `.windowStyle(.titleBar)` → `.windowToolbarStyle(.unified)` (마이너스 `.windowStyle`)
- `.defaultSize(width: 1100, height: 720)` + min 1000×640
- `@State selectedItem` → `@SceneStorage`(선택 섹션) / `@SceneStorage`(사이드바 가시성) — 창 복원
- View 메뉴: 사이드바 토글 `⌘⌥S`, 테마 서브메뉴(기존 피커 유지), 검색 `⌘F`
- `Settings { SettingsView() }` Scene (⌘, 연결)

**`Views/Sidebar/SidebarView.swift`**
- 커스텀 Button 행 → `List(selection:)` + `.listStyle(.sidebar)` + `Section`
- naver/kakao `expandedIDs` → `DisclosureGroup`
- 컬렉션 행/컨텍스트 메뉴/디스크 푸터 유지, 선택 스타일은 시스템 위임
- 검색창 제거 → 툴바로 이동
- 열 폭 `min 200 / ideal 220 / max 280`

**`Views/ContentView.swift`**
- detail 열에 `NavigationStack` — push 내비게이션 통일
- `DetailTopBar` → `.toolbar` back (`.navigation` placement)
- 검색 활성 상태(`SearchResultsView`/`SearchRecentsView`)는 툴바 검색 연동 유지

**`Views/Common/DetailTopBar.swift`** — Phase 1에서 제거 대상 (NavigationStack의 표준 back 사용)

### Phase 2 — 화면 폴리시

- **`WebtoonGrid`**: adaptive `min 170 / max 200`
- **`WebtoonGridCell`**: `cornerRadius(8)`, hover `scaleEffect(1.02)` + `.easeOut(duration: 0.12)`, 그림자 `black 0.08/0.04`, 별 9pt + `.monospacedDigit()`, 숫자 `numericText`
- **`PlatformBadge`**: `Color(.displayP3, ...)` — 네이버 초록/카카오 노랑 P3
- **`LibraryCell`**: `cornerRadius(8)`, 그림자 완화
- **`WebtoonDetailView`**: 히어로 썸네일 160×210 `cornerRadius(10)`, 회차 정렬 `.menu` 통일, 여백 24pt
- **`EpisodeRow`**: 세만틱 색(`.controlBackgroundColor` 유지 + 선택 상태), 캡션 정리
- **`ReaderView`**: 상/하단 바 hover 시에만 표시(기본 숨김 → 몰입), 화수 `.monospacedDigit()`, Space = 다음 페이지, `⌘0` = 폭맞춤
- **`SettingsView`**: `Settings` Scene 연결, minWidth 560 / idealWidth 600

### Phase 3 — 디버그 패널 & 고급

- **`DebugPanelWindowManager`**: `NSVisualEffectView`(material) 배경, 제목 `Debug Logs`(SF Symbol `ant`), 이모지 버튼 → SF Symbol, 로그 색 세만틱 + light/dark, 12pt + `.textSelection(.enabled)`, 로그 필터 `TextField`, 기본 640×360 / min 420×240
- ⌘K 커맨드 팔레트 (선택 — 사용자 승인 대기)

## 4. 구현 단계 (T-번호)

| T | 작업 | 파일 | 상태 |
|---|---|---|---|
| T-201 | PLAN/TODO/DESIGN 문서화 | docs/* | 완료 |
| T-202 | Package.swift macOS 15 타깃 + AppScene (unified/SceneStorage/메뉴/Settings) | Package.swift, EveryWebtoonApp.swift | 완료 |
| T-203 | SidebarView List(.sidebar) 전환 + 검색 제거 | SidebarView.swift | 완료 |
| T-204 | ContentView NavigationStack + 툴바 back + 검색 연동 | ContentView.swift | 완료 |
| T-205 | DetailTopBar 제거 및 Discover/Library/Search back 대체 | Discover/Library/Search/WebtoonDetail | 완료 |
| T-206 | 그리드/셀/배지 폴리시 | WebtoonGrid/Cell/PlatformBadge/LibraryCell | 완료 |
| T-207 | 디테일/에피소드 행 폴리시 | WebtoonDetailView/EpisodeRow | 완료 |
| T-208 | 리더 몰입 바 + 단축키 | ReaderView | 완료 |
| T-209 | 설정 Scene + 폭 | EveryWebtoonApp/SettingsView | 완료 |
| T-210 | 디버그 패널 리디자인 | DebugPanelWindowManager | 완료 |
| T-211 | 빌드/검증/CHANGELOG | — | 완료 |
| T-212 | 단축키 충돌 수정 (⌘D→⌘⇧D, ⌘⇧S→⌘⇧L, Debug 메뉴 이동) | EveryWebtoonApp.swift | 완료 |

## 5. 테스트 계획 (TC)

- **TC-01**: `swift build` 컴파일 0 에러
- **TC-02**: `scripts/build_and_run.sh debug macos` 앱 기동 — 메인 윈도우 unified 툴바, 사이드바 시스템 선택 확인
- **TC-03**: `⌘F` 검색 포커스, `⌘⌥S` 사이드바 토글, `⌘,` 설정 열림
- **TC-04**: 사이드바 타입-투-셀렉트 (시스템 List 동작)
- **TC-05**: Detail push/back 애니메이션 + 툴바 back 위치
- **TC-06**: 리더 Space/`⌘0`/바 자동 표시
- **TC-07**: 디버그 패널 light/dark + 필터 + 복사
- **TC-08**: 창 복원 — 재실행 시 선택 섹션 유지

## 6. 롤백 계획

- 각 Phase 커밋 단위로 진행 → 문제 시 `git revert` (현재 git repo 아님 → 파일 백업 유의)
- 구조 변경(Phase 1) 롤백: `SidebarView`/`ContentView`/`EveryWebtoonApp` 원본 복원
- 문서도 함께 되돌리기 (`docs/plans` 등)

## 7. 성능 예산

| 지표 | 예산 |
|---|---|
| 콜드 스타트 | ≤1.5s |
| 메모리 | ≤300MB |
| 그리드 스크롤 | 60fps |
| 리더 페이지 | 스크롤 60fps (기존 유지) |
| 디버그 패널 | 5000줄 로그 렌더 유지 (LazyVStack) |

## 8. 에러코드

신규 에러코드 없음 (UI 리디자인 — 로직 변경 최소화).

## 9. 세션 로그

- 2026-08-18: 문서 작성, Phase 1 시작
- 2026-08-18: Phase 1 완료 — 빌드 성공, TC-01~05 검증 (⌘F 검색 포커스, ⌘⌥S 토글, 그리드→상세 push, Back pop). Package.swift는 tools 6.0 + `.swiftLanguageMode(.v5)`로 전환 (Swift 6 동시성 에러 회피). DebugPanelWindowManager 타입체크 타임아웃 → `logRow(for:)` 분리로 해결. a11y-dump.sh + axdump/axfocus/axclick/axclickvalue/axclickbutton 스크립트 신규 추가.
- 2026-08-18: Phase 2~3 + T-211 완료 — 그리드/셀/배지/디테일/리더/설정 폴리시 적용, 디버그 패널 재작성. TC-06 리더 검증 (Space 다음화, ⌘0 fitWidth 무크래시, 호버 바 show/hide — 로그 + 스크린샷 diff로 확인). TC-07 디버그 패널 (필터 필드, 휴지통 클리어 [0/0], 새 UI 항목 확인). 설정 창 600×480 (`Settings` scene에 `.defaultSize` 추가). 산출물: v0.2_main.png / v0.2_reader.png / v0.2_debugpanel.png / v0.2_EveryWebtoon.a11y.txt / v0.2_perf.json. CHANGELOG.md 갱신.
- 2026-08-18: T-212 단축키 충돌 수정 — macOS 26 시스템 "자동으로 Dock 가리기"(⌘D)가 디버그 패널 ⌘D를 가로챔 (테스트 중 Dock autohide 1→0으로 실측 확인, 원복). 디버그 패널 ⌘D→**⌘⇧D**, Auto Scroll ⌘⇧S→**⌘⇧L** (백업 복원 ⌘⇧S와 충돌). `CommandMenu`/서브메뉴 키 동등이 발동 안 함 → View `CommandGroup(after: .sidebar)` 직접 버튼으로 이동 (⌘⇧D CGEvent 검증 통과). "자동으로 Dock 가리기"는 macOS 26 시스템 항목이라 `.toolbar` 교체로도 제거 불가 확인 → 단축키 회피가 정답.