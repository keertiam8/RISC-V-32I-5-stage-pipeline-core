`timescale 1ns/1ps

module tb_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import riscv_pkg::*;

    logic clk = 0;
    always #10 clk = ~clk; // 50MHz, matches test/test_bench.v

    cpu_if u_cpu_if (.clk(clk));

    riscv_cpu dut (
        .clk       (clk),
        .rst       (u_cpu_if.rst),
        .mem_data_i(u_cpu_if.mem_data_i),
        .mem_busy_i(u_cpu_if.mem_busy_i),
        .mem_done_i(u_cpu_if.mem_done_i),
        .mem_rwe_o (u_cpu_if.mem_rwe_o),
        .mem_addr_o(u_cpu_if.mem_addr_o),
        .mem_sel_o (u_cpu_if.mem_sel_o),
        .mem_data_o(u_cpu_if.mem_data_o)
    );
    // wb_probe_if is attached to `dut` automatically via the `bind`
    // statement in wb_probe_if.sv, visible below as dut.u_wb_probe_if

    initial begin
        uvm_config_db#(virtual cpu_if)::set(null, "uvm_test_top.env.boot_agt.drv", "vif", u_cpu_if);
        uvm_config_db#(virtual wb_probe_if)::set(null, "uvm_test_top.env.wb_mon", "vif", dut.u_wb_probe_if);
    end

    initial begin
        run_test("riscv_base_test");
    end

    // safety net in case a test forgets to end
    initial begin
        #1_000_000;
        `uvm_fatal("TIMEOUT", "simulation exceeded watchdog time")
    end

endmodule
