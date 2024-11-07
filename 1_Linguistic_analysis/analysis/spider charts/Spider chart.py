import matplotlib.pyplot as plt
import numpy as np
import matplotlib.patches as mpatches

# Define the categories and datasets for each plot
categories = ["Positive words", "Negative words", "Uncertain words", "Litigious words", "Constraining words", "Readibility index"]
names = ["WEF", "WMO", "BIS", "IMF", "FAO", "UNWWDR", "UNCTAD", "WIPO", "UNCHR"]
mean_values = [
    [0.275190165, 0.105635829, 0.246361499, 0.195009096, 0.315539931, 0.375564686, 0.621030179, 0.620604976, 0.368387962],
    [0.711857208, 0.300490948, 0.308482968, 0.336202966, 0.354393232, 0.215423825, 0.082735449, 0.076684495, 0.293914863],
    [0.64149093, 0.120235665, 0.295918499, 0.232356571, 0.121539133, 0.097175014, 0.061963727, 0.100177298, 0.025712961],
    [0.458280272, 0.03595909, 0.626807901, 0.191941586, 0.150332382, 0.432383253, 0.198928676, 0.442081276, 0.600210087],
    [0.503096212, 0.130745871, 0.743382155, 0.416887329, 0.601058152, 0.654947925, 0.542445174, 0.357210732, 0.792500525],
    [0.527189137, 0.326554438, 0.260702638, 0.09370736, 0.16767305, 0.329969695, 0.325429249, 0.278712337, 0.740480778]
]
min_values = [
    [0.142826911, 0, 0.148136714, 0.078536769, 0.128305735, 0.15774149, 0.549609488, 0.267979799, 0.055752015],
    [0.475984648, 0.143631928, 0.222577913, 0.183342936, 0.143509548, 0.131161569, 0, 0.018706077, 0.246278853],
    [0.412177443, 0.058283749, 0.205721149, 0.169991677, 0.021743093, 0.048388139, 0, 0.048638818, 0.014284686],
    [0.226079557, 0, 0.494960416, 0.094346935, 0.038153668, 0.217505968, 0.15154328, 0.285084517, 0.400387212],
    [0.318473258, 0, 0.450537705, 0.289406521, 0.388638468, 0.42062997, 0.429648411, 0.325373841, 0.548070514],
    [0.236172708, 0.131090895, 0.209522941, 0.050285911, 0, 0.250861459, 0.151439915, 0.293050162, 0.479385401]
]
max_values = [
    [0.435599125, 0.205476718, 0.299065625, 0.288952648, 0.604207934, 0.576106014, 1, 0.96515419, 0.458598245],
    [1, 0.395438153, 0.418561848, 0.480461346, 0.816814666, 0.353513252, 0.19090546, 0.141073157, 0.422894998],
    [1, 0.294835552, 0.384893681, 0.293634921, 0.341212334, 0.171550539, 0.118407556, 0.173063155, 0.046996301],
    [1, 0.080956409, 0.920707501, 0.372517678, 0.402974795, 0.660865063, 0.289851285, 0.760399745, 0.783789212],
    [0.699841947, 0.296781911, 1, 0.574791355, 0.876547694, 0.870526631, 0.808638908, 0.536289695, 0.967042476],
    [1, 0.539360303, 0.359929061, 0.135788643, 0.300095644, 0.466969941, 0.513747463, 0.401830121, 0.90287782]
]
evolution_values = [
    [-0.064680242, 0.010782812, 0.024417601, -0.066993505, -0.054429354, -0.073491839, -0.066086896, -0.030468186, -0.099453777],
    [0.287771763, 0.062360036, 0.002488953, -0.053001088, -0.128066056, 0.040733233, -0.008888548, -0.083389969, 0.091916288],
    [-0.33361598, -0.061683646, -0.064439977, -0.060658383, 0.003212365, 0.002636288, -0.010203787, -0.021356173, 0.014412284],
    [0.086146963, -0.022144512, 0.127364717, -0.010700019, -0.022295073, -0.007530597, 0.068326728, -0.354665534, 0.042152912],
    [0.016554399, 0.031977031, 0.08486524, 0.022150524, -0.147323589, -0.104646728, 0.0130779, -0.089341472, 0.097922184],
    [-0.416179145, -0.12058078, 0.034080471, -0.013890399, -0.126904437, -0.061312487, -0.017788666, -0.063881638, -0.155316316]
]

# Create a 3x3 grid of radar charts
fig, axs = plt.subplots(3, 3, figsize=(18, 18), subplot_kw=dict(polar=True))

# Increase the spacing between subplots
fig.subplots_adjust(hspace=0.5, wspace=0.5)  # Adjust values as needed


# Set the color-blind friendly colors
min_color = "#92c5de"  # Light Blue 
min_max_color = "#053061"  # Dark Blue
mean_color = "#e41a1c"      # Red

# Plotting each subplot in the 3x3 grid
for idx, (row, col) in enumerate([(i // 3, i % 3) for i in range(9)]):
    ax = axs[row, col]
    
    # Select the data for the current plot
    mean_val = [mean_values[i][idx] for i in range(6)]
    min_val = [min_values[i][idx] for i in range(6)]
    max_val = [max_values[i][idx] for i in range(6)]
    evolution_val = [evolution_values[i][idx] for i in range(6)]
    
    # Complete the loop for circular radar plots
    mean_val += mean_val[:1]
    min_val += min_val[:1]
    max_val += max_val[:1]
    angles = np.linspace(0, 2 * np.pi, len(categories), endpoint=False).tolist() + [0]

    # Plot lines and shaded area
    ax.plot(angles, min_val, color=min_color, linewidth=1, linestyle='dashed')
    ax.plot(angles, max_val, color=min_max_color, linewidth=1, linestyle='dashed')
    ax.fill_between(angles, min_val, max_val, color=min_max_color, alpha=0.1)
    ax.plot(angles, mean_val, color=mean_color, linewidth=2)

    # Add arrows with scaled lengths and sizes based on evolution values
    for i in range(len(categories)):
        angle = angles[i]
        radius = mean_val[i]
        change_magnitude = evolution_val[i]
        
        # Determine arrow direction and length based on evolution values
        direction = 1 if change_magnitude > 0 else -1
        arrow_length = abs(change_magnitude) * 0.2 * direction  # Adjust length to represent change magnitude
        arrow_size = 10 + abs(change_magnitude) * 50  # Adjust arrow head size based on change magnitude
        
        # Plot arrow
        ax.annotate('', xy=(angle, radius + arrow_length), xytext=(angle, radius),
                    arrowprops=dict(facecolor=mean_color, edgecolor=mean_color, shrink=0.05, width=2, headwidth=arrow_size, headlength=arrow_size / 1.5))
    
    # Set category labels and plot title
    ax.set_xticks(angles[:-1])
    ax.set_xticklabels(categories)
    ax.set_ylim(0, 1)
    ax.set_yticks(np.arange(0, 1.1, 0.1))
    ax.set_yticklabels([f"{i/10:.1f}" for i in range(11)], color="grey", size=8, verticalalignment='center')
    ax.grid(True)
    ax.set_title(names[idx], fontsize=14, pad=20)

# Add a single legend for the entire figure
lines = [axs[0, 0].plot([], [], color=min_color, linewidth=1, linestyle='dashed', label="Minimum")[0],
         axs[0, 0].plot([], [], color=min_max_color, linewidth=1, linestyle='dashed', label="Maximum")[0],
         axs[0, 0].plot([], [], color=mean_color, linewidth=2, label="Mean")[0]]

fig.legend(handles=lines, loc='upper center', bbox_to_anchor=(0.5, 0.95), ncol=3, fontsize=12)

# Save the figure as a high-quality image (1000 DPI)
plt.savefig("Spider chart.png", dpi=1000)

# Optionally, also display the plot
plt.show()