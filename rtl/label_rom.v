module label_rom (
    input  wire         clk,
    input  wire [6:0]   addr, // 0 to 99
    output reg  [3:0]   q
);
    reg [3:0] memory [0:99];
    
    initial begin
        $readmemh("demo_labels.mem", memory);
    end
    
    always @(posedge clk) begin
        q <= memory[addr];
    end
endmodule