# ExpenseTracker 记账助手

## 项目概述

ExpenseTracker是一款基于SwiftUI开发的iOS记账应用，旨在帮助用户轻松管理个人财务、设置预算并追踪支出。应用采用了MVVM架构设计，结合了CoreData本地存储和后端API交互功能，提供了良好的用户体验和数据管理能力。

## 主要功能

### 1. 用户认证
- 用户注册和登录功能
- 基于Token的身份验证
- 自动登录机制

### 2. 预算管理
- 创建和设置月度预算
- 修改和删除预算
- 预算使用情况可视化显示

### 3. 支出记录（开发中）
- 记录日常支出
- 分类管理支出
- 查看支出历史

### 4. 数据分析（开发中）
- 支出趋势分析
- 分类支出统计
- 预算执行率分析

### 5. 用户设置（开发中）
- 个人资料管理
- 应用首选项设置
- 通知管理

## 技术架构

### 前端架构
- **UI框架**: SwiftUI
- **架构模式**: MVVM (Model-View-ViewModel)
- **状态管理**: Combine框架
- **本地存储**: CoreData

### 后端交互
- **网络层**: 基于URLSession的网络管理器
- **数据格式**: JSON
- **认证机制**: JWT Token
- **API基地址**: http://localhost:3000/api

## 项目结构

```
ExpenseTracker/
├── Core/                    # 核心功能模块
│   ├── Extensions/          # Swift扩展
│   ├── Models/              # 通用数据模型
│   └── Network/             # 网络请求相关
├── Features/                # 功能模块
│   ├── Authentication/      # 用户认证
│   │   ├── Models/          # 认证相关模型
│   │   ├── Services/        # 认证服务
│   │   ├── ViewModels/      # 认证视图模型
│   │   └── Views/           # 认证界面
│   ├── Budget/              # 预算管理
│   │   ├── Models/          # 预算相关模型
│   │   ├── Services/        # 预算服务
│   │   ├── ViewModels/      # 预算视图模型
│   │   └── Views/           # 预算界面
│   └── Home/                # 首页
│       └── Views/           # 首页界面
├── ExpenseTracker.xcdatamodeld/ # CoreData模型
└── Assets.xcassets/         # 资源文件
```

## 开发环境

- **开发工具**: Xcode 15+
- **Swift版本**: Swift 5.0+
- **iOS版本**: iOS 16.0+
- **依赖管理**: Swift Package Manager

## 安装与运行

1. 克隆项目代码库
```bash
git clone https://github.com/username/ExpenseTracker.git
```

2. 使用Xcode打开ExpenseTracker.xcodeproj

3. 配置后端API地址
   - 在`Core/Network/APIConfig.swift`中设置正确的后端API地址

4. 运行项目
   - 选择目标设备或模拟器
   - 点击运行按钮或使用快捷键Command+R

## 后端服务

ExpenseTracker需要连接到后端API服务才能实现完整功能。可以使用以下方式设置后端：

1. 本地开发服务器
   - 默认配置为`http://localhost:3000/api`
   - 需要先启动本地后端服务

2. 远程API服务
   - 修改`APIConfig.swift`中的baseURL为实际部署的API地址

## 项目进度

- [x] 项目基础架构搭建
- [x] 用户认证功能
- [x] 预算管理功能
- [ ] 支出记录功能
- [ ] 数据分析功能
- [ ] 用户设置功能

## 贡献指南

欢迎为ExpenseTracker项目做出贡献！贡献方式包括：

1. 提交问题和建议
2. 修复错误和实现新功能
3. 改进文档

## 许可证

本项目采用MIT许可证。详情请参阅LICENSE文件。

## 联系方式

如有任何问题或建议，请通过以下方式联系：

- 电子邮件: example@example.com
- GitHub Issues: [ExpenseTracker Issues](https://github.com/username/ExpenseTracker/issues) 