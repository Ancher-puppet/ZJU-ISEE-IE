import subprocess
import re
import os
import matplotlib.pyplot as plt

# 配置区域
SIM_PATH = "code/sim"
TRACES = ["ext_traces/spice.trace", "ext_traces/cc.trace", "ext_traces/tex.trace"]

if not os.path.exists("plots"):
    os.makedirs("plots")

# 辅助函数
def run_sim(args, trace_file):
    cmd = [SIM_PATH] + args + [trace_file]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0: return None
        output = result.stdout
        hit_rates = re.findall(r"hit rate\s+([0-9\.]+)", output)
        res = {}
        if len(hit_rates) >= 2:
            res['i_hit'] = float(hit_rates[0])
            res['d_hit'] = float(hit_rates[1])
        return res
    except: return None

def plot_lines(x_data, y_datas, labels, title, xlabel, ylabel, filename, xlog=True):
    plt.figure(figsize=(10, 6))
    for y_data, label in zip(y_datas, labels):
        plt.plot(x_data, y_data, 'o-', label=label)
    if xlog: plt.xscale('log', base=2)
    plt.xlabel(xlabel); plt.ylabel(ylabel); plt.title(title)
    plt.grid(True, which="both", ls="-", alpha=0.5); plt.legend()
    plt.savefig(f"plots/{filename}")
    plt.close()
    print(f" -> 图表已保存: plots/{filename}")

# 主逻辑
def main():
    print("Running Task 2.3: Impact of Associativity")
    
    assocs = [1, 2, 4, 8, 16, 32, 64]
    
    for trace in TRACES:
        if not os.path.exists(trace): continue
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
                i_val = res['i_hit']; d_val = res['d_hit']
                i_hits.append(i_val); d_hits.append(d_val)
                print(f"{a:<10} | {i_val:<12.4f} | {d_val:<12.4f}")
            else:
                print(f"{a:<10} | Error")
            
        trace_name = os.path.basename(trace)


        # 合并对比图
        plot_lines(assocs, [i_hits, d_hits], ["Instruction", "Data"], 
                   f"2.3 Associativity Impact - Combined ({trace_name})", 
                   "Associativity", "Hit Rate", 
                   f"task2_3_{trace_name}_combined.png")

        # 指令图
        plot_lines(assocs, [i_hits], ["Instruction"], 
                   f"2.3 Associativity Impact - Instruction Only ({trace_name})", 
                   "Associativity", "Hit Rate", 
                   f"task2_3_{trace_name}_instr.png")

        # 数据图
        plot_lines(assocs, [d_hits], ["Data"], 
                   f"2.3 Associativity Impact - Data Only ({trace_name})", 
                   "Associativity", "Hit Rate", 
                   f"task2_3_{trace_name}_data.png")

if __name__ == "__main__":
    if not os.path.exists(SIM_PATH): print("请先编译代码 (make)！")
    else: main()