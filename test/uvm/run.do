; Questa UVM run script for the riscv_cpu UVM testbench.
; Run from the RISC-V-CPU repo root:
;   vsim -c -do test/uvm/run.do
; or, to see waves interactively:
;   vsim -gui -do test/uvm/run.do

; Uses its own library directory (test/uvm/uvm_work) so it never
; touches a work/ library you may already have at the repo root.
quit -sim
if {[file exists test/uvm/uvm_work]} { vdel -all -lib test/uvm/uvm_work }
vlib test/uvm/uvm_work
vmap work test/uvm/uvm_work

; Questa ships a precompiled UVM library (mtiUvm in modelsim.ini's
; LibrarySearchPath, uvm-1.1d by default on this install) - do NOT
; recompile uvm_pkg.sv, just pull in the macro header and let
; `import uvm_pkg::*` resolve against that precompiled library.
set UVM_VER "uvm-1.1d"
set UVM_SRC "$env(MTI_HOME)/verilog_src/$UVM_VER/src"

; utility.v and simple_ram.v are pulled in via `include from cache.v
; (they're not `ifndef-guarded) - do not list them separately here or
; vlog will complain about duplicate module definitions.
vlog -sv -mfcu -cuname riscv_cu +incdir+src/cpu +incdir+$UVM_SRC \
    +define+SIMULATION \
    src/cpu/defines.v \
    src/cpu/cache.v \
    src/cpu/reg_pc.v \
    src/cpu/reg_if_id.v \
    src/cpu/reg_id_ex.v \
    src/cpu/reg_ex_mem.v \
    src/cpu/reg_mem_wb.v \
    src/cpu/regfile.v \
    src/cpu/ctrl.v \
    src/cpu/stage_if.v \
    src/cpu/stage_id.v \
    src/cpu/stage_ex.v \
    src/cpu/stage_mem.v \
    src/cpu/riscv_cpu.v \
    test/uvm/cpu_if.sv \
    test/uvm/wb_probe_if.sv \
    test/uvm/riscv_pkg.sv \
    test/uvm/tb_top.sv

vsim -voptargs=+acc work.tb_top -sv_lib "$env(MTI_HOME)/$UVM_VER/win64/uvm_dpi" +UVM_TESTNAME=riscv_base_test +PROG=test/example.data +CYCLES=2000

run -all
quit -f
