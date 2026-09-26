library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity saturating_add is
  port(
    a : in unsigned(7 downto 0);
    b : in unsigned(7 downto 0);
    sum : out unsigned(7 downto 0)
  );
end entity;

architecture rtl of saturating_add is
  signal full : unsigned(8 downto 0);
begin
  full <= resize(a, 9) + b;
  -- Bug: should be >= 256, so 256 wraps to 0 instead of saturating
  sum <= x"FF" when full > 256 else full(7 downto 0);
end architecture;
