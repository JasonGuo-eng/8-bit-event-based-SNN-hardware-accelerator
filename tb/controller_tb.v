`timescale 1ns/1ps

module controller_tb;

    reg clk;
    reg reset_n;
    reg start;

    // AER Interface driving the controller
    reg  [9:0] active_count;
    reg  [9:0] active_index;
    wire       next_index;

    // Outputs from the controller
    wire pe_en, pe_clear, neuron_en, layer_sel, done;
    wire [3:0] group;
    wire [9:0] col_addr;
    wire [4:0] timestep;
    wire [3:0] active_pes;

    // Mock FIFO memory and pointer
    reg [9:0] dummy_fifo [0:2];
    integer fifo_ptr;

    // Instantiate the controller
    controller uut (
        .clk(clk),
        .reset_n(reset_n),
        .start(start),
        .active_count(active_count),
        .active_index(active_index),
        .next_index(next_index),
        .pe_en(pe_en),
        .pe_clear(pe_clear),
        .neuron_en(neuron_en),
        .group(group),
        .col_addr(col_addr),
        .layer_sel(layer_sel),
        .timestep(timestep),
        .active_pes(active_pes),
        .done(done)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Mock FIFO Logic
    always @(posedge clk) begin
        if (!reset_n) begin
            fifo_ptr <= 0;
        end else if (next_index) begin
            // When controller requests next index, advance pointer
            fifo_ptr <= fifo_ptr + 1;
        end
    end
    
    // Continuous assignment ensures the data is ready immediately 
    always @(*) begin
        active_index = dummy_fifo[fifo_ptr];
    end

    // Test Sequence
    initial begin
        // Initialize everything
        reset_n = 0;
        start = 0;
        
        // Define our test scenario: 3 active spikes
        active_count = 3; 
        
        // Populate dummy FIFO with 3 specific hardware addresses
        dummy_fifo[0] = 10'd42;
        dummy_fifo[1] = 10'd105;
        dummy_fifo[2] = 10'd700;

        #20 reset_n = 1;
        
        // Trigger the start of Layer 1 Group 0
        #10 start = 1;
        #10 start = 0;

        // Wait until the controller finishes L1 group 0 and asserts pe_clear
        wait (pe_clear == 1);
        
        #50 $display("Test Complete. Check waveforms for pe_en and col_addr!");
        $stop;
    end
    
endmodule