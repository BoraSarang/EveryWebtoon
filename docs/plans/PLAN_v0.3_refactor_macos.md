# PLAN v0.3 — macOS 코드 리팩토링

**플랫폼**: macOS (SwiftUI, macOS 15+ 타깃)
**날짜**: 2026-08-18
**목표**: 전체 소스 면밀 검토로 발견한 죽은 코드 제거, 관심사 분리(파일 분리), 중복 제거, 성능 개선 — 로직 동작 변경 없음
**범위**: A(안전 정리) + B(파일 분리) + C(중복 제거) + D(성능) — 사용자 확정
**검증**: `scripts/build_and_run.sh debug macos` + 스모크(디스커버/라이브러리/상세/리더/팔레트/디버그패널)

---

## 1. 개요

v0.2 리디자인 이후 코드가 42 파일/약 6,200줄로 성장. 대형 파일(ReaderView 688줄 등)의 관심사 혼재, 바이트 포맷터 3중, Webtoon 병합 로직 2중, 캐시 키 생성 3회, 죽은 코드(`isDownloaded` 항상 false, 동일 if/else 분기), 성능 이슈(라이브러리 정렬 시 디스크 스캔 매 body 재계산, O(n·m) 조회)를 정리한다.

## 2. 결정 사항

| 항목 | 결정 |
|---|---|
| 진행 순서 | **A → B → C → D 순** (안전 → 구조 → 중복 → 성능) |
| 원칙 | 동작 변경 없음. hover/기타 의도적 디버그 로그는 유지 (AGENTS 10.1) |
| 커밋 단위 | T-번호 1개당 1커밋 (현재 git repo 아님 → 파일 백업 유의) |

## 3. 구현 단계 (T-번호)

### A. 죽은 코드 / 안전 정리

| T | 작업 | 파일 | 상태 |
|---|---|---|---|
| T-301 | `LocalWebtoonManager.isDownloaded(id:)`(항상 false) + `Webtoon.isDownloaded` computed property 제거 | LocalWebtoonManager, Webtoon | 예정 |
| T-302 | `PythonBridge` scriptPath 동일 분기 정리 + `fputs` 디버그 제거 + `python_call.log` 덮어쓰기 제거 | PythonBridge | 예정 |
| T-303 | 미사용 `C.appName`/`C.bundleId` 제거 (`C.maxConcurrentDownloads`만 사용) | Constants | 예정 |

### B. 관심사 분리 (파일 분리)

| T | 작업 | 파일 | 상태 |
|---|---|---|---|
| T-304 | `VisualEffectView` 공용화 — `Views/Common/VisualEffectView.swift` 신설, DebugPanelWindowManager/CommandPaletteManager의 private 중복 제거 | Common 신설, DebugPanelWindowManager, CommandPaletteManager | 예정 |
| T-305 | `ReaderView` 688줄 분리 — `ReaderPageView`/`ReaderImageCache`/`ScrollViewFinder`/`TrailingIconLabelStyle` 별도 파일 | Views/Reader/ | 예정 |
| T-306 | `LibraryCell` 분리 — `Views/Library/LibraryCell.swift` | Library | 예정 |
| T-307 | `BackupAction`(NSAlert UI) 분리 — `Views/Settings/BackupAction.swift`, 중간 `import AppKit` 정리 | Services/BackupManager, Settings 신설 | 예정 |

### C. 중복 제거

| T | 작업 | 파일 | 상태 |
|---|---|---|---|
| T-308 | 바이트 포맷터 공용화 `ByteFormat` — `ReaderView.sizeText`/`DownloadTask.formatBytes`/`SidebarView.formatBytes` 3곳 통합 | Utils/ByteFormat 신설, ReaderView, DownloadTask, SidebarView | 예정 |
| T-309 | `Webtoon.merged(with:)` — `DiscoverViewModel.enrich` + `WebtoonDetailViewModel` updateDate 재구성 통합 | Webtoon, DiscoverViewModel, WebtoonDetailViewModel | 예정 |
| T-310 | 캐시 키 생성 헬퍼 — `params.sorted…joined` 3회 통합 (`[String:String].cacheKey`) | DiscoverViewModel | 예정 |
| T-311 | onProgress 갱신 공용화 — `DownloadViewModel.handleProgress(id:progress:)` 신설, ReaderViewModel의 이중 갱신 제거 | DownloadViewModel, ReaderViewModel | 예정 |

### D. 성능

| T | 작업 | 파일 | 상태 |
|---|---|---|---|
| T-312 | `LibraryView.displayWebtoons` episodeCount 디스크 스캔 매 body 재계산 → 배치 캐시 | LibraryView | 예정 |
| T-313 | `LibraryView.reload` recent `compactMap { saved.first }` O(n·m) → 딕셔너리 조회 | LibraryView | 예정 |
| T-314 | `UpdateChecker.checkAll` `localEpisodes(for:)` 스캔을 병렬 group 안으로 이동 | UpdateChecker | 예정 |

## 4. 테스트 계획 (TC)

- **TC-REF-01**: `scripts/build_and_run.sh debug macos` 컴파일 0 에러
- **TC-REF-02**: 앱 기동 — 디스커버(전체/네이버 요일) 로드 정상
- **TC-REF-03**: 라이브러리 정렬(회차 수/제목/최근 읽음) + 최근 본 탭 정상
- **TC-REF-04**: 웹툰 상세 — 회차 목록 + 다운로드 버튼 정상
- **TC-REF-05**: 리더 열기(이어보기 fraction 복원), ⌘K 팔레트, ⌘⇧D 디버그 패널
- **TC-REF-06**: DebugPanel 전체 복사 → ERROR 0개, 동작 회귀 없음 확인

## 5. 롤백 계획

- T-번호별 단계 적용 → 문제 시 해당 파일 원복
- 파일 분리(B)는 순수 이동이므로 `swift build` 실패 시 즉시 원복
- 문서도 함께 되돌리기 (`docs/plans/PLAN_v0.3_refactor_macos.md`)

## 6. 성능 예산

| 지표 | 예산 |
|---|---|
| 콜드 스타트 | ≤1.5s (변화 없음) |
| 라이브러리 회차 수 정렬 | 디스크 스캔 1회/정렬 (변경 전: 매 body 재계산) |
| 메모리 | ≤300MB (변화 없음) |

## 7. 에러코드

신규 에러코드 없음 (로직 변경 없음).

## 8. 세션 로그

- 2026-08-18: 연구 완료 — 전체 42 파일/문서 검토, 범위 A+B+C+D 사용자 확정, PLAN 작성
- 2026-08-18: A~C단계 구현 완료 (T-301~T-311). 빌드 성공 — T-308~T-311 중간 빌드에서 ReaderView.swift:224 Sendable 경고(기존) 확인, LibraryView 타입체크 타임아웃은 `onChange(of: downloadVM.tasks)`의 `[DownloadTask]` 값을 `doneCount`(Int) 감시로 전환해 해결. `@ViewBuilder content`로 body 분리.
- 2026-08-18: D단계 구현 완료 (T-312~T-314). 최종 `swift build` 성공, 경고 0건. `LocalWebtoonManager.localEpisodeCounts(for:)` 배치 조회 신설, LibraryView `episodeCounts` @State 캐시(다운로드 완료 시 `onChange(doneCount)`로 갱신), reload 딕셔너리 조회, UpdateChecker `localEpisodes` 스캔을 task group 안으로 이동해 병렬화.
- 2026-08-18: 최종 빌드 검증 완료. 스모크 테스트(디스커버/라이브러리/상세/리더/⌘K/⌘⇧D)는 사용자 수동 확인 권장.
