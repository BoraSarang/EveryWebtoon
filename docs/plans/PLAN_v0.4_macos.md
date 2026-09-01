# PLAN_v0.4_macos — 리더 뷰어 차별화: 자동 스크롤 · 정주행 · 스크롤/여백 UX (리서치 기반)

## 1. 개요
- 목표: 외부 프로그램 리서치(네이버 시리즈 PC 코믹뷰어, Kavita/Komga/YACReader 등)에서 확인된 "웹툰 리더 차별화 기능"을 기존 강력한 리더(세로 스크롤, 폭맞춤, 확대경, 밝기/대비, 이어보기, 98% 자동 다음화) 위에 추가
- 플랫폼: macOS (SwiftUI, macOS 15+, tools 6.0 + swiftLanguageMode v5)
- 참고 문헌: docs/plans/*, README(뷰어 기능표), 리서치 결과(대본)

## 2. 구현 단계

### P1 — T-501: 자동 스크롤 (Auto Scroll) + 속도 조절
- `ReaderViewModel`: `@Published var autoScroll = false`, `@Published var autoScrollSpeed: Double` (기본값 중간)
- 리더 바 플레이 ▶ 토글 버튼 (재생/일시정지 아이콘 전환)
- 구현: 기존 `scrollBy(_:)`와 fraction 관찰 로직 재사용
  - 타이머(예: 0.1s 간격)로 `clip.setBoundsOrigin`을 현재 fraction + delta 이동
  - delta = 속도에 비례 (프레임 독립: 규칙적 인터벌이므로 고정 보폭 × 속도 계수)
  - 끝(0.98)에 도달 시 기존 `handleFractionChange` 경로를 통해 자동 다음화 연동, 다음화 로드 후 자동 재생 유지
  - Space/방향키 등 수동 입력 시 자동 스크롤 중지
- 속도 조절 UI: 뷰어 상단 바 popover(기존 `filterPopover` 패턴) — 슬라이더 저속~고속

### P2 — T-502: 정주행(연속 재생) / 자동 넘김 타이머
- P1의 자동 다음화와 연동: 회차 로드 완료 시 자동 스크롤 재개 (`loadEpisode` 완료 후 `autoScroll` true면 재생 restart)
- 도달 fraction 0.98에서 다음화로 넘어가며 자동 스크롤 유지 → 연속 정주행
- 회차 끝에서 마지막화면: 자동 스크롤 정지 + 완료 표시

### P3 — T-503: 휠 스크롤 보폭 조절 + 좌우 여백
- 휠 스크롤: 상단 바에 스크롤 보폭 설정(기본/일반/크게) — 클립뷰/스크롤 민감도 계수
- 좌우 여백: 리더 콘텐츠(`readerContent` ScrollView 내 LazyVStack) 좌우 padding 추가 — 독서 몰입
- 인덴트/배치는 `ReaderView`의 `readerContent` 영역만 변경

## 3. 테스트
- `swift build` — 경고 0
- `build_and_run.sh debug macos` — 배포·실행
- DebugPanel: ERROR 0, `[INFO] [FEATURE]` 진입점 로그
- 수동 검증: 자동 스크롤 재생/일시정지, 끝 도달 자동 다음화, 속도 조절, 정주행 연속 재생, 수동 입력 시 정지, 여백/보폭 반영

## 4. 롤백
- ReaderViewModel/ReaderView의 관련 프로퍼티·메서드 되돌림 + CHANGELOG 엔트리 삭제

## 5. 세션 로그
- 진행 중 기록