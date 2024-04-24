`timescale 1ns / 1ps  // 1.2.2018
// register file, triple-port

module Registers(
  input clk, rst, wr,
  input [3:0] rno0, rno1, rno2,
  input [31:0] din,
  output [31:0] dout0, dout1, dout2);

reg [31:0] R[15:0];
assign dout0 = R[rno0];
assign dout1 = R[rno1];
assign dout2 = R[rno2];
always @ (posedge clk)

	if (!rst) begin
		R[0] = 32'h0000_0000;
		R[1] = 32'h0000_0000;
		R[2] = 32'h0000_0000;
		R[3] = 32'h0000_0000;
		R[4] = 32'h0000_0000;
		R[5] = 32'h0000_0000;
		R[6] = 32'h0000_0000;
		R[7] = 32'h0000_0000;
		R[8] = 32'h0000_0000;
		R[9] = 32'h0000_0000;
		R[10] = 32'h0000_0000;
		R[11] = 32'h0000_0000;
		R[12] = 32'h0000_0000;
		R[13] = 32'h0000_0000;
		R[14] = 32'h0000_0000;
		R[15] = 32'h0000_0000;
	end else begin
		R[rno0] <= wr ? din : R[rno0];
	end

endmodule
