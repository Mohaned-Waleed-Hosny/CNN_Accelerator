`timescale 1ns / 1ps

module kernel_config_regs #(
    parameter KERNEL_DIM  = 3,
    parameter NUM_KERNELS = 4
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         wr_en,
    input  wire [1:0]   kernel_idx,
    input  wire [3:0]   weight_addr,
    input  wire signed [7:0] weight_data_in,
    input  wire [1:0]   active_kernel_sel,
    output reg  [(KERNEL_DIM*KERNEL_DIM*8)-1:0] active_weights_flat,
    output reg           kernel_ready
);
    localparam NUM_WEIGHTS    = KERNEL_DIM * KERNEL_DIM;
    localparam WORD_ADDR_BITS = $clog2(NUM_WEIGHTS);
    localparam BANK_ADDR_BITS = $clog2(NUM_KERNELS);
    localparam MEM_DEPTH      = 1 << (BANK_ADDR_BITS + WORD_ADDR_BITS);

    reg signed [7:0] weight_mem [0:MEM_DEPTH-1];

    wire [BANK_ADDR_BITS+WORD_ADDR_BITS-1:0] wr_addr = {kernel_idx, weight_addr[WORD_ADDR_BITS-1:0]};
    always @(posedge clk) begin
        if (wr_en && weight_addr < NUM_WEIGHTS)
            weight_mem[wr_addr] <= weight_data_in;
    end

    reg [1:0] last_sel;
    reg [WORD_ADDR_BITS-1:0] load_idx;
    reg loading;
    reg first_load_done;

    wire sel_changed = (active_kernel_sel != last_sel);
    wire [BANK_ADDR_BITS+WORD_ADDR_BITS-1:0] rd_addr = {active_kernel_sel, load_idx};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_idx         <= 0;
            loading          <= 1'b1;
            first_load_done  <= 1'b0;
            kernel_ready     <= 1'b0;
            last_sel         <= active_kernel_sel;
            active_weights_flat <= 0;
        end else if (!loading && (sel_changed || !first_load_done)) begin
            loading      <= 1'b1;
            load_idx     <= 0;
            kernel_ready <= 1'b0;
            last_sel     <= active_kernel_sel;
        end else if (loading) begin
            // Shift-register loading: prepends new weight byte and shifts right by 8 bits.
            // Eliminates dynamic demux steering logic across active_weights_flat.
            active_weights_flat <= {weight_mem[rd_addr], active_weights_flat} >> 8;
            if (load_idx == NUM_WEIGHTS-1) begin
                loading         <= 1'b0;
                kernel_ready    <= 1'b1;
                first_load_done <= 1'b1;
            end else begin
                load_idx <= load_idx + 1;
            end
        end
    end
endmodule