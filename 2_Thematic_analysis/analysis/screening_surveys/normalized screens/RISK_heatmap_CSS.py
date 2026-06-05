import numpy as np
import matplotlib.pyplot as plt


data = np.array([
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

# The years including 2011 and excluding 2022
years = np.array([2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013,
                 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2023, 2024])


# Calculer la moyenne et l'écart type pour chaque ligne
mean_vals = data.mean(axis=1, keepdims=True)
std_vals = data.std(axis=1, keepdims=True)

# Normaliser les données
data_normalized = (data - mean_vals) / std_vals

# Scale the data to the range [0, 1]
data_min = data_normalized.min()
data_max = data_normalized.max()
data_scaled = (data_normalized - data_min) / (data_max - data_min)

# Define the Spectrum names
ss_names = [
    '1. Compliance', '2. Business-Centered',
    '3. Systemic', '4. Regenerative', '5. Coevolutionary'
]

plt.figure(figsize=(12, 8))  # Augmenter la taille de la figure
plt.imshow(data_scaled, cmap='Blues', aspect='auto', vmin=0, vmax=1)
plt.colorbar(label='Normalized (Z-score method) Proportion of words')
plt.xlabel('Sustainability Spectrum')
plt.ylabel('Years')
# Rotation et ajustement de la taille des étiquettes
plt.xticks(np.arange(5), ss_names, rotation=40, ha='right', fontsize=8)
# Ajustement de la taille des étiquettes
plt.yticks(np.arange(18), years, fontsize=8)
plt.tight_layout()  # Ajustement automatique du placement des éléments dans la figure
plt.show()
