// ============================================================================
// File Name:     tb_control_fsm.v
// Design Name:   Automated Testbench for Convolution Controller (10x10)
// ============================================================================
`timescale 1ns / 1ps

module tb_control_fsm;

    // ------------------------------------------------------------------------
    // Signals
    // ------------------------------------------------------------------------
    reg  clk;
    reg  rst_n;
    reg  valid_in;
    
    wire shift_en;
    wire valid_out;

    integer total_valid_outs;
    integer cycle_count;
    integer errors;

    // ------------------------------------------------------------------------
    // UUT Instantiation (Set for a 10x10 image)
    // ------------------------------------------------------------------------
    control_fsm #(
        .IMAGE_WIDTH(10),
        .IMAGE_HEIGHT(10)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .shift_en(shift_en),
        .valid_out(valid_out)
    );

    // ------------------------------------------------------------------------
    // Clock Generation
    // ------------------------------------------------------------------------
    always #5 clk = ~clk;

    // ------------------------------------------------------------------------
    // Monitor Output Valids
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_valid_outs = 0;
        end else if (valid_out) begin
            total_valid_outs = total_valid_outs + 1;
            $display("[T=%0t] Valid Output Pixel #%0d generated.", $time, total_valid_outs);
        end
    end

    // ------------------------------------------------------------------------
    // Main Test Sequence
    // ------------------------------------------------------------------------
    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        valid_in = 0;
        cycle_count = 0;
        errors = 0;

        // Apply Reset
        #15;
        rst_n = 1;
        #10;

        $display("==================================================");
        $display("   Starting Control FSM Testbench                 ");
        $display("   Testing with a 10x10 Input Image               ");
        $display("==================================================");

        // Feed 100 pixels (10x10 image) into the pipeline
        for (cycle_count = 1; cycle_count <= 100; cycle_count = cycle_count + 1) begin
            valid_in = 1;
            @(posedge clk);
            
            // Periodically stall the pipeline to verify robustness (AXI-Stream backpressure sim)
            // Stalling at cycles 25 and 75
            if (cycle_count == 25 || cycle_count == 75) begin
                valid_in = 0;
                @(posedge clk); // Stall for 1 cycle
                @(posedge clk); // Stall for 2 cycles
            end
        end

        // Stop feeding data, let the pipeline flush
        valid_in = 0;

        // Wait enough cycles for the 6-stage pipeline to flush the remaining pixels
        repeat(15) @(posedge clk);

        // --------------------------------------------------------------------
        // Verify Expected Behavior
        // --------------------------------------------------------------------
        // For a 10x10 input image using a 3x3 valid convolution (no padding):
        // Output dimensions = (10 - 3 + 1) x (10 - 3 + 1) = 8 x 8 = 64 pixels.
        
        $display("==================================================");
        if (total_valid_outs !== 64) begin
            $display("[ERROR] Expected exactly 64 valid outputs. Got: %0d", total_valid_outs);
            errors = errors + 1;
        end else begin
            $display("[SUCCESS] Exact output valid count verified (64). Pipeline timing is perfect.");
        end

        if (errors == 0) begin
            $display("   TEST PASSED SUCCESSFULLY!                      ");
        end else begin
            $display("   TEST FAILED! Total errors detected: %0d", errors);
        end
        $display("==================================================");
        $finish;
    end

endmodule





// ==============================
// ==============================
// ======= Tb verision 1 =======
// ==============================
// ==============================


// ============================================================================
// File Name:     tb_control_fsm.v
// Design Name:   Automated Testbench for Convolution Controller
// ============================================================================

/*
`timescale 1ns / 1ps

module tb_control_fsm;

    // ------------------------------------------------------------------------
    // Signals
    // ------------------------------------------------------------------------
    reg  clk;
    reg  rst_n;
    reg  valid_in;
    
    wire shift_en;
    wire valid_out;

    integer total_valid_outs;
    integer cycle_count;
    integer errors;

    // ------------------------------------------------------------------------
    // UUT Instantiation (Set for a small 5x5 image for faster testing)
    // ------------------------------------------------------------------------
    control_fsm #(
        .IMAGE_WIDTH(5),
        .IMAGE_HEIGHT(5)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .shift_en(shift_en),
        .valid_out(valid_out)
    );

    // ------------------------------------------------------------------------
    // Clock Generation
    // ------------------------------------------------------------------------
    always #5 clk = ~clk;

    // ------------------------------------------------------------------------
    // Monitor Output Valids
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_valid_outs = 0;
        end else if (valid_out) begin
            total_valid_outs = total_valid_outs + 1;
            $display("[T=%0t] Valid Output Pixel #%0d generated.", $time, total_valid_outs);
        end
    end

    // ------------------------------------------------------------------------
    // Main Test Sequence
    // ------------------------------------------------------------------------
    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        valid_in = 0;
        cycle_count = 0;
        errors = 0;

        // Apply Reset
        #15;
        rst_n = 1;
        #10;

        $display("==================================================");
        $display("   Starting Control FSM Testbench                 ");
        $display("   Testing with a 5x5 Input Image                 ");
        $display("==================================================");

        // Feed 25 pixels (5x5 image) into the pipeline
        for (cycle_count = 1; cycle_count <= 25; cycle_count = cycle_count + 1) begin
            valid_in = 1;
            @(posedge clk);
            
            // Periodically stall the pipeline to verify robustness (AXI-Stream backpressure sim)
            if (cycle_count == 10 || cycle_count == 20) begin
                valid_in = 0;
                @(posedge clk); // Stall for 1 cycle
                @(posedge clk); // Stall for 2 cycles
            end
        end

        // Stop feeding data, let the pipeline flush
        valid_in = 0;

        // Wait enough cycles for the 6-stage pipeline to flush the remaining pixels
        repeat(15) @(posedge clk);

        // --------------------------------------------------------------------
        // Verify Expected Behavior
        // --------------------------------------------------------------------
        // For a 5x5 input image using a 3x3 valid convolution (no padding):
        // Output dimensions = (5 - 3 + 1) x (5 - 3 + 1) = 3 x 3 = 9 pixels.
        
        $display("==================================================");
        if (total_valid_outs !== 9) begin
            $display("[ERROR] Expected exactly 9 valid outputs. Got: %0d", total_valid_outs);
            errors = errors + 1;
        end else begin
            $display("[SUCCESS] Exact output valid count verified (9). Pipeline timing is perfect.");
        end

        if (errors == 0) begin
            $display("   TEST PASSED SUCCESSFULLY!                      ");
        end else begin
            $display("   TEST FAILED! Total errors detected: %0d", errors);
        end
        $display("==================================================");
        $finish;
    end

endmodule
*/
