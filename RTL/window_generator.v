`timescale 1ns / 1ps

module window_generator #(
    parameter IMAGE_WIDTH = 32,
    parameter KERNEL_DIM  = 3
)(
    input  wire clk,
    input  wire rst_n,
    input  wire shift_en,
    input  wire [7:0] pixel_in,
    
    // Flattened Output Window (Size: KERNEL_DIM * KERNEL_DIM * 8 bits)
    output wire [(KERNEL_DIM*KERNEL_DIM*8)-1:0] window_flat
);

    integer r, c, i;

    // Line buffers: We need (KERNEL_DIM - 1) line buffers
    (* shreg_extract = "yes" *) reg [7:0] line_buf [0:KERNEL_DIM-2][0:IMAGE_WIDTH-1];
    
    // 2D Window Grid: [row][col]
    reg [7:0] window_grid [0:KERNEL_DIM-1][0:KERNEL_DIM-1];

    always @(posedge clk) begin
        if (shift_en) begin
            // 1. Shift internal line buffers
            for (r = 0; r < KERNEL_DIM-1; r = r + 1) begin
                for (i = IMAGE_WIDTH-1; i > 0; i = i - 1) begin
                    line_buf[r][i] <= line_buf[r][i-1];
                end
            end
            
            // 2. Feed line buffers
            line_buf[0][0] <= pixel_in; // First buffer gets incoming pixel
            for (r = 1; r < KERNEL_DIM-1; r = r + 1) begin
                line_buf[r][0] <= line_buf[r-1][IMAGE_WIDTH-1]; // Chain buffers
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (r = 0; r < KERNEL_DIM; r = r + 1) begin
                for (c = 0; c < KERNEL_DIM; c = c + 1) begin
                    window_grid[r][c] <= 8'd0;
                end
            end
        end else if (shift_en) begin
            // 1. Shift the grid horizontally
            for (r = 0; r < KERNEL_DIM; r = r + 1) begin
                for (c = 0; c < KERNEL_DIM-1; c = c + 1) begin
                    window_grid[r][c] <= window_grid[r][c+1];
                end
            end
            
            // 2. Feed the newest column of the grid
            window_grid[KERNEL_DIM-1][KERNEL_DIM-1] <= pixel_in; // Bottom-right is newest pixel
            for (r = 0; r < KERNEL_DIM-1; r = r + 1) begin
                // Older rows receive delayed pixels from the end of respective line buffers
                window_grid[r][KERNEL_DIM-1] <= line_buf[KERNEL_DIM-2-r][IMAGE_WIDTH-1];
            end
        end
    end

    // Flatten the 2D grid to the 1D output port
    genvar gr, gc;
    generate
        for (gr = 0; gr < KERNEL_DIM; gr = gr + 1) begin : gen_flat_r
            for (gc = 0; gc < KERNEL_DIM; gc = gc + 1) begin : gen_flat_c
                localparam IDX = (gr * KERNEL_DIM) + gc;
                assign window_flat[(IDX*8) +: 8] = window_grid[gr][gc];
            end
        end
    endgenerate

endmodule