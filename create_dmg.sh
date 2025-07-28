#!/bin/bash

# DMG 创建脚本 - MacEasySymbol
# 使用方法: ./create_dmg.sh [options]
# 选项:
#   --app-path PATH    指定应用程序路径 (默认: ./signed-release/MacEasySymbol.app)
#   --output-dir DIR   指定输出目录 (默认: 当前目录)
#   --help             显示帮助信息

set -e  # 出错时退出

# 默认配置
APP_NAME="DevSwitcher2"
APP_PATH="./signed-release/DevSwitcher2.app"
OUTPUT_DIR="."
TEMP_DIR="./temp_dmg"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --app-path)
            APP_PATH="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --help)
            echo "DMG 创建脚本 - DevSwitcher2"
            echo ""
            echo "使用方法: $0 [options]"
            echo ""
            echo "选项:"
            echo "  --app-path PATH    指定应用程序路径 (默认: ./signed-release/MacEasySymbol.app)"
            echo "  --output-dir DIR   指定输出目录 (默认: 当前目录)"
            echo "  --help             显示此帮助信息"
            echo ""
            echo "示例:"
            echo "  $0"
            echo "  $0 --app-path /path/to/MacEasySymbol.app"
            echo "  $0 --output-dir ~/Desktop"
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            echo "使用 --help 查看帮助信息"
            exit 1
            ;;
    esac
done

echo "🚀 开始创建 DevSwitcher2 DMG..."
echo "📱 应用路径: $APP_PATH"
echo "📂 输出目录: $OUTPUT_DIR"

# 自动从 Info.plist 读取版本号
echo "读取应用版本信息..."
if [ -f "$APP_PATH/Contents/Info.plist" ]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" 2>/dev/null)
    BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP_PATH/Contents/Info.plist" 2>/dev/null)
    
    if [ -n "$VERSION" ]; then
        if [ -n "$BUILD" ] && [ "$BUILD" != "1" ]; then
            VERSION_STRING="${VERSION}.${BUILD}"
        else
            VERSION_STRING="${VERSION}"
        fi
        echo "检测到版本: $VERSION_STRING"
        DMG_NAME="DevSwitcher2-${VERSION_STRING}"
        VOLUME_NAME="DevSwitcher2 ${VERSION_STRING}"
    else
        echo "⚠️  无法读取版本号，使用默认名称"
        DMG_NAME="DevSwitcher2"
        VOLUME_NAME="DevSwitcher2"
    fi
else
    echo "⚠️  未找到 Info.plist，使用默认名称"
    DMG_NAME="DevSwitcher2"
    VOLUME_NAME="DevSwitcher2"
fi

# 确保输出目录存在
mkdir -p "$OUTPUT_DIR"

DMG_TEMP="temp_${DMG_NAME}.dmg"
DMG_FINAL="${OUTPUT_DIR}/${DMG_NAME}.dmg"

echo "DMG 文件名: $DMG_FINAL"
echo "卷标名称: $VOLUME_NAME"

# 检查应用程序是否存在
if [ ! -d "$APP_PATH" ]; then
    echo "❌ 错误: 未找到应用程序 $APP_PATH"
    echo "请先构建并签名应用程序"
    exit 1
fi

# 清理之前的临时文件
echo "清理之前的临时文件..."
rm -rf "$TEMP_DIR"
rm -f "$DMG_TEMP"
if [ -f "$DMG_FINAL" ]; then
    echo "删除现有的 $DMG_FINAL"
    rm -f "$DMG_FINAL"
fi

# 创建临时目录
mkdir -p "$TEMP_DIR"

# 复制 app 到临时目录
echo "复制应用程序..."
cp -R "$APP_PATH" "$TEMP_DIR/"

# 创建 Applications 文件夹的符号链接
echo "创建 Applications 链接..."
ln -s /Applications "$TEMP_DIR/Applications"

# 计算需要的大小（app 大小 + 一些余量）
APP_SIZE=$(du -sm "$APP_PATH" | cut -f1)
DMG_SIZE=$((APP_SIZE + 10))

# 创建临时 DMG
echo "创建临时 DMG..."
hdiutil create -srcfolder "$TEMP_DIR" -volname "$VOLUME_NAME" -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" -format UDRW -size ${DMG_SIZE}m "$DMG_TEMP"

# 挂载临时 DMG
echo "挂载 DMG 进行配置..."
MOUNT_DIR="/Volumes/$VOLUME_NAME"
hdiutil attach "$DMG_TEMP"

# 等待挂载完成
sleep 2

# 设置 Finder 视图选项（通过 AppleScript）
osascript <<EOD
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 880, 420}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 72
        # 不设置背景图片
        delay 1
        set position of item "$APP_NAME.app" of container window to {120, 120}
        set position of item "Applications" of container window to {360, 120}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOD

# 等待设置完成
sleep 3

# 卸载临时 DMG
echo "卸载临时 DMG..."
hdiutil detach "$MOUNT_DIR"

# 转换为最终的只读 DMG
echo "创建最终 DMG..."
hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL"

# 清理临时文件
echo "清理临时文件..."
rm -f "$DMG_TEMP"
rm -rf "$TEMP_DIR"

# 获取最终DMG文件大小
if [ -f "$DMG_FINAL" ]; then
    DMG_SIZE_MB=$(du -m "$DMG_FINAL" | cut -f1)
    echo ""
    echo "✅ DMG 创建完成!"
    echo "📦 文件名: $DMG_FINAL"
    echo "📏 文件大小: ${DMG_SIZE_MB}MB"
    echo "🏷️  卷标名称: $VOLUME_NAME"
    
    # 如果有版本号，显示更多信息
    if [ -n "$VERSION_STRING" ]; then
        echo "🔢 应用版本: $VERSION_STRING"
        if [ -n "$VERSION" ] && [ -n "$BUILD" ]; then
            echo "📋 版本详情: $VERSION (Build $BUILD)"
        fi
    fi
    
    echo ""
    echo "你可以通过以下方式分发这个DMG文件:"
    echo "1. 上传到 GitHub Releases"
    echo "2. 分享给用户直接下载"
    echo "3. 提交到应用商店审核"
else
    echo "❌ DMG 创建失败"
    exit 1
fi 