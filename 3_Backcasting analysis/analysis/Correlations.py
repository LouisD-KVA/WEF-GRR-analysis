import matplotlib.pyplot as plt
import numpy as np
from statsmodels.nonparametric.smoothers_lowess import lowess
from matplotlib.lines import Line2D

# Define the data for each group
x_values = np.array([-5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5])
groups = {
    "Climatic": [-0.31, -0.43, -0.42, -0.47, -0.44, -0.28, -0.04, 0.25, 0.20, 0.45, 0.43],
    "Geophysical": [-0.48, -0.60, -0.45, -0.38, -0.05, 0.01, 0.01, -0.10, -0.08, -0.32, -0.39],
    "Ecological - diseases": [-0.13, 0.17, -0.21, 0.08, 0.48, 0.25, -0.08, -0.16, -0.46, 0.00, 0.12],
    "Ecological - ecosystem services": [-0.27, -0.34, -0.28, 0.36, -0.36, -0.11, -0.09, -0.03, 0.60, 0.02, 0.26],
    "Economic": [-0.35, -0.35, -0.46, 0.06, 0.04, -0.08, -0.07, -0.56, -0.56, -0.40, -0.18],
    "Technological": [-0.11, -0.29, -0.06, -0.08, -0.29, -0.21, -0.27, -0.36, -0.01, -0.06, -0.44],
    "Geopolitical - terrorist attacks": [0.23, 0.39, 0.54, 0.55, 0.56, 0.53, 0.62, 0.49, 0.28, -0.11, -0.34],
    "Geopolitical - conflicts": [0.37, 0.50, 0.55, 0.65, 0.65, 0.63, 0.68, 0.77, 0.78, 0.67, 0.65]
}

# Color-blind-friendly colors and markers
colors = ['#0072B2', '#D55E00', '#009E73', '#F0E442', '#56B4E9', '#CC79A7', '#E69F00', '#000000']
markers = ['o', 's', '^', 'P', 'X', 'D', '*', 'v']
frac_values = [0.2, 0.3, 0.4]  # Different smoothing parameters for LOESS

# Set up the figure and axis
fig, ax = plt.subplots(figsize=(10, 8))

# Set grid, limits, and remove spines for the cross-axis effect
ax.grid(True, linestyle="--", alpha=0.5)
ax.set_xlim(-5.2, 5.2)
ax.set_ylim(-1, 1)
ax.spines['left'].set_position(('data', 0))
ax.spines['bottom'].set_position(('data', 0))
ax.spines['right'].set_color('none')
ax.spines['top'].set_color('none')

# Create custom legend handles
legend_handles = []

# Add custom labels for the left and bottom sides
ax.text(-5.5, 0, "Backward\nlooking", va='center', ha='right', fontsize=12, rotation=0, color="black")
ax.text(5.5, 0, "Forward\nlooking", va='center', ha='left', fontsize=12, rotation=0, color="black")
ax.text(0, -1.15, "Perfect negative correlation", va='top', ha='center', fontsize=12, rotation=0, color="black")
ax.text(0, 1.15, "Perfect positive correlation", va='top', ha='center', fontsize=12, rotation=0, color="black")

# Plot each group with LOESS regression lines and an envelope for all frac values
for (group_name, y_values), marker, color in zip(groups.items(), markers, colors):
    # Plot original points for each group
    ax.scatter(x_values, y_values, label=group_name, marker=marker, color=color, s=50, alpha=0.8)
    
    # Calculate LOESS lines and store them to compute the envelope
    loess_lines = []
    for frac in frac_values:
        loess_result = lowess(y_values, x_values, frac=frac)
        x_loess, y_loess = zip(*loess_result)
        loess_lines.append(y_loess)
        
        # Plot each LOESS-smoothed line with varying line styles for each frac
        linestyle = "--" if frac == 0.2 else "-." if frac == 0.3 else ":"
        ax.plot(x_loess, y_loess, color=color, linestyle=linestyle, alpha=0.6)
    
    # Calculate the envelope by taking min and max of all LOESS lines at each x-point
    loess_min = np.min(loess_lines, axis=0)
    loess_max = np.max(loess_lines, axis=0)
    ax.fill_between(x_loess, loess_min, loess_max, color=color, alpha=0.2)

    # Add a custom legend handle with both line and marker
    legend_handles.append(Line2D([0], [0], color=color, marker=marker, linestyle="-", markersize=8, label=group_name))

# Add legend at the bottom, centered and stretched
ax.legend(handles=legend_handles, title="Risks (LOESS)", loc="lower center", bbox_to_anchor=(0.5, -0.4), ncol=2, frameon=False, fontsize=12, title_fontsize=12)

# Show the plot
ax.set_xticks([-5, -4, -3, -2, -1, 1, 2, 3, 4, 5])
# Save the figure as a high-quality image (300 DPI)
plt.savefig("Correlations.png", dpi=1000)

plt.show()
