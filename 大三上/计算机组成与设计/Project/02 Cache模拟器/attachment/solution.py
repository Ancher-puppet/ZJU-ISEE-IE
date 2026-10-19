import subprocess
import re
import os
import matplotlib.pyplot as plt

# 参数配置
SIM_PATH = "code/sim"
TRACES = ["ext_traces/spice.trace", "ext_traces/cc.trace", "ext_traces/tex.trace"]

# 输出目录
if not os.path.exists("plots"):
    os.makedirs("plots")

# 辅助函数
def run_sim(args, trace_file):
    cmd = [SIM_PATH] + args + [trace_file]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        # 如果模拟器崩溃，打印详细错误
        if result.returncode != 0:
            print(f"\n[Error] 模拟器运行失败！命令: {' '.join(cmd)}")
            print(f"[Return Code] {result.returncode}")
            return None
            
        output = result.stdout
        
        # 正则提取数据
        hit_rates = re.findall(r"hit rate\s+([0-9\.]+)", output)
        traffic = re.findall(r"TRAFFIC \(in words\)\n\s+demand fetch:\s+(\d+)\n\s+copies back:\s+(\d+)", output)
        
        res = {}
        # 通常 hit rate Instruction和Data
        if len(hit_rates) >= 2:
            res['i_hit'] = float(hit_rates[0])
            res['d_hit'] = float(hit_rates[1])
        else:

            return None

        if traffic:
            demand_fetch = int(traffic[0][0])
            copies_back = int(traffic[0][1])
            res['total_traffic'] = demand_fetch + copies_back
            
        return res
    except Exception as e:
        print(f"Python Execution Error: {e}")
        return None

def plot_lines(x_data, y_datas, labels, title, xlabel, ylabel, filename, xlog=True):
    plt.figure(figsize=(10, 6))
    for y_data, label in zip(y_datas, labels):
        plt.plot(x_data, y_data, 'o-', label=label)
    
    if xlog:
        plt.xscale('log', base=2)
    
    plt.xlabel(xlabel)
    plt.ylabel(ylabel)
    plt.title(title)
    plt.grid(True, which="both", ls="-", alpha=0.5)
    plt.legend()
    plt.savefig(f"plots/{filename}")
    plt.close()
    print(f" -> 图表已保存: plots/{filename}")

# 任务 2.1: Working Set
def task_2_1():
    print("\n" + "="*60)
    print("Running Task 2.1: Working Set Characterization")
    print("="*60)
    
    sizes = []
    curr = 4
    while curr <= 131072: # 测到 128KB
        sizes.append(curr)
        curr *= 2
    
    for trace in TRACES:
        print(f"\n正在测试 Trace: {os.path.basename(trace)}")
        print("-" * 50)
        print(f"{'Size (B)':<10} | {'Assoc':<8} | {'I-HitRate':<12} | {'D-HitRate':<12}")
        print("-" * 50)
        
        i_hits = []
        d_hits = []
        
        for s in sizes:
            # Fully Associative: Assoc = Size / BlockSize(4)
            assoc = s // 4
            args = ["-bs", "4", "-is", str(s), "-ds", str(s), "-a", str(assoc), "-wb", "-wa"]
            
            res = run_sim(args, trace)
            
            if res:
                i_val = res['i_hit']
                d_val = res['d_hit']
                i_hits.append(i_val)
                d_hits.append(d_val)
                print(f"{s:<10} | {assoc:<8} | {i_val:<12.4f} | {d_val:<12.4f}")
            else:
                print(f"{s:<10} | Error executing simulation")
        
        trace_name = os.path.basename(trace)
        plot_lines(sizes, [i_hits, d_hits], ["Instruction", "Data"], 
                   f"2.1 Working Set ({trace_name})", "Cache Size (Bytes)", "Hit Rate", f"task2_1_{trace_name}.png")

# 任务 2.2: Block Size
def task_2_2():
    print("\n" + "="*60)
    print("Running Task 2.2: Impact of Block Size")
    print("="*60)
    
    blocks = []
    curr = 4
    while curr <= 4096:
        blocks.append(curr)
        curr *= 2
        
    for trace in TRACES:
        print(f"\n正在测试 Trace: {os.path.basename(trace)}")
        print("-" * 50)
        print(f"{'BlockSize':<10} | {'I-HitRate':<12} | {'D-HitRate':<12}")
        print("-" * 50)

        i_hits = []
        d_hits = []
        
        for bs in blocks:
            # 8KB Split, Assoc 2
            args = ["-bs", str(bs), "-is", "8192", "-ds", "8192", "-a", "2", "-wb", "-wa"]
            res = run_sim(args, trace)
            
            if res:
                i_val = res['i_hit']
                d_val = res['d_hit']
                i_hits.append(i_val)
                d_hits.append(d_val)
                print(f"{bs:<10} | {i_val:<12.4f} | {d_val:<12.4f}")
            else:
                print(f"{bs:<10} | Error")
            
        trace_name = os.path.basename(trace)
        plot_lines(blocks, [i_hits, d_hits], ["Instruction", "Data"], 
                   f"2.2 Block Size Impact ({trace_name})", "Block Size (Bytes)", "Hit Rate", f"task2_2_{trace_name}.png")

# 任务 2.3: Associativity
def task_2_3():
    print("\n" + "="*60)
    print("Running Task 2.3: Impact of Associativity")
    print("="*60)
    
    assocs = [1, 2, 4, 8, 16, 32, 64]
    
    for trace in TRACES:
        print(f"\n正在测试 Trace: {os.path.basename(trace)}")
        print("-" * 50)
        print(f"{'Assoc':<10} | {'I-HitRate':<12} | {'D-HitRate':<12}")
        print("-" * 50)

        i_hits = []
        d_hits = []
        
        for a in assocs:
            # 8KB Split, BS 128
            args = ["-bs", "128", "-is", "8192", "-ds", "8192", "-a", str(a), "-wb", "-wa"]
            res = run_sim(args, trace)
            
            if res:
                i_val = res['i_hit']
                d_val = res['d_hit']
                i_hits.append(i_val)
                d_hits.append(d_val)
                print(f"{a:<10} | {i_val:<12.4f} | {d_val:<12.4f}")
            else:
                print(f"{a:<10} | Error")
            
        trace_name = os.path.basename(trace)
        plot_lines(assocs, [i_hits, d_hits], ["Instruction", "Data"], 
                   f"2.3 Associativity Impact ({trace_name})", "Associativity", "Hit Rate", f"task2_3_{trace_name}.png")

# 任务 2.4: Memory Bandwidth
def task_2_4():
    print("\n" + "="*80)
    print("Task 2.4: Memory Bandwidth Analysis (All Traces)")
    print("="*80)

    # 参数组合，模拟 8K 和 16K 大小，64 和 128 块大小，2 和 4 关联度
    param_sizes = [8192, 16384]
    param_bs = [64, 128]
    param_assocs = [2, 4]

    for trace in TRACES:
        if not os.path.exists(trace):
            print(f"\n[Warning] 找不到文件 {trace}，跳过...")
            continue

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
                    # 基础参数
                    base_args = ["-bs", str(bs), "-is", str(s), "-ds", str(s), "-a", str(a)]
                    
                    # 1.1: Run Write-Through + No-Allocate
                    args_wt = base_args + ["-wt", "-nw"]
                    f_wt, c_wt = run_sim(args_wt, trace)
                    if f_wt is not None:
                        print_row(bs, s, a, "WT", "No-Alloc", f_wt, c_wt)
                    
                    # 1.2: Run Write-Back + No-Allocate
                    args_wb = base_args + ["-wb", "-nw"]
                    f_wb, c_wb = run_sim(args_wb, trace)
                    if f_wb is not None:
                        print_row(bs, s, a, "WB", "No-Alloc", f_wb, c_wb)

        # 实验 2: Write-Allocate vs Write-No-Allocate (固定 Write-Back)
        print(f"\n[实验 2] Write-Allocate (WA) vs No-Allocate (WNA) | Policy: Write-Back")
        print("-" * 95)
        print(f"{'bs':<6} | {'is':<6} | {'ds':<6} | {'a':<4} | {'Write Pol':<12} | {'Alloc Pol':<16} | {'Fetch':<12} | {'Copies':<12}")
        print("-" * 95)

        for s in param_sizes:
            for bs in param_bs:
                for a in param_assocs:
                    # 基础参数
                    base_args = ["-bs", str(bs), "-is", str(s), "-ds", str(s), "-a", str(a), "-wb"]
                    
                    # 2.1: Run Write-Back + Write-Allocate
                    args_wa = base_args + ["-wa"]
                    f_wa, c_wa = run_sim(args_wa, trace)
                    if f_wa is not None:
                        print_row(bs, s, a, "WB", "Allocate", f_wa, c_wa)
                    
                    # 2.2: Run Write-Back + No-Allocate
                    args_nw = base_args + ["-nw"]
                    f_nw, c_nw = run_sim(args_nw, trace)
                    if f_nw is not None:
                        print_row(bs, s, a, "WB", "No-Alloc", f_nw, c_nw)
    
    print("\n" + "="*80)
    print("分析完成！")


# 主程序
if __name__ == "__main__":
    if not os.path.exists(SIM_PATH):
        print(f"错误: 找不到文件 {SIM_PATH}")
        print("   -> 请先在 code/ 目录下运行 'make'")
    else:
        # 依次运行所有任务
        task_2_1()
        task_2_2()
        task_2_3()
        task_2_4()
        print("\n 所有任务完成！图片已保存在 plots/ 文件夹下。")