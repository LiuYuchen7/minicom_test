#!/usr/bin/env bash

set -u
set -o pipefail

########################################
# 默认参数
########################################
REMOTE_USER="root"
REMOTE_PASS=""
LOCAL_FW=""
REMOTE_FW_TMP="/run/initramfs/image-bmc"
REMOTE_FW_BAK="/run/initramfs/image-bmc-1"
REMOTE_UMOUNT_TARGET="/run/initramfs/bakrsync"

CONNECT_TIMEOUT=10
SSH_OPTS_COMMON=(
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o GlobalKnownHostsFile=/dev/null
  -o LogLevel=ERROR
  -o ConnectTimeout=${CONNECT_TIMEOUT}
)

########################################
# 打印帮助
########################################
usage() {
  cat <<'EOF'
用法:
  flash_bmc.sh -i <IP> -f <firmware_file> -p <password> [端口1 端口2 ...]

示例:
  1) 传短端口号，自动补成 xx22:
     ./flash_bmc.sh -i 10.55.3.217 -f ./new-V23-boot-mctu -p '123456' 62 63 66 67 70 71 74 75

  2) 传完整端口:
     ./flash_bmc.sh -i 10.55.3.217 -f ./new-V23-boot-mctu -p '123456' 6222 6322 6622

可选参数:
  -i  目标 IP
  -f  本地固件文件路径
  -p  SSH 密码（通过 sshpass 使用）
  -u  用户名，默认 root
  -t  连接超时秒数，默认 10
  -h  显示帮助

说明:
  - 若端口小于 1000，则自动按“${port}22”转换。
    例如: 62 -> 6222, 75 -> 7522
  - 每次 scp/ssh 前都会先清理本机 known_hosts 中该 IP:端口 的旧 key
  - 使用 sshpass，无需在命令行交互输入密码
EOF
}

########################################
# 日志
########################################
log() {
  echo "[$(date '+%F %T')] $*"
}

########################################
# 检查命令是否存在
########################################
require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "错误: 未找到命令 '$cmd'，请先安装。" >&2
    exit 1
  }
}

########################################
# 端口标准化
# 62 -> 6222
# 6222 -> 6222
########################################
normalize_port() {
  local p="$1"

  if [[ ! "$p" =~ ^[0-9]+$ ]]; then
    echo "INVALID"
    return
  fi

  if (( p < 1000 )); then
    echo "${p}22"
  else
    echo "${p}"
  fi
}

########################################
# 清理 host key
########################################
clear_host_key() {
  local ip="$1"
  local port="$2"

  # 两种格式都清一遍，避免残留
  ssh-keygen -R "[$ip]:$port" >/dev/null 2>&1 || true
  ssh-keygen -R "$ip" >/dev/null 2>&1 || true
}

########################################
# 执行单个端口刷新
########################################
flash_one() {
  local ip="$1"
  local port="$2"

  log "开始处理 ${ip}:${port}"

  # 1) 先清理旧 key，再 scp
  clear_host_key "$ip" "$port"

  sshpass -p "$REMOTE_PASS" scp \
    -P "$port" \
    "${SSH_OPTS_COMMON[@]}" \
    "$LOCAL_FW" \
    "${REMOTE_USER}@${ip}:${REMOTE_FW_TMP}"

  if [[ $? -ne 0 ]]; then
    log "失败: scp 到 ${ip}:${port} 失败"
    return 1
  fi

  # 2) 再清理一次旧 key，再 ssh 执行远程命令
  clear_host_key "$ip" "$port"

  sshpass -p "$REMOTE_PASS" ssh \
    -p "$port" \
    "${SSH_OPTS_COMMON[@]}" \
    "${REMOTE_USER}@${ip}" \
    "cp '${REMOTE_FW_TMP}' '${REMOTE_FW_BAK}' && umount '${REMOTE_UMOUNT_TARGET}' && reboot"

  #if [[ $? -ne 0 ]]; then
  #  log "失败: ssh 执行远程刷新命令失败 ${ip}:${port}"
  #  return 1
  #fi

  log "成功: ${ip}:${port} 已下发并触发重启"
  return 0
}

########################################
# 主程序
########################################
main() {
  local ip=""
  local raw_ports=()

  while getopts ":i:f:p:u:t:h" opt; do
    case "$opt" in
      i) ip="$OPTARG" ;;
      f) LOCAL_FW="$OPTARG" ;;
      p) REMOTE_PASS="$OPTARG" ;;
      u) REMOTE_USER="$OPTARG" ;;
      t) CONNECT_TIMEOUT="$OPTARG" ;;
      h)
        usage
        exit 0
        ;;
      \?)
        echo "错误: 不支持的参数 -$OPTARG" >&2
        usage
        exit 1
        ;;
      :)
        echo "错误: 参数 -$OPTARG 需要值" >&2
        usage
        exit 1
        ;;
    esac
  done

  shift $((OPTIND - 1))
  raw_ports=("$@")

  # 参数检查
  if [[ -z "$ip" || -z "$LOCAL_FW" || -z "$REMOTE_PASS" || ${#raw_ports[@]} -eq 0 ]]; then
    echo "错误: 参数不足" >&2
    usage
    exit 1
  fi

  require_cmd ssh
  require_cmd scp
  require_cmd sshpass
  require_cmd ssh-keygen

  if [[ ! -f "$LOCAL_FW" ]]; then
    echo "错误: 固件文件不存在: $LOCAL_FW" >&2
    exit 1
  fi

  if [[ ! "$CONNECT_TIMEOUT" =~ ^[0-9]+$ ]]; then
    echo "错误: 超时时间必须是整数" >&2
    exit 1
  fi

  # 更新 SSH 参数中的超时时间
  SSH_OPTS_COMMON=(
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
    -o GlobalKnownHostsFile=/dev/null
    -o LogLevel=ERROR
    -o ConnectTimeout=${CONNECT_TIMEOUT}
  )

  local ok_count=0
  local fail_count=0
  local failed_ports=()

  log "目标 IP: $ip"
  log "固件文件: $LOCAL_FW"
  log "端口数量: ${#raw_ports[@]}"

  local raw_port port
  for raw_port in "${raw_ports[@]}"; do
    port="$(normalize_port "$raw_port")"

    if [[ "$port" == "INVALID" ]]; then
      log "跳过: 非法端口 '$raw_port'"
      ((fail_count++))
      failed_ports+=("$raw_port")
      continue
    fi

    flash_one "$ip" "$port"
    if [[ $? -eq 0 ]]; then
      ((ok_count++))
    else
      ((fail_count++))
      failed_ports+=("$port")
    fi
  done

  log "全部处理完成: 成功 ${ok_count} 个, 失败 ${fail_count} 个"

  if [[ ${#failed_ports[@]} -gt 0 ]]; then
    log "失败端口: ${failed_ports[*]}"
    exit 1
  fi

  exit 0
}

main "$@"
