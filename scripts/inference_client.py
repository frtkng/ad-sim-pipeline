#!/usr/bin/env python3
import os, argparse, json, random
import torch
import carla
from model import EndToEndModel

parser = argparse.ArgumentParser()
parser.add_argument('--host', default='localhost')
parser.add_argument('--port', type=int, default=2000)
parser.add_argument('--model', required=True)
parser.add_argument('--output-dir', required=True)
parser.add_argument('--episodes', type=int, default=1)
parser.add_argument('--pedestrian', action='store_true')
args = parser.parse_args()

os.makedirs(f"{args.output_dir}/scenario_data", exist_ok=True)

# モデルロード
net = EndToEndModel()
net.load_state_dict(torch.load(args.model))
net.eval()

# CARLA接続
client = carla.Client(args.host, args.port)
world = client.get_world()
bp = world.get_blueprint_library()

for ep in range(args.episodes):
    # スポーン: 車両
    veh_bp = bp.filter('vehicle.*')[0]
    spawn_pt = random.choice(world.get_map().get_spawn_points())
    vehicle = world.spawn_actor(veh_bp, spawn_pt)

    # Pedestrianスポーン
    if args.pedestrian:
        ped_bp = bp.filter('walker.pedestrian.*')[0]
        ped = world.try_spawn_actor(ped_bp, random.choice(world.get_map().get_spawn_points()))
        ped_ctrl = world.spawn_actor(bp.find('controller.ai.walker'), carla.Transform(), attach_to=ped)
        ped_ctrl.start()
        ped_ctrl.go_to_location(vehicle.get_location())

    # センサー
    cam_bp = bp.find('sensor.camera.rgb')
    cam = world.spawn_actor(cam_bp, carla.Transform(carla.Location(x=1.5, z=2.4)), attach_to=vehicle)
    coll_bp = bp.find('sensor.other.collision')
    coll_sensor = world.spawn_actor(coll_bp, carla.Transform(), attach_to=vehicle)

    metrics = {'collisions': 0}
    coll_sensor.listen(lambda event: metrics.update({'collisions': metrics['collisions']+1}))

    frames = []
    cam.listen(lambda img: frames.append(img))

    for _ in range(200):
        if frames:
            img = frames.pop(0)
            tensor = torch.from_numpy(img.raw_data).float().unsqueeze(0)
            control = net(tensor)
            vehicle.apply_control(carla.VehicleControl(throttle=float(control[0]), steer=float(control[1])))

    # 結果保存
    with open(f"{args.output_dir}/metrics_{ep}.json", 'w') as f:
        json.dump({'NG': metrics['collisions']}, f)
    # シナリオデータ
    frames[0].save_to_disk(f"{args.output_dir}/scenario_data/{ep}.png")

    # クリーンアップ
    cam.stop(); coll_sensor.stop()
    vehicle.destroy()
    if args.pedestrian: ped_ctrl.stop(); ped.destroy(); ped_ctrl.destroy()
print("Done inference")