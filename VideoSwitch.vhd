library ieee, work; use ieee.std_logic_1164.all; use ieee.numeric_std.all;   
use work.LCDpackage.all;
entity VideoSwitch is
port
( addr : in std_logic := '0';
RGB1, RGB2 : in RGB_t;
RGBColor : out RGB_t);

end entity;
architecture rlt of VideoSwitch is
begin
process(addr,RGB1,RGB2)

begin
	
	if addr = '0' then RGBColor <= RGB1;
	else RGBColor <= RGB2;
	--RGBColor <= RGB1 when addr = '0' else RGB2;
	end if;
end process;
end architecture;


