# Desktop App Harness

데스크톱 애플리케이션(설계→구현→멀티 OS 검증→패키징·배포)을 에이전트 팀이
협업하여 개발하는 하네스. **스택 무관(stack-agnostic)** — 특정 프레임워크를
전제하지 않는다. 프로젝트 시작 시 아래 어댑터 표에서 스택을 확정하고,
확정 즉시 이 차터를 보강한다.

## 구조

```
.claude/agents/
├── architect.md           — 스택 선정, 프로세스 모델, IPC, 로컬 저장 설계
├── desktop-dev.md         — 구현 (UI 프레임워크 관례, 네이티브 브리지, 크로스플랫폼 경계)
├── qa.md                  — 멀티 OS 매트릭스, 설치 수명주기, DPI/다국어/오프라인 검증
└── release-engineer.md    — 패키징, 코드사이닝, 자동업데이트, 스토어 배포
```

## 스택 어댑터

| 스택 | 언어 | 빌드 도구 | 패키징 | 적합 시나리오 |
|---|---|---|---|---|
| Electron | JS/TS | electron-builder / Forge | NSIS·MSI / DMG / AppImage 내장 지원 | 웹 기술 재사용으로 빠른 크로스플랫폼 출시 |
| .NET (WPF·WinUI) | C# + XAML | dotnet CLI / MSBuild | MSIX / MSI(WiX) | Windows 전용, 엔터프라이즈·사내 도구 |
| Tauri | Rust + 웹 프론트 | cargo + tauri-cli | MSI·NSIS / DMG / AppImage·deb 내장 번들러 | 작은 바이너리·낮은 메모리로 웹 UI 유지 |
| Qt | C++ / Python(PySide) | CMake / qmake | windeployqt·macdeployqt + 별도 인스톨러 | 고성능 네이티브 UI, 산업·임베디드 연계 |
| Flutter-desktop | Dart | flutter CLI | msix / DMG / snap 등 별도 도구 | 모바일 코드베이스를 데스크톱과 공유 |

## 스택 확정 시 차터 보강

스택이 정해지면 architect 산출물을 기반으로 이 파일에 다음을 추가한다:

1. **확정 스택** 섹션 (스택 어댑터 표 바로 아래) — 선택 스택·버전·선정 사유·탈락 후보 요약.
2. **프로세스 모델 규칙** — 프로세스/스레드 경계와 IPC 채널 목록을 계약으로 명시.
3. **빌드·패키징 명령** — 로컬 개발 실행 / 릴리스 빌드 / 서명 포함 빌드 각 1줄.
4. **로컬 데이터 규약** — 저장 경로(OS 규약)·포맷·스키마 마이그레이션 방법.

각 역할 파일(`agents/*.md`)에도 확정 스택 전용 관례를 1-2줄씩 추가한다
(예: desktop-dev 에 상태관리 패턴, release-engineer 에 서명 도구 명령).

## 데스크톱 고유 관심사

- **인스톨러**: Windows(MSI/NSIS), macOS(DMG), Linux(AppImage/deb) — 대상 OS별 최소 1개 포맷 확정.
- **코드사이닝**: Windows Authenticode, macOS Developer ID + notarization. 미서명 배포는 SmartScreen/Gatekeeper 경고를 유발한다.
- **자동업데이트**: 채널 분리(stable/beta), 업데이트 산출물 서명 검증, 실패 시 롤백 경로.
- **멀티 OS 매트릭스**: 지원 OS·버전 범위를 설계 단계에 확정하고 CI 빌드·테스트 매트릭스에 반영.
- **오프라인-퍼스트/로컬 데이터**: 네트워크 없이 핵심 기능이 동작하는 것이 기본. 로컬 저장 위치는 OS 규약 경로(AppData / Application Support / XDG)를 따른다.
- **OS 네이티브 통합**: 트레이, 알림, 파일 연결·프로토콜 핸들러, 자동 시작 — 필요한 것만 명시적으로 도입.
- **성능**: 콜드 스타트 시간·메모리 풋프린트 목표 수치를 정하고 릴리스마다 측정.

## 사용 방식

1. **architect** 로 시작: 스택 선정 + 설계를 `_workspace/01_architecture.md` 로 정리
2. **desktop-dev** 가 구현: 설계 문서 기반, 작은 단위로 커밋
3. **qa** 가 검증: OS 매트릭스 + 설치/업그레이드/제거 + 환경 변형(DPI·다국어·오프라인)
4. **release-engineer** 가 배포: 패키징 → 서명 → 업데이트 채널 → (선택) 스토어 제출
