#!/usr/bin/env bash
# 세션 시작 요약 — "이어서" 때 실행한다. 아무것도 고치지 않고 읽기만 한다.
# PLAN.md의 ▶ 줄, 요구사항 진척, 마지막 결정 번호, 최근 발견, 알려진 약점 수, git 상태, 마지막 check 결과를 한 화면에 보여 준다.
cd "$(dirname "$0")/.." || exit 1

REQ='^[-*] \[[ xX]\] \**R-?[0-9]+'
count() { [ -f PLAN.md ] || { echo 0; return; }; grep -cE "$1" PLAN.md 2>/dev/null; true; }
section() { [ -f PLAN.md ] && awk -v h="^## $1\\\\." '$0 ~ h {f=1; next} /^## /{f=0} f && /^[-*] /' PLAN.md; }

echo "== PLAN ▶"
if [ -f PLAN.md ]; then
  grep -E '^▶' PLAN.md || echo "  (▶ 줄 없음 — PLAN.md 맨 위에 ▶ 현재 / ▶ 다음을 채우세요)"
else
  echo "  (PLAN.md 없음)"
fi

req_total=$(count "$REQ")
req_done=$(count '^[-*] \[[xX]\] \**R-?[0-9]+')
assumed=$(count "${REQ}.*\\[가정")
last_dec=$( [ -f PLAN.md ] && grep -oE '^[-*] D-[0-9]+' PLAN.md | tail -1 | sed 's/^[-*] //' )
weak=$(section 8 | grep -vc '<약점>')

echo "== 진척"
echo "  요구사항 ${req_done}/${req_total} 완료 · [가정] ${assumed}개 · 마지막 결정 ${last_dec:-없음} · 알려진 약점 ${weak:-0}개"

echo "== 발견 (최근 5줄 — 같은 실수를 반복하지 않기 위해)"
found=$(section 7 | tail -5)
if [ -n "$found" ]; then echo "$found" | sed 's/^/  /'; else echo "  (없음)"; fi

echo "== git"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git status -sb | head -15
  echo "  -- 최근 커밋"
  if git rev-parse --verify -q HEAD >/dev/null; then
    git log --oneline -5 | sed 's/^/  /'
  else
    echo "  (커밋 없음)"
  fi
  tags=$(git tag --list | tr '\n' ' ')
  echo "  -- 태그: ${tags:-없음}"
else
  echo "  (git 저장소 아님)"
fi

echo "== 마지막 check"
if [ -f .kit/last_check ]; then sed 's/^/  /' .kit/last_check; else echo "  (아직 안 돌림 — ./scripts/check.sh)"; fi
