// Passive probe into riscv_cpu's writeback stage, attached via `bind`
// so the DUT source (riscv_cpu.v) is never modified. Gives the UVM
// monitor visibility into internal signals that aren't top-level ports.

`timescale 1ns/1ps

interface wb_probe_if (
    input logic        clk,
    input logic        rst,
    input logic        wb_we,
    input logic [4:0]  wb_reg_waddr,
    input logic [31:0] wb_reg_wdata,
    input logic [31:0] id_pc,
    input logic [31:0] id_inst
);
endinterface

bind riscv_cpu wb_probe_if u_wb_probe_if (
    .clk         (clk),
    .rst         (rst),
    .wb_we       (wb_we),
    .wb_reg_waddr(wb_reg_waddr),
    .wb_reg_wdata(wb_reg_wdata),
    .id_pc       (id_pc),
    .id_inst     (id_inst)
);
