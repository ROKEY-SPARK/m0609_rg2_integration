#!/usr/bin/env bash
# jazzy 개발 컨테이너 기동 래퍼.
#
#   bash docker/run.sh build          # 이미지 빌드
#   bash docker/run.sh                # 대화형 셸
#   bash docker/run.sh <command...>   # 단발 실행 (예: colcon build)
#
# TTY 없는 곳(스크립트 / CI)에서 부를 땐 DOCKER_TTY=-i 를 준다 — 기본 -it 는 "the input device
# is not a TTY" 로 실패한다.
#
# --network host  : DDS discovery 를 host 및 형제 컨테이너(DRCF 에뮬레이터)와 공유.
# docker.sock     : virtual 모드에서 run_emulator 가 DRCF 에뮬레이터를 형제로 띄운다.
#                   host 의 docker 그룹을 --group-add 로 넣어야 소켓에 접근된다.
# --user          : host 사용자로 실행 — /ws(레포 bind-mount)에 root 소유 build/install 이
#                   생겨 host 에서 지우지 못하는 상황을 막는다. HOME 은 컨테이너 안 임시 경로.
# X11             : RViz 표시. host 의 XAUTHORITY 쿠키를 그대로 마운트.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${IMAGE:-m0609-rg2-jazzy:dev}"

if [[ "${1:-}" == "build" ]]; then
    exec docker build -f "${REPO_ROOT}/docker/Dockerfile.jazzy" -t "${IMAGE}" "${REPO_ROOT}/docker"
fi

XAUTH="${XAUTHORITY:-${HOME}/.Xauthority}"
DOCKER_GID="$(getent group docker | cut -d: -f3)"

exec docker run --rm "${DOCKER_TTY:--it}" \
    --name m0609-rg2-jazzy \
    --network host \
    --user "$(id -u):$(id -g)" \
    --group-add "${DOCKER_GID}" \
    -e HOME=/tmp/rosuser \
    -e DISPLAY="${DISPLAY:-:0}" \
    -e XAUTHORITY=/tmp/.Xauthority \
    -e QT_X11_NO_MITSHM=1 \
    -e ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}" \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v "${XAUTH}:/tmp/.Xauthority:ro" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${REPO_ROOT}:/ws" \
    "${IMAGE}" "${@:-bash}"
