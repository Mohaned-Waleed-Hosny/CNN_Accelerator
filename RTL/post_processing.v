`timescale 1ns / 1ps

module post_processing (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               relu_en,    
    input  wire signed [19:0] raw_sum,    
    output reg  signed [15:0] pixel_out   
);

    localparam signed [19:0] MAX_16BIT = 20'sd32767;
    localparam signed [19:0] MIN_16BIT = -20'sd32768;

    wire signed [15:0] saturated_sum;

    assign saturated_sum = (raw_sum > MAX_16BIT) ? 16'sd32767 :  
                           (raw_sum < MIN_16BIT) ? -16'sd32768 : 
                           raw_sum[15:0];                        

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