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

echo [白守] 正在从 %PROJECT_ROOT% 启动翻译文件与代码生成的监听模式...
echo [提示] 按 Ctrl+C 可以停止监听。
pushd %PROJECT_ROOT%

:: 同时启动 slang 监听翻译文件和 build_runner 监听代码生成
:: /b 表示在同一个窗口运行，输出会混合
start /b dart run slang watch
call dart run build_runner watch --delete-conflicting-outputs

if %errorlevel% neq 0 (
    echo [错误] 监听模式异常退出，退出码：%errorlevel%。
)
popd

pause
