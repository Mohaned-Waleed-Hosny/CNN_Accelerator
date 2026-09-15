# General ModelSim/Questa simulation script
#vlib work
#vlog -work work *.v
#vsim work.tb
#add wave *
#run -all
#quit

#../rtl/xxxxx
# modelsim
# do ../Scripts/run.do
# vsim -do ../Scripts/run.do

vlib work
vlog ../RTL/*.v ../testbenches/*.v
vsim work.tb_top_cnn_accelerator_32x32

# Wave Window Configuration
add wave -group "System Control" \
    sim:/tb_top_cnn_accelerator_32x32/clk \
    sim:/tb_top_cnn_accelerator_32x32/rst_n

add wave -group "Kernel Configuration" \
    sim:/tb_top_cnn_accelerator_32x32/cfg_wr_en \
    sim:/tb_top_cnn_accelerator_32x32/cfg_kernel_idx \
    sim:/tb_top_cnn_accelerator_32x32/cfg_weight_addr \
    sim:/tb_top_cnn_accelerator_32x32/cfg_weight_data

add wave -group "Operating Mode" \
    sim:/tb_top_cnn_accelerator_32x32/active_kernel_sel \
    sim:/tb_top_cnn_accelerator_32x32/relu_en \
    sim:/tb_top_cnn_accelerator_32x32/kernel_ready

add wave -group "Input Stream" \
    sim:/tb_top_cnn_accelerator_32x32/valid_in \
    sim:/tb_top_cnn_accelerator_32x32/pixel_in

add wave -group "Output Stream" \
    sim:/tb_top_cnn_accelerator_32x32/valid_out \
    sim:/tb_top_cnn_accelerator_32x32/pixel_out

add wave -group "Testbench Debug Counters" \
    sim:/tb_top_cnn_accelerator_32x32/cycle_count \
    sim:/tb_top_cnn_accelerator_32x32/total_valid_outs \
    sim:/tb_top_cnn_accelerator_32x32/errors \
    sim:/tb_top_cnn_accelerator_32x32/i

# Formatting tweaks
configure wave -namecolwidth 250
configure wave -valuecolwidth 100
configure wave -justifyvalue right
configure wave -signalnamewidth 1

run -all