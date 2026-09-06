module aer_encoder #(
    parameter integer IN = 784
)(
    input  wire                     clk,
    input  wire                     reset_n,
    input  wire                     start,        
    input  wire [IN-1:0]            dense_spikes, //the original input
    input  wire                     next_index,   

    output reg  [$clog2(IN)-1:0]    active_count, 
    output wire [$clog2(IN)-1:0]    active_index, 
    output reg                      ready         
);

    reg [IN-1:0] working_spikes; //make a copy as we don't want to modify the original input
    integer i, j;

    // 1. Hierarchical Popcount Tree (MUST USE dense_spikes)

    reg [5:0] popcount_chunks [0:24]; //divide 784 bits into groups of 32, 25 groups in total, group0: bits 0-31...
    reg [$clog2(IN):0] count_comb;

    always @(*) begin
        count_comb = 0;
        for (i = 0; i < 25; i = i + 1) begin
            popcount_chunks[i] = 0;
            for (j = 0; j < 32; j = j + 1) begin
                if ((i * 32 + j) < IN) begin
                    // FIX: Accurately count the raw incoming image data
                    popcount_chunks[i] = popcount_chunks[i] + dense_spikes[i * 32 + j]; //count how many are there in a group are 1s, add them up
                end
            end
            count_comb = count_comb + popcount_chunks[i]; //counts the total 1s across 25 groups
        end
    end

    
    // 2. Hierarchical Priority Encoder (MUST use working_spikes)
    reg [24:0] chunk_active; //still divide 784 bits into 25 chunks, check if each chunk has spike or no
    reg [4:0]  active_chunk;
    reg [4:0]  active_bit;
    reg        found_chunk;
    reg        found_bit;

    always @(*) begin
        // Stage 2A: Identify which chunks currently have at least 1 spike
        for (i = 0; i < 25; i = i + 1) begin
            chunk_active[i] = 1'b0;
            for (j = 0; j < 32; j = j + 1) begin
                if ((i * 32 + j) < IN) begin
                    if (working_spikes[i * 32 + j]) begin
                        chunk_active[i] = 1'b1;
                    end
                end
            end
        end

        // Stage 2B: Find the first active chunk
        active_chunk = 0;
        found_chunk = 0;
        for (i = 0; i < 25; i = i + 1) begin
            if (chunk_active[i] && !found_chunk) begin
                active_chunk = i;
                found_chunk = 1'b1; //a flag, then !found_chunk = 0, and we can select the lowest-numbered active chunk
            end
        end

        // Stage 2C: Find the first 1 inside that chunk
        active_bit = 0;
        found_bit = 0;
        for (j = 0; j < 32; j = j + 1) begin
            if ((active_chunk * 32 + j) < IN) begin
                if (working_spikes[active_chunk * 32 + j] && !found_bit) begin
                    active_bit = j;
                    found_bit = 1'b1;
                end
            end
        end
    end

    // The final index is the (Chunk ID * 32) + Local Bit ID
    wire [$clog2(IN)-1:0] combinational_index = (active_chunk * 32) + active_bit;
    assign active_index = combinational_index;

    // 3. Sequential Masking Logic
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            working_spikes <= 0;
            active_count   <= 0;
            ready          <= 1'b0;
        end else if (start) begin
            working_spikes <= dense_spikes; //copy the original spike here when start
            active_count   <= count_comb; //total count of 1s in this vector
            ready          <= 1'b1; //encoder accepted the dense spike vector and is ready to provide events
        end else if (next_index && found_chunk) begin
            working_spikes[combinational_index] <= 1'b0;
        end
    end

endmodule