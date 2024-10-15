import numpy as np
import matplotlib.pyplot as plt

# Define the data
data = np.array([
    [1514, 1339, 463, 515, 106, 378, 463, 48, 300, 248, 1422, 1360, 0, 316],
    [2141, 2104, 1000, 260, 250, 362, 890, 0, 137, 144, 1390, 1951, 50, 229],
    [911, 982, 468, 387, 328, 163, 364, 0, 190, 135, 531, 853, 0, 219],
    [673, 1001, 98, 42, 633, 45, 98, 0, 52, 186, 688, 606, 221, 279],
    [1097, 968, 613, 74, 248, 116, 481, 0, 105, 84, 634, 1059, 77, 135],
    [588, 588, 337, 130, 71, 171, 337, 0, 102, 30, 413, 416, 31, 81],
    [554, 469, 122, 99, 35, 27, 122, 0, 0, 34, 371, 487, 28, 66],
    [363, 738, 112, 99, 0, 142, 112, 0, 282, 0, 477, 275, 0, 121],
    [1811, 1769, 490, 283, 110, 218, 490, 0, 66, 59, 1230, 1605, 0, 280],
    [704, 647, 248, 308, 34, 262, 248, 0, 90, 31, 462, 570, 29, 106],
    [649, 671, 164, 188, 0, 100, 164, 0, 50, 42, 490, 581, 160, 107],
    [928, 497, 322, 41, 63, 206, 267, 0, 0, 104, 239, 415, 37, 193],
    [336, 537, 167, 137, 35, 128, 140, 0, 88, 35, 316, 230, 67, 80],
    [602, 777, 188, 93, 0, 73, 188, 0, 17, 0, 540, 602, 0, 30],
    [590, 665, 93, 64, 100, 174, 68, 0, 21, 0, 428, 516, 25, 24],
    [439, 529, 168, 73, 28, 94, 168, 0, 0, 0, 311, 404, 0, 0],
    [664, 569, 79, 40, 41, 132, 79, 21, 0, 0, 507, 640, 0, 0],
    [149, 145, 52, 31, 13, 68, 39, 18, 0, 0, 100, 139, 0, 0],
    [219, 280, 89, 45, 69, 70, 89, 34, 0, 13, 167, 192, 0, 13]
])

# Calculate the mean and standard deviation for each row
mean_vals = data.mean(axis=1, keepdims=True)
std_vals = data.std(axis=1, keepdims=True)

# Normalize the data (Z-score normalization)
data_normalized = (data - mean_vals) / std_vals

# Scale the data to the range [0, 1]
data_min = data_normalized.min()
data_max = data_normalized.max()
data_scaled = (data_normalized - data_min) / (data_max - data_min)


# Create a heatmap
plt.figure(figsize=(12, 8))
plt.imshow(data_scaled, cmap='Blues', aspect='auto', vmin=0, vmax=1)
plt.colorbar(label='Normalized (with Z-SCORE method) Proportion of Words')
plt.xlabel('Anthropocene Traps')
plt.ylabel('Years')

# Adjust ticks to match the provided labels
years = list(range(2006, 2025))
traps = [
    "1. Simplification", "2. Growth-for-Growth", "3. Overshoot", "4. Division", "5. Contagion",
    "6. Infrastructure lock-in", "7. Chemical pollution", "8. Existential technology",
    "9. Technological autonomy", "10. Dis- and misinformation", "11. Short-termism",
    "12. Overconsumption", "13. Biosphere disconnect", "14. Local social capital loss"
]

plt.xticks(np.arange(len(traps)), traps, rotation=90)
plt.yticks(np.arange(len(years)), years)

plt.tight_layout()
plt.show()
