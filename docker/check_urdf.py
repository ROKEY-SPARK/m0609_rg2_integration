#!/usr/bin/env python3
"""통합 URDF 스모크 체크 — xacro 산출물에 필요한 링크 / 조인트가 다 있는지 본다.

    xacro <pkg>/urdf/m0609_with_rg2_camera.urdf.xacro > /tmp/robot.urdf
    python3 docker/check_urdf.py /tmp/robot.urdf

RViz 를 띄우지 않고도 "팔 + 그리퍼 + 브라켓 + 카메라가 한 트리로 이어졌는가"를 검증한다.
누락 시 exit 1 — 빌드 파이프라인에 그대로 걸 수 있다.
"""
import re
import sys
import xml.etree.ElementTree as ET

REQUIRED_LINKS = [
    'base_link', 'link_1', 'link_6', 'tool0',
    'rg2_base_link', 'rg2_left_inner_finger', 'rg2_right_inner_finger',
    'bracket_link',
    'camera_link', 'camera_color_optical_frame', 'camera_depth_optical_frame',
]
REQUIRED_JOINTS = ['rg2_finger_joint', 'tool0_to_bracket', 'joint0']


def main(path):
    root = ET.parse(path).getroot()
    links = {link.get('name') for link in root.findall('link')}
    joints = {j.get('name'): j for j in root.findall('joint')}

    missing_links = [name for name in REQUIRED_LINKS if name not in links]
    missing_joints = [name for name in REQUIRED_JOINTS if name not in joints]

    print(f'links={len(links)} joints={len(joints)}')

    # mimic 조인트는 rg2_finger_joint 하나만 발행해도 나머지 손가락이 따라 움직이게 하는 핵심.
    mimics = [n for n, j in joints.items() if j.find('mimic') is not None]
    print(f'mimic joints: {sorted(mimics)}')

    # 부모가 없는 링크(=트리 루트)가 여럿이면 URDF 가 끊긴 것.
    children = {j.find('child').get('link') for j in joints.values()}
    roots = sorted(links - children)
    print(f'roots: {roots}')

    packages = sorted(set(re.findall(r'package://([^/]+)/', open(path).read())))
    print(f'mesh packages: {packages}')

    ok = True
    if missing_links:
        print(f'MISSING links: {missing_links}')
        ok = False
    if missing_joints:
        print(f'MISSING joints: {missing_joints}')
        ok = False
    if len(roots) != 1:
        print(f'URDF is not a single tree: {len(roots)} roots')
        ok = False
    if not mimics:
        print('no mimic joints — gripper fingers will not follow rg2_finger_joint')
        ok = False

    print('URDF CHECK: ' + ('PASS' if ok else 'FAIL'))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else '/tmp/robot.urdf'))
