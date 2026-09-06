module de1_soc_top (
    input  wire       CLOCK_50, 
    input  wire [3:0] KEY,      
    input  wire       UART_RXD, 
    
    output wire [6:0] HEX0,
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3,
    output wire [6:0] HEX4,
     
    //  HPS Physical Pins 
    output wire [14:0] memory_mem_a,
    output wire [2:0]  memory_mem_ba,
    output wire        memory_mem_ck,
    output wire        memory_mem_ck_n,
    output wire        memory_mem_cke,
    output wire        memory_mem_cs_n,
    output wire        memory_mem_ras_n,
    output wire        memory_mem_cas_n,
    output wire        memory_mem_we_n,
    output wire        memory_mem_reset_n,
    inout  wire [7:0]  memory_mem_dq,
    inout  wire        memory_mem_dqs,
    inout  wire        memory_mem_dqs_n,
    output wire        memory_mem_odt,
    output wire        memory_mem_dm,
    input  wire        memory_oct_rzqin,
    inout  wire        hps_io_hps_io_gpio_inst_GPIO09,
    inout  wire        hps_io_hps_io_gpio_inst_LOANIO49,
    inout  wire        hps_io_hps_io_gpio_inst_LOANIO50
);

    wire reset_n = KEY[0];

    // 1. Clock Generation (25 MHz or customized via PLL)
    wire clk_25mhz;
    snn_pll pll_inst (
        .refclk   (CLOCK_50),
        .rst      (~reset_n),
        .outclk_0 (clk_25mhz)
    );

    // 2. HPS Bridge (Kept dummy-instantiated to preserve .qsf pins)
    wire [66:0] hps_loan_io_in;
    wire [66:0] hps_loan_io_out;
    wire [66:0] hps_loan_io_oe;

    soc_system hps_bridge (
        .clk_clk           (CLOCK_50),
        .reset_reset_n     (reset_n),
        .loan_io_in        (hps_loan_io_in),
        .loan_io_out       (hps_loan_io_out),
        .loan_io_oe        (hps_loan_io_oe),
        .memory_mem_a      (memory_mem_a),
        .memory_mem_ba     (memory_mem_ba),
        .memory_mem_ck     (memory_mem_ck),
        .memory_mem_ck_n   (memory_mem_ck_n),
        .memory_mem_cke    (memory_mem_cke),
        .memory_mem_cs_n   (memory_mem_cs_n),
        .memory_mem_ras_n  (memory_mem_ras_n),
        .memory_mem_cas_n  (memory_mem_cas_n),
        .memory_mem_we_n   (memory_mem_we_n),
        .memory_mem_reset_n(memory_mem_reset_n),
        .memory_mem_dq     (memory_mem_dq),
        .memory_mem_dqs    (memory_mem_dqs),
        .memory_mem_dqs_n  (memory_mem_dqs_n),
        .memory_mem_odt    (memory_mem_odt),
        .memory_mem_dm     (memory_mem_dm),
        .memory_oct_rzqin  (memory_oct_rzqin),
        .hps_io_hps_io_gpio_inst_GPIO09   (hps_io_hps_io_gpio_inst_GPIO09),
        .hps_io_hps_io_gpio_inst_LOANIO49 (hps_io_hps_io_gpio_inst_LOANIO49),
        .hps_io_hps_io_gpio_inst_LOANIO50 (hps_io_hps_io_gpio_inst_LOANIO50)
    );

    // 3. SNN Signals & ROM Instantiation for 100 Images
    reg          snn_start;
    reg  [783:0] snn_dense_spikes;
    reg          snn_latch_spikes;
    wire [3:0]   snn_predicted_class;
    wire         snn_done;
    wire [4:0]   snn_current_ts;
    
    reg  [6:0]   img_idx;       // 0 to 99
    reg  [4:0]   local_ts;      // 0 to 19
    reg  [13:0]  correct_count; 
    reg  [3:0]   true_label;
    reg  [6:0]   wrong_img_idx; // Captures the index of the wrong prediction

    wire [10:0]  spike_addr = (img_idx * 20) + local_ts;
    wire [783:0] rom_spike_data;
    wire [3:0]   rom_label_data;

    spike_rom s_rom (.clk(clk_25mhz), .addr(spike_addr), .q(rom_spike_data));
    label_rom l_rom (.clk(clk_25mhz), .addr(img_idx),    .q(rom_label_data));

    // 4. Standalone Image Processing FSM
    localparam S_INIT = 0, S_START = 1, S_RUN = 2, S_SCORE = 3, S_DONE = 4;
    reg [2:0] state;

    always @(posedge clk_25mhz or negedge reset_n) begin
        if (!reset_n) begin
            state         <= S_INIT;
            img_idx       <= 0;
            correct_count <= 0;
            wrong_img_idx <= 0;
            snn_start     <= 0;
        end else begin
            snn_start <= 0; 
            case (state)
                S_INIT: begin
                    state <= S_START; 
                end
                S_START: begin
                    true_label <= rom_label_data;
                    snn_start  <= 1; 
                    state      <= S_RUN;
                end
                S_RUN: begin
                    if (snn_done) begin
                        state <= S_SCORE;
                    end
                end
                S_SCORE: begin
                    if (snn_predicted_class == true_label) begin
                        correct_count <= correct_count + 1;
                    end else begin
                        wrong_img_idx <= img_idx; // Capture the wrong index
                    end
                    
                    if (img_idx == 99) begin // 100 images completed
                        state <= S_DONE;
                    end else begin
                        img_idx <= img_idx + 1;
                        state   <= S_INIT;
                    end
                end
                S_DONE: begin
                    // Benchmark complete.
                end
            endcase
        end
    end

    // 5. Timestep Feeding Logic
    always @(posedge clk_25mhz or negedge reset_n) begin
        if (!reset_n) begin
            local_ts         <= 0;
            snn_latch_spikes <= 0;
        end else if (snn_start) begin
            local_ts         <= 0;
            snn_latch_spikes <= 0;
        end else begin
            if ((snn_current_ts == local_ts) && (local_ts < 20) && (state == S_RUN)) begin
                snn_dense_spikes <= rom_spike_data; 
                snn_latch_spikes <= 1;
                local_ts         <= local_ts + 1;
            end else begin
                snn_latch_spikes <= 0;
            end
        end
    end

    // 6. SNN Core Instantiation
    top snn_core (
        .clk              (clk_25mhz),
        .reset_n          (reset_n),
        .start            (snn_start),
        .dense_spikes     (snn_dense_spikes),
        .latch_spikes     (snn_latch_spikes),
        .predicted_class  (snn_predicted_class),
        .done             (snn_done),
        .current_timestep (snn_current_ts)
    );

    // 7. Hex Display Output
    wire [3:0] d4, d3, d2, d1, d0;
    wire [3:0] w4, w3, w2, w1, w0;
    
    // Convert the Correct Count
    bin2bcd bcd_score (.bin(correct_count), .bcd4(d4), .bcd3(d3), .bcd2(d2), .bcd1(d1), .bcd0(d0));
    
    // Convert the Wrong Image Index (padded to 14 bits to match the module input)
    bin2bcd bcd_wrong (.bin({7'd0, wrong_img_idx}), .bcd4(w4), .bcd3(w3), .bcd2(w2), .bcd1(w1), .bcd0(w0));

    // Displays for Wrong Image Index
    hex_decoder h4 (.hex_digit(w1), .segments(HEX4)); 
    hex_decoder h3 (.hex_digit(w0), .segments(HEX3));
    
    // Blank space to separate the numbers
    hex_decoder h2 (.hex_digit(4'hF), .segments(HEX2));
    
    // Displays for Total Correct Score
    hex_decoder h1 (.hex_digit(d1), .segments(HEX1));
    hex_decoder h0 (.hex_digit(d0), .segments(HEX0));

endmodule