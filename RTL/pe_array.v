`timescale 1ns / 1ps

module pe_array #(
    parameter KERNEL_DIM  = 3,
    parameter USE_DSP     = "YES",
    parameter GROUP_SIZE  = 3
)(
    input  wire clk,
    input  wire rst_n,
    input  wire shift_en,
    input  wire [(KERNEL_DIM*KERNEL_DIM*8)-1:0] window_flat,
    input  wire [(KERNEL_DIM*KERNEL_DIM*8)-1:0] active_weights_flat,
    output reg  signed [19:0] raw_sum
);

    localparam NUM_MACS   = KERNEL_DIM * KERNEL_DIM;
    localparam NUM_GROUPS = (NUM_MACS + GROUP_SIZE - 1) / GROUP_SIZE;

    wire signed [15:0] products [0:NUM_MACS-1];

    genvar g;
    generate
        for (g = 0; g < NUM_MACS; g = g + 1) begin : gen_macs
            mac_unit #(.USE_DSP(USE_DSP)) u_mac (
                .clk(clk),
                .rst_n(rst_n),
                .shift_en(shift_en),
                .pixel_in(window_flat[(g*8) +: 8]),
                .weight_in(active_weights_flat[(g*8) +: 8]),
                .product_out(products[g])
            );
        end
    endgenerate

    wire signed [19:0] group_partial [0:NUM_GROUPS-1];

    genvar gr;
    generate
        for (gr = 0; gr < NUM_GROUPS; gr = gr + 1) begin : gen_groups
            localparam THIS_GROUP_SIZE = ((gr + 1) * GROUP_SIZE > NUM_MACS) ? 
                                         (NUM_MACS - (gr * GROUP_SIZE)) : 
                                         GROUP_SIZE;

            reg signed [19:0] acc_c [0:THIS_GROUP_SIZE];
            integer s;

            always @(*) begin
                acc_c[0] = 20'sd0;
                for (s = 0; s < THIS_GROUP_SIZE; s = s + 1)
                    acc_c[s+1] = acc_c[s] + products[gr*GROUP_SIZE + s];
            end

            reg signed [19:0] group_partial_reg;
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) group_partial_reg <= 20'sd0;
                else if (shift_en) group_partial_reg <= acc_c[THIS_GROUP_SIZE];
            end

            assign group_partial[gr] = group_partial_reg;
        end
    endgenerate

    integer i;
    reg signed [19:0] next_sum;
    always @(*) begin
        next_sum = 20'sd0;
        for (i = 0; i < NUM_GROUPS; i = i + 1) begin
            next_sum = next_sum + group_partial[i];
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) raw_sum <= 20'sd0;
        else if (shift_en) raw_sum <= next_sum;
    end

endmodule