`timescale 1ns/1ps

module root_cpu_tb;

    reg clk;
    reg rst;
    integer i;

    root_sim_top dut (
        .clk(clk),
        .rst(rst)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("root_cpu.vcd");
        $dumpvars(0, root_cpu_tb);

        rst = 1'b1;
        #25;
        rst = 1'b0;

        repeat (500) @(posedge clk);

        check_register(1, 32'd5);
        check_register(2, 32'd7);
        check_register(3, 32'd12);
        check_register(4, 32'd12);
        check_register(5, 32'd17);
        check_register(6, 32'd1);
        check_register(7, 32'd42);

        if (dut.memory0.memory[32'h100] !== 8'd12 ||
            dut.memory0.memory[32'h101] !== 8'd0 ||
            dut.memory0.memory[32'h102] !== 8'd0 ||
            dut.memory0.memory[32'h103] !== 8'd0) begin
            $fatal(1, "FAIL: memory[0x100] is %h%h%h%h, expected 0000000c",
                dut.memory0.memory[32'h103], dut.memory0.memory[32'h102],
                dut.memory0.memory[32'h101], dut.memory0.memory[32'h100]);
        end

        $display("PASS: root CPU arithmetic, store/load-use, and branch checks passed");
        $finish;
    end

    task check_register;
        input integer index;
        input [31:0] expected;
        begin
            if (dut.cpu0.regfile0.regs[index] !== expected)
                $fatal(1, "FAIL: x%0d = %h, expected %h", index,
                    dut.cpu0.regfile0.regs[index], expected);
        end
    endtask

endmodule
