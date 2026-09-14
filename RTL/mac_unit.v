`timescale 1ns / 1ps

module mac_unit #(
    parameter USE_DSP = "YES"
)(
    input  wire              clk,          
    input  wire              rst_n,
    input  wire              shift_en,     // ADDED: Clock gating control signal
    input  wire [7:0]        pixel_in,     
    input  wire signed [7:0] weight_in,    
    output reg  signed [15:0] product_out  
);

    wire signed [15:0] mult_result;
    // Single zero-bit padding for exact 9-bit signed conversion
    wire signed [8:0]  pixel_signed = $signed({1'b0, pixel_in}); 

    generate
        if (USE_DSP == "NO") begin : gen_mult_logic
            (* multstyle = "logic", use_dsp = "no" *) 
            wire signed [15:0] mult_logic_res;
            assign mult_logic_res = pixel_signed * weight_in;
            assign mult_result    = mult_logic_res;
        end else begin : gen_mult_dsp
            (* multstyle = "dsp", use_dsp = "yes" *)  
            wire signed [15:0] mult_dsp_res;
            assign mult_dsp_res = pixel_signed * weight_in;
            assign mult_result  = mult_dsp_res;
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_out <= 16'sd0;
        end else if (shift_en) begin       // ADDED: Register update conditionally toggled
            product_out <= mult_result;
        end
    end
endmodule