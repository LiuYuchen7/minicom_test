#!/bin/bash 
 
 # Minicom日志记录脚本 
 # 功能：使用minicom进行串口交互，同时记录带时间戳的日志 
 # 使用方法: sudo ./minicom_log.sh <设备路径> [日志文件名] 
 # 示例: sudo ./minicom_log.sh /dev/ttyACM4 ACM4.log 
 
 # 检查参数 
 if [ $# -lt 1 ]; then 
     echo "使用方法: $0 <设备路径> [日志文件名]" 
     echo "示例: $0 /dev/ttyACM4 ACM4.log" 
     exit 1 
 fi 
 
 # 获取参数 
 DEVICE=$1 
 
 # 如果提供了日志文件名，则使用提供的名称；否则基于设备名称和时间戳生成 
 if [ $# -eq 2 ]; then 
     LOG_FILE=$2 
 else 
     DEVICE_NAME=$(basename $DEVICE) 
     LOG_FILE="${DEVICE_NAME}_$(date +%Y%m%d_%H%M%S).log" 
 fi 
 
 # 检查设备是否存在 
 if [ ! -e "$DEVICE" ]; then 
     echo "警告: 设备 $DEVICE 不存在或不可访问" 
 fi 
 
 # 显示启动信息 
 echo "=== Minicom日志记录器启动 ===" 
 echo "设备路径: $DEVICE" 
 echo "日志文件: $LOG_FILE" 
 echo "退出方式: Ctrl+A 然后按 X" 
 echo "==============================" 
 echo "" 
 
 # 创建临时日志文件 
 TEMP_LOG=$(mktemp) 
 
 # 启动minicom，使用内置日志功能 
 echo "正在启动minicom..." 
 minicom -D "$DEVICE" -C "$TEMP_LOG" 
 
 # minicom退出后，处理日志文件 
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