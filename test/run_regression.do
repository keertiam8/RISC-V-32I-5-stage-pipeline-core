# Compile step only; see run_regression.sh
vlib work_reg
vmap work work_reg
set src ../src/cpu
vlog +incdir+$src $src/defines.v $src/utility.v $src/cache.v $src/ctrl.v $src/reg_pc.v $src/stage_if.v $src/reg_if_id.v $src/stage_id.v $src/regfile.v $src/reg_id_ex.v $src/stage_ex.v $src/reg_ex_mem.v $src/stage_mem.v $src/reg_mem_wb.v $src/riscv_cpu.v root_sim_top.v root_cpu_tb.v alu_ctrl_mem_tb.v
quit -f
