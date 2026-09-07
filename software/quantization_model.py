import torch
import torch.nn as nn
import snntorch as snn
from snntorch import surrogate

class FakeQuantSTE(torch.autograd.Function):
    """
    Forward: quantize to a FIXED scale (round + clamp).
    Backward: straight-through estimator — gradient passes through unchanged.
    """
    @staticmethod
    def forward(ctx, x, num_bits, signed, scale):
        if signed:
            qmin, qmax = -(2**(num_bits - 1)), (2**(num_bits - 1) - 1)
        else:
            qmin, qmax = 0, (2**num_bits - 1)
        x_q = torch.clamp(torch.round(x / scale), qmin, qmax) 
        return x_q * scale 

    @staticmethod
    def backward(ctx, grad_output):
        return grad_output, None, None, None

def fake_quant(x, num_bits=4, signed=True, fixed_range=None):
    """
    fixed_range: the FIXED max magnitude defining the quantization grid.
    """
    if signed:
        qmax = (2**(num_bits - 1) - 1)
    else:
        qmax = (2**num_bits - 1)

    if fixed_range is not None:
        x_max = fixed_range
    else:
        x_max = x.detach().abs().max().clamp(min=1e-8)

    scale = x_max / qmax
    return FakeQuantSTE.apply(x, num_bits, signed, scale)

class QuantizedNet(nn.Module):
    """
    Two-layer fully-connected SNN supporting LIF (beta < 1) and IF (beta = 1).
    """
    def __init__(self, num_inputs, num_hidden, num_outputs, beta, num_steps,
                 threshold=1.0, weight_bits=None, act_bits=None, mem_bits=None,
                 ema_momentum=0.01):
        super().__init__()

        self.num_inputs   = num_inputs
        self.num_hidden   = num_hidden
        self.num_outputs  = num_outputs
        self.beta         = beta
        self.num_steps    = num_steps
        self.threshold    = threshold
        self.weight_bits  = weight_bits
        self.act_bits     = act_bits
        self.mem_bits     = mem_bits
        self.ema_momentum = ema_momentum

        spike_grad = surrogate.fast_sigmoid(slope=10)
        self.fc1  = nn.Linear(num_inputs,  num_hidden,  bias=False)
        self.lif1 = snn.Leaky(beta=self.beta, spike_grad=spike_grad,
                               reset_mechanism='subtract', threshold=self.threshold)
        self.fc2  = nn.Linear(num_hidden,  num_outputs, bias=False)
        self.lif2 = snn.Leaky(beta=self.beta, spike_grad=spike_grad,
                               reset_mechanism='subtract', threshold=self.threshold)

        self.register_buffer('cur1_range', torch.tensor(1.0))
        self.register_buffer('cur2_range', torch.tensor(1.0))

    def _qw(self, w):
        if self.weight_bits is None:
            return w
        return fake_quant(w, num_bits=self.weight_bits, signed=True, fixed_range=None)

    def _qa(self, x, buf_name):
        if self.act_bits is None:
            return x
        cur_max = x.detach().abs().max().clamp(min=1e-8)
        if self.training:
            buf = getattr(self, buf_name)
            buf.mul_(1.0 - self.ema_momentum).add_(cur_max * self.ema_momentum)
        fixed = getattr(self, buf_name).item()
        return fake_quant(x, num_bits=self.act_bits, signed=True, fixed_range=fixed)

    def _qm(self, mem):
        if self.mem_bits is None:
            return mem
        return fake_quant(mem, num_bits=self.mem_bits, signed=True,
                          fixed_range=3.0 * self.threshold)

    def forward(self, x_timeseries):
        mem1 = torch.zeros(x_timeseries.size(1), self.num_hidden,  device=x_timeseries.device)
        mem2 = torch.zeros(x_timeseries.size(1), self.num_outputs, device=x_timeseries.device)

        spk_rec = []
        mem_rec = []

        w1_q = self._qw(self.fc1.weight)
        w2_q = self._qw(self.fc2.weight)

        for step in range(self.num_steps):
            current_input = x_timeseries[step]   

            cur1 = torch.nn.functional.linear(current_input, w1_q, self.fc1.bias)
            cur1 = self._qa(cur1, 'cur1_range')   

            spk1, mem1 = self.lif1(cur1, mem1)
            mem1 = self._qm(mem1)                 

            cur2 = torch.nn.functional.linear(spk1, w2_q, self.fc2.bias)
            cur2 = self._qa(cur2, 'cur2_range')   

            spk2, mem2 = self.lif2(cur2, mem2)
            mem2 = self._qm(mem2)                 

            spk_rec.append(spk2)
            mem_rec.append(mem2)

        spk_rec = torch.stack(spk_rec)  
        mem_rec = torch.stack(mem_rec)
        return spk_rec, mem_rec