import matplotlib.pyplot as plt
import numpy as np
from matplotlib.ticker import FuncFormatter

# =====================================================================
#  Global palette — ONE fixed color per version (GitHub light & dark)
# =====================================================================
VERSION_COLORS = {
    '32-bit (OFF)':        '#9467bd',   # purple
    '32-bit (ON)':         '#17becf',   # teal
    '64-bit (OFF)':        '#1f77b4',   # blue
    '64-bit-custom (OFF)': '#ff7f0e',   # orange
    '64-bit (ON)':         '#2ca02c',   # green
}

LABELS4 = ['32-bit (OFF)', '32-bit (ON)', '64-bit (OFF)', '64-bit (ON)']
LABELS3 = ['64-bit (OFF)', '64-bit-custom (OFF)', '64-bit (ON)']

def colors_for(labels):
    return [VERSION_COLORS[l] for l in labels]

# =====================================================================
#  Theme / helpers (same styling as plot.py)
# =====================================================================
def set_theme(theme):
    if theme == 'dark':
        text_c, axis_c, grid_c, bg_c = '#c9d1d9', '#8b949e', '#30363d', 'none'
    else:
        text_c, axis_c, grid_c, bg_c = '#24292e', '#24292e', '#e1e4e8', 'white'
    plt.rcParams.update({
        'text.color': text_c, 'axes.labelcolor': text_c,
        'axes.edgecolor': axis_c, 'xtick.color': text_c, 'ytick.color': text_c,
        'axes.titlecolor': text_c, 'figure.facecolor': bg_c, 'axes.facecolor': bg_c,
        'savefig.facecolor': bg_c, 'grid.color': grid_c, 'grid.linestyle': '--',
        'grid.alpha': 0.7, 'font.family': 'sans-serif', 'font.size': 10,
    })

def comma_formatter(x, pos):
    return f'{int(x):,}'

def draw_panel(ax, labels, values, title, fmt='{:.2f}', comma_axis=False, rot=12):
    """One bar panel: unique color per version, bold value label above bars."""
    bars = ax.bar(labels, values, color=colors_for(labels), width=0.55, zorder=3)
    ax.set_title(title, fontweight='bold', fontsize=12, pad=12)
    ax.set_ylim(0, max(values) * 1.18)
    ax.grid(True, axis='y', zorder=0)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    if comma_axis:
        ax.yaxis.set_major_formatter(FuncFormatter(comma_formatter))
    ax.tick_params(axis='x', labelrotation=rot)
    for b, v in zip(bars, values):
        ax.annotate(fmt.format(v), (b.get_x() + b.get_width() / 2, b.get_height()),
                    xytext=(0, 5), textcoords='offset points',
                    ha='center', va='bottom', fontweight='bold', fontsize=9)

def save(fig, name, theme):
    fig.savefig(f'{name}_{theme}.png', dpi=300, bbox_inches='tight',
                transparent=(theme == 'dark'))
    plt.close(fig)

# =====================================================================
#  1) Timing & Utilization — 4 configs  ->  cva6_timing_github_*.png
# =====================================================================
def plot_timing_4cfg(theme):
    set_theme(theme)
    fmax    = [72.84, 65.43, 52.31, 50.08]
    wns_abs = [3.729, 5.282, 9.118, 9.968]      # |WNS|
    logic   = [28, 34, 45, 47]
    routing = [85.1, 77.3, 72.0, 71.8]
    fig, axs = plt.subplots(2, 2, figsize=(13, 9.5))
    fig.suptitle('Timing Analysis Comparison', fontsize=16, fontweight='bold')
    draw_panel(axs[0, 0], LABELS4, fmax,    r'$F_{max}$ (MHz)',      '{:.2f}')
    draw_panel(axs[0, 1], LABELS4, wns_abs, '|WNS| (ns)',            '{:.3f}')
    draw_panel(axs[1, 0], LABELS4, logic,   'Logic Levels',          '{:.0f}')
    draw_panel(axs[1, 1], LABELS4, routing, 'Routing Share (%)',     '{:.1f}')
    fig.tight_layout(rect=[0, 0, 1, 0.95])
    save(fig, 'cva6_timing_github', theme)

# =====================================================================
#  2) Resource Utilization — 4 configs  ->  cva6_resource_github_*.png
#     LUT/FF on the left column, BRAM/DSP on the right column
# =====================================================================
def plot_resource_4cfg(theme):
    set_theme(theme)
    lut  = [135074, 140181, 54326, 63685]
    ff   = [327292, 328223, 23728, 25108]
    bram = [16, 16, 36, 36]
    dsp  = [4, 4, 27, 27]
    fig, axs = plt.subplots(2, 2, figsize=(13, 9.5))
    fig.suptitle('Resource Utilization Comparison', fontsize=16, fontweight='bold')
    draw_panel(axs[0, 0], LABELS4, lut,  'LUT Utilization',       '{:,.0f}', comma_axis=True)
    draw_panel(axs[1, 0], LABELS4, ff,   'Flip-Flop (FF) Utilization', '{:,.0f}', comma_axis=True)
    draw_panel(axs[0, 1], LABELS4, bram, 'BRAM Utilization',      '{:.0f}')
    draw_panel(axs[1, 1], LABELS4, dsp,  'DSP Utilization',       '{:.0f}')
    fig.tight_layout(rect=[0, 0, 1, 0.95])
    save(fig, 'cva6_resource_github', theme)

# =====================================================================
#  3) Benchmarks (cycles) — 4 configs -> cva6_benchmarks_sim_github_*.png
# =====================================================================
def plot_benchmarks_4cfg(theme):
    set_theme(theme)
    complex_s = [2683573, 2113220, 2656954, 2076882]
    matmul_c  = [121903, 113747, 117244, 112486]
    avg_c     = [10253, 14652, 10266, 14540]
    fig, axs = plt.subplots(1, 3, figsize=(16, 5.5))
    fig.suptitle('Benchmark Execution Time (Cycle Count)', fontsize=16, fontweight='bold')
    draw_panel(axs[0], LABELS4, complex_s, 'complex.S (Cycles)', '{:,.0f}', comma_axis=True, rot=20)
    draw_panel(axs[1], LABELS4, matmul_c,  'matmul.c (Cycles)',  '{:,.0f}', comma_axis=True, rot=20)
    draw_panel(axs[2], LABELS4, avg_c,     'avg.c (Cycles)',     '{:,.0f}', comma_axis=True, rot=20)
    fig.tight_layout(rect=[0, 0, 1, 0.92])
    save(fig, 'cva6_benchmarks_sim_github', theme)

# =====================================================================
#  4) §7.1 Resource — 3 configs
#     -> custom_cva6_resource_utilization_syn_github_*.png
# =====================================================================
def plot_custom_resource(theme):
    set_theme(theme)
    lut = [54326, 54023, 63685]
    ff  = [23728, 23803, 25108]
    fig, axs = plt.subplots(1, 2, figsize=(13, 5.5))
    fig.suptitle('Resource Utilization — Custom vs. Baseline', fontsize=16, fontweight='bold')
    draw_panel(axs[0], LABELS3, lut, 'LUT Utilization',            '{:,.0f}', comma_axis=True)
    draw_panel(axs[1], LABELS3, ff,  'Flip-Flop (FF) Utilization', '{:,.0f}', comma_axis=True)
    fig.tight_layout(rect=[0, 0, 1, 0.92])
    save(fig, 'custom_cva6_resource_utilization_syn_github', theme)

# =====================================================================
#  5) §7.2 Timing — 3 configs -> custom_cva6_timing_syn_github_*.png
# =====================================================================
def plot_custom_timing(theme):
    set_theme(theme)
    fmax    = [52.31, 52.19, 50.08]
    wns_abs = [9.118, 9.160, 9.968]             # |WNS|
    logic   = [45, 45, 47]
    routing = [72.0, 71.097, 71.8]
    fig, axs = plt.subplots(2, 2, figsize=(13, 9.5))
    fig.suptitle('Timing & Critical Path — Custom vs. Baseline',
                 fontsize=16, fontweight='bold')
    draw_panel(axs[0, 0], LABELS3, fmax,    r'$F_{max}$ (MHz)',  '{:.2f}')
    draw_panel(axs[0, 1], LABELS3, wns_abs, '|WNS| (ns)',        '{:.3f}')
    draw_panel(axs[1, 0], LABELS3, logic,   'Logic Levels',      '{:.0f}')
    draw_panel(axs[1, 1], LABELS3, routing, 'Routing Share (%)', '{:.2f}')
    fig.tight_layout(rect=[0, 0, 1, 0.95])
    save(fig, 'custom_cva6_timing_syn_github', theme)

# =====================================================================
#  6) §7.3.1 Benchmarks (cycles) — 3 configs
#     -> custom_cva6_benchmarks_sim_github_*.png
# =====================================================================
def plot_custom_benchmarks(theme):
    set_theme(theme)
    complex_s = [2656954, 2615871, 2076882]
    matmul_c  = [117244, 117244, 112486]
    avg_c     = [10266, 10226, 14540]
    fig, axs = plt.subplots(1, 3, figsize=(16, 5.5))
    fig.suptitle('Benchmark Execution Time — Custom vs. Baseline (Cycle Count)',
                 fontsize=16, fontweight='bold')
    draw_panel(axs[0], LABELS3, complex_s, 'complex.S (Cycles)', '{:,.0f}', comma_axis=True, rot=15)
    draw_panel(axs[1], LABELS3, matmul_c,  'matmul.c (Cycles)',  '{:,.0f}', comma_axis=True, rot=15)
    draw_panel(axs[2], LABELS3, avg_c,     'avg.c (Cycles)',     '{:,.0f}', comma_axis=True, rot=15)
    fig.tight_layout(rect=[0, 0, 1, 0.92])
    save(fig, 'custom_cva6_benchmarks_sim_github', theme)

# =====================================================================
#  7) §7.3.2 complex_avg.c — 3 configs
#     -> custom_cva6_benchmarks_sim_avg_github_*.png
# =====================================================================
def plot_custom_complex_avg(theme):
    set_theme(theme)
    cycles = [11235565, 10834566, 9875796]
    fig, ax = plt.subplots(figsize=(8, 6))
    fig.suptitle('Complex Average Program Execution Time', fontsize=16, fontweight='bold')
    draw_panel(ax, LABELS3, cycles, 'complex_avg.c (Cycles)', '{:,.0f}', comma_axis=True)
    fig.tight_layout(rect=[0, 0, 1, 0.93])
    save(fig, 'custom_cva6_benchmarks_sim_avg_github', theme)

# =====================================================================
#  8) Comparison Synthesis Results — 3 configs
#     -> results_syn_github_*.png   (regenerated with |WNS| + palette)
# =====================================================================
def plot_results_syn(theme):
    set_theme(theme)
    fmax    = [52.31, 52.19, 50.08]
    wns_abs = [9.118, 9.160, 9.968]             # |WNS|
    lut     = [54326, 54023, 63685]
    ff      = [23728, 23803, 25108]
    fig, axs = plt.subplots(2, 2, figsize=(13, 9.5))
    fig.suptitle('Synthesis Results Comparison', fontsize=16, fontweight='bold')
    draw_panel(axs[0, 0], LABELS3, fmax,    r'$F_{max}$ (MHz)', '{:.2f}')
    draw_panel(axs[0, 1], LABELS3, wns_abs, '|WNS| (ns)',       '{:.3f}')
    draw_panel(axs[1, 0], LABELS3, lut,     'LUT Utilization',  '{:,.0f}', comma_axis=True)
    draw_panel(axs[1, 1], LABELS3, ff,      'Flip-Flop (FF) Utilization', '{:,.0f}', comma_axis=True)
    fig.tight_layout(rect=[0, 0, 1, 0.95])
    save(fig, 'results_syn_github', theme)

# =====================================================================
#  9) Comparison Benchmarks Simulation — 3 configs
#     -> benchmarks_sim_github_*.png
# =====================================================================
def plot_benchmarks_sim(theme):
    set_theme(theme)
    random_prog = [2656954, 2615871, 2076882]
    matmul      = [117244, 117244, 112486]
    averaging   = [11235565, 10834566, 9875796]
    fig, axs = plt.subplots(1, 3, figsize=(16, 5.5))
    fig.suptitle('Simulation Benchmarks (Cycle Count)',
                 fontsize=16, fontweight='bold')
    draw_panel(axs[0], LABELS3, random_prog, 'Random Program (Cycle Count)',        '{:,.0f}', comma_axis=True, rot=15)
    draw_panel(axs[1], LABELS3, matmul,      'Matrix Multiplication (Cycle Count)', '{:,.0f}', comma_axis=True, rot=15)
    draw_panel(axs[2], LABELS3, averaging,   'Averaging (Cycle Count)',             '{:,.0f}', comma_axis=True, rot=15)
    fig.tight_layout(rect=[0, 0, 1, 0.92])
    save(fig, 'benchmarks_sim_github', theme)

# =====================================================================
if __name__ == '__main__':
    for t in ['light', 'dark']:
        plot_timing_4cfg(t)
        plot_resource_4cfg(t)
        plot_benchmarks_4cfg(t)
        plot_custom_resource(t)
        plot_custom_timing(t)
        plot_custom_benchmarks(t)
        plot_custom_complex_avg(t)
        plot_results_syn(t)
        plot_benchmarks_sim(t)
    print('All 18 plots (9 figures x light/dark) generated successfully!')
