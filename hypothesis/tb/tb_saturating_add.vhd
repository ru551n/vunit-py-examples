library vunit_lib;
context vunit_lib.vunit_context;

library python_bridge;
context python_bridge.python_context;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_saturating_add is
  generic(runner_cfg : string);
end entity;

architecture tb of tb_saturating_add is
  signal a, b, sum : unsigned(7 downto 0);
begin
  main : process
  begin
    test_runner_setup(runner, runner_cfg);

    import_module_from_file(join(tb_path(runner_cfg), "property.py"), "property");
    while call("property.next_example") loop
      a <= to_unsigned(eval("property.example[0]"), a'length);
      b <= to_unsigned(eval("property.example[1]"), b'length);
      wait for 1 ns;
      call("property.results.put", arg(to_integer(sum)));
    end loop;
    call("property.finish");

    test_runner_cleanup(runner);
  end process;

  dut : entity work.saturating_add
    port map(
      a => a,
      b => b,
      sum => sum
    );
end architecture;
