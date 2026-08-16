// ============================================================================
// File Name:     pe_array.v
// Design Name:   Parallel Processing Element Array (3x3)
// Target Device: FPGA (Xilinx / Intel)
// Specifications:
//   - Throughput:   1 output pixel per cycle
//   - Architecture: 9 Parallel MACs + 4-Stage Pipelined Adder Tree
//   - Output:       20-bit Signed Accumulator Output
// ============================================================================

`timescale 1ns / 1ps

module pe_array (
    input  wire        clk,
    input  wire        rst_n,
    
    // Explicit 3x3 Window Pixels (Unsigned 8-bit)
    input  wire [7:0]  p00, p01, p02,
    input  wire [7:0]  p10, p11, p12,
    input  wire [7:0]  p20, p21, p22,
    
    // Flattened Kernel Weights (Signed 8-bit, 9x8 = 72 bits)
    input  wire [71:0] active_weights_flat,
    
    // Wide Accumulator Output
    output reg  signed [19:0] raw_sum
);

    // ------------------------------------------------------------------------
    // 1. Unpack the Kernel Weights
    // ------------------------------------------------------------------------
    wire signed [7:0] w00 = active_weights_flat[ 7: 0];
    wire signed [7:0] w01 = active_weights_flat[15: 8];
    wire signed [7:0] w02 = active_weights_flat[23:16];
    
    wire signed [7:0] w10 = active_weights_flat[31:24];
    wire signed [7:0] w11 = active_weights_flat[39:32];
    wire signed [7:0] w12 = active_weights_flat[47:40];
    
    wire signed [7:0] w20 = active_weights_flat[55:48];
    wire signed [7:0] w21 = active_weights_flat[63:56];
    wire signed [7:0] w22 = active_weights_flat[71:64];

    // ------------------------------------------------------------------------
    // 2. Instantiate 9 Parallel MAC Units
    // ------------------------------------------------------------------------
    wire signed [15:0] prod00, prod01, prod02;
    wire signed [15:0] prod10, prod11, prod12;
    wire signed [15:0] prod20, prod21, prod22;

    mac_unit #(.USE_DSP("NO")) mac00 (.clk(clk), .rst_n(rst_n), .pixel_in(p00), .weight_in(w00), .product_out(prod00));
    mac_unit #(.USE_DSP("NO")) mac01 (.clk(clk), .rst_n(rst_n), .pixel_in(p01), .weight_in(w01), .product_out(prod01));
    mac_unit #(.USE_DSP("NO")) mac02 (.clk(clk), .rst_n(rst_n), .pixel_in(p02), .weight_in(w02), .product_out(prod02));
    
    mac_unit #(.USE_DSP("NO")) mac10 (.clk(clk), .rst_n(rst_n), .pixel_in(p10), .weight_in(w10), .product_out(prod10));
    mac_unit #(.USE_DSP("NO")) mac11 (.clk(clk), .rst_n(rst_n), .pixel_in(p11), .weight_in(w11), .product_out(prod11));
    mac_unit #(.USE_DSP("NO")) mac12 (.clk(clk), .rst_n(rst_n), .pixel_in(p12), .weight_in(w12), .product_out(prod12));
    
    mac_unit #(.USE_DSP("NO")) mac20 (.clk(clk), .rst_n(rst_n), .pixel_in(p20), .weight_in(w20), .product_out(prod20));
    mac_unit #(.USE_DSP("NO")) mac21 (.clk(clk), .rst_n(rst_n), .pixel_in(p21), .weight_in(w21), .product_out(prod21));
    mac_unit #(.USE_DSP("NO")) mac22 (.clk(clk), .rst_n(rst_n), .pixel_in(p22), .weight_in(w22), .product_out(prod22));

    // ------------------------------------------------------------------------
    // 3. Pipelined Adder Tree
    // ------------------------------------------------------------------------
    
    // Stage 1 Pipeline Registers (Sign-extended to 17 bits to prevent overflow)
    reg signed [16:0] add1_0, add1_1, add1_2, add1_3;
    reg signed [16:0] add1_p22_delay; // Delay matching for the odd 9th product

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            add1_0 <= 0; add1_1 <= 0; add1_2 <= 0; add1_3 <= 0;
            add1_p22_delay <= 0;
        end else begin
            add1_0 <= prod00 + prod01;
            add1_1 <= prod02 + prod10;
            add1_2 <= prod11 + prod12;
            add1_3 <= prod20 + prod21;
            add1_p22_delay <= prod22;
        end
    end

    // Stage 2 Pipeline Registers (Sign-extended to 18 bits)
    reg signed [17:0] add2_0, add2_1;
    reg signed [17:0] add2_p22_delay;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            add2_0 <= 0; add2_1 <= 0;
            add2_p22_delay <= 0;
        end else begin
            add2_0 <= add1_0 + add1_1;
            add2_1 <= add1_2 + add1_3;
            add2_p22_delay <= add1_p22_delay;
        end
    end

    // Stage 3 Pipeline Registers (Sign-extended to 19 bits)
    reg signed [18:0] add3_0;
    reg signed [18:0] add3_p22_delay;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            add3_0 <= 0;
            add3_p22_delay <= 0;
        end else begin
            add3_0 <= add2_0 + add2_1;
            add3_p22_delay <= add2_p22_delay;
        end
    end

    // Stage 4 Final Accumulation (Sign-extended to 20 bits)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            raw_sum <= 0;
        end else begin
            raw_sum <= add3_0 + add3_p22_delay;
        end
    end

endmodule