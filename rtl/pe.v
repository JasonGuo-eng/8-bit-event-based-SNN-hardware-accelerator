module pe #(
    parameter integer DATA_WIDTH = 8,
    parameter integer ACC_WIDTH  = 18 //wide since we need to add a lot of weights together
)(
    input  wire                         clk,
    input  wire                         reset_n,
    input  wire                         en,
    input  wire                         clear,
    input  wire signed [DATA_WIDTH-1:0] weight,
    
    output wire signed [ACC_WIDTH-1:0]  cur_out,
    output reg                          valid
);

    reg signed [ACC_WIDTH-1:0] accumulator;
    reg                        en_q;    //tracking the old en value 

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            accumulator <= 0;
            valid       <= 1'b0;
            en_q        <= 1'b0;
        end else begin
            en_q <= en; 

            if (clear) begin //starts a new accumulation
                accumulator <= 0;
                valid       <= 1'b0; //as we haven't finished with new accumulation yet
            end else if (en) begin
                // FIX: Explicitly sign-extend weight to ACC_WIDTH to prevent toolchain artifacts when handling negatives
                accumulator <= accumulator + {{ (ACC_WIDTH-DATA_WIDTH){weight[DATA_WIDTH-1]} }, weight};
                valid <= 1'b0; //still accumulating, the result isn't ready yet
            end else begin
                if (en_q == 1'b1 && en == 1'b0)
                    valid <= 1'b1;   //means the cur_out is finalized, and tells if neuron that it's safe to take this value into membrane potential
                else
                    valid <= 1'b0;   
            end
        end
    end

    assign cur_out = accumulator;

endmodule 

