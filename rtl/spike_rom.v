module spike_rom (
    input  wire         clk,
    input  wire [10:0]  addr, // 0 to 1999 (100 images * 20 timesteps)
    output reg  [783:0] q
);
    reg [783:0] memory [0:1999];
    
    initial begin
        $readmemh("demo_spikes.mem", memory);
    end
    
    always @(posedge clk) begin
        q <= memory[addr];
    end
endmodule