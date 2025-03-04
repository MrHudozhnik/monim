 module monim_axil_mon #(
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
  output     reg       s_axi_ready_o,
  input                s_axi_last_i,
  //  AXI4_lite_OUT
  output     reg [7:0] m_axi_data_o,
  output     reg       m_axi_valid_o,
  input                m_axi_ready_i,
  output     reg       m_axi_last_o,
  //  CONNECT to monim-sm
  input         [31:0] p_sm_1_i,
  input         [31:0] p_sm_2_i
);
  
//  COORDINATE BIG RECTENGE
reg  [15:0]  pixel_x;
reg  [15:0]  pixel_y ;
reg          s_axi_valid_if;

wire [15:0] x_1 = p_sm_1_i[31:16];
wire [15:0] y_1 = p_sm_1_i[15:00];

wire [15:0] x_2 = p_sm_2_i[31:16];
wire [15:0] y_2 = p_sm_2_i[15:00];

always_ff @(posedge clk_i or posedge arst_i) // UNC 
    begin
        if (arst_i) begin   //  RESET
            // regXYB
            pixel_x <= 'b0;
            pixel_y <= 'b0;
            // portOUT
            s_axi_ready_o <= m_axi_ready_i;
            m_axi_data_o  <= 'b0;
            m_axi_valid_o <= 'b0;
            m_axi_last_o  <= 'b0;
        end else begin
        if ((pixel_x >= x_1) && (pixel_x <= x_2) && (pixel_y <= y_1) && (pixel_y >= y_2)) begin  //  Smaall recange
                m_axi_data_o  <= (m_axi_valid_o)? s_axi_data_i: 0;   //Draw data
                
                s_axi_valid_if <= s_axi_valid_i;
                m_axi_valid_o <= (m_axi_ready_i || (!s_axi_valid_if && s_axi_valid_i))? ~m_axi_valid_o : m_axi_valid_o;
                m_axi_last_o  <= ((pixel_x == x_2)&&(pixel_y == y_1)&& m_axi_ready_i) ? 1 : 0;
        end else begin
                m_axi_data_o <= 8'b0;   //  None
                m_axi_valid_o <= 0;
                m_axi_last_o  <= 0;
        end
        if (s_axi_valid_i && s_axi_ready_o) begin   //Intf ready
            if (pixel_x == pat_w - 1) begin //  Swap string Z
                pixel_x <= 0;
                pixel_y <= (pixel_y == pat_h - 1) ? 0 : pixel_y + 1;
            end else begin
                pixel_x <= pixel_x + 1;
            end 
        end
        s_axi_ready_o <= m_axi_ready_i;
    end
end
  
endmodule