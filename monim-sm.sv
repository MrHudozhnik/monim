module monim_sm(     
//  MAIN SYNC
  input                clk_i,
  input                arst_i,
//  DATA IN
  input         [31:0] data_p_sm_1_i,
  input         [31:0] data_p_sm_2_i,
//  CONNECT to monim_axil_mon
  output    reg [31:0] p_sm_1_o,
  output    reg [31:0] p_sm_2_o
);

always_ff @(posedge clk_i or posedge arst_i) begin // UNC
    if (arst_i) begin   // RESET
        p_sm_1_o <= 32'b0;
        p_sm_2_o <= 32'b0;
    end else begin  //  Transmitting coordinates and data
        p_sm_1_o <= data_p_sm_1_i;
        p_sm_2_o <= data_p_sm_2_i;
    end
end
endmodule