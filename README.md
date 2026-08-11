# M0609 + RG2 Bringup (ROS2 Jazzy)

- Doosan M0609 협동로봇 + OnRobot RG2 그리퍼 + RealSense D435 브라켓을 **통합 기동**
- 대상: Ubuntu 24.04 (noble) + ROS2 Jazzy

## 설치

```bash
# 1) apt 의존
sudo apt update
sudo apt install -y libpoco-dev libyaml-cpp-dev \
    ros-jazzy-joint-state-publisher ros-jazzy-joint-state-publisher-gui ros-jazzy-xacro \
    ros-jazzy-realsense2-camera ros-jazzy-realsense2-description \
    ros-jazzy-ros2-control ros-jazzy-ros2-controllers ros-jazzy-velocity-controllers \
    ros-jazzy-control-msgs ros-jazzy-realtime-tools ros-jazzy-moveit-msgs \
    ros-jazzy-kdl-parser ros-jazzy-eigen3-cmake-module python3-pymodbus
```

```bash
# 2) 패키지
git clone -b jazzy https://github.com/ROKEY-SPARK/m0609_rg2_integration ~/m0609_rg2_integration
cd ~/m0609_rg2_integration/src

# doosan-robot2 jazzy fork
git clone https://github.com/ROKEY-SPARK/doosan-robot2_jazzy.git doosan-robot2
git clone https://github.com/ABC-iRobotics/onrobot-ros2

rosdep install -r --from-paths . --ignore-src --rosdistro $ROS_DISTRO -y
```

```bash
# 3) doosan-robot2 패치
DSR_IMP=~/m0609_rg2_integration/src/doosan-robot2/dsr_common2/imp/DSR_ROBOT2.py

# dsr_msgs2 의 클래스명 패치
sed -i 's/SetSingularityHandlingForce/SetSingularHandlingForce/g' "$DSR_IMP"

# 서비스 이름 prefix 패치
sed -i -E "s|^_srv_name_prefix([[:space:]]*)=[[:space:]]*''|_srv_name_prefix\1= 'dsr_controller2/'|" "$DSR_IMP"
```

```bash
# 4) 빌드
cd ~/m0609_rg2_integration
colcon build --symlink-install
source install/setup.bash
```

## 초기 설정 (최초 1회)

```bash
# DRCF 에뮬레이터
sudo usermod -aG docker $USER && newgrp docker
docker pull doosanrobot/dsr_emulator:3.0.1

# real 모드 UDP 포트 권한
sudo sysctl -w net.ipv4.ip_unprivileged_port_start=0
echo 'net.ipv4.ip_unprivileged_port_start=0' | sudo tee /etc/sysctl.d/99-ros2-doosan.conf

# RealSense udev — 적용 후 USB 재연결
sudo curl -fsSL https://raw.githubusercontent.com/IntelRealSense/librealsense/master/config/99-realsense-libusb.rules \
  -o /etc/udev/rules.d/99-realsense-libusb.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
```

---

## 실행

환경 source

```bash
source /opt/ros/jazzy/setup.bash
source ~/m0609_rg2_integration/install/setup.bash  # DSR + 그리퍼 / URDF / bringup
```

### 기동

```bash
# 에뮬레이터
ros2 launch m0609_rg2_bringup bringup.launch.py

# 실기
ros2 launch m0609_rg2_bringup bringup.launch.py mode:=real host:=192.168.1.100

# RealSense 포함 
ros2 launch m0609_rg2_bringup bringup.launch.py camera:=true
```

### 가상 pick & place 테스트

```bash
# bringup 이 떠 있는 상태에서 별도 터미널
ros2 run m0609_rg2_bringup pick_place_demo.py
# home → 집기 → 하강 → 파지 → 이동 → 하강 → 놓기 → home 한 사이클
```

---

## 그리퍼 신호 경로

```
[virtual] gripper_virtual_node ─┐
                                ├→ /onrobot_joint_states → gripper_joint_state_publisher
[real]    OnRobot RG2 드라이버 ─┘                              │  (rg2_ prefix 부착)
                                                               ↓
                                                    /gripper_joint_states
                                                               ↓
      /dsr01/joint_states ────────────────→ joint_state_publisher → robot_state_publisher → RViz
```


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


---

## 디렉토리 구조

```
m0609_rg2_integration/
├── docker/                         # jammy 워크스테이션용 jazzy 개발 컨테이너
│   ├── Dockerfile.jazzy
│   ├── entrypoint.sh
│   ├── run.sh
│   └── check_urdf.py               # URDF 스모크 체크
└── src/
    ├── m0609_rg2_bringup/          # 커스텀 브링업 패키지
    │   ├── launch/bringup.launch.py            # 로봇 + 그리퍼 + (옵션) RealSense
    │   ├── meshes/mount_bracket.stl
    │   ├── rviz/{default,moveit}.rviz
    │   ├── scripts/
    │   │   ├── gripper_joint_state_publisher.py   # onrobot_joint_states → gripper_joint_states
    │   │   ├── gripper_virtual_node.py            # virtual 그리퍼
    │   │   └── pick_place_demo.py                 # 가상 pick & place 한 사이클
    │   └── urdf/
    │       ├── m0609_with_rg2.urdf.xacro          # 팔 + 그리퍼 (표시 전용)
    │       ├── m0609_with_rg2_camera.urdf.xacro   # 팔 + 그리퍼 + 브라켓 + D435 + ros2_control
    │       ├── onrobot_rg2.xacro                  # RG2 베이스 링크 정의
    │       ├── onrobot_rg2_model_macro.xacro      # RG2 링크/조인트 매크로
    │       └── realsense_bracket.urdf.xacro       # 브라켓 + D435 마운트 (tool0 기준)
    ├── doosan-robot2/              # 외부 패키지
    └── onrobot-ros2/               # 외부 패키지
```
