library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library python_bridge;
context python_bridge.python_context;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- The CPU, mocked: the firmware, built for the PC by cpu_mock.py, runs in Python and each of its
-- register accesses becomes a transaction of the bus master bus_handle.
entity cpu_mock is
  generic(
    bus_handle : bus_master_t;
    firmware_dir : string;
    build_dir : string;
    -- Where cpu_mock.py is
    python_dir : string
  );
  port(
    -- The firmware starts once start is true: natively, or as an RV32 binary in Unicorn
    start : in boolean := true;
    rv32 : in boolean := false;
    -- The firmware has returned
    done : out boolean := false
  );
end entity;

architecture a of cpu_mock is
  -- == cpu_mock.py
  constant op_read : integer := 1;
  constant op_write : integer := 2;
begin
  main : process
    variable request : integer_vector(0 to 2);
    variable value : integer := 0;
    variable data : std_logic_vector(31 downto 0);
  begin
    if not start then
      wait until start;
    end if;
    import_module_from_file(join(python_dir, "cpu_mock.py"), "cpu_mock");
    if rv32 then
      exec("cpu = " & to_call_str("cpu_mock.CpuMock", arg(firmware_dir), arg(build_dir), arg("rv32")));
    else
      exec("cpu = " & to_call_str("cpu_mock.CpuMock", arg(firmware_dir), arg(build_dir), arg("native")));
    end if;
    loop
      request := call_integer_vector("cpu.step", arg(value));
      case request(0) is
        when op_read =>
          read_bus(net, bus_handle, std_logic_vector(to_signed(request(1), 32)), data);
          value := to_integer(signed(data));
        when op_write =>
          write_bus(net, bus_handle, std_logic_vector(to_signed(request(1), 32)),
                    std_logic_vector(to_signed(request(2), 32)));
          value := 0;
        when others =>
          exit;
      end case;
    end loop;
    done <= true;
    wait;
  end process;
end architecture;
