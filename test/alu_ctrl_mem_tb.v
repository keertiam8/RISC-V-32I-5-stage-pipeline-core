`timescale 1ns/1ps

// Directed self-checking test for Tier A (ALU), Tier B (branches/jal/lui/auipc)
// and part of Tier C (lh/lhu/lb/lbu). Reuses root_sim_top; the program is
// written into the behavioral memory while the CPU is still in reset.
module alu_ctrl_mem_tb;

    reg clk;
    reg rst;
    integer errors;

    root_sim_top dut (.clk(clk), .rst(rst));

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task write_word;
        input [31:0] address;
        input [31:0] value;
        begin
            dut.memory0.write_word(address, value);
        end
    endtask

    initial begin
        errors = 0;
        rst = 1'b1;
        #1;
        write_word(32'h00000000, 32'hfff00093);
        write_word(32'h00000004, 32'hff00f113);
        write_word(32'h00000008, 32'hffe06193);
        write_word(32'h0000000c, 32'hfff0c213);
        write_word(32'h00000010, 32'h06400293);
        write_word(32'h00000014, 32'h01e00313);
        write_word(32'h00000018, 32'h406283b3);
        write_word(32'h0000001c, 32'h0062f433);
        write_word(32'h00000020, 32'h0062e4b3);
        write_word(32'h00000024, 32'h0062c533);
        write_word(32'h00000028, 32'h00231593);
        write_word(32'h0000002c, 32'h01c0d613);
        write_word(32'h00000030, 32'h41c0d693);
        write_word(32'h00000034, 32'h0050a733);
        write_word(32'h00000038, 32'h0050b7b3);
        write_word(32'h0000003c, 32'h0000a813);
        write_word(32'h00000040, 32'h00103893);
        write_word(32'h00000044, 32'h12345937);
        write_word(32'h00000048, 32'h00001997);
        write_word(32'h0000004c, 32'h00509463);
        write_word(32'h00000050, 32'h06300a13);
        write_word(32'h00000054, 32'h0050c463);
        write_word(32'h00000058, 32'h06300a13);
        write_word(32'h0000005c, 32'h0012d463);
        write_word(32'h00000060, 32'h06300a13);
        write_word(32'h00000064, 32'h0012e463);
        write_word(32'h00000068, 32'h06300a13);
        write_word(32'h0000006c, 32'h0050f463);
        write_word(32'h00000070, 32'h06300a13);
        write_word(32'h00000074, 32'h00508463);
        write_word(32'h00000078, 32'h00100a93);
        write_word(32'h0000007c, 32'h00800b6f);
        write_word(32'h00000080, 32'h06300a13);
        write_word(32'h00000084, 32'h80008bb7);
        write_word(32'h00000088, 32'hfffb8b93);
        write_word(32'h0000008c, 32'h11702023);
        write_word(32'h00000090, 32'h10201c03);
        write_word(32'h00000094, 32'h10205c83);
        write_word(32'h00000098, 32'h10300d03);
        write_word(32'h0000009c, 32'h10004d83);
        #24;
        rst = 1'b0;

        repeat (1500) @(posedge clk);

        check(1,  32'hFFFFFFFF, "addi -1");
        check(2,  32'hFFFFFFF0, "andi sign-extended imm");
        check(3,  32'hFFFFFFFE, "ori sign-extended imm");
        check(4,  32'h00000000, "xori sign-extended imm");
        check(7,  32'd70,       "sub");
        check(8,  32'd4,        "and");
        check(9,  32'd126,      "or");
        check(10, 32'd122,      "xor");
        check(11, 32'd120,      "slli");
        check(12, 32'h0000000F, "srli");
        check(13, 32'hFFFFFFFF, "srai");
        check(14, 32'd1,        "slt");
        check(15, 32'd0,        "sltu");
        check(16, 32'd1,        "slti");
        check(17, 32'd1,        "sltiu rs,1");
        check(18, 32'h12345000, "lui");
        check(19, 32'h00001048, "auipc");
        check(20, 32'd0,        "no taken-branch/jal fallthrough executed");
        check(21, 32'd1,        "beq not taken");
        check(22, 32'h00000080, "jal link");
        check(24, 32'hFFFF8000, "lh offset 2 sign");
        check(25, 32'h00008000, "lhu offset 2");
        check(26, 32'hFFFFFF80, "lb offset 3");
        check(27, 32'h000000FF, "lbu offset 0");

        if (errors == 0) $display("PASS: ALU, branch, jal, lui/auipc and sub-word load checks passed");
        else begin
            $display("FAIL: %0d mismatches", errors);
            $fatal(1, "alu_ctrl_mem_tb failed");
        end
        $finish;
    end

    task check;
        input integer index;
        input [31:0] expected;
        input [255:0] name;
        begin
            if (dut.cpu0.regfile0.regs[index] !== expected) begin
                errors = errors + 1;
                $display("FAIL %0s: x%0d = %h, expected %h", name, index,
                    dut.cpu0.regfile0.regs[index], expected);
            end
        end
    endtask

endmodule
