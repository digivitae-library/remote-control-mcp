# Remote Control MCP

Remote Control MCP 是一套面向 AI Agent 的远程 MCP（Model Context Protocol）服务，支持在 Windows、Linux、macOS 上执行系统命令、管理 Python 环境，并通过统一的 MCP HTTP 端点对外提供工具能力。

## 功能特性

- **跨平台运行**：支持 Windows x86/x64/ARM64、Linux x86/x64/ARM64、macOS x64/ARM64
- **远程命令执行**：可在目标机器上执行 CMD、PowerShell、Bash、AppleScript 及 Python 脚本
- **Python 环境管理**：自动检测、安装 Python，更新 pip，安装 Python 包，查询 Python 环境信息
- **Worker 注册与管理**：支持多个 Worker 注册到 remote-control-mcp，统一对外暴露工具列表
- **安全通信**：Worker 与 RCM 之间通过 HTTPS + 双向 mTLS 证书认证通信；Worker 的 Access Key 使用加密传递
- **服务守护**：supervisor 负责启动、监控 Worker，支持自动重启
- **Worker 包分发**：RCM 可生成各平台可分发 Worker ZIP 包，自动合并 mTLS 证书，便于部署到不同目标机器

## 运行环境要求

### 操作系统

- Windows 10/11（x86、x64、ARM64）
- Linux（x86、x64、ARM64）
- macOS（x64、ARM64）

### 网络端口

| 服务 | 默认地址 | 端口 | 说明 |
| --- | --- | --- | --- |
| Worker MCP HTTPS | `0.0.0.0` | 18888 | Worker 对外提供 MCP HTTPS 服务（需客户端证书） |
| RCM MCP HTTP | `127.0.0.1` | 18889 | remote-control-mcp 对外提供 MCP HTTP 服务 |
| Worker 注册 HTTPS | `0.0.0.0` | 18890 | remote-control-mcp 接收 Worker 注册（需 mTLS 客户端证书） |

### 依赖

- Worker 的 Python 相关工具需要目标系统存在可用的 Python 环境，或授权 Worker 自动下载安装 Python
- 执行各类脚本工具时，目标系统需具备对应的解释器（如 Windows 的 `cmd.exe`、`powershell`，Linux/macOS 的 `bash`，macOS 的 `osascript` 等）

## 部署安装

安装脚本用于在当前机器上安装 RCM（remote-control-mcp）。安装脚本会复制所有平台目录、将当前平台的 RCM 部署到安装目录根、并生成启动脚本。

### Windows

1. 进入 `bin/` 根目录或对应平台目录（例如 `windows-x64`）
2. 运行安装脚本：

   ```powershell
   .\install.ps1
   ```

3. 按提示选择安装目录（默认为当前目录）
4. 安装完成后，运行启动脚本：

   ```powershell
   .\start.cmd
   ```

   RCM 将在当前终端显示交互菜单。按 `Ctrl+C` 或关闭终端可停止 RCM。

### Linux / macOS

1. 进入 `bin/` 根目录或对应平台目录
2. 运行安装脚本：

   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. 按提示选择安装目录（默认为当前目录）
4. 安装完成后，运行启动脚本：

   ```bash
   ./start.sh
   ```

   RCM 将在当前终端显示交互菜单。按 `Ctrl+C` 或关闭终端可停止 RCM。

### 安装后的目录结构

```
安装目录/
├── rcm/                    # 当前平台的 RCM（直接可用）
│   ├── remote-control-mcp[.exe]
│   └── config/
├── windows-x64/            # 所有平台目录（包含 rcm/ 和 worker/）
├── linux-x64/
├── ...
└── start.cmd / start.sh
```

## 启动方式

### remote-control-mcp

```bash
# Linux / macOS
./remote-control-mcp

# Windows
.\remote-control-mcp.exe
```

交互模式提供以下菜单：

```
[1] 自身配置 (MCP 端口、注册端口、保活间隔)
[2] Worker 配置 (增删改查)
[3] 查看当前 MCP 配置 JSON
[4] 应用/重启提示
[5] 重新初始化注册根证书 (Reinitialize CA)
[6] 生成可分发 Worker 包 (Generate distributable Worker packages)
[0] 退出
```

### supervisor

```bash
# Linux / macOS
./supervisor

# Windows
.\supervisor.exe
```

交互模式提供以下菜单：

```
[1] 编辑配置 (Edit configuration)
[2] 查看当前配置 (View configuration)
[3] 启动/重新应用配置 (Apply & start)
[4] 停止服务 (Stop)
[5] 刷新 remote-control-mcp 注册 (Refresh registry)
[6] 重置 AK 加密密钥 (Reset AK encryption key)
[7] 手动轮换 AK (Rotate AK)
[0] 退出 (Exit)
```

## MCP 服务说明

### Worker 端点

- 地址：`https://<worker_ip>:<worker_port>/mcp`
- 认证：HTTPS 双向 mTLS + Bearer AK
- 说明：直接运行在目标机器上的 MCP 服务，提供本地系统命令执行、Python 环境管理、系统信息查询等能力

Worker 原生工具列表：

| 工具名 | 用途 | 适用平台 |
| --- | --- | --- |
| `get_os_info` | 返回当前操作系统类型与版本 | 全平台 |
| `get_python_info` | 返回当前 Python 版本、路径及已安装包列表 | 全平台 |
| `execute_python` | 执行一段 Python 脚本 | 全平台 |
| `install_package` | 使用 pip 安装指定 Python 包 | 全平台 |
| `update_pip` | 更新当前 Python 环境的 pip | 全平台 |
| `install_python` | 检查并安装指定版本 Python（默认 3.11.0） | 全平台 |
| `execute_cmd` | 执行 CMD / Batch 脚本 | Windows |
| `execute_powershell` | 执行 PowerShell 脚本 | Windows |
| `execute_bash` | 执行 Bash 脚本 | Linux / macOS |
| `execute_applescript` | 执行 AppleScript | macOS |

### remote-control-mcp 端点

- 地址：`http://<ip>:18889/mcp`
- 说明：聚合多个 Worker 的 MCP 服务，对外提供统一工具入口，同时提供 Worker 管理工具

remote-control-mcp 自带管理工具：

| 工具名 | 用途 |
| --- | --- |
| `list_workers` | 列出所有已注册 Worker 及其状态 |
| `get_worker` | 获取指定 Worker 的详细信息 |
| `add_worker` | 手动注册一个新的 Worker |
| `update_worker` | 更新指定 Worker 的信息 |
| `delete_worker` | 删除指定 Worker |
| `call_worker_tool` | 直接在指定 Worker 上调用某个工具 |

remote-control-mcp 还会自动聚合所有 `reachable=true` 的 Worker 工具。调用 Worker 工具时，需要在 `arguments` 中传入 `_worker_id` 指定目标 Worker，例如：

```json
{
  "name": "get_os_info",
  "arguments": {
    "_worker_id": "<worker_id>"
  }
}
```

## Worker 分发部署

RCM 启动后，可通过菜单 `[6] 生成可分发 Worker 包` 为各目标平台生成可部署的 Worker ZIP 包。

### 生成步骤

1. 启动 RCM（首次启动会自动生成 mTLS 证书）
2. 在 RCM 交互菜单中选择 `[6]`
3. 选择目标平台（支持多选，如 `1,2,5` 或 `all`）
4. 指定输出目录（默认为 RCM 上级目录中的 `OUTPUT/`）
5. RCM 自动为每个选中平台生成 `worker-{平台}.zip`（如 `worker-windows-x64.zip`）

### ZIP 包内容

每个 ZIP 包包含：
- `supervisor` 二进制
- `worker` 二进制
- `config/default.toml`（supervisor 配置）
- `config/rcm-mtls/`（已合并当前 RCM 的 mTLS 证书：`ca.pem`、`supervisor-client-cert.pem`、`supervisor-client-key.pem`）

### 目标机器部署

1. 将 ZIP 包复制到目标机器
2. 解压到任意目录
3. 编辑 `config/default.toml`，配置 RCM 注册地址：
   ```toml
   [[remote_control_mcp]]
   ip = "<RCM所在机器IP>"
   port = 18890
   refresh_interval_secs = 60
   ```
4. 运行 supervisor：
   ```bash
   # Linux / macOS
   ./supervisor

   # Windows
   .\supervisor.exe
   ```
5. supervisor 启动后会自动启动 Worker 并通过 HTTPS + mTLS 注册到 RCM

---

**注意**：本分发包仅包含可直接运行的二进制文件与安装脚本。新旧版本不能混用，请确保 RCM 和 Supervisor/Worker 使用同一版本的分发包。
