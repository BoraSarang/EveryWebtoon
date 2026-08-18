# PLAN_v0.3.2_macos — 사이드바 트리 수정 (클릭 선택 + 폰트 통일)

## 1. 개요
- 네이버/카카오 하위 트리 클릭이 안 되는 버그 수정 + 트리 글자 크기 뒤죽박죽 통일
- 사용자 확정: macOS 표준(파인더식) — 레이블 클릭 = 선택+콘텐츠, chevron = 접기/펼치기

## 2. 원인 (실제 화면 AX 덤프로 확정)
- `SidebarView.groupRow`가 자식을 `VStack`으로 감싸 반환 → `List(selection:)`가 중첩 row의 `.tag`를 인식 못 함 → 자식 클릭 불가
- 그룹 헤더가 `Button`(토글 전용)이라 선택 안 됨
- row 폰트: leaf는 `Label`(sidebar 오버라이드), 그룹은 `HStack+Text(.body)` → 크기·간격 불균일

## 3. 구현 단계
- T-411: 스크린샷으로 글자 크기 상태 확정
- T-412: 사이드바 트리를 `OutlineGroup`으로 교체 — 전 노드 `.tag` 선택 가능, chevron 자동, `expandedIDs`/`groupRow`/`sidebarItemView` 제거
- T-413: row 뷰 통일 — `HStack{ Image(.body) + Text(.body) }` `.font(.body)`, `Label` 제거
- T-414: 그룹(네이버/카카오) 클릭 시 플랫폼 목록 로드 — SidebarItem naver/kakao에 platform 지정 + DiscoverViewModel에 플랫폼 전체 로드 분기 추가
- T-415: 빌드 + AX 검증 (클릭 시 선택 + 콘텐츠 전환 확인)

## 4. 테스트
- 빌드 성공
- AX 덤프: 네이버/카카오 자식 클릭 → 선택(selectedItem 변경) + 콘텐츠 전환
- 요일별/장르별 하위 펼치기/접기 정상
- 글자 크기 화면 확인

## 5. 롤백
- `git` 없음 → 변경 파일 원복: SidebarView.swift / SidebarNode.swift / DiscoverViewModel.swift

## 6. 성능 예산
- 변화 없음 (뷰 구조 교체만, 데이터 로딩 로직 동일)

## 7. 세션 로그
- 2026-08-18: 구현 완료. **중간 삽질 2건 기록**: (1) `OutlineGroup`은 부모/자식 모두 `.tag` 선택이 되고 chevron(disclosure triangle)이 자동 제공되지만, triangle 클릭 시 폴드 토글이 동작하지 않음(AX CGEvent로 2회 클릭해도 value="0" 유지) → `ForEach` 직렬 flatten(최대 3레벨 고정 중첩) + 그룹 헤더에 chevron `Button` 방식으로 교체. (2) chevron에 `onTapGesture`는 List row selection과 충돌해 클릭이 안 먹힘 → 명시적 `Button`으로 해결.
- **검증 (AX)**: 그룹 헤더(네이버) 클릭 → 창 "네이버" 전환 + 7일 통합 목록 로드 ✅ / leaf 자식(베스트 도전) 클릭 → 창 전환 ✅ / 요일별 chevron 클릭 → 펼침(월요일~일요일 노출) ✅ / 3레벨 leaf(월요일) 클릭 → 창 "월요일" 전환 ✅ / 글자 크기 프레임 덤프: 전 노드 H=16 균일 ✅
- 폰트/글자: 모든 row를 `HStack{ Image(.body).frame(width:20) + Text(.body) }`로 통일, `Label` 제거. 실제 화면은 스크린샷 `docs/screenshots/macos/v0.3.2_sidebar.png` + a11y `v0.3.2_sidebar.a11y.txt`.
- **피드백 반영 (T-416)**: (1) 자식 노드 인덴트 — flatten 시 잃었던 들여쓰기 복원. `sidebarRow`/`groupHeaderRow`에 `indent` 파라미터 추가, 레벨당 14pt (3레벨은 28pt). AX 좌표 검증: 네이버 x=50 → 요일별/장르별 x=64(+14) → 월요일 x=82(+18, sidebarRow spacing 차). (2) "나의 모음"을 별도 `Section`으로 분리 — 기존 `myCollectionsHeader`(커스텀 row)는 어색해 제거, 헤더에 plus 버튼 유지. AX: `AXHeading "나의 모음"` + 하위 인기(2) row 확인. 빌드 성공 + 클릭 검증 유지(베스트 도전 → 창 전환).
