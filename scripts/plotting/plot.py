import matplotlib.pyplot as plt
import numpy as np
import os

# ================= Data =================
# Unified Labels
labels = ['32-bit\n(SS OFF)', '32-bit\n(SS ON)', '64-bit\n(SS OFF)', '64-bit\n(SS ON)']

# Timing Data
wns_original = [-3.729, -5.282, -9.118, -9.968]
wns_abs = [abs(x) for x in wns_original] # استفاده از قدر مطلق برای زیبایی و استاندارد بصری
fmax = [72.84, 65.43, 52.31, 50.08]

# Resource Data
lut = [135074, 140181, 54326, 63685]
ff = [327292, 328223, 23728, 25108]
bram = [16, 16, 36, 36]
dsp = [4, 4, 27, 27]

# ================= Themes Configuration =================
themes = {
    'light': {
        'bg': '#ffffff', 'text': '#1f2328', 'grid': '#d0d7de', 'spine': '#d0d7de',
        'wns': '#cf222e', 'fmax': '#0969da', 
        'lut': '#0969da', 'ff': '#bf8700', 'bram': '#1a7f37', 'dsp': '#cf222e',
        'edge': '#ffffff', 'legend_bg': '#f6f8fa', 'transparent': False, 'name': 'light'
    },
    'dark': {
        'bg': '#0d1117', 'text': '#e6edf3', 'grid': '#30363d', 'spine': '#30363d',
        'wns': '#ff7b72', 'fmax': '#58a6ff', 
        'lut': '#58a6ff', 'ff': '#d29922', 'bram': '#3fb950', 'dsp': '#f85149',
        'edge': '#0d1117', 'legend_bg': '#161b22', 'transparent': False, 'name': 'dark'
    },
    'transparent': {
        'bg': 'none', 'text': '#e6edf3', 'grid': '#30363d', 'spine': '#8b949e',
        'wns': '#ff7b72', 'fmax': '#58a6ff', 
        'lut': '#58a6ff', 'ff': '#d29922', 'bram': '#3fb950', 'dsp': '#f85149',
        'edge': 'none', 'legend_bg': 'none', 'transparent': True, 'name': 'transparent'
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
def plot_timing(cfg):
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
    # استفاده از فرمت ریاضی برای F_max
    ax2.set_ylabel(r'$F_{max}$ (MHz)', color=cfg['fmax'], fontweight='bold')
    bars2 = ax2.bar(x + width/2, fmax, width, label=r'$F_{max}$ (MHz)', color=cfg['fmax'])
    ax2.tick_params(axis='y', labelcolor=cfg['fmax'], colors=cfg['text'])

    for spine in ax2.spines.values():
        spine.set_edgecolor(cfg['spine'])

    # Data labels
    for bar in bars1:
        yval = bar.get_height()
        ax1.text(bar.get_x() + bar.get_width()/2, yval + 0.2, f'{yval}', ha='center', va='bottom', color=cfg['text'], fontsize=10, fontweight='bold')
    for bar in bars2:
        yval = bar.get_height()
        ax2.text(bar.get_x() + bar.get_width()/2, yval + 1.5, f'{yval}', ha='center', va='bottom', color=cfg['text'], fontsize=10, fontweight='bold')

    # تنظیم تایتل با فرمت ریاضی
    plt.title(r'CVA6 Timing Analysis: |WNS| vs $F_{max}$', color=cfg['text'], fontweight='bold', pad=15)
    
    # تنظیم Legend
    fig.legend(loc='upper right', bbox_to_anchor=(0.9, 0.9), facecolor=cfg['legend_bg'], edgecolor=cfg['spine'], labelcolor=cfg['text'])

    # رفع مشکل هم‌پوشانی احتمالی المان‌ها در نمودار دو محوره
    max_wns = max(wns_abs)
    ax1.set_ylim(0, max_wns * 1.25)
    max_fmax = max(fmax)
    ax2.set_ylim(0, max_fmax * 1.25)

    fig.tight_layout()
    filename = f"cva6_timing_github_{cfg['name']}.png"
    plt.savefig(filename, transparent=cfg['transparent'], dpi=300)
    plt.close()
    print(f"Saved: {filename}")

def plot_resources(cfg):
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

    plt.tight_layout()
    filename = f"cva6_github_{cfg['name']}.png"
    plt.savefig(filename, dpi=300, bbox_inches='tight', transparent=cfg['transparent'])
    plt.close(fig)
    print(f"Saved: {filename}")

# ================= Generate All Charts =================
for name, cfg in themes.items():
    plot_timing(cfg)
    plot_resources(cfg)

print("\nAll 6 charts have been generated successfully!")
