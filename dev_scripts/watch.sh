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

echo "[白守] 正在从 $PROJECT_ROOT 启动翻译文件与代码生成的监听模式..."
cd "$PROJECT_ROOT"

# 同时启动 slang 监听翻译文件和 build_runner 监听代码生成
dart run slang watch &
dart run build_runner watch --delete-conflicting-outputs

if [ $? -ne 0 ]; then
    echo "[错误] 监听模式异常退出。"
    read -p "按回车键退出..."
fi
