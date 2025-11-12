"""
csv_to_smplnpz.py
Converts a CSV of joint channels (exported from your MATLAB table) into an AMASS-style SMPL .npz:
  np.savez('out.npz', poses=poses, betas=betas, trans=trans, gender=gender)

Assumptions:
- CSV columns are per your steadyspeed table (e.g., pelvis_tx, pelvis_ty, pelvis_tz,
  pelvis_tilt, pelvis_list, pelvis_rotation, hip_flexion_r, ...).
- Angles in CSV are in RADIANS (as you said). This script expects radians for angles,
  and will convert to axis-angle (SMPL expects radians).
- Missing joints are zeroed.

IMPORTANT: verify mapping and axis order for your data! Adjust EULER_ORDER per-joint if needed.
"""
import numpy as np
import pandas as pd
from scipy.spatial.transform import Rotation as R
from tqdm import tqdm
import argparse
import os

# check check

# ----------------- USER SETTINGS -----------------
CSV_FILE = r'C:\Users\steve\Documents\Dynamo_Research\dynamo_scripts\steadyspeed.csv'   
OUT_NPZ = r'C:\Users\steve\Documents\Dynamo_Research\dynamo_scripts\motion_smpl.npz'
# SMPL joints order (24 joints): AMASS/SMPL standard ordering usually:
SMPL_JOINT_NAMES = [
    'pelvis', 'left_hip', 'right_hip', 'spine1', 'left_knee', 'right_knee',
    'spine2', 'left_ankle', 'right_ankle', 'spine3', 'left_foot', 'right_foot',
    'neck', 'left_collar', 'right_collar', 'head', 'left_shoulder', 'right_shoulder',
    'left_elbow', 'right_elbow', 'left_wrist', 'right_wrist', 'left_hand', 'right_hand'
]
# -------------------------------------------------

# This mapping is a starting point: map your CSV columns -> (SMPL joint, channel_euler_triplet)
# Example: for pelvis we map pelvis_tilt, pelvis_list, pelvis_rotation as the 3 Euler angles.
# You must verify axis order (the code below assumes the angles are in the intended order).
# If your column names differ, change the keys to match CSV headers exactly.
COLUMN_MAP = {
    # SMPL pelvis
    'pelvis': ['pelvis_tilt', 'pelvis_list', 'pelvis_rotation'],
    # Root translation (SMPL expects trans separately)
    'trans': ['pelvis_tx', 'pelvis_ty', 'pelvis_tz'],
    # Right / left hip rotations (example channels)
    'right_hip': ['hip_flexion_r', 'hip_adduction_r', 'hip_rotation_r'],
    'left_hip': ['hip_flexion_l', 'hip_adduction_l', 'hip_rotation_l'],
    'right_knee': ['knee_angle_r', 'knee_angle_r', 'knee_angle_r'],  # knee is single DOF - we duplicate across axes
    'left_knee': ['knee_angle_l', 'knee_angle_l', 'knee_angle_l'],
    'right_ankle': ['ankle_angle_r', 'ankle_angle_r', 'ankle_angle_r'],
    'left_ankle': ['ankle_angle_l', 'ankle_angle_l', 'ankle_angle_l'],
    # lumbar/spine might map to several spine joints: we'll map lumbar to spine1/spine2/spine3
    'spine1': ['lumbar_extension', 'lumbar_bending', 'lumbar_rotation'],
    'spine2': ['lumbar_extension', 'lumbar_bending', 'lumbar_rotation'],
    'spine3': ['lumbar_extension', 'lumbar_bending', 'lumbar_rotation'],
    # minimal placeholders for upper body (zero if not present)
    'neck': [None, None, None],
    'left_collar': [None, None, None],
    'right_collar': [None, None, None],
    'head': [None, None, None],
    'left_shoulder': [None, None, None],
    'right_shoulder': [None, None, None],
    'left_elbow': [None, None, None],
    'right_elbow': [None, None, None],
    'left_wrist': [None, None, None],
    'right_wrist': [None, None, None],
    'left_foot': [None, None, None],
    'right_foot': [None, None, None],
    'left_hand': [None, None, None],
    'right_hand': [None, None, None]
}

# Per-joint Euler order: this is **critical**. Default: 'XYZ' for all.
# If your IK produced different axis order (e.g., flexion around X, adduction around Y), set that here.
EULER_ORDER = {jn: 'XYZ' for jn in SMPL_JOINT_NAMES}

def build_pose_vector_row(row, csv_cols):
    """
    Build one 72-dim SMPL pose vector from a pandas row.
    row: pandas Series for one frame (columns by name)
    csv_cols: list of csv column names
    """
    pose = np.zeros((24, 3))  # 24 SMPL joints, 3 axis-angle each
    # helper to read angle triple for a mapped joint key
    for j_idx, jname in enumerate(SMPL_JOINT_NAMES):
        mapping = COLUMN_MAP.get(jname, [None, None, None])
        if mapping[0] is None and mapping[1] is None and mapping[2] is None:
            # leave zeros (neutral pose)
            continue
        # collect three angle values (assume radians)
        angs = []
        for m in mapping:
            if m is None:
                angs.append(0.0)
            else:
                if m not in csv_cols:
                    raise KeyError(f'CSV missing expected column: {m}')
                angs.append(float(row[m]))
        # convert Euler angles (rad) -> rotation -> axis-angle (as vector)
        order = EULER_ORDER.get(jname, 'XYZ')
        # scipy Rotation.from_euler expects degrees=False if angles in radians
        r = R.from_euler(order, angs, degrees=False)
        # convert to axis-angle vector: magnitude = angle, direction = axis
        axis_angle = r.as_rotvec()  # gives rotation vector in radians (3 values)
        pose[j_idx, :] = axis_angle
    return pose.reshape((72,))  # flatten to 72-vector

def main():
    if not os.path.exists(CSV_FILE):
        raise FileNotFoundError(f'CSV file not found: {CSV_FILE}. Export your MATLAB table to CSV first.')

    df = pd.read_csv(CSV_FILE)
    csv_cols = df.columns.tolist()
    nframes = len(df)

    # Build poses array
    poses = np.zeros((nframes, 72), dtype=np.float32)
    trans = np.zeros((nframes, 3), dtype=np.float32)
    for i in tqdm(range(nframes), desc='Converting frames'):
        row = df.iloc[i]
        pose72 = build_pose_vector_row(row, csv_cols)
        poses[i, :] = pose72
        # translation (pelvis) - if not present, remain zeros
        tmap = COLUMN_MAP.get('trans', [None, None, None])
        if all((m in csv_cols) for m in tmap if m is not None):
            tx = float(row[tmap[0]])
            ty = float(row[tmap[1]])
            tz = float(row[tmap[2]])
            trans[i, :] = [tx, ty, tz]
        else:
            trans[i, :] = [0.0, 0.0, 0.0]

    # betas (shape) (use zeros as default; you can supply estimated betas from SMPL fitting)
    betas = np.zeros((10,), dtype=np.float32)
    gender = 'neutral'

    np.savez(OUT_NPZ, poses=poses, betas=betas, trans=trans, gender=gender)
    print(f'Saved SMPL .npz to {OUT_NPZ} (poses shape = {poses.shape}, trans shape = {trans.shape})')

if __name__ == '__main__':
    main()
