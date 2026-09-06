import numpy as np
import os

NUM_IMAGES = 100
TSTEPS = 20

def main():
    if not os.path.exists("test_spikes.npy") or not os.path.exists("test_labels.npy"):
        print("Error: Dataset files not found.")
        return

    spikes = np.load("test_spikes.npy")
    labels = np.load("test_labels.npy")

    print(f"Extracting {NUM_IMAGES} images for FPGA on-chip ROM...")

    # 1. Generate Spikes ROM (.mem) - 2000 lines total (100 * 20)
    with open("demo_spikes.mem", "w") as f:
        for i in range(NUM_IMAGES):
            for t in range(TSTEPS):
                ts_bits = spikes[i, t]
                hex_str = np.packbits(ts_bits[::-1], bitorder='big').tobytes().hex()
                f.write(f"{hex_str}\n")

    # 2. Generate Labels ROM (.mem) - 100 lines total
    with open("demo_labels.mem", "w") as f:
        for i in range(NUM_IMAGES):
            label = int(labels[i])
            f.write(f"{label:01x}\n")

    print("Success: Created demo_spikes.mem and demo_labels.mem for 100 images")

if __name__ == '__main__':
    main()