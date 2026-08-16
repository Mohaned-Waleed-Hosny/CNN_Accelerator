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
vsim work.tb_top_cnn_accelerator
add wave *
run -all