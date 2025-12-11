import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
import matplotlib.patches as mpatches
from matplotlib.lines import Line2D

data_text = np.array([
    [54, 1707, 768, 581, 0],
    [54, 1657, 1005, 1108, 0],
    [53, 772, 1027, 513, 58],
    [58, 803, 1147, 134, 31],
    [35, 799, 450, 660, 0],
    [30, 493, 478, 337, 0],
    [38, 463, 217, 122, 40],
    [49, 779, 397, 166, 0],
    [0, 1366, 1006, 581, 79],
    [0, 630, 671, 248, 51],
    [0, 573, 514, 286, 35],
    [0, 611, 385, 416, 195],
    [30, 408, 283, 221, 0],
    [17, 518, 285, 244, 0],
    [27, 543, 295, 173, 0],
    [0, 346, 167, 227, 0],
    [48, 503, 161, 167, 0],
    [23, 110, 66, 110, 0],
    [20, 161, 182, 98, 0]
])

data_survey = np.array([
    [1.333333333, 20.75, 26.41666667, 11.20833333, 0],
    [0, 21.28119724, 27.64340194, 12.32420877, 0],
    [0, 25.02254968, 30.05645058, 15.48282044, 0],
    [2.729015356, 38.36974914, 39.64675272, 17.60338248, 0],
    [3.014756865, 43.58380295, 43.18386698, 19.95787379, 0],
    [2.553878167, 39.96381317, 44.43835167, 21.24646067, 0],
    [0, 58.09160846, 60.03538992, 30.02879266, 0],
    [0, 61.54503333, 63.4866, 32.32301667, 0],
    [0, 37.07398188, 40.9808421, 19.84355624, 0],
    [0, 33.76260034, 35.73626054, 17.77545078, 0],
    [0, 36.8303263, 36.01090345, 18.40254727, 0],
    [0, 36.26029566, 38.58798827, 18.83524184, 0],
    [0, 34.32671293, 36.86051968, 18.96801379, 0],
    [0, 34.71800919, 36.29282563, 19.07215582, 0],
    [0, 34.07942454, 35.43932091, 19.16304502, 0],
    [0, 20.53691388, 45.71100677, 23.88409704, 0],
    [0, 40.49448124, 52.30684327, 24.46799117, 0],
    [0, 57.14209265, 47.18070193, 26.88121737, 0]
])

# calcule la moyenne pour chaque ligne de data
mean_vals_text = data_text.mean(axis=1, keepdims=True)
std_vals_text = data_text.std(axis=1, keepdims=True)
data_normalized_text = (data_text - mean_vals_text) / std_vals_text

mean_vals_survey = data_survey.mean(axis=1, keepdims=True)
std_vals_survey = data_survey.std(axis=1, keepdims=True)
data_normalized_survey = (data_survey - mean_vals_survey) / std_vals_survey

# Scale the data to the range [0, 1]
data_min_text = data_normalized_text.min()
data_max_text = data_normalized_text.max()
data_scaled_text = (data_normalized_text - data_min_text) / (data_max_text - data_min_text)

data_min_survey = data_normalized_survey.min()
data_max_survey = data_normalized_survey.max()
data_scaled_survey = (data_normalized_survey - data_min_survey) / (data_max_survey - data_min_survey)

# Combine the two datasets into one dataframe for Seaborn plotting
df_text = pd.DataFrame(data_scaled_text, columns=[f'CSS {i}' for i in range(1, 6)])
df_text = df_text.melt(var_name='CSS Category', value_name='Values')
df_text['Dataset'] = 'Data Text'

df_survey = pd.DataFrame(data_scaled_survey, columns=[f'CSS {i}' for i in range(1, 6)])
df_survey = df_survey.melt(var_name='CSS Category', value_name='Values')
df_survey['Dataset'] = 'Data Survey'

# Combine the two datasets into a single DataFrame
df = pd.concat([df_text, df_survey], ignore_index=True)

# Full names of the CSS
css_names = [
    'CSS 1. Compliance', 'CSS 2. Business-centered', 'CSS 3. Systemic',
    'CSS 4. Regenerative', 'CSS 5. Coevolutionary'
]

# Color-blind friendly red-to-green gradient
css_colors = {
    'CSS 1': "#D55E00",  # Coral (instead of red)
    'CSS 2': "#E69F00",  # Orange
    'CSS 3': "#F4A261",  # More visible yellowish (Goldenrod)
    'CSS 4': "#009E73",  # Teal (instead of green)
    'CSS 5': "#0072B2"   # Blue
}

# Create a column in the DataFrame for colors based on the AT category
df['Color'] = df['CSS Category'].map(css_colors)

# Increase the text size globally using rcParams
plt.rcParams.update({'font.size': 12})  # Increase the default font size globally

# Significance information for each CSS
# "both" = significant in both t-test and Wilcoxon
# "none" = no significant difference
css_significance = {
    'CSS 1. Compliance': 'both',       # t: 2.830489e-08, Wilcoxon: 0.000015
    'CSS 2. Business-centered': 'both',# t: 3.557458e-02, Wilcoxon: 0.039447
    'CSS 3. Systemic': 'both',         # t: 5.747100e-05, Wilcoxon: 0.000252
    'CSS 4. Regenerative': 'none',     # no significant difference
    'CSS 5. Coevolutionary': 'both'    # t: 2.315405e-08, Wilcoxon: 0.000008
}

# Create boxplots using matplotlib
fig, ax = plt.subplots(figsize=(12, 9))

# Plot boxplots for Data Text and Data Survey side by side for each AT category
for i, category in enumerate([f'CSS {i}' for i in range(1, 6)]):
    data_text_values = df[(df['CSS Category'] == category) & (df['Dataset'] == 'Data Text')]['Values']
    data_survey_values = df[(df['CSS Category'] == category) & (df['Dataset'] == 'Data Survey')]['Values']

    # Turn off outliers by making flierprops invisible
    flierprops = dict(marker='o', color='none', markersize=0)

    # Boxplot for Data Text (transparent with colored edges and whiskers)
    ax.boxplot(data_text_values, positions=[i - 0.2], widths=0.35, patch_artist=True,
               boxprops=dict(facecolor='none', edgecolor=css_colors[category]),  # Transparent face, colored edge
               whiskerprops=dict(color=css_colors[category]),  # Colored whiskers
               capprops=dict(color=css_colors[category]),  # Colored caps
               medianprops=dict(color=css_colors[category]),  # Median line color
               flierprops=flierprops)  # Disable circles for outliers

    # Boxplot for Data Survey (transparent with colored edges and whiskers)
    ax.boxplot(data_survey_values, positions=[i + 0.2], widths=0.35, patch_artist=True,
               boxprops=dict(facecolor='none', edgecolor=css_colors[category]),  # Transparent face, colored edge
               whiskerprops=dict(color=css_colors[category]),  # Colored whiskers
               capprops=dict(color=css_colors[category]),  # Colored caps
               medianprops=dict(color=css_colors[category]),  # Median line color
               flierprops=flierprops)  # Disable circles for outliers

    # Overlay semi-transparent crosses for individual data points
    ax.scatter([i - 0.2] * len(data_text_values), data_text_values, color=css_colors[category], marker='x', alpha=0.3, zorder=3)
    ax.scatter([i + 0.2] * len(data_survey_values), data_survey_values, color=css_colors[category], marker='o', alpha=0.3, zorder=3)

# Customize the x-axis with significance stars
ax.set_xticks(np.arange(len(css_names)))

labels_with_stars = []
for name in css_names:
    sig = css_significance.get(name, 'none')
    if sig == 'both':
        suffix = '**'      # significant in both tests
    elif sig == 'one':
        suffix = '*'       # (if you ever use this case)
    else:
        suffix = ''        # no star if not significant
    labels_with_stars.append(name + suffix)

ax.set_xticklabels(labels_with_stars, rotation=45, ha='right')


# --- Custom Legend ---
# Rectangle with cross inside (for Data Text) "#e5243b"
cross_inside_rect = Line2D([0], [0], marker='x', color='#D55E00', markerfacecolor='#D55E00', alpha=0.3, markersize=10,
                           markeredgewidth=1.5, label='Text-based conceptualization of risks', markeredgecolor='#D55E00')

# Rectangle with circle inside (for Data Survey)
circle_inside_rect = Line2D([0], [0], marker='o', color='#D55E00', markerfacecolor='#D55E00', alpha=0.3, markersize=10,
                            markeredgewidth=1.5, label='Survey-based conceptualization of risks', markeredgecolor='#D55E00')

# Add the legend at
plt.legend(handles=[cross_inside_rect, circle_inside_rect], loc='upper right', fontsize=12, frameon=False)

# Add labels and title
ax.set_ylabel('Normalized proportion of screens (Z-score)', fontsize=12)

plt.tight_layout(pad=2.0)

ax.text(
    -1.2, 1,  # Adjust position slightly outside the plot bounds
    "c)",  # Text to display
    transform=ax.transData,  # Use data coordinates for positioning
    fontsize=20,  # Font size
    ha="left",  # Horizontal alignment
    va="top",  # Vertical alignment
)

# Save the figure as a high-quality image (300 DPI)
plt.savefig("CSS.png", dpi=1000, bbox_inches="tight")

# Optionally, also display the plot
plt.show()