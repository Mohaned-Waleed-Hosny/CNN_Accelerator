// ============================================================================
// File Name:     window_generator.v
// Design Name:   BRAM-Free 3x3 Sliding Window Generator (Explicit Ports)
// Target Device: FPGA (Xilinx / Intel)
// ============================================================================

`timescale 1ns / 1ps

module window_generator #(
    parameter IMAGE_WIDTH = 32 // Required minimum input size
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        shift_en,
    input  wire [7:0]  pixel_in,
    
    // Explicit 3x3 Window Ports
    // Oldest Row (Top)
    output reg  [7:0]  p00, p01, p02,
    // Middle Row
    output reg  [7:0]  p10, p11, p12,
    // Newest Row (Bottom)
    output reg  [7:0]  p20, p21, p22
);

    integer i;

    // ------------------------------------------------------------------------
    // Memory Primitives for Line Buffers
    // ------------------------------------------------------------------------
    // No reset logic here to ensure mapping to Shift Register LUTs (SRLs)
    (* shreg_extract = "yes" *) reg [7:0] line_buf_0 [0:IMAGE_WIDTH-1];
    (* shreg_extract = "yes" *) reg [7:0] line_buf_1 [0:IMAGE_WIDTH-1];

    // ------------------------------------------------------------------------
    // Datapath & Shifting Logic
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        if (shift_en) begin
            // Shift Line Buffers
            for (i = IMAGE_WIDTH-1; i > 0; i = i - 1) begin
                line_buf_0[i] <= line_buf_0[i-1];
                line_buf_1[i] <= line_buf_1[i-1];
            end
            line_buf_0[0] <= pixel_in;
            line_buf_1[0] <= line_buf_0[IMAGE_WIDTH-1];
        end
    end

    // Shift the 3x3 Window Grid
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p00 <= 8'd0; p01 <= 8'd0; p02 <= 8'd0;
            p10 <= 8'd0; p11 <= 8'd0; p12 <= 8'd0;
            p20 <= 8'd0; p21 <= 8'd0; p22 <= 8'd0;
        end else if (shift_en) begin
            // Shift Oldest Row (Receives data from delayed buffer 1)
            p02 <= line_buf_1[IMAGE_WIDTH-1];
            p01 <= p02;
            p00 <= p01;

            // Shift Middle Row (Receives data from delayed buffer 0)
            p12 <= line_buf_0[IMAGE_WIDTH-1];
            p11 <= p12;
            p10 <= p11;

            // Shift Newest Row (Receives fresh incoming pixels)
            p22 <= pixel_in;
            p21 <= p22;
            p20 <= p21;
        end
    end

endmodule