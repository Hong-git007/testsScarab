#!/usr/bin/env python3
# -*- coding: utf-8 -*-
from shutil import copy
from os import mkdir, path
import sys
import os

# --- 인수 확인 ---
if len(sys.argv) < 2:
    print('Usage: python updateTraceModulePaths.py [trace directory]')
    exit()

traceDir = sys.argv[1]

# --- bin 폴더 생성 ---
binPath = os.path.join(traceDir, 'bin')
if not path.exists(binPath):
    mkdir(binPath)

# --- modules.log 처리 ---
modules_log_path = os.path.join(traceDir, 'raw', 'modules.log')
data = []

try:
    print(f"[INFO] Portabilizing trace using log file: {modules_log_path}")
    with open(modules_log_path, 'r', encoding='ISO-8859-1') as infile:
        separator = ', '
        first = True
        col = 99
        for line in infile:
            s = line.split(separator)
            if first:
                ss = s[0].split(' ')
                first = False
                if len(ss) < 4 or ss[2] != 'version':
                    print('Corrupt file format: ' + str(ss))
                    exit()
                else:
                    if ss[3] == '5':
                        col = 8
                    elif int(ss[3]) < 5:
                        col = 7
                    else:
                        print('new file format, please add support')
                        exit()

            if len(s) < col + 1 or not s[col].startswith('/'):
                data.append(line)
                continue

            libPath = s[col].strip()
            libName = path.basename(libPath)
            newLibPath = path.abspath(os.path.join(binPath, libName))

            if not path.exists(newLibPath) and path.exists(libPath):
                if not path.samefile(libPath, newLibPath):
                    copy(libPath, binPath)

            s[col] = newLibPath
            data.append(separator.join(s))

    with open(modules_log_path, 'w', encoding='ISO-8859-1') as outfile:
        for wline in data:
            outfile.write(wline if wline.endswith('\n') else wline + '\n')

    print("[SUCCESS] Portability step completed.")

except FileNotFoundError:
    print(f"[WARNING] {modules_log_path} not found. Skipping portability step.")
