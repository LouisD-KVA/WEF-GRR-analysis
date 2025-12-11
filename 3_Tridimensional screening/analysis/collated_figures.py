import matplotlib.pyplot as plt
import matplotlib.image as mpimg
from subprocess import run

# Step 1: Execute each script to generate and save figures
scripts = ["SDG.py", "AT.py", "CSS.py"]

for script in scripts:
    run(["python", script])  # Runs each script to generate figures

# Step 2: Load saved images
images = ["SDG.png", "AT.png", "CSS.png"]
fig, axs = plt.subplots(len(images), 1, figsize=(10, 15))  # Adjust size as needed

for ax, img_path in zip(axs, images):
    img = mpimg.imread(img_path)
    ax.imshow(img)
    ax.axis("off")  # Turn off axes for better display

plt.tight_layout()
plt.savefig("collated_figures.png", dpi=1000)  # Save the combined image
plt.show()
