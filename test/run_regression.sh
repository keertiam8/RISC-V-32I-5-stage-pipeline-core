#!/bin/bash
# Full regression with ModelSim ASE. Run from test/:  ./run_regression.sh
export PATH="/c/intelFPGA/18.1/modelsim_ase/win32aloem:$PATH"
cd "$(dirname "$0")"
vsim -c -do run_regression.do | grep -i 'error' | grep -v 'Errors: 0' && exit 1
rc=0
for tb in root_cpu_tb alu_ctrl_mem_tb; do
  out=$(vsim -c work.$tb -do "run -all; quit -f")
  echo "$out" | grep -E '^# (PASS|FAIL)'
  echo "$out" | grep -q '^# PASS' || rc=1
done
exit $rc
