`timescale 1ns/1ps

module top_tb_single;

    // =======================================================
    // CONFIGURATION: Select which image index to test
    // =======================================================
    parameter integer IMAGE_TO_TEST      = 0; 
    parameter integer TSTEPS             = 20;
    parameter integer CLK_PERIOD         = 31; // ~31ns period = 32.2 MHz (Quartus Fmax)[cite: 3]

    reg clk;
    reg reset_n;
    reg start;

    wire [9:0] active_count;
    wire [9:0] active_index;
    wire       next_index;

    wire [3:0] predicted_class;
    wire       done;

    // Expanded memory arrays to hold the full Python dataset[cite: 3]
    reg [9:0] event_counts  [0:199999];    
    reg [9:0] event_indices [0:49999999];  
    reg [3:0] test_labels   [0:9999];      

    integer idx_ptr;
    integer image_idx;

    // =======================================================
    // BENCHMARKING & METRIC VARIABLES[cite: 3]
    // =======================================================
    time    img_start_time;
    time    img_end_time;
    integer img_cycles;
    real    latency_us;

    top uut (
        .clk(clk),
        .reset_n(reset_n),
        .start(start),
        .active_count(active_count),
        .active_index(active_index),
        .next_index(next_index),
        .predicted_class(predicted_class),
        .done(done)
    );

    // =======================================================
    // POWER ANALYSIS: Generate VCD for Quartus
    // =======================================================
    initial begin
        $dumpfile("power_capture.vcd");
        $dumpvars(0, uut);
    end

    // Clock generation[cite: 3]
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2.0) clk = ~clk;
    end

    // Load all memory files[cite: 3]
    initial begin
        $display("Loading memory files...");
        $readmemh("mem_event/event_counts.mem", event_counts);
        $readmemh("mem_event/event_indices.mem", event_indices);
        $readmemh("mem_event/test_labels.mem", test_labels);
        $display("Memory files loaded successfully.");
    end

    // AER Handshaking Logic[cite: 3]
    assign active_count = event_counts[(image_idx * TSTEPS) + uut.ctrl.timestep];
    assign active_index = event_indices[idx_ptr];

    always @(posedge clk) begin
        if (!reset_n) begin
            idx_ptr <= 0;
        end else if (next_index) begin
            idx_ptr <= idx_ptr + 1;
        end
    end

    // Single Image Execution
    initial begin
        reset_n = 0;
        start = 0;
        image_idx = IMAGE_TO_TEST;

        // Reset the system (Scaled to clock period)[cite: 3]
        #(CLK_PERIOD * 2) reset_n = 1;
        #(CLK_PERIOD);

        $display("==================================================");
        $display("STARTING SINGLE INFERENCE FOR IMAGE %0d", IMAGE_TO_TEST);
        $display("==================================================");

        // 1. Record start time
        img_start_time = $time;

        // Trigger inference (Hold start high for 2 full clock cycles)[cite: 3]
        start = 1;
        #(CLK_PERIOD * 2) start = 0;

        // Wait until the top level argmax asserts done[cite: 3]
        wait(done == 1);
        
        // 2. Record end time and calculate cycles
        img_end_time = $time;
        img_cycles = (img_end_time - img_start_time) / CLK_PERIOD;
        latency_us = (img_cycles * CLK_PERIOD) / 1000.0;

        // Wait a few cycles to capture the final state in the VCD
        #(CLK_PERIOD * 10);

        // Print final summary metrics
        $display("==================================================");
        $display("           SINGLE INFERENCE BENCHMARK SUMMARY      ");
        $display("==================================================");
        $display("Image Index Tested     : %0d", image_idx);
        $display("Actual Label           : %0d", test_labels[image_idx]);
        $display("Predicted Class        : %0d", predicted_class);
        if (predicted_class == test_labels[image_idx])
            $display("Prediction Status      : CORRECT");
        else
            $display("Prediction Status      : INCORRECT");
        $display("--------------------------------------------------");
        $display("Total Clock Cycles     : %0d cycles", img_cycles);
        $display("Latency (@ 32.2MHz)    : %0.2f us", latency_us);
        $display("==================================================");
        $display("VCD file 'power_capture.vcd' generated successfully.");

        $stop;
    end

endmodule