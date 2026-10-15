library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Three AXI-Lite registers: A (0x0) and B (0x4) are written by the CPU, SUM (0x8) reads A + B.
-- Write strobes are ignored.
entity adder_regs is
  port(
    clk : in std_ulogic;

    awvalid : in std_ulogic;
    awready : out std_ulogic;
    awaddr : in std_ulogic_vector(7 downto 0);
    wvalid : in std_ulogic;
    wready : out std_ulogic;
    wdata : in std_ulogic_vector(31 downto 0);
    bvalid : out std_ulogic;
    bready : in std_ulogic;

    arvalid : in std_ulogic;
    arready : out std_ulogic;
    araddr : in std_ulogic_vector(7 downto 0);
    rvalid : out std_ulogic;
    rready : in std_ulogic;
    rdata : out std_ulogic_vector(31 downto 0)
  );
end entity;

architecture rtl of adder_regs is
  signal a, b : unsigned(31 downto 0) := (others => '0');
  signal write_en, bvalid_i, rvalid_i : std_ulogic := '0';
begin
  -- A write is taken when its address and data are both there
  write_en <= awvalid and wvalid and not bvalid_i;
  awready <= write_en;
  wready <= write_en;
  bvalid <= bvalid_i;
  arready <= not rvalid_i;
  rvalid <= rvalid_i;

  process(clk)
  begin
    if rising_edge(clk) then
      if write_en = '1' then
        case awaddr(3 downto 2) is
          when "00" => a <= unsigned(wdata);
          when "01" => b <= unsigned(wdata);
          when others => null;
        end case;
        bvalid_i <= '1';
      elsif bready = '1' then
        bvalid_i <= '0';
      end if;

      if arvalid = '1' and rvalid_i = '0' then
        case araddr(3 downto 2) is
          when "00" => rdata <= std_ulogic_vector(a);
          when "01" => rdata <= std_ulogic_vector(b);
          when "10" => rdata <= std_ulogic_vector(a + b);
          when others => rdata <= (others => '0');
        end case;
        rvalid_i <= '1';
      elsif rready = '1' then
        rvalid_i <= '0';
      end if;
    end if;
  end process;
end architecture;
