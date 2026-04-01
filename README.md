<p align="center">
  <img src="screenshots/overview.png" width="800" />
</p>

<h1 align="center">Apple Health Analyzer</h1>

<p align="center">
  <strong>将 Apple Health 导出数据转化为精美的交互式分析仪表板</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/python-3.8+-blue?logo=python&logoColor=white" />
  <img src="https://img.shields.io/badge/platform-macOS%20|%20Windows-lightgrey?logo=apple" />
  <img src="https://img.shields.io/badge/license-MIT-green" />
  <img src="https://img.shields.io/badge/chart.js-4.4-orange?logo=chartdotjs" />
</p>

---

## 功能特性

**一键解析** iPhone 健康数据导出（XML + GPX），自动生成一个完全自包含的 HTML 报告，双击即可打开 — 无需服务器、无需网络。

### 四大分析维度

| 维度 | 分析内容 |
|------|---------|
| **总览** | 运动类型时长分布、每周运动总时长、VO2 Max 趋势、体重变化、每日步数与活动热量 |
| **骑行** | 通勤路线自动识别、均速趋势与线性回归、心率趋势、每周距离/频率、心率效率散点、力训干扰分析、骑行日状态评分 |
| **力量训练** | 每周频率与总时长、平均心率趋势、单次时长趋势、活动热量趋势、力训次数 vs 骑行均速关联 |
| **身体趋势** | 静息心率 & HRV 双轴图、VO2 Max 含线性趋势线、体重趋势、步行心率、每日步数、活动热量 |

### 交互功能

- **时间范围选择器** — 1 个月 / 3 个月 / 半年 / 1 年 / 全部
- **多标签页切换** — 总览 / 骑行 / 力量训练 / 身体趋势
- **路线聚类** — 基于 GPS 坐标自动识别通勤/常走路线
- **趋势分析** — 线性回归、均值参考线、前后半段对比

---

## 截图演示

<details>
<summary><b>🚴 骑行分析</b> — 通勤均速、心率趋势、距离频率、心率效率</summary>
<br>
<img src="screenshots/cycling.png" width="800" />
</details>

<details>
<summary><b>🏋️ 力量训练</b> — 周频率/时长、心率趋势、热量趋势、力训 vs 骑行</summary>
<br>
<img src="screenshots/strength.png" width="800" />
</details>

<details>
<summary><b>💓 身体趋势</b> — 静息心率/HRV、VO2 Max、体重、步行心率、步数</summary>
<br>
<img src="screenshots/body.png" width="800" />
</details>

---

## 快速开始

### 方式一：Python 脚本（推荐）

```bash
# 1. 克隆仓库
git clone https://github.com/JacksonHuang517/apple-health-analyzer.git
cd apple-health-analyzer

# 2. 创建虚拟环境
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 3. 安装依赖（无额外依赖，仅标准库）
# Python 3.8+ 即可，无需 pip install

# 4. 运行分析
python3 HealthCyclingAnalyzer.py
```

运行后会弹出文件夹选择窗口，选择 Apple Health 导出目录（包含 `导出.xml` 的那个文件夹），程序会自动：
1. 解析 XML 数据和 GPX 路线文件
2. 生成 `analysis_data.json`（结构化数据）
3. 生成 `report.html`（自包含报告，双击即可查看）
4. 自动在浏览器中打开报告

### 方式二：macOS 桌面应用

```bash
# 安装依赖
pip install pyinstaller customtkinter tkinterdnd2

# 构建 .app
pyinstaller build.spec --clean -y
```

构建完成后在 `dist/` 目录下找到 `Apple Health Analyzer.app`，双击运行。

### 方式三：Windows

```bash
# 直接运行批处理脚本（自动安装依赖并构建）
build_windows.bat
```

构建完成后在 `dist\Apple Health Analyzer\` 目录下找到可执行文件。

---

## 数据导出指南

### 第一步：从 iPhone 导出健康数据

1. 打开 iPhone 上的 **「健康」** App（白底红心图标）
2. 点击右上角 **个人头像**
3. 滚动到页面最底部，点击 **「导出所有健康数据」**
4. 系统会提示"正在准备导出数据"，根据数据量可能需要 **1-10 分钟**
5. 导出完成后弹出分享菜单

### 第二步：传输到电脑

| 方式 | 说明 |
|------|------|
| **AirDrop**（推荐） | Mac 用户最快的方式，直接发送到电脑 |
| **隔空投送到文件** | 保存到"文件" App，通过 iCloud Drive 同步 |
| **邮件 / 微信** | 通过邮件或微信发送（文件可能较大，约 50-200MB） |
| **数据线** | 连接电脑，通过 Finder / iTunes 传输 |

### 第三步：解压并使用

1. 收到的文件名为 `导出.zip`
2. **双击解压**，得到 `apple_health_export` 文件夹
3. 文件夹内包含：
   ```
   apple_health_export/
   ├── 导出.xml          ← 主数据文件（所有健康记录）
   ├── 导出_cda.xml      ← 临床数据（可忽略）
   └── workout-routes/   ← GPS 路线数据
       ├── route_2026-01-05.gpx
       ├── route_2026-01-06.gpx
       └── ...
   ```
4. 运行本程序，**选择 `apple_health_export` 文件夹**即可

> **提示**：导出的 XML 文件可能很大（100MB-1GB+），解析需要几十秒到几分钟，请耐心等待。

### 程序读取的数据

| 数据类型 | Apple Health 标识 |
|---------|------------------|
| 骑行 / 力训 / 其他运动 | `Workout` 元素 + `WorkoutStatistics` |
| GPS 路线 & 实时速度 | `workout-routes/*.gpx` |
| 静息心率 | `RestingHeartRate` |
| 心率变异性 (HRV) | `HeartRateVariabilitySDNN` |
| VO2 Max | `VO2Max` |
| 体重 | `BodyMass` |
| 步数 | `StepCount` |
| 活动热量 | `ActiveEnergyBurned` |
| 步行心率 | `WalkingHeartRateAverage` |

---

## 技术栈

| 组件 | 技术 |
|------|------|
| 桌面 GUI | [CustomTkinter](https://github.com/TomSchimansky/CustomTkinter) — macOS / Windows 11 原生风格自适应 |
| 数据解析 | Python 3 标准库（`xml.etree.ElementTree`） |
| 路线分析 | Haversine 距离计算 + 坐标聚类 |
| 可视化 | [Chart.js 4.4](https://www.chartjs.org/)（内嵌，零 CDN 依赖） |
| 前端设计 | Apple Design 风格（SF Pro 字体、Apple Health 配色、圆角卡片） |
| 图标系统 | 内嵌 SVG 图标徽章（Lucide 风格） |
| 拖拽支持 | [tkinterdnd2](https://github.com/pmgagne/tkinterdnd2) — 文件夹拖放识别 |
| 桌面打包 | PyInstaller |

---

## 项目结构

```
.
├── HealthCyclingAnalyzer.py   # 核心解析与报告生成
├── dashboard.html             # 仪表板 HTML 模板
├── build.spec                 # PyInstaller 构建配置（macOS）
├── build_windows.bat          # Windows 构建脚本
├── screenshots/               # README 截图
└── README.md
```

---

## License

MIT License — 自由使用，欢迎贡献。
