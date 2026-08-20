// ============================================================================
// File Name:     tb_top_cnn_accelerator.v
// Design Name:   Automated Integration Testbench for Top-Level Accelerator
// ============================================================================

`timescale 1ns / 1ps

module tb_top_cnn_accelerator;

    // ------------------------------------------------------------------------
    // Parameters & Signals
    // ------------------------------------------------------------------------
    localparam IMG_W = 8;
    localparam IMG_H = 8;
    localparam TOTAL_PIXELS = IMG_W * IMG_H;
    localparam EXPECTED_VALIDS = (IMG_W - 2) * (IMG_H - 2);

    reg         clk;
    reg         rst_n;
    
    // Configuration
    reg         cfg_wr_en;
    reg  [1:0]  cfg_kernel_idx;
    reg  [3:0]  cfg_weight_addr;
    reg  signed [7:0] cfg_weight_data;
    
    // Operation
    reg  [1:0]  active_kernel_sel;
    reg         relu_en;
    
    // Stream In
    reg         valid_in;
    reg  [7:0]  pixel_in;
    
    // Stream Out
    wire        valid_out;
    wire signed [15:0] pixel_out;

    integer cycle_count;
    integer total_valid_outs;
    integer errors;

    // ------------------------------------------------------------------------
    // UUT Instantiation
    // ------------------------------------------------------------------------
    top_cnn_accelerator #(
        .IMAGE_WIDTH(IMG_W),
        .IMAGE_HEIGHT(IMG_H)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_wr_en(cfg_wr_en),
        .cfg_kernel_idx(cfg_kernel_idx),
        .cfg_weight_addr(cfg_weight_addr),
        .cfg_weight_data(cfg_weight_data),
        .active_kernel_sel(active_kernel_sel),
        .relu_en(relu_en),
        .valid_in(valid_in),
        .pixel_in(pixel_in),
        .valid_out(valid_out),
        .pixel_out(pixel_out)
    );

    // ------------------------------------------------------------------------
    // Clock & Monitors
    // ------------------------------------------------------------------------
    always #5 clk = ~clk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_valid_outs = 0;
        end else if (valid_out) begin
            total_valid_outs = total_valid_outs + 1;
            $display("[T=%0t] Output #%0d Valid | Result = %d", 
                     $time, total_valid_outs, pixel_out);
        end
    end

    // ------------------------------------------------------------------------
    // Helper Tasks
    // ------------------------------------------------------------------------
    task write_weight(input [1:0] k_idx, input [3:0] addr, input signed [7:0] data);
        begin
            @(negedge clk);
            cfg_wr_en = 1;
            cfg_kernel_idx = k_idx;
            cfg_weight_addr = addr;
            cfg_weight_data = data;
            @(negedge clk);
            cfg_wr_en = 0;
        end
    endtask

    // ------------------------------------------------------------------------
    // Main Sequence
    // ------------------------------------------------------------------------
    initial begin
        // Init
        clk = 0; rst_n = 0; cycle_count = 0;
        cfg_wr_en = 0; cfg_kernel_idx = 0; cfg_weight_addr = 0; cfg_weight_data = 0;
        active_kernel_sel = 0; relu_en = 0;
        valid_in = 0; pixel_in = 0;
        errors = 0;

        #15;
        rst_n = 1;
        #10;

        $display("==================================================");
        $display("   Starting Top-Level CNN Accelerator Testbench   ");
        $display("   Image Size: 8x8                                ");
        $display("==================================================");

        // 1. Configure an Identity Kernel (x2 Multiplier) in Bank 0
        // Matrix:
        // [ 0,  0,  0 ]
        // [ 0,  2,  0 ]
        // [ 0,  0,  0 ]
        $display("--> Configuring Kernel Bank 0...");
        write_weight(0, 0, 8'd0); write_weight(0, 1, 8'd0); write_weight(0, 2, 8'd0);
        write_weight(0, 3, 8'd0); write_weight(0, 4, 8'd2); write_weight(0, 5, 8'd0); // Center = 2
        write_weight(0, 6, 8'd0); write_weight(0, 7, 8'd0); write_weight(0, 8, 8'd0);
        
        active_kernel_sel = 0;
        relu_en = 0;
        
        // Safely synchronize to the clock instead of using a hardcoded #20 delay
        @(negedge clk);
        @(negedge clk);

        // 2. Stream the 8x8 Image (Pixels 1 to 64)
        $display("--> Streaming 8x8 Input Image...");
        
        cycle_count = 1;
        while (cycle_count <= TOTAL_PIXELS) begin
            // 1. Apply the data
            valid_in = 1;
            pixel_in = cycle_count;
            
            // 2. Wait a full clock cycle
            @(negedge clk); 
            
            // 3. Increment ONLY after the clock cycle has passed
            cycle_count = cycle_count + 1;
        end
        
        // Stop streaming
        valid_in = 0;

        // 3. Wait for the pipeline to flush
        // Datapath is 6 cycles, let's wait 20 to be safe
        repeat(20) @(posedge clk);

        // 4. Verification Check
        $display("==================================================");
        if (total_valid_outs !== EXPECTED_VALIDS) begin
            $display("[ERROR] Expected %0d valid outputs, but got %0d.", EXPECTED_VALIDS, total_valid_outs);
            errors = errors + 1;
        end else begin
            $display("[SUCCESS] Correct number of output pixels generated (%0d).", EXPECTED_VALIDS);
        end

        if (errors == 0) begin
            $display("   TEST PASSED SUCCESSFULLY! Integration complete.");
        end else begin
            $display("   TEST FAILED! Total errors: %0d", errors);
        end
        $display("==================================================");
        $finish;
    end

endmodule