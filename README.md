# Remote Control MCP

Remote Control MCP 是一套面向 AI Agent 的远程 MCP（Model Context Protocol）服务集合，支持在 Windows、Linux、macOS 上执行系统命令、管理 Python 环境，并通过统一的 MCP HTTP 端点对外提供工具能力。

## 功能特性

- **跨平台运行**：支持 Windows x64/ARM64、Linux x86/x64/ARM64、macOS x64/ARM64。
- **远程命令执行**：可在目标机器上执行 CMD、PowerShell、Bash、AppleScript 及 Python 脚本。
- **Python 环境管理**：自动检测、安装 Python，更新 pip，安装 Python 包，查询 Python 环境信息。
- **Worker 注册与管理**：支持多个 Worker 注册到 remote-control-mcp，统一对外暴露工具列表。
- **安全通信**：Worker 与 remote-control-mcp 之间通过 HTTPS + AK（Access Key）进行认证通信。
- **服务守护**：supervisor 负责启动、监控 Worker，支持自动重启。

## 运行环境要求

### 操作系统

- Windows 10/11（x64、ARM64）
- Linux（x86、x64、ARM64）
- macOS（x64、ARM64）

### 网络端口

默认使用以下端口，安装时可根据实际情况修改：

| 服务 | 默认地址 | 端口 | 说明 |
| --- | --- | --- | --- |
| Worker HTTPS | `0.0.0.0` | 18888 | Worker 对外提供 MCP HTTPS 服务 |
| MCP HTTP | `127.0.0.1` | 18889 | remote-control-mcp 对外提供 MCP HTTP 服务 |
| Worker 注册 | `0.0.0.0` | 18890 | remote-control-mcp 接收 Worker 注册 |

### 依赖

- Worker 的 Python 相关工具（`execute_python`、`install_python`、`install_package`、`update_pip`、`get_python_info`）需要目标系统存在可用的 Python 环境，或授权 Worker 自动下载安装 Python。
- 执行各类脚本工具时，目标系统需具备对应的解释器或运行环境（如 Windows 的 `cmd.exe`、`powershell`，Linux/macOS 的 `bash`，macOS 的 `osascript` 等）。

## 目录结构

```
bin/
├── install.ps1              # Windows 安装脚本（自动检测平台）
├── install.sh               # Linux/macOS 安装脚本（自动检测平台）
├── windows-x64/             # Windows x64 平台二进制包
│   ├── supervisor.exe
│   ├── worker.exe
│   ├── remote-control-mcp.exe
│   ├── config/default.toml
│   ├── config/remote-control-mcp.toml
│   └── install.ps1
├── windows-arm64/           # Windows ARM64 平台二进制包
├── linux-x86/               # Linux x86 平台二进制包
├── linux-x64/               # Linux x64 平台二进制包
├── linux-arm64/             # Linux ARM64 平台二进制包
├── macos-x64/               # macOS x64 平台二进制包
├── macos-arm64/             # macOS ARM64 平台二进制包
└── macos-universal/         # macOS 双架构二进制包（ supervisor-x86_64 / supervisor-arm64 等）
```

各平台目录已包含运行所需的二进制文件与默认配置文件。根目录下的 `install.ps1` 与 `install.sh` 会根据当前系统自动选择对应平台目录进行安装。

## 部署安装

### Windows

1. 进入与目标平台对应的目录（例如 `windows-x64`），或直接使用根目录的 `install.ps1`。
2. 以管理员身份运行 PowerShell，执行：

   ```powershell
   .\install.ps1
   ```

3. 按向导提示选择：
   - 安装路径（默认 `C:\Program Files\RemoteControlMCP`）
   - Worker 服务端口（默认 `18888`）
   - Worker 名称
   - 是否自动重启
   - 健康检查间隔
4. 安装完成后，使用生成的启动脚本管理服务：

   ```powershell
   .\start.ps1 start    # 启动
   .\start.ps1 stop     # 停止
   .\start.ps1 restart  # 重启
   .\start.ps1 status   # 查看状态
   ```

### Linux / macOS

1. 进入与目标平台对应的目录（例如 `linux-x64` 或 `macos-universal`），或直接使用根目录的 `install.sh`。
2. 执行安装脚本：

   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. 按向导提示选择安装路径、端口、Worker 名称等。
4. 安装完成后，使用生成的启动脚本管理服务：

   ```bash
   ./start.sh start    # 启动
   ./start.sh stop     # 停止
   ./start.sh restart  # 重启
   ./start.sh status   # 查看状态
   ```

## MCP 服务说明

### Worker 端点

- 地址：`https://<worker_ip>:<worker_port>/mcp`
- 说明：直接运行在目标机器上的 MCP 服务，提供本地系统命令执行、Python 环境管理、系统信息查询等能力。

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
- 说明：聚合多个 Worker 的 MCP 服务，对外提供统一工具入口，同时提供 Worker 管理工具。

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

## 快速验证

安装并启动服务后，可向 remote-control-mcp 发送 `tools/list` 请求验证服务是否正常：

```bash
curl -X POST http://127.0.0.1:18889/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/list",
    "id": 1
  }'
```

正常返回应包含 `list_workers`、`get_worker` 等管理工具，以及已注册 Worker 提供的工具。

---

**注意**：本分发包仅包含可直接运行的二进制文件与安装脚本。如需从源码重新构建，请使用项目根目录的 `build.ps1` 或 `build.sh`。
