// ============================================================================
// File Name:     tb_kernel_config_regs.v
// Design Name:   Testbench for Programmable Multi-Kernel Weight Storage
// ============================================================================

`timescale 1ns / 1ps

module tb_kernel_config_regs;

    // ------------------------------------------------------------------------
    // Signals
    // ------------------------------------------------------------------------
    reg         clk;
    reg         rst_n;
    reg         wr_en;
    reg  [1:0]  kernel_idx;
    reg  [3:0]  weight_addr;
    reg  signed [7:0] weight_data_in;
    reg  [1:0]  active_kernel_sel;
    wire [71:0] active_weights_flat;

    integer errors;
    integer i;

    // ------------------------------------------------------------------------
    // UUT Instantiation
    // ------------------------------------------------------------------------
    kernel_config_regs #(
        .KERNEL_DIM(3),
        .NUM_KERNELS(4)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .kernel_idx(kernel_idx),
        .weight_addr(weight_addr),
        .weight_data_in(weight_data_in),
        .active_kernel_sel(active_kernel_sel),
        .active_weights_flat(active_weights_flat)
    );

    // ------------------------------------------------------------------------
    // Clock Generation
    // ------------------------------------------------------------------------
    always #5 clk = ~clk;

    // ------------------------------------------------------------------------
    // Main Test Sequence
    // ------------------------------------------------------------------------
    initial begin
        clk = 0;
        rst_n = 0;
        wr_en = 0;
        kernel_idx = 0;
        weight_addr = 0;
        weight_data_in = 0;
        active_kernel_sel = 0;
        errors = 0;

        // Apply Reset
        #15;
        rst_n = 1;
        #10;
        
        $display("==================================================");
        $display("   Starting Kernel Config Register Testbench      ");
        $display("==================================================");

        // 1. Write a Sobel-X Kernel into Bank 0
        // [-1, 0, 1]
        // [-2, 0, 2]
        // [-1, 0, 1]
        write_weight(0, 0, -8'sd1); write_weight(0, 1, 8'sd0);  write_weight(0, 2, 8'sd1);
        write_weight(0, 3, -8'sd2); write_weight(0, 4, 8'sd0);  write_weight(0, 5, 8'sd2);
        write_weight(0, 6, -8'sd1); write_weight(0, 7, 8'sd0);  write_weight(0, 8, 8'sd1);

        // 2. Write a Simple Blur Kernel into Bank 1
        // [1, 1, 1]
        // [1, 1, 1]
        // [1, 1, 1]
        for (i = 0; i < 9; i = i + 1) begin
            write_weight(1, i, 8'sd1);
        end

        // 3. Test Bank 0 Output (Sobel-X)
        active_kernel_sel = 0;
        #10; // Wait for combinational logic
        verify_weight(0, 0, -8'sd1);
        verify_weight(0, 3, -8'sd2);
        verify_weight(0, 5, 8'sd2);

        // 4. Test Bank 1 Output (Blur)
        active_kernel_sel = 1;
        #10;
        verify_weight(1, 0, 8'sd1);
        verify_weight(1, 4, 8'sd1);
        verify_weight(1, 8, 8'sd1);

        // 5. Test Bank 2 Output (Should be 0 from reset)
        active_kernel_sel = 2;
        #10;
        verify_weight(2, 4, 8'sd0);

        // Summary
        $display("==================================================");
        if (errors == 0) begin
            $display("   TEST PASSED SUCCESSFULLY! All banks matched.   ");
        end else begin
            $display("   TEST FAILED! Total errors detected: %d", errors);
        end
        $display("==================================================");
        $finish;
    end

    // ------------------------------------------------------------------------
    // Tasks
    // ------------------------------------------------------------------------
    task write_weight(input [1:0] k_idx, input [3:0] addr, input signed [7:0] data);
        begin
            @(negedge clk);
            wr_en = 1;
            kernel_idx = k_idx;
            weight_addr = addr;
            weight_data_in = data;
            @(negedge clk);
            wr_en = 0;
        end
    endtask

    task verify_weight(input [1:0] expected_bank, input [3:0] addr, input signed [7:0] expected_val);
        reg signed [7:0] actual_val;
        begin
            // Extract the specific 8-bit slice from the flattened output
            actual_val = active_weights_flat[(addr*8) +: 8];
            
            if (actual_val !== expected_val) begin
                $display("[ERROR] Bank %0d, Addr %0d | Expected: %4d | Got: %4d", 
                         expected_bank, addr, expected_val, actual_val);
                errors = errors + 1;
            end else begin
                $display("[SUCCESS] Bank %0d, Addr %0d correctly read as %4d", 
                         expected_bank, addr, actual_val);
            end
        end
    endtask

endmodule