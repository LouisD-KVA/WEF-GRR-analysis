import numpy as np
import matplotlib.pyplot as plt

# Define the data
data = np.array([
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
# Calculate mean and standard deviation for each row
mean_vals = data.mean(axis=1, keepdims=True)
std_vals = data.std(axis=1, keepdims=True)

# Normalize the data using Z-score
data_normalized = (data - mean_vals) / std_vals

# Scale the data to the range [0, 1]
data_min = data_normalized.min()
data_max = data_normalized.max()
data_scaled = (data_normalized - data_min) / (data_max - data_min)

# Create a square figure
plt.figure(figsize=(8, 8))

# Create a heatmap using the 'Blues' colormap
plt.imshow(data_scaled, cmap='Blues', aspect='auto', vmin=0, vmax=1)
plt.colorbar(label='Normalized (Z-Score method) Proportion of words')
plt.xlabel('Sustainability spectrum')
plt.ylabel('Years')
plt.xticks(np.arange(5), ['1. Compliance', '2. Business-Centered',
           '3. Systemic', '4. Regenerative', '5. Coevolutionary'])
plt.yticks(np.arange(19), np.arange(2006, 2025))
plt.show()
