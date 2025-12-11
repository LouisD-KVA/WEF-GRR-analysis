import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
import matplotlib.patches as mpatches
from matplotlib.lines import Line2D

data_text = np.array([
    [1514,1339,463,515,106,378,463,48,300,248,1422,1360,0,316],
    [2141,2104,1000,260,250,362,890,0,137,144,1390,1951,50,229],
    [911,982,468,387,328,163,364,0,190,135,531,853,0,219],
    [673,1001,98,42,633,45,98,0,52,186,688,606,221,279],
    [1097,968,613,74,248,116,481,0,105,84,634,1059,77,135],
    [588,588,337,130,71,171,337,0,102,30,413,416,31,81],
    [554,469,122,99,35,27,122,0,0,34,371,487,28,66],
    [363,738,112,99,0,142,112,0,282,0,477,275,0,121],
    [1811,1769,490,283,110,218,490,0,66,59,1230,1605,0,280],
    [704,647,248,308,34,262,248,0,90,31,462,570,29,106],
    [649,671,164,188,0,100,164,0,50,42,490,581,160,107],
    [928,497,322,41,63,206,267,0,0,104,239,415,37,193],
    [336,537,167,137,35,128,140,0,88,35,316,230,67,80],
    [602,777,188,93,0,73,188,0,17,0,540,602,0,30],
    [590,665,93,64,100,174,68,0,21,0,428,516,25,24],
    [439,529,168,73,28,94,168,0,0,0,311,404,0,0],
    [664,569,79,40,41,132,79,21,0,0,507,640,0,0],
    [149,145,52,31,13,68,39,18,0,0,100,139,0,0],
    [219,280,89,45,69,70,89,34,0,13,167,192,0,13]
])

data_survey = np.array([
    [16.875,21.79166667,9.75,14.29166667,5.666666667,2.958333333,9.75,1.875,4.833333333,0,15.08333333,15.375,3.958333333,0],
    [22.13263393,23.38781876,8.847010507,13.58442248,7.049240896,6.656921074,8.847010507,3.900814157,1.354614738,0,19.41219991,21.43973883,5.833726565,0],
    [25.71318895,30.04201235,11.96440286,17.29594347,8.033354235,6.39380346,11.96440286,3.589941475,1.689457521,0,22.86360859,28.65862756,10.18021255,0],
    [38.44847503,44.80143344,15.21322894,25.07007509,8.616199453,6.483399276,13.79488756,3.079462456,3.313602385,0,33.30284598,34.3552293,1.418341382,0],
    [45.29454692,49.04197691,15.08511939,27.16480738,9.416223745,8.711364804,15.08511939,3.089835937,3.910526428,0,36.65867396,38.29335857,1.581288974,0],
    [45.774741,44.4473715,23.922979,24.83495983,5.1733525,7.451103333,18.4906965,6.870999667,4.464790333,0,38.96245367,41.11764433,2.701324167,0],
    [58.24531498,51.37850626,37.88873887,29.96743964,7.706227113,15.90677839,31.41006747,7.79909342,10.06426459,2.502013668,41.67139256,49.97085568,3.001900411,2.502013668],
    [62.12818333,54.58075,41.25706667,31.75326667,8.057133333,16.34081667,33.90593333,9.104083333,10.62475,2.647733333,44.40063333,53.82371667,3.277333333,2.647733333],
    [42.52379791,34.72761299,19.97539321,23.46456957,4.599025899,9.759525262,17.18125156,4.780528282,5.789625048,0,28.84694355,34.94306289,5.912507838,2.794141648],
    [36.92472569,31.88654083,18.15931632,26.7298815,2.950294163,10.73949976,15.29679602,5.606858445,8.575030645,0,19.8317023,31.5688583,2.862520295,2.952168754],
    [40.36755485,34.98539452,18.62897989,26.93649371,2.734420962,10.69751833,15.59406756,5.562902516,8.667121412,0,22.97171873,35.17606869,3.034912338,3.103545483],
    [40.68804794,37.76181707,19.21219667,30.2676129,2.742506631,10.60962913,16.29159799,5.996710068,8.657548705,0,22.29556746,35.38086845,2.920598681,2.868387605],
    [39.14685526,35.21012734,19.54999232,28.56372881,2.603587223,10.38653839,16.5928013,5.767455552,8.848292606,0,20.17272348,33.84115842,2.957191024,2.704888414],
    [39.31335654,35.46384882,19.73445986,27.93632214,2.669269283,10.61927768,16.60630581,5.059498405,8.848532308,0,20.34757522,33.79145487,3.12815405,2.685268123],
    [38.87287622,37.54558111,19.88264901,27.04150777,2.578653425,10.29009782,16.57988591,4.787142433,8.672732318,0,19.95710326,33.42328726,3.302763098,2.735073014],
    [32.69286072,31.39557616,21.49262263,20.72990662,5.79839065,7.357778527,18.31216031,4.781377093,7.832803154,5.660295922,18.26805016,25.33508219,8.072305275,11.13678475],
    [38.86313466,45.61368653,24.46799117,28.46799117,13.8410596,13.88962472,16.20750552,6.353200883,7.236203091,14.18101545,27.58940397,28.81677704,4.046357616,14.18101545],
    [44.31514495,46.41071604,26.88121737,23.94221741,10.38202173,16.76020224,22.72507305,6.080994123,17.91857907,7.619488493,29.43540497,34.55103582,4.156144325,7.619488493]
])

# Normalize and scale the data
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

# Full names for each AT with AT number
at_names = [
    'AT 1. Simplification', 'AT 2. Growth-for-growth', 'AT 3. Overshoot', 'AT 4. Division', 'AT 5. Contagion',
    'AT 6. Infrastructure lock-in', 'AT 7. Chemical pollution', 'AT 8. Existential technology',
    'AT 9. Technological autonomy', 'AT 10. Dis- and mis-information', 'AT 11. Short-termism',
    'AT 12. Overconsumption', 'AT 13. Biosphere disconnect', 'AT 14. Local social capital loss'
]

# Combine the two datasets
df_text = pd.DataFrame(data_scaled_text, columns=at_names)
df_text = df_text.melt(var_name='AT Category', value_name='Values')
df_text['Dataset'] = 'Data Text'

df_survey = pd.DataFrame(data_scaled_survey, columns=at_names)
df_survey = df_survey.melt(var_name='AT Category', value_name='Values')
df_survey['Dataset'] = 'Data Survey'

df = pd.concat([df_text, df_survey], ignore_index=True)

# Color palette
at_colors = {
    'AT 1. Simplification': "#1E90FF",  # Dodger Blue
    'AT 2. Growth-for-growth': "#1D89F2",  # Slightly darker Dodger Blue
    'AT 3. Overshoot': "#1C83E6",  # Closer shade of blue
    'AT 4. Division': "#1B7CDA",  # Another close blue shade
    'AT 5. Contagion': "#1A76CF",  # Darker blue, closer in tone
    'AT 6. Infrastructure lock-in': "#FFA07A",  # Light Salmon
    'AT 7. Chemical pollution': "#FF9A74",  # Slightly darker salmon
    'AT 8. Existential technology': "#FF946F",  # Closer in tone to orange
    'AT 9. Technological autonomy': "#FF8E69",  # A slightly deeper orange
    'AT 10. Dis- and mis-information': "#FF8864",  # Even closer in tone to orange-red
    'AT 11. Short-termism': "#32CD32",  # Lime Green (consistent)
    'AT 12. Overconsumption': "#BA55D3",  # Medium Orchid
    'AT 13. Biosphere disconnect': "#B052C9",  # Slightly darker purple
    'AT 14. Local social capital loss': "#A74EBF"  # Even closer darker purple
}

df['Color'] = df['AT Category'].map(at_colors)

# Significance information for each AT
# "both"  = significant in t-test *and* Wilcoxon
# "one"   = significant in only one of the two tests
# "none"  = no significant difference

significance = {
    'AT 1. Simplification': 'both',              # t: 2.047749e-05, Wilcoxon: 0.000145
    'AT 2. Growth-for-growth': 'both',           # t: 6.435382e-03, Wilcoxon: 0.012921
    'AT 3. Overshoot': 'both',                   # t: 4.063399e-05, Wilcoxon: 0.000706
    'AT 4. Division': 'both',                    # t: 3.807430e-12, Wilcoxon: 0.000008
    'AT 5. Contagion': 'none',                   # t: 9.462313e-01, Wilcoxon: 0.637518
    'AT 6. Infrastructure lock-in': 'none',      # t: 1.564924e-01, Wilcoxon: 0.162336
    'AT 7. Chemical pollution': 'both',          # t: 3.437256e-05, Wilcoxon: 0.000650
    'AT 8. Existential technology': 'both',      # t: 1.751242e-03, Wilcoxon: 0.002335
    'AT 9. Technological autonomy': 'one',       # Significant in Wilcoxon only
    'AT 10. Dis- and mis-information': 'both',   # t: 8.455982e-03, Wilcoxon: 0.006393
    'AT 11. Short-termism': 'one',               # Significant in t-test only
    'AT 12. Overconsumption': 'both',            # t: 1.131957e-04, Wilcoxon: 0.000145
    'AT 13. Biosphere disconnect': 'none',       # No significant difference
    'AT 14. Local social capital loss': 'both'   # t: 1.211354e-02, Wilcoxon: 0.025775
}

# Increase the text size 
plt.rcParams.update({'font.size': 12})  # Increase the default font size globally

# Create boxplots using matplotlib
fig, ax = plt.subplots(figsize=(12, 9))

# Plot boxplots for Data Text and Data Survey
for i, category in enumerate(at_names):
    data_text_values = df[(df['AT Category'] == category) & (df['Dataset'] == 'Data Text')]['Values']
    data_survey_values = df[(df['AT Category'] == category) & (df['Dataset'] == 'Data Survey')]['Values']

    # Turn off outliers by making flierprops invisible
    flierprops = dict(marker='o', color='none', markersize=0)

    # Boxplot for Data Text (transparent with colored edges and whiskers)
    ax.boxplot(data_text_values, positions=[i - 0.2], widths=0.35, patch_artist=True,
               boxprops=dict(facecolor='none', edgecolor=at_colors[category]),  # Transparent face, colored edge
               whiskerprops=dict(color=at_colors[category]),  # Colored whiskers
               capprops=dict(color=at_colors[category]),  # Colored caps
               medianprops=dict(color=at_colors[category]),  # Median line color
               flierprops=flierprops)  # Disable circles for outliers

    # Boxplot for Data Survey (transparent with colored edges and whiskers)
    ax.boxplot(data_survey_values, positions=[i + 0.2], widths=0.35, patch_artist=True,
               boxprops=dict(facecolor='none', edgecolor=at_colors[category]),  # Transparent face, colored edge
               whiskerprops=dict(color=at_colors[category]),  # Colored whiskers
               capprops=dict(color=at_colors[category]),  # Colored caps
               medianprops=dict(color=at_colors[category]),  # Median line color
               flierprops=flierprops)  # Disable circles for outliers

    # Overlay semi-transparent crosses for individual data points
    ax.scatter([i - 0.2] * len(data_text_values), data_text_values, color=at_colors[category], marker='x', alpha=0.3, zorder=3)
    ax.scatter([i + 0.2] * len(data_survey_values), data_survey_values, color=at_colors[category], marker='o', alpha=0.3, zorder=3)

# Customize the x-axis with significance stars
ax.set_xticks(np.arange(len(at_names)))

labels_with_stars = []
for name in at_names:
    sig = significance.get(name, 'none')
    if sig == 'both':
        suffix = '**'   # significant in both tests
    elif sig == 'one':
        suffix = '*'    # significant in only one test
    else:
        suffix = ''     # no star if not significant
    labels_with_stars.append(name + suffix)

ax.set_xticklabels(labels_with_stars, rotation=45, ha='right')

# --- Custom Legend ---
# Rectangle with cross inside (for Data Text) "#e5243b"
cross_inside_rect = Line2D([0], [0], marker='x', color='#1E90FF', markerfacecolor='#1E90FF', alpha=0.3, markersize=10,
                           markeredgewidth=1.5, label='Text-based conceptualization of risks', markeredgecolor='#1E90FF')

# Rectangle with circle inside (for Data Survey)
circle_inside_rect = Line2D([0], [0], marker='o', color='#1E90FF', markerfacecolor='#1E90FF', alpha=0.3, markersize=10,
                            markeredgewidth=1.5, label='Survey-based conceptualization of risks', markeredgecolor='#1E90FF')

# Add the legend
plt.legend(handles=[cross_inside_rect, circle_inside_rect], loc='upper right', fontsize=12, frameon=False)

# Add labels and title
ax.set_ylabel('Normalized proportion of screens (Z-score)', fontsize=12)

plt.tight_layout(pad=2.0)

ax.text(
    -2, 1,  # Adjust position slightly outside the plot bounds
    "b)",  # Text to display
    transform=ax.transData,  # Use data coordinates for positioning
    fontsize=20,  # Font size
    ha="left",  # Horizontal alignment
    va="top",  # Vertical alignment
)

# Save the figure as a high-quality image (300 DPI)
plt.savefig("AT.png", dpi=1000, bbox_inches="tight")

# Optionally, also display the plot
plt.show()

