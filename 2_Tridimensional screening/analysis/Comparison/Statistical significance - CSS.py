import pandas as pd
import matplotlib.pyplot as plt
from scipy.stats import ttest_rel, wilcoxon

# Data for Survey-based screens
survey_data = {
    "Year": [2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2023, 2024],
    1: [0.06, 0.03, 0.02, 0.06, 0.06, 0.05, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.01, 0.04, 0.02, 0.02],
    2: [0.72, 0.71, 0.73, 0.82, 0.83, 0.78, 0.81, 0.80, 0.78, 0.80, 0.83, 0.79, 0.79, 0.80, 0.80, 0.47, 0.71, 0.89],
    3: [0.92, 0.92, 0.88, 0.84, 0.82, 0.86, 0.83, 0.83, 0.86, 0.84, 0.81, 0.84, 0.84, 0.83, 0.83, 1.00, 0.91, 0.74],
    4: [0.40, 0.42, 0.46, 0.38, 0.38, 0.41, 0.43, 0.43, 0.43, 0.43, 0.42, 0.42, 0.44, 0.44, 0.45, 0.54, 0.44, 0.43],
    5: [0.01, 0.03, 0.02, 0.00, 0.00, 0.00, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.01, 0.04, 0.02, 0.02],
}

# Data for Text-based screens
text_data = {
    "Year": [2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024],
    1: [0.18, 0.13, 0.13, 0.21, 0.13, 0.13, 0.20, 0.22, 0.12, 0.12, 0.10, 0.00, 0.15, 0.15, 0.19, 0.13, 0.24, 0.20, 0.16],
    2: [0.97, 0.86, 0.67, 0.69, 0.83, 0.76, 0.99, 0.97, 0.88, 0.78, 0.82, 0.86, 0.87, 0.92, 0.95, 0.89, 1.00, 0.77, 0.73],
    3: [0.52, 0.56, 0.87, 0.91, 0.51, 0.74, 0.53, 0.58, 0.68, 0.82, 0.74, 0.54, 0.63, 0.56, 0.58, 0.50, 0.43, 0.48, 0.82],
    4: [0.43, 0.61, 0.48, 0.26, 0.70, 0.55, 0.35, 0.34, 0.44, 0.38, 0.46, 0.59, 0.52, 0.50, 0.40, 0.63, 0.44, 0.77, 0.48],
    5: [0.16, 0.10, 0.13, 0.19, 0.10, 0.09, 0.20, 0.17, 0.16, 0.17, 0.15, 0.28, 0.10, 0.13, 0.15, 0.13, 0.16, 0.05, 0.08],
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
ax.set_xlabel("Corporate Sustainability Spectrums")
ax.set_ylabel("p-value")
ax.set_title("p-values for t-test and Wilcoxon signed-rank test")
ax.legend()
plt.xticks(x)
plt.ylim(0, 1)

# Show plot
plt.tight_layout()
plt.savefig("Statistical significance - CSS", dpi=1000)
plt.show()

# Print results with interpretations
print(results_df)