module IKAOPLL_pg #(parameter USE_PIPELINED_MULTIPLIER = 1) (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock
    input   wire            i_phiM_PCEN_n,

    //master reset
    input   wire            i_IC_n,

    //internal clock
    input   wire            i_phi1_PCEN_n, //positive edge clock enable for emulation
    input   wire            i_phi1_NCEN_n, //negative edge clock enable for emulation

    //timings
    input   wire            i_CYCLE_17, i_CYCLE_20, i_CYCLE_21,

    //parameters
    input   wire            i_RHYTHM_EN,
    input   wire    [8:0]   i_FNUM,
    input   wire    [2:0]   i_BLOCK,
    input   wire            i_PM,
    input   wire    [2:0]   i_PMVAL,
    input   wire    [3:0]   i_MUL,
    input   wire    [3:0]   i_TEST,

    //control
    input   wire            i_PG_PHASE_RST,

    //output
    output  wire    [9:0]   o_OP_PHASE
);


///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            emuclk = i_EMUCLK;
wire            phiMpcen_n = i_phiM_PCEN_n;
wire            phi1pcen_n = i_phi1_PCEN_n;
wire            phi1ncen_n = i_phi1_NCEN_n;



///////////////////////////////////////////////////////////
//////  Cycle 0: Latch FNUM and BLOCK
////

reg     [8:0]   cyc0r_fnum;
reg     [2:0]   cyc0r_block;
reg     [3:0]   cyc0r_mul;
reg             cyc0r_pm;
always @(posedge emuclk) if(!phi1ncen_n) begin
    cyc0r_fnum <= i_FNUM;
    cyc0r_block <= i_BLOCK;
    cyc0r_mul <= i_MUL;
    cyc0r_pm <= i_PM;
end



//declare cyc3r variable first
reg     [18:0]  cyc3r_phase_current;

//cycle 18 out
wire    [18:0]  cyc18r_phase_sr_out;

generate
if(USE_PIPELINED_MULTIPLIER == 1) begin : USE_PIPELINED_MULTIPLIER_1

///////////////////////////////////////////////////////////
//////  Cycle 1: Add PMVAL and shift
////

//make phase modulation value using high bits of the FNUM
wire            cyc1c_pmamt_sign = i_PMVAL[2] & cyc0r_pm;
reg     [2:0]   cyc1c_pmamt_val;
always @(*) begin
    case(i_PMVAL[1:0] & {2{cyc0r_pm}})
        2'b00: cyc1c_pmamt_val = 3'b000                  ^ {3{cyc1c_pmamt_sign}};
        2'b01: cyc1c_pmamt_val = {1'b0, cyc0r_fnum[8:7]} ^ {3{cyc1c_pmamt_sign}};
        2'b10: cyc1c_pmamt_val = {cyc0r_fnum[8:6]}       ^ {3{cyc1c_pmamt_sign}};
        2'b11: cyc1c_pmamt_val = {1'b0, cyc0r_fnum[8:7]} ^ {3{cyc1c_pmamt_sign}};
    endcase
end

//modulate phase by adding the modulation value
wire    [10:0]  cyc1c_phase_modded_val = {cyc0r_fnum, 1'b0} + {{7{cyc1c_pmamt_sign}}, cyc1c_pmamt_val} + cyc1c_pmamt_sign;
wire            cyc1c_phase_modded_sign = cyc1c_phase_modded_val[10] & ~cyc1c_pmamt_sign;
wire    [10:0]  cyc1c_phase_modded = {cyc1c_phase_modded_sign, cyc1c_phase_modded_val[9:0]}; 

//do block shift(octave)
reg     [13:0]  cyc1c_blockshifter0;
reg     [16:0]  cyc1c_blockshifter1;
always @(*) begin
    case(cyc0r_block[1:0])
        2'b00: cyc1c_blockshifter0 = {3'b000, cyc1c_phase_modded};
        2'b01: cyc1c_blockshifter0 = {2'b00, cyc1c_phase_modded, 1'b0};
        2'b10: cyc1c_blockshifter0 = {1'b0, cyc1c_phase_modded, 2'b00};
        2'b11: cyc1c_blockshifter0 = {cyc1c_phase_modded, 3'b000};
    endcase

    case(cyc1c_blockshifter1[2])
        1'b0: cyc1c_blockshifter1 = {cyc1c_blockshifter0, 3'b000};
        1'b1: cyc1c_blockshifter1 = {4'b0000, cyc1c_blockshifter0[13:1]};
    endcase
end

//register part
reg     [3:0]   cyc1r_mul;
reg     [16:0]  cyc1r_phase_shifted;
reg     [18:0]  cyc1r_phase_prev;
always @(posedge emuclk) if(!phi1ncen_n) begin
    cyc1r_mul <= cyc0r_mul;
    cyc1r_phase_shifted <= cyc1c_blockshifter1;

    cyc1r_phase_prev <= ~(~i_PG_PHASE_RST | i_TEST[2]) ? cyc18r_phase_sr_out : 19'd0;
end



///////////////////////////////////////////////////////////
//////  Cycle 2: Apply MUL
////

reg     [20:0]  cyc2r_phase_multiplied; //use 19-bit only
reg     [18:0]  cyc2r_phase_prev;
always @(posedge emuclk) if(!phi1ncen_n) begin
    cyc2r_phase_multiplied <= cyc1r_phase_shifted * cyc1r_mul;

    cyc2r_phase_prev <= cyc1r_phase_prev;
end



///////////////////////////////////////////////////////////
//////  Cycle 3: Add phase delta to the previous phase
////

always @(posedge emuclk) if(!phi1ncen_n) begin
    cyc3r_phase_current <= cyc2r_phase_multiplied[18:0] + cyc2r_phase_prev;
end

end
else begin : USE_PIPELINED_MULTIPLIER_0

///////////////////////////////////////////////////////////
//////  Cycle 1: Add PMVAL, shift, and apply MUL
////

//make phase modulation value using high bits of the FNUM
wire            cyc1c_pmamt_sign = i_PMVAL[2] & cyc0r_pm;
reg     [2:0]   cyc1c_pmamt_val;
always @(*) begin
    case(i_PMVAL[1:0] & {2{cyc0r_pm}})
        2'b00: cyc1c_pmamt_val = 3'b000                  ^ {3{cyc1c_pmamt_sign}};
        2'b01: cyc1c_pmamt_val = {1'b0, cyc0r_fnum[8:7]} ^ {3{cyc1c_pmamt_sign}};
        2'b10: cyc1c_pmamt_val = {cyc0r_fnum[8:6]}       ^ {3{cyc1c_pmamt_sign}};
        2'b11: cyc1c_pmamt_val = {1'b0, cyc0r_fnum[8:7]} ^ {3{cyc1c_pmamt_sign}};
    endcase
end

//modulate phase by adding the modulation value
wire    [10:0]  cyc1c_phase_modded_val = {cyc0r_fnum, 1'b0} + {{7{cyc1c_pmamt_sign}}, cyc1c_pmamt_val} + cyc1c_pmamt_sign;
wire            cyc1c_phase_modded_sign = cyc1c_phase_modded_val[10] & ~cyc1c_pmamt_sign;
wire    [10:0]  cyc1c_phase_modded = {cyc1c_phase_modded_sign, cyc1c_phase_modded_val[9:0]}; 

//do block shift(octave)
reg     [13:0]  cyc1c_blockshifter0;
reg     [16:0]  cyc1c_blockshifter1;
always @(*) begin
    case(cyc0r_block[1:0])
        2'b00: cyc1c_blockshifter0 = {3'b000, cyc1c_phase_modded};
        2'b01: cyc1c_blockshifter0 = {2'b00, cyc1c_phase_modded, 1'b0};
        2'b10: cyc1c_blockshifter0 = {1'b0, cyc1c_phase_modded, 2'b00};
        2'b11: cyc1c_blockshifter0 = {cyc1c_phase_modded, 3'b000};
    endcase

    case(cyc1c_blockshifter1[2])
        1'b0: cyc1c_blockshifter1 = {cyc1c_blockshifter0, 3'b000};
        1'b1: cyc1c_blockshifter1 = {4'b0000, cyc1c_blockshifter0[13:1]};
    endcase
end

//apply MUL
reg     [20:0]  cyc1c_phase_multiplied = cyc1c_blockshifter1 * cyc0r_mul;

//previous phase
wire    [18:0]  cyc1c_phase_prev;

//register part
reg     [18:0]  cyc1r_phase_multiplied;
reg     [18:0]  cyc1r_phase_prev;
always @(posedge emuclk) if(!phi1ncen_n) begin
    cyc1r_phase_multiplied <= cyc1c_phase_multiplied[18:0];
    cyc1r_phase_prev <= ~(~i_PG_PHASE_RST | i_TEST[2]) ? cyc18r_phase_sr_out : 19'd0;
end



///////////////////////////////////////////////////////////
//////  Cycle 2: Add phase delta to the previous phase
////

reg     [18:0]  cyc2r_phase_current;
always @(posedge emuclk) if(!phi1ncen_n) begin
    cyc2r_phase_current <= cyc1r_phase_multiplied + cyc1r_phase_prev;
end



///////////////////////////////////////////////////////////
//////  Cycle 3: NOP
////

always @(posedge emuclk) if(!phi1ncen_n) begin
    cyc3r_phase_current <= cyc2r_phase_current;
end

end
endgenerate



///////////////////////////////////////////////////////////
//////  Cycle 4-18: delay shift register
////

IKAOPLL_sr #(.WIDTH(18), .LENGTH(15)) u_cyc4r_cyc18r_phase_sr
(.i_EMUCLK(emuclk), .i_CEN_n(phi1ncen_n), .i_D(cyc3r_phase_current), .o_Q_LAST(cyc18r_phase_sr_out));



///////////////////////////////////////////////////////////
//////  Rhythm phase generator/phase selector
////

/*
    CH7 M = BD0
    CH7 C = BD1
    CH8 M = HH
    CH8 C = SD
    CH9 M = TT
    CH9 C = TC

    HH phase arrives at the SR final stage at cycle 17
    SD phase arrives at the SR final stage at cycle 20
    TC phase arrives at the SR final stage at cycle 21
*/

//rhythm phase enables
wire            hh_phase_en = i_CYCLE_17 & i_RHYTHM_EN;
wire            sd_phase_en = i_CYCLE_20 & i_RHYTHM_EN;
wire            tc_phase_en = i_CYCLE_21 & i_RHYTHM_EN;

//phase latch
reg     [3:0]   hh_phase_z;
reg     [1:0]   tc_phase_z;
always @(posedge emuclk) if(!phi1pcen_n) begin
    if(i_CYCLE_17)  hh_phase_z <= {cyc18r_phase_sr_out[17:16], cyc18r_phase_sr_out[12:11]};
    if(tc_phase_en) tc_phase_z <= {cyc18r_phase_sr_out[14], cyc18r_phase_sr_out[12]};
end

//make alias signals
wire            hh_phase_z_d17 = hh_phase_z[3];
wire            hh_phase_z_d16 = hh_phase_z[2];
wire            hh_phase_z_d12 = hh_phase_z[1];
wire            hh_phase_z_d11 = hh_phase_z[0];
wire            tc_phase_z_d14 = tc_phase_z[1];
wire            tc_phase_z_d12 = tc_phase_z[0];

//what the fuck??
wire            scramble_phase = |{(hh_phase_z_d16 ^ hh_phase_z_d11),
                                   (hh_phase_z_d12 ^ tc_phase_z_d14),
                                   (tc_phase_z_d14 ^ tc_phase_z_d12)};

//declare the LFSR noise output port first...
wire            noise_out;
wire            noise_inv = noise_out ^ scramble_phase;

//generate rhythm phase
reg     [9:0]   rhythm_phase;
always @(*) begin
    case({hh_phase_en, sd_phase_en, tc_phase_en})
        3'b100:  rhythm_phase = {scramble_phase, 1'b0, {2{noise_inv}}, ~noise_inv, 1'b1, 1'b0, ~noise_inv, 2'b00}; //1'b1 <- optimized
        3'b010:  rhythm_phase = {hh_phase_z_d17, noise_out ^ hh_phase_z_d17, 8'b0000_0000}; //negative input XNOR -> XNOR
        3'b001:  rhythm_phase = {scramble_phase, 1'b1, 8'b0000_0000};
        default: rhythm_phase = 10'b00_0000_0000;
    endcase
end

wire            pgmem_out_en = ~((i_CYCLE_17 | i_CYCLE_20 | i_CYCLE_21) & i_RHYTHM_EN);
assign  o_OP_PHASE = rhythm_phase | (cyc18r_phase_sr_out[19:10] & {10{pgmem_out_en}});



///////////////////////////////////////////////////////////
//////  LFSR
////

reg     [22:0]  noise_lfsr;
wire            noise_lfsr_zero = noise_lfsr == 23'd0;
assign  noise_out = noise_lfsr[22];

always @(posedge emuclk) begin
    if(!i_IC_n) noise_lfsr <= 23'd0; //parallel reset added: the original design doesnt't have this
    else begin if(!phi1ncen_n) begin
        noise_lfsr[0] <= (noise_lfsr[22] ^ noise_lfsr[8]) | noise_lfsr_zero | i_TEST[1];
        noise_lfsr[22:1] <= noise_lfsr[21:0];
    end end
end

endmodule