#!/usr/bin/env bash
# 키트 템플릿(template/)을 현재 폴더(= 과제 작업 폴더)에 복사한다.
# - 작업 폴더 = 과제 README가 있는 폴더 (본시험은 홈 /home/user)
# - 없는 파일만 복사한다. 이미 있는 파일은 덮어쓰지 않는다 (스타터 코드 보호)
# - 예외: 이미 있는 AGENTS.md에는 키트 규칙을 구분선 아래에 덧붙이고, 이미 있는 .gitignore에는 빠진 줄만 덧붙인다
# - 작업 폴더가 홈이면 .gitignore에 "홈의 숨김 파일·폴더 제외" 줄을 덧붙인다 (~/.codex 로그인 정보가 커밋에 섞이지 않게)
# - 사람용 문서(playbook·prompts)는 .kit/에 복사한다 (에디터로 열어 두기 · .gitignore 대상)
# - git 커밋·태그는 하지 않는다 → 메인 Codex에서 "시작"이 한다 (사람이 git을 칠 필요가 없게)
# - ~/.codex 등 Codex 설정은 건드리지 않는다
# - 다시 실행해도 된다 (덧붙인 줄·규칙을 또 덧붙이지 않는다)
#
# 사용 (bash로 실행 · 키트는 작업 저장소 바깥에 받는다):
#   git clone -b exam-retake https://github.com/<계정>/codex-exam-kit /tmp/kit
#   cd <작업 폴더> && bash /tmp/kit/install.sh
set -eo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$KIT_DIR/template"
DEST="$(pwd)"

if [ "$DEST" = "$KIT_DIR" ] || [ "${DEST#"$KIT_DIR"/}" != "$DEST" ]; then
  echo "키트 폴더 안에서 실행했어요. 작업 폴더로 이동한 뒤 다시 실행하세요: cd <작업 폴더> && bash $KIT_DIR/install.sh"
  exit 1
fi

# 키트가 작업 저장소 안에 있으면 제출물에 키트 저장소가 섞인다 (저장소 루트가 홈이면 ~/kit도 안쪽이다)
TOP="$(git -C "$DEST" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$TOP" ] && { [ "$KIT_DIR" = "$TOP" ] || [ "${KIT_DIR#"$TOP"/}" != "$KIT_DIR" ]; }; then
  echo "키트가 작업 저장소($TOP) 안에 있어요. 이대로면 제출물에 키트 저장소가 섞입니다."
  echo "저장소 바깥에 받은 뒤 다시 실행하세요: git clone -b exam-retake <키트 주소> /tmp/kit && bash /tmp/kit/install.sh"
  exit 1
fi

copied=0
merged=0
skipped=0
while IFS= read -r -d '' f; do
  rel="${f#"$SRC"/}"
  target="$DEST/$rel"
  if [ ! -e "$target" ]; then
    mkdir -p "$(dirname "$target")"
    cp "$f" "$target"
    case "$rel" in *.sh) chmod +x "$target" ;; esac
    echo "  복사함: $rel"
    copied=$((copied + 1))
  elif [ "$rel" = "AGENTS.md" ]; then
    # 키트판을 그대로 복사해 둔 AGENTS.md나 이미 덧붙인 AGENTS.md면 다시 덧붙이지 않는다
    if grep -q '^## 약속어' "$target" || grep -q '^## 작업 키트 규칙' "$target"; then
      echo "  건너뜀(이미 키트 규칙이 있음): AGENTS.md"
      skipped=$((skipped + 1))
    else
      {
        printf '\n\n---\n\n## 작업 키트 규칙 (위의 과제 지침과 부딪히면 위가 우선)\n\n'
        sed '1d' "$f"
      } >> "$target"
      echo "  덧붙임: AGENTS.md (기존 내용 아래에 키트 규칙)"
      merged=$((merged + 1))
    fi
  elif [ "$rel" = ".gitignore" ]; then
    added=0
    while IFS= read -r line; do
      case "$line" in ''|'#'*) continue ;; esac
      if ! grep -qxF "$line" "$target"; then
        if [ "$added" -eq 0 ]; then printf '\n# 작업 키트\n' >> "$target"; fi
        echo "$line" >> "$target"
        added=$((added + 1))
      fi
    done < "$f"
    if [ "$added" -gt 0 ]; then
      echo "  덧붙임: .gitignore (빠진 줄 ${added}개)"
      merged=$((merged + 1))
    else
      echo "  건너뜀(빠진 줄 없음): .gitignore"
      skipped=$((skipped + 1))
    fi
  else
    echo "  건너뜀(이미 있음): $rel  → 키트판: $f"
    skipped=$((skipped + 1))
  fi
done < <(find "$SRC" -type f -print0)

# 작업 폴더가 홈이면: 홈 바로 아래 숨김 파일·폴더(.codex .config .npm .bashrc .profile …)는 설정·캐시·로그인 정보다
# → 통째로 git에서 빼고 .gitignore·.env.example만 살린다 (경로 지정 커밋이 기본이지만 실수 대비)
HOME_REAL="$(cd "${HOME:-/nonexistent}" 2>/dev/null && pwd -P || true)"
DEST_REAL="$(pwd -P)"
at_home=0
if [ -n "$HOME_REAL" ] && [ "$DEST_REAL" = "$HOME_REAL" ]; then
  at_home=1
  home_added=0
  for line in '/.*' '!/.gitignore' '!/.env.example'; do
    if ! grep -qxF -- "$line" "$DEST/.gitignore" 2>/dev/null; then
      if [ "$home_added" -eq 0 ]; then printf '\n# 작업 키트: 작업 폴더가 홈 — 홈의 숨김 파일·폴더(설정·캐시·로그인 정보)는 제출물이 아니다\n' >> "$DEST/.gitignore"; fi
      printf '%s\n' "$line" >> "$DEST/.gitignore"
      home_added=$((home_added + 1))
    fi
  done
  if [ "$home_added" -gt 0 ]; then
    echo "  덧붙임: .gitignore (홈 숨김 파일 제외 ${home_added}줄 — ~/.codex 등이 커밋에 섞이지 않게)"
    merged=$((merged + 1))
  fi
fi

# 사람용 문서: 에디터(파일 탐색기 → .kit)로 열어 두도록 작업 폴더 안 .kit/에 복사 (.gitignore 대상 · 다시 실행하면 최신으로)
mkdir -p "$DEST/.kit"
cp "$KIT_DIR/playbook.md" "$KIT_DIR/prompts.md" "$DEST/.kit/"
echo "  복사함: .kit/playbook.md · .kit/prompts.md (사람용 · 제출물에 안 들어감)"

echo
echo "복사 ${copied}개 · 덧붙임 ${merged}개 · 건너뜀 ${skipped}개"

if git -C "$DEST" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "git 저장소: 있음 ($(git -C "$DEST" log --oneline -1 2>/dev/null || echo '커밋 없음'))"
else
  echo "git 저장소: 없음 — \"시작\"에서 Codex가 git init 여부를 물어봅니다"
fi
if [ "$at_home" -eq 1 ] || { [ -n "$TOP" ] && [ -n "$HOME_REAL" ] && [ "$TOP" = "$HOME_REAL" ]; }; then
  echo "주의: 저장소 루트가 홈이에요. git add . / -A는 홈 파일까지 담습니다 → 커밋은 Codex가 파일 경로로 합니다(키트 규칙)."
fi
if [ -z "$(find "$DEST" -maxdepth 1 -iname 'readme*' -print -quit 2>/dev/null)" ]; then
  echo "주의: 이 폴더에 README가 없어요. 과제 README가 있는 폴더(= codex를 띄울 폴더)에 설치해야 Codex가 AGENTS.md를 읽습니다."
fi
if [ -z "$(git -C "$DEST" config user.name 2>/dev/null)" ]; then
  echo "참고: git 사용자 이름이 비어 있어요 — 설정은 바꾸지 않고 Codex가 커밋할 때 -c 로 넣습니다."
fi
echo
echo "다음: T1에서 codex → 시작   (이미 떠 있던 codex는 /quit 후 다시 띄운다 — 키트 규칙은 띄울 때 읽힌다)"
echo "      승인 창은 명령을 읽고 'Yes, just this once'(이번만)만 — 'don't ask again …'·'allow … in the future'·'full access'는 고르지 않는다"
echo "      T2에서 codex --sandbox read-only --ask-for-approval never   (설명·리뷰·이해 확인, 쓰지 않는 창)"
echo "흐름 = 에디터로 .kit/playbook.md · 상황별 문구 = .kit/prompts.md   (안 열리면 less $KIT_DIR/playbook.md)"
