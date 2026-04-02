#!/bin/bash
# Setup script for HealthAnalyzerApp iOS project
# Run this after installing Xcode

set -e

cd "$(dirname "$0")"

echo "=== 健康数据分析 iOS App - 项目设置 ==="

# Check Xcode
if ! xcode-select -p &>/dev/null; then
    echo "❌ 请先安装 Xcode"
    exit 1
fi

echo "✓ Xcode 已检测到: $(xcodebuild -version 2>/dev/null | head -1)"

# Try xcodegen first
if command -v xcodegen &>/dev/null; then
    echo "→ 使用 XcodeGen 生成项目..."
    xcodegen generate
    echo "✓ 项目生成成功！"
else
    echo "→ XcodeGen 未安装，尝试安装..."
    if brew install xcodegen 2>/dev/null; then
        xcodegen generate
        echo "✓ 项目生成成功！"
    else
        echo "→ XcodeGen 安装失败，使用备选方案..."
        echo ""
        echo "请手动在 Xcode 中创建项目："
        echo "  1. 打开 Xcode → Create New Project → iOS App"
        echo "  2. Product Name: HealthAnalyzerApp"
        echo "  3. Bundle Identifier: com.jacksonhuang.healthanalyzer"
        echo "  4. Interface: SwiftUI, Language: Swift"
        echo "  5. 选择保存到当前目录的上级目录"
        echo "  6. 删除默认生成的 ContentView.swift"
        echo "  7. 将 HealthAnalyzerApp/ 文件夹下的所有文件拖入项目"
        echo "  8. 在 Signing & Capabilities 中添加 HealthKit"
        echo ""
        echo "或者运行以下命令生成最小化项目文件："
        echo "  python3 generate_project.py"
        exit 0
    fi
fi

echo ""
echo "=== 设置完成 ==="
echo "打开项目: open HealthAnalyzerApp.xcodeproj"
echo ""
echo "首次运行步骤："
echo "  1. 在 Xcode 中选择你的开发者团队 (Signing & Capabilities)"
echo "  2. 选择目标设备（建议使用真机 iPhone）"
echo "  3. Command+R 运行"
