import time
import torch
import matplotlib.pyplot as plt
import snntorch as snn

def accuracy_score(outputs, labels):
    """Calculates accuracy given output rates and labels."""
    _, predicted = outputs.max(1)
    correct = (predicted == labels).sum().item()
    return correct / labels.size(0)

def benchmark_software_inference(model, model_name, data_loader, device, num_inputs=784, num_steps=20):
    """Benchmarks inference throughput and latency to compare against FPGA metrics."""
    print(f"       SOFTWARE INFERENCE BENCHMARK: {model_name}")
    
    model.eval()
    correct = 0
    total = 0
    
    with torch.no_grad():
        start_time = time.time()
        
        for images, labels in data_loader:
            images = images.view(-1, num_inputs).to(device)
            labels = labels.to(device)
            
            spike_input = snn.spikegen.rate(images, num_steps=num_steps, gain=2.0)
            spk_rec, _ = model(spike_input)
            
            output_rates = spk_rec.sum(dim=0)
            _, predicted = output_rates.max(1)
            
            total += labels.size(0)
            correct += (predicted == labels).sum().item()
            
        end_time = time.time()
        
    total_time_sec = end_time - start_time
    avg_latency_ms = (total_time_sec / total) * 1000 
    fps_estimate   = total / total_time_sec
    accuracy       = (correct / total) * 100
    
    print(f"Total Images Tested    : {total}")
    print(f"Total Correct          : {correct}")
    print(f"Classification Accuracy: {accuracy:.2f}%")
    print(f"Total Software Time    : {total_time_sec:.4f} sec")
    print(f"Avg Latency Per Image  : {avg_latency_ms:.2f} ms")
    print(f"Throughput Estimate    : {fps_estimate:.0f} FPS")

def plot_training_results(loss_hist, train_acc_hist, val_acc_hist, model_name="LIF"):
    """Plots the loss and accuracy curves for a given training run."""
    plt.figure(figsize=(15, 5))

    # Plot Loss
    plt.subplot(1, 2, 1)
    plt.plot(loss_hist, label=f"{model_name} Training Loss", color="red")
    plt.title(f'{model_name} Model Training Loss per Epoch')
    plt.xlabel('Epoch')
    plt.ylabel('Loss')
    plt.legend()

    # Plot Accuracies
    plt.subplot(1, 2, 2)
    plt.plot(train_acc_hist, label=f"{model_name} Train Accuracy", color="blue")
    plt.plot(val_acc_hist, label=f"{model_name} Validation Accuracy", color="orange")
    plt.title(f'{model_name} Model Accuracy per Epoch')
    plt.xlabel('Epoch')
    plt.ylabel('Accuracy')
    plt.legend()

    plt.tight_layout()
    plt.show()

def plot_model_comparison(val_acc_hist_1, val_acc_hist_2, label1="LIF", label2="IF"):
    """Plots a side-by-side validation accuracy comparison between two models."""
    plt.figure(figsize=(15, 5))
    plt.plot(val_acc_hist_1, label=f"{label1} Validation Accuracy", color="purple", linestyle='--')
    plt.plot(val_acc_hist_2, label=f"{label2} Validation Accuracy", color="green", linestyle='-')
    plt.title(f'Validation Accuracy: {label1} vs. {label2} Model')
    plt.xlabel('Epoch')
    plt.ylabel('Validation Accuracy')
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    plt.show()