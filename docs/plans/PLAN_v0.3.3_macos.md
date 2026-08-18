# PLAN_v0.3.3_macos — macOS 전용 정리 + 번들 ID 변경 (CHANGELOG 반영)

## 1. 개요
- 야간 세션에서 수행된 "macOS 전용 정리 + 번들 ID 변경" 작업의 CHANGELOG.md 반영 (세션 로그에 "CHANGELOG에 이번 정리 이력 추가 대기"로 남아 있던 항목)

## 2. 구현 단계
- T-417: CHANGELOG.md 최상단에 정리 이력 엔트리 추가 (2026-08-18)
- T-418: 구 번들 ID 흔적 전면 제거 (CHANGELOG/세션 로그 문자열 + 옛 번들 ID 캐시/데이터 폴더 삭제)

## 3. 테스트
- 마크다운 렌더링 확인 (기존 엔트리 형식과 일치)

## 4. 롤백
- CHANGELOG.md 해당 엔트리 삭제

## 5. 세션 로그
- 2026-08-18: T-417 완료 — CHANGELOG 반영
- 2026-08-18: T-418 완료 — 구 번들 ID 흔적 전면 제거: CHANGELOG/세션 로그 문자열 제거, `~/Library/Caches/EveryWebtoon/`·`~/Documents/EveryWebtoonData/` 삭제. 프로젝트 전체 grep 0건 확인 (venv playwright 바이너리 내부 문자열은 의존성 내부라 무관 제외)