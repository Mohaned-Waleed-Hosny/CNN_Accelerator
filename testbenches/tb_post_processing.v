// ============================================================================
// File Name:     tb_post_processing.v
// Design Name:   Automated Testbench for Post-Processing Unit
// ============================================================================

`timescale 1ns / 1ps

module tb_post_processing;

    // ------------------------------------------------------------------------
    // Signals
    // ------------------------------------------------------------------------
    reg         clk;
    reg         rst_n;
    reg         relu_en;
    reg  signed [19:0] raw_sum;
    wire signed [15:0] pixel_out;

    integer errors;

    // ------------------------------------------------------------------------
    // UUT Instantiation
    // ------------------------------------------------------------------------
    post_processing uut (
        .clk(clk),
        .rst_n(rst_n),
        .relu_en(relu_en),
        .raw_sum(raw_sum),
        .pixel_out(pixel_out)
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
        clk     = 0;
        rst_n   = 0;
        relu_en = 0;
        raw_sum = 0;
        errors  = 0;

        // Apply Reset
        #15;
        rst_n = 1;
        #10;

        $display("==================================================");
        $display("   Starting Post-Processing Testbench             ");
        $display("==================================================");

        // --------------------------------------------------------------------
        // Group 1: Normal Range (No Saturation, No ReLU)
        // --------------------------------------------------------------------
        relu_en = 0;
        apply_test(20'sd15000,  16'sd15000, "Normal Positive Passthrough");
        apply_test(-20'sd20000, -16'sd20000, "Normal Negative Passthrough");

        // --------------------------------------------------------------------
        // Group 2: Saturation Logic (Overflow Clipping)
        // --------------------------------------------------------------------
        // Provide a value much larger than 32767
        apply_test(20'sd100000, 16'sd32767, "Positive Overflow Saturation");
        
        // Provide a value much smaller than -32768
        apply_test(-20'sd250000, -16'sd32768, "Negative Overflow Saturation");

        // --------------------------------------------------------------------
        // Group 3: ReLU Activation Bonus Logic
        // --------------------------------------------------------------------
        relu_en = 1;
        
        // Positive numbers should remain unchanged
        apply_test(20'sd12000, 16'sd12000, "ReLU Enabled - Positive Number");
        
        // Negative numbers within bounds should become 0
        apply_test(-20'sd5000, 16'sd0, "ReLU Enabled - Negative Number to 0");
        
        // Negative numbers that overflow should STILL become 0
        apply_test(-20'sd250000, 16'sd0, "ReLU Enabled - Neg Overflow to 0");

        // --------------------------------------------------------------------
        // Summary
        // --------------------------------------------------------------------
        $display("==================================================");
        if (errors == 0) begin
            $display("   TEST PASSED SUCCESSFULLY! All modes working.");
        end else begin
            $display("   TEST FAILED! Total errors detected: %0d", errors);
        end
        $display("==================================================");
        $finish;
    end

    // ------------------------------------------------------------------------
    // Verification Task
    // ------------------------------------------------------------------------
    task apply_test(
        input signed [19:0] test_in,
        input signed [15:0] expected_out,
        input [800:0] test_name // string holder
    );
        begin
            raw_sum = test_in;
            @(posedge clk);
            #1; // Delay to sample the registered output

            if (pixel_out !== expected_out) begin
                $display("[ERROR] %s | In: %0d | Expected: %0d | Got: %0d", 
                         test_name, test_in, expected_out, pixel_out);
                errors = errors + 1;
            end else begin
                $display("[SUCCESS] %s | In: %0d -> Out: %0d", 
                         test_name, test_in, pixel_out);
            end
        end
    endtask

endmodule