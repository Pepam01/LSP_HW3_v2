-------------------------------------------------------------
-- CTU-FFE Prague, Dept. of Control Eng. [Richard Susta]
-- Published under GNU General Public License
-------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.LCDpackage.all;


entity VeekMT2_LCDgenerator is 
port (
	CLOCK_50 : in std_logic:='0'; -- input clock signal 50 MHz 
	ACLRN : in std_logic:='0'; -- asynchronous clear negative, connected to KEY[0] 
	xcolumn  : out xy_t:=(others=>'0');	 -- order number of actual pixel-column, see note 1 below
	yrow     : out xy_t:=(others=>'0');   -- order number of actual pixel-row
   XEND_N   : out std_logic:='0';	-- '0' pulse at the end of x-column 
	YEND_N   : out std_logic:='0';   -- '0' pulse at the end of y-row
	LCD_DE   : out std_logic:='0';   -- DataEnable control signal of LCD controller
	LCD_DCLK : out std_logic:='0';   -- LCD pixel clock, 33 MHz, see note 2 below
	CLRN    : out std_logic:='0'    -- output of phase-locked loop, after start-up, it changes from 0 -> 1 and remains in 1
	
);
end entity VeekMT2_LCDgenerator;
-- Note1: xcolumn counts from 0 to 1023, visible columns from 0 to 799
--        yrow counts from 0 to 511, visible columns from 0 to 799
-- Note2: XEND_N and YEND_N go to 0 only for the last columns or rows. Their rising edges begin new rows/frames. 

architecture driver of VeekMT2_LCDgenerator is

component VeekMT2_LCDgenerator_PLL
	PORT
	(
		areset		: IN STD_LOGIC  := '0';
		inclk0		: IN STD_LOGIC  := '0';
		c0		: OUT STD_LOGIC ;
		c1		: OUT STD_LOGIC ;
		locked		: OUT STD_LOGIC 
	);
end component;


signal pllreset : std_logic;
signal CLK, CLKshift : std_logic; -- not used in this version, but reserved

constant LCD_XCOLUMN_MAX : unsigned(xcolumn'RANGE) := (others=>'1'); 
constant LCD_YROW_MAX : integer := 524;

begin

 pllreset<=not ACLRN; -- areset of PLL, it is set to 1, but ACLRN is active in 0.
 
 iLCDpll : VeekMT2_LCDgenerator_PLL 
    port map(areset => pllreset, inclk0 => CLOCK_50, c0=>CLK, c1=>CLKshift, locked=>CLRN);
	
	LCD_DCLK<=CLK;

	process(CLK)
		variable	horizontal : unsigned(xcolumn'RANGE):=(others=>'0');
		variable	vertical : unsigned(yrow'RANGE):=(others=>'0');
	begin
		-- the generate utilizes the same principle as processor pipelines.
		-- In first stage, it prepares the next coordinates
		if falling_edge(CLK) then 
			if horizontal>=LCD_XCOLUMN_MAX then
			    if vertical<LCD_YROW_MAX then vertical:=vertical+1; 
				 else vertical:=(others=>'0');
				 end if;
			end if; 
			horizontal:=horizontal+1; -- unsigned counter overflows
		end if;
		-- The second stage adds synchronization signals and outputs results
		if rising_edge(CLK) then 
			XEND_N<='1';YEND_N<='1';LCD_DE <= '1'; -- we initialize to default values
			-- and then, we override initializations.
			if horizontal>=LCD_XCOLUMN_MAX then XEND_N<='0'; end if;
			if vertical>=LCD_YROW_MAX then YEND_N<='0'; end if;
			if ((horizontal >= LCD_XSCREEN) or (vertical >= LCD_YSCREEN))
			    then LCD_DE <= '0'; -- data active - visible part of image
			end if;
			xcolumn <= horizontal;
			yrow<=vertical;
		end if;
		
	end process;

	
end architecture driver;
