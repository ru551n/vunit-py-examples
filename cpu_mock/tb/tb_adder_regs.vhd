library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library ieee;
use ieee.std_logic_1164.all;

-- The firmware in ../firmware runs on the CPU mock, natively or as an RV32 binary in Unicorn, and
-- accesses adder_regs through VUnit's AXI-Lite master.
entity tb_adder_regs is
  generic(runner_cfg : string);
end entity;

architecture tb of tb_adder_regs is
  constant bus_handle : bus_master_t := new_bus(data_length => 32, address_length => 32);

  signal clk : std_logic := '0';
  signal start, rv32, done : boolean := false;
  signal awvalid, awready, wvalid, wready, bvalid, bready : std_logic;
  signal arvalid, arready, rvalid, rready : std_logic;
  signal awaddr, araddr, wdata, rdata : std_logic_vector(31 downto 0);
  signal wstrb : std_logic_vector(3 downto 0);
begin
  clk <= not clk after 5 ns;

  main : process
  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      if run("Test native firmware") then
        rv32 <= false;
      elsif run("Test RV32 firmware on Unicorn") then
        rv32 <= true;
      end if;
      start <= true;
      wait until done;
    end loop;
    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 100 us);

  cpu : entity work.cpu_mock
    generic map(
      bus_handle => bus_handle,
      firmware_dir => join(tb_path(runner_cfg), "../firmware"),
      build_dir => join(output_path(runner_cfg), "firmware"),
      python_dir => tb_path(runner_cfg)
    )
    port map(
      start => start,
      rv32 => rv32,
      done => done
    );

  axi_lite_master_inst : entity vunit_lib.axi_lite_master
    generic map(
      bus_handle => bus_handle
    )
    port map(
      aclk => clk,
      arready => arready,
      arvalid => arvalid,
      araddr => araddr,
      rready => rready,
      rvalid => rvalid,
      rdata => rdata,
      rresp => "00",
      awready => awready,
      awvalid => awvalid,
      awaddr => awaddr,
      wready => wready,
      wvalid => wvalid,
      wdata => wdata,
      wstrb => wstrb,
      bvalid => bvalid,
      bready => bready
    );

  dut : entity work.adder_regs
    port map(
      clk => clk,
      awvalid => awvalid,
      awready => awready,
      awaddr => awaddr(7 downto 0),
      wvalid => wvalid,
      wready => wready,
      wdata => wdata,
      bvalid => bvalid,
      bready => bready,
      arvalid => arvalid,
      arready => arready,
      araddr => araddr(7 downto 0),
      rvalid => rvalid,
      rready => rready,
      rdata => rdata
    );
end architecture;
