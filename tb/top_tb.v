/*`timescale 1ns/1ps

module top_tb;

    // =======================================================
    // CONFIGURATION: Set to 10000 for the full dataset
    // =======================================================
    parameter integer NUM_IMAGES_TO_TEST = 10000; 
    parameter integer TSTEPS             = 20;
    parameter real CLK_PERIOD         = 25.64; // ~31ns period = 32.2 MHz (Quartus Fmax)

    reg clk;
    reg reset_n;
    reg start;

    wire [9:0] active_count;
    wire [9:0] active_index;
    wire       next_index;

    wire [3:0] predicted_class;
    wire       done;

    // Expanded memory arrays to hold the full Python dataset
    reg [9:0] event_counts  [0:199999];    // 20 timesteps * 10000 images
    reg [9:0] event_indices [0:49999999];  // 50 Million depth to hold all spikes
    reg [3:0] test_labels   [0:9999];      // 10000 labels

    integer idx_ptr;
    integer image_idx;
    integer correct_count;

    // =======================================================
    // BENCHMARKING & METRIC VARIABLES
    // =======================================================
    time    img_start_time;
    time    img_end_time;
    time    sim_start_time;
    time    sim_end_time;
    
    integer img_cycles;
    integer total_cycles;
    integer avg_cycles;
    real    avg_latency_us;
    real    fps_estimate;

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

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Load all memory files
    initial begin
        $display("Loading memory files...");
        $readmemh("mem_event/event_counts.mem", event_counts);
        $readmemh("mem_event/event_indices.mem", event_indices);
        $readmemh("mem_event/test_labels.mem", test_labels);
        $display("Memory files loaded successfully.");
    end

    // AER Handshaking Logic
    assign active_count = event_counts[(image_idx * TSTEPS) + uut.ctrl.timestep];
    assign active_index = event_indices[idx_ptr];

    always @(posedge clk) begin
        if (!reset_n) begin
            idx_ptr <= 0;
        end else if (next_index) begin
            idx_ptr <= idx_ptr + 1;
        end
    end

    // Batch Simulation Execution
    initial begin
        reset_n = 0;
        start = 0;
        image_idx = 0;
        correct_count = 0;
        total_cycles = 0;

        // Reset the system (Scaled to clock period)
        #(CLK_PERIOD * 2) reset_n = 1;
        #(CLK_PERIOD);

        $display("STARTING BATCH INFERENCE FOR %0d IMAGES", NUM_IMAGES_TO_TEST);
        
        // Record overall batch start time
        sim_start_time = $time;

        // Loop through the requested number of images
        for (image_idx = 0; image_idx < NUM_IMAGES_TO_TEST; image_idx = image_idx + 1) begin
            
            // 1. Record start time for current image
            img_start_time = $time;

            // Trigger inference (Hold start high for 2 full clock cycles)
            start = 1;
            #(CLK_PERIOD * 2) start = 0;

            // Wait until the top level argmax asserts done
            wait(done == 1);
            
            // 2. Record end time and accumulate cycles
            img_end_time = $time;
            img_cycles = (img_end_time - img_start_time) / CLK_PERIOD;
            total_cycles = total_cycles + img_cycles;

            // Check prediction
            if (predicted_class == test_labels[image_idx]) begin
                correct_count = correct_count + 1;
            end 

            // Wait 2 full clock cycles before starting the next image
            #(CLK_PERIOD * 2);
        end

        // Record overall batch end time
        sim_end_time = $time;

        // Calculate metric averages
        avg_cycles     = total_cycles / NUM_IMAGES_TO_TEST;
        avg_latency_us = (avg_cycles * CLK_PERIOD) / 1000.0; // convert ns to microseconds
        fps_estimate   = 1000000.0 / avg_latency_us;         // 1 sec = 1,000,000 us

        // Print final summary metrics
        
        $display("           BATCH INFERENCE BENCHMARK SUMMARY       ");
        $display("Total Images Tested    : %0d", NUM_IMAGES_TO_TEST);
        $display("Total Correct          : %0d", correct_count);
        $display("Classification Accuracy: %0d%%", (correct_count * 100) / NUM_IMAGES_TO_TEST);
        $display("Total Hardware Time    : %0t ns", (sim_end_time - sim_start_time));
        $display("Total Clock Cycles     : %0d cycles", total_cycles);
        $display("Avg Cycles Per Image   : %0d cycles", avg_cycles);
        $display("Avg Latency (@ 39MHz): %0.2f us", avg_latency_us);
        $display("Throughput (@ 39MHz) : %0.0f FPS", fps_estimate);

        $stop;
    end

endmodule */

`timescale 1ns/1ps

module top_tb;

    // =======================================================
    // CONFIGURATION: Set to 10000 for the full dataset
    // =======================================================
    parameter integer NUM_IMAGES_TO_TEST = 100; 
    parameter integer TSTEPS             = 20;
    parameter integer L1_IN              = 784;
    parameter real CLK_PERIOD            = 25.0; // ~31ns period = 32.2 MHz (Quartus Fmax)

    reg clk;
    reg reset_n;
    reg start;

    // New Dense Spike Inputs for the AER Encoder
    reg [L1_IN-1:0] dense_spikes;
    reg             latch_spikes;

    wire [3:0] predicted_class;
    wire       done;

    // Memory arrays to hold the raw Python dataset
    reg [L1_IN-1:0] raw_spike_data [0:199999]; // 20 timesteps * 10000 images
    reg [3:0]       test_labels    [0:9999];   // 10000 labels

    integer image_idx;
    integer correct_count;
    integer current_timestep;

    // =======================================================
    // BENCHMARKING & METRIC VARIABLES
    // =======================================================
    time    img_start_time;
    time    img_end_time;
    time    sim_start_time;
    time    sim_end_time;
    
    integer img_cycles;
    integer total_cycles;
    integer avg_cycles;
    real    avg_latency_us;
    real    fps_estimate;

    // Instantiate Top Level
    // NOTE: Ensure your top.v module has updated ports for dense_spikes and latch_spikes!
    top uut (
        .clk(clk),
        .reset_n(reset_n),
        .start(start),
        .dense_spikes(dense_spikes), 
        .latch_spikes(latch_spikes), 
        .predicted_class(predicted_class),
        .done(done)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Load all memory files
    initial begin
        $display("Loading memory files...");
        // Uses $readmemb because spikes are stored as binary strings of 1s and 0s
        $readmemb("mem_event/raw_spikes.mem", raw_spike_data);
        $readmemh("mem_event/test_labels.mem", test_labels);
        $display("Memory files loaded successfully.");
    end

    // =======================================================
    // TIMESTEP FEEDING LOGIC
    // =======================================================
    always @(posedge clk) begin
        if (!reset_n || start) begin
            current_timestep <= 0;
            latch_spikes <= 1'b0;
        end else begin
            // Whenever the controller progresses to a new timestep,
            // fetch the 784-bit vector for that timestep and pulse latch_spikes high.
            if (uut.ctrl.timestep == current_timestep && current_timestep < TSTEPS) begin
                dense_spikes <= raw_spike_data[(image_idx * TSTEPS) + current_timestep];
                latch_spikes <= 1'b1;
                current_timestep <= current_timestep + 1;
            end else begin
                latch_spikes <= 1'b0; // Pulse high for only 1 clock cycle
            end
        end
    end

    // =======================================================
    // BATCH SIMULATION EXECUTION
    // =======================================================
    initial begin
        reset_n = 0;
        start = 0;
        image_idx = 0;
        correct_count = 0;
        total_cycles = 0;

        // Reset the system (Scaled to clock period)
        #(CLK_PERIOD * 2) reset_n = 1;
        #(CLK_PERIOD);

        $display("STARTING BATCH INFERENCE FOR %0d IMAGES", NUM_IMAGES_TO_TEST);
        
        // Record overall batch start time
        sim_start_time = $time;

        // Loop through the requested number of images
        for (image_idx = 0; image_idx < NUM_IMAGES_TO_TEST; image_idx = image_idx + 1) begin
            
            // 1. Record start time for current image
            img_start_time = $time;

            // Trigger inference (Hold start high for 2 full clock cycles)
            start = 1;
            #(CLK_PERIOD * 2) start = 0;

            // Wait until the top level argmax asserts done
            wait(done == 1);
            
            // 2. Record end time and accumulate cycles
            img_end_time = $time;
            img_cycles = (img_end_time - img_start_time) / CLK_PERIOD;
            total_cycles = total_cycles + img_cycles;

            // Check prediction against truth label
            if (predicted_class == test_labels[image_idx]) begin
                correct_count = correct_count + 1;
            end 

            // Wait 2 full clock cycles before starting the next image
            #(CLK_PERIOD * 2);
        end

        // Record overall batch end time
        sim_end_time = $time;

        // Calculate metric averages
        avg_cycles     = total_cycles / NUM_IMAGES_TO_TEST;
        avg_latency_us = (avg_cycles * CLK_PERIOD) / 1000.0; // convert ns to microseconds
        fps_estimate   = 1000000.0 / avg_latency_us;         // 1 sec = 1,000,000 us

        // Print final summary metrics
        $display("===================================================");
        $display("           BATCH INFERENCE BENCHMARK SUMMARY       ");
        $display("===================================================");
        $display("Total Images Tested    : %0d", NUM_IMAGES_TO_TEST);
        $display("Total Correct          : %0d", correct_count);
        $display("Classification Accuracy: %0d%%", (correct_count * 100) / NUM_IMAGES_TO_TEST);
        $display("Total Hardware Time    : %0t ns", (sim_end_time - sim_start_time));
        $display("Total Clock Cycles     : %0d cycles", total_cycles);
        $display("Avg Cycles Per Image   : %0d cycles", avg_cycles);
        $display("Avg Latency (@ 40MHz): %0.2f us", avg_latency_us);
        $display("Throughput (@ 40MHz) : %0.0f FPS", fps_estimate);
        $display("===================================================");

        $stop;
    end

endmodule