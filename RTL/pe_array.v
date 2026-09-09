`timescale 1ns / 1ps

module pe_array #(
    parameter KERNEL_DIM = 3,
    parameter USE_DSP    = "YES"
)(
    input  wire clk,
    input  wire rst_n,
    
    // Flattened Ports
    input  wire [(KERNEL_DIM*KERNEL_DIM*8)-1:0] window_flat,
    input  wire [(KERNEL_DIM*KERNEL_DIM*8)-1:0] active_weights_flat,
    
    output reg  signed [19:0] raw_sum
);

    localparam NUM_MACS = KERNEL_DIM * KERNEL_DIM;

    // Array of outputs from all MACs
    wire signed [15:0] products [0:NUM_MACS-1];

    // Instantiate Parameterized MACs
    genvar g;
    generate
        for (g = 0; g < NUM_MACS; g = g + 1) begin : gen_macs
            mac_unit #(.USE_DSP(USE_DSP)) u_mac (
                .clk(clk),
                .rst_n(rst_n),
                .pixel_in(window_flat[(g*8) +: 8]),
                .weight_in(active_weights_flat[(g*8) +: 8]),
                .product_out(products[g])
            );
        end
    endgenerate

    // Parameterized Summation (1 Pipeline Stage for Accumulation)
    // Synthesis tools will map this combinatorial loop to adder trees/cascades automatically.
    integer i;
    reg signed [19:0] next_sum;

    always @(*) begin
        next_sum = 20'sd0;
        for (i = 0; i < NUM_MACS; i = i + 1) begin
            next_sum = next_sum + products[i];
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            raw_sum <= 20'sd0;
        end else begin
            raw_sum <= next_sum;
        end
    end

endmodule