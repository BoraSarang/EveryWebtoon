# CHANGELOG

## [2026-09-01] 앱 이름 현지화 (한국어/영어) — v0.4.5

### 플랫폼: macOS (SwiftUI, SwiftPM)

- **요구사항**: 한글 "모두의 웹툰", 영문 "Every Webtoon"으로 앱 이름 현지화
- **변경** (`macos-localization.md` 가이드 적용):
  - `scripts/resources/Info.plist`:
    - `CFBundleDisplayName`/`CFBundleName` → "EveryWebtoon" (번들명과 일치 — Finder가 번들명과 비교해 InfoPlist.strings를 로드하도록)
    - `LSHasLocalizedDisplayName = true` 추가 (누락 시 InfoPlist.strings 무시됨)
  - `ko.lproj/InfoPlist.strings` (UTF-16): `CFBundleDisplayName`/`CFBundleName` = "모두의 웹툰"
  - `en.lproj/InfoPlist.strings` (UTF-16): `CFBundleDisplayName`/`CFBundleName` = "Every Webtoon"
  - 기존에는 `CFBundleName` 누락 + `CFBundleDisplayName`이 번들명("EveryWebtoon")과 불일치("Every Webtoon") → 현지화 무시되던 문제 수정
- **검증**: `lsregister`에서 `localizedNames`: "ko"="모두의 웹툰", "en"="Every Webtoon" 확인. 시스템 한국어 → "모두의 웹툰", 영문 → "Every Webtoon" 표시
- **빌드**: `swift build` 성공, 앱 실행

---

## [2026-09-01] 사이드바 요일별/장르별 플랫폼 혼합 버그 수정 — v0.4.4

### 플랫폼: macOS (SwiftUI, macOS 15+)

- **버그**: 네이버/카카오의 "요일별"/"장르별" **그룹 헤더 클릭 시** `platform`/`category`가 nil이라 `loadAllView`(네이버+카카오 병합)로 잘못 라우팅되어 두 채널이 섞여 표시됨
- **수정**:
  - `SidebarNode`: `naver-week`/`naver-genre`/`kakao-week`/`kakao-genre` 그룹에 `platform` 부여
  - `DiscoverViewModel.performLoad`: "전체보기(`all`)만 병합", "플랫폼 루트 + 해당 플랫폼 week/genre 그룹"은 `loadPlatformView`(채널 단일 통합)로 라우팅하도록 조건 변경
  - `loadPlatformView`: platform을 `item.id` 대신 `item.platform` 사용
- **결과**: 전체보기만 양쪽 병합, 모든 채널 그룹/개별 요일·장르 항목은 해당 채널 단일로 표시
- **검증**: `swift build` 성공, 앱 실행

---

## [2026-09-01] 웹툰 상세 모음 추가 버튼 재구성 — v0.4.3

### 플랫폼: macOS (SwiftUI, macOS 15+)

- **모음 버튼 재구성**: 우측 상단 독립 VStack의 `Menu`(캡션 폴더) 제거 → `actionButtons` 행으로 통합
  - ★ **빠른 담기 버튼**: 기본 모음("팔로우")에 즉시 담기/빼기 — `CollectionsManager.ensureDefaultCollection()`으로 없으면 자동 생성, 상태 실시간 반영
  - 📁 **모음 선택/관리 버튼**: 기존 `CollectionAddMenu`(전체 모음 체크 + 새 모음 만들기) 유지
- **CollectionsManager**: `defaultCollectionName` + `ensureDefaultCollection()` 추가 (기본 모음 보장)
- **검증**: `swift build` 성공, 앱 실행

---

## [2026-09-01] 자동 스크롤 부드러운 스크롤 전환 — v0.4.2

### 플랫폼: macOS (SwiftUI, macOS 15+)

- **자동 스크롤 스터터링 수정**: 기존 매 tick(0.05s)마다 `setBoundsOrigin` 순간 점프(step-and-hold)라 낮은 주사율 모니터에서 끊겨 보였음 → `NSAnimationContext` + `.animator()`(duration 0.08s, linear) tween으로 전환, 기존 `scrollBy`(↑/↓)와 동일한 부드러운 방식. 점프로 인한 모아레/스터터 제거
- **정리**: 더 이상 쓰지 않는 `setOrigin(_:y:)` 메서드 제거
- **검증**: `swift build` 성공, `~/Applications/EveryWebtoon.app` 실행

---

## [2026-09-01] 리더 자동 스크롤 속도 보정 + 사이드바 여백 — v0.4.1

### 플랫폼: macOS (SwiftUI, macOS 15+)

- **자동 스크롤 속도 재설계**: 기존 `step = max(2, maxY×0.0004)×speed×20`(하한 2px 고정으로 짧은 회차에서 초당 80px + 다음화 연발) → `step = maxY×(0.001+speed×0.004)×0.05`, 하한 0.5px만. 0.1x 한 화 약 714초(기존 대비 대폭 감속), 기본 0.5x 약 333초, 2.0x 약 111초
- **사이드바 "나의 모음" + 버튼 여백**: 커스텀 Section 헤더 HStack에 `.padding(.trailing, 6)` 추가 — 시스템 기본 헤더와 동일한 오른쪽 여백 확보
- **검증**: `swift build` 성공, `~/Applications/EveryWebtoon.app` 배포

---

## [2026-09-01] 리더 차별화: 자동 스크롤 · 정주행 · 스크롤/여백 — v0.4

### 플랫폼: macOS (SwiftUI, macOS 15+)

- **자동 스크롤(P1/T-501)**: 뷰어 상단 바 ▶ 토글(재생/일시정지). 0.05s 타이머로 fraction 이동 — 기존 98% 자동 다음화와 연동. 속도 슬라이더(0.1x~2.0x). 수동 키(↑/↓/Space/←/→) 입력 시 자동 정지
- **정주행 연속 재생(P2/T-502)**: 자동 스크롤 중 끝(0.98) 도달 → 다음화 자동 로드 후 `currentEpisodeNo` onChange에서 자동 재생 재개. 마지막화 도달 시 정지
- **스크롤 보폭(P3/T-503)**: ↑/↓ 페이지 스크롤 보폭을 세밀/기본/크게(0.5/1.0/2.0x) 선택
- **좌우 여백(P3/T-503)**: 리더 콘텐츠 좌우 여백 0~20pt 슬라이더 — 독서 몰입
- **UI**: 뷰어 상단 바에 ▶ 재생 버튼 + ⚙️ 설정 팝오버(속도/보폭/여백) 추가
- **검증**: `swift build` 성공(경고 2 — 기존 `positionSaveTimer`와 동일한 MainActor Sendable 정적 경고, 비차단), `~/Applications/EveryWebtoon.app` 배포 확인

---

## [2026-08-18] macOS 전용 정리 + 번들 ID 변경 — v0.3.3

### 플랫폼: macOS (SwiftUI, macOS 15+)

- **macOS 단일 플랫폼으로 축소**: Android/ 전체 제거 (scripts/build-android.sh, docs/screenshots/android/, backup/, vendor/) — "처음부터 macOS 앱이었던 것처럼" 정리
- **스크립트 macOS 전용화**: `build_and_run.sh`(android 분기 제거), `screenshot.sh`(기본값 macos + android/ios/web 분기 제거), `a11y-dump.sh`, `env-expiry-check.sh`(Android/.env 제거)
- **문서 정리**: docs/TODO.md(android 라벨/항목), docs/DESIGN.md(Android 섹션), CHANGELOG.md(Android 이력 2건), PLAN_v0.2_macos.md("iOS/웹 관습" 문구) 제거
- **번들 ID 변경**: `com.borasarang.everywebtoon`으로 변경 (12곳 — Info.plist, DebugLogger(OSLog), DiscoveryCache, ax* 스크립트 7개, README, PLAN.md)
- **빌드**: `swift build` 성공, `build_and_run.sh debug macos` 배포·실행 확인. 배포 경로 `~/Applications/EveryWebtoon.app` + PkgInfo 생성 추가. 성능 영향 없음
- **알려진 문제**: Finder/Dock 표시 이름 "모두의 웹툰" 근본 미해결 — `localizedNameKey`가 파일명("EveryWebtoon")으로 폴백. 시도·실패 6건(번들 ID 변경/Finder·Dock 재시작/재부팅/파일명 한글화 폐기/PkgInfo+DevelopmentRegion). 실행 프로세스(`lsappinfo`)는 "모두의 웹툰" 정상 표시

---

## [2026-08-18] 사이드바 트리 수정 — v0.3.2

### 플랫폼: macOS (SwiftUI, macOS 15+)

- **클릭 버그 수정**: 네이버/카카오 하위 트리가 클릭 시 아무 반응 없던 문제 해결. 원인은 `groupRow`가 자식을 `VStack`으로 감싸 반환해 `List(selection:)`가 중첩 row의 `.tag`를 인식 못 한 것 → `ForEach` 직렬 flatten(최대 3레벨) + 그룹 헤더에 chevron `Button` 방식으로 재구성. 모든 노드가 개별 selectable row가 됨
- **macOS 표준 동작**: 그룹(네이버/카카오) 레이블 클릭 → 선택 + 해당 플랫폼 7일 통합 목록 로드(`loadPlatformView`), chevron 클릭 → 접기/펼치기. 요일별/장르별 하위까지 동일
- **글자 크기 통일**: `Label`(사이드바 스타일 오버라이드) 제거, 모든 row를 `HStack{ 아이콘(.body) + Text(.body) }`로 통일 — AX 프레임 덤프로 전 노드 H=16 균일 확인
- **자식 노드 인덴트(T-416)**: flatten 시 잃었던 트리 들여쓰기 복원 — `indent` 파라미터로 레벨당 14pt(3레벨 28pt). AX 좌표 검증: 네이버 x=50 → 요일별 x=64(+14) → 월요일 x=82
- **나의 모음 섹션 분리(T-416)**: 커스텀 row 헤더(`myCollectionsHeader`)를 별도 `Section`으로 교체, 헤더에 plus 버튼 유지 — "인기" 모음이 어색하게 붙어 보이던 문제 해결
- **검증**: 빌드 성공 + AX 클릭 시뮬레이션 — 네이버/베스트 도전/월요일 클릭 시 창 전환 ✅, 요일별 chevron 펼침 ✅. 스크린샷 `docs/screenshots/macos/v0.3.2_sidebar.png`
- **참고**: `OutlineGroup`(triangle 토글 클릭 불동작)과 chevron `onTapGesture`(List selection 충돌)는 시도 후 실패, 최종적으로 위 구조로 확정

---

## [2026-08-18] 코드 리팩토링 — v0.3

### 플랫폼: macOS (SwiftUI, macOS 15+)

- **죽은 코드 제거(A)**: `LocalWebtoonManager.isDownloaded(id:)`(항상 false) + `Webtoon.isDownloaded`(사용처 없음) 제거, PythonBridge 동일 if/else 분기 정리 + `fputs`/`python_call.log` 제거, 미사용 `C.appName`/`C.bundleId` 제거
- **파일 분리(B)**: ReaderView 688줄에서 `ReaderPageView`/`ReaderImageCache`/`ScrollViewFinder`/`TrailingIconLabelStyle` 추출, `LibraryCell`·`BackupAction` 분리, `VisualEffectView` 공용화(중복 2곳 제거)
- **중복 제거(C)**: `ByteFormat`(1024 기반) 단일화 — DownloadTask/ReaderView/SidebarView 3중 포맷터 통합, `Webtoon.merged(with:)`/`with(updateDate:)`로 병합 로직 2중 통합, DiscoverViewModel 캐시 키 생성 3회 → `cacheKey(_:_:)`, `DownloadViewModel.handleProgress(id:progress:)` 공용화(updateExternal 제거, onProgress 이중 구현 제거)
- **성능(D)**: 라이브러리 회차 수 정렬 디스크 스캔 매 body → `episodeCounts` @State 배치 캐시(`localEpisodeCounts(for:)`, 다운로드 완료 시 `onChange(doneCount)` 갱신), reload `saved.first` O(n·m) → 딕셔너리 조회, UpdateChecker 로컬 스캔 task group 병렬화
- **검증**: `swift build` 성공, 경고 0건. LibraryView 타입체크 타임아웃은 `onChange` 값 타입(`[DownloadTask]`)을 `doneCount`(Int)로 전환해 해결. 참고: 회차 수·용량 표시가 1024 단위로 통일됨(기존 1000 단위에서 소폭 변경)

## [2026-08-18] 앱 이름 로케일 지역화 — v0.3.1

### 플랫폼: macOS (SwiftUI, macOS 15+)

- 시스템 로케일에 따라 Dock/Finder 표시 이름 분리: 한글 **모두의 웹툰** / 영문(기본) **Every Webtoon**
- `CFBundleDisplayName` + `CFBundleName`을 `InfoPlist.strings`로 지역화 (ko.lproj/en.lproj), 기본값 `CFBundleDevelopmentRegion=en`
- `build_and_run.sh`에 lproj 리소스 복사 추가, `.app` 배포 검증 완료

---

## [2026-08-18] ⌘K 커맨드 팔레트 + 기동 정지 버그 수정 — v0.2.1

### 플랫폼: macOS (SwiftUI, macOS 15+)

- **⌘K 커맨드 팔레트**: Raycast/Linear 스타일 중앙 오버레이(460×320, `.hudWindow`), 검색 필터 + ↑↓ 이동 + Enter 실행 + Esc 닫기. `CommandPaletteManager.swift` 신규 (PaletteCommand/CommandPaletteStore/Manager/View/PalettePanel/VisualEffectView)
- **명령 13개**: 검색(⌘F), 사이드바 토글(⌥⌘S), 테마 3종, 설정 열기(⌘,), 전체보기, 네이버, 카카오, 내 보관함, 최근 본, 디버그 패널(⌘⇧D), 로그 지우기(⌘⇧K) — 사이드바 그룹(네이버/카카오) 포함(`isGroup == false` 필터 제거)
- **Clear Logs ⌘K→⌘⇧K 이전** (충돌 해소), `CommandGroup(after: .sidebar)` 직접 버튼 + toggleSidebar/navigateSidebar Notification + ContentView onReceive (detailPath 초기화 후 selectedItem 변경)
- **키보드 수신**: `.nonactivatingPanel`이 키 이벤트 차단(AX상 focused이나 실키 미전달) → styleMask `[.borderless]` + `NSApp.activate` + `makeKeyAndOrderFront`로 해결, `NSEvent.addLocalMonitorForEvents(.keyDown)` 핸들링, `show()` 시 store.reset()으로 재오픈 쿼리 리셋
- **기동 정지 버그 수정**: `DiscoveryCache` 메인 스레드 동기 파일 I/O가 `Data(contentsOf:)`/`open`에서 무한 블로킹(환경적, 루트 미규명) → `get/set/getEpisodes/setEpisodes/clear` 전부 비동기화(`ioQueue .concurrent` + `readData` 3초 타임아웃)로 메인 스레드 보호. 앱이 캐시 파일 존재 상태에서도 정상 기동됨 (호출부 4곳 `await` 전환)
- **검증**: 빌드 ✅ / TC-CMD-01~05 ✅ (⌘K 표시+포커스, dark·네이버 필터, ↑↓+Enter 실행+닫기, Esc 닫기, ⌘⇧K 로그 클리어[0/0], 재오픈 쿼리 리셋 13개) / ⌘⇧D 디버그 패널 ✅ / 네이버 명령 실행(창 제목 "네이버") ✅ / 스크린샷 `docs/screenshots/macos/v0.2.1_palette.png`
- **참고**: CGWindowList layer=3 잔존은 stale 아티팩트 — 표시/숨김 판정은 AX windows 목록 사용. 한국어 IME 활성 시 팔레트 실타이핑은 조합문자로 들어감(정상)

---

## [2026-08-18] macOS 전면 리디자인 — v0.2 (Phase 1~3 완료)

### 플랫폼: macOS (SwiftUI, macOS 15+)

- **구조 (Phase 1)**: `.windowToolbarStyle(.unified)` + `defaultSize 1100×720/min 1000×640`, `NavigationSplitView` + `List(.sidebar)` 사이드바, detail에 `NavigationStack` + 툴바 검색(⌘F), `DetailTopBar` 제거 후 `.navigationTitle`/툴바 Back 대체, `CommandGroup(after: .sidebar)`로 사이드바 토글(⌘⌥S)·검색(⌘F)·테마 Picker, `Settings` Scene
- **화면 폴리시 (Phase 2)**: 그리드 adaptive min 170/max 200, 셀 cornerRadius 8 + 그림자 2단(hover 0.14/8/3·일반 0.08/4/2) + hover 1.02/easeOut 0.12, 별점 9pt·점수/화수/날짜 `monospacedDigit`, `PlatformBadge` displayP3 색, LibraryCell 정리, 디테일 히어로 160×210/cornerRadius 10 + 정렬 `.menu`, 리더 Space(49)·⌘0(29) 단축키 + 호버 바 자동숨김(1.6s) + 화수 `monospacedDigit`, 설정 창 600×480
- **디버그 패널 리디자인 (Phase 3)**: `NSWindow` 640×360/min 420×240/`.fullSizeContentView`/투명 타이틀, `VisualEffectView(.popover)` 배경, "ant" 심볼 + 카운트 + 필터 TextField + SF Symbol 툴바(자동스크롤/복사/전체복사/지우기), 로그 12pt monospaced + `.textSelection(.enabled)` + 레벨별 세만틱 색, `logRow(for:)` 리팩터로 타입체크 타임아웃 해결
- **단축키 충돌 수정**: macOS 26 시스템 "자동으로 Dock 가리기"(⌘D)가 디버그 패널 ⌘D 가로챔 → **⌘⇧D**로 변경(검증), `CommandMenu`/서브메뉴 키 동등 미등록 → View `CommandGroup` 직접 버튼으로 이동(⌘⇧D/⌘⇧C/⌘⇧A/⌘K/⌘⇧L), Auto Scroll ⌘⇧S→**⌘⇧L** (백업 복원과 충돌)
- **빌드**: `Package.swift` tools 6.0 + `.swiftLanguageMode(.v5)` (macOS 15 타깃) — Swift 6 언어 모드의 기존 singleton/동시성 에러 회피
- **검증**: 빌드 ✅, TC-01~05(사이드바/검색/디테일/back) ✅, ⌘F/⌘⌥S/⌘⇧D ✅, 설정 창 600×480 ✅, 리더 Space 다음화 ✅ + 호버 바 숨김 ✅(로그+스크린샷 diff), 디버그 패널 필터/지우기 ✅, `a11y-dump.sh` + 스크린샷 산출물 저장

---

## [2026-08-02] v1.11.1 — 신규 회차 확인 네트워크 최적화 (32배 절감)

### 경량 `latest_episode` 액션
- `fetcher/naver_fetcher.py`: JSON API `/api/article/list?titleId=X&page=1` 1회 조회(약 10KB) → 첫 페이지 `max(no)` 반환. 기존 HTML 상세 페이지(약 320KB) 대비 **32배 절감**. 성인 웹툰(404)은 `AdultVerificationError`로 구분
- `fetcher/kakao_fetcher.py`: `window_size=30 → 100` 1회 조회 → 최대 uid 반환 (기존 최대 10회 페이지네이션 대비 1/3)
- `api.py`: `latest_episode` 액션 신설 (platform, title_id → `{episode_no}`)
- `UpdateChecker.swift`: 신규 회차 확인 시 `get_episodes`(전체 목록) 대신 `latest_episode` 호출 — 24h 인메모리 캐시 + 기존 에피소드 캐시 우선 사용(캐시 히트 시 0KB)
- 검증: 네이버 361, 카카오 14143759 반환 확인, 성인/err 경로 확인, macOS 빌드+배포 통과

---

## [2026-08-02] v1.11.0 — 설정 화면 + 저장 위치/캐시/신규 회차 알림

### 설정 화면 (메뉴바 "설정…")
- `SettingsView.swift` 신설: 저장 위치 / 캐시 / 신규 회차 3개 섹션
- 저장 위치: 현재 경로 표시, 폴더 선택(NSOpenPanel), 기본 위치 재설정, **기존 데이터 이동**(복사 방식, 다운로드 중 비활성, 대상 폴더에 이미 있으면 스킵)
- 캐시: 디스커버리 유효기간 1/6/12/24시간 또는 사용 안 함
- 신규 회차: 자동 확인 주기 1/5/10/30분 또는 수동만, 알림센터 알림 ON/OFF
- 저장 위치 변경은 **앱 재시작 후 적용**

### 설정 저장소 확장 (AppSettings)
- 신규 키: `storage_base_path`, `cache_ttl_hours`, `update_check_interval`, `new_episode_alerts`

### 하드코딩 제거
- `AppPaths.basePath`: 설정 우선 + 디렉토리 자동 생성
- `DiscoveryCache`: TTL 동적 반영 (설정값, 0 = 캐시 비활성)
- `UpdateChecker`: 확인 주기 설정 반영 (0 = 수동), **새 회차 발견 시 UNUserNotificationCenter 알림**
- `CachedAsyncImage`/`PythonBridge`(python_call.log): 경로 하드코딩 → AppPaths 기반

### 검증
- macOS 빌드 + 배포, `storage_base_path` → `/tmp/ew_test_storage` 재시작 후 DB/캐시/로그 신규 생성 확인, 원복 후 정상 동작 확인
- DebugPanel ERROR 0

---

## [2026-08-01] v1.10.0 — 컬렉션(나의 모음) + Books 스타일 셀 + 뷰어 회차 픽커

### 팔로우 → "나의 모음" (컬렉션 시스템)
- `FollowManager` → **`CollectionsManager`** (신규): 모음 이름 → 웹툰 ID 집합, UserDefaults
- create/rename/delete/add/remove/toggle, `names(containing:)`, `allIds`
- 자동 마이그레이션: 기존 `followed_webtoon_ids` → "팔로우" 모음으로 1회 이전
- 사이드바 LIBRARY: "나의 모음" 헤더 + 모음 리스트 + `+` 버튼
- 상세 화면: ★ 토글 → **"모음에 추가" 메뉴** (모음별 추가/제거 체크 + "새 모음 만들기…")

### 셀 인터랙션
- **우클릭 컨텍스트 메뉴**: 모음에 추가 / 공식 사이트 / 업데이트 확인
- **호버 강조**: 커버 `scaleEffect(1.03)` + 그림자 강화

### 뷰어 회차 픽커
- 하단 바 중앙 회차 표시 → **회차 선택 Menu** (전체 회차 내림차순, 현재 체크, 선택 시 즉시 로드)

---

## [2026-08-01] v1.9.0 — 소스 아키텍처 정리 + EPUB 내보내기

### 소스 아키텍처 정리
- `FollowManager`, `ReadHistoryManager`, `LocalWebtoonManager`, `WebtoonDB`, `DiscoveryCache` → `Services/`
- 재사용 뷰를 `Views/Common/`으로 이동: `CachedAsyncImage`, `PlatformBadge`, `WebtoonGrid`, `WebtoonGridCell`
- 검색 뷰 3타입을 `Views/Search/`로 분리: `SearchField`, `SearchRecentsView`, `SearchResultsView`
- 상세 화면 뒤로가기 → 공용 `Views/Common/DetailTopBar.swift`

### EPUB 내보내기
- 백엔드 `exporter.py`: `export_episode_epub` — EPUB3 (mimetype stored + container.xml + content.opf + nav.xhtml + toc.ncx), XML 이스케이프, `.partial` 거부
- 에피소드 행 내보내기 버튼 → 메뉴에서 **CBZ / EPUB** 선택

---

## [2026-07-31] v1.8.0 — 이어보기 + 일괄 다운로드 + 업데이트 감지 + 백업

### 이어보기 (페이지 단위 위치 복원)
- `ReadHistoryManager`: 회차별 읽기 위치(스크롤 비율 0~1) 저장/복원
- `ReaderView`: `boundsDidChange` 관찰로 1% 단위 저장, `onDisappear` 시 저장
- 98% 지점 도달 시 **다음 회차 자동 로드**
- 라이브러리 서브타이틀: "3화 · 45%까지 봄"

### 일괄 다운로드
- 상세 화면: 최근 10화 / 전체 / **범위 선택** (시작~끝 화 스테퍼)
- `DownloadStatus.paused` 추가 — **일시정지/재개**: 프로세스 terminate + 큐 보존, 재개 시 재투입
- 백엔드: `.partial` 보존 + 재개 시 기존 페이지 스킵

### 업데이트 감지
- `UpdateChecker`: 보관함 웹툰별 로컬 최대 회차 vs 서버 최신 회차 비교 (병렬 `withTaskGroup`, 캐시 활용)
- 라이브러리 그리드: 새 회차 배지("+N"), 자동 확인(5분 간격)
- 성인 웹툰: `AdultVerificationError`로 구분, 스킵

### 백업/복원
- `BackupManager`: JSON (version=1, webtoons + history)
- 메뉴바: `백업 생성…`(Cmd+S) / `백업에서 복원…`(Cmd+Shift+S), 병합 복원

### CBZ 내보내기
- 백엔드 `export_episode(format=cbz)` — `_export/{제목}/{회차}.cbz`, ZIP_STORED
- 에피소드 행 내보내기 버튼 → Finder에서 보기

### 라이브러리 정렬/필터
- 정렬: 최근 추가 / 제목순 / 회차 수 / 최근 읽음
- 필터: 플랫폼 + 상태(연재/완결)

### 뷰어 개선 + 테마
- **확대기**: 호버 시 원형 렌즈(2.4x)
- **이미지 필터**: 밝기(-50%~+50%) / 대비(0.5~1.8) 슬라이더
- **테마**: system/light/dark — 메뉴바 View → 테마

### 팔로우 + 검색 기록
- `FollowManager`: 상세 화면 ★ 토글, 사이드바 "팔로우" 섹션
- 업데이트 감지 기준: `max(다운로드 회차, 마지막 본 회차)`
- **최근 검색어**: 최대 10개 저장

### v1.8.1 — 수정
- 이어보기 전면 수정: ScrollViewFinder를 LazyVStack 내부로 이동, clip view `postsBoundsChangedNotifications = true` 강제 활성화
- 98% 자동 다음화: 상슬 에지 감지로 변경
- 위치 복원 재시도: 1.5초까지 6회
- 보기창 닫힘/키 잃음 시 위치 저장 + 타이머 정리
- 사이드바 클릭 시 검색창 포커스 해제
- 창 타이틀바: 화면별 타이틀 복원

---

## [2026-07-31] v1.7.2 — UI 회귀 수정 + 배포 파이프라인 정비

### 백엔드
- **치명적 버그 수정**: `main.py` — 요청 태스크 스폰 후 readline 복귀로 인해 stdin EOF 즉시 감지 → pending 태스크 전부 취소 → 다운로드 0% 멈춤. EOF 분기에서 `await asyncio.gather(*active_tasks.values(), return_exceptions=True)`로 진행 중 태스크 완료 대기 후 종료

### Swift 앱 (UI)
- **사이드바 클릭 무반응 수정**: toolbar의 SearchField이 사이드바 히트 테스트를 가로채는 버그 → 검색창을 사이드바 내부 최상단으로 이동
- **검색창 포커스 상실 수정**: 한자 입력 시 detail 전환 → `@FocusState`로 복원
- `.navigation` 배치 ToolbarItem 제거 → 상세 뷰 상단 인라인 back bar
- 디스커버/라이브러리 상단 여백 축소

### 배포/아이콘
- **배포 경로**: `~/Applications/EveryWebtoon.app` (build_and_run.sh가 번들 직접 구성)
- **Info.plist 수리**: DOCTYPE 오류 수정, `</plist>` 누락 수정
- **앱 아이콘**: `scripts/generate_icon.sh` (Swift/CGContext → make_icns.py)

---

## [2026-07-31] v1.7.1 — 안정화 패치

### 백엔드
- **치명적 버그 수정**
  - `downloader.py`: `shutil` import 누락 수정
  - 재시도 예외에 `asyncio.TimeoutError` 추가, `403/404`는 즉시 실패
  - `as_completed` 실패 시 고아 태스크 `cancel()` + 정리
  - `kakao_fetcher.py`: `last_release_dt` `None[:10]` 크래시 방어
  - 빈 `image_urls`는 조기 `ValueError`
- **취소 실제 구현**: 요청별 `asyncio.Task` 맵 (`active_tasks`), 취소 시 `{"cancelled": true}` 응답
- **다운로드 개선**: `.done` 마커 스킵, `force_close` 제거 (keep-alive 유지), 경로 조작 방어, `asyncio.to_thread`로 블로킹 방지

### Swift 앱
- **PythonBridge**: continuation resume을 MainActor, `taskId` 지원 + `activeProcesses` 레지스트리, `withTaskCancellationHandler` → 프로세스 `terminate()`
- **DownloadViewModel**: id 기반 조회로 인덱스 크래시 방지
- **ReaderViewModel**: `waitForTask` 무한 스피너 수정
- **ReaderView**: `NSImage(contentsOfFile:)` 백그라운드 로딩 + 메모리 캐시
- **DiscoverViewModel**: 14회 순차 요청 → `withTaskGroup` 병렬화
- **CachedAsyncImage**: 2회 재시도

---

## [2026-07-30] v1.7.0 — 디버그 패널 + 다운로드 병렬화 + UI 개선

- PythonBridge 파싱 재작성: Data 기반 바이트 버퍼
- 오늘의 웹툰 2행 분리 (네이버 별점 TOP10 + 카카오 요일 TOP10)
- `is_updated`(UP) 배지, 카카오 썸네일 fallback
- `PAGE_CONCURRENCY=6` 세마포어, 커넥터 12
- 진행률 상세: 바이트/페이지 수, 뷰어 로딩 크기
- 뷰어 키보드: `NSEvent.addLocalMonitor` (ESC/←/→/↑/↓)

---

## [2026-07-30] v1.6.0 — 멀티 플랫폼 + 카카오 지원

- 카카오 웹툰 플랫폼 추가 (discover, get_episodes, download)
- DebugPanel 메뉴바 표준 (Cmd+D, 📌 자동 스크롤)
- macOS Settings Scene

---

## [2026-07-29] v1.5.0 — MVP

- 네이버 웹툰 디스커버리/감상/다운로드 (macOS)
- SwiftUI + Python aiohttp 백엔드

---

## [2026-07-28] v1.0.0 — 프로젝트 시작

- 아이디어 구상 및 프로토타입
