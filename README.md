# 白守 (BaiShou)

> 以纯白誓约，守护彼此一生。

**吉祥物：** 白守狐/小白
![BaiShou Banner](assets/icon/icon.png)

## 简介

**白守 (BaiShou)** 不仅仅是一个日记应用，它是为了对抗遗忘而构建的"灵魂容器"。

这是一款运行在本地的、注重隐私的、具有 AI 辅助分析功能的日记与生活记录应用。它的核心理念是将碎片化的日常记录，通过层级化的 AI 总结（日记 -> 周记 -> 月报 -> 季报 -> 年鉴），编织成一部完整的个人史。

## 核心特性

- **数据私有**：基于 Flutter + SQLite 开发，所有数据存储在本地，不上传任何服务器（付费用户会获取云同步功能，上传的数据加密，不被开发团队查看）。
- **AI 智能总结**：
  - 支持 Google Gemini 和 OpenAI (DeepSeek/ChatGPT) 等多种 AI 模型。
  - **自动层级总结**：AI 会自动阅读你的日记，生成周记；阅读周记，生成月报……以此类推，构建记忆的金字塔。
  - **历史归档逻辑**：严格的时间锁机制，只有当周期完全结束后（如2月过完），才允许生成该周期的总结，确保记忆的完整性。
- **LifeBook 系统**：
  - 多级视图：日、周、月、季、年，五个维度的记忆切片。
  - 标签与心情追踪：记录生活的情绪起伏。
- **自定义配置**：
  - 用户可自选 AI 提供商，配置自己的 API Key 和 Base URL。
  - 灵活的设置选项，适配不同的使用习惯。

## 技术栈

- **前端**：Flutter (Dart)
- **状态管理**：Riverpod
- **本地数据库**：SQLite (Drift)
- **AI集成**：HTTP REST API (Gemini / OpenAI Compatible)

## 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/Anson-Trio/BaiShou.git
cd BaiShou
```

### 2. 安装依赖

```bash
flutter pub get
```

### 3. 运行

```bash
flutter run
```

### 4. 配置 AI

进入 App 后，点击右上角设置图标 -> **AI 配置**：

- 选择 AI 提供商 (Gemini 或 OpenAI)。
- 输入你的 API Key (和 Base URL)。
- 点击"测试连接"确保配置正确。

## 贡献指南

虽然目前主要由 Anson、樱和晓三人开发，但我们非常欢迎 Issue 和 PR！如果你有好的想法，请随时告诉我们。

## 📄 开源协议 (License)

本项目采用 **GPL v3** 协议开源。

- 客户端代码完全开源，鼓励社区参与改进。
- 请遵守 GPL v3 协议：如果您修改了本项目的代码并发布，您的修改版本也必须开源。

---

## 许可证

MIT License

Copyright (c) 2026 Anson & Kasumiame Sakura & Tenkou Akatsuki
