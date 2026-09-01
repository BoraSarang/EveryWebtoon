# DESIGN — 기술 설계

## macOS 섹션

### v0.2 — 앱 전체 리디자인 (2026-08-18)

#### 창 구조
- 메인: `WindowGroup` + `.windowToolbarStyle(.unified)` + `.defaultSize(1100, 720)` / min 1000×640
- 설정: `Settings { SettingsView() }` (⌘,), minWidth 560 / idealWidth 600
- 리더: `ReaderWindowManager` — 420×910 유지 (이미 최적), 별도 NSWindow
- 디버그: `DebugPanelWindowManager` — `NSVisualEffectView` 재질, 640×360, `.floating + 100`

#### 상태 복원
- `@SceneStorage("selectedItemID")` — 선택 섹션
- `@SceneStorage("sidebarVisible")` — 사이드바 가시성
- AppKit 창 복원은 WindowGroup 기본 제공 + 위 SceneStorage 조합

#### 내비게이션
- 사이드바: `List(selection:)` + `.listStyle(.sidebar)` — 시스템 선택/타이핑 이동/재질
- 디테일: `NavigationStack` + `.toolbar` back (`.navigation`) — `DetailTopBar` 제거
- 검색: 툴바 `.principal` 배치 + `⌘F` 포커스 (`@FocusState`)

#### 색/재질
- 사이드바·툴바: 시스템 재질 (`.sidebar`/`.bar` 자동)
- 배지: `Color(.displayP3, ...)` — 네이버 초록 `0.09/0.78/0.02`, 카카오 노랑 `0.97/0.86/0.04`
- 셀 그림자: `black.opacity(0.08/0.04)`
- 디버그 패널: 세만틱 로그 색 (red/yellow/blue/green), light/dark 대응

#### 동작/애니메이션
- hover: `scaleEffect(1.02)` + `.easeOut(duration: 0.12)` — 0.15 easeInOut 대체
- 숫자: `.monospacedDigit()` + `contentTransition(.numericText())`
- 리더 바: hover 시에만 표시 (기본 숨김) — `.onHover`로 크롬 노출
- 리더 단축키 추가: Space=다음, `⌘0`=폭맞춤 (기존 ESC/←/→/↑/↓ 유지)

### v0.4 — 리더 차별화 (2026-09-01)
- **자동 스크롤**: 상단 바 ▶ 토글. 0.05s 타이머로 clip bounds 이동(보폭 = docHeight×0.0004×속도×20). 끝 0.98 도달 시 기존 `handleFractionChange` 경유 → 자동 다음화. 수동 키 입력 → `stopAutoScroll()`
- **정주행**: `onChange(currentEpisodeNo)`에서 `autoScroll == true`면 `startAutoScroll()` 재개 — 연속 재생. 마지막화에서 `stopAutoScroll()`
- **설정 팝오버**(⚙️, `readerSettingsPopover`): 자동 스크롤 속도(0.1~2.0) / 스크롤 보폭(세밀·기본·크게 = 0.5/1.0/2.0, ↑↓ 페이지 이동에 적용) / 좌우 여백(0~20pt)
- **ReaderViewModel 상태**: `autoScroll`, `autoScrollSpeed`, `scrollStep`, `horizontalPadding`

#### 폰트/타이포
- 사이드바 헤더: 11pt semibold + tracking (List Section 자동)
- 화수/카운트: SF Pro + `.monospacedDigit()`