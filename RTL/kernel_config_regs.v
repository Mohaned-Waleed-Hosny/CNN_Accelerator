`timescale 1ns / 1ps

module kernel_config_regs #(
    parameter KERNEL_DIM  = 3,  
    parameter NUM_KERNELS = 4   
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         wr_en,
    input  wire [1:0]   kernel_idx,        
    input  wire [7:0]   weight_addr,       // Widened to 8 bits to support up to 16x16 kernels
    input  wire signed [7:0] weight_data_in,
    input  wire [1:0]   active_kernel_sel, 
    output wire [(KERNEL_DIM*KERNEL_DIM*8)-1:0] active_weights_flat
);

    localparam NUM_WEIGHTS = KERNEL_DIM * KERNEL_DIM;
    reg signed [7:0] weight_bank [0:NUM_KERNELS-1][0:NUM_WEIGHTS-1];

    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_KERNELS; i = i + 1) begin
                for (j = 0; j < NUM_WEIGHTS; j = j + 1) begin
                    weight_bank[i][j] <= 8'sd0;
                end
            end
        end else if (wr_en) begin
            if (weight_addr < NUM_WEIGHTS) begin
                weight_bank[kernel_idx][weight_addr] <= weight_data_in;
            end
        end
    end

    genvar g;
    generate
        for (g = 0; g < NUM_WEIGHTS; g = g + 1) begin : gen_flatten
            assign active_weights_flat[(g*8) +: 8] = weight_bank[active_kernel_sel][g];
        end
    endgenerate

endmodule