module IKAOPLL_reg #(parameter FULLY_SYNCHRONOUS = 1, parameter VRC7_PATCH_CONFIG_MODE = 0, parameter INSTROM_STYLE = 0) (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock
    input   wire            i_phiM_PCEN_n,

    //master reset
    input   wire            i_IC_n,

    //internal clock
    input   wire            i_phi1_PCEN_n, //positive edge clock enable for emulation
    input   wire            i_phi1_NCEN_n, //negative edge clock enable for emulation

    input   wire            i_CS_n,
    input   wire            i_WR_n,
    input   wire            i_A0,
    
    input   wire    [7:0]   i_D,
    output  wire    [1:0]   o_D,
    output  wire            o_D_OE,

    input   wire            i_VRC7_EN,

    //timings
    input   wire            i_CYCLE_21, i_CYCLE_D3_ZZ, i_CYCLE_D4_ZZ, i_HALF_SUBCYCLE
);



///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            emuclk = i_EMUCLK;
wire            phiMpcen_n = i_phiM_PCEN_n;
wire            phi1pcen_n = i_phi1_PCEN_n;
wire            phi1ncen_n = i_phi1_NCEN_n;



///////////////////////////////////////////////////////////
//////  Write request synchronizer
////

wire            addrreg_wrrq, datareg_wrrq;
IKAOPLL_rw_synchronizer #(.FULLY_SYNCHRONOUS(FULLY_SYNCHRONOUS)) u_sync_addrreg(
    .i_EMUCLK(emuclk), .i_phiM_PCEN_n(phiMpcen_n), .i_phi1_NCEN_n(phi1ncen_n),
    .i_IC_n(i_IC_n), .i_IN(~|{i_CS_n, i_WR_n, i_A0}), .o_OUT(addrreg_wrrq)
);
IKAOPLL_rw_synchronizer #(.FULLY_SYNCHRONOUS(FULLY_SYNCHRONOUS)) u_sync_datareg(
    .i_EMUCLK(emuclk), .i_phiM_PCEN_n(phiMpcen_n), .i_phi1_NCEN_n(phi1ncen_n),
    .i_IC_n(i_IC_n), .i_IN(~|{i_CS_n, i_WR_n, ~i_A0}), .o_OUT(datareg_wrrq)
);



///////////////////////////////////////////////////////////
//////  Temporary data latch
////

wire    [7:0]   dbus_inlatch;

generate
if(FULLY_SYNCHRONOUS == 0) begin : FULLY_SYNCHRONOUS_0_inlatch

wire    [7:0]   dbus_inlatch_temp;
IKAOPLL_dlatch #(.WIDTH(8)) u_dbus_inlatch_temp (
    .i_EN(~|{i_CS_n, i_WR_n, ~i_IC_n}), .i_D(i_D), .o_Q(dbus_inlatch_temp)
);

assign  dbus_inlatch = dbus_inlatch_temp;

end
else begin : FULLY_SYNCHRONOUS_1_inlatch

reg     [7:0]   din_syncchain[0:1];
reg     [1:0]   cs_n_syncchain, wr_n_syncchain;
reg     [7:0]   dbus_inlatch_temp;

//make alias signals
wire            cs_n = cs_n_syncchain[1];
wire            wr_n = wr_n_syncchain[1];
wire    [7:0]   din = din_syncchain[1];

always @(posedge emuclk) begin
    din_syncchain[0] <= i_D;
    din_syncchain[1] <= din_syncchain[0];

    cs_n_syncchain[0] <= i_CS_n;
    cs_n_syncchain[1] <= cs_n_syncchain[0];

    wr_n_syncchain[0] <= i_WR_n;
    wr_n_syncchain[1] <= wr_n_syncchain[0];

    if(~|{cs_n, wr_n}) dbus_inlatch_temp <= din;
end

assign  dbus_inlatch = dbus_inlatch_temp;
    
end
endgenerate



///////////////////////////////////////////////////////////
//////  D1REG - parameter*1 register
////

//latch D1REG address, the original chip latches "decoded" register select bits
reg     [3:0]   d1reg_addr;
always @(posedge emuclk) if(!phi1ncen_n) if(addrreg_wrrq && dbus_inlatch[7:4] == 4'h0) d1reg_addr <= dbus_inlatch[3:0];

//D1REG pair, 0=modulator 1=carrier
reg     [1:0]   am_reg, pm_reg, etyp_reg, ksr_reg;
reg     [3:0]   mul_reg[0:1];
reg     [1:0]   ksl_reg[0:1];
reg     [3:0]   ar_reg[0:1];
reg     [3:0]   dr_reg[0:1];
reg     [3:0]   sl_reg[0:1];
reg     [3:0]   rr_reg[0:1];

//D1REG single
reg     [5:0]   tl_reg;
reg             dc_reg, dm_reg;
reg             fb_reg;
reg     [3:0]   test_reg;
reg     [5:0]   rhythm_reg;
reg             vrc7_en_reg;

`ifdef IKAOPLL_ASYNC_RST
always @(posedge emuclk or negedge i_IC_n)
`else
always @(posedge emuclk)
`endif
begin
    if(!i_IC_n) begin
        am_reg <= 2'b00; pm_reg <= 2'b00; etyp_reg <= 2'b00; ksr_reg <= 2'b00;
        mul_reg[0] <= 4'd0; mul_reg[1] <= 4'd0;
        ksl_reg[0] <= 2'd0; ksl_reg[1] <= 2'd0;
        ar_reg[0] <= 4'd0; ar_reg[1] <= 4'd0;
        dr_reg[0] <= 4'd0; dr_reg[1] <= 4'd0;
        sl_reg[0] <= 4'd0; sl_reg[1] <= 4'd0;
        rr_reg[0] <= 4'd0; rr_reg[1] <= 4'd0;

        tl_reg <= 6'd0;
        dc_reg <= 1'b0; dm_reg <= 1'b0;
        fb_reg <= 1'b0;
        test_reg <= 4'b0000;
        rhythm_reg <= 6'b000000;
    end
    else begin if(!phi1ncen_n) begin
        if(datareg_wrrq) begin
                 if(d1reg_addr[3:0] == 4'h0) {am_reg[0], pm_reg[0], etyp_reg[0], ksr_reg[0], mul_reg[0]} <= dbus_inlatch;
            else if(d1reg_addr[3:0] == 4'h1) {am_reg[1], pm_reg[1], etyp_reg[1], ksr_reg[1], mul_reg[1]} <= dbus_inlatch;
            else if(d1reg_addr[3:0] == 4'h2) {ksl_reg[0], tl_reg} <= dbus_inlatch;
            else if(d1reg_addr[3:0] == 4'h3) {ksl_reg[0], dc_reg, dm_reg, fb_reg} <= {dbus_inlatch[7:6], dbus_inlatch[4:0]};
            else if(d1reg_addr[3:0] == 4'h4) {ar_reg[0], dr_reg[0]} <= dbus_inlatch;
            else if(d1reg_addr[3:0] == 4'h5) {ar_reg[1], dr_reg[1]} <= dbus_inlatch;
            else if(d1reg_addr[3:0] == 4'h6) {sl_reg[0], rr_reg[0]} <= dbus_inlatch;
            else if(d1reg_addr[3:0] == 4'h7) {sl_reg[1], rr_reg[1]} <= dbus_inlatch;
            else if(d1reg_addr[3:0] == 4'hE) rhythm_reg <= dbus_inlatch[5:0];
            else if(d1reg_addr[3:0] == 4'hF) {vrc7_en_reg, test_reg} <= dbus_inlatch[4:0];
        end
    end end
end



///////////////////////////////////////////////////////////
//////  D9REG - parameter*9 register
////

//latch D9REG address
reg     [5:0]   d9reg_addr;
always @(posedge emuclk) if(!phi1ncen_n) if(addrreg_wrrq && dbus_inlatch[7:6] == 2'b00) d9reg_addr <= dbus_inlatch[5:0];

//D9REG enable
reg             d9reg_en;
always @(posedge emuclk) begin
    if(!i_IC_n) d9reg_en <= 1'b0;
    else begin if(!phi1ncen_n) begin
        if(addrreg_wrrq) d9reg_en <= dbus_inlatch[7:6] == 2'b00;
    end end
end

//latch D9REG data
reg     [7:0]   d9reg_data;
always @(posedge emuclk) begin
    if(!i_IC_n) d9reg_data <= 8'h00;
    else begin if(!phi1ncen_n) begin
        if(d9reg_en && datareg_wrrq) d9reg_data <= dbus_inlatch;
    end end
end

//D9REG address counter
reg     [4:0]   d9reg_addrcntr;
always @(posedge emuclk) if(!phi1ncen_n) begin
    if(i_CYCLE_21) d9reg_addrcntr <= 5'd0;
    else d9reg_addrcntr <= d9reg_addrcntr + 5'd1;
end

//D9REG write data queued flag
reg             d9reg_wrdata_queued_n; // = 1'b1;
wire            trace_d9reg_addrcntr = ~|{~i_IC_n, addrreg_wrrq, d9reg_wrdata_queued_n};
always @(posedge emuclk) if(!phi1ncen_n) begin
    d9reg_wrdata_queued_n <= ~(trace_d9reg_addrcntr | (d9reg_en && datareg_wrrq));
end

//address match signal
wire            d9reg_addr_match = d9reg_addrcntr[4] & (d9reg_addrcntr[3:0] == d9reg_addr[3:0]) & trace_d9reg_addrcntr;

//D9REG enable signals
wire            reg10_18_en = (d9reg_addr[5:4] == 2'b01) & d9reg_addr_match & ~i_IC_n;
wire            reg20_28_en = (d9reg_addr[5:4] == 2'b10) & d9reg_addr_match & ~i_IC_n;
wire            reg30_38_en = (d9reg_addr[5:4] == 2'b11) & d9reg_addr_match & ~i_IC_n;

//D9REG
wire    [8:0]   fnum_reg;
wire    [2:0]   block_reg;
wire            kon_reg, susen_reg;
wire    [3:0]   vol_reg, inst_reg;

IKAOPLL_d9reg #(8) u_fnum_lsbs (.i_EMUCLK(emuclk), .i_phi1_NCEN_n(phi1ncen_n), 
                                .i_EN(reg10_18_en), .i_TAPSEL({i_CYCLE_D4_ZZ, i_CYCLE_D3_ZZ}), .i_D(dbus_inlatch), .o_Q(fnum_reg[7:0]));

IKAOPLL_d9reg #(1) u_fnum_msb  (.i_EMUCLK(emuclk), .i_phi1_NCEN_n(phi1ncen_n), 
                                .i_EN(reg20_28_en), .i_TAPSEL({i_CYCLE_D4_ZZ, i_CYCLE_D3_ZZ}), .i_D(dbus_inlatch[0]), .o_Q(fnum_reg[8]));

IKAOPLL_d9reg #(3) u_block     (.i_EMUCLK(emuclk), .i_phi1_NCEN_n(phi1ncen_n), 
                                .i_EN(reg20_28_en), .i_TAPSEL({i_CYCLE_D4_ZZ, i_CYCLE_D3_ZZ}), .i_D(dbus_inlatch[3:1]), .o_Q(block_reg));

IKAOPLL_d9reg #(1) u_kon       (.i_EMUCLK(emuclk), .i_phi1_NCEN_n(phi1ncen_n), 
                                .i_EN(reg20_28_en), .i_TAPSEL({i_CYCLE_D4_ZZ, i_CYCLE_D3_ZZ}), .i_D(dbus_inlatch[4]), .o_Q(kon_reg));

IKAOPLL_d9reg #(1) u_susen     (.i_EMUCLK(emuclk), .i_phi1_NCEN_n(phi1ncen_n), 
                                .i_EN(reg20_28_en), .i_TAPSEL({i_CYCLE_D4_ZZ, i_CYCLE_D3_ZZ}), .i_D(dbus_inlatch[5]), .o_Q(susen_reg));

IKAOPLL_d9reg #(4) u_vol       (.i_EMUCLK(emuclk), .i_phi1_NCEN_n(phi1ncen_n), 
                                .i_EN(reg30_38_en), .i_TAPSEL({i_CYCLE_D4_ZZ, i_CYCLE_D3_ZZ}), .i_D(dbus_inlatch[3:0]), .o_Q(vol_reg));

IKAOPLL_d9reg #(4) u_inst      (.i_EMUCLK(emuclk), .i_phi1_NCEN_n(phi1ncen_n), 
                                .i_EN(reg30_38_en), .i_TAPSEL({i_CYCLE_D4_ZZ, i_CYCLE_D3_ZZ}), .i_D(dbus_inlatch[7:4]), .o_Q(inst_reg));



///////////////////////////////////////////////////////////
//////  INSTRUMENT ROM
////


IKAOPLL_instrom #(INSTROM_STYLE) u_intsrom (
    //chip clock
    .i_EMUCLK                   (emuclk                     ),
    .i_phi1_PCEN_n              (phi1pcen_n                 ),

    //1 = use the optional VRC7 enable register, 0 = use value from the off-chip
    .i_VRC7_EN                  (VRC7_PATCH_CONFIG_MODE ? vrc7_en_reg : i_VRC7_EN),

    .i_INST_ADDR                (inst_reg                   ),
    .i_BD0_SEL(), .i_BD1_SEL(), .i_SD_SEL(), .i_TT_SEL(), .i_TC_SEL(), .i_HH_SEL(),
    .i_MnC_SEL(i_HALF_SUBCYCLE),

    .o_TL_ROM(), .o_DC_ROM(), .o_DM_ROM(), .o_FB_ROM(),
    .o_AM_ROM(), .o_PM_ROM(), .o_ETYP_ROM(), .o_KSR_ROM(),
    .o_MUL_ROM(), .o_KSL_ROM(),
    .o_AR_ROM(), .o_DR_ROM(), .o_SL_ROM(), .o_RR_ROM()
);











endmodule

module IKAOPLL_rw_synchronizer #(parameter FULLY_SYNCHRONOUS = 1) (
    //chip clock
    input   wire            i_EMUCLK,
    input   wire            i_phiM_PCEN_n,
    input   wire            i_phi1_NCEN_n,

    input   wire            i_IC_n,

    input   wire            i_IN,
    output  wire            o_OUT
);

generate
if(FULLY_SYNCHRONOUS == 0) begin : FULLY_SYNCHRONOUS_0_busrq

wire            busrq_latched;
IKAOPLL_srlatch u_busrq_srlatch (
    .i_S((i_IN & i_IC_n) & ~o_OUT), .i_R(o_OUT | ~i_IC_n), .o_Q(busrq_latched)
);

reg     [2:0]   inreg;
assign          o_OUT = inreg[2];
always @(posedge i_EMUCLK) begin
    if(!i_IC_n) inreg <= 3'b000;
    else begin
        if(!i_phiM_PCEN_n) begin
            inreg[0] <= busrq_latched;
            inreg[1] <= inreg[0];
        end

        if(!i_phi1_NCEN_n) begin
            inreg[2] <= inreg[1];
        end
    end
end

end
else begin : FULLY_SYNCHRONOUS_1_busrq

reg     [2:0]   inreg;
assign          o_OUT = inreg[2];
always @(posedge i_EMUCLK) begin
    if(!i_IC_n) inreg <= 3'b000;
    else begin
        if(!i_phiM_PCEN_n) begin
            case({o_OUT, i_IN})
                2'b00: inreg[0] <= inreg[0];
                2'b01: inreg[0] <= 1'b1;
                2'b10: inreg[0] <= 1'b0;
                2'b11: inreg[0] <= 1'b0;
            endcase

            inreg[1] <= inreg[0];
        end

        if(!i_phi1_NCEN_n) begin
            inreg[2] <= inreg[1];
        end
    end
end

end
endgenerate

endmodule

module IKAOPLL_d9reg #(parameter WIDTH = 1) (
    //chip clock
    input   wire                    i_EMUCLK,
    input   wire                    i_phi1_NCEN_n,

    input   wire                    i_EN,
    input   wire    [1:0]           i_TAPSEL,

    input   wire    [WIDTH-1:0]     i_D,
    output  reg     [WIDTH-1:0]     o_Q
);

wire    [WIDTH-1:0]     d, q_0, q_1, q_2, q_last;
primitive_sr #(.WIDTH(WIDTH), .LENGTH(9), .TAP0(2), .TAP1(5), .TAP2(8)) u_d9reg 
(.i_EMUCLK(i_EMUCLK), .i_CEN_n(i_phi1_NCEN_n), .i_D(d), .o_Q_TAP0(q_0), .o_Q_TAP1(q_1), .o_Q_TAP2(q_2), .o_Q_LAST(q_last));

assign  d = i_EN ? i_D : q_last;

always @(*) begin
    case(i_TAPSEL)
        2'd0: o_Q = q_0;
        2'd1: o_Q = q_1;
        2'd2: o_Q = q_2;
        2'd3: o_Q = {WIDTH{1'b0}};
    endcase
end

endmodule

module IKAOPLL_instrom #(parameter INSTROM_STYLE = 0) (
    //chip clock
    input   wire            i_EMUCLK,
    input   wire            i_phi1_PCEN_n, //positive!

    input   wire            i_VRC7_EN,
    input   wire    [3:0]   i_INST_ADDR,
    input   wire            i_BD0_SEL, i_BD1_SEL, i_SD_SEL, i_TT_SEL, i_TC_SEL, i_HH_SEL,
    input   wire            i_MnC_SEL, //1=MOD 0=CAR

    output  wire    [5:0]   o_TL_ROM,
    output  wire            o_DC_ROM, o_DM_ROM,
    output  wire    [2:0]   o_FB_ROM,
    output  wire            o_AM_ROM, o_PM_ROM, o_ETYP_ROM, o_KSR_ROM,
    output  wire    [3:0]   o_MUL_ROM,
    output  wire    [1:0]   o_KSL_ROM,
    output  wire    [3:0]   o_AR_ROM, o_DR_ROM, o_SL_ROM, o_RR_ROM
);


///////////////////////////////////////////////////////////
//////  Address decoder
////

wire            percussion_sel = |{i_BD0_SEL, i_BD1_SEL, i_SD_SEL, i_TT_SEL, i_TC_SEL, i_HH_SEL};
reg     [5:0]   mem_addr;

always @(*) begin
    if(percussion_sel) begin
        case({i_BD0_SEL, i_BD1_SEL, i_SD_SEL, i_TT_SEL, i_TC_SEL, i_HH_SEL})
            6'b100000: mem_addr = {i_VRC7_EN, 1'b1, 4'h0};
            6'b010000: mem_addr = {i_VRC7_EN, 1'b1, 4'h1};
            6'b001000: mem_addr = {i_VRC7_EN, 1'b1, 4'h2};
            6'b000100: mem_addr = {i_VRC7_EN, 1'b1, 4'h3};
            6'b000010: mem_addr = {i_VRC7_EN, 1'b1, 4'h4};
            6'b000001: mem_addr = {i_VRC7_EN, 1'b1, 4'h5};
            default:   mem_addr = {i_VRC7_EN, 1'b1, 4'hF};
        endcase
    end
    else begin
        mem_addr = {i_VRC7_EN, 1'b0, i_INST_ADDR};
    end
end



///////////////////////////////////////////////////////////
//////  Data section
////

/*
    implementation note:
    rom style 0: Store both instrument and percussion parameters in a single BRAM
    rom style 1: Store instrument in a BRAM, store percussion parameters in LUTs
    rom style 2: Store both instrument and percussion parameters in LUTs
*/

reg     [62:0]  mem_q;

generate

//
//  ROM STYLE 0: Store both instrument and percussion parameters in a single BRAM
//
if(INSTROM_STYLE == 0) begin
always @(posedge i_EMUCLK) if(!i_phi1_PCEN_n) begin
    case(mem_addr)
        //                         D D              KS           KS
        //                    TL   C M FB  AM PM ET  R   MUL      L     AR       DR       SL       RR
        //                                 MC MC MC MC <-M><C-> M><C <-M><C-> <-M><C-> <-M><C-> <-M><C->
        //YM2413 patches
        6'h00: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;
        6'h01: mem_q <= 63'b011110_1_0_111_00_11_11_10_00010001_0000_11010111_00001000_00000001_00000111;
        6'h02: mem_q <= 63'b011010_0_1_101_00_01_00_10_00110001_0000_11011111_10000111_00100001_00110011;
        6'h03: mem_q <= 63'b011001_0_0_000_00_00_00_10_00110001_1000_11111100_00100100_00010010_00010011;
        6'h04: mem_q <= 63'b001110_0_0_111_00_01_11_10_00010001_0000_10100110_10000100_01110010_00000111;
        6'h05: mem_q <= 63'b011110_0_0_110_00_00_11_10_00100001_0000_11100111_00000110_00000010_00001000;
        6'h06: mem_q <= 63'b010110_0_0_101_00_00_11_10_00010010_0000_11100111_00000001_00000001_00001000;
        6'h07: mem_q <= 63'b011101_0_0_111_00_01_11_00_00010001_0000_10001000_00100001_00010000_00000111;
        6'h08: mem_q <= 63'b101101_1_0_100_00_00_11_00_00110001_0000_10100111_00100010_00000000_00000111;
        6'h09: mem_q <= 63'b011011_0_0_110_00_11_11_00_00010001_0000_01100110_01000101_00010001_00000111;
        6'h0A: mem_q <= 63'b001011_1_1_000_00_11_01_00_00010001_0000_10001111_01010111_01110000_00010111;
        6'h0B: mem_q <= 63'b000011_1_0_001_00_00_00_10_00110001_1000_11111110_10100100_00010000_00000100;
        6'h0C: mem_q <= 63'b100100_0_0_111_01_01_00_10_01110001_0000_11111111_10001000_00100001_00100010;
        6'h0D: mem_q <= 63'b001100_0_0_101_00_11_10_01_00010000_0000_11001111_00100101_00100100_00000010;
        6'h0E: mem_q <= 63'b010101_0_0_011_00_00_00_00_00010001_0100_11001001_10010101_00000000_00110010;
        6'h0F: mem_q <= 63'b001001_0_0_011_00_11_10_00_00010001_1000_11111110_00010100_01000001_00000011;

        6'h10: mem_q <= 63'b011000_0_1_111_00_00_00_00_00010000_0000_11010000_11110000_01100000_10100000; //bass drum 0
        6'h11: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000001_0000_00001111_00001000_00000110_00001101; //bass drum 1
        6'h12: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000001_0000_00001101_00001000_00000100_00001000; //snare drum 
        6'h13: mem_q <= 63'b000000_0_0_000_00_00_00_00_01010000_0000_11110000_10000000_01010000_10010000; //tom tom    
        6'h14: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000001_0000_00001010_00001010_00000101_00000101; //top cymbal 
        6'h15: mem_q <= 63'b000000_0_0_000_00_00_00_00_00010000_0000_11000000_10000000_10100000_01110000; //hi hat     
        6'h16: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;
        6'h17: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;
        6'h18: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;
        6'h19: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;
        6'h1A: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;
        6'h1B: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;
        6'h1C: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;
        6'h1D: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;
        6'h1E: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;
        6'h1F: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;

        //VRC7 patches
        6'h20: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;
        6'h21: mem_q <= 63'b000101_0_0_110_00_00_01_00_00110001_0000_11101000_10000001_01000010_00100111;
        6'h22: mem_q <= 63'b010100_0_1_101_00_01_00_10_00110001_0000_11011111_10000110_00100001_00110010;
        6'h23: mem_q <= 63'b001000_0_1_000_00_00_00_11_00010001_0000_11111011_10100010_00100001_00000010;
        6'h24: mem_q <= 63'b001100_0_0_111_00_01_11_10_00010001_0000_10100110_10000100_01100010_00010111;
        6'h25: mem_q <= 63'b011110_0_0_110_00_00_11_10_00100001_0000_11100111_00010110_00000010_00011000;
        6'h26: mem_q <= 63'b000110_0_0_000_00_00_00_00_00100001_0000_10101110_00110010_11111111_01000100;
        6'h27: mem_q <= 63'b011101_0_0_111_00_01_11_00_00010001_0000_10001000_00100001_00010000_00010111;
        6'h28: mem_q <= 63'b100010_1_0_111_00_00_11_00_00110001_0000_10100111_00100010_00000001_00010111;
        6'h29: mem_q <= 63'b100101_0_0_000_00_00_10_11_01010001_0000_01000111_00000011_01110000_00100001;
        6'h2A: mem_q <= 63'b001111_0_1_111_10_00_10_10_01010001_0000_10101010_10000101_01010000_00010010;
        6'h2B: mem_q <= 63'b100100_0_0_111_01_01_00_10_01110001_0000_11111111_10001000_00100001_00100010;
        6'h2C: mem_q <= 63'b010001_0_0_110_00_10_11_10_00010011_0000_01100111_01010100_00010001_10000110;
        6'h2D: mem_q <= 63'b010011_0_0_101_00_00_00_00_00010010_1100_11001001_10010101_00000000_00110010;
        6'h2E: mem_q <= 63'b001100_0_0_000_00_11_11_00_00010011_0000_10011100_01000000_00111111_00110110;
        6'h2F: mem_q <= 63'b001101_0_0_000_00_01_11_01_00010010_0000_11001101_00010101_01010000_01100110;

        6'h30: mem_q <= 63'b011000_0_1_111_00_00_00_00_00010000_0000_11010000_11110000_01100000_10100000; //bass drum 0
        6'h31: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000001_0000_00001111_00001000_00000110_00001101; //bass drum 1
        6'h32: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000001_0000_00001101_00001000_00000100_00001000; //snare drum 
        6'h33: mem_q <= 63'b000000_0_0_000_00_00_00_00_01010000_0000_11110000_10000000_01010000_10010000; //tom tom    
        6'h34: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000001_0000_00001010_00001010_00000101_00000101; //top cymbal 
        6'h35: mem_q <= 63'b000000_0_0_000_00_00_00_00_00010000_0000_11000000_10000000_10100000_01110000; //hi hat     
        6'h36: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;
        6'h37: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;
        6'h38: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;
        6'h39: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;
        6'h3A: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;
        6'h3B: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;
        6'h3C: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;
        6'h3D: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;
        6'h3E: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;
        6'h3F: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;
    endcase
end
end


//
//  ROM STYLE 1: Store instrument in a BRAM, store percussion parameters in LUTs
//
else if(INSTROM_STYLE == 1) begin

reg     [62:0]  inst_q;
reg     [62:0]  perc_q;

reg             ipsel; //instrument/percussion select
always @(posedge i_EMUCLK) if(!i_phi1_PCEN_n) ipsel <= mem_addr[4]; //delay address bit to select data properly
always @(*) mem_q = ipsel ? perc_q : inst_q;

always @(posedge i_EMUCLK) if(!i_phi1_PCEN_n) begin

    //BLOCK RAM REGION
    case({mem_addr[5], mem_addr[3:0]})
        //                          D D              KS           KS
        //                     TL   C M FB  AM PM ET  R   MUL      L     AR       DR       SL       RR
        //                                  MC MC MC MC <-M><C-> M><C <-M><C-> <-M><C-> <-M><C-> <-M><C->
        //YM2413 patches
        5'h00: inst_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;
        5'h01: inst_q <= 63'b011110_1_0_111_00_11_11_10_00010001_0000_11010111_00001000_00000001_00000111;
        5'h02: inst_q <= 63'b011010_0_1_101_00_01_00_10_00110001_0000_11011111_10000111_00100001_00110011;
        5'h03: inst_q <= 63'b011001_0_0_000_00_00_00_10_00110001_1000_11111100_00100100_00010010_00010011;
        5'h04: inst_q <= 63'b001110_0_0_111_00_01_11_10_00010001_0000_10100110_10000100_01110010_00000111;
        5'h05: inst_q <= 63'b011110_0_0_110_00_00_11_10_00100001_0000_11100111_00000110_00000010_00001000;
        5'h06: inst_q <= 63'b010110_0_0_101_00_00_11_10_00010010_0000_11100111_00000001_00000001_00001000;
        5'h07: inst_q <= 63'b011101_0_0_111_00_01_11_00_00010001_0000_10001000_00100001_00010000_00000111;
        5'h08: inst_q <= 63'b101101_1_0_100_00_00_11_00_00110001_0000_10100111_00100010_00000000_00000111;
        5'h09: inst_q <= 63'b011011_0_0_110_00_11_11_00_00010001_0000_01100110_01000101_00010001_00000111;
        5'h0A: inst_q <= 63'b001011_1_1_000_00_11_01_00_00010001_0000_10001111_01010111_01110000_00010111;
        5'h0B: inst_q <= 63'b000011_1_0_001_00_00_00_10_00110001_1000_11111110_10100100_00010000_00000100;
        5'h0C: inst_q <= 63'b100100_0_0_111_01_01_00_10_01110001_0000_11111111_10001000_00100001_00100010;
        5'h0D: inst_q <= 63'b001100_0_0_101_00_11_10_01_00010000_0000_11001111_00100101_00100100_00000010;
        5'h0E: inst_q <= 63'b010101_0_0_011_00_00_00_00_00010001_0100_11001001_10010101_00000000_00110010;
        5'h0F: inst_q <= 63'b001001_0_0_011_00_11_10_00_00010001_1000_11111110_00010100_01000001_00000011;

        //VRC7 patches
        5'h10: inst_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;
        5'h11: inst_q <= 63'b000101_0_0_110_00_00_01_00_00110001_0000_11101000_10000001_01000010_00100111;
        5'h12: inst_q <= 63'b010100_0_1_101_00_01_00_10_00110001_0000_11011111_10000110_00100001_00110010;
        5'h13: inst_q <= 63'b001000_0_1_000_00_00_00_11_00010001_0000_11111011_10100010_00100001_00000010;
        5'h14: inst_q <= 63'b001100_0_0_111_00_01_11_10_00010001_0000_10100110_10000100_01100010_00010111;
        5'h15: inst_q <= 63'b011110_0_0_110_00_00_11_10_00100001_0000_11100111_00010110_00000010_00011000;
        5'h16: inst_q <= 63'b000110_0_0_000_00_00_00_00_00100001_0000_10101110_00110010_11111111_01000100;
        5'h17: inst_q <= 63'b011101_0_0_111_00_01_11_00_00010001_0000_10001000_00100001_00010000_00010111;
        5'h18: inst_q <= 63'b100010_1_0_111_00_00_11_00_00110001_0000_10100111_00100010_00000001_00010111;
        5'h19: inst_q <= 63'b100101_0_0_000_00_00_10_11_01010001_0000_01000111_00000011_01110000_00100001;
        5'h1A: inst_q <= 63'b001111_0_1_111_10_00_10_10_01010001_0000_10101010_10000101_01010000_00010010;
        5'h1B: inst_q <= 63'b100100_0_0_111_01_01_00_10_01110001_0000_11111111_10001000_00100001_00100010;
        5'h1C: inst_q <= 63'b010001_0_0_110_00_10_11_10_00010011_0000_01100111_01010100_00010001_10000110;
        5'h1D: inst_q <= 63'b010011_0_0_101_00_00_00_00_00010010_1100_11001001_10010101_00000000_00110010;
        5'h1E: inst_q <= 63'b001100_0_0_000_00_11_11_00_00010011_0000_10011100_01000000_00111111_00110110;
        5'h1F: inst_q <= 63'b001101_0_0_000_00_01_11_01_00010010_0000_11001101_00010101_01010000_01100110;
    endcase

    //LUT REGION
    case(mem_addr[2:0])
        3'h0:  perc_q <= 63'b011000_0_1_111_00_00_00_00_00010000_0000_11010000_11110000_01100000_10100000; //bass drum 0
        3'h1:  perc_q <= 63'b000000_0_0_000_00_00_00_00_00000001_0000_00001111_00001000_00000110_00001101; //bass drum 1
        3'h2:  perc_q <= 63'b000000_0_0_000_00_00_00_00_00000001_0000_00001101_00001000_00000100_00001000; //snare drum 
        3'h3:  perc_q <= 63'b000000_0_0_000_00_00_00_00_01010000_0000_11110000_10000000_01010000_10010000; //tom tom    
        3'h4:  perc_q <= 63'b000000_0_0_000_00_00_00_00_00000001_0000_00001010_00001010_00000101_00000101; //top cymbal 
        3'h5:  perc_q <= 63'b000000_0_0_000_00_00_00_00_00010000_0000_11000000_10000000_10100000_01110000; //hi hat   
        default: perc_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;  
    endcase
end
end

//
//  ROM STYLE 2: Store both instrument and percussion parameters in LUTs
//
else if(INSTROM_STYLE == 2) begin
always @(posedge i_EMUCLK) if(!i_phi1_PCEN_n) begin
    case(mem_addr)
        //                         D D              KS           KS
        //                    TL   C M FB  AM PM ET  R   MUL      L     AR       DR       SL       RR
        //                                 MC MC MC MC <-M><C-> M><C <-M><C-> <-M><C-> <-M><C-> <-M><C->
        //YM2413 patches
        6'h01: mem_q <= 63'b011110_1_0_111_00_11_11_10_00010001_0000_11010111_00001000_00000001_00000111;
        6'h02: mem_q <= 63'b011010_0_1_101_00_01_00_10_00110001_0000_11011111_10000111_00100001_00110011;
        6'h03: mem_q <= 63'b011001_0_0_000_00_00_00_10_00110001_1000_11111100_00100100_00010010_00010011;
        6'h04: mem_q <= 63'b001110_0_0_111_00_01_11_10_00010001_0000_10100110_10000100_01110010_00000111;
        6'h05: mem_q <= 63'b011110_0_0_110_00_00_11_10_00100001_0000_11100111_00000110_00000010_00001000;
        6'h06: mem_q <= 63'b010110_0_0_101_00_00_11_10_00010010_0000_11100111_00000001_00000001_00001000;
        6'h07: mem_q <= 63'b011101_0_0_111_00_01_11_00_00010001_0000_10001000_00100001_00010000_00000111;
        6'h08: mem_q <= 63'b101101_1_0_100_00_00_11_00_00110001_0000_10100111_00100010_00000000_00000111;
        6'h09: mem_q <= 63'b011011_0_0_110_00_11_11_00_00010001_0000_01100110_01000101_00010001_00000111;
        6'h0A: mem_q <= 63'b001011_1_1_000_00_11_01_00_00010001_0000_10001111_01010111_01110000_00010111;
        6'h0B: mem_q <= 63'b000011_1_0_001_00_00_00_10_00110001_1000_11111110_10100100_00010000_00000100;
        6'h0C: mem_q <= 63'b100100_0_0_111_01_01_00_10_01110001_0000_11111111_10001000_00100001_00100010;
        6'h0D: mem_q <= 63'b001100_0_0_101_00_11_10_01_00010000_0000_11001111_00100101_00100100_00000010;
        6'h0E: mem_q <= 63'b010101_0_0_011_00_00_00_00_00010001_0100_11001001_10010101_00000000_00110010;
        6'h0F: mem_q <= 63'b001001_0_0_011_00_11_10_00_00010001_1000_11111110_00010100_01000001_00000011;

        6'h10: mem_q <= 63'b011000_0_1_111_00_00_00_00_00010000_0000_11010000_11110000_01100000_10100000; //bass drum 0
        6'h11: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000001_0000_00001111_00001000_00000110_00001101; //bass drum 1
        6'h12: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000001_0000_00001101_00001000_00000100_00001000; //snare drum 
        6'h13: mem_q <= 63'b000000_0_0_000_00_00_00_00_01010000_0000_11110000_10000000_01010000_10010000; //tom tom    
        6'h14: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000001_0000_00001010_00001010_00000101_00000101; //top cymbal 
        6'h15: mem_q <= 63'b000000_0_0_000_00_00_00_00_00010000_0000_11000000_10000000_10100000_01110000; //hi hat     

        //VRC7 patches
        6'h21: mem_q <= 63'b000101_0_0_110_00_00_01_00_00110001_0000_11101000_10000001_01000010_00100111;
        6'h22: mem_q <= 63'b010100_0_1_101_00_01_00_10_00110001_0000_11011111_10000110_00100001_00110010;
        6'h23: mem_q <= 63'b001000_0_1_000_00_00_00_11_00010001_0000_11111011_10100010_00100001_00000010;
        6'h24: mem_q <= 63'b001100_0_0_111_00_01_11_10_00010001_0000_10100110_10000100_01100010_00010111;
        6'h25: mem_q <= 63'b011110_0_0_110_00_00_11_10_00100001_0000_11100111_00010110_00000010_00011000;
        6'h26: mem_q <= 63'b000110_0_0_000_00_00_00_00_00100001_0000_10101110_00110010_11111111_01000100;
        6'h27: mem_q <= 63'b011101_0_0_111_00_01_11_00_00010001_0000_10001000_00100001_00010000_00010111;
        6'h28: mem_q <= 63'b100010_1_0_111_00_00_11_00_00110001_0000_10100111_00100010_00000001_00010111;
        6'h29: mem_q <= 63'b100101_0_0_000_00_00_10_11_01010001_0000_01000111_00000011_01110000_00100001;
        6'h2A: mem_q <= 63'b001111_0_1_111_10_00_10_10_01010001_0000_10101010_10000101_01010000_00010010;
        6'h2B: mem_q <= 63'b100100_0_0_111_01_01_00_10_01110001_0000_11111111_10001000_00100001_00100010;
        6'h2C: mem_q <= 63'b010001_0_0_110_00_10_11_10_00010011_0000_01100111_01010100_00010001_10000110;
        6'h2D: mem_q <= 63'b010011_0_0_101_00_00_00_00_00010010_1100_11001001_10010101_00000000_00110010;
        6'h2E: mem_q <= 63'b001100_0_0_000_00_11_11_00_00010011_0000_10011100_01000000_00111111_00110110;
        6'h2F: mem_q <= 63'b001101_0_0_000_00_01_11_01_00010010_0000_11001101_00010101_01010000_01100110;

        6'h30: mem_q <= 63'b011000_0_1_111_00_00_00_00_00010000_0000_11010000_11110000_01100000_10100000; //bass drum 0
        6'h31: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000001_0000_00001111_00001000_00000110_00001101; //bass drum 1
        6'h32: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000001_0000_00001101_00001000_00000100_00001000; //snare drum 
        6'h33: mem_q <= 63'b000000_0_0_000_00_00_00_00_01010000_0000_11110000_10000000_01010000_10010000; //tom tom    
        6'h34: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000001_0000_00001010_00001010_00000101_00000101; //top cymbal 
        6'h35: mem_q <= 63'b000000_0_0_000_00_00_00_00_00010000_0000_11000000_10000000_10100000_01110000; //hi hat    

        default: mem_q <= 63'b000000_0_0_000_00_00_00_00_00000000_0000_00000000_00000000_00000000_00000000;   
    endcase
end
end
endgenerate



///////////////////////////////////////////////////////////
//////  Data selector
////

reg             m_nc_sel_z;
always @(posedge i_EMUCLK) if(!i_phi1_PCEN_n) m_nc_sel_z <= i_MnC_SEL; //delay select bit to select data properly

assign  o_RR_ROM   = m_nc_sel_z ? mem_q[7:4] : mem_q[3:0];
assign  o_SL_ROM   = m_nc_sel_z ? mem_q[15:12] : mem_q[11:8];
assign  o_DR_ROM   = m_nc_sel_z ? mem_q[23:20] : mem_q[19:16];
assign  o_AR_ROM   = m_nc_sel_z ? mem_q[31:28] : mem_q[27:24];

assign  o_KSL_ROM  = m_nc_sel_z ? mem_q[35:34] : mem_q[33:32];

assign  o_MUL_ROM  = m_nc_sel_z ? mem_q[43:40] : mem_q[39:36];

assign  o_KSR_ROM  = m_nc_sel_z ? mem_q[45] : mem_q[44];
assign  o_ETYP_ROM = m_nc_sel_z ? mem_q[47] : mem_q[46];
assign  o_PM_ROM   = m_nc_sel_z ? mem_q[49] : mem_q[48];
assign  o_AM_ROM   = m_nc_sel_z ? mem_q[51] : mem_q[50];

assign  o_FB_ROM   = mem_q[54:52];

assign  o_DM_ROM   = mem_q[55];
assign  o_DC_ROM   = mem_q[56];

assign  o_TL_ROM   = mem_q[62:57];

endmodule