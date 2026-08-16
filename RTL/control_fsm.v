// ============================================================================
// File Name:     control_fsm.v
// Design Name:   Convolution Controller and Pipeline Synchronizer
// Target Device: FPGA (Xilinx / Intel)
// Specifications:
//   - Tracks 2D image boundaries (row and column counters).
//   - Generates shift enables for the sliding window generator.
//   - Delays the valid signal to perfectly match the 6-cycle datapath latency.
// ============================================================================

`timescale 1ns / 1ps

module control_fsm #(
    parameter IMAGE_WIDTH  = 32,
    parameter IMAGE_HEIGHT = 32
) (
    input wire clk,
    input wire rst_n,

    // Input Stream Control
    input wire valid_in,  // High when incoming pixel is valid

    // Internal Datapath Control
    output wire shift_en,  // Enables the window_generator line buffers

    // Output Stream Control
    output wire valid_out  // High when the final post-processed pixel is ready
);

  // ------------------------------------------------------------------------
  // 1. Shift Enable Logic
  // ------------------------------------------------------------------------
  // The window generator should only shift when we receive a valid pixel.
  assign shift_en = valid_in;

  // ------------------------------------------------------------------------
  // 2. Image Coordinate Tracking
  // ------------------------------------------------------------------------
  // We need counters large enough to hold the maximum dimension
  reg [15:0] col_cnt;
  reg [15:0] row_cnt;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      col_cnt <= 16'd0;
      row_cnt <= 16'd0;
    end else if (valid_in) begin
      if (col_cnt == IMAGE_WIDTH - 1) begin
        col_cnt <= 16'd0;
        if (row_cnt == IMAGE_HEIGHT - 1) begin
          row_cnt <= 16'd0;  // End of frame, wrap around
        end else begin
          row_cnt <= row_cnt + 1;
        end
      end else begin
        col_cnt <= col_cnt + 1;
      end
    end
  end

  // ------------------------------------------------------------------------
  // 3. Valid Window Detection
  // ------------------------------------------------------------------------
  // A 3x3 convolution window is strictly valid only when:
  // We have shifted in at least 2 full rows (row_cnt >= 2)
  // AND we have shifted in at least 3 pixels of the current row (col_cnt >= 2)
  // AND valid_in is high (we just completed a new valid window shift)

  wire valid_window;
  assign valid_window = valid_in && (col_cnt >= 2) && (row_cnt >= 2);

  // ------------------------------------------------------------------------
  // 4. Pipeline Latency Synchronization
  // ------------------------------------------------------------------------
  // The computational datapath takes exactly 6 clock cycles:
  // PE Array MAC       = 1 cycle
  // PE Array Adders    = 4 cycles
  // Post Processing    = 1 cycle
  // Total Datapath Lat = 6 cycles
  // We must delay the 'valid_window' signal by exactly 6 cycles.

  reg [5:0] valid_pipeline;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_pipeline <= 6'd0;
    end else begin
      // Shift register for the valid signal
      valid_pipeline <= {valid_pipeline[4:0], valid_window};
    end
  end

  // The MSB of the pipeline is the final synchronized valid_out
  assign valid_out = valid_pipeline[5];

endmodule
