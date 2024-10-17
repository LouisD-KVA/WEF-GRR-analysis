import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
import matplotlib.patches as mpatches
from matplotlib.lines import Line2D

data_text = np.array([
    [24.85714286, 26.25, 24.85714286, 95.85714286, 24.85714286, 0, 120.25,
        1006.607143, 375.25, 78.85714286, 0, 0, 269, 97, 123, 647.8571429, 195.5],
    [67.61904762, 190.9166667, 115.952381, 21.28571429, 21.28571429, 119.6666667, 225.25,
        1148.869048, 316.25, 67.61904762, 46.33333333, 87, 436, 158, 158, 357.1190476, 286.8333333],
    [59, 18.66666667, 266.6666667, 18, 18, 18.66666667, 98.66666667, 476, 278.8333333,
        149, 19.33333333, 53.66666667, 334.3333333, 51.33333333, 51.33333333, 400, 111.5],
    [19.71428571, 43.33333333, 521.047619, 240.7142857, 19.71428571, 43.33333333, 0, 580.7142857,
        203.3333333, 70.71428571, 10.33333333, 0, 87.66666667, 10.33333333, 10.33333333, 194.7142857, 117],
    [11.71428571, 100.3333333, 118.047619, 11.71428571, 11.71428571, 89.33333333, 65.33333333,
        536.7142857, 196, 11.71428571, 0, 18.33333333, 322, 110.1666667, 110.1666667, 98.21428571, 132.5],
    [7.285714286, 124.6666667, 61.95238095, 7.285714286, 7.285714286, 79.66666667, 0, 237.2857143,
        207, 7.285714286, 112, 0, 218.3333333, 23.33333333, 23.33333333, 164.2857143, 87],
    [4.571428571, 34.66666667, 47.23809524, 49.57142857, 4.571428571, 36.66666667, 0, 308.5714286,
        40.33333333, 4.571428571, 13.33333333, 0, 73, 18.66666667, 18.66666667, 118.0714286, 107.5],
    [25.57142857, 0, 25.57142857, 25.57142857, 25.57142857, 41, 54,
        472.5714286, 370, 55.57142857, 0, 0, 71, 0, 0, 169.0714286, 55.5],
    [31.57142857, 178.6666667, 68.23809524, 31.57142857, 31.57142857, 170.6666667, 91, 1137.071429,
        278.3333333, 31.57142857, 26.33333333, 0, 292.3333333, 45, 45, 425.5714286, 147.5],
    [10.71428571, 30, 44.71428571, 10.71428571, 10.71428571, 97, 0,
        383.7142857, 250, 10.71428571, 196, 0, 126, 21, 21, 272.2142857, 115.5],
    [9.285714286, 0, 9.285714286, 169.2857143, 9.285714286, 55, 67, 428.2857143, 136.6666667,
        9.285714286, 11.66666667, 0, 105, 35.33333333, 35.33333333, 217.7857143, 109.5],
    [12.71428571, 34, 239.7142857, 49.71428571, 12.71428571, 83, 79,
        235.2142857, 229, 12.71428571, 65, 14, 308, 22, 22, 138.2142857, 50],
    [11.42857143, 7.8, 11.42857143, 11.42857143, 11.42857143, 28.8, 59.8,
        267.2285714, 95.8, 11.42857143, 0, 31, 93, 12, 12, 191.4285714, 86],
    [4.285714286, 59.4, 4.285714286, 4.285714286, 4.285714286, 90.4, 87.4, 371.852381, 20.4,
        37.28571429, 0, 28, 33.66666667, 5.666666667, 20.66666667, 162.452381, 129.6666667],
    [3.428571429, 57.91666667, 64.0952381, 3.428571429, 3.428571429, 51.66666667, 86.25,
        385.8452381, 96.25, 3.428571429, 0, 0, 36, 12.5, 12.5, 120.5952381, 100.6666667],
    [0, 20, 18, 0, 0, 51, 74.5, 258, 35, 0, 0, 15.5, 54, 12, 25, 88.5, 88.5],
    [0, 68.13333333, 30.33333333, 0, 0, 34.13333333, 86.3, 406.4666667, 8.8, 0,
        0, 19, 38.33333333, 10.33333333, 10.33333333, 63.16666667, 103.6666667],
    [0, 2.5, 13, 0, 0, 0, 64.83333333, 94, 2.5, 0,
        0, 4.333333333, 35.33333333, 4, 4, 58, 26.5],
    [1.857142857, 7.5, 47.85714286, 1.857142857, 1.857142857, 5, 34.5, 144.8571429,
        19.5, 1.857142857, 0, 6.5, 62.66666667, 6.666666667, 6.666666667, 93.85714286, 18]
])

data_survey = np.array([
    [0,0,6.875,0,0,0,1.458333333,16.25,6.333333333,0,0,0,9.75,2.291666667,2.291666667,14.70833333,16.375],
    [0,0,8.403855634,0,0,2.045630782,3.477198259,16.74685969,4.534337553,0,0,0,6.801379726,0,0,16.24976271,15.06597547],
    [0,0,9.722811756,0,0,1.784190302,3.518417583,20.45770628,4.564843398,0,0,0,10.18021255,2.380096791,2.380096791,19.70184578,22.3907486],
    [0,2.527022281,11.52338789,0,0,1.788778835,2.390153543,32.33326516,7.406848118,1.100229795,0,0,10.78349111,3.588052042,3.588052042,23.02808887,29.92348496],
    [0,3.373028551,12.85805365,0,0,1.879980793,3.291465425,36.60162107,9.330425808,1.379925069,0,0,11.74010606,4.156237861,4.156237861,24.73894481,31.81931734],
    [2.730958333,7.754655667,7.647553167,0,0,5.174040667,5.228480667,33.15478417,11.556361,5.400618,0,0,8.490094,4.786835167,2.603976833,30.26589783,12.81776517],
    [8.198517035,14.51835509,15.42644983,2.502013668,0,8.668049343,16.93909812,33.45558042,22.28047878,8.77372193,2.80572445,5.775436082,15.86463465,15.69510145,18.23996363,49.44818777,20.07225981],
    [9.060783333,15.46093333,16.0203,2.647733333,0,9.05825,18.44868333,35.64736667,23.45166667,9.189816667,2.918183333,6.181033333,17.16953333,16.62091667,19.35258333,52.26661667,21.69591667],
    [2.575729932,5.705978325,7.301171957,0,0,3.031706109,7.773955819,26.01775086,10.668214,5.758712079,2.575729932,0,11.71250211,11.38827757,13.61933542,27.91794471,10.17368953],
    [2.4904581,2.938847685,2.950294163,0,0,3.277039806,2.893174271,22.3592781,13.93089803,5.268609608,2.4904581,0,12.01975622,11.64875134,11.64875134,24.06589378,6.272810188],
    [2.488540831,2.982058096,2.734420962,0,0,3.243923959,3.017491337,25.45961609,13.85860757,5.984788658,2.488540831,0,12.3501436,12.00083776,14.81639215,26.54281015,6.009872086],
    [2.57154912,2.943874654,2.742506631,0,0,3.107855353,2.730900519,24.95880882,13.9647282,5.892811045,2.57154912,0,13.18374264,12.9535026,15.87066414,29.89912474,8.753154549],
    [2.616777184,2.877417145,2.603587223,0,0,3.046042903,2.464064366,22.7946569,14.15398945,5.668428475,2.616777184,0,13.5467584,13.25568393,15.91043348,28.36630125,8.003530556],
    [2.648008731,2.62377158,2.669269283,0,0,3.111671322,2.449367282,22.94834303,14.37043397,5.662685656,2.648008731,0,13.49463449,13.17262444,15.73480637,27.58520096,8.356408847],
    [2.447707958,2.635009131,2.578653425,0,0,3.112404902,2.392800911,22.51850185,14.12232127,5.238878564,2.447707958,0,13.46748101,13.24345523,13.24345523,24.40851353,8.340565332],
    [2.975927445,2.37869955,8.368580642,7.631376985,0,2.37869955,8.012788776,23.10710387,20.49004312,5.822572387,2.975927445,2.907330061,12.67807108,12.33161524,14.69017426,39.1390158,10.62788485],
    [3.437086093,6.710816777,9.997792494,6.913907285,0,6.710816777,7.306843267,27.06843267,20.70640177,7.434878587,3.437086093,3.984547461,16.43708609,12.01103753,15.2406181,45.18543046,10.91611479],
    [6.966906333,6.538166059,13.65625923,10.82760432,3.366689648,10.20450442,10.71171082,38.89241275,27.6826882,10.72694442,0,7.485406612,11.57332808,19.39581076,22.39791195,44.28658196,6.858793788]
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
df_text = pd.DataFrame(data_scaled_text, columns=[f'SDG {i}' for i in range(1, 18)])
df_text = df_text.melt(var_name='SDG Category', value_name='Values')
df_text['Dataset'] = 'Data Text'

df_survey = pd.DataFrame(data_scaled_survey, columns=[f'SDG {i}' for i in range(1, 18)])
df_survey = df_survey.melt(var_name='SDG Category', value_name='Values')
df_survey['Dataset'] = 'Data Survey'

# Combine the two datasets into a single DataFrame
df = pd.concat([df_text, df_survey], ignore_index=True)


# Full names of the SDGs
sdg_names = [
    'SDG 1. No poverty', 'SDG 2. Zero hunger', 'SDG 3. Good health and well-being',
    'SDG 4. Quality education', 'SDG 5. Gender equality', 'SDG 6. Clean water and sanitation',
    'SDG 7. Affordable and clean energy', 'SDG 8. Decent work and economic growth',
    'SDG 9. Industry, innovation, and infrastructure', 'SDG 10. Reduced inequalities',
    'SDG 11. Sustainable cities and communities', 'SDG 12. Responsible consumption and production',
    'SDG 13. Climate action', 'SDG 14. Life below water', 'SDG 15. Life on land',
    'SDG 16. Peace, justice, and strong institutions', 'SDG 17. Partnerships for the goals'
]

# SDG colors for each SDG category
sdg_colors = {
    'SDG 1': "#e5243b", 'SDG 2': "#dda63a", 'SDG 3': "#4c9f38", 'SDG 4': "#c5192d",
    'SDG 5': "#ff3a21", 'SDG 6': "#26bde2", 'SDG 7': "#fcc30b", 'SDG 8': "#a21942",
    'SDG 9': "#fd6925", 'SDG 10': "#dd1367", 'SDG 11': "#fd9d24", 'SDG 12': "#bf8b2e",
    'SDG 13': "#3f7e44", 'SDG 14': "#0a97d9", 'SDG 15': "#56c02b", 'SDG 16': "#00689d",
    'SDG 17': "#19486a"
}

# Create a column in the DataFrame for colors based on the SDG category
df['Color'] = df['SDG Category'].map(sdg_colors)

# Increase the text size globally using rcParams
plt.rcParams.update({'font.size': 12})  # Increase the default font size globally

# Create boxplots using matplotlib
fig, ax = plt.subplots(figsize=(12, 9))

# Plot boxplots for Data Text and Data Survey side by side for each SDG category
for i, category in enumerate([f'SDG {i}' for i in range(1, 18)]):
    data_text_values = df[(df['SDG Category'] == category) & (df['Dataset'] == 'Data Text')]['Values']
    data_survey_values = df[(df['SDG Category'] == category) & (df['Dataset'] == 'Data Survey')]['Values']

    # Turn off outliers by making flierprops invisible
    flierprops = dict(marker='o', color='none', markersize=0)

    # Boxplot for Data Text (transparent with colored edges and whiskers)
    ax.boxplot(data_text_values, positions=[i - 0.2], widths=0.35, patch_artist=True,
               boxprops=dict(facecolor='none', edgecolor=sdg_colors[category]),  # Transparent face, colored edge
               whiskerprops=dict(color=sdg_colors[category]),  # Colored whiskers
               capprops=dict(color=sdg_colors[category]),  # Colored caps
               medianprops=dict(color=sdg_colors[category]),  # Median line color
               flierprops=flierprops)  # Disable circles for outliers

    # Boxplot for Data Survey (transparent with colored edges and whiskers)
    ax.boxplot(data_survey_values, positions=[i + 0.2], widths=0.35, patch_artist=True,
               boxprops=dict(facecolor='none', edgecolor=sdg_colors[category]),  # Transparent face, colored edge
               whiskerprops=dict(color=sdg_colors[category]),  # Colored whiskers
               capprops=dict(color=sdg_colors[category]),  # Colored caps
               medianprops=dict(color=sdg_colors[category]),  # Median line color
               flierprops=flierprops)  # Disable circles for outliers

    # Overlay semi-transparent crosses for individual data points
    ax.scatter([i - 0.2] * len(data_text_values), data_text_values, color=sdg_colors[category], marker='x', alpha=0.3, zorder=3)
    ax.scatter([i + 0.2] * len(data_survey_values), data_survey_values, color=sdg_colors[category], marker='o', alpha=0.3, zorder=3)

# Customize x-axis with full SDG names
ax.set_xticks(np.arange(len(sdg_names)))
ax.set_xticklabels(sdg_names, rotation=45, ha='right')

# --- Custom Legend ---
# Rectangle with cross inside (for Data Text) "#e5243b"
cross_inside_rect = Line2D([0], [0], marker='x', color='#e5243b', markerfacecolor='#e5243b', alpha=0.3, markersize=10,
                           markeredgewidth=1.5, label='Text-based conceptualization of risks', markeredgecolor='#e5243b')

# Rectangle with circle inside (for Data Survey)
circle_inside_rect = Line2D([0], [0], marker='o', color='#e5243b', markerfacecolor='#e5243b', alpha=0.3, markersize=10,
                            markeredgewidth=1.5, label='Survey-based conceptualization of risks', markeredgecolor='#e5243b')

# Add the legend
plt.legend(handles=[cross_inside_rect, circle_inside_rect], loc='upper left', fontsize=12, frameon=False)

# Add labels and title
ax.set_xlabel('Sustainable Development Goals', fontsize=12)
ax.set_ylabel('Normalized proportion of screens (Z-score)', fontsize=12)

plt.tight_layout()

# Save the figure as a high-quality image (300 DPI)
plt.savefig("SDG.png", dpi=1000)

# Optionally, also display the plot
plt.show()