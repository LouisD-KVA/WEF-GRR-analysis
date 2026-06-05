# Import necessary libraries
import numpy as np
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from scipy.spatial.distance import pdist, squareform
from tabulate import tabulate  # For pretty-printing the DataFrame

# Define the categories and report names
categories = ["Positive\nwords", "Negative\nwords", "Uncertain\nwords",
              "Litigious\nwords", "Constraining\nwords", "Readability\nindex"]

names = ["WEF", "WMO", "BIS", "IMF", "FAO", "UNWWDR", "UNCTAD", "WIPO", "UNHCR"]

# Mean values for each linguistic criterion for all reports
mean_values = [
    [0.275190165, 0.105635829, 0.246361499, 0.195009096, 0.315539931,
     0.375564686, 0.621030179, 0.620604976, 0.368387962],  # Positive words
    [0.711857208, 0.300490948, 0.308482968, 0.336202966, 0.354393232,
     0.215423825, 0.082735449, 0.076684495, 0.293914863],  # Negative words
    [0.64149093, 0.120235665, 0.295918499, 0.232356571, 0.121539133,
     0.097175014, 0.061963727, 0.100177298, 0.025712961],  # Uncertain words
    [0.458280272, 0.03595909, 0.626807901, 0.191941586, 0.150332382,
     0.432383253, 0.198928676, 0.442081276, 0.600210087],  # Litigious words
    [0.503096212, 0.130745871, 0.743382155, 0.416887329, 0.601058152,
     0.654947925, 0.542445174, 0.357210732, 0.792500525],  # Constraining words
    [0.527189137, 0.326554438, 0.260702638, 0.09370736, 0.16767305,
     0.329969695, 0.325429249, 0.278712337, 0.740480778]   # Readability index
]

# Transpose the mean_values to align data correctly
data = np.array(mean_values).T  # Shape will be (9 reports, 6 criteria)

# Calculate the Euclidean distances between each pair of reports
distances = pdist(data, metric='euclidean')
distance_matrix = squareform(distances)

# Create a DataFrame for better readability
distance_df = pd.DataFrame(distance_matrix, index=names, columns=names)

# Compute the mean distances excluding self (diagonal elements)
distance_df_no_diag = distance_df.copy()
np.fill_diagonal(distance_df_no_diag.values, np.nan)
mean_distances = distance_df_no_diag.mean(axis=1)

# Add mean distances as a new column to the DataFrame
distance_df['Mean Distance'] = mean_distances

# Adjust the names list to include 'Mean Distance' as a column label
names_plus_mean = names + ['Mean Distance']

# Create mask for the lower triangle and diagonal of the distance matrix
mask_distance = np.tril(np.ones((len(names), len(names))), k=0).astype(bool)

# Create mask for the 'Mean Distance' column (all False)
mask_mean = np.zeros((len(names), 1), dtype=bool)

# Combine the masks
mask = np.hstack((mask_distance, mask_mean))

# Plot the heatmap with the mask
plt.figure(figsize=(12, 8))
sns.heatmap(distance_df, annot=True, fmt=".3f", cmap='cividis',
            xticklabels=names_plus_mean, yticklabels=names, annot_kws={"color": "black"},
            cbar_kws={'label': 'Euclidean Distance'}, mask=mask)

plt.xticks(rotation=45, ha='right')
plt.yticks(rotation=0)
plt.tight_layout()

# Save the figure as a high-quality image (1000 DPI)
plt.savefig("Euclidean_distances_with_mean.png", dpi=1000)

plt.show()

# **Add these lines to print the distance matrix with mean distances**

# Round the DataFrame for better readability
distance_df_rounded = distance_df.round(3)

# Print the distance matrix using tabulate for a formatted table
print("\nDistance Matrix with Mean Distances:")
print(tabulate(distance_df_rounded, headers='keys', tablefmt='pretty'))