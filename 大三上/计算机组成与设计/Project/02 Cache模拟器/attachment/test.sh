#!/bin/bash

# 定义 Trace 文件路径
TRACE_FILE="ext_traces/spice.trace"

# 定义运行的命令列表
commands=(
    # --- Split Cache (Size变化) ---
    "./code/sim -bs 16 -is 8192 -ds 8192 -a 1 -wb -wa $TRACE_FILE"   # 8K Split
    "./code/sim -bs 16 -is 16384 -ds 16384 -a 1 -wb -wa $TRACE_FILE" # 16K Split
    "./code/sim -bs 16 -is 32768 -ds 32768 -a 1 -wb -wa $TRACE_FILE" # 32K Split
    "./code/sim -bs 16 -is 65536 -ds 65536 -a 1 -wb -wa $TRACE_FILE" # 64K Split
    
    # --- Unified Cache (Size固定, BlockSize变化) ---
    "./code/sim -bs 16 -us 8192 -a 1 -wb -wa $TRACE_FILE"            # 8K Unified BS 16
    "./code/sim -bs 32 -us 8192 -a 1 -wb -wa $TRACE_FILE"            # 8K Unified BS 32
    "./code/sim -bs 64 -us 8192 -a 1 -wb -wa $TRACE_FILE"            # 8K Unified BS 64
    "./code/sim -bs 128 -is 32768 -ds 32768 -a 1 -wb -wa $TRACE_FILE" # 32K Split BS 128
    
    # --- Split Cache (Associativity变化) ---
    "./code/sim -bs 64 -is 8192 -ds 8192 -a 2 -wb -wa $TRACE_FILE"   # 8K Split Assoc 2
    "./code/sim -bs 64 -is 8192 -ds 8192 -a 4 -wb -wa $TRACE_FILE"   # 8K Split Assoc 4
    "./code/sim -bs 64 -is 8192 -ds 8192 -a 8 -wb -wa $TRACE_FILE"   # 8K Split Assoc 8
    "./code/sim -bs 64 -is 8192 -ds 8192 -a 16 -wb -wa $TRACE_FILE"   # 8K Split Assoc 16
    "./code/sim -bs 64 -is 8192 -ds 8192 -a 128 -wb -wa $TRACE_FILE"   # 8K Split Assoc 128
    "./code/sim -bs 64 -is 1024 -ds 1024 -a 2 -wb -wa $TRACE_FILE"   # 1K Split Assoc 2
    "./code/sim -bs 64 -is 1024 -ds 1024 -a 8 -wb -wa $TRACE_FILE"   # 1K Split Assoc 8
    "./code/sim -bs 64 -is 1024 -ds 1024 -a 16 -wb -wa $TRACE_FILE"   # 1K Split Assoc 16
    
    # --- 策略变化 (WT, WNA) ---
    "./code/sim -bs 16 -is 8192 -ds 8192 -a 1 -wt -wa $TRACE_FILE"   # Write Through BS 16
    "./code/sim -bs 32 -is 8192 -ds 8192 -a 1 -wt -wa $TRACE_FILE"   # Write Through BS 32
    "./code/sim -bs 64 -is 8192 -ds 8192 -a 2 -wt -wa $TRACE_FILE"   # Write Through BS 64 Assoc 2

    "./code/sim -bs 16 -is 8192 -ds 8192 -a 1 -wa -nw $TRACE_FILE"   # Write No-Allocate
    "./code/sim -bs 32 -is 8192 -ds 8192 -a 1 -wa -nw $TRACE_FILE"   # Write No-Allocate
    "./code/sim -bs 64 -is 8192 -ds 8192 -a 2 -wa -nw $TRACE_FILE"   # Write No-Allocate
)

echo "--------------------------------------------------------------------------------------"
printf "%-10s | %-10s | %-10s | %-10s | %-12s | %-12s\n" "I-Miss" "I-Repl" "D-Miss" "D-Repl" "DemandFetch" "CopiesBack"
echo "--------------------------------------------------------------------------------------"

for cmd in "${commands[@]}"; do
    # 1. 运行模拟器并捕获输出
    output=$($cmd)

    # 2. 解析输出
    # 提取 Instruction Misses
    i_miss=$(echo "$output" | grep -A 5 "INSTRUCTIONS" | grep "misses" | awk '{print $2}')
    # 提取 Instruction Replacements
    i_repl=$(echo "$output" | grep -A 5 "INSTRUCTIONS" | grep "replace" | awk '{print $2}')
    
    # 提取 Data Misses
    d_miss=$(echo "$output" | grep -A 5 "DATA" | grep "misses" | awk '{print $2}')
    # 提取 Data Replacements
    d_repl=$(echo "$output" | grep -A 5 "DATA" | grep "replace" | awk '{print $2}')
    
    # 提取 Fetch 和 Copies Back
    fetch=$(echo "$output" | grep "demand fetch" | awk '{print $3}')
    cb=$(echo "$output" | grep "copies back" | awk '{print $3}')

    # 3. 打印一行数据
    printf "%-10s | %-10s | %-10s | %-10s | %-12s | %-12s\n" "$i_miss" "$i_repl" "$d_miss" "$d_repl" "$fetch" "$cb"
done