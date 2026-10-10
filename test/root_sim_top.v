`timescale 1ns/1ps

module root_sim_top (
    input wire clk,
    input wire rst
);

    wire [63:0] mem_data_i;
    wire [1:0] mem_busy_i;
    wire [1:0] mem_done_i;
    wire [3:0] mem_rwe_o;
    wire [63:0] mem_addr_o;
    wire [7:0] mem_sel_o;
    wire [63:0] mem_data_o;

    riscv_cpu cpu0 (
        .clk       (clk),
        .rst       (rst),
        .mem_data_i(mem_data_i),
        .mem_busy_i(mem_busy_i),
        .mem_done_i(mem_done_i),
        .mem_rwe_o (mem_rwe_o),
        .mem_addr_o(mem_addr_o),
        .mem_sel_o (mem_sel_o),
        .mem_data_o(mem_data_o)
    );

    root_sim_memory memory0 (
        .clk       (clk),
        .rst       (rst),
        .mem_rwe   (mem_rwe_o),
        .mem_addr  (mem_addr_o),
        .mem_sel   (mem_sel_o),
        .mem_wdata (mem_data_o),
        .mem_rdata (mem_data_i),
        .mem_busy  (mem_busy_i),
        .mem_done  (mem_done_i)
    );

endmodule

module root_sim_memory (
    input wire        clk,
    input wire        rst,
    input wire [3:0]  mem_rwe,
    input wire [63:0] mem_addr,
    input wire [7:0]  mem_sel,
    input wire [63:0] mem_wdata,
    output wire [63:0] mem_rdata,
    output wire [1:0]  mem_busy,
    output wire [1:0]  mem_done
);

    reg [7:0] memory [0:4095];
    reg [31:0] read_data [0:1];
    reg [1:0] done_r;
    integer i;

    assign mem_rdata = {read_data[1], read_data[0]};
    assign mem_busy = 2'b00;
    assign mem_done = done_r;

    initial begin
        for (i = 0; i < 4096; i = i + 1)
            memory[i] = 8'h00;

        // addi x1, x0, 5
        write_word(32'h00000000, 32'h00500093);
        // addi x2, x0, 7
        write_word(32'h00000004, 32'h00700113);
        // add x3, x1, x2
        write_word(32'h00000008, 32'h002081b3);
        // sw x3, 0x100(x0)
        write_word(32'h0000000c, 32'h10302023);
        // lw x4, 0x100(x0)
        write_word(32'h00000010, 32'h10002203);
        // add x5, x4, x1 (load-use dependency)
        write_word(32'h00000014, 32'h001202b3);
        // addi x6, x0, 1
        write_word(32'h00000018, 32'h00100313);
        // beq x6, x6, +8
        write_word(32'h0000001c, 32'h00630463);
        // skipped: addi x7, x0, 99
        write_word(32'h00000020, 32'h06300393);
        // branch target: addi x7, x0, 42
        write_word(32'h00000024, 32'h02a00393);
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            done_r <= 2'b00;
            read_data[0] <= 32'h00000000;
            read_data[1] <= 32'h00000000;
        end else begin
            done_r <= 2'b00;
            service_channel(0);
            service_channel(1);
        end
    end

    task service_channel;
        input integer channel;
        reg [1:0] request;
        reg [31:0] address;
        reg [31:0] write_data;
        reg [3:0] write_mask;
        begin
            request = mem_rwe[channel * 2 +: 2];
            address = mem_addr[channel * 32 +: 32];
            write_data = mem_wdata[channel * 32 +: 32];
            write_mask = mem_sel[channel * 4 +: 4];

            if (request[0]) begin
                read_data[channel] <= read_word(address);
                done_r[channel] <= 1'b1;
            end else if (request[1]) begin
                write_masked(address, write_data, write_mask);
                done_r[channel] <= 1'b1;
            end
        end
    endtask

    task write_word;
        input [31:0] address;
        input [31:0] value;
        begin
            memory[address] = value[7:0];
            memory[address + 1] = value[15:8];
            memory[address + 2] = value[23:16];
            memory[address + 3] = value[31:24];
        end
    endtask

    function [31:0] read_word;
        input [31:0] address;
        begin
            read_word = {memory[address + 3], memory[address + 2], memory[address + 1], memory[address]};
        end
    endfunction

    task write_masked;
        input [31:0] address;
        input [31:0] value;
        input [3:0] mask;
        begin
            if (mask[0]) memory[address] = value[7:0];
            if (mask[1]) memory[address + 1] = value[15:8];
            if (mask[2]) memory[address + 2] = value[23:16];
            if (mask[3]) memory[address + 3] = value[31:24];
        end
    endtask

endmodule
