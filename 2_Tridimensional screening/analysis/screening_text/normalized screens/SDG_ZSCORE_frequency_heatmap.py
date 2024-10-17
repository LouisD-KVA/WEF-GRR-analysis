import numpy as np
import matplotlib.pyplot as plt


# Define the data
data = np.array([
    [174, 105, 174, 316, 174, 0, 223, 1338, 454,
        228, 0, 0, 463, 291, 343, 956, 337],
    [288, 373, 335, 149, 149, 211, 403, 1596, 407,
        288, 139, 174, 702, 449, 449, 619, 599],
    [208, 56, 412, 126, 126, 56, 225, 615, 417,
        298, 58, 180, 602, 154, 154, 631, 223],
    [138, 130, 726, 359, 138, 130, 0, 784, 224, 207, 31, 0, 129, 31, 31, 363, 234],
    [82, 211, 299, 82, 82, 200, 102, 685, 196, 82, 0, 55, 466, 274, 274, 223, 265],
    [51, 172, 153, 51, 51, 127, 0, 337, 177, 51, 128, 0, 251, 40, 40, 179, 144],
    [32, 35, 98, 94, 32, 60, 0, 380, 67, 32, 40, 0, 137, 56, 56, 203, 192],
    [179, 0, 179, 179, 179, 41, 54, 626, 370, 209, 0, 0, 71, 0, 0, 378, 111],
    [221, 252, 331, 221, 221, 244, 91, 1394, 331,
        221, 79, 0, 435, 135, 135, 695, 295],
    [75, 30, 109, 75, 75, 97, 0, 503, 284, 75, 230, 0, 202, 63, 63, 425, 259],
    [65, 0, 65, 225, 65, 55, 67, 555, 160, 65, 35, 0, 199, 106, 106, 312, 219],
    [89, 128, 358, 89, 89, 177, 159, 356, 411, 89, 195, 42, 510, 66, 66, 235, 100],
    [80, 39, 80, 80, 80, 60, 142, 421, 127, 100, 0, 82, 157, 36, 36, 313, 193],
    [30, 73, 30, 30, 30, 104, 129, 518, 34, 63, 0, 56, 45, 17, 47, 243, 265],
    [24, 116, 124, 24, 24, 91, 105, 497, 115, 24, 0, 0, 36, 25, 25, 190, 208],
    [0, 30, 28, 0, 0, 61, 90, 311, 35, 0, 0, 31, 78, 36, 49, 124, 177],
    [0, 114, 41, 0, 0, 80, 132, 552, 44, 0, 0, 19, 59, 31, 31, 87, 214],
    [0, 10, 13, 0, 0, 0, 81, 110, 10, 0, 0, 13, 52, 12, 12, 76, 53],
    [13, 25, 69, 13, 13, 15, 53, 177, 27, 13, 0, 13, 76, 20, 20, 114, 36]
])


# calcule la moyenne pour chaque ligne de data
mean_vals = data.mean(axis=1, keepdims=True)
print(mean_vals)
std_vals = data.std(axis=1, keepdims=True)
print(std_vals)
data_normalized = (data - mean_vals) / std_vals
print(data_normalized)

# Scale the data to the range [0, 1]
data_min = data_normalized.min()
data_max = data_normalized.max()
data_scaled = (data_normalized - data_min) / (data_max - data_min)

# Define the SDG names
sdg_names = [
    "1. No Poverty", "2. Zero Hunger", "3. Good Health", "4. Quality Education",
    "5. Gender Equality", "6. Clean Water", "7. Affordable Energy", "8. Decent Work",
    "9. Industry & Innovation", "10. Reduced Inequalities", "11. Sustainable Cities",
    "12. Responsible Consumption", "13. Climate Action", "14. Life Below Water",
    "15. Life on Land", "16. Peace & Justice", "17. Partnerships"
]
plt.figure(figsize=(16, 10))  # Augmenter la taille de la figure
plt.imshow(data_scaled, cmap='Blues', aspect='auto', vmin=0, vmax=1)
plt.colorbar(label='Normalized (Z-score method) Proportion of words')
plt.xlabel('SDGs')
plt.ylabel('Years')
plt.xticks(np.arange(17), sdg_names, rotation=30, ha='right', fontsize=7)
# Augmenter la taille de la police des années
plt.yticks(np.arange(19), np.arange(2006, 2025), fontsize=10)
plt.tight_layout()  # Ajustement automatique du placement des éléments dans la figure
plt.show()

# Normalisation z-score : Soustrayez la moyenne de chaque ligne et divisez par l'écart-type. Cela mettra en évidence les écarts par rapport à la moyenne dans chaque ligne.
# La normalisation Z-score est effectuée sur chaque ligne, ce qui signifie que les valeurs sont centrées autour de la moyenne de chaque ligne et échelonnées en fonction de l'écart-type de chaque ligne. Cela permet de comparer les valeurs de chaque année (ligne) par rapport à la moyenne et à la variabilité de cette année-là.
