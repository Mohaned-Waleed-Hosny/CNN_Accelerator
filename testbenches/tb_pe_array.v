// ============================================================================
// File Name:     tb_pe_array.v
// Design Name:   Automated Testbench for Parallel PE Array
// ============================================================================

`timescale 1ns / 1ps

module tb_pe_array;

    // ------------------------------------------------------------------------
    // Signals
    // ------------------------------------------------------------------------
    reg         clk;
    reg         rst_n;
    
    reg  [7:0]  p00, p01, p02;
    reg  [7:0]  p10, p11, p12;
    reg  [7:0]  p20, p21, p22;
    
    reg  [71:0] active_weights_flat;
    wire signed [19:0] raw_sum;

    integer errors;

    // ------------------------------------------------------------------------
    // UUT Instantiation
    // ------------------------------------------------------------------------
    pe_array uut (
        .clk(clk),
        .rst_n(rst_n),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22),
        .active_weights_flat(active_weights_flat),
        .raw_sum(raw_sum)
    );

    // ------------------------------------------------------------------------
    // Clock Generation
    // ------------------------------------------------------------------------
    always #5 clk = ~clk;

    // ------------------------------------------------------------------------
    // Main Test Sequence
    // ------------------------------------------------------------------------
    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        p00=0; p01=0; p02=0;
        p10=0; p11=0; p12=0;
        p20=0; p21=0; p22=0;
        active_weights_flat = 72'd0;
        errors = 0;

        // Apply Reset
        #15;
        rst_n = 1;
        #10;

        $display("==================================================");
        $display("   Starting PE Array Pipelined Testbench          ");
        $display("==================================================");

        // --------------------------------------------------------------------
        // Test Case 1: Sobel-X Edge Detection Kernel
        // --------------------------------------------------------------------
        // Pixels:    1  2  3      Weights:  -1  0  1
        //            4  5  6                -2  0  2
        //            7  8  9                -1  0  1
        // --------------------------------------------------------------------
        // Mathematical Expectation:
        // (1*-1) + (2*0) + (3*1) = -1 + 0 + 3 = 2
        // (4*-2) + (5*0) + (6*2) = -8 + 0 + 12 = 4
        // (7*-1) + (8*0) + (9*1) = -7 + 0 + 9 = 2
        // Total Expected Sum = 2 + 4 + 2 = 8
        // --------------------------------------------------------------------
        
        // Feed Pixels
        p00=1; p01=2; p02=3;
        p10=4; p11=5; p12=6;
        p20=7; p21=8; p22=9;
        
        // Feed Weights (Packed into 72 bits)
        active_weights_flat = {
            8'sd1,  8'sd0, -8'sd1,   // w22, w21, w20
            8'sd2,  8'sd0, -8'sd2,   // w12, w11, w10
            8'sd1,  8'sd0, -8'sd1    // w02, w01, w00
        };

        // The pipeline depth is 5 cycles (1 MAC + 4 Adder Stages).
        // Wait exactly 5 clock cycles for the data to propagate.
        repeat(5) @(posedge clk);
        #1; // Wait a tiny delay after the 5th edge to sample the combinational output wire

        if (raw_sum !== 20'sd8) begin
            $display("[ERROR] Test Case 1 (Sobel-X) Failed. Expected: 8, Got: %0d", raw_sum);
            errors = errors + 1;
        end else begin
            $display("[SUCCESS] Test Case 1 (Sobel-X) Passed. Computed: %0d", raw_sum);
        end

        // --------------------------------------------------------------------
        // Test Case 2: Maximum Negative Saturation Check
        // --------------------------------------------------------------------
        // Pixels: Max Unsigned (255 everywhere)
        // Weights: Min Signed (-128 everywhere)
        // Expected: 9 * (255 * -128) = 9 * (-32640) = -293760
        // --------------------------------------------------------------------
        p00=255; p01=255; p02=255;
        p10=255; p11=255; p12=255;
        p20=255; p21=255; p22=255;
        
        active_weights_flat = {
            -8'sd128, -8'sd128, -8'sd128, 
            -8'sd128, -8'sd128, -8'sd128, 
            -8'sd128, -8'sd128, -8'sd128
        };

        repeat(5) @(posedge clk);
        #1;

        if (raw_sum !== -20'sd293760) begin
            $display("[ERROR] Test Case 2 (Min Saturation) Failed. Expected: -293760, Got: %0d", raw_sum);
            errors = errors + 1;
        end else begin
            $display("[SUCCESS] Test Case 2 (Min Saturation) Passed. Computed: %0d", raw_sum);
        end

        // --------------------------------------------------------------------
        // Test Result Summary
        // --------------------------------------------------------------------
        $display("==================================================");
        if (errors == 0) begin
            $display("   TEST PASSED SUCCESSFULLY! All pipelines matched.");
        end else begin
            $display("   TEST FAILED! Total errors detected: %0d", errors);
        end
        $display("==================================================");
        $finish;
    end

endmodule