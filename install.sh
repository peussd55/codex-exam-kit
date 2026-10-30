#!/usr/bin/env bash
# 키트 템플릿(template/)을 현재 폴더(= 과제 작업 폴더)에 복사한다.
# - 없는 파일만 복사한다. 이미 있는 파일은 덮어쓰지 않는다 (스타터 코드 보호)
# - 예외 둘: 이미 있는 AGENTS.md에는 키트 규칙을 구분선 아래에 덧붙이고,
#   이미 있는 .gitignore에는 빠진 줄만 덧붙인다
# - git 저장소를 만들거나 커밋하지 않는다 (상태만 알려 준다)
# - ~/.codex 등 Codex 설정은 건드리지 않는다
#
# 사용 (bash로 실행):
#   git clone -b exam-1031 https://github.com/<계정>/codex-exam-kit /tmp/kit   ← 작업 저장소 바깥
#   cd <작업 폴더>                                                             ← 예: ~/uploads
#   bash /tmp/kit/install.sh
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
  echo "저장소 바깥에 받은 뒤 다시 실행하세요: git clone -b exam-1031 <키트 주소> /tmp/kit && bash /tmp/kit/install.sh"
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
    if grep -q '^## 작업 키트 규칙' "$target"; then
      echo "  건너뜀(이미 덧붙여 있음): AGENTS.md"
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
        [ "$added" -eq 0 ] && printf '\n# 작업 키트\n' >> "$target"
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

echo
echo "복사 ${copied}개 · 덧붙임 ${merged}개 · 건너뜀 ${skipped}개"

if git -C "$DEST" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "git 저장소: 있음 ($(git -C "$DEST" log --oneline -1 2>/dev/null || echo '커밋 없음'))"
  echo "  키트 파일을 커밋하고 시작 상태에 태그를 다세요:"
  echo "  git status -s -uall .   ← 키트 파일만 보이는지 확인"
  echo "  git add . && git commit -m \"chore: 작업 키트 추가\" && git tag r0"
else
  echo "git 저장소: 없음 → 아래를 실행하세요"
  echo "  git init"
  echo "  git config user.name \"이름\"; git config user.email \"메일\""
  echo "  git add . && git commit -m \"init: 과제 시작 상태 + 작업 키트\" && git tag r0"
fi
if [ -n "$TOP" ] && [ "$TOP" = "$HOME" ]; then
  echo "주의: 저장소 루트가 홈($HOME)이에요. git add -A는 ~/.codex(로그인 정보) 같은 홈 파일까지 담습니다 → 작업 폴더에서 git add . 만 쓰세요."
fi
if [ -z "$(git -C "$DEST" config user.name 2>/dev/null)" ]; then
  echo "주의: git user.name이 비어 있어요. 커밋 전에 설정하세요."
fi
echo "다음: 메인 Codex를 codex -c sandbox_workspace_write.network_access=true 로 실행하고 README부터 읽게 하세요. 문구 모음 = cat $KIT_DIR/prompts.md · 흐름 = cat $KIT_DIR/playbook.md"
