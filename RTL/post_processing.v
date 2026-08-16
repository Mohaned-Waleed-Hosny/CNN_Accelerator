// ============================================================================
// File Name:     post_processing.v
// Design Name:   Saturation and ReLU Post-Processing Unit
// Target Device: FPGA (Xilinx / Intel)
// Specifications:
//   - Input:        20-bit Signed raw accumulator sum
//   - Output:       16-bit Signed finalized pixel
//   - Features:     Positive/Negative Saturation (Clipping), Optional ReLU
// ============================================================================

`timescale 1ns / 1ps

module post_processing (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               relu_en,    // High = Enable ReLU, Low = Bypass ReLU
    input  wire signed [19:0] raw_sum,    // Wide accumulator sum from PE array
    output reg  signed [15:0] pixel_out   // Final 16-bit signed output
);

    // ------------------------------------------------------------------------
    // 1. Saturation (Clipping) Logic
    // ------------------------------------------------------------------------
    // The maximum and minimum values for a 16-bit signed integer:
    // Max Positive =  32767 (16'h7FFF)
    // Max Negative = -32768 (16'h8000)
    
    localparam signed [19:0] MAX_16BIT = 20'sd32767;
    localparam signed [19:0] MIN_16BIT = -20'sd32768;

    wire signed [15:0] saturated_sum;

    assign saturated_sum = (raw_sum > MAX_16BIT) ? 16'sd32767 :  // Clip positive overflow
                           (raw_sum < MIN_16BIT) ? -16'sd32768 : // Clip negative overflow
                           raw_sum[15:0];                        // Safe to truncate

    // ------------------------------------------------------------------------
    // 2. ReLU Activation & Pipeline Register
    // ------------------------------------------------------------------------
    // ReLU Function: f(x) = max(0, x)
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_out <= 16'sd0;
        end else begin
            // If ReLU is enabled and the value is negative (MSB is 1), output 0.
            // Otherwise, output the saturated sum.
            if (relu_en && saturated_sum[15]) begin
                pixel_out <= 16'sd0;
            end else begin
                pixel_out <= saturated_sum;
            end
        end
    end

endmodule