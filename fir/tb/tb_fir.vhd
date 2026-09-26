library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library python_bridge;
context python_bridge.python_context;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_fir is
  generic(runner_cfg : string);
end entity;

architecture tb of tb_fir is
  constant master : axi_stream_master_t := new_axi_stream_master(data_length => 8);
  constant slave : axi_stream_slave_t := new_axi_stream_slave(data_length => 32);

  signal clk : std_logic := '0';
  signal in_valid, out_valid : std_logic;
  signal in_data : std_logic_vector(7 downto 0);
  signal out_data : std_logic_vector(31 downto 0);
begin
  clk <= not clk after 5 ns;

  main : process
    variable stimuli, expected : integer_array_t;
  begin
    test_runner_setup(runner, runner_cfg);

    import_module_from_file(join(tb_path(runner_cfg), "model.py"), "model");
    stimuli := call("model.stimuli", arg(1000), arg_unsigned(get_seed(runner_cfg)));
    expected := call("model.fir", arg(stimuli));

    for i in 0 to length(stimuli) - 1 loop
      push_axi_stream(net, master, std_logic_vector(to_signed(get(stimuli, i), 8)));
      check_axi_stream(net, slave, std_logic_vector(to_signed(get(expected, i), 32)), blocking => false);
    end loop;
    wait_until_idle(net, as_sync(master));
    wait_until_idle(net, as_sync(slave));

    test_runner_cleanup(runner);
  end process;

  axi_stream_master_inst : entity vunit_lib.axi_stream_master
    generic map(master => master)
    port map(aclk => clk, tvalid => in_valid, tdata => in_data);

  axi_stream_slave_inst : entity vunit_lib.axi_stream_slave
    generic map(slave => slave)
    port map(aclk => clk, tvalid => out_valid, tdata => out_data);

  dut : entity work.fir
    port map(
      clk => clk,
      in_valid => in_valid,
      in_data => signed(in_data),
      out_valid => out_valid,
      std_logic_vector(out_data) => out_data
    );
end architecture;
