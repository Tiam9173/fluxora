<div align="center">

<img src="../assets/images/fluxora_mark.svg" alt="Fluxora" width="104" height="104">

# Fluxora 流序

**Make routing legible. — 명확한 라우팅, 차분한 제어.**

오픈소스·크로스플랫폼 Mihomo 네트워크 라우팅 클라이언트.
설정·연결·규칙·트래픽 상태를 절제된, 명확하고 감사 가능한 하나의 화면에 담았습니다.

[![License](https://img.shields.io/badge/license-GPL--3.0-29D6C7?style=flat-square)](../LICENSE)
[![Platforms](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Android-4C8DFF?style=flat-square)](#지원-플랫폼)
[![Stars](https://img.shields.io/github/stars/Tiam9173/fluxora?style=flat-square&color=7C75FF&label=stars)](https://github.com/Tiam9173/fluxora/stargazers)

<!-- 문서 언어 -->

[![简体中文](https://img.shields.io/badge/简体中文-29D6C7?style=flat-square)](../README.md)
[![English](https://img.shields.io/badge/English-4C8DFF?style=flat-square)](../README_en.md)

**[다운로드](#다운로드)** · **[문제 신고](https://github.com/Tiam9173/fluxora/issues)** · **[기여하기](#기여하기)** · **[라이선스](../LICENSE)**

📢 **[Telegram 채널](https://t.me/Fluxora_Channel)** · 💬 **[Telegram 그룹](https://t.me/Fluxora_Group1)**

</div>

---

## 공식 커뮤니티

- 📢 **[Telegram 채널](https://t.me/Fluxora_Channel)** — 업데이트, 릴리스, 프로젝트 소식
- 💬 **[Telegram 그룹](https://t.me/Fluxora_Group1)** — 토론, 질문, 피드백

## 왜 Fluxora 인가

대부분의 프록시 클라이언트는 "연결되면 끝"으로 보고, 규칙·로그·연결 상태를 깊은 하위 메뉴에 밀어 넣습니다. Fluxora 는 반대로 합니다. **먼저 상태를 보이게 하고, 그다음에 조작에 손이 닿게 합니다.**

Mihomo(Clash Meta) 코어 위에 Flutter 로 구축했고, 데스크톱과 모바일에서 동일한 정보 구조를 제공합니다 — 대시보드, 프록시, 설정, 도구, 로그, 요청, 리소스, 스크립트, 연결. 아홉 개 페이지가 각자의 역할을 가지며, 쌓아 올리지도 숨기지도 않습니다.

설계 원칙은 세 가지입니다. **절제**(장식적 모션이나 네온 광효 없음), **명확**(상태는 항상 조작보다 눈에 띔), **감사 가능**(오픈소스, 내장 계정 없음, 선언되지 않은 클로즈드소스 의존성 없음).

## 핵심 강점

- **현대적 인터페이스** — Material 3 와 통일된 디자인 토큰(색상·글자·여백·모서리·모션). 상위 UI 를 단순히 다시 쓴 것이 아닙니다.
- **플랫폼 일관성** — Windows·macOS·Linux·Android 가 하나의 Flutter 코드베이스와 정보 구조를 공유합니다.
- **완전한 프록시 제어** — 규칙 / 글로벌 / 다이렉트 출구 모드, 그룹 선택, 지연 측정, 체인 프록시와 주거용 랜딩.
- **네트워크 인수** — TUN 가상 어댑터와 시스템 프록시, 데스크톱에서는 상주 트레이와 전역 단축키.
- **테마와 머티리얼** — 라이트 / 다크 / 시스템 따르기, 퓨어 블랙, 네 가지 머티리얼(클래식 / 프로스트 글래스 / 리퀴드 글래스 / 경량)과 "옵시디언" 테마. 시스템 색상 추출과 사용자 지정 액센트를 지원합니다.
- **오픈소스·감사 가능** — GPL-3.0. 코어, 스크립트 엔진, 의존성을 모두 확인할 수 있고 클라우드 계정 체계가 없습니다.

## 기능

### 연결

- 시스템 프록시(데스크톱)
- TUN 가상 어댑터(스택 유형과 라우팅 모드 포함)
- 출구 모드: 규칙 / 글로벌 / 다이렉트
- 연결 목록과 실시간 트래픽, 연결 종료
- 스마트 자동 정지: 지정한 네트워크에 연결되면 프록시 서비스 중지

### 노드

- 프록시 그룹: select / url-test / fallback / load-balance
- 지연 측정과 노드 전환
- 수동 전환은 한 번만 적용되며 영구 고정으로 저장되지 않습니다. url-test 그룹은 실측 최저 지연 노드로 돌아갑니다

### 체인 프록시

- 진입 홉 + 고정 주거용 IP 의 2단 릴레이. 진입 → 랜딩 순서로 전달
- 체인 프록시 전용 그룹 카드(🔗 체인 프록시)를 생성해 일반 그룹과 나란히 관리
- 홉별 노드 선택과 상태(진입 / 랜딩), 홉 단위 지연 측정과 진단
- 라우트 토폴로지 미리보기: 각 홉의 도달성과 지연을 한눈에 확인
- 구독별로 켤 수 있고, 명시적 다중 진입 체인도 지원합니다

### Cloudflare WARP

- WARP 출구를 내장하고 전용 "🛡️ WARP 출구" 그룹을 생성. 어떤 프록시 그룹과도 조합 가능
- Cloudflare 계정 원클릭 등록, WARP+ 라이선스 키 연결 지원
- 엔드포인트 / 포트, 클린 IP, MTU, UDP 스위치, 원격 DNS 해석 설정 가능
- 라우팅 모드를 선택할 수 있고 상위 다이얼러(default dialer proxy)도 지정 가능

> 연결 가능 여부는 노드, 네트워크 환경, Cloudflare 서비스 상태에 따라 달라집니다.

### 설정

- 다중 프로파일 관리(로컬 파일 / 구독 링크)
- 프로파일 가져오기와 업데이트, 규칙 프로바이더
- 다중 구독 집계
- JavaScript 로 규칙과 설정 처리

### 도구

- 네트워크 점검, 내부 IP, 미디어 차단 해제 판정
- DNS·Sniffer·NTP 덮어쓰기
- IPv6 스위치, 메모리 사용량, 트래픽 통계
- 로그, 요청 기록, 연결 진단
- 선택적 IP 위험 정보(기본값 꺼짐)

### 인터페이스와 개인화

- 홈 컴포넌트를 추가·정렬·삭제할 수 있고, 연결 주 조작은 항상 남습니다
- 데스크톱 사이드바는 208px 라벨형과 68px 아이콘형을 전환. 모바일은 플로팅 내비게이션
- 라이트 / 다크 / 시스템 따르기, 퓨어 블랙(OLED)
- 네 가지 머티리얼과 "옵시디언" 테마. 렌즈 강도와 투명도는 따로 조정 가능
- 세 가지 색상 소스: 브랜드 팔레트, 시스템 색상(Android Material You), 사용자 지정 액센트
- 모션은 실제 상태에 연결되고 시스템의 "애니메이션 줄이기" 설정을 존중합니다
- 데스크톱 트레이, 전역 단축키, 로그인 시 자동 실행

### 브랜드 아이콘

여덟 가지 스타일이 있고 각각 다크용과 라이트용이 따로 있습니다: 오피셜, 클래식, 아쿠아, 프리미엄, 스피드, 스카이, 선셋, 블루 나이트.
**설정 → 테마 → 앱 아이콘** 에서 선택합니다. 아이콘 색상과 페이지 테마는 각각 설정합니다.

![Fluxora 아이콘 목록](../design/brand_icons/preview.png)

## 스크린샷

## 지원 플랫폼

| 플랫폼 | 상태 |
|---|---|
| Windows 10 / 11 | 지원 |
| macOS 12+ | 지원 |
| Linux | 지원 |
| Android 8.0+ | 지원 |
| iOS | 공식 클라이언트 없음 |

## 다운로드

패키지는 **[GitHub Releases](https://github.com/Tiam9173/fluxora/releases)** 에 `Fluxora-<version>-<platform>` 형식으로 배포됩니다.

현재 정식 버전은 **[v1.1.1](https://github.com/Tiam9173/fluxora/releases/tag/v1.1.1)** 입니다. `dev` 브랜치의 **1.1.2-rc.2 미리보기는 배포 보류 중** 이며, 소스의 버전 표기가 패키지가 이미 배포되었다는 뜻은 아닙니다. 실제 상태와 다운로드는 Releases 를 확인하세요.

| 플랫폼 | 제공 형식 | 아키텍처 |
|---|---|---|
| Windows 10 / 11 | `setup.exe` 설치 프로그램 · `portable.zip` 포터블 | amd64 · amd64-compatible · arm64 |
| macOS 12+ | `.dmg` | arm64 · amd64 · amd64-compatible |
| Linux | `.AppImage` · `.deb` · `.rpm` | amd64 · amd64-compatible(세 형식) · arm64(deb) |
| Android 8.0+ | `.apk` | arm64-v8a · armeabi-v7a · x86_64 · universal |
| iOS | 공식 클라이언트 없음 | — |

> `-compatible` 는 구형 CPU 와 시스템(새 명령어 집합이 없는 기기)을 위한 것입니다. 일반 기기에서는 표준 빌드를 선택하세요. 이 표는 각 플랫폼이 지원하는 형식을 뜻하며, 모든 후보 빌드가 전 형식을 산출했다는 의미는 아닙니다.

## 설치

### Windows

`setup.exe` 설치 프로그램을 사용하거나 `*-windows-amd64-portable.zip` 을 풀고 `Fluxora.exe` 를 바로 실행합니다.

### Android

Releases 에서 기기 아키텍처에 맞는 APK 를 받아 사이드로드로 설치합니다.

### Linux

배포판에 맞춰 `.AppImage` / `.deb` / `.rpm` 을 선택하세요.

### macOS

아키텍처에 맞는 DMG 를 받아 엽니다.

## 사용과 개인정보

1. "설정"에서 자신의 구독 또는 로컬 설정을 가져오고 사용할 것을 선택합니다.
2. "프록시"에서 노드를 고르고 연결을 시작합니다. Fluxora 는 구독이나 프록시 서버를 제공하지 않습니다.
3. TUN 과 시스템 프록시는 플랫폼과 권한에 따라 동작합니다. 시스템 프록시는 그 설정을 따르는 앱에만 영향을 줍니다.

구독 업데이트, 지연 측정, 출구 IP / 차단 해제 판정, WARP 등록은 해당 서비스에 접속합니다. IP 위험 정보는 기본적으로 꺼져 있고, 켜서 조회하면 대상 IP 가 정보 제공자에게 전송됩니다. **"Fluxora 클라우드 계정이 없다"를 "제3자 통신이 없다"로 읽지 마세요.** 설정·로그·진단을 공유하기 전에 구독 주소, 키, 개인정보를 제거하세요.

## FAQ

### Fluxora 는 무엇인가요?

Mihomo(Clash Meta) 코어 위에 Flutter 로 구축한 오픈소스·크로스플랫폼 라우팅 클라이언트입니다.

### 어떤 플랫폼을 지원하나요?

Windows, macOS, Linux, Android 입니다. iOS 공식 클라이언트는 없고 현재 계획에도 없습니다.

### 오픈소스인가요? 라이선스는?

예, **GPL-3.0** 입니다. 전문은 [LICENSE](../LICENSE) 를 참고하세요.

### 설정은 어떻게 가져오나요?

"설정" 페이지에서 구독 링크를 추가하거나 로컬 파일을 가져온 뒤 선택하면 연결됩니다. `fluxora://install-config` 링크로 바로 가져올 수도 있습니다.

### TUN 과 시스템 프록시의 차이는?

시스템 프록시는 시스템 프록시 설정을 따르는 앱에만 영향을 줍니다. TUN 은 가상 어댑터로 더 낮은 계층에서 트래픽을 인수하므로 적용 범위가 넓고 보통 관리자 권한이 필요합니다. 데스크톱에서는 둘을 따로 켜고 끌 수 있습니다.

### iOS 버전이 없는 이유는?

iOS 는 별도의 Network Extension 구현과 개발자 서명 배포가 필요합니다. 현재 계획에 포함되어 있지 않습니다.

### 데이터를 수집하나요?

아니요. Fluxora 는 클라우드 계정 서비스도, 내장 통계 전송도 없습니다. 다만 구독 업데이트, 지연 측정, IP 와 차단 해제 판정 등은 사용자의 설정에 따라 해당 제3자 서비스에 접속합니다.

## 개발

**필요 환경**: Flutter(Dart 포함), Android SDK/NDK 와 JDK, 각 플랫폼 툴체인(Windows 는 Visual Studio Build Tools, macOS 는 Xcode, Linux 는 GTK 개발 라이브러리). 코어와 Helper 는 Go / Rust 컴포넌트이며 각각의 툴체인이 필요합니다.

```bash
git clone https://github.com/Tiam9173/fluxora.git
cd fluxora
flutter pub get
dart run build_runner build -d
flutter analyze
flutter test
flutter run            # 또는 flutter build windows --release
```

## 기여하기

Issue, 문서 개선, 수정, 코드 모두 환영합니다:

- **버그 신고 / 기능 제안** → [Issues](https://github.com/Tiam9173/fluxora/issues) (플랫폼, 버전, 재현 절차, 개인정보를 제거한 로그를 함께)
- **코드** → [Pull Requests](https://github.com/Tiam9173/fluxora/pulls)

제출 전에 선언되지 않은 클로즈드소스 의존성을 추가하지 않았는지, GPL 이나 제3자 라이선스 표기를 삭제하지 않았는지 확인하세요.

## 라이선스와 계보

Fluxora is distributed under the GNU General Public License v3.0. See [LICENSE](../LICENSE).

Fluxora includes and interoperates with open-source components, including the [Mihomo](https://github.com/MetaCubeX/mihomo) core and other Flutter, Go, Rust, and platform libraries. Their applicable copyright notices and licenses remain in their respective source directories and distribution metadata. See [NOTICE](../NOTICE) and the relevant component license files.

Fluxora is based on development of [Bettbox](https://github.com/appshubcc/Bettbox) project. Project lineage: **FlClash → Bettbox → Fluxora**. Fluxora's branding, UI, design system and Windows components were developed independently on that base, starting 2026-09-25. See [NOTICE](../NOTICE) for the full attribution record.

Fluxora is an independent product identity. This repository does not present itself as an official product of any upstream project.
