-------------------------------------------------------------
-- CTU-FFE Prague, Dept. of Control Eng. [Richard Susta]
-- Published under GNU General Public License
-------------------------------------------------------------

library ieee, work; use ieee.std_logic_1164.all; use ieee.numeric_std.all;   
use work.LCDpackage.all;

entity LCDlogic_1 is
    port(
        xcolumn  : in  xy_t      := XY_ZERO; -- x-coordinate of pixel (column index)
        yrow     : in  xy_t      := XY_ZERO; -- y-coordinate of pixel (row index)
        XEND_N   : in  std_logic := '0'; -- '0' only when max xcolumn, otherwise '1' 
        YEND_N   : in  std_logic := '0'; -- '0' only when max yrow
        LCD_DE   : in  std_logic := '0'; -- DataEnable visible part of LCDr
        LCD_DCLK : in  std_logic := '0'; -- LCD data clock, 33 MHz, see note 2 below
        RGBcolor : out RGB_t             --  color data
    );
end;
-- Note1: The initializations of inputs are active only during simulations, otherwise, they are ignored.
-- Note2: LCDLogic entity also contains not used inputs. They were added to notice their presence.
-- Note3: Pixel coordinate xcolumn counts from 0 to 1023, but the visible part lies from 0 to 799,
--        and yrow runs from 0 to 511, but visible rows are only from 0 to 479.
-- Note3: XEND_N and YEND_N are '0' only when xcolumns=1023 or yrow=524, otherwise are '1'.
--        They denote the end of a line or a frame. Their rising edges begin a new row/frame. 

architecture behavioral of LCDlogic_1 is
constant GOLDENROD  : RGB_t := HsvToRGB(30, 217, 217); -- HSV 45 degrees,85%,85%, = ToRGB(X"DAA520"); 
constant DARKGREEN  : RGB_t := ToRGB(0, 100, 0); -- X"006400"); 

     -- we placed the saw pattern in the function to obtain a well-arranged main code
    function sawPattern(x,y:integer) return boolean is
    constant XMOD       : integer := 10; --saw pattern
    variable x10           : integer range 0 to 1024 / XMOD; -- here, the ranges are required
    variable xmod10        : integer range 0 to XMOD - 1;
    variable isSaw         : boolean;
    begin
         -- We approximate forbidden x/10 by the fraction, see our textbook page 85 
        x10    := (13108 * x) / (2 ** 17); -- x/10
        xmod10 := x - x10 * XMOD;
        -- here, we write the conditions for one triangle that will repeat due to modulo XMOD
        if y < XMOD then
            if (x10 mod 2 = 0) then     -- even/odd
                isSaw := y < xmod10;
            else
                isSaw := XMOD - y > xmod10;
            end if;
        else
            isSaw := FALSE;
        end if;
        return isSaw;
    end function; 

begin -- architecture ---------------------------------------------------------------

    -- The process-sensitive list defines only signals after their changes the outputs can change  
LSPimage : 
process(xcolumn, yrow, LCD_DE)
variable rgb, rgbChess:RGB_t;
variable x,y:integer range 0 to 1023;
begin -- process
  x := to_integer(xcolumn); y := to_integer(yrow); 
  if (xcolumn(3) xor yrow(3)) = '1' then  rgbChess := YELLOW; else rgbChess := GOLDENROD;
  end if; 
  if LCD_DE = '0' or sawPattern(x,y) or sawPattern(x,LCD_YSCREEN - y) then  rgb := BLACK;               
 elsif x**2 + (y - LCD_YSCREEN) ** 2 < 128 ** 2 then -- circle
      rgb:= rgbChess; 
  elsif 6 * y < 6 * LCD_YSCREEN - 5 * x then -- y < 800-(5/6)*x
      rgb := DARKGREEN;
 elsif 8 * y < 8 * LCD_YSCREEN - 3 * x then -- y < 800-(3/8)*x
      rgb := rgbChess;
  else rgb := NAVY;
  end if;
  RGBcolor <= rgb;
end process;


end architecture;
