module controller #(
    parameter integer L1_IN  = 784,
    parameter integer L1_OUT = 128,
    parameter integer L2_IN  = 128,
    parameter integer L2_OUT = 10,
    parameter integer PES    = 8, //layer 1 has 16 groups, layer 2 has 2 groups(0-7, 8-9)
    parameter integer TSTEPS = 20
)(
    input  wire clk,
    input  wire reset_n,
    input  wire start,

    input  wire [$clog2(L1_IN)-1:0]         active_count, 
    input  wire [$clog2(L1_IN)-1:0]         active_index, 
    output reg                              next_index,   

    output reg                              pe_en,
    output reg                              pe_clear,
    output reg                              neuron_en,
    output reg  [$clog2(L1_OUT/PES)-1:0]    group,
    output reg  [$clog2(L1_IN)-1:0]         col_addr,
    output reg                              layer_sel,
    output reg  [$clog2(TSTEPS)-1:0]        timestep,
    output reg  [3:0]                       active_pes,
    output reg                              done
);

    localparam L1_GROUPS = L1_OUT / PES;
    localparam L2_GROUPS = (L2_OUT + PES - 1) / PES; 

    localparam IDLE            = 4'd0;
    localparam L1_FETCH        = 4'd1;  
    localparam L1_WAIT         = 4'd2;
    localparam L1_COMPUTE      = 4'd3;
    localparam L1_COMPUTE_WAIT = 4'd4;  
    localparam L1_FIRE         = 4'd5;
    localparam L1_CLEAR        = 4'd6;
    localparam L2_WAIT         = 4'd7;
    localparam L2_COMPUTE      = 4'd8;
    localparam L2_COMPUTE_WAIT = 4'd9;  
    localparam L2_FIRE         = 4'd10;
    localparam L2_CLEAR        = 4'd11;
    localparam DONE            = 4'd12;

    reg [3:0] state;
    reg [$clog2(L1_IN):0] spike_cnt; 

    // Internal Spike Buffer
    reg [$clog2(L1_IN)-1:0] spike_buffer [0:L1_IN-1]; //memory containing indices of active input spikes

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state      <= IDLE;
            pe_en      <= 0;
            pe_clear   <= 0;
            neuron_en  <= 0;
            col_addr   <= 0;
            group      <= 0;
            layer_sel  <= 0;
            timestep   <= 0;
            active_pes <= PES;
            done       <= 0;
            next_index <= 0;
            spike_cnt  <= 0;
        end else begin
            pe_en      <= 0;
            pe_clear   <= 0;
            neuron_en  <= 0;
            done       <= 0;
            next_index <= 0;

            case (state)
                IDLE: begin
                    group     <= 0;
                    col_addr  <= 0;
                    layer_sel <= 0;
                    timestep  <= 0;
                    spike_cnt <= 0;
                    if (start) state <= L1_FETCH;
                end

                L1_FETCH: begin
                    if (spike_cnt < active_count) begin //how many are there
                        spike_buffer[spike_cnt] <= active_index; //stores the active index
                        next_index <= 1; //requests the next active index
                        spike_cnt  <= spike_cnt + 1;
                    end else begin
                        spike_cnt <= 0;
                        state     <= L1_WAIT;
                    end
                end

                L1_WAIT: begin
                    active_pes <= PES;  //use all 8 PEs
                    spike_cnt  <= 0;
                    if (active_count == 0) begin //if there isn't any spike, then skip computation
                        state <= L1_COMPUTE_WAIT; //zero skipping
                    end else begin
                        state <= L1_COMPUTE;
                    end
                end

                L1_COMPUTE: begin //where controller drives the PE computation, PE will accumulate these weights
                    pe_en    <= 1;
                    col_addr <= spike_buffer[spike_cnt]; 
                    
                    if (spike_cnt == active_count - 1) begin
                        state <= L1_COMPUTE_WAIT;
                    end else begin
                        spike_cnt <= spike_cnt + 1;
                    end
                end

                L1_COMPUTE_WAIT: begin //stop pe accumulation
                    pe_en    <= 0; 
                    col_addr <= 0;
                    state    <= L1_FIRE;
                end

                L1_FIRE: begin  //cur values are handed to the neuron logic
                    neuron_en <= 1;
                    pe_clear  <= 1; // cur represents the current timestep's input, don't want to carry it to the next timestep or group
                    state     <= L1_CLEAR;
                end

                L1_CLEAR: begin
                    if (group == L1_GROUPS - 1) begin //have all 16 groupes been processed
                        group     <= 0;
                        col_addr  <= 0;
                        layer_sel <= 1; //move to layer 2
                        state     <= L2_WAIT;
                    end else begin
                        group    <= group + 1; //otherwise increment the group num, need to finish all 128 neurons
                        col_addr <= 0;
                        state    <= L1_WAIT;
                    end
                end

                L2_WAIT: begin
                    col_addr   <= 0;
                    spike_cnt  <= 0; 
                    active_pes <= (group == L2_GROUPS - 1)
                                ? (L2_OUT % PES == 0 ? PES : L2_OUT % PES)
                                : PES; //2 groups
                    state <= L2_COMPUTE;
                end

                L2_COMPUTE: begin
                    pe_en    <= 1;
                    col_addr <= spike_cnt; 
                    
                    if (spike_cnt == L2_IN - 1) begin //not event driven, need to loop over all 128 
                        state <= L2_COMPUTE_WAIT;
                    end else begin
                        spike_cnt <= spike_cnt + 1; 
                    end
                end
                
                L2_COMPUTE_WAIT: begin
                    pe_en <= 0; 
                    state <= L2_FIRE;
                end

                L2_FIRE: begin
                    neuron_en <= 1;
                    pe_clear  <= 1; // Assert pe_clear early to correctly trigger spike_register reset
                    state     <= L2_CLEAR;
                end

                L2_CLEAR: begin //decides whether the whole timestep is complete
                    if (group == L2_GROUPS - 1) begin //processed both L2 groups
                        if (timestep == TSTEPS - 1) begin //completed all 20 timesteps
                            state <= DONE;
                        end else begin
                            timestep  <= timestep + 1;
                            group     <= 0;
                            col_addr  <= 0;
                            layer_sel <= 0;
                            spike_cnt <= 0;
                            state     <= L1_FETCH; 
                        end
                    end else begin
                        group    <= group + 1;
                        col_addr <= 0;
                        state    <= L2_WAIT;
                    end
                end

                DONE: begin
                    done  <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule