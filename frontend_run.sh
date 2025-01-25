#!/bin/bash

cd MiniCPM-o-demo-script || { echo "没有找到MiniCPM-o-demo-script目录,请返回根目录。"; exit 1; }

# 指定端口号
PORT=8088

# 文件目录
DIRECTORY="./frontend/dist"

# http.server
python3 -m http.server $PORT --directory $DIRECTORY