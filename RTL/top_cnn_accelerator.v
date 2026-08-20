// ============================================================================
// File Name:     top_cnn_accelerator.v
// Design Name:   Top-Level Convolutional Neural Network Accelerator
// Target Device: FPGA (Xilinx / Intel)
// Specifications:
//   - Architecture: Fully pipelined, 1 pixel/cycle throughput
//   - Memory:       0 BRAMs used (SRL and FF based)
//   - Features:     Multi-Kernel switching, optional ReLU, Saturation
// ============================================================================

`timescale 1ns / 1ps

module top_cnn_accelerator #(
    parameter IMAGE_WIDTH  = 32,
    parameter IMAGE_HEIGHT = 32,
    parameter KERNEL_DIM   = 3,
    parameter NUM_KERNELS  = 4
)(
    input  wire         clk,
    input  wire         rst_n,

    // ------------------------------------------------------------------------
    // Configuration Interface (Kernel Weights)
    // ------------------------------------------------------------------------
    input  wire         cfg_wr_en,
    input  wire [1:0]   cfg_kernel_idx,
    input  wire [3:0]   cfg_weight_addr,
    input  wire signed [7:0] cfg_weight_data,
    
    // ------------------------------------------------------------------------
    // Operational Control Interface
    // ------------------------------------------------------------------------
    input  wire [1:0]   active_kernel_sel,
    input  wire         relu_en,
    
    // ------------------------------------------------------------------------
    // Data Stream Interface (Input)
    // ------------------------------------------------------------------------
    input  wire         valid_in,
    input  wire [7:0]   pixel_in,

    // ------------------------------------------------------------------------
    // Data Stream Interface (Output)
    // ------------------------------------------------------------------------
    output wire         valid_out,
    output wire signed [15:0] pixel_out
);

    // ========================================================================
    // Internal Interconnect Signals
    // ========================================================================
    
    wire [71:0] active_weights_flat;
    wire        shift_en;
    
    // Explicit 3x3 Window Pixels
    wire [7:0] p00, p01, p02;
    wire [7:0] p10, p11, p12;
    wire [7:0] p20, p21, p22;
    
    wire signed [19:0] raw_sum;

    // ========================================================================
    // Sub-Module Instantiations
    // ========================================================================

    // 1. Kernel Configuration Registers
    kernel_config_regs #(
        .KERNEL_DIM(KERNEL_DIM),
        .NUM_KERNELS(NUM_KERNELS)
    ) u_kernel_config (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(cfg_wr_en),
        .kernel_idx(cfg_kernel_idx),
        .weight_addr(cfg_weight_addr),
        .weight_data_in(cfg_weight_data),
        .active_kernel_sel(active_kernel_sel),
        .active_weights_flat(active_weights_flat)
    );

    // 2. Control FSM (Synchronization & Shift Enable)
    control_fsm #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT)
    ) u_control_fsm (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .shift_en(shift_en),
        .valid_out(valid_out)
    );

    // 3. 3x3 Sliding Window Generator (BRAM-Free)
    window_generator #(
        .IMAGE_WIDTH(IMAGE_WIDTH)
    ) u_window_gen (
        .clk(clk),
        .rst_n(rst_n),
        .shift_en(shift_en),
        .pixel_in(pixel_in),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22)
    );

    // 4. Processing Element Array (MACs & Adder Tree)
    pe_array u_pe_array (
        .clk(clk),
        .rst_n(rst_n),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22),
        .active_weights_flat(active_weights_flat),
        .raw_sum(raw_sum)
    );

    // 5. Post Processing (Saturation & ReLU)
    post_processing u_post_proc (
        .clk(clk),
        .rst_n(rst_n),
        .relu_en(relu_en),
        .raw_sum(raw_sum),
        .pixel_out(pixel_out)
    );

endmodule