# PLAN v0.2.1 macos — ⌘K 커맨드 팔레트 (T-213)

> 문서 우선 원칙 (AGENTS 1.7) — 대형 기능은 아니나 1개 모듈+단축키 충돌 해소가 있어 PLAN/TODO 등록.
> 상위: docs/plans/PLAN_v0.2_macos.md (v0.2 Phase 3 선택 항목 ⌘K 팔레트)

## 1. 개요

- macOS 26 시대의 Raycast/Linear 스타일 **⌘K 커맨드 팔레트** 추가
- 전체 화면을 덮지 않는 중앙 상단 오버레이, 검색 필터 + ↑↓ 이동 + Enter 실행 + Esc 닫기
- 기존 단축키 충돌: Debug "Clear Logs"가 ⌘K 사용 중 → **⌘⇧K로 이전**

## 2. 결정 사항

1. 트리거: **⌘K** (View 메뉴 CommandGroup 직접 버튼 — 서브메뉴 키 등록 불가 확인됨, 직접 버튼만 동작)
2. Clear Logs: ⌘K → **⌘⇧K** (충돌 해소)
3. 구현: `CommandPaletteManager`(NSPanel, DebugPanelWindowManager 패턴) + `CommandPaletteView`(SwiftUI)
   - 창: `.borderless` NSPanel + `PalettePanel(canBecomeKey=true)` + `NSApp.activate(ignoringOtherApps:)` + `makeKeyAndOrderFront`
   - **키보드 핵심**: 최초 `.nonactivatingPanel`로 만들었다가 **키 이벤트가 도달하지 않아 제거** (AX상 필드는 focused로 보이나 실키 미전달 확인) → styleMask `[.borderless]`만 사용, `show()`에서 activate + makeKey. 키 핸들링은 `NSEvent.addLocalMonitorForEvents(.keyDown)` (125/126/36/53 소비)
   - 필터 TextField + `ScrollView` + ForEach 명령 행 (SF Symbol + 타이틀 + 단축키 힌트)
   - 상태: `@Published query`, `selectedIndex`, `isVisible` — `CommandPaletteStore`를 Manager가 소유해 `show()` 시 `reset()` (재오픈 시 쿼리/선택 리셋)
4. 명령 목록 (13개, 정적 정의 — `isGroup == false` 필터 제거해 사이드바 그룹 포함):
   - 검색 (⌘F) / 사이드바 토글 (⌥⌘S) / 테마: 시스템·라이트·다크 / 설정 열기 (⌘,) / 전체보기 / **네이버 / 카카오** / 내 보관함 / 최근 본 / 디버그 패널 (⌘⇧D) / 로그 지우기 (⌘⇧K)
5. 동작: 팔레트 표시 중 텍스트 필드 자동 포커스, ↑↓ 이동, Enter 실행+닫기, Esc 닫기
6. 테마/외관: `.hudWindow` 비주얼 + primary/전경 텍스트, 선택 행 `.selection` 하이라이트
7. **발견된 기동 정지 버그 수정**: `DiscoveryCache` 메인 스레드 동기 파일 I/O가 `open`에서 무한 블로킹 → `DiscoveryCache` 전체 비동기화(`ioQueue .concurrent` + `readData` 3초 타임아웃)로 메인 스레드 보호. 루트 원인은 환경적(macOS)로 미규명이나, 앱 프리즈는 해소됨

## 3. 구현 단계

- T-213a: `CommandPaletteManager.swift` 신규 (CommandPaletteStore/Manager/View/PalettePanel/VisualEffectView)
- T-213b: EveryWebtoonApp.swift — ⌘K 메뉴 버튼 추가 + Clear Logs ⌘⇧K로 이전 + toggleSidebar/navigateSidebar Notification 추가
- T-213c: ContentView.swift — toggleSidebar/navigateSidebar onReceive 추가 (detailPath 초기화 후 selectedItem 변경)
- T-213d: DiscoveryCache 비동기화 (기동 정지 방지)
- T-213e: 빌드 + AX/스크린샷 검증 ✅

## 4. 테스트 계획 (TC) — 검증 결과

- TC-CMD-01: ⌘K로 팔레트 표시 + 검색필드 자동 포커스 — **✅** (AX windows 1→2, 키보드 실입력 도달)
- TC-CMD-02: "dark"/"네이버" 입력 → 필터 1개 행 → Enter 실행 → 창 제목 "네이버" 전환 + 닫힘 — **✅**
- TC-CMD-03: ↑↓ 이동(125) + Enter(36) 실행+닫기, Esc(53) 닫기 — **✅** (사이드바 토글 실행으로 동작 확인, AX windows 2→1)
- TC-CMD-04: Clear Logs ⌘⇧K 동작 — **✅** (Debug Logs [1/1] → [0/0])
- TC-CMD-05: 재오픈 시 쿼리 리셋(13개 명령 복귀) — **✅**
- 추가 검증: ⌘⇧D 디버그 패널, 사이드바 명령 포함(13개), 호버 등 기존 기능 회귀 없음
- 산출물: `docs/screenshots/macos/v0.2.1_palette.png`

## 5. 롤백 계획

- 신규 파일 삭제 + EveryWebtoonApp.swift 단축키 복구 (⌘K → Clear Logs 유지)
- DiscoveryCache는 비동기화가 기존보다 안전(메인 스레드 무블로킹) — 롤백 시 `open` 정지 재발 위험
- git repo 아님 — 파일 백업 유의

## 6. 성능 예산

- 팔레트 오픈 ≤150ms, 명령 목록 ≤50개 (LazyVStack), 스크롤 60fps
- DiscoveryCache 읽기 타임아웃 3s, 메인 스레드 블로킹 0

## 7. 에러코드

- 신규 에러코드 없음 (UI 기능)

## 세션 로그 (v0.2.1)

- T-213a/b/c/d/e 완료. ⌘K 팔레트 구현 + 비동기 캐시 수정 + 검증 완료.
- 검증 상세: ⌘K(AX windows 2) / 필터(dark→1개, 네이버→1개) / ↑↓+Enter(사이드바 토글 실행+닫힘) / Esc 닫힘 / ⌘⇧K 로그 클리어[0/0] / 쿼리 리셋(13개) / 네이버 명령 실행(창 제목 "네이버") — 모두 통과.
- 키보드 수신 수정: `.nonactivatingPanel` 제거 + `NSApp.activate` → 실키 도달 확인 (이전 "ㅗ마;" 실입력 검증).
- 기동 정지: `DiscoveryCache.get` 동기 I/O open 블로킹(환경적) → 비동기화+타임아웃으로 해소. CGWindowList layer=3 잔존은 stale 아티팩트(AX windows로 판정).
