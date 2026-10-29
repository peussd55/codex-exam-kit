# codex-exam-kit

시간제한이 있는 1인 AI 코딩 과제(OpenAI Codex CLI 사용)를 위한 개인 작업 키트입니다.
2026년 AI 해커톤 2차 예선 응시를 앞두고, 그동안 AI 코딩 에이전트와 일하며 효과를 본 작업 방식을 범용 틀로 정리했습니다.

- 특정 과제의 문제나 풀이는 들어 있지 않습니다. 과제 내용은 시험 전에 알 수 없습니다.
- 들어 있는 것은 작업 규칙, 계획 문서 뼈대, 검사 스크립트, 요청 문구입니다.
- 결과물 코드를 대신 만들어 주는 것은 없습니다.

## 구성

| 경로 | 내용 | 작업 폴더로 복사 |
|---|---|---|
| `template/AGENTS.md` | Codex 작업 규칙과 약속어(이어서 · 정리 · 리뷰) | 예 |
| `template/PLAN.md` | 계획 문서 뼈대: 목표·범위 밖·완료 조건 / 요구사항(출처 태그) / 설계 / 용어집 / Progress / Decision Log / 발견 / 알려진 약점 / Outcomes | 예 |
| `template/scripts/check.sh` | 완료 조건 검사: 테스트 자동 감지, 선택 스모크, 비밀값·줄바꿈 위생 | 예 |
| `template/scripts/status.sh` | 세션 시작 요약: PLAN ▶ 줄, 요구사항 진척, 마지막 결정, 최근 발견, git 상태, 마지막 check | 예 |
| `template/.gitignore` | 의존성·빌드·비밀 파일 제외 | 예 |
| `install.sh` | template/을 현재 폴더에 복사(있는 파일은 덮어쓰지 않음) | — |
| `prompts.md` | 단계별 요청 문구 | 아니오 (키트 폴더에서 `cat`) |
| `playbook.md` | 180분 흐름과 규칙 한 장 | 아니오 |

## 사용

```bash
git clone --depth 1 --branch exam-1031 https://github.com/<계정>/codex-exam-kit ~/kit
cd <작업 폴더>
bash ~/kit/install.sh
# 안내대로 커밋하고 시작 상태에 태그
git add -A && git commit -m "chore: 작업 키트 추가" && git tag r0
```

- 태그: 시험에 쓰는 판은 `exam-1031` 태그로 고정합니다. 이후 이 태그는 옮기지 않습니다.
- 키트는 작업 폴더 **바깥**에 받고 필요한 파일만 복사합니다. 작업 폴더의 git 이력에 키트 저장소가 섞이지 않게 하려는 것입니다. 작업 폴더가 홈(`~`) 자체라면 `~/kit` 대신 `/tmp/kit`에 받습니다.
- git clone이 막히면 압축 파일로 받습니다:
  `mkdir -p ~/kit && curl -fsSL https://github.com/<계정>/codex-exam-kit/archive/refs/tags/exam-1031.tar.gz | tar xz -C ~/kit --strip-components=1`
- `install.sh`는 없는 파일만 복사합니다. 이미 있는 AGENTS.md에는 키트 규칙을 구분선 아래에 덧붙이고(과제 지침이 우선), 이미 있는 .gitignore에는 빠진 줄만 덧붙입니다. 그 밖의 기존 파일은 건드리지 않습니다. git 커밋, 원격 저장소, Codex 설정(`~/.codex`)도 건드리지 않습니다.

## 작업 방식 요약

- **기록은 PLAN.md 한 곳**: 현재 상태(▶ 줄·요구사항·설계)는 최신으로 고치고, 이력(Progress·Decision Log·발견)은 덧붙이기만 합니다. 다른 곳에서는 R1·D-1 같은 번호로만 가리키고 다시 풀어 쓰지 않습니다. 세션이 바뀔 때마다 다른 말로 옮겨 적으면 뜻이 조금씩 흘러가기 때문입니다.
- **발견은 따로**: 환경의 함정과 실패한 시도는 발견 절에 근거와 함께 모읍니다. 새 세션이 `status.sh`로 바로 보고 같은 실수를 하지 않습니다.
- **쓰기는 메인 Codex 하나**: 보조 Codex는 읽기 전용(`--sandbox read-only`)으로 질의와 리뷰만 합니다.
- **다음 단계 판정은 테스트**: `./scripts/check.sh`가 CHECK PASS여야 넘어갑니다. 리뷰 지적은 사람이 골라 반영하고 이유를 남깁니다.
- **세션은 작업 덩어리마다**: 끝낼 때 "정리", 새 세션에서 "이어서". 새 세션이 PLAN.md만 보고 이어갈 수 있어야 합니다.
- **범위 통제**: 요청하지 않은 기능·리팩토링·방어 코드는 만들지 않고, 요구사항에 없는 판단은 [가정]으로 남깁니다.

## 참고한 공개 자료

- OpenAI Codex 문서: AGENTS.md, 승인·샌드박스, 모범 사례, ExecPlan
- Anthropic 엔지니어링 블로그: 장시간 에이전트 하네스, 하네스 설계
- Cognition 블로그: 멀티에이전트 작업 방식
