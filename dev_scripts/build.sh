#!/bin/bash

# 自动探测项目根目录
if [ -f "pubspec.yaml" ]; then
    PROJECT_ROOT="."
elif [ -f "../pubspec.yaml" ]; then
    PROJECT_ROOT=".."
else
    echo "[错误] 找不到 pubspec.yaml。"
    exit 1
fi

echo "[白守] 正在从 $PROJECT_ROOT 运行 build_runner..."
cd "$PROJECT_ROOT"
dart run build_runner build --delete-conflicting-outputs

if [ $? -ne 0 ]; then
    echo "[错误] build_runner 运行失败。"
    read -p "按回车键退出..."
fi
