#!/bin/bash 

 # Minicom日志记录脚本 
 # 功能：使用minicom进行串口交互，同时实时记录带时间戳的日志 
 # 使用方法: sudo ./minicom_log.sh <设备路径> 
 # 示例: sudo ./minicom_log.sh /dev/ttyACM4 

 # 检查参数 
 if [ $# -ne 1 ]; then 
     echo "使用方法: $0 <设备路径>" 
     echo "示例: $0 /dev/ttyACM4" 
     exit 1 
 fi 

 # 获取参数 
 DEVICE=$1 

 # 基于设备名称和时间戳生成日志文件名 
 DEVICE_NAME=$(basename $DEVICE) 
 LOG_FILE="${DEVICE_NAME}_$(date +%Y%m%d_%H%M%S).log" 
 
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
 
 # 创建命名管道用于实时处理 
 PIPE=$(mktemp -u) 
 mkfifo "$PIPE" 
 
 # 后台处理：实时为输出添加时间戳并写入日志文件 
 (while read line; do 
     echo "[$(date +'%Y-%m-%d %H:%M:%S')] $line" 
 done < "$PIPE" > "$LOG_FILE") & 
 
 # 保存后台进程PID 
 PROCESS_PID=$! 
 
 # 启动minicom，将输出重定向到管道 
 echo "正在启动minicom..." 
 minicom -D "$DEVICE" 2>&1 | tee "$PIPE" 
 
 # 清理 
 kill $PROCESS_PID 2>/dev/null 
 rm -f "$PIPE" 2>/dev/null 
 
 # 显示日志文件信息 
 if [ -f "$LOG_FILE" ]; then 
     echo "" 
     echo "日志记录已完成，日志文件：$LOG_FILE" 
     echo "日志大小: $(ls -lh "$LOG_FILE" | cut -d' ' -f5)" 
 fi