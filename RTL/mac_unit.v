`timescale 1ns / 1ps

module mac_unit #(
    parameter USE_DSP = "YES"
)(
    input  wire              clk,          
    input  wire              rst_n,        
    input  wire [7:0]        pixel_in,     
    input  wire signed [7:0] weight_in,    
    output reg  signed [15:0] product_out  
);

    wire signed [15:0] mult_result;
    wire signed [9:0] pixel_signed = $signed({2'b00, pixel_in}); // Padded safely

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
        end else begin
            product_out <= mult_result;
        end
    end
endmodule