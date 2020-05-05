vlib work
vlog +define+WAVE +acc "../../rtl/fontMem.v"
vlog +define+WAVE +acc "../tb_fontMem.v"
vsim work.tb_fontMem
onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_fontMem/clk
add wave -noupdate /tb_fontMem/error
add wave -noupdate -radix decimal /tb_fontMem/addr
add wave -noupdate -radix hexadecimal /tb_fontMem/dout
add wave -noupdate -radix hexadecimal /tb_fontMem/expected
add wave -noupdate /tb_fontMem/dut_fontMem/mem
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 0
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {1 us}
run -all
