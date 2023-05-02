-------------------------------------------------------------
-- CTU-FFE Prague, Dept. of Control Eng. [Richard Susta]
-- Published under GNU General Public License
-------------------------------------------------------------

library ieee, work; use ieee.std_logic_1164.all; use ieee.numeric_std.all;  
use work.LCDpackage.all;

entity LCDlogic_Pepa is
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

architecture behavioral of LCDlogic_Pepa is
constant GOLDENROD  : RGB_t := HsvToRGB(30, 217, 217); -- HSV 45 degrees,85%,85%, ToRGB(X"DAA520");
constant DARKGREEN  : RGB_t := ToRGB(0, 100, 0); -- X"006400");
constant DIMGRAY  : RGB_t := X"696969";
 ---------------------------------------------------------------------------
constant ROMW       : integer  := 192; -- =128+8, we multiply to obtain ROM address  
constant ROMH       : integer  := 190; -- any number, we do not multiply by it
constant XIMG1      : integer  := 175;  -- positions of the 1st image in LCD picture
constant YIMG1      : integer  := 140;
constant XIMG2      : integer  := 370; -- symmetrical positions of 2nd image
constant YIMG2      : integer  := 140;

 
 -- signal address : std_logic_vector(13 downto 0); -- ROM memory address
signal address : std_logic_vector(15 downto 0);
signal q       : std_logic_vector(1 downto 0); -- data from ROM memory
constant ZERO_ADDRESS    : std_logic_vector(address'RANGE) := (others => '0');

     -- we placed the saw pattern in the function to obtain a well-arranged main code
   

    -- converting integers to ROM addresses
    function int2addr(x : integer) return std_logic_vector is
    begin
        if x<0 or x>=2**ZERO_ADDRESS'LENGTH then return ZERO_ADDRESS; -- overflow
 else return std_logic_vector(to_unsigned(x, ZERO_ADDRESS'LENGTH));
 end if;
    -- we reffered to ZERO_ADDRESS'LENGTH, i.e., to the known constant,
-- a reference to address signal leads to an impure function
    end function;
     -- check if n in < nmin, nmin+nlen-1 )
function inRange(n, nmin, nlen:integer) return boolean is
   begin
     return n>=nmin and n<nmin+nlen;
end function;

begin -- architecture ---------------------------------------------------------------

  instROM : entity work.romL10_Pepa port map( address, LCD_DCLK, q);

  -- The process-sensitive list defines only signals after their changes the outputs can change  
LSPimage :
process(xcolumn, yrow, LCD_DE, q)
variable rgb, rgbChess:RGB_t;
variable x,y    :integer range 0 to 1023;
variable imgID  : integer range 0 to 2;
 
begin -- process
  x := to_integer(xcolumn); y := to_integer(yrow);
  imgID:=0;
  if inRange(x, XIMG1, ROMW) and inRange(y, YIMG1, ROMH ) then
imgID:=1;
  end if;

  -- The 2nd image is rotated by 90 degrees, so we switched ROMH with ROMW in the condition.
  if inRange(x, XIMG2, ROMH) and inRange(y, YIMG2, ROMW ) then
imgID:=2;
  end if;
 
  -- if (xcolumn(3) xor yrow(3)) = '1' then  rgbChess := YELLOW; else rgbChess := GOLDENROD;
  -- end if;
  if LCD_DE = '0' then  rgb := BLACK;
  elsif x > 357 AND x < 380 AND y > 130 AND y < 330 then
rgb := BLACK;
  elsif y > 325 AND y < 340 AND x > 370 AND x < 560 then
rgb := BLACK;
  elsif imgID > 0  then -- the transparent background in our image is "11", yellow!!
      case q is
        when "01"   =>
      if imgID = 1 then  RGB := BLACK; else  RGB := BLACK;  end if;
        when "10"   =>
      if imgID = 1 then  RGB := GREEN; else  RGB := YELLOW;  end if;
 when "11"   =>
      if imgID = 1 then  RGB := GRAY; else  RGB := GRAY;  end if;
        when others => -- others is required, each bit is 9-value logic
  if imgID = 1 then  RGB := BLACK; else  RGB := BLACK;  end if;
      end case;
 
  elsif  4*y <= 3*x - 1140 then -- primka vysece z vrchu dolu
     --rgb := ToRGB(139, 64, 0);
 rgb := YELLOW;
  elsif  4*y >= -3*x + 3060 then -- primka vysece z dola nahoru
     --rgb := ToRGB(139, 64, 0);
 rgb := YELLOW;

  elsif (x-418)*(x-418) + 4*(y-240)*(y-240) < 1*316*316 AND 4*y > 3*x - 1140 AND 4*y < -3*x + 3060 then -- elipsa
 rgb := BLACK;

  --elsif  y <= 320 AND y >= 160 AND 5*y > - 6*x + 960*5 then -- y < 800-(3/8)*x
  --   rgb := ToRGB(139, 64, 0);
  --elsif  y < 320 AND y > 160 AND 5*y <  6*x - 480*5 then -- y < 800-(3/8)*x
  --   rgb := ToRGB(139, 64, 0);
  else
 rgb:= GREEN;

end if;


   ----------- we define the new ROM address
   case imgID is
       when 1 =>
            address<= int2addr((y - YIMG1) * ROMW + (x - XIMG1));
       when 2 =>
           -- we rotate images 90 degrees clockwise by matrix [0 1; -1 0]*[x y], i.e., x=-y, y=x
            --address<= int2addr((y - YIMG2+1) * ROMW - (x - XIMG2));
address <= int2addr((XIMG2 + ROMH - 1 -x)*ROMW + (y - YIMG2));
       when others =>
             address <= ZERO_ADDRESS;
      end case;

   -- Inside processes, we always prefere variables. Signal are only connections from/to outside.
  RGBcolor <= rgb;
end process;

end architecture;