#!/usr/bin/env bash
# 완료 조건 = 이 스크립트가 "CHECK PASS"로 끝나는 것.
# 과제에 맞게 아래 '3) 과제별 검사' 칸을 채운다. 테스트를 지우거나 기대값을 바꿔서 통과시키지 않는다.
#
# 사용:
#   ./scripts/check.sh
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

# 0) 환경: Codex 샌드박스가 네트워크를 막으면 127.0.0.1 포트도 못 연다 → 서버를 띄우는 테스트가 코드와 무관하게 실패
port_blocked() {
  if command -v python3 >/dev/null 2>&1; then
    ! python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); s.listen()' 2>/dev/null
  elif command -v node >/dev/null 2>&1; then
    ! node -e 'require("net").createServer().listen(0, "127.0.0.1", () => process.exit(0)).on("error", () => process.exit(1))' 2>/dev/null
  else
    return 1
  fi
}
if port_blocked; then
  echo "── 환경: 127.0.0.1 포트를 열 수 없음(Codex 샌드박스 네트워크 차단). 서버를 띄우는 테스트는 코드와 무관하게 실패한다 — 코드를 고치지 말고 보고할 것."
  echo "   메인 Codex는 codex -c sandbox_workspace_write.network_access=true 로 띄운다. 아니면 T3 셸에서 ./scripts/check.sh"
fi

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
  echo "── 테스트: 감지 못 함 → package.json의 scripts.test를 만들거나 scripts/check.sh 1) 칸에 테스트 명령을 넣으세요"
  fail=1
fi

# 2) 스모크 (선택): 서버가 떠 있으면 응답 확인
if [ -n "${SMOKE_URL:-}" ]; then
  run "smoke $SMOKE_URL" curl -fsS -o /dev/null --max-time 5 "$SMOKE_URL"
fi

# 3) 과제별 검사 — 필요하면 추가 (예: run "lint" npm run lint --silent)

# 4) 위생: 비밀값 패턴(커밋 안 한 새 파일 포함, .gitignore 대상 제외) · 셸 스크립트 CRLF
#    값은 출력하지 않고 파일 이름만 보여 준다
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  secret_files=$(git grep --untracked -lIE '(^|[^A-Za-z0-9_-])(sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,})|-----BEGIN [A-Z ]*PRIVATE KEY-----' 2>/dev/null \
    | grep -vE '(^|/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|poetry\.lock|Pipfile\.lock|[^/]*\.lock)$' || true)
  if [ -n "$secret_files" ]; then
    echo "── 비밀값 의심: $(echo "$secret_files" | tr '\n' ' ')(.env로 옮기고 .gitignore 확인)"
    echo "   FAIL secrets"
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

echo
if [ "$fail" -eq 0 ]; then result="CHECK PASS"; else result="CHECK FAIL"; fi
echo "$result"
# 마지막 결과 기록 (.kit/ 는 .gitignore 대상)
mkdir -p .kit 2>/dev/null && echo "$(TZ=KST-9 date '+%H:%M') $result" > .kit/last_check 2>/dev/null || true
exit "$fail"
