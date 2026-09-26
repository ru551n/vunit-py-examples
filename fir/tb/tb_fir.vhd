library vunit_lib;
context vunit_lib.vunit_context;

library python_bridge;
context python_bridge.python_context;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_fir is
  generic(runner_cfg : string);
end entity;

architecture tb of tb_fir is
  signal clk : std_ulogic := '0';
  signal in_valid, out_valid : std_ulogic := '0';
  signal in_data : signed(7 downto 0) := (others => '0');
  signal out_data : signed(31 downto 0);

  signal stimuli, expected : integer_array_t;
  signal start, done : boolean := false;
begin
  clk <= not clk after 5 ns;

  main : process
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test exec, eval and call") then
        exec("import math");
        check_equal(eval_integer("math.gcd(35, 77)"), 7);
        check_equal(real'(call("round", arg(3.14159), kwarg("ndigits", 2))), 3.14);

      elsif run("Test FIR against NumPy model") then
        -- Relative paths are relative to this testbench file
        import_module_from_file(join(tb_path(runner_cfg), "model.py"), "model");

        -- Python generates the stimuli and the expected output, both as integer_array_t
        stimuli <= call_integer_array("model.stimuli", arg(1000), arg_unsigned(get_seed(runner_cfg)));
        wait for 0 ns;
        expected <= call_integer_array("model.fir", arg(stimuli));
        start <= true;
        wait until done;
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

  drive : process
  begin
    wait until start;
    for i in 0 to length(stimuli) - 1 loop
      wait until rising_edge(clk);
      in_valid <= '1';
      in_data <= to_signed(get(stimuli, i), in_data'length);
    end loop;
    wait until rising_edge(clk);
    in_valid <= '0';
    wait;
  end process;

  check_output : process
    variable idx : natural := 0;
  begin
    wait until start;
    while idx < length(expected) loop
      wait until rising_edge(clk) and out_valid = '1';
      check_equal(out_data, get(expected, idx), "sample " & to_string(idx));
      idx := idx + 1;
    end loop;
    done <= true;
    wait;
  end process;

  dut : entity work.fir
    port map(
      clk => clk,
      in_valid => in_valid,
      in_data => in_data,
      out_valid => out_valid,
      out_data => out_data
    );
end architecture;
