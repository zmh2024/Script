#!/bin/bash

# 设置错误时退出
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_BANTIME=3600
DEFAULT_MAXRETRY=5
DEFAULT_FINDTIME=600
DEFAULT_IGNOREIP="127.0.0.1/8 ::1"

# 全局变量
BANTIME=$DEFAULT_BANTIME
MAXRETRY=$DEFAULT_MAXRETRY
FINDTIME=$DEFAULT_FINDTIME
IGNOREIP="$DEFAULT_IGNOREIP"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助信息
show_help() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -b, --bantime <seconds>    设置封禁时间（秒），默认: $DEFAULT_BANTIME"
    echo "  -m, --maxretry <number>    设置最大尝试次数，默认: $DEFAULT_MAXRETRY"
    echo "  -f, --findtime <seconds>   设置检测时间窗口（秒），默认: $DEFAULT_FINDTIME"
    echo "  -i, --ignoreip <ip_list>   设置白名单IP（用逗号分隔），默认: $DEFAULT_IGNOREIP"
    echo "  -h, --help                 显示此帮助信息"
    echo
    echo "Example:"
    echo "  $0 -b 7200 -m 3 -i '127.0.0.1/8,192.168.1.0/24'"
    exit 0
}

# 参数解析
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -b|--bantime)
                BANTIME="$2"
                shift 2
                ;;
            -m|--maxretry)
                MAXRETRY="$2"
                shift 2
                ;;
            -f|--findtime)
                FINDTIME="$2"
                shift 2
                ;;
            -i|--ignoreip)
                IGNOREIP="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                ;;
            *)
                log_error "Unknown parameter: $1"
                show_help
                ;;
        esac
    done
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# 检查系统
check_system() {
    if ! command -v apt-get &> /dev/null; then
        log_error "This script only works on Debian/Ubuntu systems"
        exit 1
    fi
}

# 安装fail2ban
install_fail2ban() {
    log_info "Updating package list..."
    apt-get update

    log_info "Installing fail2ban..."
    apt-get install -y fail2ban
}

# 配置fail2ban
configure_fail2ban() {
    log_info "Configuring fail2ban..."
    
    # 备份原配置文件
    if [ -f /etc/fail2ban/jail.local ]; then
        log_warn "Backing up existing jail.local..."
        cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.backup.$(date +%Y%m%d%H%M%S)
    fi

    # 创建主配置文件
    cat > /etc/fail2ban/jail.local << EOL
[DEFAULT]
# 封禁时间（秒）
bantime = $BANTIME

# 检测时间范围（秒）
findtime = $FINDTIME

# 在指定时间内失败次数
maxretry = $MAXRETRY

# 忽略的IP地址列表
ignoreip = $IGNOREIP

# 默认使用iptables作为防火墙
banaction = iptables-multiport

# 指定日志级别
loglevel = INFO

# 设置日志位置
logtarget = /var/log/fail2ban.log

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = $MAXRETRY
findtime = $FINDTIME
bantime = $BANTIME
EOL
}

# 启动服务
start_service() {
    log_info "Starting fail2ban service..."
    systemctl start fail2ban
    systemctl enable fail2ban

    if systemctl is-active --quiet fail2ban; then
        log_info "Fail2ban service is running"
    else
        log_error "Fail2ban service failed to start"
        exit 1
    fi
}

# 显示配置信息
show_status() {
    log_info "Checking fail2ban status..."
    fail2ban-client status

    log_info "Installation completed successfully!"
    echo -e "\nSSH Protection Configuration:"
    echo "- Ban Time: $BANTIME seconds"
    echo "- Max Retry: $MAXRETRY times"
    echo "- Find Time: $FINDTIME seconds"
    echo "- Ignored IPs: $IGNOREIP"
    echo -e "\nUseful commands:"
    echo "- Check status: fail2ban-client status"
    echo "- Check SSH jail: fail2ban-client status sshd"
    echo "- Ban IP: fail2ban-client set sshd banip <IP>"
    echo "- Unban IP: fail2ban-client set sshd unbanip <IP>"
    echo "- View logs: tail -f /var/log/fail2ban.log"
}

# 主函数
main() {
    parse_args "$@"
    check_root
    check_system
    install_fail2ban
    configure_fail2ban
    start_service
    show_status
}

# 运行主函数
main "$@"
