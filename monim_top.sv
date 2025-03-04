module monim_top #(
//  PATTERN (W,H)
  parameter            pat_w = 800,
  parameter            pat_h = 600
)(
//  MAIN SYNC
  input                clk_i,
  input                arst_i,
//  AXI4_lite_IN
  input          [7:0] s_axi_data_i,
  input                s_axi_valid_i,
  output               s_axi_ready_o,
  input                s_axi_last_i,
//  AXI4_lite_OUT
  output         [7:0] m_axi_data_o,
  output               m_axi_valid_o,
  input                m_axi_ready_i,
  output               m_axi_last_o,
//  DATA
  input         [31:0] data_p_sm_1_i,
  input         [31:0] data_p_sm_2_i
);

logic           [31:0] data_1;
logic           [31:0] data_2;

monim_axil_mon #(pat_w,pat_h) axi_mon (
//  MAIN SYNC
.clk_i(clk_i),
.arst_i(arst_i),
//  AXI4_lite_IN
.s_axi_data_i(s_axi_data_i),
.s_axi_valid_i(s_axi_valid_i),
.s_axi_ready_o(s_axi_ready_o),
.s_axi_last_i(s_axi_last_i),
//  AXI4_lite_OUT
.m_axi_data_o(m_axi_data_o),
.m_axi_valid_o(m_axi_valid_o),
.m_axi_ready_i(m_axi_ready_i),
.m_axi_last_o(m_axi_last_o),
//  CONNECT to monim-sm
.p_sm_1_i(data_1),
.p_sm_2_i(data_2)
);

monim_sm data_sm(
//  MAIN SYNC
.clk_i(clk_i),
.arst_i(arst_i),
//  DATA IN
.data_p_sm_1_i(data_p_sm_1_i),
.data_p_sm_2_i(data_p_sm_2_i),
//  CONNECT to monim_axil_mon
.p_sm_1_o(data_1),
.p_sm_2_o(data_2)
);
endmodule