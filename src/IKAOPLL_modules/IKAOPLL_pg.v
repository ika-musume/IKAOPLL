module IKAOPLL_pg #(parameter USE_PIPELINED_MULTIPLIER = 1) (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock
    input   wire            i_phiM_PCEN_n,

    //master reset
    input   wire            i_IC_n,

    //internal clock
    input   wire            i_phi1_PCEN_n, //positive edge clock enable for emulation
    input   wire            i_phi1_NCEN_n, //negative edge clock enable for emulation

    //parameters
    input   wire    [8:0]   i_FNUM,
    input   wire    [2:0]   i_BLOCK,
    input   wire            i_PM,
    input   wire    [2:0]   i_PMVAL,
    input   wire    [3:0]   i_MUL,

    //control
    input   wire            i_PG_PHASE_RST
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
always @(posedge emuclk) if(!phi1ncen_n) begin
    cyc0r_fnum <= i_FNUM;
    cyc0r_block <= i_BLOCK;
end



//declare cyc3r variable first
reg     [18:0]  cyc3r_phase_current;

generate
if(USE_PIPELINED_MULTIPLIER == 1) begin : USE_PIPELINED_MULTIPLIER_1

///////////////////////////////////////////////////////////
//////  Cycle 1: Add PMVAL and shift
////

//make phase modulation value using high bits of the FNUM
wire            cyc1c_pmamt_sign = i_PM[2] & i_PM;
reg     [2:0]   cyc1c_pmamt_val;
always @(*) begin
    case(i_PMVAL[1:0] & {2{i_PM}})
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

//previous phase
wire    [18:0]  cyc1c_phase_prev;

//register part
reg     [3:0]   cyc1r_mul;
reg     [16:0]  cyc1r_phase_shifted;
reg     [18:0]  cyc1r_phase_prev;
always @(posedge emuclk) if(!phi1ncen_n) begin
    cyc1r_mul <= i_MUL;
    cyc1r_phase_shifted <= cyc1c_blockshifter1;

    cyc1r_phase_prev <= ~(~i_PG_PHASE_RST | i_TEST[2]) ? cyc1c_phase_prev : 19'd0;
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
wire            cyc1c_pmamt_sign = i_PM[2] & i_PM;
reg     [2:0]   cyc1c_pmamt_val;
always @(*) begin
    case(i_PMVAL[1:0] & {2{i_PM}})
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
reg     [20:0]  cyc1c_phase_multiplied = cyc1c_blockshifter1 * i_MUL;

//previous phase
wire    [18:0]  cyc1c_phase_prev;

//register part
reg     [18:0]  cyc1r_phase_multiplied;
reg     [18:0]  cyc1r_phase_prev;
always @(posedge emuclk) if(!phi1ncen_n) begin
    cyc1r_phase_multiplied <= cyc1c_phase_multiplied[18:0];
    cyc1r_phase_prev <= ~(~i_PG_PHASE_RST | i_TEST[2]) ? cyc1c_phase_prev : 19'd0;
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
//////  Cycle 4-19: delay shift register
////

wire    [18:0]  cyc19r_phase_sr_out;
IKAOPLL_sr #(.WIDTH(19), .LENGTH(16)) u_cyc4r_cyc19r_phase_sr
(.i_EMUCLK(emuclk), .i_CEN_n(phi1ncen_n), .i_D(cyc3r_phase_current), .o_Q_LAST(cyc19r_phase_sr_out));






endmodule