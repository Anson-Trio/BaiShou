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

echo "[白守] 正在从 $PROJECT_ROOT 运行代码生成任务..."
cd "$PROJECT_ROOT"

# 先生成翻译文件
echo "[白守] 正在生成翻译文件..."
dart run slang

# 再运行 build_runner
echo "[白守] 正在运行 build_runner..."
dart run build_runner build --delete-conflicting-outputs

if [ $? -ne 0 ]; then
    echo "[错误] 运行失败。"
    read -p "按回车键退出..."
else
    echo "[白守] 代码生成任务圆满完成。"
fi
