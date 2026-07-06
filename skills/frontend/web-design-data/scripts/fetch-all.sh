#!/usr/bin/env bash
# fetch-all.sh — web-design-data 외부 소스 4종 재현 가능 추출 오케스트레이터.
# 정책: MIT/Apache 소스만. 각 소스의 커밋 SHA 를 _raw/<source>/COMMIT 에 기록(재현성).
# 산출: _raw/ (원본·감사용, git 미추적) → normalize.py 가 references/ 생성.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for s in ui-ux-pro-max design-systems hallmark impeccable bencium; do
  echo "──── fetch: $s ────"
  bash "$HERE/fetch-$s.sh"
done
echo "──── normalize ────"
python3 "$HERE/normalize.py"
echo "──── notice ────"
bash "$HERE/gen-notice.sh"
echo "fetch-all complete."
