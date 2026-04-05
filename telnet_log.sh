#!/bin/bash 

 # Telnet日志记录脚本 
 # 功能：执行telnet连接到指定IP和端口，同时实时记录带时间戳的日志 
 # 使用方法: sudo ./telnet_log.sh <IP地址> <端口> 
 # 示例: sudo ./telnet_log.sh 192.168.90.90 110 

 # 检查参数 
 if [ $# -ne 2 ]; then 
     echo "使用方法: $0 <IP地址> <端口>" 
     echo "示例: $0 192.168.90.90 110" 
     exit 1 
 fi 

 # 获取参数 
 TELNET_IP=$1 
 TELNET_PORT=$2 

 # 基于目标IP、端口和时间戳生成日志文件名 
 LOG_FILE="telnet_${TELNET_IP}_${TELNET_PORT}_$(date +%Y%m%d_%H%M%S).log" 

 # 显示启动信息 
 echo "=== Telnet日志记录器启动 ===" 
 echo "目标地址: ${TELNET_IP}:${TELNET_PORT}" 
 echo "日志文件: $LOG_FILE" 
 echo "退出方式: Ctrl+] 然后输入 quit 并按回车" 
 echo "==============================" 
 echo "" 

 # 创建命名管道用于实时处理 
 PIPE=$(mktemp -u) 
 mkfifo "$PIPE" 

 # 后台处理：实时为输出添加时间戳并写入日志文件 
 (while read line; do 
     echo "[$(date +'%Y-%m-%d %H:%M:%S')] $line" 
 done < "$PIPE" > "$LOG_FILE") & 

 # 保存后台进程PID 
 PROCESS_PID=$! 

 # 启动telnet，将输出重定向到管道 
 echo "正在启动telnet..." 
 script -q -c "telnet ${TELNET_IP} ${TELNET_PORT}" /dev/null 2>&1 | tee "$PIPE" 

 # 清理 
 kill $PROCESS_PID 2>/dev/null 
 rm -f "$PIPE" 2>/dev/null 

 # 显示日志文件信息 
 if [ -f "$LOG_FILE" ]; then 
     echo "" 
     echo "日志记录已完成，日志文件：$LOG_FILE" 
     echo "日志大小: $(ls -lh "$LOG_FILE" | cut -d' ' -f5)" 
 fi