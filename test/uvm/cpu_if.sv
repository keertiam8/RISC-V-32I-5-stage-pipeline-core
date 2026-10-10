// DUT I/O interface + backing memory model for riscv_cpu.
//
// riscv_cpu's mem_* ports are split into two channels packed into the
// same bus: bits/half [1] = icache channel, [0] = dcache channel
// (see riscv_cpu.v). This interface implements a simple one-request-
// at-a-time slave for each channel: assert done one cycle after a
// request, busy stays low. That satisfies cache.v's handshake
// (it never issues a second request before mem_done).

`timescale 1ns/1ps

interface cpu_if #(
    parameter MEM_BYTES = 1 << 20
) (
    input logic clk
);

    logic                 rst;
    logic [2*32-1:0]      mem_data_i;
    logic [1:0]           mem_busy_i;
    logic [1:0]           mem_done_i;
    logic [3:0]            mem_rwe_o;
    logic [2*32-1:0]      mem_addr_o;
    logic [7:0]             mem_sel_o;
    logic [2*32-1:0]      mem_data_o;

    // backing store, byte addressable
    logic [7:0] mem [0:MEM_BYTES-1];

    function automatic void load_program(string path, int base_addr = 0);
        logic [7:0] tmp [0:MEM_BYTES-1];
        int i;
        for (i = 0; i < MEM_BYTES; i++) tmp[i] = 8'h00;
        $readmemh(path, tmp);
        for (i = 0; i < MEM_BYTES; i++) mem[base_addr + i] = tmp[i];
    endfunction

    function automatic logic [31:0] peek_word(logic [31:0] addr);
        peek_word = {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr]};
    endfunction

    // one-cycle-latency slave for each of the two channels
    genvar ch;
    generate
        for (ch = 0; ch < 2; ch++) begin : chan
            logic [1:0]  rwe;
            logic [31:0] addr;
            logic [31:0] wdata;
            logic [3:0]  sel;

            assign rwe   = {mem_rwe_o[2*ch+1], mem_rwe_o[2*ch]};
            assign addr  = mem_addr_o[32*ch +: 32];
            assign wdata = mem_data_o[32*ch +: 32];
            assign sel   = mem_sel_o[4*ch +: 4];

            always_ff @(posedge clk or posedge rst) begin
                if (rst) begin
                    mem_done_i[ch] <= 1'b0;
                    mem_busy_i[ch] <= 1'b0;
                    mem_data_i[32*ch +: 32] <= 32'h0;
                end else begin
                    mem_done_i[ch] <= 1'b0;
                    if (rwe[0]) begin // read
                        mem_data_i[32*ch +: 32] <= peek_word(addr);
                        mem_done_i[ch] <= 1'b1;
                    end else if (rwe[1]) begin // write
                        if (sel[0]) mem[addr+0] <= wdata[7:0];
                        if (sel[1]) mem[addr+1] <= wdata[15:8];
                        if (sel[2]) mem[addr+2] <= wdata[23:16];
                        if (sel[3]) mem[addr+3] <= wdata[31:24];
                        mem_done_i[ch] <= 1'b1;
                    end
                end
            end
        end
    endgenerate

endinterface
