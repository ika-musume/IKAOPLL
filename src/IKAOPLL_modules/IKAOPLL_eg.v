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
    input   wire            i_CYCLE_00, i_CYCLE_21, i_MnC_SEL,

    //parameter input
    input   wire            i_KON,
    input   wire            i_SUSEN,
    input   wire            i_ETYP,
    input   wire            i_AR, i_DR, i_RR,
    input   wire    [3:0]   i_TEST,

    //control input
    input   wire            i_EG_ENVCNTR_TEST_DATA
);


///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            emuclk = i_EMUCLK;
wire            phiMpcen_n = i_phiM_PCEN_n;
wire            phi1pcen_n = i_phi1_PCEN_n;
wire            phi1ncen_n = i_phi1_NCEN_n;



///////////////////////////////////////////////////////////
//////  EG parameter mux
////

wire    [1:0]   envstat_masked; //declare first
reg     [3:0]   egparam_muxed;
always @(*) begin
    case(envstat_masked)
        2'd0: egparam_muxed = i_AR;
        2'd1: egparam_muxed = i_DR;
        2'd2: egparam_muxed = i_ETYP ? 4'd0 : i_RR;
        2'd3: egparam_muxed = i_SUSEN ? 4'd5 : i_RR;
    endcase
end



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
    conseczerobitcntr[2] <= zb_sr[3] | zb_sr[4] | zb_sr[5] | zb_sr[6] | zb_sr[11] | zb_sr[12];
    conseczerobitcntr[1] <= zb_sr[1] | zb_sr[2] | zb_sr[5] | zb_sr[6] | zb_sr[9] | zb_sr[10];
    conseczerobitcntr[0] <= zb_sr[0] | zb_sr[2] | zb_sr[4] | zb_sr[6] | zb_sr[8] | zb_sr[10] | zb_sr[12];
end



endmodule