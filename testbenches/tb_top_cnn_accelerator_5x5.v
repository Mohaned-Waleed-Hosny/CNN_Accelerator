`timescale 1ns / 1ps

module tb_top_cnn_accelerator_5x5;

    // ------------------------------------------------------------------------
    // Parameterization: 5x5 Kernel on a 10x10 Image
    // ------------------------------------------------------------------------
    localparam IMG_W = 10;
    localparam IMG_H = 10;
    localparam K_DIM = 5; 
    localparam TOTAL_PIXELS = IMG_W * IMG_H; // 100 pixels
    localparam EXPECTED_VALIDS = (IMG_W - (K_DIM - 1)) * (IMG_H - (K_DIM - 1)); // 6 x 6 = 36 valid outputs

    reg         clk;
    reg         rst_n;
    
    // Configuration Ports
    reg         cfg_wr_en;
    reg  [1:0]  cfg_kernel_idx;
    reg  [7:0]  cfg_weight_addr;
    reg  signed [7:0] cfg_weight_data;
    
    // Operational Signals
    reg  [1:0]  active_kernel_sel;
    reg         relu_en;
    
    // Data Stream Ports
    reg         valid_in;
    reg  [7:0]  pixel_in;
    
    wire        valid_out;
    wire signed [15:0] pixel_out;

    integer cycle_count;
    integer total_valid_outs;
    integer errors;
    integer i;

    // ------------------------------------------------------------------------
    // Instantiate UUT with 5x5 Parameters
    // ------------------------------------------------------------------------
    top_cnn_accelerator #(
        .IMAGE_WIDTH(IMG_W),
        .IMAGE_HEIGHT(IMG_H),
        .KERNEL_DIM(K_DIM),
        .USE_DSP("NO")
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

    // Clock Generation
    always #5 clk = ~clk;

    // Output Monitor
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_valid_outs = 0;
        end else if (valid_out) begin
            total_valid_outs = total_valid_outs + 1;
            $display("[T=%0t] Output #%0d Valid | Result = %d", 
                     $time, total_valid_outs, pixel_out);
        end
    end

    // Task to program weight registers
    task write_weight(input [1:0] k_idx, input [7:0] addr, input signed [7:0] data);
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
    // Simulation Routine
    // ------------------------------------------------------------------------
    initial begin
        // Reset and initialization
        clk = 0; rst_n = 0; cycle_count = 0;
        cfg_wr_en = 0; cfg_kernel_idx = 0; cfg_weight_addr = 0; cfg_weight_data = 0;
        active_kernel_sel = 0; relu_en = 0;
        valid_in = 0; pixel_in = 0;
        errors = 0;

        #15 rst_n = 1; #10;

        $display("==================================================");
        $display("   Testing Parameterization: 5x5 Kernel on 10x10   ");
        $display("==================================================");

        // Configure a 5x5 Identity Kernel (Center Weight = 2, All others = 0)
        // Weight indices range from 0 to 24 (Center is index 12)
        for (i = 0; i < K_DIM * K_DIM; i = i + 1) begin
            if (i == 12) begin
                write_weight(0, i, 8'd2); // Center pixel multiplier x2
            end else begin
                write_weight(0, i, 8'd0);
            end
        end
        
        active_kernel_sel = 0; 
        relu_en = 0;
        
        @(negedge clk); @(negedge clk);
        
        // Stream 100 Input Pixels (Linear values: 1, 2, 3... 100)
        cycle_count = 1;
        while (cycle_count <= TOTAL_PIXELS) begin
            valid_in = 1;
            pixel_in = cycle_count;
            @(negedge clk); 
            cycle_count = cycle_count + 1;
        end
        valid_in = 0;

        // Pipeline flush wait
        repeat(30) @(posedge clk);

        // Verification checks
        $display("==================================================");
        if (total_valid_outs !== EXPECTED_VALIDS) begin
            $display("[ERROR] Expected %0d valid outputs, but got %0d.", EXPECTED_VALIDS, total_valid_outs);
            errors = errors + 1;
        end else begin
            $display("[SUCCESS] Correct number of output pixels generated (%0d).", EXPECTED_VALIDS);
        end

        if (errors == 0) $display("   5x5 PARAMETERIZATION TEST PASSED SUCCESSFULLY!");
        else             $display("   TEST FAILED! Total errors: %0d", errors);
        $display("==================================================");
        $finish;
    end

endmodule