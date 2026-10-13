<div align="center">

<img src="../assets/images/fluxora_mark.svg" alt="Fluxora" width="104" height="104">

# Fluxora 流序

**Make routing legible. — 명확한 라우팅, 차분한 제어.**

오픈소스·크로스플랫폼 Mihomo 네트워크 라우팅 클라이언트.
설정·연결·규칙·트래픽 상태를 절제된, 명확하고 감사 가능한 하나의 화면에 담았습니다.

[![License](https://img.shields.io/badge/license-GPL--3.0-29D6C7?style=flat-square)](../LICENSE)
[![Platforms](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Android-4C8DFF?style=flat-square)](#지원-플랫폼)
[![Stars](https://img.shields.io/github/stars/Tiam9173/fluxora?style=flat-square&color=7C75FF&label=stars)](https://github.com/Tiam9173/fluxora/stargazers)

<!-- 문서 언어 / Documentation language -->

[![简体中文](https://img.shields.io/badge/简体中文-29D6C7?style=flat-square)](../README.md)
[![English](https://img.shields.io/badge/English-4C8DFF?style=flat-square)](../README_en.md)
[![日本語](https://img.shields.io/badge/日本語-7C75FF?style=flat-square)](README_ja.md)
[![한국어](https://img.shields.io/badge/한국어-현재-FF6B9D?style=flat-square)](README_ko.md)
[![Русский](https://img.shields.io/badge/Русский-FFB020?style=flat-square)](README_ru.md)
[![فارسی](https://img.shields.io/badge/فارسی-56C1FF?style=flat-square)](README_fa.md)

**[다운로드](#다운로드)** · **[문제 신고](https://github.com/Tiam9173/fluxora/issues)** · **[기여하기](#기여하기)** · **[라이선스](../LICENSE)**

📢 **[공식 Telegram 채널](https://t.me/Fluxora_Chanel)** · 💬 **[공식 Telegram 그룹](https://t.me/Fluxora_Grup)**

</div>

---

## 공식 커뮤니티

- 📢 **[공식 Telegram 채널](https://t.me/Fluxora_Chanel)** —— Fluxora 업데이트, 릴리스 소식, 프로젝트 동향을 전합니다
- 💬 **[공식 Telegram 그룹](https://t.me/Fluxora_Grup)** —— 커뮤니티 토론, 문제 신고, 사용 경험 공유

## 왜 Fluxora인가

대부분의 프록시 클라이언트는 "연결됨"을 종착점으로 삼고 규칙, 로그, 연결 상태를 여러 겹의 하위 메뉴 속에 쌓아 둡니다. Fluxora는 반대로 합니다. **먼저 상태를 보이게 하고, 그다음에 조작에 손이 닿게 합니다.**

Mihomo(Clash Meta) 코어를 기반으로 Flutter로 제작되었으며, 데스크톱과 모바일에서 동일한 정보 구조를 제공합니다——대시보드, 프록시, 설정, 도구, 로그, 요청, 리소스, 스크립트, 연결이라는 아홉 개의 페이지가 각자의 역할을 다하며, 채워 넣지도 숨기지도 않습니다.

설계는 세 가지 원칙을 따릅니다. **절제**(장식적인 애니메이션과 네온 효과를 넣지 않음), **명확**(상태는 언제나 조작보다 눈에 띔), **감사 가능**(오픈소스, 계정 체계 없음, 선언되지 않은 클로즈드소스 의존성을 도입하지 않음).

Fluxora는 독립적인 제품이며 어떤 업스트림 프로젝트와도 공식적인 관계가 없습니다. 그 유래와 라이선스 의무는 [NOTICE](../NOTICE)에 완전히 기록되어 있습니다.

## 핵심 장점

- **현대적인 인터페이스** — Material 3 설계 체계와 통일된 디자인 토큰(색상 / 글자 크기 / 여백 / 모서리 / 모션). 업스트림 UI를 단순히 고쳐 쓴 것이 아닙니다.
- **플랫폼 전반의 일관성** — Windows, macOS, Linux, Android가 동일한 Flutter 코드와 정보 구조를 공유합니다.
- **완전한 프록시 제어** — 규칙 / 전역 / 직접 세 가지 아웃바운드 모드, 프록시 그룹 선택, 지연 측정, 체인 프록시와 프런트·랜딩 중계.
- **네트워크 인계** — TUN 가상 NIC와 시스템 프록시, 데스크톱 상주 트레이와 전역 단축키.
- **테마 시스템** — 라이트 / 다크 / 시스템 연동, 순수 검정 모드, 7종 브랜드 프리셋 배색, Android는 Material You 동적 색상 지원.
- **오픈소스·감사 가능** — GPL-3.0. 코어, 스크립트 엔진, 의존성 전체를 확인할 수 있으며 클라우드 계정 체계가 없습니다.

## 기능

### 연결
- 시스템 프록시(데스크톱)
- TUN 가상 NIC(스택 유형 및 라우팅 모드 선택 포함)
- 아웃바운드 모드: 규칙 / 전역 / 직접
- 연결 목록과 실시간 트래픽, 연결 종료
- 스마트 시작/정지: 지정한 네트워크에 연결되면 프록시 서비스를 자동으로 중지

### 노드
- 프록시 그룹: 선택 / 자동 속도 측정 / 장애 조치 / 부하 분산
- 지연 측정과 노드 전환
- 체인 프록시(프런트 / 랜딩 중계)

### 설정
- 다중 프로필 관리(로컬 파일 / 구독 링크)
- 프로필 가져오기와 업데이트, 규칙 리소스(rule providers)

### 도구
- 네트워크 점검, 내부 IP, 미디어 차단 해제 확인
- DNS 재정의, Sniffer 재정의, NTP 재정의
- IPv6 스위치, 메모리 사용량, 트래픽 통계
- 로그, 요청 기록, 연결 진단
- JavaScript 스크립트(규칙과 설정 처리)

### 개인 설정
- 라이트 / 다크 / 시스템 연동
- 순수 검정 모드(OLED)
- 7종 브랜드 프리셋 배색 + 사용자 지정 기본 색상
- Android Material You 동적 색상
- 데스크톱 트레이, 전역 단축키, 자동 시작

## 제품 화면

![Fluxora 홈](../snapshots/fluxora-home.png)

## 지원 플랫폼

| 플랫폼 | 상태 |
|---|---|
| Windows 10 / 11 | 지원 |
| macOS 12+ | 지원 |
| Linux | 지원 |
| Android 8.0+ | 지원 |
| iOS | 공식 클라이언트 없음 |

## 다운로드

정식 버전이 곧 공개될 예정입니다. 공개 후 설치 패키지는 **[GitHub Releases](https://github.com/Tiam9173/fluxora/releases)** 에 모여 있으며, 이름 규칙은 `Fluxora-<version>-<platform>` 입니다.

현재 이 저장소에는 **정식 Release가 아직 없습니다**. 따라서 아래에 바로 클릭할 수 있는 설치 파일 링크는 없습니다——공개된 뒤 Releases 페이지에서 받아 주세요.

## 설치

### Windows
1. Releases에서 Windows 포터블 패키지(`*-windows-amd64-portable.zip`)를 내려받습니다.
2. 원하는 디렉터리에 압축을 풉니다(설치 불필요).
3. `Fluxora.exe`를 실행합니다.

> 설치 프로그램(`.exe` 설치 마법사)은 준비 중입니다. 현재는 포터블 패키지를 사용해 주세요.

### Android
Releases에서 아키텍처에 맞는 APK를 내려받아 사이드로드로 설치하거나, 앱 스토어 버전을 기다려 주세요.

### Linux
Releases에서 AppImage / deb / rpm을 내려받습니다(공개 내용에 따라 다릅니다).

### macOS
Releases에서 아키텍처에 맞는 DMG를 내려받습니다.

> Linux와 macOS의 정식 설치 패키지는 아직 빌드되지 않았습니다. Releases 페이지의 실제 내용을 확인해 주세요.

## FAQ

### Fluxora는 무엇인가요?
Mihomo(Clash Meta) 코어를 기반으로 Flutter로 제작된 오픈소스·크로스플랫폼 네트워크 라우팅 클라이언트입니다.

### 어떤 플랫폼을 지원하나요?
Windows, macOS, Linux, Android입니다. iOS는 현재 공식 클라이언트가 없으며 현재 계획에도 포함되어 있지 않습니다.

### Fluxora와 업스트림 프로젝트의 관계는?
Fluxora는 **독립적인 제품**이며 어떤 업스트림 프로젝트의 공식 릴리스도 아닙니다. Bettbox 프로젝트의 독립적인 연속 버전으로, 그 위에 브랜드, UI, 설계 체계, Windows 구성 요소를 독자적으로 개발했습니다. 전체 유래와 라이선스 의무는 [NOTICE](../NOTICE)를 참고하세요.

### 오픈소스인가요? 어떤 라이선스인가요?
오픈소스이며 **GPL-3.0**을 사용합니다. 전문은 [LICENSE](../LICENSE)를 참고하세요.

### 설정은 어떻게 가져오나요?
「설정」 페이지에서 구독 링크를 추가하거나 로컬 설정 파일을 가져온 뒤 선택하면 연결됩니다. `fluxora://install-config` 링크로 바로 가져오는 것도 지원합니다.

### TUN과 시스템 프록시의 차이는?
시스템 프록시는 시스템 프록시 설정을 따르는 앱에만 영향을 줍니다. TUN은 가상 NIC를 통해 더 낮은 계층에서 트래픽을 인계하므로 적용 범위가 넓고 보통 관리자 권한이 필요합니다. 데스크톱에서는 둘을 각각 켜고 끌 수 있습니다.

### 일부 플랫폼에 설치 패키지가 없는 이유는?
플랫폼별 배포 패키지는 각각의 빌드 환경이 필요합니다(Linux는 GTK 툴체인, macOS는 Xcode 서명과 공증). 첫 정식 릴리스에 맞춰 순차적으로 갖춰집니다.

### 제 데이터가 수집되나요?
아니요. Fluxora는 클라우드 계정 서비스를 제공하지 않으며 통계 전송도 내장되어 있지 않습니다. 구독, 규칙, 네트워크 요청은 전적으로 사용자가 선택한 설정에 따릅니다.

## 개발

**사전 요구 사항**: Flutter(Dart 포함), Android SDK/NDK와 JDK, 대상 플랫폼의 빌드 도구(Windows는 Visual Studio Build Tools, macOS는 Xcode, Linux는 GTK 개발 라이브러리). 프록시 코어와 Helper는 Go / Rust 구성 요소이므로 해당 툴체인이 필요합니다.

```bash
git clone https://github.com/Tiam9173/fluxora.git
cd fluxora
flutter pub get
dart run build_runner build -d
flutter run            # 또는 flutter build windows --release
```

## 기여하기

Issue 제출, 문서 개선, 문제 수정, 코드 기여를 환영합니다:

- **버그 신고 / 기능 제안** → [Issues](https://github.com/Tiam9173/fluxora/issues)
- **코드 기여** → [Pull Requests](https://github.com/Tiam9173/fluxora/pulls)

변경 사항을 제출하기 전에 선언되지 않은 클로즈드소스 의존성을 도입하지 않는지, GPL 또는 제3자 라이선스 표시를 삭제하지 않는지 확인해 주세요.

## 라이선스와 프로젝트 계보

Fluxora is distributed under the GNU General Public License v3.0. See [LICENSE](../LICENSE).

Fluxora includes and interoperates with open-source components, including the [Mihomo](https://github.com/MetaCubeX/mihomo) core and other Flutter, Go, Rust, and platform libraries. Their applicable copyright notices and licenses remain in their respective source directories and distribution metadata. See [NOTICE](../NOTICE) and the relevant component license files.

Fluxora is an independent continuation of the [Bettbox](https://github.com/appshubcc/Bettbox) project. Project lineage: **FlClash → Bettbox → Fluxora**. Fluxora's branding, UI, design system and Windows components were developed independently on that base, starting 2026-09-25. See [NOTICE](../NOTICE) for the full attribution record.

Fluxora is an independent product identity. This repository does not present itself as an official product of any upstream project.
