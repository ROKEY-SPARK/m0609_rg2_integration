#!/usr/bin/env bash
# DSR 스택이 없는 워크스페이스에서 bringup 이 "무엇이 없고 어떻게 고치는지"를 말하는지 확인한다.
#
# 회귀 대상: 예전에는 dsr_description2 를 못 찾은 사실이 xacro 트레이스백 속 PackageNotFoundError 로
# 묻혀서, 사용자가 원인(= DSR 스택 미설치)에도 해법(= clone 하거나 cobot_ws 오버레이 source)에도
# 도달하지 못했다.
#
#   bash docker/test_missing_dsr.sh          # 기본 이미지로 실행
set -euo pipefail

IMAGE="${IMAGE:-m0609-rg2-jazzy:dev}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

mkdir -p "${WORK}/src"
cp -a "${REPO_ROOT}/src/m0609_rg2_bringup" "${WORK}/src/"
[ -d "${REPO_ROOT}/src/onrobot-ros2" ] && cp -a "${REPO_ROOT}/src/onrobot-ros2" "${WORK}/src/"

# DSR 오버레이(/opt/dsr_ws)를 일부러 source 하지 않는다 — 실기의 "DSR 미설치 워크스페이스" 재현.
out="$(docker run --rm -i --user "$(id -u):$(id -g)" -e HOME=/tmp/rosuser \
    -v "${WORK}:/w" --entrypoint /bin/bash "${IMAGE}" -lc '
mkdir -p $HOME; cd /w
set +u; source /opt/ros/jazzy/setup.bash
colcon build --symlink-install >/dev/null 2>&1
source /w/install/setup.bash
timeout 40 ros2 launch m0609_rg2_bringup bringup.launch.py 2>&1
' || true)"

fail=0
check() {
    if grep -qF -- "$2" <<<"${out}"; then
        echo "  PASS  $1"
    else
        echo "  FAIL  $1 (기대 문자열 없음: $2)"; fail=1
    fi
}

echo "=== DSR 미설치 워크스페이스에서의 bringup 에러 메시지 ==="
check "없는 패키지를 이름으로 지목"      "dsr_description2"
check "원인을 문장으로 설명"              "DSR"
check "해법 1: 워크스페이스에 clone"      "doosan-robot2"
check "해법 2: 기존 오버레이 source"      "install/setup.bash"

if [ "${fail}" -ne 0 ]; then
    echo
    echo "--- 실제 출력 (마지막 25줄) ---"
    tail -25 <<<"${out}"
    exit 1
fi
echo "모두 통과"
