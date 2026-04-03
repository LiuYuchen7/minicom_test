#!/bin/bash 

 # Telnet日志记录脚本 
 # 功能：执行telnet连接到指定IP和端口，同时记录带时间戳的日志 
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

 # 创建临时日志文件 
 TEMP_LOG=$(mktemp) 

 # 启动telnet，记录日志 
 echo "正在启动telnet..." 
 script -q -c "telnet ${TELNET_IP} ${TELNET_PORT}" "$TEMP_LOG" 

 # telnet退出后，处理日志文件 
 echo "" 
 echo "正在处理日志文件..." 
 awk '{ 
     timestamp = strftime("[%Y-%m-%d %H:%M:%S] "); 
     print timestamp $0; 
 }' "$TEMP_LOG" > "$LOG_FILE" 

 # 显示日志文件信息 
 if [ -f "$LOG_FILE" ]; then 
     echo "日志记录已完成，日志文件：$LOG_FILE" 
     echo "日志大小: $(ls -lh "$LOG_FILE" | cut -d' ' -f5)" 
 fi 

 # 清理 
 rm -f "$TEMP_LOG" 2>/dev/null