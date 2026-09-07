# 8-bit Event-Driven Spiking Neural Network (SNN) FPGA Accelerator

This repository contains an 8-bit event-driven Spiking Neural Network (SNN) accelerator implemented in Verilog and deployed on an Intel DE1-SoC FPGA. The design utilizes event-driven sparsity to reduce unnecessary computations on inactive spikes, significantly improving latency while maintaining software-level classification accuracy.

This project was developed at Lab for Computing Research and Innovation (LCRAIN) under the supervision of Prof. Amirali Amirsoleimani.

## Objective
Conventional processors are only optimized for dense computation, which is inefficient for sparse spiking workloads. The objective of this project is to design a hardware-efficient, low-precision SNN accelerator for image classification (MNIST) that preserves software-level accuracy (97.63%) while maximizing hardware throughput on an FPGA.

## Hardware Architecture (8-Way Parallel Processing)
* **Address Event Representation Encoder:** Processes the original 784-bit dense input spike vector by dividing the input into 25 chunks of 32 bits and extracting only the active spike indices and the total active count. 
* **Controller:** Manages the execution flow across the two neural network layers. It fetches the active indices from the encoder into an internal spike buffer and manages the control logic.
* **Processing Elements (PEs):** Sign-extends incoming 8-bit weights and accumulates them into an 18-bit register.
* **IF Neuron:** Adds the current PE accumulation to the historical membrane potential. If the membrane potential exceeds a certain threshold, the neuron emits a spike and performs a soft reset by subtracting the threshold value.
* **Memory:** 8 interleaved Weight BRAM banks allow simultaneous weight fetching for the 8 parallel PEs.
<img width="959" height="548" alt="{EB43D00A-1ABD-45CC-992D-A9EF4D085E0E}" src="https://github.com/user-attachments/assets/04fe3e6d-4423-4724-a9fb-6025b46d436f" />

  

## Performance
The architecture was verified in ModelSim and deployed on a DE1-SoC board using Intel Quartus Prime. 

The event-driven architecture **reduces the latency by 5.2x** compared to the time-driven approach and **by 16.3x** compared to the CPU when normalized to a 40MHz clock frequency.
### Architectural Efficiency (at 40 MHz)
| Metric | Time-driven SNN (FPGA) | Event-driven SNN (FPGA) | CPU (Software) |
| :--- | :--- | :--- | :--- |
| **Accuracy (%)** | 97.12% | 97.12% | 97.63% |
| **Avg. Cycles / Image** | 257,082 | 49,124 | 794,880 |
| **Latency / Image** | 6.427 ms | 1.228 ms | 19.87 ms (Raw: 0.36 ms) |
| **Throughput** | 156 FPS | 814 FPS | 50 FPS (Raw: 2,743 FPS) |

*Note that without the clock frequency normalization, CPU operates at 2.2GHz (approximately 50x faster than the normalized clock frequency), and its raw latency is 0.36ms, 0.29x of that of the event-driven approach. *

### Hardware Resource Utilization (Cyclone V)
The performance improvements of the event-driven design require a trade-off in resource utilization compared to a standard time-driven approach:

| Resource | Time-driven | Event-driven | Δ % |
| :--- | :--- | :--- | :--- |
| **Dedicated Logic Registers** | 3,005 | 4,453 | +48.2% |
| **Block Memory Bits** | 819,200 | 1,568,000 | +91.4% |
| **ALMs Needed** | 2,350 | 3,589 | +52.7% |

## Repository Structure
* `rtl/`: Core Verilog source files containing the FSM, PEs, IF neuron modules, and BRAM instantiations.
* `tb/`: Testbenches for ModelSim RTL verification.
* `script/`: Tcl and automation scripts for simulation and synthesis.
* `mem/`: Contains mature weights extracted from software. *(Note: Large dataset .mem and .npy files are excluded from this repository).*
* `soc_system/`: Platform Designer (Qsys) system definitions.
* `*.qpf` / `*.qsf`: Main Quartus project and settings files including pin assignments.

## Future Work
1. **External Memory Streaming:** Implement SD-card-based image streaming to bypass on-chip memory limits and evaluate the accelerator on the full 10,000-image MNIST test set.
2. **Neuromorphic Datasets:** Evaluate the accelerator on dynamic datasets (e.g., N-MNIST) to further explore the advantages of event-driven hardware and Leaky Integrate-and-Fire (LIF) models.
3. **Power Profiling:** Measure live FPGA power consumption to quantify the energy savings of event-driven sparsity.
