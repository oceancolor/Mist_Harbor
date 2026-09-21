# 教程站点部署说明

本页记录把 `course/` 站点发布到静态托管（EdgeOne Pages / GitHub Pages / 任意静态服务器）的完整流程。

---

## 1. 站点产物

```powershell
python tools/course_build.py                       # → course/site（默认，图片与视频都在本地）
python tools/course_build.py --embed --out <目录>    # 单文件版（图片与 CSS 内联，视频仍外链）
python tools/course_build.py --video-base <URL>      # 视频不外拷，改为外链
```

| 参数 | 作用 |
|---|---|
| `--out <目录>` | 输出目录（默认 `course/site`） |
| `--embed` | 图片与 CSS 内联成单文件页（便于发送/导入 LMS） |
| `--video-base <URL>` | 视频指向外链（如 GitHub Pages），**不再拷贝 76 MB 视频** |

**页面全部使用相对链接**（`chapter-XX.html`、`assets/...`），因此放在任意子路径下都能正常工作，
例如 `/course/index.html` 或站点根目录均可。

---

## 2. 视频为什么外链

36 章演示短片共 **76.2 MB**（单文件 0.75–3.6 MB）。托管平台常见限制是**单文件 25 MiB**，
文件本身没超，但总量会让部署变慢、占用配额。所以部署时让页面引用外部源：

```
https://oceancolor.github.io/Mist_Harbor/course/media/video/<章号>/<章号>-demo.webm
```

启用方式（GitHub Pages 已开启，源为 `main` 分支根目录）：

```powershell
python tools/course_build.py --out .codebuddy/releases/edgeone-course-root `
    --video-base https://oceancolor.github.io/Mist_Harbor/course/media/video
```

> 📌 若 GitHub Pages 不可达，可改用 jsDelivr：
> `--video-base https://cdn.jsdelivr.net/gh/oceancolor/Mist_Harbor@main/course/media/video`
> （jsDelivr 单文件上限 20 MB，我们的短片最大 3.6 MB，安全。）

---

## 3. EdgeOne Pages 部署

### CLI

```powershell
edgeone pages deploy <目录> -n <项目名> -t $env:EDGEONE_TOKEN -e production --json
```

| 参数 | 说明 |
|---|---|
| `-n` | 项目名（不存在则新建，存在则更新） |
| `-t` | API Token（**不要写进仓库/文件**；建议用环境变量注入） |
| `-e` | `production` 或 `preview` |
| `-a` | `global` / `overseas` |

### ⚠️ 部署是"整项目替换"

`edgeone pages deploy` 用上传目录**整体覆盖**目标项目，**不是追加子目录**。因此：

| 想做的事 | 可行方案 |
|---|---|
| 在原域名下出现 `/course` | 必须连游戏本体一起重新部署（合并树） |
| **完全不动原游戏** | 只能新建项目 → 得到**新域名**；原域名的 `/course` 需要平台侧再做路径映射 |

本仓库采用后者：新建独立项目发布教程，**原游戏服务不受影响**。

### 已备好的部署树（`.codebuddy/releases/`，不入库）

| 目录 | 结构 | 体积 | 用途 |
|---|---|---:|---|
| `edgeone-course-root/` | 教程在**根目录** | 20.6 MB | **新建项目推荐**（独立域名直接访问；将来做 `/course/* → 该项目 /*` 映射最自然） |
| `edgeone-course/` | 教程在 `course/` 子目录 | 20.6 MB | 若映射规则是"保留 /course 前缀" |
| `edgeone-full/` | 游戏根 + `course/` | 31.0 MB | 合并树（最大单文件 9.61 MB，符合 25 MiB 限制），用于直接更新原项目 |

### 已完成的部署（2026-09-21）

| 项 | 值 |
|---|---|
| 项目名 | `mist-harbor-course` |
| Project ID | `makers-umdakezd9w6r` |
| Deployment ID | `dpyc3jxf30sq` |
| 环境 / 区域 | Production / global |
| **线上地址** | **https://mist-harbor-course.app.bootcamp.qq.com** |
| 上传内容 | `.codebuddy/releases/edgeone-course-root`（20.6 MB，教程在项目根目录） |

命令（token 用环境变量注入，不落盘）：

```powershell
$env:EDGEONE_TOKEN='<你的token>'
edgeone pages deploy .codebuddy\releases\edgeone-course-root `
    -n mist-harbor-course -t $env:EDGEONE_TOKEN -e production --json
```

**验收结果（真实 Chromium）**

```
/index.html       200  图片 0/0 坏
/chapter-10.html  200  图片 4/4 正常，视频 readyState=4，时长 43.6s，1280×800
/chapter-31.html  200  图片 2/2 正常，视频外链正常
/appendix.html    200
console errors: none
原游戏入口 https://mist-harbor-3d.app.bootcamp.qq.com/  200 —— 未受影响
```

> 视频外链的 `net::ERR_ABORTED` 是浏览器缓冲完成后关闭 range 请求所致，
> 非加载失败（`readyState=4` 表示数据足够播放）。

### 关于原域名的 `/course`（2026-09-21 决定：不做）

教程已发布在独立域名 **https://mist-harbor-course.app.bootcamp.qq.com**，
**不再**把 `/course/*` 映射到 `mist-harbor-3d.app.bootcamp.qq.com`——该路径保持 404，无需处理。

理由：原域名的部署是"整项目替换"，追加子目录会破坏游戏本体；
独立项目既能保住游戏，又各有独立域名与部署记录，运维更清晰。

> 若将来确实需要同域 `/course`，唯一安全做法是重新部署**合并树**
> （`.codebuddy/releases/edgeone-full`：游戏根 + `course/`，31 MB，最大单文件 9.61 MB）。

### 部署后必做验证

```
1. 打开首页与各章，确认图片正常（外链视频能加载）
2. 打开 https://<域名>/course/ 或对应入口，确认相对链接没坏
3. 跑一次浏览器控制台检查：无 404、无 JS 报错
4. 原游戏入口仍需可访问（确认没被覆盖）
```

---

## 4. GitHub Pages（备选 / 视频源）

- 已启用：https://oceancolor.github.io/Mist_Harbor/
- 源：`main` 分支根目录 → 教程站点可直接访问 `.../Mist_Harbor/course/site/index.html`
- 视频源文件：`.../Mist_Harbor/course/media/video/<章号>/<章号>-demo.webm`

---

## 5. 常见坑

| 现象 | 原因 | 处理 |
|---|---|---|
| 部署后根路径 404 | 用只含子目录的树覆盖了原项目 | 见第 3 节：要么合并树，要么新建项目 |
| 上传被拒（单文件过大） | 平台限制 25 MiB | 检查是否有未预压缩的大文件（wasm 需 gzip 预处理） |
| 视频不显示 | 外链不可达 | 换 jsDelivr，或把 `--video-base` 去掉改为本地拷贝 |
| 页面样式丢失 | 单文件版漏了样式内联 | 确认用 `--embed`（会内联 CSS；仅视频外链） |
| 子路径下链接 404 | 用了绝对路径 | 本站点全相对路径，若自己改模板请注意 |
