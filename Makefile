oberon_obst:
	mkdir -p output
	yosys -q -p "synth_ecp5 -noabc9 -top RISC5Top -json output/oberon_obst.json; write_verilog output/oberon_obst_synth.v" rtl_sram/*.v
	nextpnr-ecp5 --12k --package CABGA256 --lpf-allow-unconstrained --lpf rtl_sram/obst_v0.lpf --json output/oberon_obst.json --textcfg output/obst_oberon_out.config
	ecppack -v --compress --freq 2.4 output/obst_oberon_out.config --bit output/obst.bit

prog:
	sudo openFPGALoader -c dirtyJtag output/obst.bit
