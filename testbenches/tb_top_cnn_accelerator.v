`timescale 1ns / 1ps

module tb_top_cnn_accelerator;

    localparam IMG_W = 8;
    localparam IMG_H = 8;
    localparam K_DIM = 3; 
    localparam TOTAL_PIXELS = IMG_W * IMG_H;
    localparam EXPECTED_VALIDS = (IMG_W - (K_DIM-1)) * (IMG_H - (K_DIM-1));

    reg         clk;
    reg         rst_n;
    reg         cfg_wr_en;
    reg  [1:0]  cfg_kernel_idx;
    reg  [7:0]  cfg_weight_addr;
    reg  signed [7:0] cfg_weight_data;
    
    reg  [1:0]  active_kernel_sel;
    reg         relu_en;
    reg         valid_in;
    reg  [7:0]  pixel_in;
    
    wire        valid_out;
    wire signed [15:0] pixel_out;
    wire        kernel_ready; // Added kernel_ready wire

    integer cycle_count;
    integer total_valid_outs;
    integer errors;

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
        .pixel_out(pixel_out),
        .kernel_ready(kernel_ready) // Connected kernel_ready port
    );

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

    initial begin
        clk = 0; rst_n = 0; cycle_count = 0;
        cfg_wr_en = 0; cfg_kernel_idx = 0; cfg_weight_addr = 0; cfg_weight_data = 0;
        active_kernel_sel = 2'b11; // 1. Start on unused bank so 0 triggers a change
        relu_en = 0;
        valid_in = 0; pixel_in = 0;
        errors = 0;

        #15 rst_n = 1; #10;

        $display("==================================================");
        $display("   Starting Top-Level CNN Accelerator Testbench   ");
        $display("==================================================");

        // 2. Program weights into configuration memory
        write_weight(0, 0, 8'd0); write_weight(0, 1, 8'd0); write_weight(0, 2, 8'd0);
        write_weight(0, 3, 8'd0); write_weight(0, 4, 8'd2); write_weight(0, 5, 8'd0); 
        write_weight(0, 6, 8'd0); write_weight(0, 7, 8'd0); write_weight(0, 8, 8'd0);
        
        // 3. Select Bank 0 to trigger sequential loading
        @(negedge clk);
        active_kernel_sel = 2'b00; 
        relu_en = 0;
        
        // 4. Wait for sequential weight loader to finish copying memory to registers
        wait(kernel_ready == 1'b1);
        @(negedge clk);
        
        cycle_count = 1;
        while (cycle_count <= TOTAL_PIXELS) begin
            valid_in = 1;
            pixel_in = cycle_count;
            @(negedge clk); 
            cycle_count = cycle_count + 1;
        end
        valid_in = 0;

        // Flush pipeline
        repeat(30) @(posedge clk);

        $display("==================================================");
        if (total_valid_outs !== EXPECTED_VALIDS) begin
            $display("[ERROR] Expected %0d valid outputs, but got %0d.", EXPECTED_VALIDS, total_valid_outs);
            errors = errors + 1;
        end else begin
            $display("[SUCCESS] Correct number of output pixels generated (%0d).", EXPECTED_VALIDS);
        end

        if (errors == 0) $display("   TEST PASSED SUCCESSFULLY!");
        else             $display("   TEST FAILED! Total errors: %0d", errors);
        $display("==================================================");
        $finish;
    end
endmodule