`timescale 1ns / 1ps

module post_processing (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               shift_en,
    input  wire               relu_en,    
    input  wire signed [19:0] raw_sum,    
    output reg  signed [15:0] pixel_out   
);

    wire in_range = (raw_sum[19:15] == {5{raw_sum[15]}});

    wire signed [15:0] saturated_sum;

    assign saturated_sum = in_range   ? raw_sum[15:0] :
                           raw_sum[19] ? -16'sd32768   :
                                          16'sd32767;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_out <= 16'sd0;
        end else if (shift_en) begin
            if (relu_en && saturated_sum[15]) begin
                pixel_out <= 16'sd0;
            end else begin
                pixel_out <= saturated_sum;
            end
        end
    end
endmodule