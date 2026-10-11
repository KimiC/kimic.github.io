#!/usr/bin/env bash
# ===================================================================
#  setup-server.sh —— 阿里云轻量应用服务器：部署 / 更新个人主页
#
#  ⚠️ 这台服务器（47.82.233.199）上已经跑着别的站点：
#     80 端口有个 default_server 在做 http -> https 跳转。
#     所以本脚本**刻意不碰 80/443、不碰 sites-enabled/default、
#     不声明 default_server**，只在一个独立端口上把主页挂起来，
#     和已有站点井水不犯河水。
#
#  第一次跑：装 Nginx + Git，克隆仓库到 /var/www/kimic，配好站点
#  以后再跑：同一条命令，拉取最新代码 + 重载 Nginx（幂等）
#
#  用法（服务器上，**需要 root**；如果登录用户是 admin/ubuntu 就加 sudo）：
#     sudo bash setup-server.sh
#         挂到 http://47.82.233.199:8899/（默认端口 8899）
#
#     sudo PORT=9000 bash setup-server.sh
#         换端口。
#
#     sudo bash setup-server.sh --domain example.com
#         有域名时用这个：把站点挂到 80 端口并匹配该域名。
#
#     sudo EMAIL=me@example.com bash setup-server.sh --domain example.com --https
#         再加 Let's Encrypt 证书 + 强制 https（新加坡地域不需要备案）。
#
#  兼容性：自动识别 apt-get / dnf / yum，也自动识别 nginx 运行用户
#         （Debian 系是 www-data，RHEL 系是 nginx），并处理 SELinux 标签。
#
#  可覆盖的变量：
#     REPO_URL   默认 https://github.com/KimiC/kimic.github.io.git
#     SITE_DIR   默认 /var/www/kimic
#     PORT       默认 8899（只在没有域名时用）
#     FORCE_NGINX=1  重新渲染 Nginx 配置（会覆盖服务器上现有那份）
#
#  安全兜底：写配置前会备份，nginx -t 不通过就自动回滚，
#            服务器保持原样，不会留下半坏的状态。
# ===================================================================
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/KimiC/kimic.github.io.git}"
SITE_DIR="${SITE_DIR:-/var/www/kimic}"
NGINX_CONF="${NGINX_CONF:-/etc/nginx/conf.d/kimic.conf}"
EMAIL="${EMAIL:-}"
PORT="${PORT:-8899}"

DOMAIN=""
USE_HTTPS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --https)     USE_HTTPS=1 ;;
    --domain)    shift; DOMAIN="${1:-}"; [ -n "$DOMAIN" ] || { echo "--domain 后面要跟域名" >&2; exit 2; } ;;
    --port)      shift; PORT="${1:-}"; [ -n "$PORT" ] || { echo "--port 后面要跟端口号" >&2; exit 2; } ;;
    --force-nginx) FORCE_NGINX=1 ;;
    -h|--help)   awk 'NR>1 && /^#/ {print; next} NR>1 {exit}' "$0"; exit 0 ;;
    -*)          echo "未知参数：$1（用 --help 看用法）" >&2; exit 2 ;;
    *)           DOMAIN="$1" ;;
  esac
  shift
done

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m[X] %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "请用 root 运行，或者：sudo bash $0 $*"
if [ "$USE_HTTPS" = 1 ] && [ -z "$DOMAIN" ]; then
  die "--https 需要同时给域名，例如：bash $0 --domain example.com --https"
fi
case "$PORT" in
  ''|*[!0-9]*) die "端口必须是数字，现在是：$PORT" ;;
esac
[ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ] || die "端口越界：$PORT"

# ---------------------------------------------------------------- 包管理器
if command -v apt-get >/dev/null 2>&1; then
  PKG=apt
elif command -v dnf >/dev/null 2>&1; then
  PKG=dnf
elif command -v yum >/dev/null 2>&1; then
  PKG=yum
else
  PKG=""
fi
[ -n "$PKG" ] || die "找不到 apt-get / dnf / yum；请手动装好 nginx 和 git 再跑本脚本"

pkg_install() {
  case "$PKG" in
    apt) export DEBIAN_FRONTEND=noninteractive
         apt-get update -y
         apt-get install -y "$@" ;;
    dnf) dnf install -y "$@" ;;
    yum) yum install -y "$@" ;;
  esac
}

nginx_run_user() {
  local u=""
  if [ -f /etc/nginx/nginx.conf ]; then
    u="$(sed -n 's/^[[:space:]]*user[[:space:]]\{1,\}\([^ ;]*\).*/\1/p' /etc/nginx/nginx.conf | head -n1)"
  fi
  printf '%s' "$u"
}

port_in_use() {
  local p="$1" out=""
  if command -v ss >/dev/null 2>&1; then
    out="$(ss -ltnH "( sport = :$p )" 2>/dev/null || true)"
  elif command -v netstat >/dev/null 2>&1; then
    out="$(netstat -ltn 2>/dev/null | awk -v p=":$p" '$4 ~ p"$" {print $4}' || true)"
  fi
  [ -n "$out" ]
}

# ---------------------------------------------------------------- 1. 依赖
say "包管理器：$PKG"
if command -v nginx >/dev/null 2>&1 && command -v git >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
  say "Nginx / Git / curl 已安装，跳过"
else
  say "安装 Nginx / Git / curl"
  pkg_install nginx git ca-certificates curl
fi

# ---------------------------------------------------------------- 2. 代码
if [ -d "$SITE_DIR/.git" ]; then
  say "更新代码：git pull"
  if ! git -C "$SITE_DIR" pull --ff-only; then
    warn "无法快进，改为强制与 GitHub 同步（服务器上的本地改动会被覆盖）"
    BRANCH="$(git -C "$SITE_DIR" rev-parse --abbrev-ref HEAD)"
    git -C "$SITE_DIR" fetch --prune origin
    git -C "$SITE_DIR" reset --hard "origin/$BRANCH"
  fi
else
  say "首次部署：克隆仓库到 $SITE_DIR"
  if [ -e "$SITE_DIR" ] && [ -n "$(ls -A "$SITE_DIR" 2>/dev/null || true)" ]; then
    BACKUP_DIR="${SITE_DIR}.bak.$(date +%Y%m%d%H%M%S)"
    warn "$SITE_DIR 已存在且不是 git 仓库，先备份到 $BACKUP_DIR"
    mv "$SITE_DIR" "$BACKUP_DIR"
  fi
  mkdir -p "$(dirname "$SITE_DIR")"
  git clone "$REPO_URL" "$SITE_DIR"
fi

[ -f "$SITE_DIR/index.html" ] || die "$SITE_DIR/index.html 不存在，仓库内容看起来不对"

# 服务器上不做本地修改，关掉文件模式检查，避免权限调整挡住以后的 git pull
git -C "$SITE_DIR" config core.fileMode false

# ---------------------------------------------------------------- 3. Nginx 配置
TEMPLATE="$SITE_DIR/deploy/nginx.conf"
[ -f "$TEMPLATE" ] || die "仓库里找不到 deploy/nginx.conf，无法配置站点"

WRITE_CONF=0
if [ ! -f "$NGINX_CONF" ]; then
  WRITE_CONF=1
elif [ -n "$DOMAIN" ] || [ "${FORCE_NGINX:-0}" = "1" ]; then
  WRITE_CONF=1
fi

if [ "$DOMAIN" != "" ]; then
  RENDER_PORT=80
  RENDER_NAME="$DOMAIN www.$DOMAIN"
else
  RENDER_PORT="$PORT"
  RENDER_NAME="_"
fi

if [ "$WRITE_CONF" = 0 ]; then
  say "Nginx 配置已存在，保持不变：$NGINX_CONF"
  echo "    想按当前参数重新生成：FORCE_NGINX=1 bash $0 $*"
elif [ "$DOMAIN" = "" ] && [ ! -f "$NGINX_CONF" ] && port_in_use "$PORT"; then
  die "端口 $PORT 上已经有别的服务在监听（换个端口：PORT=9000 bash $0）"
else
  say "生成 Nginx 配置：$NGINX_CONF"
  CONF_BACKUP=""
  if [ -f "$NGINX_CONF" ]; then
    CONF_BACKUP="$(mktemp /tmp/kimic-nginx.XXXXXX)"
    cp -p "$NGINX_CONF" "$CONF_BACKUP"
    echo "    已备份原配置到 $CONF_BACKUP"
  fi

  sed -e "s/__PORT__/${RENDER_PORT}/g" \
      -e "s/__SERVER_NAME__/${RENDER_NAME}/g" \
      "$TEMPLATE" > "$NGINX_CONF"

  say "检查 Nginx 配置语法"
  if ! nginx -t; then
    if [ -n "$CONF_BACKUP" ]; then
      cp -p "$CONF_BACKUP" "$NGINX_CONF"
      warn "配置有问题，已回滚到原来的配置，服务器维持原样"
    else
      rm -f "$NGINX_CONF"
      warn "配置有问题，已删掉刚写入的文件，服务器维持原样"
    fi
    die "nginx -t 没通过，上面有具体原因"
  fi
fi

if [ -n "${CONF_BACKUP:-}" ]; then
  rm -f "$CONF_BACKUP"
fi

# ---------------------------------------------------------------- 4. 权限
say "设置目录权限"
NGINX_USER="$(nginx_run_user)"
if [ -z "$NGINX_USER" ]; then
  for cand in www-data nginx; do
    if id -u "$cand" >/dev/null 2>&1; then NGINX_USER="$cand"; break; fi
  done
fi
if [ -n "$NGINX_USER" ] && id -u "$NGINX_USER" >/dev/null 2>&1; then
  echo "    nginx 运行用户：$NGINX_USER"
  chown -R "$NGINX_USER" "$SITE_DIR" || warn "chown 失败，跳过（文件本来就可读）"
else
  warn "没识别出 nginx 运行用户，跳过 chown"
fi
chmod -R a+rX "$SITE_DIR"

# SELinux（RHEL 系 / Alibaba Cloud Linux）：默认标签可能让 nginx 返回 403
if command -v getenforce >/dev/null 2>&1; then
  ENFORCE="$(getenforce 2>/dev/null || echo Disabled)"
  if [ "$ENFORCE" != "Disabled" ]; then
    say "SELinux 处于 $ENFORCE 状态，给站点目录打 Web 内容标签"
    if chcon -R -t httpd_sys_content_t "$SITE_DIR" 2>/dev/null; then
      echo "    chcon 已应用"
    else
      warn "chcon 失败；如果访问返回 403，需要让 raftchen 处理 SELinux"
    fi
  fi
fi

# ---------------------------------------------------------------- 5. 生效
say "启动 / 重载 Nginx"
systemctl enable nginx >/dev/null 2>&1 || true
systemctl reload nginx 2>/dev/null || systemctl restart nginx

# ---------------------------------------------------------------- 6. HTTPS
if [ "$USE_HTTPS" = 1 ]; then
  say "申请免费证书并开启 HTTPS：$DOMAIN"
  pkg_install certbot python3-certbot-nginx
  if [ -n "$EMAIL" ]; then
    certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" --redirect -n --agree-tos -m "$EMAIL"
  else
    certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" --redirect -n --agree-tos \
            --register-unsafely-without-email
  fi
  systemctl reload nginx
  say "HTTPS 已配置，续期由 certbot.timer 负责"
fi

# ---------------------------------------------------------------- 7. 自测
say "本机自测"
TEST_URL="http://127.0.0.1:${RENDER_PORT}/"
if [ -n "$DOMAIN" ]; then
  if curl -fsS -m 8 -o /dev/null -H "Host: $DOMAIN" "$TEST_URL"; then
    echo "    [OK] $TEST_URL 返回 200"
  else
    warn "$TEST_URL 自测没通过，看 /var/log/nginx/kimic.error.log"
  fi
else
  if curl -fsS -m 8 -o /dev/null "$TEST_URL"; then
    echo "    [OK] $TEST_URL 返回 200"
  else
    warn "$TEST_URL 自测没通过，看 /var/log/nginx/kimic.error.log"
  fi
fi

# ---------------------------------------------------------------- 8. 收尾
PUBLIC_IP="$(curl -fsS -m 5 https://api.ipify.org 2>/dev/null || true)"
say "完成"
if [ -n "$DOMAIN" ]; then
  echo "    访问地址：https://$DOMAIN/"
else
  if [ -n "$PUBLIC_IP" ]; then
    echo "    访问地址：http://$PUBLIC_IP:$PORT/"
  else
    echo "    访问地址：http://<公网IP>:$PORT/"
  fi
  echo "    ⚠️ 还要在「阿里云轻量控制台 → 防火墙」放行 TCP $PORT，否则外面打不开"
  if systemctl is-active --quiet firewalld 2>/dev/null; then
    echo "       另外检测到服务器内部 firewalld 在运行，可能也要放行："
    echo "         firewall-cmd --add-port=$PORT/tcp --permanent && firewall-cmd --reload"
  elif systemctl is-active --quiet ufw 2>/dev/null; then
    echo "       另外检测到服务器内部 ufw 在运行，可能也要放行：ufw allow $PORT/tcp"
  fi
fi
echo "    站点目录：$SITE_DIR"
echo "    以后更新：服务器上再跑一次这条命令"
echo "    配置文件：$NGINX_CONF（由 deploy/nginx.conf 模板生成）"
