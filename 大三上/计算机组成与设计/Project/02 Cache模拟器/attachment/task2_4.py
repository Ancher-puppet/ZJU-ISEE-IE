import subprocess
import re
import os

# 配置区域
SIM_PATH = "code/sim"
TRACES = ["ext_traces/spice.trace", "ext_traces/cc.trace", "ext_traces/tex.trace"]

# 辅助函数
def run_sim(args, trace_file):
    cmd = [SIM_PATH] + args + [trace_file]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0: return None, None
        output = result.stdout
        traffic = re.findall(r"TRAFFIC \(in words\)\n\s+demand fetch:\s+(\d+)\n\s+copies back:\s+(\d+)", output)
        if traffic:
            return int(traffic[0][0]), int(traffic[0][1])
        return None, None
    except: return None, None

def print_row(bs, size, a, wp, ap, fetch, copies):
    print(f"{bs:<6} | {size:<6} | {size:<6} | {a:<4} | {wp:<12} | {ap:<16} | {fetch:<12} | {copies:<12}")

# 主逻辑
def main():
    print("Task 2.4: Memory Bandwidth Analysis (All Traces)")

    param_sizes = [8192, 16384]
    param_bs = [64, 128]
    param_assocs = [2, 4]

    for trace in TRACES:
        if not os.path.exists(trace): continue
        trace_name = os.path.basename(trace)
        print(f"\n\n>>> 正在分析 Trace: {trace_name} <<<")

        # 实验 1: Write-Through vs Write-Back (固定 Write-No-Allocate)
        print(f"\n[实验 1] Write-Through (WT) vs Write-Back (WB) | Policy: Write-No-Allocate")
        print("-" * 95)
        print(f"{'bs':<6} | {'is':<6} | {'ds':<6} | {'a':<4} | {'Write Pol':<12} | {'Alloc Pol':<16} | {'Fetch':<12} | {'Copies':<12}")
        print("-" * 95)

        for s in param_sizes:
            for bs in param_bs:
                for a in param_assocs:
                    base_args = ["-bs", str(bs), "-is", str(s), "-ds", str(s), "-a", str(a)]
                    
                    # WT + No-Alloc
                    f_wt, c_wt = run_sim(base_args + ["-wt", "-nw"], trace)
                    if f_wt is not None: print_row(bs, s, a, "WT", "No-Alloc", f_wt, c_wt)
                    
                    # WB + No-Alloc
                    f_wb, c_wb = run_sim(base_args + ["-wb", "-nw"], trace)
                    if f_wb is not None: print_row(bs, s, a, "WB", "No-Alloc", f_wb, c_wb)

        # 实验 2: WA vs WNA (固定 Write-Back)
        print(f"\n[实验 2] Write-Allocate (WA) vs No-Allocate (WNA) | Policy: Write-Back")
        print("-" * 95)
        print(f"{'bs':<6} | {'is':<6} | {'ds':<6} | {'a':<4} | {'Write Pol':<12} | {'Alloc Pol':<16} | {'Fetch':<12} | {'Copies':<12}")
        print("-" * 95)

        for s in param_sizes:
            for bs in param_bs:
                for a in param_assocs:
                    base_args = ["-bs", str(bs), "-is", str(s), "-ds", str(s), "-a", str(a), "-wb"]
                    
                    # WB + Allocate
                    f_wa, c_wa = run_sim(base_args + ["-wa"], trace)
                    if f_wa is not None: print_row(bs, s, a, "WB", "Allocate", f_wa, c_wa)
                    
                    # WB + No-Alloc
                    f_nw, c_nw = run_sim(base_args + ["-nw"], trace)
                    if f_nw is not None: print_row(bs, s, a, "WB", "No-Alloc", f_nw, c_nw)

if __name__ == "__main__":
    if not os.path.exists(SIM_PATH): print("请先编译代码 (make)！")
    else: main()