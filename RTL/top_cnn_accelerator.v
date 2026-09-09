`timescale 1ns / 1ps

module top_cnn_accelerator #(
    parameter IMAGE_WIDTH  = 32,
    parameter IMAGE_HEIGHT = 32,
    parameter KERNEL_DIM   = 3,
    parameter NUM_KERNELS  = 4,
    parameter USE_DSP      = "YES" // Now accessible at top-level
)(
    input  wire         clk,
    input  wire         rst_n,

    // Configuration
    input  wire         cfg_wr_en,
    input  wire [1:0]   cfg_kernel_idx,
    input  wire [7:0]   cfg_weight_addr,
    input  wire signed [7:0] cfg_weight_data,
    
    // Operation
    input  wire [1:0]   active_kernel_sel,
    input  wire         relu_en,
    
    // Input Stream
    input  wire         valid_in,
    input  wire [7:0]   pixel_in,

    // Output Stream
    output wire         valid_out,
    output wire signed [15:0] pixel_out
);

    wire [(KERNEL_DIM*KERNEL_DIM*8)-1:0] active_weights_flat;
    wire [(KERNEL_DIM*KERNEL_DIM*8)-1:0] window_flat;
    
    wire shift_en;
    wire signed [19:0] raw_sum;

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

    control_fsm #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .KERNEL_DIM(KERNEL_DIM),
        .DATAPATH_LATENCY(4) // 1 MAC, 1 PE Add, 1 PostProc
    ) u_control_fsm (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .shift_en(shift_en),
        .valid_out(valid_out)
    );

    window_generator #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .KERNEL_DIM(KERNEL_DIM)
    ) u_window_gen (
        .clk(clk),
        .rst_n(rst_n),
        .shift_en(shift_en),
        .pixel_in(pixel_in),
        .window_flat(window_flat)
    );

    pe_array #(
        .KERNEL_DIM(KERNEL_DIM),
        .USE_DSP(USE_DSP)
    ) u_pe_array (
        .clk(clk),
        .rst_n(rst_n),
        .window_flat(window_flat),
        .active_weights_flat(active_weights_flat),
        .raw_sum(raw_sum)
    );

    post_processing u_post_proc (
        .clk(clk),
        .rst_n(rst_n),
        .relu_en(relu_en),
        .raw_sum(raw_sum),
        .pixel_out(pixel_out)
    );

endmodule