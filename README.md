# Remote Control MCP

Remote Control MCP 是一套面向 AI Agent 的远程 MCP（Model Context Protocol）服务，支持在 Windows、Linux、macOS 上执行系统命令、管理 Python 环境，并通过统一的 MCP HTTP 端点对外提供工具能力。

## 功能特性

- **跨平台运行**：支持 Windows x86/x64/ARM64、Linux x86/x64/ARM64、macOS x64/ARM64
- **远程命令执行**：可在目标机器上执行 CMD、PowerShell、Bash、AppleScript 及 Python 脚本
- **Python 环境管理**：自动检测、安装 Python，更新 pip，安装 Python 包，查询 Python 环境信息
- **两种工作模式**：主动监听模式（remote-control-mcp 主动连接目标机器）与反向代理模式（目标机器主动连接 remote-control-mcp）。模式按「每个 RCM」与「每个 Worker」分别配置，同一台机器可同时服务多个 RCM
- **Worker 唯一归属**：每个 Worker 只归属一个 RCM，RCM 只能看到并调用属于自己的 Worker，避免多个 RCM 同时操作同一台机器
- **零配置批量部署**：RCM 生成分发包时引导选择工作模式，并按模式预置全部通信配置（AK、证书、模式、绑定）。主动监听模式下目标机器还内置全局接入 AK，RCM 首次连接即自动建档、自动分配 Worker
- **Worker 管理**：多个 Worker 统一接入 remote-control-mcp，对外暴露聚合工具列表；Worker 完全依赖反向接入与 supervisor 注册，RCM 不再手工维护（仅列举与查询）
- **机器可辨识**：Worker 清单与聚合工具描述中都带计算机名与主机 IP，AI Agent 可分辨同名 Worker 属于哪台机器
- **安全通信**：全链路 HTTPS/TLS + 证书认证 + AK 双向 HMAC 证明，认证失败按来源 IP 审计并临时封禁
- **服务守护**：supervisor 负责启动、监控 Worker，支持单个 Worker 启停、自动重启与 AK 定期轮换
- **Worker 包分发**：RCM 可生成各平台可分发 Worker ZIP 包，生成后自动做完整性校验（逐条解压比对），校验不通过不会产出文件

## 运行环境要求

### 操作系统

- Windows 10/11（x86、x64、ARM64）
- Linux（x86、x64、ARM64）
- macOS（x64、ARM64）

### 网络端口

| 服务 | 默认地址 | 端口 | 使用模式 | 说明 |
| --- | --- | --- | --- | --- |
| Worker MCP HTTPS | `0.0.0.0` | 18888 | 主动监听 | Worker 对外提供 MCP HTTPS 服务（需 RCM 客户端证书 + AK） |
| RCM MCP HTTP | `127.0.0.1` | 18889 | 两种模式 | remote-control-mcp 对外提供聚合 MCP HTTP 服务 |
| RCM 反向接入 | `0.0.0.0` | 18890 | 反向代理 | 接收 supervisor / Worker 的主动连接（TLS + mTLS） |
| supervisor 控制端口 | `0.0.0.0` | 18891 | 主动监听 | remote-control-mcp 自动接入并拉取属于它的 Worker（listen 分发包默认已开启） |

> 反向代理模式下 Worker 不监听任何端口，目标机器只需能出站访问 RCM 的 18890。

## 工作模式

| 模式 | 适用场景 | 连接方向 | 需要开放的端口 |
| --- | --- | --- | --- |
| 主动监听模式 | 目标机器有可达地址 | remote-control-mcp → supervisor / Worker | 目标机器的 18888、18891 |
| 反向代理模式 | 目标机器无公网地址，remote-control-mcp 有可达地址 | supervisor / Worker → remote-control-mcp | remote-control-mcp 的 18890 |

模式不再是全局开关，而是按对象配置：每个 `[[remote_control_mcp]]` 有自己的模式，每个 `[[workers]]` 也有自己的模式，并通过 `rcm` 字段绑定到同模式的某个 RCM。因此一台机器可以同时把一部分 Worker 交给 A（主动监听），另一部分交给 B（反向代理）；RCM 侧在菜单 `[2] Worker 管理` 中按模式分组列出属于自己的全部 Worker。

### 主动监听模式配置步骤（零配置）

1. 目标机器解压 listen 分发包并运行 supervisor：控制端口与自动接入已默认开启，全局接入 AK 已内置
2. 在 remote-control-mcp 菜单 `[3] Supervisor 管理` 的 `[1] 添加 Supervisor` 中只填名称、目标 IP 与控制端口（AK 已默认填好）
3. 保存后 RCM 立即自动接入：获得该 supervisor 下发的专属控制 AK、固定其 CA 指纹，并自动获得一个 Worker（划归已有的无归属 Worker，或新建并启动一个）
4. 自动接入完成后会立刻用新凭据拉取一次，屏幕上会显示分配到的 Worker

> 非分发包部署时，可在目标 supervisor 菜单 `[1] 编辑配置 -> [1] 基本配置` 中查看全局接入 AK 并开启控制端口，再执行第 2 步。

### 反向代理模式配置步骤（零配置）

1. 启动 remote-control-mcp，首次启动会自动初始化反向接入 AK（`rcm/certs/reverse-ak.txt`）
2. 在菜单 `[8] 生成可分发 Worker 包` 中选择平台与 `reverse` 模式，RCM 地址、反向接入 AK、mTLS 证书与 Worker 绑定会全部写入包内
3. 目标机器解压后直接运行 supervisor，它会主动连接 RCM 上报属于该 RCM 的 Worker，随后 Worker 自行建立隧道
4. 在 remote-control-mcp 菜单 `[2] Worker 管理` 中确认对应 Worker 出现在“反向代理模式”分组且为“在线”

如使用非 RCM 生成的包，则在 remote-control-mcp 菜单 `[4] 反向接入配置` 中获取 AK，再到 supervisor 菜单 `[1] 编辑配置 -> [3] RCM 管理 -> [4] 添加新 RCM`（模式选 reverse）填入地址与该 AK，并在 `Worker 管理` 中把 Worker 绑定到它。

## 安全说明

- **通道加密与身份**：所有管理与调用通道均为 TLS。
  - supervisor 控制端口使用本机 CA 自签的服务端证书（CN `supervisor`）：remote-control-mcp 在首次自动接入时固定该 CA，之后每次拉取都据此校验，因此多个使用不同 CA 的 RCM 可共用同一个端口
  - remote-control-mcp 反向接入端口只接受 CN 为 `supervisor` 的客户端证书，且客户端要求服务端身份为 `remote-control-mcp`
  - Worker MCP 端口只接受 CN 为 `remote-control-mcp` 的客户端证书
- **AK 双向证明**：控制端口与反向隧道均不传输 AK，双方基于每次连接的随机数交换 HMAC-SHA256 证明，既防止 AK 泄露，也防止伪造的对端骗取 Worker 凭据
- **调用方识别与隔离**：控制端口为每个 RCM 发放独立的控制 AK（`worker/certs/control-ak.json`），命中哪个 AK 就识别为哪个 RCM，并只返回绑定到它的 Worker；首次接入时还会固定该 RCM 的客户端证书指纹，指纹变化即拒绝
- **自动接入的安全性**：全局接入 AK（`worker/certs/bootstrap-ak.txt`）可开关（`bootstrap_enabled`）。首次接入时服务端证书尚未被信任，因此该次交换由全局 AK 锚定：supervisor 必须用它证明自己，且下发的专属控制 AK 以「全局 AK + 本次随机数」派生的密钥加密，中间人无法读取
- **AK 管理**：
  - Worker AK 由 supervisor 随机生成、加密下发，支持菜单手动轮换与按间隔自动轮换
  - 每个 RCM 的控制 AK 与全局接入 AK 均可在 supervisor 菜单中查看与重新生成
  - remote-control-mcp 反向接入 AK 位于 `rcm/certs/reverse-ak.txt`，可在菜单中查看与重新生成
- **入侵防护**：认证失败（AK 证明不符、指纹不符、缺失认证头）均记录来源 IP 与失败原因；同一来源在 60 秒内失败 5 次将被临时封禁 300 秒。TLS 握手超时 5 秒，控制端口请求体上限 64KB
- **最小暴露面**：supervisor 控制端口默认关闭（listen 分发包按需开启）；反向代理模式下 Worker 不监听任何端口
- **分发包不含敏感残留**：打包时排除 `logs/`、`certs/` 等运行时目录，不会把上一台机器的 Worker 证书与密钥带进分发包

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
4. 安装脚本会自动为所有平台目录中的 `remote-control-mcp`、`supervisor`、`worker` 以及 `start.sh` 设置可执行权限
5. 安装完成后，运行启动脚本：

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
[1] 自身配置 (MCP 端口、反向接入端口、保活间隔)
[2] Worker 管理 (列举与查询 Worker 工作状态)
[3] Supervisor 管理 (主动监听模式接入与拉取)
[4] 反向接入配置 (反向代理模式 AK 与连接状态)
[5] 查看当前 MCP 配置 JSON
[6] 应用/重启提示
[7] 重新初始化注册根证书 (Reinitialize CA)
[8] 生成可分发 Worker 包 (按工作模式全预置)
[0] 退出
```

其中 `[2] Worker 管理` 只提供列举与查询（刷新列表、查看 Worker 详情、查看 Worker MCP JSON）：

- 列表按两种工作模式分组展示，主动监听模式（direct）与反向代理模式（reverse）的 Worker 均会列出
- 每条均显示计算机名与主机 IP，用于区分不同机器上同名的 Worker
- 汇总行同时显示在线数、各模式 Worker 数与当前反向隧道连接数
- Worker 详情中会展示来源 supervisor、接入地址、凭据状态与反向隧道是否已连接
- Worker 的新增 / 修改 / 删除已完全取消，RCM 不再手工维护 Worker，完全依赖反向连接与 supervisor 注册

`[3] Supervisor 管理` 提供添加（只需 IP + 全局接入 AK）、编辑、删除、立即拉取与重新接入；列表会显示接入状态、已固定的 CA 指纹与 AK 掩码。

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
[2] 查看当前配置与状态 (View configuration & status)
[3] 启动/重新应用配置 (Apply & start)
[4] 停止服务 (Stop)
[5] 重置 AK 加密密钥 (Reset AK encryption key)
[6] 手动轮换 AK (Rotate AK)
[0] 退出 (Exit)
```

其中 `[1] 编辑配置` 分为三个子菜单：

```
[1] 基本配置 (Basic settings)
[2] Worker 管理 (Worker management)
[3] RCM 管理 (remote-control-mcp management)
```

- **基本配置**：检查间隔、AK 轮换间隔、控制端口开关与地址、自动接入开关，以及查看/重新生成全局接入 AK（同时展示本机 CA 指纹与地址，供 RCM 侧核对）。只要开启了自动接入，主菜单 `[2] 查看当前配置与状态` 也会直接列出【全局接入 AK（批量部署用）】，无需进入编辑菜单即可取用
- **Worker 管理**：列举（按模式分组，含运行状态 PID/运行时长/重启次数/最近错误、归属 RCM）、查询、编辑（地址参数、切换模式、重新绑定 RCM、启用/禁用、单个启动/停止/重启、删除）、添加（先选模式，再从同模式 RCM 列表中编号选择绑定目标，或暂不绑定留给自动接入）
- **RCM 管理**：列举（模式、启用状态、是否自动建档、绑定的 Worker、控制 AK/证书指纹/最近拉取或反向连接状态）、查询、添加（listen 只需名称，控制 AK 自动生成）、编辑。编辑菜单只显示当前工作模式适用的项：两种模式共有重命名、切换工作模式、启用/禁用、删除；主动监听模式额外提供查看/重新生成控制 AK、清除已固定的客户端证书指纹；反向代理模式额外提供修改地址/端口/刷新间隔/反向接入 AK、启动反向连接、停止反向连接。切换模式后菜单立即按新模式重新显示

当某个 RCM 没有同模式的绑定 Worker 时，菜单会直接提示添加方法。两类操作都会先列出受影响的 Worker 并要求确认，但后果不同：删除或禁用 RCM 会把绑定到它的 Worker 置为无归属并禁用；切换 RCM 的工作模式会把绑定的 Worker 一并切换为同一模式（绑定关系与启用状态保留），避免 Worker 因模式与归属 RCM 不一致而在两条通道上都被过滤、变成不可达。

## MCP 服务说明

### Worker 端点

- 主动监听模式地址：`https://<worker_ip>:<worker_port>/mcp`
- 反向代理模式地址：`reverse://<supervisor>/<worker_name>`（通过 Worker 主动建立的隧道转发，不对外监听）
- 认证：双向 mTLS + 证书身份校验，加上 AK（监听模式为 Bearer AK，反向模式为建隧道时的 AK 双向证明）
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
| `list_directory` | 枚举指定目录下的文件和文件夹，支持正则过滤 | 全平台 |
| `create_directory` | 创建目录（递归） | 全平台 |
| `upload_file` | 上传 base64 编码的文件到指定路径 | 全平台 |
| `download_file` | 下载指定文件并以 base64 编码返回内容 | 全平台 |
| `execute_cmd` | 执行 CMD / Batch 脚本 | Windows |
| `execute_powershell` | 执行 PowerShell 脚本 | Windows |
| `execute_bash` | 执行 Bash 脚本 | Linux / macOS |
| `execute_applescript` | 执行 AppleScript | macOS |

### remote-control-mcp 端点

- 地址：`http://<ip>:18889/mcp`
- 说明：聚合多个 Worker 的 MCP 服务，对外提供统一工具入口，同时提供 Worker 管理工具

remote-control-mcp 自带管理工具（只读查询 + 工具调用，不提供 Worker 增删改）：

| 工具名 | 用途 |
| --- | --- |
| `list_workers` | 列出所有已接入 Worker 及其状态（含 `hostname`、`host_ip`、`mode`、来源 supervisor），两种模式的 Worker 均包含在内 |
| `get_worker` | 获取指定 Worker 的详细信息（含计算机名与主机 IP） |
| `call_worker_tool` | 直接在指定 Worker 上调用某个工具 |

聚合工具的描述中会标注可用的 Worker，格式为 `名称@计算机名 [主机 IP] (id=...)`，因此同名 Worker 在不同机器上也能被清楚区分。

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

RCM 启动后，可通过菜单 `[8] 生成可分发 Worker 包` 为各目标平台生成可部署的 Worker ZIP 包。

### 生成步骤

1. 启动 RCM（首次启动会自动生成 mTLS 证书与反向接入 AK）
2. 在 RCM 交互菜单中选择 `[8]`
3. 选择目标平台（支持多选，如 `1,2,5` 或 `all`）
4. 指定输出目录（默认为 RCM 上级目录中的 `OUTPUT/`）
5. 选择工作模式：
   - `reverse`（推荐）：确认目标机器可达的 RCM 地址与反向接入端口
   - `listen`：确认目标机器的控制端口；首次使用时会自动生成本批共用的全局接入 AK
6. RCM 自动为每个选中平台生成 `worker-{平台}.zip`（如 `worker-windows-x64.zip`），并在生成后立即校验：重新打开包、逐条完整解压并与源文件比对大小与 CRC、校验必需文件与可执行权限

校验通过才会生成正式文件（先写临时文件再重命名）；任何失败都会删除临时文件，不会在输出目录里留下无法解压的半成品。

### 批量生成（无菜单）

同样的生成与校验流程也可以直接用命令行触发，便于批量部署与自动化：

```bash
# 反向代理模式：为所有平台生成到 OUTPUT/
remote-control-mcp --package reverse --platforms all --output ./OUTPUT \
                   --package-ip <RCM可达IP> --package-port 18890

# 主动监听模式：控制端口 18891，全局接入 AK 自动生成并写入包内
remote-control-mcp --package listen --platforms windows-x64,linux-x64 --control-port 18891
```

`--platforms` 支持 `all` 或逗号分隔列表；任一平台校验失败时进程以非零码退出。

### ZIP 包内容

共同部分：
- `supervisor` 二进制
- `worker` 二进制
- `config/default.toml`（supervisor 配置，已预置每个 Worker 的模式与绑定）

反向代理模式额外包含：
- `config/rcm-mtls/`（当前 RCM 的 mTLS 证书：`ca.pem`、`supervisor-client-cert.pem`、`supervisor-client-key.pem`）
- 配置中已写入 RCM 地址、端口与反向接入 AK，所有 Worker 已绑定到该 RCM

主动监听模式额外包含：
- `certs/bootstrap-ak.txt`（全局接入 AK，权限 0600）
- 配置中已开启控制端口与自动接入，Worker 保持无归属，等待首次接入的 RCM 划归

包内不含 `logs/`、`certs/`（除上述全局接入 AK）等运行时文件。ZIP 包中的二进制已带 Linux/macOS 可执行权限，解压后可直接运行。

### 目标机器部署

1. 将 ZIP 包复制到目标机器
2. 解压到任意目录
3. 直接运行 supervisor，无需编辑任何配置、无需手工填写 AK：
   ```bash
   # Linux / macOS
   ./supervisor

   # Windows
   .\supervisor.exe
   ```
4. supervisor 启动后会自动启动 Worker；反向代理模式下主动连接 RCM 并建立隧道，主动监听模式下等待 RCM 自动接入并拉取
5. 主动监听模式下，RCM 侧只需在菜单 `[3] Supervisor 管理` 中添加该机器的 IP（AK 已默认填好）；其余均无需操作
6. 如需在部署后调整模式或绑定，均可在 supervisor 菜单 `[1] 编辑配置` 的 `Worker 管理` / `RCM 管理` 中完成，无需手改配置文件

## 快速验证

### Linux / macOS 安装验证清单

```bash
cd bin            # 或解开后的分发包目录
chmod +x install.sh
./install.sh      # 按提示输入安装目录，直接回车使用默认值
```

逐项确认：

| 检查项 | 预期结果 | 命令 |
| --- | --- | --- |
| 安装路径无乱码 | `-> /your/install/path`，不含 `\033[` 等字样 | 观察安装输出 |
| 平台目录已拷贝 | 列出 `linux-x64 -> copied` 等，缺失平台自动跳过且不中断 | `ls <安装目录>` |
| RCM 已就位 | 存在 `rcm/remote-control-mcp` | `ls <安装目录>/rcm` |
| 可执行权限已设置 | `[5/5]` 步骤报告“... file(s) marked executable” | `ls -l <安装目录>/rcm/remote-control-mcp` 应有 `x` |
| 启动脚本可执行 | `start.sh` 具备 `x` 权限 | `ls -l <安装目录>/start.sh` |
| RCM 可启动 | 显示交互菜单，无“Permission denied” | `./start.sh` |
| MCP 端口已监听 | 返回自带管理工具列表 | `curl -s -X POST http://127.0.0.1:18889/mcp -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'` |
| 证书已生成 | 存在 `rcm/certs/`、`rcm/rcm-mtls/` | `ls <安装目录>/rcm/certs` |

### Windows 安装验证清单

```powershell
cd bin
.\install.ps1
.\start.cmd
```

确认：安装目录下生成 `rcm\`、`start.cmd` 与各平台目录；启动后 `http://127.0.0.1:18889/mcp` 可返回工具列表。

### Worker 接入验证

1. RCM 菜单 `[2] Worker 管理`：目标 Worker 出现在对应模式分组下且状态为“在线”，且计算机名/主机 IP 与目标机器一致
2. 调用 `list_workers` 确认数量、`mode`、`hostname`/`host_ip` 与来源 supervisor 正确（两种模式均应列出）
3. 调用 `call_worker_tool`（`tool_name` 为 `get_os_info`）确认能拿到目标机器的系统信息
4. 多 RCM 隔离验证：两个 RCM 各自只看到自己的 Worker；用对方的 AK 拉取只会得到对方的集合

---

**注意**：本分发包仅包含可直接运行的二进制文件与安装脚本。新旧版本不能混用，请确保 RCM 和 Supervisor/Worker 使用同一版本的分发包。
