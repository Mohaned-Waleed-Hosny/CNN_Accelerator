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

    // Explicit 2D Counters replacing Modulo/Division logic
    localparam COL_WIDTH = (IMAGE_WIDTH > 1)  ? $clog2(IMAGE_WIDTH)  : 1;
    localparam ROW_WIDTH = (IMAGE_HEIGHT > 1) ? $clog2(IMAGE_HEIGHT) : 1;

    reg [COL_WIDTH-1:0] col_cnt;
    reg [ROW_WIDTH-1:0] row_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_cnt <= {COL_WIDTH{1'b0}};
            row_cnt <= {ROW_WIDTH{1'b0}};
        end else if (valid_in) begin
            if (col_cnt == IMAGE_WIDTH - 1) begin
                col_cnt <= {COL_WIDTH{1'b0}};
                if (row_cnt == IMAGE_HEIGHT - 1) begin
                    row_cnt <= {ROW_WIDTH{1'b0}};
                end else begin
                    row_cnt <= row_cnt + 1'b1;
                end
            end else begin
                col_cnt <= col_cnt + 1'b1;
            end
        end
    end

    wire valid_window = valid_in && 
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

    // BUG FIX: Pipeline Flush Optimization.
    // Keep the datapath shifting if there is STILL valid data propagating 
    // inside the pipeline, even if valid_in has dropped to 0.
    assign shift_en = valid_in | (|valid_pipeline);

    assign valid_out = valid_pipeline[DATAPATH_LATENCY-1];

endmodule