`timescale 1ns / 1ps
module tb_monim;

  //---------------------------------
  // Signals
  //---------------------------------

  logic clk;
  logic rst;

  logic [7:0] s_data, m_data;
  logic s_valid, s_ready, s_last, m_valid, m_ready, m_last;
  logic [31:0] p1sm, p2sm;

  //---------------------------------
  // Parametrs
  //---------------------------------

  parameter CLK_P = 10;
  parameter pat_w = 3;
  parameter pat_h = 3;

  parameter x_1 = 16'h0001;
  parameter y_1 = 16'h0001;

  parameter x_2 = 16'h0001;
  parameter y_2 = 16'h0001;

  //---------------------------------
  // Connect to module
  //---------------------------------

  monim_top #(pat_w, pat_h) monim (
      //  MAIN SYNC
      .clk_i(clk),
      .arst_i(rst),
      //  AXI4_lite_IN
      .s_axi_data_i(s_data),
      .s_axi_valid_i(s_valid),
      .s_axi_ready_o(s_ready),
      .s_axi_last_i(s_last),
      //  AXI4_lite_OUT
      .m_axi_data_o(m_data),
      .m_axi_valid_o(m_valid),
      .m_axi_ready_i(m_ready),
      .m_axi_last_o(m_last),
      //  CONNECT to monim-sm
      .data_p_sm_1_i(p1sm),
      .data_p_sm_2_i(p2sm)
  );

  //---------------------------------
  // Packet & MailBox
  //---------------------------------
  class packet;
    rand logic [7:0] tdata;
    logic            tready;
    logic            tvalid;
    logic            tlast;
  endclass

  class small_data_packet extends packet;
    constraint tdata_c {tdata inside {[0 : 255]};}
    ;
  endclass

  //---------------------------------
  // CFG
  //---------------------------------
  class axi4_cfg_base;

    int unsigned      master_pkt_amount   = pat_h * pat_w;
    rand int unsigned master_delay_min    = 0;
    rand int unsigned master_delay_max    = 10;
    rand int unsigned slave_delay_min     = 0;
    rand int unsigned slave_delay_max     = 10;
    int               test_timeout_cycles = 10000000;

    function void post_randomize();
      string str;
      str = {str, $sformatf("master_pkt_amount  : %0d\n", master_pkt_amount)};
      str = {str, $sformatf("master_delay_min   : %0d\n", master_delay_min)};
      str = {str, $sformatf("master_delay_max   : %0d\n", master_delay_max)};
      str = {str, $sformatf("slave_delay_min    : %0d\n", slave_delay_min)};
      str = {str, $sformatf("slave_delay_max    : %0d\n", slave_delay_max)};
      $display(str);
    endfunction

    constraint master_delay_c {
      master_delay_min inside {[0 : 40]};
      master_delay_max inside {[0 : 40]};
      master_delay_max >= master_delay_min;
    }
    ;

    constraint slave_delay_c {
      slave_delay_min inside {[0 : 40]};
      slave_delay_max inside {[0 : 40]};
      slave_delay_max >= slave_delay_min;
    }

  endclass
  //---------------------------------
  // Generation AXI4-Lite master
  //---------------------------------
  class axi4_master_gen_base;

    axi4_cfg_base cfg;

    mailbox #(packet) gen2drv;

    virtual task run();
      int cnt = 0;
      repeat (cfg.master_pkt_amount) begin
        gen_master(cnt, cfg.master_pkt_amount);
        cnt = cnt + 1;
      end
    endtask

    virtual task gen_master(int cnt, int mount);
      packet p;
      p = create_packet();
      if (!p.randomize()) begin
        $error("Can't randomize packet!");
        $finish();
      end
      if (cnt == mount - 1) p.tlast = 1;
      else p.tlast = 0;
      gen2drv.put(p);
    endtask

    virtual function packet create_packet();
      packet p;
      p = new();
      return p;
    endfunction

  endclass

  //---------------------------------
  // Monitor AXI4-Lite Master
  //---------------------------------
  class axi4_master_monitor_base;
    mailbox #(packet) mbm;

    virtual task run();
      forever begin
        wait (~rst);
        fork
          forever begin
            monitor_master();
          end
        join_none
        wait (rst);
        disable fork;
      end
    endtask

    virtual task monitor_master();
      packet p;
      @(posedge clk);
      if (s_valid & s_ready) begin
        p = new();
        p.tdata = s_data;
        p.tvalid = s_ready;
        p.tlast = s_last;
        p.tready = s_ready;
        mbm.put(p);
      end
    endtask
  endclass

  //---------------------------------
  // Driver AXI4-Lite Master
  //---------------------------------
  class axi4_master_driver_base;
    axi4_cfg_base cfg;
    mailbox #(packet) gen2drv;
    virtual task run();
      packet p;
      forever begin
        @(posedge clk);
        fork
          forever begin
            gen2drv.get(p);
            drive_master(p);
          end
        join_none
        wait (rst);
        disable fork;
        reset_master();
        wait (~rst);
      end
    endtask

    virtual task reset_master();
      s_valid <= 0;
      s_data  <= 0;
      s_last  <= 0;
    endtask

    virtual task drive_master(packet p);
      int delay;
      delay = $urandom_range(cfg.master_delay_min, cfg.master_delay_max);
      repeat (delay) @(posedge clk);
      s_valid <= 1;
      s_data  <= p.tdata;
      do begin
        @(posedge clk);
      end while (~m_ready);
      s_last <= p.tlast;
      @(posedge clk);
      s_valid <= 0;
      s_last  <= 0;
    endtask
  endclass

  //---------------------------------
  // Agent AXI4-Lite Master
  //---------------------------------
  class axi4_master_agent_base;

    axi4_master_gen_base     master_gen;
    axi4_master_monitor_base master_monitor;
    axi4_master_driver_base  master_driver;

    function new();
      master_gen     = new();
      master_monitor = new();
      master_driver  = new();
    endfunction

    virtual task run();
      fork
        master_gen.run();
        master_driver.run();
        master_monitor.run();
      join
    endtask

  endclass

  //---------------------------------
  // Monitor AXI4-Lite Slave
  //---------------------------------
  class axi4_slave_monitor_base;
    mailbox #(packet) mbs;

    virtual task run();
      forever begin
        wait (~rst);
        fork
          forever begin
            monitor_master();
          end
        join_none
        wait (rst);
        disable fork;
      end
    endtask

    virtual task monitor_master();
      packet p;
      @(posedge clk);
      if (m_ready) begin
        p = new();
        p.tdata = m_data;
        p.tlast = m_last;
        p.tready = m_ready;
        p.tvalid = m_valid;
        mbs.put(p);
      end
    endtask
  endclass

  //---------------------------------
  // Driver AXI4-Lite Slave
  //---------------------------------
  class axi4_slave_driver_base;
    axi4_cfg_base cfg;

    virtual task run();
      forever begin
        @(posedge clk);
        fork
          forever begin
            drive_slave();
          end
        join_none
        wait (rst);
        disable fork;
        reset_slave();
        wait (~rst);
      end
    endtask

    virtual task reset_slave();
      m_ready <= 0;
    endtask

    virtual task drive_slave();
      int delay;
      delay = $urandom_range(cfg.slave_delay_min, cfg.slave_delay_max);
      repeat (delay) @(posedge clk);
      m_ready <= 1;
      @(posedge clk);
      m_ready <= 0;
    endtask
  endclass

  //---------------------------------
  // Agent AXI4-Lite Slave
  //---------------------------------
  class axi4_slave_agent_base;

    axi4_slave_monitor_base slave_monitor;
    axi4_slave_driver_base  slave_driver;

    function new();
      slave_monitor = new();
      slave_driver  = new();
    endfunction

    virtual task run();
      fork
        slave_driver.run();
        slave_monitor.run();
      join
    endtask

  endclass

  //---------------------------------
  // Checker
  //---------------------------------
  class checker_base;
    bit done;
    int pixel_x, pixel_y;
    axi4_cfg_base cfg;
    mailbox #(packet) mbm;
    mailbox #(packet) mbs;

    virtual task run();
      do_check();
    endtask

    virtual task check(packet in, packet out);
      if ((pixel_x >= x_1) && (pixel_x <= x_2) && (pixel_y <= y_1) && (pixel_y >= y_2)) begin 
        if (out.tdata !== in.tdata) begin
          $error("%0t Invalid TDATA: Real: %0d, Expected: %0d = %0d", $time(), out.tdata, in.tdata,
                 in.tdata); 
        end
        if ((pixel_x == x_2) && (pixel_y == y_1) && ~out.tready) begin
          $error("%0t Invalid TLAST: Real: %1b, Expected: %1b", $time(), out.tlast, 1);
        end
      end else if (out.tdata !== 0) begin
        $error("%0t Invalid TDATA: Real: %0d, Expected: %0d = %0d", $time(), out.tdata, in.tdata,
               0);
      end

      if (pixel_x == pat_w - 1) begin  //  Swap string Z
        pixel_x <= 0;
        pixel_y <= (pixel_y == pat_h - 1) ? 0 : pixel_y + 1;
      end else begin
        pixel_x <= pixel_x + 1;
      end
      
      
    endtask

    virtual task do_check();
      int cnt;
      packet in_p, out_p;
      forever begin
        wait (~rst);
        fork
          forever begin
            mbm.get(in_p);
            mbs.get(out_p);
            check(in_p, out_p);
            cnt = cnt + out_p.tready;
            if (cnt == cfg.master_pkt_amount) begin
              break;
            end
          end
          begin
            wait (rst);
          end
        join_any
        disable fork;
        if (cnt == cfg.master_pkt_amount) begin
          done = 1;
          break;
        end
        while (mbm.try_get(in_p)) cnt = cnt + in_p.tready;
      end
    endtask

  endclass

  //---------------------------------
  // BASE
  //---------------------------------
  class env_base;

    axi4_master_agent_base master;
    axi4_slave_agent_base  slave;
    checker_base           check;

    function new();
      master = new();
      slave  = new();
      check  = new();
    endfunction

    virtual task run();
      fork
        master.run();
        slave.run();
        check.run();
      join
    endtask

  endclass

  //---------------------------------
  // Generation signal reset
  //---------------------------------
  task reset();
    rst <= 1;
    #(10 * CLK_P);
    rst <= 0;
  endtask

  //---------------------------------
  // Generation signal CLK
  //---------------------------------
  initial begin
    rst  <= 0;
    clk  <= 0;
    p1sm <= {x_1, y_1};
    p2sm <= {x_2, y_2};
    forever begin
      #(CLK_P / 2) clk <= ~clk;
    end
  end

  //---------------------------------
  // TEST
  //---------------------------------
  class test_base;

    axi4_cfg_base cfg;

    env_base env;

    mailbox #(packet) gen2drv;
    mailbox #(packet) mbm;
    mailbox #(packet) mbs;

    function new();

      cfg = new();
      env = new();
      gen2drv = new();
      mbm = new();
      mbs = new();

      if (!cfg.randomize()) begin
        $error("Can't randomize test configuration!");
        $finish();
      end
      env.master.master_gen.cfg        = cfg;
      env.master.master_driver.cfg     = cfg;
      env.slave.slave_driver.cfg       = cfg;
      env.check.cfg                    = cfg;

      env.master.master_gen.gen2drv    = gen2drv;
      env.master.master_driver.gen2drv = gen2drv;
      env.master.master_monitor.mbm    = mbm;
      env.slave.slave_monitor.mbs      = mbs;
      env.check.mbm                    = mbm;
      env.check.mbs                    = mbs;
    endfunction

    virtual task run();
      bit done;
      fork
        env.run();
        timeout();
      join_none
      wait (env.check.done);
      $display("Test was finished!");
      $finish();
    endtask

    task timeout();
      repeat (cfg.test_timeout_cycles) @(posedge clk);
      $error("Test timeout!");
      $finish();
    endtask

  endclass

  class test_cfg_long_master extends axi4_cfg_base;

    constraint bottleneck_c {
      master_delay_min > 15;
      master_delay_max > 15;
    }

  endclass

  class test_long_master extends test_base;

    function new();
      test_cfg_long_master cfg_long_master;
      super.new();
      cfg_long_master = new();
      if (!cfg_long_master.randomize()) begin
        $error("Can't randomize test configuration!");
        $finish();
      end
      env.master.master_gen.cfg    = cfg_long_master;
      env.master.master_driver.cfg = cfg_long_master;
      env.slave.slave_driver.cfg   = cfg_long_master;
      env.check.cfg                = cfg_long_master;
    endfunction

  endclass

  initial begin
    test_long_master test;
    test = new();
    fork
      reset();
      test.run();
    join_none
    //    repeat (10000) @(posedge clk);
    //    reset();
  end
endmodule
