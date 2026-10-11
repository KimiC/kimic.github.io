> 部署与迁移手册：从本机预览 → GitHub 仓库 → 阿里云轻量应用服务器
> 这是给你（Kimi）自己看的操作说明，每一步都可以照着敲。

---

# 目录

1. [现在在哪儿跑](#1-现在在哪儿跑)
2. [本地预览](#2-本地预览)
3. [改内容改哪里](#3-改内容改哪里)
4. [推到 GitHub](#4-推到-github)
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
├── 404.html                  ← 找不到页面时显示
├── .nojekyll                 ← 让 GitHub Pages 跳过 Jekyll 处理
├── assets/
│   ├── css/style.css         ← 全部样式（极简黑白主题 + 深色模式）
│   ├── js/main.js            ← 交互：主题切换、滚动动画、导航高亮
│   └── img/                  ← 照片：Kimi.jpg / Kimi-1200.jpg / Kimi-800.jpg
├── dev_server.py             ← 本地预览服务器（Python 标准库，无需安装）
├── start.bat                 ← Windows 双击启动本地预览
├── start.sh                  ← macOS / Linux 启动本地预览
├── deploy-github.bat         ← Windows 双击：提交 + 推送到 GitHub
├── deploy/
│   ├── nginx.conf            ← 站点配置**模板**（__PORT__ / __SERVER_NAME__ 占位符）
│   ├── setup-server.sh       ← 服务器上跑：一键部署 / 一键更新
│   └── DEPLOY.md             ← 你正在看的这份
├── .gitignore
└── README.md
```

> `dsh-bot/`（DSH 飞书机器人踩坑记录）是另一件事，已经被 `.gitignore` 排除，
> **不会**被推到主页仓库、也不会出现在网站上。

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
| 邮箱 / GitHub 链接 | `index.html` → `<section id="contact">`，搜 `chenkimi12@hotmail.com` 和 `@KimiC` |
| 颜色（想换个主色调） | `assets/css/style.css` 最上面的 `:root { }` 变量 |
| 头像照片 | 把图片放进 `assets/img/`，替换 `about` 里的 `portrait-frame` 那块 |
| 导航菜单 | `index.html` 里 `class="nav"` 的 `<a>` 列表 |

> ✅ 早先那几处**占位内容已经全部替换完成**，现在页面上是真内容：
> 邮箱 `chenkimi12@hotmail.com`、GitHub 链接 `https://github.com/KimiC`、
> 关于区块用的是 `assets/img/Kimi.jpg`（配 `srcset` 自动挑尺寸）。
> 页面里也**没有**给人看的临时提示文字了，可以直接对外发布。

---

## 4. 推到 GitHub

仓库在 **<https://github.com/KimiC/kimic.github.io>**，而且 **`default-workspace` 本身就是它的克隆**：

| 项目 | 现状 |
| --- | --- |
| 本地分支 | `main`，14 次提交 |
| `origin` | `https://github.com/KimiC/kimic.github.io.git` —— 已配置好，`main` 已跟踪 `origin/main` |
| 提交身份 | `Kimi Chen <kimic@users.noreply.github.com>` —— 用的是 GitHub 的 noreply 邮箱，**不会暴露真实邮箱** |
| 同步状态 | 本地 `origin/main` = 远程 `main` = `da9f8833`（"去掉照片上的 KIMI-C 文字"）—— **完全一致** |

所以推代码这件事**没有"初始化"步骤**：仓库、远端、身份都是现成的，
只需要把当前改动提交并推上去。

### 4.1 一条命令搞定（推荐）

在 `default-workspace` 里**双击 `deploy-github.bat`**。它会做完：

1. 发现 `.git` 已存在 → 跳过 `git init`（不会碰历史）
2. 提交身份已配置 → 不动它（脚本只在**完全没配**时才补一个）
3. `git add -A` + `git commit`
4. `origin` 已指向正确的仓库 → 不动它
5. `git push -u origin main`
6. 把结果打出来

**这条脚本可以反复跑**：以后每次改完网页，再双击一次就是「提交 + 推送」。
它不会删你本地任何文件，也不会改写已有提交。

> 想先看一眼"这次到底会提交哪些文件"？在 `default-workspace` 里开个终端跑：
> ```bash
> git status --short
> ```
> `??` 是新增、` M` 是修改。确认没问题再双击脚本。

> 📌 **这次会推上去的新文件**：`deploy-github.bat`、`deploy/setup-server.sh`、`.nojekyll`，
> 以及改过的 `deploy/nginx.conf`、`deploy/DEPLOY.md`、`README.md`、`.gitignore`
> （`.gitignore` 里新增了 `dsh-bot/`，所以那个项目**不会**被推上去）。

### 4.2 推送会问账号密码

- 用户名：`KimiC`
- 密码：**填 Personal Access Token，不是 GitHub 登录密码**

> 如果 Windows 凭据管理器里已经存过 Token，这一步会直接跳过。
> 需要重新生成时：GitHub → 右上角头像 → Settings → Developer settings →
> Personal access tokens → **Tokens (classic)** → Generate new token (classic) →
> 勾选 `repo` → 生成后**立刻复制**（离开页面就再也看不到）。

### 4.3 如果推送报错

| 屏幕上出现的提示 | 怎么办 |
| --- | --- |
| `"git" was not found in PATH` | 脚本会问你 git.exe 所在目录。如果 Git 装在 `D:\乱七八糟\Git`，就填 `D:\乱七八糟\Git\cmd`；或者重装 Git 时勾上 "Add Git to PATH" |
| `Authentication failed` | Token 没填对或已过期，重跑脚本，重新生成一个 Token |
| `nothing to commit` | 不算错误，说明没有改动需要提交 |
| `rejected ... non-fast-forward` | 远程有你本地没有的提交（比如你在 GitHub 网页上直接改过文件）。先 `git pull --rebase origin main`，解决冲突后再重跑；**别直接 `--force`**，那会盖掉网页上那次改动 |

### 4.4 不想用脚本的话，手动就这三条

```bash
git add -A
git commit -m "deploy: 部署到阿里云新加坡服务器（8899）"
git push
```

`git init` / `git remote add` / `git branch -M` 这些**不需要**了 —— 仓库早就配好了。

### 4.5 白捡一个免费在线地址（可选）

**这个已经开好了，什么都不用做**：<https://kimic.github.io/> 现在就能访问
（仓库名就叫 `kimic.github.io`，所以地址没有子路径）。

想确认或重新打开：仓库 → **Settings** → **Pages** → Source 选
`Deploy from a branch` → Branch 选 `main`、目录 `/ (root)` → **Save**。

> 这跟阿里云**不冲突**，两边内容来自同一个仓库：
> GitHub 这份当"随时能看的预览"，阿里云那份当正式站。

---

## 5. 搬到阿里云轻量应用服务器

> 目标地址：**<http://47.82.233.199:8899/>**
> 服务器在**新加坡**，是 **raftchen 的机器**，而且**上面已经跑着别的站点** —— 所以下面每一步都按"合租"来设计，不抢端口、不动别人的配置。

### 5.1 服务器现状

服务器已经买好了，是 **raftchen 的阿里云轻量应用服务器**：

| 项目 | 值 |
| --- | --- |
| 公网 IP | `47.82.233.199` |
| 地域 | **新加坡**（`AS45102 Alibaba`，所以**不需要备案**） |
| 已有站点 | ⚠️ **有**。用 `http://47.82.233.199/` 会被 301 跳到 `https://`，说明 80 端口上已经有一个 `default_server` 在跑别人的站 |

**因为这台机器不是你独占的，部署方式要选对：**

- ❌ 不要用 `listen 80 default_server` —— nginx 只允许一个 `default_server` 监听同一端口，
  硬加会报 `a duplicate default server for 0.0.0.0:80`，启动失败，还可能把别人的站点带下去。
- ❌ 不要 `rm -f /etc/nginx/sites-enabled/default` —— 那可能是别人正在用的配置。
- ✅ 我们只在**一个独立端口**（默认 `8899`）上把主页挂起来，和已有站点井水不犯河水。

你需要向 raftchen 拿到：**`admin` 用户的登录密码**（不是 root 直登）、以及**在控制台加一条防火墙规则**的权限。
脚本里所有要动系统的地方都会用 `sudo`。

### 5.2 放行端口（两层防火墙）

轻量服务器的防火墙是**两层**，两层都要开：

1. **阿里云轻量控制台** → 你的实例 → 防火墙 → 添加规则：`TCP 8899`（我们给主页选的端口）
2. 服务器**内部**的防火墙如果开着，也要放行（二选一，看装了哪个）：
   - `sudo ufw allow 8899/tcp`
   - `sudo firewall-cmd --add-port=8899/tcp --permanent && sudo firewall-cmd --reload`（firewalld，RHEL 系常见）

> 脚本跑完会自己检测 ufw / firewalld 是否在运行，并在结尾把该敲的命令打出来。

> ⚠️ 加防火墙规则属于对 raftchen 服务器的改动，**先跟他说一声**。
> 这也是唯一需要动控制台的地方，80/443 我们完全不碰。

> ✅ 服务器在新加坡地域，**不需要备案**，以后绑域名只要 DNS 解析生效就能用。

### 5.3 连上服务器

Windows 上用 PowerShell 连：

```bash
ssh admin@47.82.233.199
```

> ⚠️ 登录用户是 **`admin`，不是 `root`**。所以：
> - 直接 `git clone ... /var/www/kimic` 会报 `Permission denied`（`/var/www` 只有 root 能写）
> - 需要动系统的地方都要加 `sudo`
>
> 先确认 sudo 可用：
> ```bash
> sudo id        # 看到 uid=0(root) 就对了
> ```
>
> 第一次连接会问 `Are you sure you want to continue connecting?`，输入 `yes`。

### 5.4 两条命令完成部署

> 前提：GitHub 上已经有最新代码 —— 先在**本机**跑一次 `deploy-github.bat` 推上去。
> 没推的话服务器拉到的还是没有 `setup-server.sh` 的旧版。

因为 `/var/www` 只有 root 能写，**不要在 `admin` 身份下自己 clone 到那里**，
交给脚本用 `sudo` 去克隆：

```bash
# ① 先在工作目录拿一份仓库（用来跑脚本）
cd ~
git clone https://github.com/KimiC/kimic.github.io.git    # 已经克隆过就跳过
cd kimic.github.io
git pull                                                  # 确保拿到最新脚本

# ② 用 root 权限跑：装依赖、克隆到 /var/www/kimic、配 Nginx、自测
sudo bash deploy/setup-server.sh
```

`setup-server.sh` 会做这些事，**并且可以反复跑**：

1. 自动识别包管理器（`apt-get` / `dnf` / `yum`），缺 Nginx / Git / curl 才安装
2. 站点目录没有仓库就 `git clone` 到 `/var/www/kimic`，有就 `git pull --ff-only`（拉不动时自动强制对齐 GitHub）
3. 用 `deploy/nginx.conf` **模板**生成 `/etc/nginx/conf.d/kimic.conf`：
   把 `__PORT__` 换成 `8899`、`__SERVER_NAME__` 换成 `_`
   （**不碰 80/443，不碰 `sites-enabled/default`，不声明 `default_server`**）
4. **写配置前先备份**，如果 `nginx -t` 不通过，**自动回滚**并退出 —— 服务器不会停在半坏的状态
5. 自动识别 nginx 运行用户（Debian 系 `www-data`，RHEL 系 `nginx`）再 `chown`，`chmod -R a+rX`，
   并关掉 `core.fileMode` 防止权限变化挡住以后的 `git pull`
6. 如果是 RHEL 系且 SELinux 开着，给站点目录打 `httpd_sys_content_t` 标签（否则可能 403）
7. `systemctl enable nginx` → `reload`，然后 `curl` 本机自测，把结果打出来
8. 打印访问地址、以及"还要去控制台放行 8899"的提醒

跑完打开 **<http://47.82.233.199:8899/>** 就能看到主页了。

> 想换端口：`sudo PORT=9000 bash deploy/setup-server.sh`
> （换端口后要记得同步改控制台防火墙规则；已经生成过配置的话加 `FORCE_NGINX=1` 重新渲染）

> **更省事的写法**（仓库是公开的才能用）：
> ```bash
> curl -fsSLo /tmp/setup-server.sh https://raw.githubusercontent.com/KimiC/kimic.github.io/main/deploy/setup-server.sh
> sudo bash /tmp/setup-server.sh
> ```

### 5.5 手动步骤（脚本万一出问题时对照用）

```bash
sudo apt update && sudo apt install -y nginx git curl        # RHEL 系换成 sudo dnf install
sudo git clone https://github.com/KimiC/kimic.github.io.git /var/www/kimic

# 渲染配置模板：__PORT__ -> 8899，__SERVER_NAME__ -> _
sed -e 's/__PORT__/8899/g' -e 's/__SERVER_NAME__/_/g' \
    /var/www/kimic/deploy/nginx.conf | sudo tee /etc/nginx/conf.d/kimic.conf >/dev/null

sudo nginx -t && sudo systemctl reload nginx
sudo chown -R www-data:www-data /var/www/kimic              # RHEL 系改成 nginx:nginx
sudo chmod -R a+rX /var/www/kimic
sudo systemctl enable nginx
```

> ⚠️ 手动步骤里**没有** `rm -f /etc/nginx/sites-enabled/default`，也**不要**加
> `default_server` —— 这台机器上还有别人的站点，这两下都可能把它弄挂。
>
> 仓库如果是私有的，克隆要带 token：
> `git clone https://<你的token>@github.com/KimiC/kimic.github.io.git /var/www/kimic`
>
> 直接从本机上传也行（Windows PowerShell，在 `default-workspace` 里执行）：
> ```powershell
> scp -r .\index.html .\404.html .\.nojekyll .\assets root@47.82.233.199:/var/www/kimic/
> ```

### 5.6 绑域名 + HTTPS（可选，但有域名才好看）

> 先用 `:8899` 访问没问题了，再考虑这一步。域名可以以后再买、再绑，
> 站点内容完全不用改。

1. 域名解析：在你买域名的地方加两条 `A` 记录，都指向 `47.82.233.199`
   - 主机记录 `@`（也就是裸域名）
   - 主机记录 `www`
2. 在服务器上，用同一个脚本换成域名版：

```bash
EMAIL=你的邮箱 bash /var/www/kimic/deploy/setup-server.sh --domain example.com --https
```

它会重新渲染配置（`listen 80` + `server_name example.com www.example.com`）、
申请 Let's Encrypt 证书、把 HTTP 强制跳到 HTTPS，并交给 `certbot.timer` 自动续期
（查状态：`systemctl status certbot.timer`）。

只想绑域名、暂时不申请证书：

```bash
bash /var/www/kimic/deploy/setup-server.sh --domain example.com
```

> **这一版配置监听 80 端口，但仍然是普通虚拟主机、不是 `default_server`**，
> 所以和服务器上已有的站点可以共存 —— 请求的 `Host` 不是你的域名时，
> 会落到原来那个 `default_server` 上，别人的站点不受影响。

> ✅ 新加坡地域**不需要备案**。绑域名前确认一下：如果那个域名以前备案过、
> 或者 raftchen 已经有域名指向这台机器，直接加子域名最省事。

---

## 6. 以后怎么更新线上内容

**本机改 → 推到 GitHub → 服务器拉取**，就两步：

```bash
# ① 本机：双击 deploy-github.bat
#    （命令行等价写法：git add -A && git commit -m "更新近况" && git push）

# ② 服务器上：再跑一次同一个脚本
bash /var/www/kimic/deploy/setup-server.sh
```

静态站不用重启任何东西，脚本跑完刷新浏览器就是新内容。

> 想连第 ② 步都省掉，以后可以加 GitHub Actions 或 Webhook，
> 让 push 之后服务器自动拉取。现在两条命令已经够顺手，先这样跑。

---

## 7. 可选：GitHub Pages 免费预览

仓库名就叫 `kimic.github.io`，所以只要打开一次开关：
仓库 → **Settings** → **Pages** → Source 选 `Deploy from a branch` →
Branch 选 `main`、目录 `/ (root)` → **Save**。

一两分钟后访问 **<https://kimic.github.io/>**（没有子路径，很干净）。
具体步骤在 [4.5](#45-白捡一个免费在线地址可选) 也写了一份。

> 注意：Pages 在国内访问速度一般，所以它更适合当"随时能看的预览"，
> 正式对外还是走阿里云。两边内容完全一样，都来自同一个仓库。

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

**Q：为什么站点挂在 `:8899` 而不是 80 端口？**
因为这台机器上 80 端口已经被别人的站点占了（访问 IP 会跳到 https）。
nginx 只允许一个 `default_server` 监听同一端口，我们再去抢 80，
轻则 `nginx -t` 报 `duplicate default server` 起不来，重则把别人的站点带下线。
挂独立端口是最稳的做法。想要好看的地址，就按 [5.6](#56-绑域名--https可选但有域名才好看) 绑一个域名。

**Q：会不会影响 raftchen 原有站点？**
不会。脚本只做三件事：写 `/etc/nginx/conf.d/kimic.conf`、建 `/var/www/kimic`、
`reload` nginx。它**不删** `sites-enabled/default`、**不声明** `default_server`、
**不改**任何已有文件；而且写配置前会先备份，`nginx -t` 一旦不通过就**自动回滚**，
服务器保持原样。想彻底确认，跑完让 raftchen 看一眼 `nginx -t` 输出和访问日志即可。

**Q：`http://47.82.233.199:8899/` 打不开？**
按顺序查：① 轻量控制台防火墙放行 `TCP 8899` 了吗 ② `systemctl status nginx` 是否 running
③ 脚本最后的"本机自测"是不是 `[OK]` ④ 是不是被公司/学校网络拦了非常用端口。

---

*最后更新：随仓库一起维护。有问题直接问。*
