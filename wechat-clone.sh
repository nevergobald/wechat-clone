#!/bin/bash
# macOS 微信多开脚本（学习用途）
# 原理：复制 App → 修改 Bundle ID → 重新签名 → 启动
#
# 用法:
#   sudo ./wechat-clone.sh dual          # 双开
#   sudo ./wechat-clone.sh multi 3       # 开3个副本
#   sudo ./wechat-clone.sh rebuild       # 微信更新后重建
#   sudo ./wechat-clone.sh kill          # 关闭所有实例
#   加 --yes 跳过确认提示

set -euo pipefail

# ── 配置 ──────────────────────────────────────────────
WECHAT_SRC="/Applications/WeChat.app"
APPS_DIR="/Applications"
CLONE_NAME="绿泡泡"         # 副本 App 名称前缀
BUNDLE_ID_PREFIX="com.tencent.wechat.clone"
AUTO_YES=0
# ──────────────────────────────────────────────────────

# 颜色输出
info()    { echo -e "\033[0;34m[info]\033[0m $*"; }
success() { echo -e "\033[0;32m[ok]\033[0m $*"; }
warn()    { echo -e "\033[1;33m[warn]\033[0m $*"; }
die()     { echo -e "\033[0;31m[error]\033[0m $*" >&2; exit 1; }

# 检查依赖命令
for cmd in ditto codesign xattr /usr/libexec/PlistBuddy; do
    command -v "$cmd" >/dev/null 2>&1 || die "缺少依赖命令: $cmd"
done

# 检查微信是否安装
check_wechat_exists() {
    [ -d "$WECHAT_SRC" ] || die "未找到微信: $WECHAT_SRC"
    success "检测到微信已安装"
}

# 询问用户确认（--yes 时跳过）
confirm() {
    local msg="$1"
    [ $AUTO_YES -eq 1 ] && return 0
    read -rp "$msg (y/n): " ans
    [[ $ans =~ ^[Yy]$ ]] || return 1
}

# 删除已存在的副本
remove_if_exists() {
    local target="$APPS_DIR/$1"
    if [ -d "$target" ]; then
        confirm "「$1」已存在，是否删除重建？" || die "用户取消"
        rm -rf "$target"
        info "已删除旧副本: $1"
    fi
}

# 复制 WeChat.app
copy_app() {
    local dest="$APPS_DIR/$1"
    info "正在复制 WeChat.app → $1 ..."
    ditto "$WECHAT_SRC" "$dest"
}

# 修改 Bundle ID（核心步骤：让系统把副本当独立 App）
patch_bundle_id() {
    local plist="$APPS_DIR/$1/Contents/Info.plist"
    local new_id="${BUNDLE_ID_PREFIX}.${RANDOM}${RANDOM}"
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $new_id" "$plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $1" "$plist" 2>/dev/null || true
    info "Bundle ID 已修改 → $new_id"
}

# 去除隔离标记 + 重新签名
resign_app() {
    local dest="$APPS_DIR/$1"
    rm -rf "$dest/Contents/_CodeSignature"
    xattr -dr com.apple.quarantine "$dest" 2>/dev/null || true
    info "正在重新签名 $1 ..."
    codesign --force --deep --sign - --timestamp=none "$dest"
    success "$1 签名完成"
}

# 构建单个副本（复制 → patch → 签名）
build_clone() {
    local name="$1"
    remove_if_exists "$name"
    copy_app "$name"
    patch_bundle_id "$name"
    resign_app "$name"
}

# 启动指定 App（-n 强制新实例）
launch_app() {
    open -n "$APPS_DIR/$1"
    sleep 0.8
}

# 列出已存在的副本
list_clones() {
    ls "$APPS_DIR" | grep -E "^${CLONE_NAME}[0-9]*\.app$" || true
}

# ── 命令处理 ──────────────────────────────────────────

cmd_dual() {
    check_wechat_exists
    build_clone "${CLONE_NAME}.app"
    launch_app "WeChat.app"
    launch_app "${CLONE_NAME}.app"
    success "双开启动完成"
}

cmd_multi() {
    local count="${1:-2}"
    [[ "$count" =~ ^[0-9]+$ ]] || die "副本数量必须是数字"
    check_wechat_exists
    launch_app "WeChat.app"
    for i in $(seq 1 "$count"); do
        local name="${CLONE_NAME}${i}.app"
        build_clone "$name"
        launch_app "$name"
    done
    success "已启动 $count 个副本"
}

cmd_rebuild() {
    check_wechat_exists
    local clones
    clones=$(list_clones)
    [ -n "$clones" ] || die "未找到任何副本，请先运行 dual 或 multi"
    info "开始重建所有副本..."
    for name in $clones; do
        warn "重建: $name"
        build_clone "$name"
    done
    success "所有副本重建完成"
}

cmd_kill() {
    pkill -f "WeChat" 2>/dev/null && success "已关闭所有微信进程" || warn "没有运行中的微信进程"
}

cmd_list() {
    local clones
    clones=$(list_clones)
    if [ -z "$clones" ]; then
        warn "暂无副本"
    else
        echo "当前副本："
        for name in $clones; do echo "  • $name"; done
    fi
}

usage() {
    echo "用法: $0 <命令> [选项] [--yes]"
    echo ""
    echo "命令："
    echo "  dual         双开微信（原版 + 1个副本）"
    echo "  multi N      多开 N 个副本"
    echo "  rebuild      重建所有副本（微信更新后使用）"
    echo "  kill         关闭所有微信进程"
    echo "  list         列出当前副本"
    echo ""
    echo "选项："
    echo "  --yes        跳过确认提示"
}

# ── 入口 ──────────────────────────────────────────────

# 解析 --yes 参数
for arg in "$@"; do [[ "$arg" == "--yes" ]] && AUTO_YES=1; done

case "${1:-}" in
    dual)    cmd_dual ;;
    multi)   cmd_multi "${2:-2}" ;;
    rebuild) cmd_rebuild ;;
    kill)    cmd_kill ;;
    list)    cmd_list ;;
    -h|--help|"") usage ;;
    *) die "未知命令: $1，运行 $0 --help 查看用法" ;;
esac
