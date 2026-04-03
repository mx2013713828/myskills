#!/usr/bin/env python3
import cv2
import numpy as np
import os
import glob
import json
import argparse

def process_matlab(img, config, scale=0.6):
    coeffs = config['mappingCoefficients']
    center = config['DistortionCenter']
    h, w = img.shape[:2]
    u, v = np.meshgrid(np.arange(w), np.arange(h))
    x, y = u - w/2, v - h/2
    r_p = np.sqrt(x**2 + y**2)
    theta = np.arctan2(r_p, coeffs[0] * scale)
    r_f = sum(c * (theta**i) for i, c in enumerate(coeffs, 1))
    mask = r_p > 0
    s = np.zeros_like(r_p)
    s[mask] = r_f[mask] / r_p[mask]
    return cv2.remap(img, (x * s + center[0]).astype(np.float32), (y * s + center[1]).astype(np.float32), cv2.INTER_LINEAR)

def process_opencv(img, config, balance=0.0):
    K, D, size = np.array(config['camera_matrix']), np.array(config['dist_coeff']), tuple(config['img_size'])
    nk = cv2.fisheye.estimateNewCameraMatrixForUndistortRectify(K, D, size, np.eye(3), balance=balance)
    m1, m2 = cv2.fisheye.initUndistortRectifyMap(K, D, np.eye(3), nk, size, cv2.CV_16SC2)
    return cv2.remap(img, m1, m2, cv2.INTER_LINEAR)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--config", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--scale", type=float, default=0.6)
    parser.add_argument("--balance", type=float, default=0.0)
    args = parser.parse_args()

    with open(args.config, 'r') as f: config = json.load(f)
    os.makedirs(args.output, exist_ok=True)
    
    files = glob.glob(os.path.join(args.input, "*.[jp][pn]g")) if os.path.isdir(args.input) else [args.input]
    for fpath in files:
        img = cv2.imread(fpath)
        dst = process_matlab(img, config, args.scale) if 'mappingCoefficients' in config else process_opencv(img, config, args.balance)
        cv2.imwrite(os.path.join(args.output, os.path.basename(fpath)), dst)
    print("Done.")

if __name__ == "__main__": main()
