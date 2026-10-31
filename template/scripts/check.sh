#!/usr/bin/env bash
# 완료 조건 = 이 스크립트가 "CHECK PASS"로 끝나는 것.
# 과제와 무관한 칸(1·2·4·5)은 키트가 고정하고, 과제별 검사(3)는 과제를 아는 Codex가 scripts/verify.sh에 직접 쓴다.
# 테스트를 지우거나 기대값을 바꿔서 통과시키지 않는다.
#
# 사용:
#   ./scripts/check.sh
#   SUBMIT=1 ./scripts/check.sh                          # 제출 전: verify.sh의 제출 문서 검사까지
#   SMOKE_URL=http://localhost:3000/ ./scripts/check.sh   # 서버가 떠 있을 때 응답까지 확인
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
run() {
  local name="$1"; shift
  echo "── $name"
  if "$@"; then
    echo "   PASS $name"
  else
    echo "   FAIL $name"
    fail=1
  fi
}

# 테스트는 감시(watch) 모드를 끄고(CI=true) 제한 시간 안에서 돌린다. 늘리려면 TEST_TIMEOUT=600 ./scripts/check.sh
TEST_TIMEOUT="${TEST_TIMEOUT:-300}"
with_timeout() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$TEST_TIMEOUT" env CI=true "$@"
    local rc=$?
    [ "$rc" -eq 124 ] && echo "   (제한 시간 ${TEST_TIMEOUT}초 초과 — 감시 모드나 닫히지 않는 서버·연결이 있는지 확인)"
    return "$rc"
  else
    env CI=true "$@"
  fi
}

# 1) 테스트 (스택 자동 감지 — 맞지 않으면 이 칸을 직접 고친다)
has_npm_test() {
  [ -f package.json ] && command -v node >/dev/null 2>&1 &&
    node -e 'const s=(require("./package.json").scripts||{});process.exit(s.test?0:1)' 2>/dev/null
}
if has_npm_test; then
  run "npm test" with_timeout npm test
elif [ -f pyproject.toml ] || [ -f pytest.ini ] || [ -f setup.cfg ] || [ -d tests ]; then
  if command -v pytest >/dev/null 2>&1; then
    run "pytest" with_timeout pytest -q
  elif command -v python3 >/dev/null 2>&1 && python3 -m pytest --version >/dev/null 2>&1; then
    run "pytest" with_timeout python3 -m pytest -q
  else
    echo "── 테스트: pytest를 찾지 못함 (가상환경을 켰나요? pip install pytest)"
    fail=1
  fi
else
  if [ ! -f package.json ] && [ ! -f pyproject.toml ] && [ ! -f requirements.txt ]; then
    echo "── 테스트: 아직 프로젝트 파일이 없음 — 시작 단계면 정상(\"구현\"으로 테스트가 생기면 PASS할 수 있다)"
  else
    echo "── 테스트: 감지 못 함 → package.json의 scripts.test를 만들거나 scripts/check.sh 1) 칸에 테스트 명령을 넣으세요"
  fi
  fail=1
fi

# 2) 스모크 (선택): 서버가 떠 있으면 응답 확인
if [ -n "${SMOKE_URL:-}" ]; then
  run "smoke $SMOKE_URL" curl -fsS -o /dev/null --max-time 5 "$SMOKE_URL"
fi

# 3) 과제별 검사: scripts/verify.sh — Codex가 과제를 읽고 직접 쓴다(PLAN.md 3절 검사 계획 · 대상을 만드는 "구현"에서 추가).
#    규칙: 하드 제약 위반만 exit 1 · 점수·소프트 제약은 출력만 · 바꿀 수 없는 환경 조건(런타임 버전 등)은 경고만
#          · 제출 문서 검사는 SUBMIT=1일 때만 · 포트를 열지 않는다
#    예:
#      rc=0
#      node scripts/validate.js || rc=1    # 실제 데이터로 산출 → 하드 제약 위반 0건인지 · 점수 출력
#      test -d src/logic && ! grep -rnE "(require\(|from ).(node:)?(http|express|sqlite3?|pg|mysql2?)" src/logic || rc=1   # 계층 경계(폴더가 없으면 FAIL)
#      [ "${SUBMIT:-0}" != 1 ] || ! grep -n "TODO" HOW_TO_RUN.md || rc=1   # 제출 문서에 양식 빈칸이 남았나
#      exit "$rc"
if [ -f scripts/verify.sh ]; then
  run "과제 검사 (scripts/verify.sh)" with_timeout bash scripts/verify.sh
elif grep -qE '^[-*] \[[xX]\] \**R-?[0-9]+' PLAN.md 2>/dev/null; then
  echo "── 과제 검사 없음: 구현이 시작됐는데 scripts/verify.sh가 없다 → PLAN.md 3절 검사 계획대로 만든다"
  fail=1
fi

# 4) 위생: 비밀값 패턴(커밋 안 한 새 파일 포함, .gitignore 대상 제외) · 커밋 대상 · 셸 스크립트 CRLF
#    값은 출력하지 않고 파일 이름만 보여 준다. 점(.)으로 시작하는 최상위 폴더·파일(홈 설정·로그인 정보)은 훑지 않는다
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  secret_files=$(git grep --untracked -lIE '(^|[^A-Za-z0-9_-])(sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,})|-----BEGIN [A-Z ]*PRIVATE KEY-----' \
      -- . ':(exclude,glob).*' ':(exclude,glob).*/**' 2>/dev/null \
    | grep -vE '(^|/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|poetry\.lock|Pipfile\.lock|[^/]*\.lock)$' || true)
  if [ -n "$secret_files" ]; then
    echo "── 비밀값 의심: $(echo "$secret_files" | tr '\n' ' ')(내가 만든 파일이면 값을 .env로 옮기고 .gitignore 확인)"
    echo "   FAIL secrets"
    fail=1
  fi
  # 스테이징·r0 이후 커밋에 홈 설정·로그인 정보·의존성·.env가 섞였나
  mixed=$( { git diff --cached --name-only; git rev-parse -q --verify r0 >/dev/null && git diff --name-only r0 HEAD; } 2>/dev/null \
    | grep -E '^\.(codex|config|ssh|aws|gnupg|npm|cache|local)/|(^|/)node_modules/|(^|/)\.env$' | sort -u)
  if [ -n "$mixed" ]; then
    echo "── 커밋 대상에 홈 설정·의존성·.env: $(echo $mixed) — 파일은 건드리지 말고 사람에게 보고"
    echo "   FAIL staging"
    fail=1
  fi
fi
crlf_files=""
for f in scripts/*.sh; do
  [ -f "$f" ] && [ "$(tr -cd '\r' < "$f" | wc -c)" -gt 0 ] && crlf_files="$crlf_files $f"
done
if [ -n "$crlf_files" ]; then
  echo "── CRLF 줄바꿈:$crlf_files (sed -i 's/\r$//' <파일>)"
  echo "   FAIL line-endings"
  fail=1
fi

# 5) 환경 (FAIL일 때만): Codex 샌드박스는 127.0.0.1 포트도 막는다 → 서버를 띄우는 테스트가 코드와 무관하게 실패
port_blocked() {
  if command -v python3 >/dev/null 2>&1; then
    ! python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); s.listen()' 2>/dev/null
  elif command -v node >/dev/null 2>&1; then
    ! node -e 'require("net").createServer().listen(0, "127.0.0.1", () => process.exit(0)).on("error", () => process.exit(1))' 2>/dev/null
  else
    return 1
  fi
}
if [ "$fail" -ne 0 ] && port_blocked; then
  echo "── 환경: 이 셸은 127.0.0.1 포트를 열 수 없음(Codex 샌드박스). 실패가 EPERM·listen 오류뿐이면 코드 문제가 아니다"
  echo "   → 코드를 고치지 말고 check를 샌드박스 밖에서 다시 돌린다(승인 요청) · 사람은 터미널에서 ./scripts/check.sh"
fi

echo
if [ "$fail" -eq 0 ]; then result="CHECK PASS"; else result="CHECK FAIL"; fi
echo "$result"
# 마지막 결과 기록 (.kit/ 는 .gitignore 대상)
mkdir -p .kit 2>/dev/null && echo "$(TZ=KST-9 date '+%H:%M') $result${SUBMIT:+ (SUBMIT=$SUBMIT)}" > .kit/last_check 2>/dev/null || true
exit "$fail"
