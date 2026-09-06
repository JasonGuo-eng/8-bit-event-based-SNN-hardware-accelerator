module top #(
    parameter integer L1_IN        = 784,
    parameter integer L1_OUT       = 128,
    parameter integer L2_IN        = 128,
    parameter integer L2_OUT       = 10,
    parameter integer PES          = 8,
    parameter integer TSTEPS       = 20,
    parameter integer DATA_WIDTH   = 8,
    parameter integer ACC_WIDTH    = 18, // Globally upgraded to 32-bit
    parameter integer L1_THRESHOLD = 364, 
    parameter integer L2_THRESHOLD = 196
)(
    input  wire                        clk,
    input  wire                        reset_n,
    input  wire                        start,

    //input  wire [$clog2(L1_IN)-1:0]    active_count,
    //input  wire [$clog2(L1_IN)-1:0]    active_index,
    input  wire [L1_IN-1:0]            dense_spikes, // Raw 784-bit spike vector
    input  wire                        latch_spikes, // Pulses high to load a new timestep

    output reg  [$clog2(L2_OUT)-1:0]   predicted_class,
    output reg                         done,
    output wire [$clog2(TSTEPS)-1:0]   current_timestep //for hardware
);

    wire                            pe_en;
    wire                            pe_clear;
    wire                            neuron_en;
    wire [$clog2(L1_OUT/PES)-1:0]   group;
    wire [$clog2(L1_IN)-1:0]        col_addr;
    wire                            layer_sel;
    wire [$clog2(TSTEPS)-1:0]       timestep;
    wire [3:0]                      active_pes;
    wire                            ctrl_done; //the controller has completed the entire image
    assign current_timestep = timestep; // NEW: Route the controller's timestep out to the wrapper

    reg [L1_OUT-1:0] spike_register;//holds the spikes that fired out of 128 neurons, layer 2 needs it

    wire [PES-1:0]   l1_spikes_out; //get the result from if_neuron.v, but they are temporary, so stored in spike_register
    wire [PES-1:0]   l1_valid;
    wire [PES-1:0]   l2_spikes_out;
    wire [PES-1:0]   l2_valid;

    reg signed [ACC_WIDTH-1:0] output_membrane [0:L2_OUT-1];  //lives after the second if neuron layer, accumulate the spikes so far for one image

    wire [$clog2(L1_IN)-1:0] l1_col_addr = col_addr; //adapts the controller's col_addr to layer 1
    wire [$clog2(L2_IN)-1:0] l2_col_addr = col_addr[$clog2(L2_IN)-1:0];

    wire [$clog2(L1_IN * L1_OUT/PES)-1:0] l1_base_addr = group * L1_IN; //select the block, base address of each block
    wire [$clog2(L2_IN * ((L2_OUT+PES-1)/PES))-1:0] l2_base_addr = group * L2_IN;
    // AER routing wires
    wire [$clog2(L1_IN)-1:0] internal_active_count;
    wire [$clog2(L1_IN)-1:0] internal_active_index;
    wire                     aer_ready;
    wire                     next_index;


    // Instantiate AER Encoder
    aer_encoder #(
        .IN(L1_IN)
    ) aer_inst (
        .clk(clk),
        .reset_n(reset_n),
        .start(latch_spikes),        
        .dense_spikes(dense_spikes), 
        .next_index(next_index),     
        .active_count(internal_active_count),
        .active_index(internal_active_index),
        .ready(aer_ready)
    );

    controller #(
        .L1_IN  (L1_IN),
        .L1_OUT (L1_OUT),
        .L2_IN  (L2_IN),
        .L2_OUT (L2_OUT),
        .PES    (PES),
        .TSTEPS (TSTEPS)
    ) ctrl (
        .clk          (clk),
        .reset_n      (reset_n),
        .start        (start),
        .active_count (internal_active_count),
        .active_index (internal_active_index),
        .next_index   (next_index),
        .pe_en        (pe_en),
        .pe_clear     (pe_clear),
        .neuron_en    (neuron_en),
        .group        (group),
        .col_addr     (col_addr),
        .layer_sel    (layer_sel),
        .timestep     (timestep),
        .active_pes   (active_pes),
        .done         (ctrl_done)
    );

    wire image_start_clear = start; //when a new image begins, clear the previous image's state

    layer #(
        .IN         (L1_IN),
        .OUT        (L1_OUT),
        .PES        (PES),
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH),
        .THRESHOLD  (L1_THRESHOLD),
        .MEM_FILE0  ("mem_if/fc1_weights_bank0.mem"),
        .MEM_FILE1  ("mem_if/fc1_weights_bank1.mem"),
        .MEM_FILE2  ("mem_if/fc1_weights_bank2.mem"),
        .MEM_FILE3  ("mem_if/fc1_weights_bank3.mem"),
        .MEM_FILE4  ("mem_if/fc1_weights_bank4.mem"),
        .MEM_FILE5  ("mem_if/fc1_weights_bank5.mem"),
        .MEM_FILE6  ("mem_if/fc1_weights_bank6.mem"),
        .MEM_FILE7  ("mem_if/fc1_weights_bank7.mem")
    ) layer1 (
        .clk              (clk),
        .reset_n          (reset_n),
        .en               (pe_en & ~layer_sel), //layer_sel = 0 means layer 1 is acive; layer_sel = 1 means layer 2 is active
        .clear            ((pe_clear & ~layer_sel) | image_start_clear), 
        .image_start_clear(image_start_clear),
        .neuron_en        (neuron_en & ~layer_sel),
        .col_addr         (l1_col_addr),
        .active_pes       (active_pes),       
        .group            (group),
        .base_addr        (l1_base_addr),     
        .spikes_out       (l1_spikes_out),
        .valid            (l1_valid)
    );

    layer #(
        .IN         (L2_IN),
        .OUT        (L2_OUT),
        .PES        (PES),
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH),
        .THRESHOLD  (L2_THRESHOLD),
        .MEM_FILE0  ("mem_if/fc2_weights_bank0.mem"),
        .MEM_FILE1  ("mem_if/fc2_weights_bank1.mem"),
        .MEM_FILE2  ("mem_if/fc2_weights_bank2.mem"),
        .MEM_FILE3  ("mem_if/fc2_weights_bank3.mem"),
        .MEM_FILE4  ("mem_if/fc2_weights_bank4.mem"),
        .MEM_FILE5  ("mem_if/fc2_weights_bank5.mem"),
        .MEM_FILE6  ("mem_if/fc2_weights_bank6.mem"),
        .MEM_FILE7  ("mem_if/fc2_weights_bank7.mem")
    ) layer2 (
        .clk              (clk),
        .reset_n          (reset_n),
        .en               (pe_en & layer_sel & spike_register[l2_col_addr]), //if in the array, it is a 0, perform 0 skipping, and don't perform PE accumulation
        .clear            ((pe_clear & layer_sel) | image_start_clear), 
        .image_start_clear(image_start_clear),
        .neuron_en        (neuron_en & layer_sel),
        .col_addr         (l2_col_addr),
        .active_pes       (active_pes),  
        .group            (group[$clog2((L2_OUT+PES-1)/PES)-1:0]), //only has 2 bits  
        .base_addr        (l2_base_addr),     
        .spikes_out       (l2_spikes_out),
        .valid            (l2_valid)
    );

    localparam L2_GROUPS = (L2_OUT + PES - 1) / PES;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            spike_register <= 0;
        end else if (start || (pe_clear && layer_sel && group == L2_GROUPS - 1)) begin //two situations where we ned to clear all spikes, 1.new image 2.finished layer 2, before moving to the next timestep
            spike_register <= 0;
        end else if (neuron_en && ~layer_sel) begin
            spike_register[group * PES +: PES] <= l1_spikes_out; //0-7, 8-15,...,120-127, 128 layer 1 output spikes in total, fill the 128-bit reg across 16 groups
        end
    end

    integer i;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            for (i = 0; i < L2_OUT; i = i + 1)
                output_membrane[i] <= 0;
        end else if (start) begin
            for (i = 0; i < L2_OUT; i = i + 1)
                output_membrane[i] <= 0;
        end else if (neuron_en && layer_sel) begin
            for (i = 0; i < PES; i = i + 1) begin
                if ((group * PES + i) < L2_OUT) 
                    output_membrane[group * PES + i] <= 
                        output_membrane[group * PES + i] + l2_spikes_out[i];
            end
        end                 
    end

    integer j;
    reg signed [ACC_WIDTH-1:0] max_val;
    reg [$clog2(L2_OUT)-1:0]   max_idx;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            predicted_class <= 0;
            done            <= 0;
        end else if (ctrl_done) begin
            max_val = output_membrane[0]; 
            max_idx = 0;
            for (j = 1; j < L2_OUT; j = j + 1) begin
                if (output_membrane[j] > max_val) begin
                    max_val = output_membrane[j]; 
                    max_idx = j;
                end
            end
            predicted_class <= max_idx;
            done <= 1;
        end else begin
            done <= 0;
        end
    end

endmodule