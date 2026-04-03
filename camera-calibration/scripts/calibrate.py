#!/usr/bin/env python3
import cv2
import numpy as np
import os
import glob
import json
import argparse
import sys
import re

def run_calibration_loop(objpoints, imgpoints, img_size, image_names):
    objpoints_fish = [np.reshape(o, (1, -1, 3)) for o in objpoints]
    flags = (cv2.fisheye.CALIB_RECOMPUTE_EXTRINSIC + 
             cv2.fisheye.CALIB_CHECK_COND + 
             cv2.fisheye.CALIB_FIX_SKEW)
    
    try:
        _, K_init, _, _, _ = cv2.calibrateCamera(objpoints, imgpoints, img_size, None, None)
        flags |= cv2.fisheye.CALIB_USE_INTRINSIC_GUESS
    except:
        K_init = np.eye(3, dtype=np.float32)
        K_init[0,0] = K_init[1,1] = img_size[0] / 2
        K_init[0,2] = img_size[0] / 2
        K_init[1,2] = img_size[1] / 2

    current_obj, current_img, current_names = list(objpoints_fish), list(imgpoints), list(image_names)
    skipped = []

    while len(current_img) >= 4:
        try:
            K, D = np.zeros((3, 3)), np.zeros((4, 1))
            rms, _, _, _, _ = cv2.fisheye.calibrate(
                current_obj, current_img, img_size, K, D, flags=flags,
                criteria=(cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 100, 1e-6))
            return K, D, rms, current_names, skipped
        except cv2.error as e:
            match = re.search(r"input array (\d+)", str(e))
            if match:
                idx = int(match.group(1))
                skipped.append(current_names.pop(idx))
                current_obj.pop(idx); current_img.pop(idx)
                continue
            if flags & cv2.fisheye.CALIB_CHECK_COND:
                flags &= ~cv2.fisheye.CALIB_CHECK_COND
                continue
            skipped.append(current_names.pop()); current_obj.pop(); current_img.pop()
    return None, None, None, None, skipped

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input_dir", required=True)
    parser.add_argument("--output_file", required=True)
    parser.add_argument("--rows", type=int, default=7)
    parser.add_argument("--cols", type=int, default=11)
    args = parser.parse_args()

    size = (args.cols, args.rows)
    images = sorted(glob.glob(os.path.join(args.input_dir, "*.[jp][pn]g")))
    if not images: sys.exit(1)

    all_objp, all_imgp, names, img_size = [], [], [], None
    objp = np.zeros((size[0] * size[1], 3), np.float32)
    objp[:, :2] = np.mgrid[0:size[0], 0:size[1]].T.reshape(-1, 2)

    for fname in images:
        img = cv2.imread(fname)
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        if img_size is None: img_size = gray.shape[::-1]
        ret, corners = cv2.findChessboardCorners(gray, size, cv2.CALIB_CB_ADAPTIVE_THRESH + cv2.CALIB_CB_NORMALIZE_IMAGE)
        if ret:
            all_objp.append(objp)
            all_imgp.append(cv2.cornerSubPix(gray, corners, (3, 3), (-1, -1), (cv2.TERM_CRITERIA_EPS+cv2.TERM_CRITERIA_MAX_ITER, 30, 0.001)))
            names.append(os.path.basename(fname))

    K, D, rms, valid, skipped = run_calibration_loop(all_objp, all_imgp, img_size, names)
    if K is not None:
        with open(args.output_file, "w") as f:
            json.dump({"camera_matrix": K.tolist(), "dist_coeff": D.tolist(), "rms": rms, "img_size": img_size, "used": valid, "skipped": skipped}, f, indent=4)
        print(f"Success! RMS: {rms}")
    else: print("Failed.")

if __name__ == "__main__": main()
