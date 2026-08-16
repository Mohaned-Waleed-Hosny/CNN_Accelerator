// ============================================================================
// File Name:     tb_window_generator.v
// Design Name:   Automated Testbench for 3x3 Sliding Window Generator
// ============================================================================

`timescale 1ns / 1ps

module tb_window_generator;

    // ------------------------------------------------------------------------
    // Signals
    // ------------------------------------------------------------------------
    reg         clk;
    reg         rst_n;
    reg         shift_en;
    reg  [7:0]  pixel_in;
    
    // Explicit Window Signals
    wire [7:0] p00, p01, p02;
    wire [7:0] p10, p11, p12;
    wire [7:0] p20, p21, p22;

    integer cycle_count;
    integer errors;

    // ------------------------------------------------------------------------
    // UUT Instantiation
    // ------------------------------------------------------------------------
    window_generator #(
        .IMAGE_WIDTH(32)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .shift_en(shift_en),
        .pixel_in(pixel_in),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22)
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
        shift_en = 0;
        pixel_in = 0;
        cycle_count = 0;
        errors = 0;

        // Reset
        #15;
        rst_n = 1;
        #10;
        
        $display("==================================================");
        $display("   Starting Sliding Window Testbench              ");
        $display("   IMAGE_WIDTH = 32 pixels                        ");
        $display("==================================================");

        shift_en = 1;

        // Feed sequential data: 1, 2, 3, 4 ... 
        for (cycle_count = 1; cycle_count <= 100; cycle_count = cycle_count + 1) begin
            pixel_in = cycle_count;
            @(posedge clk);
            #1; 
            
            // Validate at Cycle 68
            if (cycle_count == 68) begin
                $display("--- Window at Cycle 68 ---");
                // Print visually matching the spatial layout (p00 is top left, p22 is bottom right)
                $display("[%3d] [%3d] [%3d]", p00, p01, p02);
                $display("[%3d] [%3d] [%3d]", p10, p11, p12);
                $display("[%3d] [%3d] [%3d]", p20, p21, p22);
                
                // Assert Spatial Correctness
                // At cycle 68, the newest pixel (p22) is 68.
                // The pixel directly above it (p12) should be 36 (68 - 32).
                // The pixel above that (p02) should be 4 (36 - 32).
                if (p22 !== 68 || p12 !== 36 || p02 !== 4) begin
                    $display("[ERROR] Spatial alignment failed on Column 2!");
                    errors = errors + 1;
                end
                if (p21 !== 67 || p11 !== 35 || p01 !== 3) begin
                    $display("[ERROR] Spatial alignment failed on Column 1!");
                    errors = errors + 1;
                end
                if (p20 !== 66 || p10 !== 34 || p00 !== 2) begin
                    $display("[ERROR] Spatial alignment failed on Column 0!");
                    errors = errors + 1;
                end
            end
        end

        shift_en = 0;
        
        $display("==================================================");
        if (errors == 0) begin
            $display("   TEST PASSED SUCCESSFULLY! Window perfectly aligned.");
        end else begin
            $display("   TEST FAILED! Total errors detected: %d", errors);
        end
        $display("==================================================");
        $finish;
    end

endmodule