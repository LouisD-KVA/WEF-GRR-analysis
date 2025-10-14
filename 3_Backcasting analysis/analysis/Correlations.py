import matplotlib.pyplot as plt
import numpy as np
from statsmodels.nonparametric.smoothers_lowess import lowess
from matplotlib.lines import Line2D

# Define the data for each group
x_values = np.array([-5, -4, -3, -2, -1, 1, 2, 3, 4, 5])
groups = {
    "Climatic": [-0.32, -0.48, -0.21, -0.35, -0.49, -0.08, 0.40, 0.18, 0.30, 0.59],
    "Geophysical": [-0.58, -0.52, -0.33, -0.17, 0.00, -0.09, -0.05, -0.31, -0.35, -0.29],
    "Ecological - diseases": [-0.14, -0.06, -0.24, 0.22, 0.47, -0.06, -0.20, -0.11, 0.31, 0.45],
    "Ecological - ecosystem services": [-0.80, 0.19, 0.01, -0.32, -0.35, 0.28, 0.34, -0.12, -0.54, -0.06],
    "Economic": [-0.44, -0.35, -0.41, 0.09, 0.28, -0.24, -0.50, -0.45, -0.46, -0.02],
    "Technological": [-0.29, -0.45, -0.23, -0.24, -0.44, -0.39, -0.47, -0.14, -0.18, -0.54],
    "Geopolitical - terrorist attacks": [0.23, 0.39, 0.54, 0.55, 0.56, 0.62, 0.49, 0.28, -0.11, -0.34],
    "Geopolitical - conflicts": [-0.30, -0.16, -0.07, 0.18, 0.19, 0.25, 0.47, 0.44, 0.33, 0.42]
}

# Color-blind-friendly colors and markers
colors = ['#0072B2', '#D55E00', '#009E73', '#F0E442', '#56B4E9', '#CC79A7', '#E69F00', '#000000']
markers = ['o', 's', '^', 'P', 'X', 'D', '*', 'v']
frac_values = [0.1, 0.2, 0.3, 0.4, 0.5]  # Different smoothing parameters for LOESS

# Set up the figure and axis
fig, ax = plt.subplots(figsize=(10, 10))
ax.grid(True, linestyle="--", alpha=0.5)
ax.set_xlim(-5.2, 5.2)
ax.set_ylim(-1, 1)
ax.spines['left'].set_position(('data', 0))
ax.spines['bottom'].set_position(('data', 0))
ax.spines['right'].set_color('none')
ax.spines['top'].set_color('none')

# Create custom legend handles
legend_handles = []

# Plot each group with LOESS regression lines and an envelope for all frac values
for (group_name, y_values), marker, color in zip(groups.items(), markers, colors):
    ax.scatter(x_values, y_values, label=group_name, marker=marker, color=color, s=50, alpha=0.8)
    
    loess_lines = []
    for frac in frac_values:
        loess_result = lowess(y_values, x_values, frac=frac)
        x_loess = loess_result[:, 0]
        y_loess = loess_result[:, 1]
        loess_lines.append(y_loess)
        linestyle = "--" if frac == 0.2 else "-." if frac == 0.3 else ":"
        ax.plot(x_loess, y_loess, color=color, linestyle=linestyle, alpha=0.6)
    
    loess_min = np.min(loess_lines, axis=0)
    loess_max = np.max(loess_lines, axis=0)
    ax.fill_between(x_loess, loess_min, loess_max, color=color, alpha=0.2)
    legend_handles.append(Line2D([0], [0], color=color, marker=marker, linestyle="-", markersize=8, label=group_name))

# Add legend and annotations
ax.legend(handles=legend_handles, loc="lower center", bbox_to_anchor=(0.5, -0.35), ncol=2, frameon=False, fontsize=12, title="Risk category")
ax.text(-5.5, 0, "Backward\nlooking", va='center', ha='right', fontsize=12, color="black")
ax.text(5.5, 0, "Forward\nlooking", va='center', ha='left', fontsize=12, color="black")
ax.text(0, -1.15, "Perfect negative correlation", va='top', ha='center', fontsize=12, color="black")
ax.text(0, 1.15, "Perfect positive correlation", va='top', ha='center', fontsize=12, color="black")

# Adjust layout and save the plot
plt.tight_layout(pad=2.0)
plt.savefig("Correlations.png", dpi=1000, bbox_inches="tight")
plt.show()
