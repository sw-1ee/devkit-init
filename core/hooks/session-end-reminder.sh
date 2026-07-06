#!/bin/bash
# UserPromptSubmit hook: wrap-up 신호 감지 시 세션 종료 체크리스트 컨텍스트 주입.
# stdout 은 additionalContext 로 Claude 에 전달됨.

json=$(cat)
prompt=$(echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('prompt',''))" 2>/dev/null)

if echo "$prompt" | grep -qiE '(끝\?|끝난겨|끝났|끝인가|완료\?|완료야|완료\?|다음\?|다음은|wrap|마무리|세션.?종료|저장해|정리해줘|이만)'; then
    cat <<'REMINDER'
[SESSION-END CHECKLIST — 세션 종료 절차 강제 리마인더]
사용자가 wrap-up 신호를 보냈다. 기능 답변만 하고 끝내지 말고, 아래 4단계 먼저 확인·실행:
1. (자동 — Stop hook 이 처리) JSONL → conversation_log.md
2. CLAUDE.md ## Current State 섹션 갱신 (last_session / last_jsonl / last_commit / pending)
3. Memory 점검 (이번 세션에서 user/feedback/project/reference 저장할 것 있나 자문)
4. git status 확인 → 커밋 또는 명시적 WIP 이월
각 단계 수행/스킵 여부를 명시. 조용히 생략하지 말 것.
REMINDER
fi
exit 0
