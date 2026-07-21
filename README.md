# M0609 + RG2 ROS2 Workspace (Jazzy)

Doosan M0609 협동로봇 + OnRobot RG2 그리퍼 + RealSense D435 브라켓 통합 ROS2 워크스페이스.

`ros2_jazzy_test` 인스톨러가 만든 `~/cobot_ws` (DSR 드라이버 + cobot2 애플리케이션) 위에
오버레이로 얹어 쓰는 것을 전제로 한다.

---

## 요구사항

- Ubuntu 24.04 (noble)
- ROS2 Jazzy
- Docker (virtual 모드 DRCF 에뮬레이터)
- Intel RealSense SDK 2.0 (실 카메라 사용 시)

```bash
sudo apt update

# DSR 드라이버 빌드 의존
sudo apt install libpoco-dev libyaml-cpp-dev

# ROS2 빌드 및 실행 관련
sudo apt install ros-jazzy-joint-state-publisher \
    ros-jazzy-joint-state-publisher-gui \
    ros-jazzy-xacro \
    ros-jazzy-realsense2-camera \
    ros-jazzy-realsense2-description

# 제어 및 하드웨어 인터페이스
sudo apt install ros-jazzy-ros2-control \
    ros-jazzy-ros2-controllers \
    ros-jazzy-velocity-controllers \
    ros-jazzy-control-msgs \
    ros-jazzy-realtime-tools \
    ros-jazzy-moveit-msgs \
    ros-jazzy-kdl-parser \
    ros-jazzy-eigen3-cmake-module

# 그리퍼 Modbus 통신 (real 모드)
sudo apt install python3-pymodbus
```

---

## 의존성 패키지 설치

```bash
mkdir -p ~/M0609_RG2_Integration/src
cd ~/M0609_RG2_Integration/src

# Doosan 패키지 — jazzy 스냅샷을 버전 고정한 fork (upstream 의 humble 브랜치는 안 됨)
git clone https://github.com/ROKEY-SPARK/doosan-robot2_jazzy.git doosan-robot2

# OnRobot RG2 패키지 (jazzy 에서 수정 없이 빌드된다)
git clone https://github.com/ABC-iRobotics/onrobot-ros2

# package.xml 의존성 자동 설치
cd ~/M0609_RG2_Integration/src
rosdep install -r --from-paths . --ignore-src --rosdistro $ROS_DISTRO -y
```

> `onrobot_rg_control` 의 `message_generation` / `message_runtime` 키는 ROS1 잔재라 경고가 나오지만
> `-r` 플래그로 무시되어 빌드엔 영향 없음.

### doosan-robot2 (jazzy) 소스 패치 2건

clone 직후 아래 두 곳을 고쳐야 `DSR_ROBOT2` 가 동작한다 (둘 다 멱등 — 여러 번 실행해도 안전).

```bash
DSR_IMP=~/M0609_RG2_Integration/src/doosan-robot2/dsr_common2/imp/DSR_ROBOT2.py

# (1) dsr_msgs2 가 만드는 실제 클래스명은 SetSingularHandlingForce — 모듈 로드 시 NameError 방지
sed -i 's/SetSingularityHandlingForce/SetSingularHandlingForce/g' "$DSR_IMP"

# (2) 서비스 이름 prefix 가 비어 있어 클라이언트가 존재하지 않는 이름을 부르고 영원히 대기
sed -i -E "s|^_srv_name_prefix([[:space:]]*)=[[:space:]]*''|_srv_name_prefix\1= 'dsr_controller2/'|" "$DSR_IMP"
```

> `ros2_jazzy_test` 의 `resources/dsr-project-install.sh` 를 쓰면 이 패치가 자동 적용된다.

---

## 초기 설정 (최초 1회)

### DRCF 에뮬레이터 (virtual 모드 motion service용)

```bash
sudo usermod -aG docker $USER
newgrp docker
docker pull doosanrobot/dsr_emulator:3.0.1
```

### Real 모드 사전 조건

- 로봇 IP: `192.168.1.100`
- 그리퍼 IP: `192.168.1.1` (OnRobot 컴퓨트박스, 고정)
- UDP 포트 권한 설정:
  ```bash
  sudo sysctl -w net.ipv4.ip_unprivileged_port_start=0
  echo 'net.ipv4.ip_unprivileged_port_start=0' | sudo tee /etc/sysctl.d/99-ros2-doosan.conf
  ```

### RealSense udev rules

```bash
sudo curl https://raw.githubusercontent.com/IntelRealSense/librealsense/master/config/99-realsense-libusb.rules \
  -o /etc/udev/rules.d/99-realsense-libusb.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
```

적용 후 USB 재연결 필요.

---

## 빌드

```bash
cd ~/M0609_RG2_Integration
colcon build --symlink-install
source install/setup.bash
```

---

## 실행

```bash
source /opt/ros/jazzy/setup.bash
source ~/M0609_RG2_Integration/install/setup.bash
```

### Virtual 모드 (시뮬레이션)

```bash
# 로봇 + 그리퍼 + 브라켓/카메라 모델 + RViz (DRCF 에뮬레이터 자동 기동)
ros2 launch m0609_rg2_bringup bringup.launch.py

# RealSense 드라이버까지 (가상 모드에서 실 카메라를 쓰고 싶을 때)
ros2 launch m0609_rg2_bringup bringup.launch.py camera:=true
```

### Real 모드 (실제 로봇)

```bash
ros2 launch m0609_rg2_bringup bringup.launch.py mode:=real host:=192.168.1.100
```

`mode:=real` 이면 RealSense 드라이버는 자동으로 함께 뜬다.

### launch 인자

| 인자 | 기본값 | 설명 |
|------|--------|------|
| `mode` | `virtual` | `virtual`(DRCF 에뮬레이터) / `real`(실 컨트롤러) |
| `host` | `192.168.1.100` | 실기 IP. `virtual` 이면 무시되고 `127.0.0.1` 로 강제 |
| `port` | `12345` | DSR 컨트롤러 포트(DRFL) |
| `rt_host` | `192.168.137.50` | 실기 RT control 채널 IP. 빈 값이면 DRCF 3.0+ 에서 RT 연결이 열리지 않는다 |
| `camera` | `false` | RealSense 드라이버 기동. `mode:=real` 이면 항상 기동 |
| `rviz` | `true` | RViz 기동 여부 |

---

## 가상 pick & place

bringup 이 떠 있는 상태에서 별도 터미널:

```bash
ros2 run m0609_rg2_bringup pick_place_demo.py
```

카메라 / YOLO / 음성 없이 관절공간 웨이포인트로 한 사이클(home → 집기 위치 → 하강 → 파지 →
이동 → 하강 → 놓기 → home)을 수행한다. 그리퍼는 `/onrobot/sendCommand` 로만 제어하므로
virtual(가상 노드) / real(OnRobot 드라이버) 어느 쪽이든 같은 코드가 돈다.

### 그리퍼 신호 경로 (virtual / real 공통)

```
[virtual] gripper_virtual_node ─┐
                                ├→ /onrobot_joint_states → gripper_joint_state_publisher
[real]    OnRobot RG2 드라이버 ─┘                              │  (rg2_ prefix 부착)
                                                               ↓
                                                    /gripper_joint_states
                                                               ↓
      /dsr01/joint_states ────────────────→ joint_state_publisher → robot_state_publisher → RViz
```

두 모드가 같은 토픽 체인을 쓰므로 RViz 하위 경로에 모드 분기가 없다.

`gripper_virtual_node` 가 제공하는 서비스는 실 드라이버와 동일한 인터페이스다:

| 명령 | 의미 |
|------|------|
| `o` | 최대 개방 (110 mm) |
| `c` | 완전 폐쇄 |
| 정수 | 목표 너비 (1/10 mm, 0..1100) |

서비스 응답은 애니메이션이 목표에 도달한 뒤에 돌아온다 — 실 그리퍼의 busy 대기와 같은 의미라
호출자가 곧바로 다음 모션으로 넘어가지 않는다.

---

## cobot2 (robot_move / robot_control) 연동

`ros2_jazzy_test` 스택의 pick & place 노드는 그리퍼를 pymodbus 로 직접 잡는다
(`RG("rg2", "192.168.1.1", "502")`). 에뮬레이터만 도는 virtual 환경에는 그 하드웨어가 없어
그리퍼 동작이 통째로 건너뛰어졌다.

`~/cobot_ws/src/cobot2/*/onrobot.py` 의 `RG` 가 Modbus 연결 실패 시
`/onrobot/sendCommand`(= `gripper_virtual_node`)로 우회하도록 바뀌었다. 서비스도 없으면
기존처럼 skip 한다. 호출부(`robot_move.py` / `robot_control.py`)는 수정 불필요.

### 설치 스택과의 통합

`ros2_jazzy_test` 인스톨러가 이 패키지를 통합 bringup 진입점으로 쓴다.

- `setup-app.sh` 의 `obtain_m0609` 단계가 이 레포를 `${M0609_REPO_DIR}`(기본
  `~/M0609_RG2_Integration`)에 두고, `src/m0609_rg2_bringup` **한 패키지만**
  `~/cobot_ws/src` 로 심볼릭 링크한다. 이미 레포가 있으면 clone 을 건너뛰므로 개발 중인
  작업본이 덮어써지지 않는다. `src/onrobot-ros2` 는 커밋 SHA 로 핀 고정해 같은 곳에 clone 된다.
- `containers/bringup.sh` 가 `ros2 launch m0609_rg2_bringup bringup.launch.py` 를 호출한다
  (구 `cobot2_bringup bringup_all.launch.py` 대체). `camera:=` 를 지정하지 않으면 래퍼가
  `camera:=true` 를 붙인다 — yolo 노드가 카메라 토픽 없이는 조용히 대기만 하기 때문.

따라서 그 스택에서는 워크스페이스가 `~/cobot_ws` 하나이고 오버레이도 하나다:

```bash
source /opt/ros/jazzy/setup.bash
source ~/cobot_ws/install/setup.bash              # DSR + cobot2 + m0609_rg2_bringup + onrobot

bash <ros2_jazzy_test>/containers/bringup.sh      # 터미널 1 (yolo 컨테이너 + host voice 포함)
ros2 run pick_and_place_text robot_move           # 터미널 2
```

이 레포만 단독으로 쓸 때는 별도 워크스페이스로 빌드해 오버레이를 겹쳐도 된다:

```bash
source ~/cobot_ws/install/setup.bash              # DSR + cobot2
source ~/M0609_RG2_Integration/install/setup.bash # 그리퍼 / URDF / bringup

ros2 launch m0609_rg2_bringup bringup.launch.py
```

---

## humble → jazzy 마이그레이션 노트

| 항목 | humble | jazzy |
|------|--------|-------|
| DSR 소스 | `doosan-robotics/doosan-robot2` (humble) | `ROKEY-SPARK/doosan-robot2_jazzy` + 소스 패치 2건 |
| 링크 / 조인트 이름 | `link1`..`link6`, `joint1`..`joint6` | `link_1`..`link_6`, `joint_1`..`joint_6` |
| `controller_manager` 의 robot_description | 노드 파라미터 | **토픽 구독** (`<ns>/robot_description`) |
| `tool0` | `dsr_description2/urdf/m0609.urdf` 에 포함 | `xacro/m0609.urdf.xacro` 에는 없음 → 이 패키지가 정의 |
| `world` 링크 | 별도 `static_transform_publisher` | `xacro/m0609.urdf.xacro` 가 생성 (`world_fixed`) |
| onrobot-ros2 | 그대로 | 그대로 (수정 없이 빌드됨) |

`controller_manager` 가 토픽에서 URDF 를 읽게 되면서, 팔 URDF(ros2_control 포함)와 표시용
통합 URDF 를 따로 두면 갈라질 여지가 생긴다. 그래서 `m0609_with_rg2_camera.urdf.xacro` 가
`dsr_description2/xacro/m0609.urdf.xacro` 를 include 해 `<ros2_control>` 까지 담고,
`robot_state_publisher` 와 `controller_manager` 가 같은 한 장을 본다.

---

## RealSense 주요 토픽

| 토픽 | 설명 |
|------|------|
| `/camera/camera/color/image_raw` | RGB 컬러 이미지 |
| `/camera/camera/aligned_depth_to_color/image_raw` | 컬러 정렬 뎁스 이미지 |
| `/camera/camera/depth/color/points` | RGB 포인트클라우드 |
| `/camera/camera/color/camera_info` | 컬러 카메라 내부 파라미터 |

`camera/camera` 이중 네임스페이스는 realsense2_camera 의 `rs_launch.py` 기본값
(`camera_namespace` / `camera_name` 둘 다 `camera`)과 같은 조합이다. cobot2 의 소비자
(`object_detection` / `pick_and_place_text`)가 이 경로를 구독하므로 바꾸면 안 된다.

`default.rviz` 사전 구성 display: Color Image / Depth Image / PointCloud2 / RobotModel.

---

## TF 구조

```
world
└── base_link
    └── link_1 → link_2 → link_3 → link_4 → link_5 → link_6
                                                        └── tool0
                                                            ├── rg2_base_link
                                                            │   ├── rg2_left_outer_knuckle
                                                            │   │   ├── rg2_left_inner_knuckle
                                                            │   │   └── rg2_left_inner_finger
                                                            │   └── rg2_right_outer_knuckle
                                                            │       ├── rg2_right_inner_knuckle
                                                            │       └── rg2_right_inner_finger
                                                            └── bracket_link
                                                                └── camera_link
                                                                    ├── camera_color_frame / camera_color_optical_frame
                                                                    ├── camera_depth_frame / camera_depth_optical_frame
                                                                    ├── camera_infra1_frame / camera_infra1_optical_frame
                                                                    └── camera_infra2_frame / camera_infra2_optical_frame
```

- `world → base_link`: `world_fixed` (URDF 내부, fixed)
- `tool0 → rg2_base_link`: `joint0` (fixed)
- `tool0 → bracket_link`: `tool0_to_bracket` (fixed)
- `rg2_finger_joint` 외 그리퍼 조인트는 전부 mimic — 이 하나만 발행하면 손가락 전체가 따라온다

---

## 개발용 jazzy 컨테이너 (Ubuntu 22.04 워크스테이션)

개발 머신이 22.04(jammy)면 jazzy 를 host 에 설치할 수 없다(배포판 불일치). 컨테이너 안에서
빌드 / 실행 / RViz 확인을 한다. 24.04 머신에서는 필요 없다.

```bash
bash docker/run.sh build                                    # 이미지 빌드 (DSR 오버레이 포함)
bash docker/run.sh colcon build --symlink-install           # 워크스페이스 빌드
bash docker/run.sh ros2 launch m0609_rg2_bringup bringup.launch.py
```

`--network host` + host `docker.sock` 을 쓰므로 DRCF 에뮬레이터는 형제 컨테이너로 뜨고,
DDS 토픽은 host 와 그대로 공유된다.

URDF 스모크 체크 (RViz 없이 링크 / 조인트 연결 검증):

```bash
bash docker/run.sh bash -c 'xacro $(ros2 pkg prefix m0609_rg2_bringup)/share/m0609_rg2_bringup/urdf/m0609_with_rg2_camera.urdf.xacro \
    host:=127.0.0.1 port:=12345 mode:=virtual model:=m0609 update_rate:=100 > /tmp/robot.urdf \
    && python3 /ws/docker/check_urdf.py /tmp/robot.urdf'
```

---

## 디렉토리 구조

```
M0609_RG2_Integration/
├── docker/                         # jammy 워크스테이션용 jazzy 개발 컨테이너
│   ├── Dockerfile.jazzy
│   ├── entrypoint.sh
│   ├── run.sh
│   └── check_urdf.py               # URDF 스모크 체크
└── src/
    ├── m0609_rg2_bringup/          # 커스텀 브링업 패키지
    │   ├── launch/
    │   │   └── bringup.launch.py           # 로봇 + 그리퍼 + (옵션) RealSense
    │   ├── meshes/
    │   │   └── mount_bracket.stl
    │   ├── rviz/
    │   │   ├── default.rviz
    │   │   └── moveit.rviz
    │   ├── scripts/
    │   │   ├── gripper_joint_state_publisher.py   # onrobot_joint_states → gripper_joint_states
    │   │   ├── gripper_virtual_node.py            # virtual 그리퍼 (서비스 + joint_states)
    │   │   └── pick_place_demo.py                 # 가상 pick & place 한 사이클
    │   └── urdf/
    │       ├── m0609_with_rg2.urdf.xacro           # 팔 + 그리퍼 (표시 전용, ros2_control 없음)
    │       ├── m0609_with_rg2_camera.urdf.xacro    # 팔 + 그리퍼 + 브라켓 + D435 + ros2_control
    │       ├── onrobot_rg2.xacro                   # RG2 베이스 링크 정의
    │       ├── onrobot_rg2_model_macro.xacro       # RG2 링크/조인트 매크로
    │       └── realsense_bracket.urdf.xacro        # 브라켓 + D435 마운트 (tool0 기준)
    ├── m0609_rg2_moveit/               # MoveIt2 패키지 (deprecated — 현재 미사용)
    ├── doosan-robot2/                  # 외부 패키지 — read-only
    └── onrobot-ros2/                   # 외부 패키지 — read-only
```

---

## 검증 상태

| 항목 | 상태 |
|------|------|
| jazzy colcon 빌드 (bringup / moveit / onrobot-ros2) | 확인됨 |
| 통합 URDF xacro 파싱 + 링크/조인트 연결 | 확인됨 (`docker/check_urdf.py`) |
| virtual bringup — 에뮬레이터 연결, 두 컨트롤러 활성화 | 확인됨 |
| RViz 에 팔 + RG2 + 브라켓 + D435 표시 | 확인됨 |
| 가상 pick & place 1 사이클 (`pick_place_demo.py`) | 확인됨 |
| 그리퍼 관절 구동 범위 (-0.4608 ~ 0.7854 rad) | 확인됨 |
| cobot2 `RG` → 가상 그리퍼 우회 | 확인됨 |
| `~/cobot_ws` 심볼릭 링크 레이아웃 colcon 빌드 (5 패키지) | 확인됨 |
| `rt_host` 가 렌더된 URDF 의 ros2_control 파라미터에 반영 | 확인됨 |
| RealSense 노드가 `camera/camera` 네임스페이스로 기동 | 확인됨 (노드 이름 기준) |
| real 모드 (실 로봇 / 실 그리퍼 / 실 카메라) | **미검증** — 하드웨어 필요 |
| RealSense 실제 토픽 발행 (`camera:=true`) | **미검증** — 카메라 하드웨어 필요 |
