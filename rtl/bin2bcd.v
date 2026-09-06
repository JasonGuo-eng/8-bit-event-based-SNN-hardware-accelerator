module bin2bcd (
    input  wire [13:0] bin,
    output reg  [3:0]  bcd4, bcd3, bcd2, bcd1, bcd0
);
    integer i;
    always @(bin) begin
        bcd4 = 0; bcd3 = 0; bcd2 = 0; bcd1 = 0; bcd0 = 0;
        for (i = 13; i >= 0; i = i - 1) begin
            if (bcd4 >= 5) bcd4 = bcd4 + 3;
            if (bcd3 >= 5) bcd3 = bcd3 + 3;
            if (bcd2 >= 5) bcd2 = bcd2 + 3;
            if (bcd1 >= 5) bcd1 = bcd1 + 3;
            if (bcd0 >= 5) bcd0 = bcd0 + 3;
            bcd4 = {bcd4[2:0], bcd3[3]};
            bcd3 = {bcd3[2:0], bcd2[3]};
            bcd2 = {bcd2[2:0], bcd1[3]};
            bcd1 = {bcd1[2:0], bcd0[3]};
            bcd0 = {bcd0[2:0], bin[i]};
        end
    end
endmodule