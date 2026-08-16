// ============================================================================
// File Name:     kernel_config_regs.v
// Design Name:   Programmable Multi-Kernel Weight Storage
// Target Device: FPGA (Xilinx / Intel)
// Specifications:
//   - Storage:      4 banks of 3x3 kernels (configurable up to NUM_KERNELS)
//   - Precision:    8-bit Signed fixed-point per weight
//   - Architecture: standard Flip-Flops (0 BRAMs used to optimize FOM)
// ============================================================================

`timescale 1ns / 1ps

module kernel_config_regs #(
    parameter KERNEL_DIM  = 3,  // 3x3 kernel
    parameter NUM_KERNELS = 4   // Support 4 different kernels for the bonus
)(
    input  wire         clk,
    input  wire         rst_n,
    
    // Configuration Interface
    input  wire         wr_en,
    input  wire [1:0]   kernel_idx,        // Selects which of the 4 banks to write to
    input  wire [3:0]   weight_addr,       // Selects which of the 9 weights to write (0 to 8)
    input  wire signed [7:0] weight_data_in,
    
    // Operational Interface
    input  wire [1:0]   active_kernel_sel, // Selects which bank drives the compute array
    
    // Flattened Output (9 weights * 8 bits = 72 bits)
    output wire [(KERNEL_DIM*KERNEL_DIM*8)-1:0] active_weights_flat
);

    localparam NUM_WEIGHTS = KERNEL_DIM * KERNEL_DIM;

    // 2D Array: [Kernel Bank 0-3][Weight Index 0-8]
    reg signed [7:0] weight_bank [0:NUM_KERNELS-1][0:NUM_WEIGHTS-1];

    integer i, j;

    // ------------------------------------------------------------------------
    // Write Logic (Synchronous)
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Clear all weights on reset
            for (i = 0; i < NUM_KERNELS; i = i + 1) begin
                for (j = 0; j < NUM_WEIGHTS; j = j + 1) begin
                    weight_bank[i][j] <= 8'sd0;
                end
            end
        end else if (wr_en) begin
            // Prevent out-of-bounds writes
            if (weight_addr < NUM_WEIGHTS) begin
                weight_bank[kernel_idx][weight_addr] <= weight_data_in;
            end
        end
    end

    // ------------------------------------------------------------------------
    // Read Logic (Combinational flattening of the selected kernel)
    // ------------------------------------------------------------------------
    genvar g;
    generate
        for (g = 0; g < NUM_WEIGHTS; g = g + 1) begin : gen_flatten
            assign active_weights_flat[(g*8) +: 8] = weight_bank[active_kernel_sel][g];
        end
    endgenerate

endmodule