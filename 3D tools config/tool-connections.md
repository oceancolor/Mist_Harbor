# 3D 生成工具接入配置（tool-connections）

> 版本 v1.0 ｜ 日期 2026-09-25 ｜ 查证来源：官方/社区 MCP 仓库与 npm（2026-09-25 检索）
> ⚠ 所有 API key 均为**占位符**，由 Benja 换成真实 key 后方可运行；key 属敏感信息，勿提交进任何仓库

## 1. Meshy（首选 · 官方 MCP）

- **包**：`@meshy-ai/meshy-mcp-server`（官方，npm）
- **Key 获取**：app.meshy.ai → Settings → API Keys → Generate（`msy_` 开头；**API 需 Pro 档或以上**）
- **工具面**：text/image/multi-image → 3D、refine、remesh、retexture、rig/animate（本项目基本用不到 rig）、任务管理、余额查询
- **导出**：GLB / FBX / OBJ / USDZ

CodeBuddy / WorkBuddy / Cursor（`mcp.json` 的 `mcpServers` 节）：

```json
{
  "mcpServers": {
    "meshy": {
      "command": "npx",
      "args": ["-y", "@meshy-ai/meshy-mcp-server"],
      "env": {
        "MESHY_API_KEY": "msy_YOUR_API_KEY_HERE"
      }
    }
  }
}
```

Windows 注意：若客户端不自动包一层，需改为 `"command": "cmd", "args": ["/c", "npx", "-y", "@meshy-ai/meshy-mcp-server"]`。
可选环境变量：`MESHY_API_HOST`（默认 `https://api.meshy.ai`）、`TRANSPORT`（stdio/http）。

## 2. Tripo（对照/压面数 · 社区 MCP）

- **包**：`tripo-ai-mcp-server`（npm，社区维护，2026-04 仍在更新）
- **官方 MCP 不采用的原因**：VAST 官方 `tripo-mcp` 停留在 alpha、绑定 Blender addon、2025-04 起停更——本项目是 Godot 管线，不匹配
- **Key 获取**：platform.tripo3d.ai（`TRIPO_API_KEY`）
- **对本管线的关键能力**：`face_limit` 参数（生成时直接压面数，对应 spec 面数预算）、`convert_model`（GLTF/GLB 互转）、multiview-to-3D（可喂概念图多视角）

```json
{
  "mcpServers": {
    "tripo-ai": {
      "command": "npx",
      "args": ["-y", "tripo-ai-mcp-server"],
      "env": {
        "TRIPO_API_KEY": "YOUR_TRIPO_KEY_HERE"
      }
    }
  }
}
```

## 3. Hyper3D（腾讯混元 3D · HTTP API 直连，待账号）

无成熟 MCP server，走 REST 直连。骨架如下（key 到位后补全具体端点与参数，以 3d.hunyuan.tencent.com 官方文档为准）：

```
Base URL:   https://3d.hunyuan.tencent.com 官方文档定（占位）
Auth:       Bearer <HUNYUAN_3D_API_KEY>
典型流程:    提交生成任务 → 轮询任务状态 → 下载 GLB/OBJ
用途定位:    中文造型词（燕尾脊/蚵壳厝/骑楼）直连生成的对照通道——
            中式构件的语义理解预期优于英文 prompt 中转译
```

```json
{
  "mcpServers": {
    "hunyuan-3d": {
      "command": "python",
      "args": ["<路径>/hunyuan3d_mcp_bridge.py"],
      "env": {
        "HUNYUAN_3D_API_KEY": "YOUR_KEY_HERE"
      }
    }
  }
}
```

> 上面的 bridge 脚本**尚不存在**——若确定开通混元 3D，下一轮由工程侧写一个薄 MCP 桥（提交任务/轮询/下载三个工具即可）。

## 4. 安装后激活

- **WorkBuddy**：写入 `~/.workbuddy/mcp.json` 后，到连接管理页右上角「自定义连接器」入口对新 server 点「信任」，新 MCP 不会自动生效
- **CodeBuddy / Cursor**：重启客户端后查看 MCP 列表绿点；首次调用建议用「生成一个 100 面以内的测试方块」验证链路
- **验证清单**：① 两把 key 均能查到余额（`get_balance`）② 试产一个测试资产并成功导出 GLB ③ GLB 在 Godot 4.4 中导入无坐标/朝向问题

## 5. 安全与成本纪律

- key 只放本文件 env 占位处或本地 `.env`，**不进 git**（本目录如纳入版本控制，先加 `.gitignore`）
- Meshy/Tripo 均按积分计费：先跑**泉州组试管线**（复用改造 13 项先出），单资产确认三步（压面/色值/导入）都通再批量
- 每个资产的生成+remesh+retexture 预算上限建议 ≤ 3 次生成；超限回炉改提示词而不是继续烧积分
