import os
import shutil
import torch
import numpy as np
import snntorch as snn
from model import QuantizedNet
from dataset import get_dataloaders

def export_weights_banked_interleaved(weight_tensor, prefix, out_dir, num_bits=8, num_banks=8):
    """Exports 8-bit quantized weights into interleaved .mem files for FPGA BRAM."""
    scale = weight_tensor.detach().abs().max() / (2**(num_bits-1) - 1)
    w_int = torch.clamp(
        torch.round(weight_tensor.detach() / scale),
        -(2**(num_bits-1)),
        (2**(num_bits-1) - 1)
    ).to(torch.int8).cpu().numpy()

    for bank in range(num_banks):
        bank_rows = w_int[bank::num_banks, :]
        with open(f"{out_dir}/{prefix}_bank{bank}.mem", 'w') as f:
            for val in bank_rows.flatten():
                f.write(f'{int(val) & 0xFF:02X}\n')

    print(f"Exported {prefix}: {w_int.shape} -> {num_banks} banks (INTERLEAVED) in {out_dir}/")

def calculate_hardware_thresholds(model, layer1_name='fc1', layer2_name='fc2', pt_thresh=0.5):
    """Calculates hardware thresholds based on PyTorch threshold and quantization scale."""
    w1 = getattr(model, layer1_name).weight
    w2 = getattr(model, layer2_name).weight
    
    scale1 = (w1.detach().abs().max() / 127).item()
    scale2 = (w2.detach().abs().max() / 127).item()

    l1_thresh = round(pt_thresh / scale1)
    l2_thresh = round(pt_thresh / scale2)

    print(f"parameter integer L1_THRESHOLD = {l1_thresh};")
    print(f"parameter integer L2_THRESHOLD = {l2_thresh};")

def export_event_driven_data(dataset, device, out_dir="mem_event", num_steps=20):
    """Exports event counts, indices, and labels for hardware simulations."""
    os.makedirs(out_dir, exist_ok=True)
    num_images = len(dataset)
    print(f"Exporting {num_images} images to hardware-friendly .mem files...")

    with open(f'{out_dir}/event_counts.mem', 'w') as f_counts, \
         open(f'{out_dir}/event_indices.mem', 'w') as f_indices, \
         open(f'{out_dir}/test_labels.mem', 'w') as f_labels:

        for img_idx in range(num_images):
            image, label = dataset[img_idx]

            spike_train = snn.spikegen.rate(
                image.flatten().unsqueeze(0).to(device),
                num_steps=num_steps, 
                gain=2.0
            ).to(device)

            for t in range(num_steps):
                spike_vec = spike_train[t].squeeze()
                active_indices = torch.nonzero(spike_vec).flatten().tolist()
                
                f_counts.write(f"{len(active_indices):02X}\n")
                for idx in active_indices:
                    f_indices.write(f"{idx:03X}\n")

            f_labels.write(f'{label:01X}\n')
    print(f"Done! Event data saved in {out_dir}/")

def main():
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    
    # 1. Initialize network and load best weights
    num_inputs, num_hidden, num_outputs, num_steps = 784, 128, 10, 20
    net = QuantizedNet(num_inputs, num_hidden, num_outputs, beta=0.875, num_steps=num_steps, threshold=0.5, weight_bits=8)
    
    try:
        net.load_state_dict(torch.load("best_lif_model.pth", map_location=device, weights_only=True))
        print("Loaded best_lif_model.pth successfully.")
    except Exception as e:
        print(f"Warning: Could not load weights. {e}")
        
    net.eval()

    # 2. Hardware Thresholds
    print("LIF Hardware Thresholds")
    calculate_hardware_thresholds(net)

    # 3. Export Weights
    os.makedirs("mem_lif", exist_ok=True)
    export_weights_banked_interleaved(net.fc1.weight, "fc1_weights", "mem_lif")
    export_weights_banked_interleaved(net.fc2.weight, "fc2_weights", "mem_lif")
    shutil.make_archive("mem_files_lif", "zip", "mem_lif")

    # 4. Export Event Data
    _, _, _, test_dataset = get_dataloaders()
    export_event_driven_data(test_dataset, device, num_steps=num_steps)

if __name__ == "__main__":
    main()