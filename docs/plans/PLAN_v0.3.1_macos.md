# PLAN_v0.3.1_macos — 앱 이름 로케일 지역화

## 1. 개요
- 시스템 로케일(한글/영문)에 따라 Dock, Finder에서 표시되는 앱 이름을 다르게 한다.
- 한글: **모두의 웹툰** / 영문(기본): **Every Webtoon**

## 2. 결정 사항
- `CFBundleName` + `CFBundleDisplayName`을 `InfoPlist.strings`로 지역화 (macOS 13+는 Dock/Finder가 CFBundleDisplayName보다 CFBundleName을 참조하는 경우가 있어 둘 다 지역화).
- 기본값(CFBundleDevelopmentRegion=en)은 `Every Webtoon`, `ko.lproj`에서 `모두의 웹툰` 제공.
- `build_and_run.sh`에 lproj 복사 추가.

## 3. 구현 단계
- T-401: `scripts/resources/Info.plist` — CFBundleDisplayName 추가(=Every Webtoon), CFBundleName을 Every Webtoon으로 변경, CFBundleDevelopmentRegion=en
- T-402: `scripts/resources/ko.lproj/InfoPlist.strings` (모두의 웹툰) + `en.lproj/InfoPlist.strings` (Every Webtoon)
- T-403: `build_and_run.sh`에 lproj 리소스 복사 추가

## 4. 테스트
- `build_and_run.sh debug macos` → `.app` 재배포
- 한국어 시스템: Finder/Dock에 "모두의 웹툰" (Dock 캐시로 반영 지연 가능, 재시작 필요 시 안내)
- 영문 시스템: "Every Webtoon"

## 5. 롤백
- Info.plist CFBundleName 원복 + lproj 삭제 + 스크립트 복사 줄 제거

## 6. 성능 예산
- 변경 없음 (리소스 2KB 수준)

## 7. 세션 로그
- 2026-08-18: T-401~T-403 완료. `build_and_run.sh debug macos` 성공, `.app` 배포 시 ko/en lproj 복사 확인. 현재 시스템 AppleLanguages = ko-KR 우선 → ko.lproj 선택으로 "모두의 웹툰" 표시 예상. plutil 문법 검증 OK. Dock/Finder 반영은 Dock 캐시로 인해 지연될 수 있어 사용자 확인 안내.