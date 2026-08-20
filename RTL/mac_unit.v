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
    // Set to "YES" to use DSP blocks, or "NO" to force synthesis into LUTs.
    parameter USE_DSP = "YES"
)(
    input  wire              clk,          // System Clock
    input  wire              rst_n,        // Active-Low Synchronous/Async Reset
    input  wire [7:0]        pixel_in,     // 8-bit Unsigned Input Pixel
    input  wire signed [7:0] weight_in,    // 8-bit Signed Kernel Weight
    output reg  signed [15:0] product_out  // 16-bit Signed Product Output
);

    wire signed [15:0] mult_result;
    
    // Explicit sign extension: Concatenate '0' to unsigned pixel to safely cast it to signed
    wire signed [8:0] pixel_signed = $signed({1'b0, pixel_in});

    // ========================================================================
    // Conditional Multiplier Generation
    // Synthesizer will safely ignore attributes meant for other vendor tools
    // ========================================================================
    generate
        if (USE_DSP == "NO") begin : gen_mult_logic
            // Force synthesis into fabric logic (LUTs/ALMs)
            (* multstyle = "logic" *)  // Intel Quartus attribute
            (* use_dsp = "no" *)       // Xilinx Vivado attribute
            wire signed [15:0] mult_logic_res;
            
            assign mult_logic_res = pixel_signed * weight_in;
            assign mult_result    = mult_logic_res;
            
        end else begin : gen_mult_dsp
            // Force synthesis into dedicated DSP blocks
            (* multstyle = "dsp" *)    // Intel Quartus attribute
            (* use_dsp = "yes" *)      // Xilinx Vivado attribute
            wire signed [15:0] mult_dsp_res;
            
            assign mult_dsp_res = pixel_signed * weight_in;
            assign mult_result  = mult_dsp_res;
        end
    endgenerate

    // ========================================================================
    // Pipelined Output Register
    // Enables timing closure at high clock frequencies
    // ========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_out <= 16'sd0;
        end else begin
            product_out <= mult_result;
        end
    end

endmodule