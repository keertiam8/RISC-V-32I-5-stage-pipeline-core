`timescale 1ns/1ps

package riscv_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    //------------------------------------------------------------
    // Transactions
    //------------------------------------------------------------

    // Driven into the DUT: what program to load and how long to run.
    class boot_item extends uvm_sequence_item;
        `uvm_object_utils(boot_item)

        string prog_path;
        int    run_cycles;

        function new(string name = "boot_item");
            super.new(name);
        endfunction
    endclass

    // Observed from the DUT: one committed register write.
    class reg_write_txn extends uvm_sequence_item;
        `uvm_object_utils(reg_write_txn)

        rand bit [4:0]  waddr;
        rand bit [31:0] wdata;
        bit [31:0]      pc;

        function new(string name = "reg_write_txn");
            super.new(name);
        endfunction

        function string convert2string();
            return $sformatf("pc=0x%08x  x%0d <= 0x%08x", pc, waddr, wdata);
        endfunction
    endclass

    //------------------------------------------------------------
    // Sequences
    //------------------------------------------------------------

    class boot_sequence extends uvm_sequence #(boot_item);
        `uvm_object_utils(boot_sequence)

        string prog_path   = "test/example.data";
        int    run_cycles  = 2000;

        function new(string name = "boot_sequence");
            super.new(name);
        endfunction

        task body();
            boot_item item = boot_item::type_id::create("item");
            start_item(item);
            item.prog_path  = prog_path;
            item.run_cycles = run_cycles;
            finish_item(item);
        endtask
    endclass

    //------------------------------------------------------------
    // Driver: loads memory image, releases reset, lets the CPU run
    // freely for N cycles.
    //------------------------------------------------------------

    class boot_driver extends uvm_driver #(boot_item);
        `uvm_component_utils(boot_driver)

        virtual cpu_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual cpu_if)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "cpu_if not set in config_db")
        endfunction

        task run_phase(uvm_phase phase);
            boot_item item;
            forever begin
                seq_item_port.get_next_item(item);

                vif.rst = 1'b1;
                vif.load_program(item.prog_path);
                repeat (10) @(posedge vif.clk);
                vif.rst = 1'b0;
                `uvm_info("BOOT_DRV", $sformatf("released reset, loaded %s", item.prog_path), UVM_LOW)

                repeat (item.run_cycles) @(posedge vif.clk);

                seq_item_port.item_done();
            end
        endtask
    endclass

    //------------------------------------------------------------
    // Monitor: watches the bound writeback probe, publishes a
    // reg_write_txn every time the register file is written.
    //------------------------------------------------------------

    class wb_monitor extends uvm_monitor;
        `uvm_component_utils(wb_monitor)

        virtual wb_probe_if vif;
        uvm_analysis_port #(reg_write_txn) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual wb_probe_if)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "wb_probe_if not set in config_db")
        endfunction

        task run_phase(uvm_phase phase);
            reg_write_txn txn;
            forever begin
                @(posedge vif.clk);
                if (!vif.rst && vif.wb_we && vif.wb_reg_waddr != 0) begin
                    txn = reg_write_txn::type_id::create("txn");
                    txn.waddr = vif.wb_reg_waddr;
                    txn.wdata = vif.wb_reg_wdata;
                    txn.pc    = vif.id_pc;
                    `uvm_info("WB_MON", txn.convert2string(), UVM_HIGH)
                    ap.write(txn);
                end
            end
        endtask
    endclass

    //------------------------------------------------------------
    // Scoreboard: tracks architectural register state and flags
    // obvious violations (x0 written, address out of range, etc.)
    // Extend `check_final()` with program-specific expected values.
    //------------------------------------------------------------

    class riscv_scoreboard extends uvm_subscriber #(reg_write_txn);
        `uvm_component_utils(riscv_scoreboard)

        bit [31:0] regfile [32];
        int        write_count;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void write(reg_write_txn t);
            write_count++;
            if (t.waddr == 0) begin
                `uvm_error("SB", "write to x0 observed - regfile should block this")
            end
            regfile[t.waddr] = t.wdata;
            `uvm_info("SB", $sformatf("commit: %s", t.convert2string()), UVM_MEDIUM)
        endfunction

        function void report_phase(uvm_phase phase);
            `uvm_info("SB", $sformatf("total register writes observed: %0d", write_count), UVM_LOW)
            if (write_count == 0)
                `uvm_error("SB", "no register writes observed - CPU likely never ran")
        endfunction
    endclass

    //------------------------------------------------------------
    // Agent / Env
    //------------------------------------------------------------

    class boot_agent extends uvm_agent;
        `uvm_component_utils(boot_agent)

        uvm_sequencer #(boot_item) sqr;
        boot_driver                drv;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sqr = uvm_sequencer#(boot_item)::type_id::create("sqr", this);
            drv = boot_driver::type_id::create("drv", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction
    endclass

    class riscv_env extends uvm_env;
        `uvm_component_utils(riscv_env)

        boot_agent        boot_agt;
        wb_monitor        wb_mon;
        riscv_scoreboard  sb;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            boot_agt = boot_agent::type_id::create("boot_agt", this);
            wb_mon   = wb_monitor::type_id::create("wb_mon", this);
            sb       = riscv_scoreboard::type_id::create("sb", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            wb_mon.ap.connect(sb.analysis_export);
        endfunction
    endclass

    //------------------------------------------------------------
    // Test
    //------------------------------------------------------------

    class riscv_base_test extends uvm_test;
        `uvm_component_utils(riscv_base_test)

        riscv_env env;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = riscv_env::type_id::create("env", this);
        endfunction

        task run_phase(uvm_phase phase);
            boot_sequence seq = boot_sequence::type_id::create("seq");
            if (!$value$plusargs("PROG=%s", seq.prog_path))
                seq.prog_path = "test/example.data";
            void'($value$plusargs("CYCLES=%d", seq.run_cycles));

            phase.raise_objection(this);
            seq.start(env.boot_agt.sqr);
            phase.drop_objection(this);
        endtask
    endclass

endpackage
