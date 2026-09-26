library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fir is
  port(
    clk : in std_ulogic;
    in_valid : in std_ulogic;
    in_data : in signed(7 downto 0);
    out_valid : out std_ulogic := '0';
    out_data : out signed(31 downto 0)
  );
end entity;

architecture rtl of fir is
  constant coeffs : integer_vector := (1, 3, 3, 1);

  type taps_t is array (coeffs'range) of signed(in_data'range);
  signal taps : taps_t := (others => (others => '0'));
begin
  process(clk)
    variable next_taps : taps_t;
    variable acc : signed(out_data'range);
  begin
    if rising_edge(clk) then
      out_valid <= in_valid;
      if in_valid = '1' then
        next_taps := in_data & taps(0 to taps'high - 1);
        acc := (others => '0');
        for i in coeffs'range loop
          acc := acc + next_taps(i) * coeffs(i);
        end loop;
        taps <= next_taps;
        out_data <= acc;
      end if;
    end if;
  end process;
end architecture;
