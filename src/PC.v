module PC_Module(clk,rst,PC,PC_Next);
    input clk,rst;
    input [31:0] PC_Next;
    output reg [31:0] PC;

    always @(posedge clk or negedge rst)
    begin
        if(rst == 1'b0)
            PC <= 32'b0;
        else
            PC <= PC_Next;
    end
endmodule
