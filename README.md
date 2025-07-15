# 文件分卷合并工具

[![Build Cross-Platform](https://github.com/diy-x/merger/actions/workflows/build.yml/badge.svg)](https://github.com/diy-x/merger/actions/workflows/build.yml)

一个用 Zig 语言编写的文件分卷合并工具，用于合并由 `split` 命令生成的分卷文件。

## 功能特性

- 🔄 自动识别并按顺序合并分卷文件
- 📊 显示处理进度和文件大小
- ✅ 验证分卷序列的完整性
- 🚀 高性能文件处理
- 🌐 跨平台支持（Windows、Linux、macOS）

## 下载

您可以从 [Releases](https://github.com/你的用户名/merger/releases) 页面下载预编译的二进制文件：

- **Linux x86_64**: `merger-linux-x86_64`
- **Linux ARM64**: `merger-linux-aarch64`  
- **Windows x86_64**: `merger-windows-x86_64.exe`
- **macOS x86_64**: `merger-macos-x86_64`
- **macOS ARM64**: `merger-macos-aarch64`

## 使用方法

```bash
./merger <输入目录> <输出文件名>
```

### 示例

```bash
# Linux/macOS
./merger ./parts ubuntu-24.04.img.xz

# Windows
merger.exe ./parts ubuntu-24.04.img.xz
```

### 参数说明

- `<输入目录>`: 包含 `.part` 文件的目录
- `<输出文件名>`: 合并后的文件名

工具会自动识别目录中的所有分卷文件（格式：`filename.part1`, `filename.part2`, ...），并按顺序合并它们。

## 构建说明

### 环境要求

- Zig 0.14.1 或更高版本

### 本地构建

```bash
# 克隆仓库
git clone https://github.com/你的用户名/merger.git
cd merger

# 构建
zig build

# 运行测试
zig build test

# 构建优化版本
zig build -Doptimize=ReleaseSafe
```

### 交叉编译

```bash
# 构建 Windows 版本
zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-windows

# 构建 Linux ARM64 版本
zig build -Doptimize=ReleaseSafe -Dtarget=aarch64-linux

# 构建 macOS ARM64 版本
zig build -Doptimize=ReleaseSafe -Dtarget=aarch64-macos
```

## 自动化构建

项目使用 GitHub Actions 进行自动化构建和发布：

### 构建工作流

- **触发条件**: 每次推送到 `main`/`master` 分支或创建 Pull Request
- **构建平台**: Ubuntu、Windows、macOS
- **构建架构**: x86_64、ARM64
- **构建模式**: ReleaseSafe（优化版本）

### 发布工作流

- **触发条件**: 推送带有 `v*` 格式的标签
- **自动功能**: 创建 GitHub Release 并上传所有平台的二进制文件

### 创建发布

```bash
# 创建并推送标签
git tag v1.0.0
git push origin v1.0.0
```

发布工作流会自动：
1. 创建 GitHub Release
2. 构建所有平台的二进制文件
3. 上传二进制文件到 Release

## 项目结构

```
merger/
├── .github/
│   └── workflows/
│       ├── build.yml      # 构建工作流
│       └── release.yml    # 发布工作流
├── src/
│   ├── main.zig          # 主程序入口
│   └── root.zig          # 库入口
├── build.zig             # 构建脚本
├── build.zig.zon         # 项目配置
└── README.md
```

## 错误处理

工具会处理以下错误情况：

- 目录不存在或无法访问
- 分卷文件缺失或序列不完整
- 文件读写权限问题
- 磁盘空间不足

## 许可证

本项目使用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

## 贡献

欢迎提交 Issue 和 Pull Request！

## 更新日志

### v1.0.0
- 初始版本
- 支持基本的分卷文件合并功能
- 添加跨平台构建支持
