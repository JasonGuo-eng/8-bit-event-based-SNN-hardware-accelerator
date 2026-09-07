import torch
import numpy as np
import snntorch as snn
from snntorch import functional as SF
from torch.optim import lr_scheduler
import matplotlib.pyplot as plt

from model import QuantizedNet
from dataset import get_dataloaders

def accuracy_score(outputs, labels):
    _, predicted = outputs.max(1)
    correct = (predicted == labels).sum().item()
    return correct / labels.size(0)

def main():
    # Set seeds and device
    torch.manual_seed(42)
    torch.cuda.manual_seed(42)
    np.random.seed(42)
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"Using device: {device}")

    # Hyperparameters
    batch_size = 128
    num_epochs = 10
    learning_rate = 5e-4 
    clip_grad_norm_value = 1.0 
    
    # SNN Architecture params
    num_inputs  = 784   
    num_outputs = 10    
    num_hidden  = 128   
    num_steps   = 20    

    # Load Data
    train_loader, test_loader, train_dataset, test_dataset = get_dataloaders(batch_size=batch_size)

    # Instantiate LIF network 
    beta_lif = 0.875   
    threshold_lif = 0.5

    net_lif = QuantizedNet(
        num_inputs, num_hidden, num_outputs, beta_lif, num_steps,
        threshold=threshold_lif,
        weight_bits=8, act_bits=None, mem_bits=None
    ).to(device)

    loss_fn = SF.ce_rate_loss()
    optimizer_lif = torch.optim.Adam(net_lif.parameters(), lr=learning_rate, betas=(0.9, 0.999))
    scheduler_lif = lr_scheduler.CosineAnnealingLR(optimizer_lif, T_max=len(train_loader) * num_epochs) 

    #  Training Loop for LIF 
    best_acc_lif = 0.0 
    print("Beginning LIF Model Training...")
    
    for epoch in range(num_epochs):
        running_loss = 0
        running_correct = 0
        total_spikes = 0 

        net_lif.train() 

        for i, (images, labels) in enumerate(train_loader):
            images = images.view(-1, num_inputs).to(device)
            labels = labels.to(device)

            spike_input = snn.spikegen.rate(images, num_steps=num_steps, gain=2.0) 
            spk_rec, mem_rec = net_lif(spike_input)

            total_spikes += spk_rec.sum().item()
            loss = loss_fn(spk_rec, labels)

            optimizer_lif.zero_grad()
            loss.backward()
            torch.nn.utils.clip_grad_norm_(net_lif.parameters(), clip_grad_norm_value)
            optimizer_lif.step()
            scheduler_lif.step() 

            running_loss += loss.item()
            output_rates = spk_rec.sum(dim=0)
            running_correct += accuracy_score(output_rates, labels) * labels.size(0)

        avg_loss = running_loss / len(train_loader)
        train_acc = running_correct / len(train_dataset) 
        avg_spikes_per_image = total_spikes / len(train_dataset)

        net_lif.eval() 
        val_correct = 0
        with torch.no_grad():
            for images, labels in test_loader:
                images = images.view(-1, num_inputs).to(device)
                labels = labels.to(device)

                spike_input = snn.spikegen.rate(images, num_steps=num_steps, gain=2.0) 
                spk_rec, mem_rec = net_lif(spike_input)

                output_rates = spk_rec.sum(dim=0)
                _, predicted = output_rates.max(1)
                val_correct += (predicted == labels).sum().item()

        val_acc = val_correct / len(test_dataset)
        print(f"Epoch {epoch+1}/{num_epochs} | Loss: {avg_loss:.4f} | Train Acc: {train_acc:.4f} | Val Acc: {val_acc:.4f} | Avg Spikes/Img: {avg_spikes_per_image:.1f}")

        if val_acc > best_acc_lif:
            best_acc_lif = val_acc
            torch.save(net_lif.state_dict(), "best_lif_model.pth")
            print(f"  --> New best LIF model saved! (Val Acc: {best_acc_lif:.4f})")

    #  Instantiate IF network
    beta_if = 1.0
    threshold_if = 0.5 

    net_if = QuantizedNet(
        num_inputs, num_hidden, num_outputs, beta_if, num_steps,
        threshold=threshold_if,
        weight_bits=8, act_bits=None, mem_bits=None
    ).to(device)

    optimizer_if = torch.optim.Adam(net_if.parameters(), lr=learning_rate, betas=(0.9, 0.999))
    scheduler_if = lr_scheduler.CosineAnnealingLR(optimizer_if, T_max=len(train_loader) * num_epochs)
    
    # Training Loop for IF
    best_acc_if = 0.0 
    print("\\nBeginning IF Model Training...")
    
    for epoch in range(num_epochs):
        running_loss_if = 0
        running_correct_if = 0
        total_spikes_if = 0

        net_if.train() 

        for i, (images, labels) in enumerate(train_loader):
            images = images.view(-1, num_inputs).to(device)
            labels = labels.to(device)

            spike_input = snn.spikegen.rate(images, num_steps=num_steps, gain=2.0) 
            spk_rec_if, mem_rec_if = net_if(spike_input)

            total_spikes_if += spk_rec_if.sum().item()
            loss_if = loss_fn(spk_rec_if, labels)

            optimizer_if.zero_grad()
            loss_if.backward()
            torch.nn.utils.clip_grad_norm_(net_if.parameters(), clip_grad_norm_value)
            optimizer_if.step()
            scheduler_if.step()

            running_loss_if += loss_if.item()
            output_rates_if = spk_rec_if.sum(dim=0)
            running_correct_if += accuracy_score(output_rates_if, labels) * labels.size(0)

        avg_loss_if = running_loss_if / len(train_loader)
        train_acc_if = running_correct_if / len(train_dataset)

        net_if.eval() 
        val_correct_if = 0
        with torch.no_grad():
            for images, labels in test_loader:
                images = images.view(-1, num_inputs).to(device)
                labels = labels.to(device)

                spike_input = snn.spikegen.rate(images, num_steps=num_steps, gain=2.0) 
                spk_rec_if, mem_rec_if = net_if(spike_input)

                output_rates_if = spk_rec_if.sum(dim=0)
                _, predicted_if = output_rates_if.max(1)
                val_correct_if += (predicted_if == labels).sum().item()

        val_acc_if = val_correct_if / len(test_dataset)
        print(f"Epoch {epoch+1}/{num_epochs} (IF) | Loss: {avg_loss_if:.4f} | Train Acc: {train_acc_if:.4f} | Val Acc: {val_acc_if:.4f}")

        if val_acc_if > best_acc_if:
            best_acc_if = val_acc_if
            torch.save(net_if.state_dict(), "best_if_model.pth")
            print(f"  --> New best IF model saved! (Val Acc: {best_acc_if:.4f})")

if __name__ == '__main__':
    main()