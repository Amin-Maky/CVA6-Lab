import matplotlib.pyplot as plt
import numpy as np
import os

# ================= Old Data =================
labels_old = ['32-bit\n(SS OFF)', '32-bit\n(SS ON)', '64-bit\n(SS OFF)', '64-bit\n(SS ON)']
wns_abs_old = [abs(x) for x in [-3.729, -5.282, -9.118, -9.968]] 
fmax_old = [72.84, 65.43, 52.31, 50.08]
lut_old = [135074, 140181, 54326, 63685]
ff_old = [327292, 328223, 23728, 25108]
bram_old = [16, 16, 36, 36]
dsp_old = [4, 4, 27, 27]

complex_s_old = [5367146, 4226440, 5313908, 4153764]
matmul_c_old = [243806, 227494, 234488, 224972]
avg_c_old = [20506, 29304, 20532, 29080]

# ================= New Data (Tables 7.1, 7.2, 7.3) =================
labels_new = ['64-bit\n(SS OFF)', '64-bit-custom\n(SS OFF)', '64-bit\n(SS ON)']
wns_abs_new = [abs(x) for x in [-9.118, -9.160, -9.968]]
fmax_new = [52.31, 52.19, 50.08]
lut_new = [54326, 54023, 63685]
ff_new = [23728, 23803, 25108]
bram_new = [36, 36, 36]
dsp_new = [27, 27, 27]

complex_s_new = [5313908, 5231742, 4153764]
matmul_c_new = [234488, 234488, 224972]
avg_c_new = [20532, 20452, 29080]

complex_avg_c_new = [22471130, 21669132, 19751592]

# ================= Themes Configuration =================
themes = {
    'transparent': {
        'bg': 'none', 'text': '#000000', 'grid': '#cccccc', 'spine': '#000000',
        'wns': '#ff7b72', 'fmax': '#58a6ff', 
        'lut': '#58a6ff', 'ff': '#d29922', 'bram': '#3fb950', 'dsp': '#f85149',
        'bench1': '#58a6ff', 'bench2': '#d29922', 'bench3': '#3fb950',
        'edge': 'none', 'legend_bg': 'none', 'transparent': True, 'name': 'transparent'
    },
    'light': {
        'bg': '#ffffff', 'text': '#24292f', 'grid': '#d0d7de', 'spine': '#d0d7de',
        'wns': '#cf222e', 'fmax': '#0969da', 
        'lut': '#0969da', 'ff': '#9a6700', 'bram': '#1a7f37', 'dsp': '#cf222e',
        'bench1': '#0969da', 'bench2': '#9a6700', 'bench3': '#1a7f37',
        'edge': 'none', 'legend_bg': '#ffffff', 'transparent': False, 'name': 'light'
    },
    'dark': {
        'bg': '#0d1117', 'text': '#c9d1d9', 'grid': '#30363d', 'spine': '#30363d',
        'wns': '#ff7b72', 'fmax': '#58a6ff', 
        'lut': '#58a6ff', 'ff': '#d29922', 'bram': '#3fb950', 'dsp': '#f85149',
        'bench1': '#58a6ff', 'bench2': '#d29922', 'bench3': '#3fb950',
        'edge': 'none', 'legend_bg': '#161b22', 'transparent': False, 'name': 'dark'
    }
}

# ================= Helper Functions =================
def autolabel(rects, ax, text_color):
    for rect in rects:
        height = rect.get_height()
        ax.annotate(f'{height:,}',
                    xy=(rect.get_x() + rect.get_width() / 2, height),
                    xytext=(0, 3), textcoords="offset points",
                    ha='center', va='bottom', fontsize=8.5,
                    fontweight='bold', color=text_color)

def set_background(fig, axes, cfg):
    if cfg['bg'] != 'none':
        fig.patch.set_facecolor(cfg['bg'])
        for ax in axes:
            ax.set_facecolor(cfg['bg'])
    else:
        fig.patch.set_alpha(0.0)
        for ax in axes:
            ax.patch.set_alpha(0.0)

# ================= Plotting Functions =================
def plot_timing(cfg, labels, wns_abs, fmax, filename):
    width = 0.35
    x = np.arange(len(labels))
    
    fig, ax1 = plt.subplots(figsize=(8, 5))
    set_background(fig, [ax1], cfg)

    ax1.set_xlabel('Configurations', color=cfg['text'], fontweight='bold')
    ax1.set_ylabel('|WNS| (ns)', color=cfg['wns'], fontweight='bold')
    bars1 = ax1.bar(x - width/2, wns_abs, width, label='|WNS| (ns)', color=cfg['wns'])
    
    ax1.tick_params(axis='y', labelcolor=cfg['wns'], colors=cfg['text'])
    ax1.tick_params(axis='x', colors=cfg['text'])
    ax1.set_xticks(x)
    ax1.set_xticklabels(labels)
    ax1.grid(True, axis='y', color=cfg['grid'], linestyle='--', alpha=0.5)

    for spine in ax1.spines.values():
        spine.set_edgecolor(cfg['spine'])

    ax2 = ax1.twinx()
    ax2.set_ylabel(r'$F_{max}$ (MHz)', color=cfg['fmax'], fontweight='bold')
    bars2 = ax2.bar(x + width/2, fmax, width, label=r'$F_{max}$ (MHz)', color=cfg['fmax'])
    ax2.tick_params(axis='y', labelcolor=cfg['fmax'], colors=cfg['text'])

    for spine in ax2.spines.values():
        spine.set_edgecolor(cfg['spine'])

    for bar in bars1:
        yval = bar.get_height()
        ax1.text(bar.get_x() + bar.get_width()/2, yval + (max(wns_abs)*0.02), f'{yval}', ha='center', va='bottom', color=cfg['text'], fontsize=10, fontweight='bold')
    for bar in bars2:
        yval = bar.get_height()
        ax2.text(bar.get_x() + bar.get_width()/2, yval + (max(fmax)*0.02), f'{yval}', ha='center', va='bottom', color=cfg['text'], fontsize=10, fontweight='bold')

    plt.title(r'CVA6 Timing Analysis: |WNS| vs $F_{max}$', color=cfg['text'], fontweight='bold', pad=15)
    fig.legend(loc='upper right', bbox_to_anchor=(0.9, 0.9), facecolor=cfg['legend_bg'], edgecolor=cfg['spine'], labelcolor=cfg['text'])

    ax1.set_ylim(0, max(wns_abs) * 1.25)
    ax2.set_ylim(0, max(fmax) * 1.25)

    fig.tight_layout()
    plt.savefig(filename, transparent=cfg['transparent'], dpi=300)
    plt.close()
    print(f"Saved: {filename}")

def plot_resources(cfg, labels, lut, ff, bram, dsp, filename):
    width = 0.35
    x = np.arange(len(labels))
    
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))
    set_background(fig, [ax1, ax2], cfg)

    # Subplot 1: LUT & FF
    rects1 = ax1.bar(x - width/2, lut, width, label='LUT', color=cfg['lut'], edgecolor=cfg['edge'], linewidth=0.8)
    rects2 = ax1.bar(x + width/2, ff, width, label='FF', color=cfg['ff'], edgecolor=cfg['edge'], linewidth=0.8)

    ax1.set_ylabel('Resource Count', color=cfg['text'], fontsize=11, fontweight='semibold')
    ax1.set_title('LUT and FF Utilization', color=cfg['text'], fontsize=13, fontweight='bold', pad=12)
    ax1.set_xticks(x)
    ax1.set_xticklabels(labels, color=cfg['text'], fontsize=10)
    ax1.tick_params(colors=cfg['text'])
    ax1.grid(axis='y', linestyle='--', alpha=0.5, color=cfg['grid'])
    
    leg1 = ax1.legend(facecolor=cfg['legend_bg'], edgecolor=cfg['spine'], labelcolor=cfg['text'])
    if cfg['transparent']: leg1.get_frame().set_alpha(0.0)

    for spine in ax1.spines.values(): spine.set_color(cfg['spine'])
    autolabel(rects1, ax1, cfg['text'])
    autolabel(rects2, ax1, cfg['text'])
    ax1.set_ylim(0, max(max(lut), max(ff)) * 1.2)

    # Subplot 2: BRAM & DSP
    rects3 = ax2.bar(x - width/2, bram, width, label='BRAM', color=cfg['bram'], edgecolor=cfg['edge'], linewidth=0.8)
    rects4 = ax2.bar(x + width/2, dsp, width, label='DSP', color=cfg['dsp'], edgecolor=cfg['edge'], linewidth=0.8)

    ax2.set_ylabel('Resource Count', color=cfg['text'], fontsize=11, fontweight='semibold')
    ax2.set_title('BRAM and DSP Utilization', color=cfg['text'], fontsize=13, fontweight='bold', pad=12)
    ax2.set_xticks(x)
    ax2.set_xticklabels(labels, color=cfg['text'], fontsize=10)
    ax2.tick_params(colors=cfg['text'])
    ax2.grid(axis='y', linestyle='--', alpha=0.5, color=cfg['grid'])
    
    leg2 = ax2.legend(facecolor=cfg['legend_bg'], edgecolor=cfg['spine'], labelcolor=cfg['text'])
    if cfg['transparent']: leg2.get_frame().set_alpha(0.0)

    for spine in ax2.spines.values(): spine.set_color(cfg['spine'])
    autolabel(rects3, ax2, cfg['text'])
    autolabel(rects4, ax2, cfg['text'])
    ax2.set_ylim(0, max(max(bram), max(dsp)) * 1.25)

    plt.tight_layout()
    plt.savefig(filename, dpi=300, bbox_inches='tight', transparent=cfg['transparent'])
    plt.close(fig)
    print(f"Saved: {filename}")

def plot_benchmarks(cfg, labels, data_comp_s, data_mat_c, data_avg_c, filename):
    width = 0.5
    x = np.arange(len(labels))
    
    fig, (ax1, ax2, ax3) = plt.subplots(1, 3, figsize=(18, 5))
    set_background(fig, [ax1, ax2, ax3], cfg)

    # Subplot 1: complex.S
    rects1 = ax1.bar(x, data_comp_s, width, color=cfg['bench1'], edgecolor=cfg['edge'], linewidth=0.8)
    ax1.set_title('complex.S Execution Time', color=cfg['text'], fontsize=12, fontweight='bold')
    
    # Subplot 2: matmul.c
    rects2 = ax2.bar(x, data_mat_c, width, color=cfg['bench2'], edgecolor=cfg['edge'], linewidth=0.8)
    ax2.set_title('matmul.c Execution Time', color=cfg['text'], fontsize=12, fontweight='bold')
    
    # Subplot 3: avg.c
    rects3 = ax3.bar(x, data_avg_c, width, color=cfg['bench3'], edgecolor=cfg['edge'], linewidth=0.8)
    ax3.set_title('avg.c Execution Time', color=cfg['text'], fontsize=12, fontweight='bold')

    for ax, rects in zip([ax1, ax2, ax3], [rects1, rects2, rects3]):
        ax.set_ylabel('Time (ps)', color=cfg['text'], fontsize=10, fontweight='semibold')
        ax.set_xticks(x)
        ax.set_xticklabels(labels, color=cfg['text'], fontsize=9)
        ax.tick_params(colors=cfg['text'])
        ax.grid(axis='y', linestyle='--', alpha=0.5, color=cfg['grid'])
        for spine in ax.spines.values(): spine.set_color(cfg['spine'])
        autolabel(rects, ax, cfg['text'])
        ax.set_ylim(0, max([r.get_height() for r in rects]) * 1.15)

    plt.tight_layout()
    plt.savefig(filename, dpi=300, bbox_inches='tight', transparent=cfg['transparent'])
    plt.close(fig)
    print(f"Saved: {filename}")

def plot_single_benchmark(cfg, labels, data, title, filename):
    width = 0.4
    x = np.arange(len(labels))
    
    fig, ax = plt.subplots(figsize=(8, 5))
    set_background(fig, [ax], cfg)

    rects = ax.bar(x, data, width, color=cfg['bench1'], edgecolor=cfg['edge'], linewidth=0.8)
    
    ax.set_title(title, color=cfg['text'], fontsize=13, fontweight='bold', pad=15)
    ax.set_ylabel('Time (ps)', color=cfg['text'], fontsize=11, fontweight='semibold')
    ax.set_xticks(x)
    ax.set_xticklabels(labels, color=cfg['text'], fontsize=10)
    ax.tick_params(colors=cfg['text'])
    ax.grid(axis='y', linestyle='--', alpha=0.5, color=cfg['grid'])
    
    for spine in ax.spines.values(): spine.set_color(cfg['spine'])
    autolabel(rects, ax, cfg['text'])
    ax.set_ylim(0, max(data) * 1.15)

    plt.tight_layout()
    plt.savefig(filename, dpi=300, bbox_inches='tight', transparent=cfg['transparent'])
    plt.close(fig)
    print(f"Saved: {filename}")

# ================= Generate All Charts =================
for name, cfg in themes.items():
    # 1. Generate OLD Charts
    plot_timing(cfg, labels_old, wns_abs_old, fmax_old, f"cva6_timing_github_{cfg['name']}.png")
    plot_resources(cfg, labels_old, lut_old, ff_old, bram_old, dsp_old, f"cva6_resources_github_{cfg['name']}.png")
    plot_benchmarks(cfg, labels_old, complex_s_old, matmul_c_old, avg_c_old, f"cva6_benchmarks_github_{cfg['name']}.png")
    
    # 2. Generate NEW Charts (Timing & Resources)
    if cfg['name'] != 'transparent':
        plot_timing(cfg, labels_new, wns_abs_new, fmax_new, f"custom_cva6_timing_syn_github_{cfg['name']}.png")
        plot_resources(cfg, labels_new, lut_new, ff_new, bram_new, dsp_new, f"custom_cva6_resource_utilization_syn_github_{cfg['name']}.png")
        
        # 3. Generate NEW Benchmark Charts
        plot_benchmarks(cfg, labels_new, complex_s_new, matmul_c_new, avg_c_new, f"custom_cva6_benchmarks_sim_github_{cfg['name']}.png")
        plot_single_benchmark(cfg, labels_new, complex_avg_c_new, 'complex_avg.c Execution Time', f"custom_cva6_benchmarks_sim_avg_github_{cfg['name']}.png")
    else:
        # For transparent theme just in case
        plot_timing(cfg, labels_new, wns_abs_new, fmax_new, f"custom_cva6_timing_syn_github_{cfg['name']}.png")
        plot_resources(cfg, labels_new, lut_new, ff_new, bram_new, dsp_new, f"custom_cva6_resource_utilization_syn_github_{cfg['name']}.png")
        plot_benchmarks(cfg, labels_new, complex_s_new, matmul_c_new, avg_c_new, f"custom_cva6_benchmarks_sim_github_{cfg['name']}.png")
        plot_single_benchmark(cfg, labels_new, complex_avg_c_new, 'complex_avg.c Execution Time', f"custom_cva6_benchmarks_sim_avg_github_{cfg['name']}.png")

print("\nAll old and new benchmark charts have been generated successfully!")
