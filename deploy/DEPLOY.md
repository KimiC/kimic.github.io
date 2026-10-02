> 部署与迁移手册：从本机预览 → GitHub 仓库 → 阿里云轻量应用服务器
> 这是给你（Kimi）自己看的操作说明，每一步都可以照着敲。

---

# 目录

1. [现在在哪儿跑](#1-现在在哪儿跑)
2. [本地预览](#2-本地预览)
3. [改内容改哪里](#3-改内容改哪里)
4. [GitHub 建仓与推送](#4-github-建仓与推送)
5. [搬到阿里云轻量应用服务器](#5-搬到阿里云轻量应用服务器)
6. [以后怎么更新线上内容](#6-以后怎么更新线上内容)
7. [可选：GitHub Pages 免费预览](#7-可选github-pages-免费预览)
8. [常见问题](#8-常见问题)

---

## 1. 现在在哪儿跑

这是一个**纯静态站点**：只有 HTML / CSS / JS，没有后端、没有数据库、没有构建步骤。
谁都能托管它——本机 Python、Nginx、GitHub Pages、OSS，都行。

```
default-workspace/            ← 站点根目录，也是 Git 仓库根目录
├── index.html                ← 唯一页面，所有内容都在这里
├── assets/
│   ├── css/style.css         ← 全部样式（极简黑白主题 + 深色模式）
│   ├── js/main.js            ← 交互：主题切换、滚动动画、导航高亮
│   └── img/                  ← 放图片（现在还是空的）
├── dev_server.py             ← 本地预览服务器（Python 标准库，无需安装）
├── start.bat                 ← Windows 双击启动
├── start.sh                  ← macOS / Linux 启动
├── deploy/
│   ├── nginx.conf            ← 阿里云上线用的 Nginx 配置
│   └── DEPLOY.md             ← 你正在看的这份
├── .gitignore
└── README.md
```

---

## 2. 本地预览

**Windows**：双击 `start.bat`

**命令行**：

```bash
python dev_server.py                 # http://127.0.0.1:8080
python dev_server.py -p 5500         # 换端口
python dev_server.py --host 0.0.0.0  # 同一 WiFi 下手机 / 平板也能看
python dev_server.py --no-reload     # 关掉自动刷新
```

打开 <http://127.0.0.1:8080/> 就能看到页面。
服务有**自动刷新**：改完 `index.html` 或 CSS，保存后浏览器会自己刷新，不用手动按 F5。

> 想省事的话，也可以直接双击 `index.html` 用浏览器打开。
> 页面本身不依赖服务器，只是这样就**没有**自动刷新，且 `file://` 下少数浏览器行为略有差异。

---

## 3. 改内容改哪里

| 想改什么 | 去哪里 |
| --- | --- |
| 首页大标题、自我介绍 | `index.html` → `<section class="hero">` |
| 关于我、个人信息表 | `index.html` → `<section id="about">` |
| 兴趣卡片（加一张/改文字） | `index.html` → `<section id="interests">` 里复制一个 `<article class="card">` |
| 近况时间线 | `index.html` → `<section id="now">` |
| 邮箱 / GitHub 链接 | `index.html` → `<section id="contact">`，搜 `you@example.com` 和 `@kimic` |
| 颜色（想换个主色调） | `assets/css/style.css` 最上面的 `:root { }` 变量 |
| 头像照片 | 把图片放进 `assets/img/`，替换 `about` 里的 `portrait-frame` 那块 |
| 导航菜单 | `index.html` 里 `class="nav"` 的 `<a>` 列表 |

> 页面上有两处**占位内容**必须自己替换：
> 1. 邮箱 `you@example.com`
> 2. 关于区块的照片位（现在显示一个大写的 `K`）
> 搜 `YOUR_USERNAME` 也能定位到 GitHub 链接那一块。

**注意**：`index.html` 里那行 `<p class="contact-tip">` 是给你自己看的修改提示，
改完邮箱后**记得把它整段删掉**，不然访客也能看到。

---

## 4. GitHub 建仓与推送

本机已经装好 Git（在 `D:\乱七八糟\Git`），但没配全局身份，也没装 `gh` 命令行。
先在仓库目录里配置身份（只对这个仓库生效，不动全局）：

```bash
git config user.name  "Kimi Chen"
git config user.email "你的邮箱"
```

### 4.1 在 GitHub 上建空仓库

打开 <https://github.com/new>：

- **Owner** 选 `kimic`
- **Repository name** 建议 `kimic.github.io`
  - 用这个名字的好处：以后开启 GitHub Pages，地址直接是 `https://kimic.github.io/`
  - 想用别的名字也行（比如 `homepage`），只是 Pages 地址会变成 `https://kimic.github.io/homepage/`
- **不要**勾选 "Add a README file" / ".gitignore" / "license"（本地已经有了，勾了会冲突）
- 点 **Create repository**

### 4.2 推送

建完仓库后，把 `<仓库名>` 换掉，逐条执行：

```bash
git remote add origin https://github.com/kimic/<仓库名>.git
git branch -M main
git push -u origin main
```

推送时会要账号密码：**密码位置填 Personal Access Token，不是 GitHub 登录密码。**
生成方式：GitHub → Settings → Developer settings → Personal access tokens →
Tokens (classic) → Generate new token，勾选 `repo` 权限即可。

### 4.3 以后每次更新

```bash
git add -A
git commit -m "更新内容"
git push
```

---

## 5. 搬到阿里云轻量应用服务器

### 5.1 买服务器

- 阿里云 → **轻量应用服务器** → 选**中国内地**地域
- 镜像：**系统镜像 → Ubuntu 24.04**（最省事，教程最多）
- 套餐：最低配（2核2G）就够跑一个静态站
- 买完在控制台**重置密码**，记下**公网 IP**

### 5.2 放行端口

轻量服务器有**两层防火墙**，两层都要开：

1. **轻量应用服务器控制台** → 你的实例 → 防火墙 → 添加规则：`80`（HTTP）、`443`（HTTPS）
2. 服务器内部（Ubuntu 一般默认没有 ufw 拦截，无需额外操作；如果开了 ufw，执行 `ufw allow 80,443/tcp`）

> ⚠️ 如果用的是**中国内地**地域的服务器，域名要**备案**之后 80/443 才能正常对外服务。
> 暂时没备案也行——先用 `http://公网IP` 访问是通的，等域名备案下来再切域名。

### 5.3 连上服务器并装环境

Windows 上用 PowerShell 连（把 IP 换成你的）：

```bash
ssh root@你的公网IP
```

然后在服务器上：

```bash
# 更新系统
apt update && apt upgrade -y

# 安装 Nginx 和 Git
apt install -y nginx git

# 建站点目录
mkdir -p /var/www/kimic
```

### 5.4 把站点传上去

**方式 A：从 GitHub 拉（推荐，以后更新最方便）**

```bash
# 服务器上执行；公开仓库不需要登录
git clone https://github.com/kimic/<仓库名>.git /var/www/kimic
```

> 如果仓库是私有的，需要配置 Deploy Key 或使用带 token 的地址：
> `git clone https://<你的token>@github.com/kimic/<仓库名>.git /var/www/kimic`

**方式 B：从本机直接上传**（Windows PowerShell 里执行）

```powershell
scp -r .\* root@你的公网IP:/var/www/kimic/
```

### 5.5 配置 Nginx

```bash
# 把仓库里的配置复制过去
cp /var/www/kimic/deploy/nginx.conf /etc/nginx/conf.d/kimic.conf

# 删掉 Nginx 自带的默认站点，避免抢 80 端口
rm -f /etc/nginx/sites-enabled/default

# 检查配置语法
nginx -t

# 没问题就重载
systemctl reload nginx
```

现在浏览器打开 `http://你的公网IP/` 就能看到主页了。

### 5.6 目录权限（避免以后拉取出问题）

```bash
chown -R www-data:www-data /var/www/kimic
chmod -R 755 /var/www/kimic
```

### 5.7 绑域名 + HTTPS（可选但推荐）

1. 域名解析：阿里云 → 云解析 DNS → 添加记录
   - 记录类型 `A`，主机记录 `@`，记录值 = 服务器公网 IP
   - 再加一条 `A`，主机记录 `www`，记录值同上
2. 申请证书并自动配置 HTTPS：

```bash
apt install -y certbot python3-certbot-nginx
certbot --nginx -d your-domain.com -d www.your-domain.com
```

certbot 会自动改好 Nginx 配置并设置证书自动续期（`systemctl status certbot.timer` 可以查看）。

3. 顺手把 HTTP 强制跳 HTTPS：certbot 会问你，选 **2 (Redirect)** 即可。

### 5.8 设置开机自启

Nginx 装好后默认就是开机自启，确认一下：

```bash
systemctl enable nginx
systemctl status nginx
```

---

## 6. 以后怎么更新线上内容

**本机改 → 推到 GitHub → 服务器拉取**，三步：

```bash
# ① 本机（改完文件后）
git add -A
git commit -m "更新近况"
git push

# ② 服务器上
cd /var/www/kimic
git pull
```

静态站不用重启任何东西，`git pull` 完刷新浏览器就是新内容。

> 想更省事可以写个一键脚本放服务器上，或者以后加 GitHub Actions 自动部署
> （push 之后服务器自动 pull）。等这个站跑顺了再说，现在没必要。

---

## 7. 可选：GitHub Pages 免费预览

想在建站期间先有个在线地址，不用等阿里云，用 GitHub Pages：

仓库 → **Settings** → **Pages** → Source 选 `Deploy from a branch` →
Branch 选 `main`、目录 `/ (root)` → Save。

一两分钟后访问 `https://kimic.github.io/<仓库名>/`
（如果仓库名就叫 `kimic.github.io`，地址是 `https://kimic.github.io/`）。

> 注意：Pages 在国内访问速度一般，所以它更适合当"随时能看的预览"，
> 正式对外还是走阿里云。

---

## 8. 常见问题

**Q：端口 8080 被占用，起不来？**
换端口：`python dev_server.py -p 8081`。本机 8080 常被其他开发工具占着。

**Q：`python` 命令找不到？**
装 Python 时没勾 "Add Python to PATH"。重装一次勾上，或用 `py` 代替 `python`。

**Q：改了 CSS 但页面没变？**
服务默认关了缓存，正常刷新即可。如果是直接双击打开的 `index.html`，
按 `Ctrl + F5` 强制刷新。

**Q：服务器上 `http://IP` 打不开？**
按顺序查：① 轻量控制台防火墙放行 80 了吗 ② `systemctl status nginx` 是否 running
③ `nginx -t` 是否报错 ④ 内地服务器 + 域名的话，域名是否已备案。

**Q：想加一个博客/作品集页面？**
在根目录新建 `blog/index.html`，把 `assets/` 的相对路径改成 `../assets/`，
然后在导航里加 `<a href="/blog/">博客</a>`。Nginx 配置里 `try_files` 已经支持这种目录形式。

**Q：想换字体？**
改 `assets/css/style.css` 里的 `--font-sans`。想用网络字体，
在 `index.html` 的 `<head>` 里加 `<link>` 引 Google Fonts 或国内 CDN 即可。

---

*最后更新：随仓库一起维护。有问题直接问。*
