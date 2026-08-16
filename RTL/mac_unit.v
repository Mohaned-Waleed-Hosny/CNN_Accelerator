// ============================================================================
// File Name:     mac_unit.v
// Design Name:   Single Processing Element Multiplier Engine
// Target Device: FPGA (Xilinx / Intel)
// Specifications:
//   - Input Pixel:  8-bit Unsigned fixed-point [0 to 255]
//   - Input Weight: 8-bit Signed fixed-point [-128 to +127]
//   - Output:       16-bit Signed product [-32640 to +32385]
// ============================================================================

`timescale 1ns / 1ps

module mac_unit #(
    // Parameter to control DSP usage. 
    // Set to "NO" to force synthesis into fabric LUTs for FOM score optimization.
    parameter USE_DSP = "NO"
)(
    input  wire               clk,          // System Clock
    input  wire               rst_n,        // Active-Low Synchronous/Async Reset
    input  wire [7:0]         pixel_in,     // 8-bit Unsigned Input Pixel
    input  wire signed [7:0]  weight_in,    // 8-bit Signed Kernel Weight
    output reg  signed [15:0] product_out   // 16-bit Signed Product Output
);

    // Optional synthesis attribute forcing synthesis engine placement logic
    (* use_dsp = USE_DSP *) 
    wire signed [15:0] mult_result;

    // Explicit sign extension: Concatenate '0' to unsigned pixel prior to casting to signed
    assign mult_result = $signed({1'b0, pixel_in}) * weight_in;

    // Pipelined output register stage to enable timing closure at high clock frequencies
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_out <= 16'sd0;
        end else begin
            product_out <= mult_result;
        end
    end

endmodule