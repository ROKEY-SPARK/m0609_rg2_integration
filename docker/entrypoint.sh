#!/usr/bin/env bash
# ROS2 underlay → DSR 오버레이 → (있으면) 이 워크스페이스 오버레이 순으로 source.
# set -u 는 두지 않는다 — ROS 의 setup.bash 가 미정의 변수를 참조한다.
# shellcheck disable=SC1090,SC1091  # ROS setup 파일은 런타임 생성물이라 정적 추적 불가
set -eo pipefail

source "/opt/ros/${ROS_DISTRO}/setup.bash"
source /opt/dsr_ws/install/setup.bash
if [ -f /ws/install/setup.bash ]; then
    source /ws/install/setup.bash
fi

exec "$@"
