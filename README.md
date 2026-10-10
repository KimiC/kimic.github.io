# Kimi Chen — 个人主页

> 一个手写的极简黑白个人主页。纯静态，零依赖，零构建。

八年级学生，对电子游戏、自然科技、物理化学、天文地理都感兴趣。

---

## 预览

```bash
python dev_server.py
```

然后打开 <http://127.0.0.1:8080/>。

Windows 用户直接**双击 `start.bat`** 即可，不需要安装任何东西（Python 标准库实现）。

## 技术选型

| 项目 | 选择 | 原因 |
| --- | --- | --- |
| 页面 | 原生 HTML / CSS / JS | 零构建、秒开、扔哪都能跑 |
| 本地服务 | Python `http.server` | 无需 `npm install`，改完即见 |
| 部署 | Nginx | 阿里云轻量服务器一条命令装好 |

没有框架、没有打包器、没有 `node_modules`。打开 `index.html` 就是全部。

## 目录结构

```
.
├── index.html          # 单页站点，所有内容
├── assets/
│   ├── css/style.css   # 极简黑白主题 + 深色模式
│   ├── js/main.js      # 主题切换 / 滚动动画 / 导航高亮
│   └── img/            # 图片放这里
├── dev_server.py       # 本地预览服务（含热重载）
├── start.bat           # Windows 一键启动
├── start.sh            # macOS / Linux 一键启动
└── deploy/
    ├── nginx.conf      # 阿里云 Nginx 配置
    └── DEPLOY.md       # 完整部署与迁移手册
```

## 功能

- 极简黑白排版，支持深浅色主题（跟随系统，可手动切换并记忆）
- 滚动入场动画、阅读进度条、导航自动高亮
- 响应式布局，手机 / 平板 / 桌面都正常
- 尊重 `prefers-reduced-motion`，无障碍友好
- 本地服务支持**保存即自动刷新**

## 部署

完整步骤见 [deploy/DEPLOY.md](deploy/DEPLOY.md)：本机预览 → GitHub 仓库 → 阿里云轻量应用服务器 → 域名与 HTTPS。

## 联系方式

- 邮箱：chenkimi12@hotmail.com
- GitHub：[@KimiC](https://github.com/KimiC)
- 所在地：中国 · 上海

## 还可以补充的内容

- [ ] `index.html` 关于区块的照片位（现在显示大写 `K`），图片放进 `assets/img/` 后替换

---

© Kimi Chen
