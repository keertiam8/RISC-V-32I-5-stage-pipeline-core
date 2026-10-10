`include "defines.v"

module stage_if (
	input  wire               clk       ,
	input  wire               rst       ,
	input  wire [`MemAddrBus] pc_i      ,
	input  wire [    `RegBus] mem_data_i,
	input  wire               mem_busy  ,
	input  wire               mem_done  ,
	input  wire               br        ,
	input  wire               right_one ,
	output reg                mem_re    ,
	output reg  [`MemAddrBus] mem_addr_o,
	output reg  [`MemAddrBus] pc_o      ,
	output reg  [   `InstBus] inst_o    ,
	output reg                stallreq
);

	reg mem_taking;
	reg waiting_one;
	reg next_mem_taking;
	reg next_waiting_one;

	always @ (*) begin
		stallreq       = 0;
		mem_re         = 0;
		mem_addr_o     = 0;
		pc_o           = 0;
		inst_o         = 0;
		next_mem_taking = mem_taking;
		next_waiting_one = waiting_one;

		if (right_one)
			next_waiting_one = 0;

		if (rst) begin
			next_mem_taking = 0;
			next_waiting_one = 0;
		end else if (br) begin
			next_mem_taking = 0;
			next_waiting_one = 1;
		end else if (!waiting_one && !mem_busy && !mem_taking) begin
			stallreq = 1;
			mem_re = 1;
			mem_addr_o = pc_i;
			next_mem_taking = 1;
		end else if (!waiting_one && mem_taking && mem_done) begin
			pc_o = pc_i;
			inst_o = mem_data_i;
			next_mem_taking = 0;
		end else if (!waiting_one && mem_taking) begin
			stallreq = 1;
		end else if (!waiting_one && mem_busy) begin
			stallreq = 1;
		end else if (waiting_one) begin
			next_mem_taking = 0;
			next_waiting_one = 0;
		end
	end

	always @ (posedge clk or posedge rst) begin
		if (rst) begin
			mem_taking <= 0;
			waiting_one <= 0;
		end else begin
			mem_taking <= next_mem_taking;
			waiting_one <= next_waiting_one;
		end
	end

endmodule // stage_if