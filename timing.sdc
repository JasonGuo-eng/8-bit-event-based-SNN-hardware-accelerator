# 1. Define the base physical crystal clock
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]

# 2. Tell Quartus to automatically find and calculate your 25 MHz PLL output
derive_pll_clocks

# 3. Add realistic real-world jitter to make the timing analysis accurate
derive_clock_uncertainty