`timescale 1ns / 1ps  // 14.6.2018
// with SRAM, and gpio
// PS/2 mouse and network 7.1.2014 PDR
// machdyne port 16.4.2024 LDC

module RISC5Top(
  input CLK48M,
  input  RxD,   // RS-232
  output TxD,
  output led_r, led_g, led_b,
  output [7:0] ledsa,
  output [7:0] ledsb,
  output SRAM0_CS, SRAM0_OE, SRAM0_WE, SRAM0_LB, SRAM0_UB,
  output SRAM1_CS, SRAM1_OE, SRAM1_WE, SRAM1_LB, SRAM1_UB,
  output [17:0] SRadr,
  inout [31:0] SRdat,
  input MISO,          // SPI - SD card & network
  output SCLK, MOSI,
  output SS,
  output hsync, vsync, // video controller
  output [2:0] RGB,
  input PS2C, PS2D,    // keyboard
  inout msclk, msdat,
  inout [7:0] gpio);

assign led_r = 1;
assign led_g = 1;
assign led_b = spiCtrl[0];

reg [3:0] btn = 4'b0000;
reg [7:0] swi = 8'b0111_0110;
reg [7:0] gpin = 8'b00000000;

wire pll_locked;

wire CLK150M;
wire CLK75M;
wire CLK50M;

pll #() pll_i (
   .clkin(CLK48M),
   .clkout0(CLK150M),
   .clkout1(CLK75M),
   .clkout2(CLK50M),
   .locked(pll_locked)
);

wire SRwe;
wire SRoe;

assign SRwe = ~wr | clk;
assign SRoe = wr;
assign SRadr = vidreq ? vidadr : adr[19:2];

assign SRAM0_CS = 0;
assign SRAM1_CS = 0;

assign SRAM0_OE = SRoe;
assign SRAM1_OE = SRoe;

assign SRAM0_WE = SRwe;
assign SRAM1_WE = SRwe;

assign SRAM0_LB = ~(~ben | ~adr[0]);
assign SRAM0_UB = ~(~ben | adr[0]);
assign SRAM1_LB = ~(~ben | ~adr[1]);
assign SRAM1_UB = ~(~ben | adr[1]);

// IO addresses for input / output
// 0  -64  FFFFC0  milliseconds / --
// 1  -60  FFFFC4  switches / LEDs
// 2  -56  FFFFC8  RS-232 data / RS-232 data (start)
// 3  -52  FFFFCC  RS-232 status / RS-232 control
// 4  -48  FFFFD0  SPI data / SPI data (start)
// 5  -44  FFFFD4  SPI status / SPI control
// 6  -40  FFFFD8  PS2 mouse data, keyboard status / --
// 7  -36  FFFFDC  keyboard data / --
// 8  -32  FFFFE0  general-purpose I/O data
// 9  -28  FFFFE4  general-purpose I/O tri-state control

reg clk;
wire[23:0] adr;
wire [3:0] iowadr; // word address
wire [31:0] inbus, inbus0;  // data to RISC core
wire [31:0] outbus;  // data from RISC core
wire [31:0] romout, codebus;  // code to RISC core
wire rd, wr, ben, ioenb, vidreq;

wire [7:0] dataTx, dataRx, dataKbd;
wire rdyRx, doneRx, startTx, rdyTx, rdyKbd, doneKbd;
wire [27:0] dataMs;
reg bitrate;  // for RS232
wire limit;  // of cnt0

reg [7:0] Lreg;
reg [15:0] cnt0;
reg [31:0] cnt1; // milliseconds

wire [31:0] spiRx;
wire spiStart, spiRdy;
reg [3:0] spiCtrl;
wire [17:0] vidadr;
reg [7:0] gpout, gpoc;

RISC5 riscx(.clk(clk), .rst(rst), .irq(limit),
   .rd(rd), .wr(wr), .ben(ben), .stallX(vidreq),
   .adr(adr), .codebus(codebus), .inbus(inbus),
	.outbus(outbus));
PROM PM (.adr(adr[10:2]), .data(romout), .clk(~clk));
RS232R receiver(.clk(clk), .rst(rst), .RxD(RxD), .fsel(bitrate),
   .done(doneRx), .data(dataRx), .rdy(rdyRx));
RS232T transmitter(.clk(clk), .rst(rst), .start(startTx),
   .fsel(bitrate), .data(dataTx), .TxD(TxD), .rdy(rdyTx));
SPI spi(.clk(clk), .rst(rst), .start(spiStart), .dataTx(outbus),
   .fast(spiCtrl[2]), .dataRx(spiRx), .rdy(spiRdy),
 	.SCLK(SCLK), .MOSI(MOSI), .MISO(MISO));
VID vid(.clk(clk), .pclk(CLK75M), .req(vidreq), .inv(swi[7]),
   .vidadr(vidadr), .viddata(inbus0), .RGB(RGB),
	.hsync(hsync), .vsync(vsync));
PS2 kbd(.clk(clk), .rst(rst), .done(doneKbd), .rdy(rdyKbd), .shift(),
   .data(dataKbd), .PS2C(PS2C), .PS2D(PS2D));
MouseP Ms(.clk(clk), .rst(rst), .msclk(msclk),
   .msdat(msdat), .out(dataMs));

assign codebus = (adr[23:14] == 10'h3FF) ? romout : inbus0;
assign iowadr = adr[5:2];
assign ioenb = (adr[23:6] == 18'h3FFFF);
assign inbus = ~ioenb ? inbus0 :
   ((iowadr == 0) ? cnt1 :
    (iowadr == 1) ? {20'b0, btn, swi} :
    (iowadr == 2) ? {24'b0, dataRx} :
    (iowadr == 3) ? {30'b0, rdyTx, rdyRx} :
    (iowadr == 4) ? spiRx :
    (iowadr == 5) ? {31'b0, spiRdy} :
    (iowadr == 6) ? {3'b0, rdyKbd, dataMs} :
    (iowadr == 7) ? {24'b0, dataKbd} :
    (iowadr == 8) ? {24'b0, gpin} :
    (iowadr == 9) ? {24'b0, gpoc} : 0);
	 
genvar i;
generate // tri-state buffer for SRAM
	for (i = 0; i < 32; i = i + 1)
		begin: bufblock
			BB obz_i (
				.I(outbus[i]), .O(inbus0[i]), .B(SRdat[i]), .T(~wr)
			);
		end
endgenerate


assign dataTx = outbus[7:0];
assign startTx = wr & ioenb & (iowadr == 2);
assign doneRx = rd & ioenb & (iowadr == 2);
assign limit = (cnt0 == 24999);
assign ledsa = adr[7:0];
assign ledsb = Lreg;
assign spiStart = wr & ioenb & (iowadr == 4);
assign SS = ~spiCtrl[0];  //active low slave select
assign doneKbd = rd & ioenb & (iowadr == 7);

   reg [12:0] resetn_counter = 0;
   wire rst = &resetn_counter;

   always @(posedge clk) begin
      if (!pll_locked)
         resetn_counter <= 0;
      else if (!rst)
         resetn_counter <= resetn_counter + 1;
   end

always @(posedge clk)
begin
//  rst <= ((cnt1[4:0] == 0) & limit) ? ~btn[3] : rst;
  Lreg <= ~rst ? 0 : (wr & ioenb & (iowadr == 1)) ? outbus[7:0] : Lreg;
  cnt0 <= limit ? 0 : cnt0 + 1;
  cnt1 <= cnt1 + limit;
  spiCtrl <= ~rst ? 0 : (wr & ioenb & (iowadr == 5)) ? outbus[3:0] : spiCtrl;
  bitrate <= ~rst ? 0 : (wr & ioenb & (iowadr == 3)) ? outbus[0] : bitrate;
  gpout <= (wr & ioenb & (iowadr == 8)) ? outbus[7:0] : gpout;
  gpoc <= ~rst ? 0 : (wr & ioenb & (iowadr == 9)) ? outbus[7:0] : gpoc;
end

always @ (posedge CLK50M) clk <= ~clk;
endmodule
