# iOS 真机测试指南

## 前置条件

- Mac 上已安装 Xcode（当前版本：26.4）
- 一台 iPhone（iOS 17.0 或更高版本）
- USB 数据线（Lightning 或 USB-C）
- Apple ID（免费账号即可，无需付费开发者计划）

---

## 第一步：连接 iPhone

1. 用 USB 数据线将 iPhone 连接到 Mac
2. iPhone 上弹出「是否信任此电脑？」→ 点击 **信任** 并输入锁屏密码
3. 如果 Mac 弹出「是否允许 USB 配件连接？」→ 点击 **允许**

### 验证连接

打开终端运行：
```bash
xcrun devicectl list devices
```
应该能看到你的 iPhone 型号和 UDID。

---

## 第二步：打开 Xcode 项目

在终端运行：
```bash
open /Volumes/Data_2T/Applications/Xcode.app /Users/jacksonhuang/Desktop/健康数据/HealthAnalyzerApp/HealthAnalyzerApp.xcodeproj
```

或者手动：双击 `HealthAnalyzerApp.xcodeproj` 文件，系统会用 Xcode 打开。

---

## 第三步：配置签名

这是**最关键**的一步，确保 App 能安装到真机上。

1. 在 Xcode **左侧导航栏**点击顶部的 **HealthAnalyzerApp**（蓝色项目图标）
2. 在中间面板选择 **TARGET** → **HealthAnalyzerApp**
3. 点击 **Signing & Capabilities** 标签页
4. 勾选 ✅ **Automatically manage signing**
5. 在 **Team** 下拉菜单中：
   - 如果已有 Apple ID → 直接选择你的账号（显示为 `你的名字 (Personal Team)`）
   - 如果没有 → 点击 **Add Account...** → 用你的 Apple ID 和密码登录
6. 等待 Xcode 自动生成证书和配置文件（大约几秒钟）

### 确认 HealthKit 权限

在同一个 **Signing & Capabilities** 页面：
- 确认列表中有 **HealthKit** 一项（带心形图标）
- 如果没有 → 点击 **+ Capability** → 搜索 **HealthKit** → 双击添加

### 常见签名问题

| 问题 | 解决方案 |
|------|----------|
| "Failed to register bundle identifier" | Bundle ID 可能被占用。在 **General** 标签页修改 Bundle Identifier（如改为 `com.你的名字.healthanalyzer`） |
| "No signing certificate" | 确保在 Team 中选择了正确的 Apple ID |
| "Untrusted developer" | 见第五步 |

---

## 第四步：选择设备并编译运行

1. 在 Xcode **顶部工具栏**中间找到设备选择器（默认可能显示 "Any iOS Device" 或某个模拟器）
2. 点击下拉 → 在 **iOS Device** 部分找到你的 iPhone（显示为 `你的iPhone名 (iPhone XX)`）
3. 按 **Command + R** 编译并运行

### 首次编译可能需要 1-2 分钟

如果看到进度条在 Xcode 顶部移动，就是正在编译中。

---

## 第五步：信任开发者证书（首次必须）

首次安装后，App 可能无法打开，iPhone 会弹出警告：

1. 打开 iPhone **设置**
2. 进入 **通用** → **VPN 与设备管理**（或 **描述文件与设备管理**）
3. 找到你的 Apple ID 开发者证书
4. 点击 **信任 "你的 Apple ID"** → 确认 **信任**
5. 返回桌面，重新打开 App

> ⚠️ 免费开发者证书有效期 7 天，过期后需要重新在 Xcode 中运行安装。

---

## 第六步：使用 App

### 引导页（首次启动）

App 首次打开会显示 3 页引导：

1. **健康数据分析** — 功能介绍
2. **智能图表可视化** — 图表说明
3. **隐私优先** — 数据安全说明

滑动到最后一页，点击 **「授权并开始分析」**。

### HealthKit 授权弹窗

系统会弹出 HealthKit 权限请求：

- **建议：全部开启所有类型**（点击右上角「全部打开」）
- 包括：步数、心率、体重、VO2 Max、HRV、运动记录等
- 点击 **「允许」**

### 数据加载

授权后 App 自动开始读取数据：

```
请求健康数据授权...  →  5%
正在读取运动记录...   →  15%
正在读取健康指标...   →  40%
正在读取骑行路线...   →  60%
正在生成分析报告...   →  80%
完成！              →  100%
```

### 仪表盘

加载完成后自动跳转到交互式仪表盘，包含：

- **总览**：运动类型分布饼图、每周运动量等
- **骑行/力训/跑步**：各运动详细分析
- **身体趋势**：VO2 Max、心率变异性、体重变化等
- **时间范围选择**：1月 / 3月 / 半年 / 1年 / 全部

所有图表支持交互（点击查看详情）。

---

## 故障排查

### "此设备不支持 HealthKit"

- 确保你使用的是 iPhone（不是 iPod touch）
- 确保 iOS 版本 ≥ 17.0

### 加载后没有数据 / 图表为空

- 检查 iPhone 的「健康」App 中是否有数据
- 确保你在 HealthKit 授权弹窗中允许了所有类型
- 去 设置 → 隐私与安全 → 健康 → 健康分析 → 确认权限已打开

### 编译错误："Provisioning profile doesn't include..."

- 在 Xcode 中修改 Bundle Identifier 为一个唯一的值
- 例如：`com.你的名字.healthanalyzer.dev`

### 真机无法连接

- 确保 USB 线支持数据传输（有些线只能充电）
- 尝试重新拔插
- 在 iPhone 上重新信任此电脑

---

## 项目文件说明

```
HealthAnalyzerApp/
├── HealthAnalyzerApp.xcodeproj   ← Xcode 项目文件（双击打开）
├── HealthAnalyzerApp/
│   ├── App.swift                  ← 应用入口
│   ├── ContentView.swift          ← 主视图状态机
│   ├── Views/
│   │   ├── OnboardingView.swift   ← 引导页（3页）
│   │   ├── LoadingView.swift      ← 加载动画
│   │   └── DashboardWebView.swift ← WKWebView 仪表盘
│   ├── HealthKit/
│   │   ├── HealthKitManager.swift ← HealthKit 授权+查询
│   │   └── DataTransformer.swift  ← 数据转 JSON
│   ├── Resources/
│   │   └── dashboard.html         ← 交互式仪表盘
│   ├── Assets.xcassets/           ← App Icon + 颜色
│   ├── Info.plist                 ← 应用配置
│   └── HealthAnalyzerApp.entitlements ← HealthKit 权限声明
├── setup.sh                       ← 自动化设置脚本
├── generate_project.py            ← 项目文件生成器
└── project.yml                    ← XcodeGen 配置
```
