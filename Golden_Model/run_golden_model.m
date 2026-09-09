% =========================================================================
% IEEE SSCS Egypt Chapter 2026 Student Design Competition
% File Name : run_golden_model.m
% Description: Golden Reference Model with Decimal Export & Visual Figures
% =========================================================================

clear; clc; close all;

fprintf('====================================================\n');
fprintf('   SSCS 2026 Accelerator Golden Model Verification  \n');
fprintf('====================================================\n\n');

% --- 1. Design & Simulation Parameters ---
img_w   = 10;
img_h   = 10;
k_dim   = 5;
relu_en = false; % Set to true to enable ReLU activation

% --- 2. Input Image Generation (10x10 Grayscale Stream: 1 to 100) ---
input_1D    = uint8(1:100);
input_image = reshape(input_1D, img_w, img_h)'; % Matrix format (row-major)

% --- 3. Kernel Configuration (5x5 Center-Weighted Identity Filter) ---
kernel      = zeros(k_dim, k_dim, 'int8');
kernel(3,3) = int8(2); % Scale center pixel by 2

% --- 4. Execute Golden Reference Model ---
[output_stream, output_map] = cnn_accelerator_golden_model(input_image, kernel, relu_en);

% --- 5. Display Summary in Command Window ---
fprintf('Input Image Size : %dx%d\n', img_h, img_w);
fprintf('Kernel Dimensions: %dx%d\n', k_dim, k_dim);
fprintf('Total Valid Out  : %d pixels\n\n', length(output_stream));
fprintf('Expected Decimal Output Stream (Matching Verilog %%d):\n');
disp(output_stream);

% --- 6. Export Test Vectors (Decimal Format for Testbench) ---
% Export Input Pixels in Signed/Unsigned Decimal
fileID_in_dec = fopen('input_pixels_dec.txt', 'w');
fprintf(fileID_in_dec, '%d\n', input_1D);
fclose(fileID_in_dec);

% Export Expected Outputs in Signed Decimal (%d)
fileID_out_dec = fopen('expected_outputs_dec.txt', 'w');
fprintf(fileID_out_dec, '%d\n', output_stream);
fclose(fileID_out_dec);

% Export Hexadecimal versions for $readmemh
fileID_in_hex = fopen('input_pixels_hex.txt', 'w');
fprintf(fileID_in_hex, '%02X\n', input_1D);
fclose(fileID_in_hex);

fileID_out_hex = fopen('expected_outputs_hex.txt', 'w');
for i = 1:length(output_stream)
    val = output_stream(i);
    if val < 0, val = val + 65536; end % 16-bit 2's complement
    fprintf(fileID_out_hex, '%04X\n', val);
end
fclose(fileID_out_hex);

fprintf('Exported Test Vector Files:\n');
fprintf('  [Decimal] -> input_pixels_dec.txt, expected_outputs_dec.txt\n');
fprintf('  [Hex]     -> input_pixels_hex.txt, expected_outputs_hex.txt\n\n');

% --- 7. Generate Visual Verification Figures (Professional & Compact) ---
fig = figure('Name', 'SSCS 2026 CNN Accelerator', 'Color', [0.05 0.07 0.10]);
tiledlayout(2,2, 'TileSpacing', 'compact', 'Padding', 'compact');

% Subplot configuration matrix: {Data, Title, Colormap}
m_plots = {
    input_image,   '1. Input Image (10x10, 8-bit)',      'gray';
    double(kernel),'2. Kernel Weights (5x5, 8-bit)',     'bone';
    output_map,    '3. Output Feature Map (6x6, 16-bit)','parula'
};

% Unified Loop for Matrix Subplots (1-3)
for i = 1:3
    nexttile; ax = gca; data = m_plots{i,1};
    imagesc(data); colormap(ax, m_plots{i,3}); 
    cb = colorbar; cb.Color = [0.8 0.8 0.8];
    title(m_plots{i,2}, 'Color', 'w', 'FontSize', 9.5, 'FontWeight', 'bold');
    xlabel('Columns', 'Color', [0.6 0.6 0.6]); ylabel('Rows', 'Color', [0.6 0.6 0.6]);
    set(ax, 'Color', [0.09 0.11 0.15], 'XColor', [0.8 0.8 0.8], 'YColor', [0.8 0.8 0.8]); 
    axis square;
    
    % Dynamic Text Overlay for Crisp Luminance Contrast
    norm_d = (data - min(data(:))) / (max(data(:)) - min(data(:)) + eps);
    [R, C] = size(data);
    for r = 1:R, for c = 1:C
        tc = [0.95 0.95 0.95]; if norm_d(r,c) > 0.6, tc = [0.05 0.05 0.05]; end
        text(c, r, num2str(data(r,c)), 'Color', tc, 'HorizontalAlignment', 'center', ...
             'FontSize', 7.5, 'FontWeight', 'bold');
    end, end
end

% Subplot 4: Output Valid Stream Plot
nexttile;
plot(1:length(output_stream), output_stream, '-o', 'LineWidth', 1.8, ...
    'Color', [0.2 0.75 1], 'MarkerSize', 4, 'MarkerFaceColor', [0.05 0.07 0.10]);
grid on;
set(gca, 'Color', [0.09 0.11 0.15], 'XColor', [0.8 0.8 0.8], 'YColor', [0.8 0.8 0.8], ...
    'GridColor', [0.25 0.3 0.4], 'GridAlpha', 0.6);
title('4. Output Valid Stream (Pixel # vs Value)', 'Color', 'w', 'FontSize', 9.5, 'FontWeight', 'bold');
xlabel('Valid Output Index (1 to 36)', 'Color', [0.6 0.6 0.6]);
ylabel('Pixel Value (16-bit Signed)', 'Color', [0.6 0.6 0.6]);
xlim([1 length(output_stream)]);

% =========================================================================
% Local Function: CNN Accelerator Golden Model
% =========================================================================
function [output_stream, output_map] = cnn_accelerator_golden_model(input_image, kernel, relu_en)
    [img_h, img_w] = size(input_image);
    [k_h, k_w]     = size(kernel);
    
    if k_h ~= k_w
        error('Kernel must be square (N x N).');
    end
    k_dim = k_h;

    out_h = img_h - k_dim + 1;
    out_w = img_w - k_dim + 1;

    output_map = zeros(out_h, out_w);

    MAX_16BIT = 32767;
    MIN_16BIT = -32768;

    for r = 1:out_h
        for c = 1:out_w
            window  = double(input_image(r:r+k_dim-1, c:c+k_dim-1));
            weights = double(kernel);

            raw_sum = sum(sum(window .* weights));

            if raw_sum > MAX_16BIT
                sat_sum = MAX_16BIT;
            elseif raw_sum < MIN_16BIT
                sat_sum = MIN_16BIT;
            else
                sat_sum = raw_sum;
            end

            if relu_en && sat_sum < 0
                pixel_out = 0;
            else
                pixel_out = sat_sum;
            end

            output_map(r, c) = pixel_out;
        end
    end

    output_stream = reshape(output_map', 1, []);
end