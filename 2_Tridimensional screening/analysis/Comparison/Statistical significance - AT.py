import pandas as pd
import matplotlib.pyplot as plt
from scipy.stats import ttest_rel, wilcoxon

# Data for Survey-based screens
survey_data = {
    "Year": [2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2023, 2024],
    1: [0.74, 0.82, 0.76, 0.81, 0.85, 0.85, 0.88, 0.88, 0.94, 0.91, 0.91, 0.89, 0.90, 0.90, 0.89, 0.91, 0.84, 0.89],
    2: [0.95, 0.86, 0.88, 0.93, 0.91, 0.83, 0.78, 0.77, 0.77, 0.79, 0.80, 0.83, 0.81, 0.81, 0.86, 0.87, 1.00, 0.93],
    3: [0.43, 0.34, 0.37, 0.37, 0.34, 0.48, 0.58, 0.59, 0.46, 0.46, 0.44, 0.44, 0.46, 0.47, 0.47, 0.57, 0.49, 0.51],
    4: [0.63, 0.51, 0.52, 0.56, 0.54, 0.49, 0.46, 0.46, 0.53, 0.66, 0.62, 0.67, 0.66, 0.65, 0.63, 0.55, 0.59, 0.45],
    5: [0.26, 0.28, 0.26, 0.25, 0.24, 0.16, 0.14, 0.13, 0.13, 0.09, 0.10, 0.10, 0.09, 0.09, 0.09, 0.09, 0.24, 0.15],
    6: [0.14, 0.26, 0.21, 0.21, 0.23, 0.20, 0.26, 0.25, 0.24, 0.28, 0.27, 0.26, 0.26, 0.27, 0.26, 0.14, 0.24, 0.29],
    7: [0.43, 0.34, 0.37, 0.34, 0.34, 0.38, 0.48, 0.49, 0.40, 0.39, 0.37, 0.38, 0.40, 0.40, 0.40, 0.47, 0.29, 0.42],
    8: [0.10, 0.17, 0.13, 0.14, 0.14, 0.19, 0.14, 0.15, 0.14, 0.16, 0.16, 0.16, 0.16, 0.15, 0.14, 0.06, 0.06, 0.06],
    9: [0.22, 0.08, 0.08, 0.15, 0.15, 0.14, 0.17, 0.17, 0.16, 0.23, 0.22, 0.22, 0.23, 0.23, 0.23, 0.15, 0.08, 0.32],
    10: [0.02, 0.03, 0.03, 0.08, 0.09, 0.07, 0.06, 0.06, 0.03, 0.02, 0.04, 0.04, 0.03, 0.03, 0.04, 0.08, 0.24, 0.09],
    11: [0.66, 0.72, 0.68, 0.71, 0.70, 0.73, 0.64, 0.63, 0.65, 0.50, 0.53, 0.50, 0.48, 0.48, 0.47, 0.47, 0.57, 0.56],
    12: [0.67, 0.79, 0.84, 0.73, 0.73, 0.77, 0.76, 0.76, 0.77, 0.78, 0.80, 0.78, 0.78, 0.78, 0.77, 0.69, 0.60, 0.67],
    13: [0.19, 0.24, 0.32, 0.11, 0.11, 0.11, 0.07, 0.07, 0.16, 0.09, 0.10, 0.10, 0.10, 0.10, 0.11, 0.16, 0.00, 0.02],
    14: [0.02, 0.03, 0.03, 0.08, 0.09, 0.07, 0.06, 0.06, 0.09, 0.09, 0.10, 0.10, 0.09, 0.09, 0.10, 0.25, 0.24, 0.09],
}

# Data for Text-based screens
text_data = {
    "Year": [2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2023, 2024],
    1: [0.73, 0.74, 0.71, 0.58, 0.74, 0.74, 0.78, 0.51, 0.75, 0.76, 0.73, 1.00, 0.60, 0.65, 0.72, 0.69, 0.73, 0.67],
    2: [0.64, 0.72, 0.77, 0.83, 0.66, 0.74, 0.68, 0.95, 0.74, 0.70, 0.75, 0.57, 0.95, 0.81, 0.80, 0.81, 0.71, 0.84],
    3: [0.24, 0.38, 0.37, 0.13, 0.44, 0.43, 0.25, 0.21, 0.27, 0.29, 0.23, 0.39, 0.31, 0.28, 0.20, 0.32, 0.30, 0.30],
    4: [0.27, 0.15, 0.30, 0.08, 0.10, 0.18, 0.22, 0.20, 0.19, 0.35, 0.25, 0.11, 0.26, 0.19, 0.17, 0.19, 0.21, 0.18],
    5: [0.08, 0.14, 0.26, 0.54, 0.21, 0.11, 0.14, 0.08, 0.13, 0.07, 0.06, 0.13, 0.09, 0.11, 0.21, 0.13, 0.13, 0.24],
    6: [0.20, 0.18, 0.13, 0.09, 0.13, 0.23, 0.13, 0.25, 0.17, 0.30, 0.16, 0.28, 0.25, 0.17, 0.28, 0.22, 0.37, 0.25],
    7: [0.24, 0.34, 0.28, 0.13, 0.36, 0.43, 0.25, 0.21, 0.27, 0.29, 0.23, 0.34, 0.27, 0.28, 0.17, 0.32, 0.24, 0.30],
    8: [0.05, 0.06, 0.00, 0.05, 0.05, 0.02, 0.09, 0.08, 0.09, 0.03, 0.06, 0.07, 0.03, 0.11, 0.10, 0.09, 0.15, 0.15],
    9: [0.17, 0.11, 0.15, 0.09, 0.12, 0.15, 0.09, 0.41, 0.11, 0.12, 0.11, 0.07, 0.18, 0.12, 0.12, 0.09, 0.07, 0.05],
    10: [0.14, 0.11, 0.11, 0.20, 0.11, 0.06, 0.14, 0.08, 0.11, 0.06, 0.10, 0.18, 0.09, 0.11, 0.10, 0.09, 0.07, 0.09],
    11: [0.68, 0.50, 0.41, 0.59, 0.45, 0.52, 0.56, 0.64, 0.54, 0.51, 0.57, 0.31, 0.57, 0.60, 0.55, 0.51, 0.51, 0.52],
    12: [0.65, 0.68, 0.67, 0.52, 0.72, 0.53, 0.70, 0.40, 0.68, 0.62, 0.66, 0.49, 0.42, 0.65, 0.64, 0.64, 0.69, 0.59],
    13: [0.03, 0.08, 0.00, 0.22, 0.10, 0.06, 0.13, 0.08, 0.09, 0.06, 0.23, 0.11, 0.14, 0.11, 0.13, 0.09, 0.07, 0.05],
    14: [0.18, 0.14, 0.17, 0.27, 0.14, 0.12, 0.18, 0.22, 0.19, 0.14, 0.17, 0.26, 0.16, 0.14, 0.13, 0.09, 0.07, 0.09],
}

# Convert dictionaries to DataFrames
survey_df = pd.DataFrame(survey_data)
text_df = pd.DataFrame(text_data)

# Align data by dropping the extra year (2022) from text_df
text_df = text_df[text_df["Year"].isin(survey_df["Year"])]

# Perform paired t-test or Wilcoxon signed-rank test
results = []
for col in survey_df.columns[1:]:  # Skip the "Year" column
    survey_col = survey_df[col]
    text_col = text_df[col]

    # Perform paired t-test
    t_stat, t_pvalue = ttest_rel(survey_col, text_col)
    # Perform Wilcoxon signed-rank test
    w_stat, w_pvalue = wilcoxon(survey_col, text_col)

    results.append((col, t_pvalue, w_pvalue))

# Generate a DataFrame for results
results_df = pd.DataFrame(results, columns=["Column", "t-pvalue", "Wilcoxon-pvalue"])

# Add interpretation
results_df["Interpretation"] = results_df.apply(
    lambda row: "Significant in both tests" if row["t-pvalue"] < 0.05 and row["Wilcoxon-pvalue"] < 0.05
    else "Significant in t-test only" if row["t-pvalue"] < 0.05
    else "Significant in Wilcoxon only" if row["Wilcoxon-pvalue"] < 0.05
    else "No significant difference",
    axis=1,
)

# Plot results
fig, ax = plt.subplots(figsize=(10, 6))
x = results_df["Column"]
width = 0.4

ax.bar(x - width / 2, results_df["t-pvalue"], width, label="t-test p-value", color="blue")
ax.bar(x + width / 2, results_df["Wilcoxon-pvalue"], width, label="Wilcoxon p-value", color="orange")

# Add significance threshold line
ax.axhline(0.05, color="red", linestyle="--", label="Significance threshold (p=0.05)")

# Add labels and legend
ax.set_xlabel("Anthropocene Traps")
ax.set_ylabel("p-value")
ax.set_title("p-values for t-test and Wilcoxon signed-rank test")
ax.legend()
plt.xticks(x)
plt.ylim(0, 1)

# Show plot
plt.tight_layout()
plt.savefig("Statistical significance - AT", dpi=1000)
plt.show()

# Print results with interpretations
print(results_df)