@echo off
setlocal

:: 检查当前是否在项目根目录或脚本目录
if exist pubspec.yaml (
    set PROJECT_ROOT=.
) else if exist ..\pubspec.yaml (
    set PROJECT_ROOT=..
) else (
    echo [错误] 找不到 pubspec.yaml。请在项目根目录或 dev_scripts 文件夹中运行此脚本。
    pause
    exit /b 1
)

echo [白守] 正在从 %PROJECT_ROOT% 运行代码生成任务...
pushd %PROJECT_ROOT%

:: 先生成翻译文件
echo [白守] 正在生成翻译文件...
call dart run slang
if %errorlevel% neq 0 (
    echo [错误] 翻译文件生成失败。
)

:: 再运行 build_runner
echo [白守] 正在运行 build_runner...
call dart run build_runner build --delete-conflicting-outputs
if %errorlevel% neq 0 (
    echo [错误] build_runner 运行失败，退出码：%errorlevel%。
) else (
    echo [白守] 代码生成任务圆满完成。
)
popd

pause
