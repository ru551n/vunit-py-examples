library vunit_lib;
context vunit_lib.vunit_context;

library python_bridge;
context python_bridge.python_context;

entity tb_gain is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_gain is
begin
  main : process
    variable expected : integer;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("call Python model") then
        exec_file("gain.py");
        expected := call("gain", arg(7), kwarg("factor", 3));
        check_equal(expected, 21);
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;
