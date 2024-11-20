import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

# Define the data
data = {
    "lookings": [-5, -4, -3, -2, -1, 1, 2, 3, 4, 5],
    "Climatic": [-0.31, -0.43, -0.42, -0.47, -0.44, -0.04, 0.25, 0.2, 0.45, 0.43],
    "Geophysical": [-0.48, -0.6, -0.45, -0.38, -0.05, 0.01, -0.1, -0.08, -0.32, -0.39],
    "Ecological - diseases": [-0.13, 0.17, -0.21, 0.08, 0.48, -0.08, -0.16, -0.46, 0.0, 0.12],
    "Ecological - ecosystem services": [-0.27, -0.34, -0.28, 0.36, -0.36, -0.09, -0.03, 0.6, 0.02, 0.26],
    "Economic": [-0.35, -0.35, -0.46, 0.06, 0.04, -0.07, -0.56, -0.56, -0.4, -0.18],
    "Technological": [-0.11, -0.29, -0.06, -0.08, -0.29, -0.27, -0.36, -0.01, -0.06, -0.44],
    "Geopolitical - terrorist attacks": [0.23, 0.39, 0.54, 0.55, 0.56, 0.62, 0.49, 0.28, -0.11, -0.34],
    "Geopolitical - conflicts": [0.37, 0.5, 0.55, 0.65, 0.65, 0.68, 0.77, 0.78, 0.67, 0.65]
}

# Convert to DataFrame
df = pd.DataFrame(data)

# Separate negative and positive "lookings" and reshape them for plotting
melted_data = []
for category in df.columns[1:]:
    melted_data.append(pd.DataFrame({
        "Values": df[df["lookings"] < 0][category],
        "Category": category,
        "Looking": "Backward\nlooking"
    }))
    melted_data.append(pd.DataFrame({
        "Values": df[df["lookings"] > 0][category],
        "Category": category,
        "Looking": "Forward\nlooking"
    }))

# Concatenate all category DataFrames
plot_df = pd.concat(melted_data, ignore_index=True)

# Define colors for each category
category_colors = {
    "Climatic": '#0072B2',
    "Economic": '#56B4E9',
    "Geophysical": '#D55E00',
    "Technological": '#CC79A7',
    "Ecological - diseases": '#009E73',
    "Geopolitical - terrorist attacks": '#E69F00',
    "Ecological - ecosystem services": '#F0E442',
    "Geopolitical - conflicts": '#000000'
}

# Define subplot positions for each category in a 2x4 layout
subplot_positions = [
    ("Climatic", 0, 0),
    ("Geophysical", 0, 1),
    ("Economic", 0, 2),
    ("Technological", 0, 3),
    ("Ecological - diseases", 1, 0),
    ("Ecological - ecosystem services", 1, 1),
    ("Geopolitical - terrorist attacks", 1, 2),
    ("Geopolitical - conflicts", 1, 3)
]

# Plotting with uniform y-axis and specific colors for each category
fig, axes = plt.subplots(2, 4, figsize=(14, 8), constrained_layout=True)
y_min, y_max = -1, 1  # Set the same y-axis limits for all subplots

for category, row, col in subplot_positions:
    ax = axes[row, col]
    # Filter data for the current category
    cat_data = plot_df[plot_df["Category"] == category]
    color = category_colors[category]
    
    # Boxplot for backward and forward lookings with specific color, using `Looking` as hue
    sns.boxplot(x="Looking", y="Values", data=cat_data, ax=ax, hue="Looking", palette=[color, color], dodge=False, 
                width=0.3, linewidth=1.5)  # Set thinner box width and adjust box line thickness
    
    # Remove legend if it exists
    if ax.get_legend():
        ax.get_legend().remove()
    
    # Add horizontal line at y=0
    ax.axhline(0, color='gray', linestyle='--', linewidth=1)
    
    ax.set_title(category, color=color)
    ax.set_ylabel("Correlation")
    ax.set_ylim(y_min, y_max)  # Set the y-axis limits for consistency across subplots
    ax.set_xlabel("")  # Remove x-axis label

# Save the figure as a high-quality image (300 DPI)
plt.savefig("Correlations_boxplot.png", dpi=1000)

plt.show()
