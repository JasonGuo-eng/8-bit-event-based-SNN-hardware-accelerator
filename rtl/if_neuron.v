module if_neuron #( // purely combinational
    parameter integer ACC_WIDTH = 18, 
    parameter integer THRESHOLD = 32
) (
    input wire signed [ACC_WIDTH-1:0] mem_in, //in
    input wire signed [ACC_WIDTH-1:0] cur_in, //in, this is just cur_out from the pe
    output wire spike_out, //out
    output wire signed [ACC_WIDTH-1:0] mem_out //out
);

    // Safely extend widths before arithmetic sum to prevent hidden carry-loss
    wire signed [ACC_WIDTH:0] membrane_next = {{1{mem_in[ACC_WIDTH-1]}}, mem_in} + {{1{cur_in[ACC_WIDTH-1]}}, cur_in}; 
    
    // Threshold Check
    assign spike_out = (membrane_next >= THRESHOLD) ? 1'b1 : 1'b0;
    
    // Soft reset by subtraction to match Python training behavior
    assign mem_out = (membrane_next >= THRESHOLD) ? (membrane_next - THRESHOLD) : membrane_next; //stays inside this module, output will become input again, however this is achieved in layer.v

endmodule

