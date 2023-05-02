library ieee, work; use ieee.std_logic_1164.all; use ieee.numeric_std.all;   
use work.LCDpackage.all;

entity VideoProcessor is
    port(
        xcolumn  : in  xy_t      := XY_ZERO; -- x-coordinate of pixel (column index)
        yrow     : in  xy_t      := XY_ZERO; -- y-coordinate of pixel (row index)
		  IR_ready : in  std_logic := '0';
		  IR_data  : in  std_logic_vector(31 downto 0);
        XEND_N   : in  std_logic := '0'; -- '0' only when max xcolumn, otherwise '1'
        YEND_N   : in  std_logic := '0'; -- '0' only when max yrow
        LCD_DCLK : in  std_logic := '0'; -- LCD data clock, 33 MHz, see note 2 below
        addr : out std_logic             --  color data
    );
end;

architecture rtl of VideoProcessor is
signal cmp : unsigned(9 downto 0) := (others => '0');

begin

	addr<= '0' when xcolumn < cmp+(yrow mod 64) else '1';

	process(YEND_N)
	variable cntr:unsigned(cmp'RANGE):=(others => '0');
	begin 
		if rising_edge(YEND_N) then cntr := cntr+4; end if;
		cmp<=cntr;
	end process;

end architecture;