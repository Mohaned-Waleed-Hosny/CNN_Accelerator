// ============================================================================
// File Name:     tb_mac_unit.v
// Design Name:   Automated Self-Checking Testbench for mac_unit
// ============================================================================

`timescale 1ns / 1ps

module tb_mac_unit;

    // ------------------------------------------------------------------------
    // Signal Declarations
    // ------------------------------------------------------------------------
    reg         clk;
    reg         rst_n;
    reg  [7:0]  pixel_in;
    reg  signed [7:0] weight_in;
    wire signed [15:0] product_out;

    reg signed [15:0] expected_product;
    integer errors;

    // ------------------------------------------------------------------------
    // Unit Under Test (UUT) Instantiation
    // ------------------------------------------------------------------------
    mac_unit #(
        .USE_DSP("NO") // Test fabric LUT synthesis path
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_in(pixel_in),
        .weight_in(weight_in),
        .product_out(product_out)
    );

    // ------------------------------------------------------------------------
    // Clock Generation (100 MHz System Clock -> 10 ns Period)
    // ------------------------------------------------------------------------
    always #5 clk = ~clk;

    // ------------------------------------------------------------------------
    // Main Test Stimulus
    // ------------------------------------------------------------------------
    initial begin
        // Initialize Inputs
        clk       = 0;
        rst_n     = 0;
        pixel_in  = 8'd0;
        weight_in = 8'sd0;
        errors    = 0;

        // Apply Reset
        #15;
        rst_n = 1;
        #10;

        $display("==================================================");
        $display("   Starting Self-Checking Testbench for MAC Unit  ");
        $display("==================================================");

        // Test Case 1: Zero Multiplication
        apply_test(8'd0, 8'sd0);

        // Test Case 2: Max Unsigned Pixel * Max Positive Weight (255 * 127 = 32385)
        apply_test(8'd255, 8'sd127);

        // Test Case 3: Max Unsigned Pixel * Min Negative Weight (255 * -128 = -32640)
        apply_test(8'd255, -8'sd128);

        // Test Case 4: Mid-range Pixel * Negative Weight (128 * -50 = -6400)
        apply_test(8'd128, -8'sd50);

        // Test Case 5: Mid-range Pixel * Positive Weight (200 * 64 = 12800)
        apply_test(8'd200, 8'sd64);

        // Summary Report
        #20;
        $display("==================================================");
        if (errors == 0) begin
            $display("   TEST PASSED SUCCESSFULLY! All cases matched.   ");
        end else begin
            $display("   TEST FAILED! Total errors detected: %d", errors);
        end
        $display("==================================================");
        $finish;
    end

    // ------------------------------------------------------------------------
    // Test Verification Task
    // ------------------------------------------------------------------------
    task apply_test(
        input [7:0] p_in,
        input signed [7:0] w_in
    );
        begin
            pixel_in  = p_in;
            weight_in = w_in;
            expected_product = $signed({1'b0, p_in}) * w_in;

            // Wait 1 clock cycle to accommodate pipeline register
            @(posedge clk);
            #1; // Delay past edge for stability observation

            if (product_out !== expected_product) begin
                $display("[ERROR] Pixel: %3d | Weight: %4d | Expected: %6d | Got: %6d",
                         p_in, w_in, expected_product, product_out);
                errors = errors + 1;
            end else begin
                $display("[SUCCESS] Pixel: %3d | Weight: %4d | Product: %6d",
                         p_in, w_in, product_out);
            end
        end
    endtask

endmodule