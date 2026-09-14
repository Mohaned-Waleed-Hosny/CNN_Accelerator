`timescale 1ns / 1ps

module control_fsm #(
    parameter IMAGE_WIDTH      = 32,
    parameter IMAGE_HEIGHT     = 32,
    parameter KERNEL_DIM       = 3,
    parameter DATAPATH_LATENCY = 4
) (
    input  wire clk,
    input  wire rst_n,
    input  wire valid_in,
    output wire shift_en,
    output wire valid_out
);

    assign shift_en = valid_in;

    // FLATTENED COUNTER OPTIMIZATION:
    // Replaces dual 5-bit col/row counters with a single linear counter over TOTAL_PIXELS.
    // Eliminates nested comparator priority encoders and multi-adder LUT overhead.
    localparam TOTAL_PIXELS = IMAGE_WIDTH * IMAGE_HEIGHT;
    localparam CNT_WIDTH    = (TOTAL_PIXELS > 1) ? $clog2(TOTAL_PIXELS) : 1;
    localparam COL_WIDTH    = (IMAGE_WIDTH > 1) ? $clog2(IMAGE_WIDTH) : 1;

    reg [CNT_WIDTH-1:0] pixel_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_cnt <= {CNT_WIDTH{1'b0}};
        end else if (valid_in) begin
            if (pixel_cnt == TOTAL_PIXELS - 1) begin
                pixel_cnt <= {CNT_WIDTH{1'b0}};
            end else begin
                pixel_cnt <= pixel_cnt + 1'b1;
            end
        end
    end

    // Extract col and row indices from flat index.
    // Modulo and division by constant power-of-2 dimensions infer 0-LUT bit slices in synthesis.
    wire [COL_WIDTH-1:0] col_cnt = pixel_cnt % IMAGE_WIDTH;
    wire [CNT_WIDTH-1:0] row_cnt = pixel_cnt / IMAGE_WIDTH;

    wire valid_window;
    assign valid_window = valid_in && 
                          (col_cnt >= KERNEL_DIM - 1) && 
                          (row_cnt >= KERNEL_DIM - 1);

    reg [DATAPATH_LATENCY-1:0] valid_pipeline;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_pipeline <= {DATAPATH_LATENCY{1'b0}};
        end else begin
            valid_pipeline <= {valid_pipeline[DATAPATH_LATENCY-2:0], valid_window};
        end
    end

    assign valid_out = valid_pipeline[DATAPATH_LATENCY-1];

endmodule