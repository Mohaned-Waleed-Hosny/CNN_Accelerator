`timescale 1ns / 1ps

module post_processing (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               relu_en,    
    input  wire signed [19:0] raw_sum,    
    output reg  signed [15:0] pixel_out   
);

    // WIDTH/LOGIC OPTIMIZATION: a 20-bit signed value fits in 16 bits signed
    // exactly when its top 5 bits (raw_sum[19:15]) all equal the sign bit
    // (raw_sum[15]) -- i.e. the extra guard bits carry no real magnitude
    // information beyond what the 16-bit field already holds. This replaces
    // two full 20-bit magnitude comparisons (raw_sum > MAX, raw_sum < MIN)
    // with a single small equality/uniformity check, which is typically
    // cheaper in LUTs while being logically equivalent for detecting
    // whether raw_sum is in the representable 16-bit signed range.
    wire in_range = (raw_sum[19:15] == {5{raw_sum[15]}});

    wire signed [15:0] saturated_sum;

    assign saturated_sum = in_range   ? raw_sum[15:0] :
                           raw_sum[19] ? -16'sd32768   : // sign bit set -> negative overflow
                                          16'sd32767;    // sign bit clear -> positive overflow

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_out <= 16'sd0;
        end else begin
            if (relu_en && saturated_sum[15]) begin
                pixel_out <= 16'sd0;
            end else begin
                pixel_out <= saturated_sum;
            end
        end
    end
endmodule