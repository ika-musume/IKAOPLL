module IKAOPLL_eg (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock
    input   wire            i_phiM_PCEN_n,

    //master reset
    input   wire            i_IC_n,

    //internal clock
    input   wire            i_phi1_PCEN_n, //positive edge clock enable for emulation
    input   wire            i_phi1_NCEN_n, //negative edge clock enable for emulation

    //timings
    input   wire            i_CYCLE_00, i_CYCLE_21, i_MnC_SEL, i_HH_TT_SEL,

    //parameter input
    input   wire    [8:0]   i_FNUM,
    input   wire    [2:0]   i_BLOCK,
    input   wire            i_KON,
    input   wire            i_SUSEN,
    input   wire            i_ETYP,
    input   wire            i_AR, i_DR, i_RR, i_SL,
    input   wire    [3:0]   i_TEST,

    //control input
    input   wire            i_EG_ENVCNTR_TEST_DATA,

    //control output
    output  wire            o_PG_RST_PHASE
);


///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            emuclk = i_EMUCLK;
wire            phiMpcen_n = i_phiM_PCEN_n;
wire            phi1pcen_n = i_phi1_PCEN_n;
wire            phi1ncen_n = i_phi1_NCEN_n;



///////////////////////////////////////////////////////////
//////  EG prescaler
////

reg     [1:0]   eg_prescaler;
reg             eg_prescaler_d0_z;
wire            serial_val_latch = i_CYCLE_00 & eg_prescaler_d0_z;
always @(posedge emuclk) begin
    if(!i_IC_n) eg_prescaler <= 2'd0;
    else begin if(!phi1ncen_n) begin
        if(i_CYCLE_21) eg_prescaler <= eg_prescaler + 2'd1;
    end end

    eg_prescaler_d0_z <= eg_prescaler[0];
end



///////////////////////////////////////////////////////////
//////  Envelope counter
////

reg     [17:0]  envcntr_sr;
reg             envcntr_adder_co_z;
wire    [1:0]   envcntr_adder = ((envcntr_adder_co_z | i_CYCLE_00) & eg_prescaler == 2'd3) + envcntr_sr[0];
always @(posedge emuclk) if(!phi1ncen_n) begin
    envcntr_adder_co_z <= envcntr_adder[1]; //save carry

    envcntr_sr[17] <= envcntr_adder[0] & i_IC_n;
    envcntr_sr[16] <= i_TEST[3] ? i_EG_ENVCNTR_TEST_DATA : envcntr_sr[17];
    envcntr_sr[15:0] <= envcntr_sr[16:1]; 
end

reg     [1:0]   envcntr;
always @(posedge emuclk) if(!phi1pcen_n) if(serial_val_latch) envcntr <= envcntr_sr[1:0];



///////////////////////////////////////////////////////////
//////  Consecutive zero bit counter
////

reg             ic_z;
reg             det_one;
reg     [16:0]  zb_sr;
always @(posedge emuclk) if(!phi1ncen_n) begin
    ic_z <= ~i_IC_n;

    det_one <= ~(~(i_CYCLE_00 | ic_z) & (envcntr_sr[17] | ~det_one));

    zb_sr[16] <= det_one & envcntr_sr[17];
    zb_sr[15:0] <= zb_sr[16:1];
end

reg     [3:0]   conseczerobitcntr;
always @(posedge emuclk) if(!phi1pcen_n) if(serial_val_latch) begin
    conseczerobitcntr[3] <= zb_sr[7] | zb_sr[8] | zb_sr[9] | zb_sr[10] | zb_sr[11] | zb_sr[12];
    conseczerobitcntr[2] <= zb_sr[3] | zb_sr[4] | zb_sr[5] | zb_sr[6]  | zb_sr[11] | zb_sr[12];
    conseczerobitcntr[1] <= zb_sr[1] | zb_sr[2] | zb_sr[5] | zb_sr[6]  | zb_sr[9]  | zb_sr[10];
    conseczerobitcntr[0] <= zb_sr[0] | zb_sr[2] | zb_sr[4] | zb_sr[6]  | zb_sr[8]  | zb_sr[10] | zb_sr[12];
end



///////////////////////////////////////////////////////////
//////  Cycle 2-19: Envelope state machine
////

//envelope status sr
wire    [1:0]   cyc2c_next_envstat;
wire    [1:0]   cyc17r_envstat, cyc19r_envstat;
primitive_sr #(.WIDTH(2), .LENGTH(18), .TAP0(16)) u_cyc2r_cyc19r_envstatreg
(.i_EMUCLK(i_EMUCLK), .i_CEN_n(i_phi1_NCEN_n), .i_D(cyc2c_next_envstat), .o_Q_TAP0(cyc17r_envstat), .o_Q_LAST(cyc19r_envstat));

//attenuation level flags, declare here first
wire            cyc2c_decay_end, cyc2c_attnlv_min, cyc18c_attnlv_quite; //min = minimum(zero), quite = human perception of loudness(-???dB)

//delay something
reg             cyc18r_kon, cyc19r_kon;
reg             cyc18r_attnlv_quite, cyc19r_attnlv_quite;
always @(posedge emuclk) if(!phi1ncen_n) begin
    cyc18r_kon <= i_KON;
    cyc19r_kon <= cyc18r_kon;

    cyc18r_attnlv_quite <= cyc18c_attnlv_quite;
    cyc19r_attnlv_quite <= cyc18r_attnlv_quite;
end

//start attack flag
wire            cyc18c_start_attack = cyc17r_envstat == 2'd3 & cyc18c_attnlv_quite & i_KON;
reg             cyc18r_start_attack, cyc19r_start_attack;
always @(posedge emuclk) if(!phi1ncen_n) begin
    cyc18r_start_attack <= cyc18c_start_attack;
    cyc19r_start_attack <= cyc18r_start_attack;
end

//phase reset signal
reg     [14:0]  hh_tt_start_attack_dly; //delays rhythm "start attack" signal for HH(ch8m) and TT(ch9m)
assign  o_PG_RST_PHASE = i_HH_TT_SEL ? hh_tt_start_attack_dly[14] : cyc18r_start_attack;
always @(posedge emuclk) if(!phi1ncen_n) begin
    hh_tt_start_attack_dly[0] <= cyc18r_start_attack;
    hh_tt_start_attack_dly[14:1] <= hh_tt_start_attack_dly[13:0];
end

//masked envelope status
wire    [1:0]   envstat_masked = cyc17r_envstat & {2{~cyc18c_start_attack}};

//make envelope status state machine transition conditions
assign  cyc2c_next_envstat[1] = |{~i_IC_n,
                                  ~cyc19r_start_attack & ~cyc19r_kon,
                                  ~cyc19r_start_attack &  cyc19r_envstat == 2'd3,
                                  ~cyc19r_start_attack &  cyc19r_envstat == 2'd2,
                                  ~cyc19r_start_attack &  cyc19r_envstat == 2'd3 &  cyc2c_decay_end};

assign  cyc2c_next_envstat[0] = |{~i_IC_n,
                                  ~cyc19r_start_attack & ~cyc19r_kon,
                                  ~cyc19r_start_attack &  cyc19r_envstat == 2'd3,
                                  ~cyc19r_start_attack &  cyc19r_envstat == 2'd3 & ~cyc2c_decay_end,
                                  ~cyc19r_start_attack &  cyc19r_envstat == 2'd0 &  cyc2c_attnlv_min};



///////////////////////////////////////////////////////////
//////  Cycle 0: select a rate should be applied
////

//latch the values
reg     [3:0]   cyc0r_egparam_muxed;
reg     [3:0]   cyc0r_ksr_factor;
always @(posedge emuclk) if(!phi1ncen_n) begin
    case({( i_KON & cyc17r_envstat == 2'd3 & ~cyc18c_attnlv_quite), 
          (~i_KON & ~i_SUSEN & ~i_MnC_SEL & ~i_ETYP)})
        2'b10: cyc0r_egparam_muxed <= 4'd12; //DP rate, "damp" the previous envelope to start the new envelope
        2'b01: cyc0r_egparam_muxed <= 4'd7;  //KON off, attenuating envelope, carrier, no
        2'b00: begin
            case(envstat_masked)
                2'd0: cyc0r_egparam_muxed <= i_AR;
                2'd1: cyc0r_egparam_muxed <= i_DR;
                2'd2: cyc0r_egparam_muxed <= i_ETYP ? 4'd0 : i_RR;
                2'd3: cyc0r_egparam_muxed <= i_SUSEN ? 4'd5 : i_RR;
            endcase
        end
        2'b11: cyc0r_egparam_muxed <= 4'd15; //bus contention, will not happen
    endcase

    cyc0r_ksr_factor <= i_KSR ? {i_BLOCK[2:0], i_FNUM[8]} : {2'b00, i_BLOCK[2:1]};
end



///////////////////////////////////////////////////////////
//////  Cycle 1: scale egparam and latch some values
////

//combinational
wire    [4:0]   cyc1c_egparam_scaled = cyc0r_egparam_muxed + cyc0r_ksr_factor[3:2];
wire    [3:0]   cyc1c_egparam_saturated = cyc1c_egparam_scaled[4] ? 4'd15 : cyc1c_egparam_scaled[3:0]; //saturation

//register
reg     [1:0]   cyc1r_eg_prescaler;
reg     [3:0]   cyc1r_egparam_saturated;
reg     [3:0]   cyc1r_attenrate; //consecutive zero bit counter
reg             cyc1r_envdeltaweight_intensity;
reg     [1:0]   cyc1r_ksr_factor_lo;
reg             cyc1r_egparam_zero;
always @(posedge emuclk) if(!phi1ncen_n) begin
    cyc1r_eg_prescaler <= eg_prescaler;
    cyc1r_egparam_saturated <= cyc1c_egparam_saturated;
    cyc1r_attenrate <= conseczerobitcntr;
    cyc1r_envdeltaweight_intensity <= (cyc0r_ksr_factor[1]      & ~envcntr[0]) |
							          (cyc0r_ksr_factor[0]      &  envcntr == 2'd0) |
							          (cyc0r_ksr_factor == 2'd3 &  envcntr == 2'd1);
    cyc1r_ksr_factor_lo <= cyc0r_ksr_factor[1:0];
    cyc1r_egparam_zero <= cyc0r_egparam_muxed == 4'd0;
end



///////////////////////////////////////////////////////////
//////  Cycle 2: generate attn delta selector signals
////

wire    [3:0]   cyc2c_egparam_final = cyc1r_egparam_saturated + cyc1r_attenrate; //discard carry
wire            cyc2c_slow_atten = (cyc2c_egparam_final == 4'd12 & cyc1r_egparam_saturated < 4'd12 & ~cyc1r_egparam_zero) |
                                   (cyc2c_egparam_final == 4'd13 & cyc1r_egparam_saturated < 4'd12 & ~cyc1r_egparam_zero & cyc1r_ksr_factor_lo[1]) |
                                   (cyc2c_egparam_final == 4'd14 & cyc1r_egparam_saturated < 4'd12 & ~cyc1r_egparam_zero & cyc1r_ksr_factor_lo[0]);

//activate attenuation: decrease volume linearly
wire            cyc2c_attn_act = (~cyc19r_attnlv_quite & cyc19r_envstat[1]      & ~cyc19r_start_attack) |
                                  (~cyc19r_attnlv_quite & cyc19r_envstat == 2'd1 & ~cyc19r_start_attack & cyc2c_decay_end);

//select signals
wire    [3:0]   cyc2c_attndelta_sel;
assign  cyc2c_attndelta_sel[0] =  cyc2c_slow_atten | 
                                 (cyc1r_egparam_saturated == 4'd12 & ~cyc1r_envdeltaweight_intensity);

assign  cyc2c_attndelta_sel[1] = (cyc1r_egparam_saturated == 4'd12 &  cyc1r_envdeltaweight_intensity) |
                                 (cyc1r_egparam_saturated == 4'd13 & ~cyc1r_envdeltaweight_intensity);

assign  cyc2c_attndelta_sel[2] = (cyc1r_egparam_saturated == 4'd13 &                               cyc1r_envdeltaweight_intensity) |
                                 (cyc1r_egparam_saturated == 4'd14 &                              ~cyc1r_envdeltaweight_intensity) |
                                 (cyc1r_egparam_saturated == 4'd12 & cyc1r_eg_prescaler == 2'd3 & ~cyc1r_envdeltaweight_intensity & cyc2c_attn_act) |
                                 (cyc1r_egparam_saturated == 4'd12 & cyc1r_eg_prescaler[0]      &  cyc1r_envdeltaweight_intensity & cyc2c_attn_act) |
                                 (cyc1r_egparam_saturated == 4'd13 & cyc1r_eg_prescaler[0]      & ~cyc1r_envdeltaweight_intensity & cyc2c_attn_act) |
                                 (cyc2c_slow_atten                 & cyc1r_eg_prescaler == 2'd3                                   & cyc2c_attn_act);
                                 
assign  cyc2c_attndelta_sel[3] = (cyc1r_egparam_saturated == 4'd14 & ~cyc1r_envdeltaweight_intensity) |
                                  cyc1r_egparam_saturated == 4'd15;

//select attenuation delta(addend 0)
wire            cyc2c_dec_attnlv = cyc19r_envstat == 2'd0 & cyc19r_kon & cyc1r_egparam_saturated != 4'd15 & ~cyc2c_attnlv_min;
wire    [6:0]   cyc19r_attnlv;
reg     [6:0]   cyc2c_attndelta;
always @(*) begin
    case(cyc2c_attndelta_sel)
        4'b0001: cyc2c_attndelta = cyc2c_dec_attnlv ? {4'b1111, ~cyc19r_attnlv[6:4]} : 7'd0;
        4'b0010: cyc2c_attndelta = cyc2c_dec_attnlv ? {3'b111, ~cyc19r_attnlv[6:3]} : 7'd0;
        4'b0100: cyc2c_attndelta = cyc2c_dec_attnlv ? {2'b11, ~cyc19r_attnlv[6:3], cyc2c_attn_act ? 1'b1 : ~cyc19r_attnlv[2]} : 
                                                      {6'b000000,                  cyc2c_attn_act ? 1'b1 : 1'b0}
        4'b1000: cyc2c_attndelta = cyc2c_dec_attnlv ? {2'b1, ~cyc19r_attnlv[6:3],  cyc2c_attn_act ? 1'b1 : ~cyc19r_attnlv[2], ~cyc19r_attnlv[1]} : 
                                                      {5'b00000,                   cyc2c_attn_act ? 1'b1 : 1'b0,              1'b0}
        default: cyc2c_attndelta = 7'd0;
    endcase
end

//control previous attenuation value(addend 1)
wire            cyc2c_curr_attnlv_en = ~(cyc1r_egparam_saturated == 4'd15 & cyc19r_start_attack);
wire            cyc2c_curr_attnlv_force_max = (cyc19r_attnlv_quite & |{cyc19r_envstat} & ~cyc19r_start_attack) | ~i_IC_n;
wire    [6:0]   cyc2c_curr_attnlv = cyc2c_curr_attnlv_force_max ? 7'd127 :
                                                                  cyc2c_curr_attnlv_en ? cyc19r_attnlv : 7'd0;

//sum two addends
wire    [6:0]   cyc2c_next_attnlv = cyc2c_curr_attnlv + cyc2c_attndelta; //discard carry

//register part
reg     [6:0]   cyc2r_attnlv;
always @(posedge emuclk) if(!phi1ncen_n) cyc2r_attnlv <= cyc2c_next_attnlv;



///////////////////////////////////////////////////////////
//////  Cycle 3-19 shift register
////

//cycle 3 to 19
wire    [6:0]   cyc17r_attnlv, cyc18r_attnlv;
primitive_sr #(.WIDTH(7), .LENGTH(17), .TAP0(15), .TAP1(16)) u_cyc3r_cyc19r_attnlvreg
(.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(cyc2r_attnlv), .o_Q_TAP0(cyc17r_attnlv), .o_Q_TAP1(cyc18r_attnlv), , .o_Q_LAST(cyc19r_attnlv));

//cycle 18
assign  cyc18c_attnlv_quite = cyc17r_attnlv[6:2] == 5'd0;

//cycle 19
reg     [3:0]   cyc19r_sl;
always @(posedge emuclk) if(!phi1ncen_n) cyc19r_sl <= i_SL;

//cycle 2
assign  cyc2c_attnlv_min = cyc19r_attnlv == 7'd0;
assign  cyc2c_attnlv_max = cyc19r_attnlv == 7'd127;
assign  cyc2c_decay_end = cyc19r_attnlv[6:2] == cyc19r_sl;














endmodule