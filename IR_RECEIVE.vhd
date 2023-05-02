--library ieee;
--use ieee.std_logic_1164.all;
--use ieee.numeric_std.all;

library ieee, work; use ieee.std_logic_1164.all; use ieee.numeric_std.all;  
--use work.LCDpackage.all;

entity IR_RECEIVE is
  port (
    iCLK         : in  std_logic;      -- clk 50MH z
    iRST_n       : in  std_logic;      -- reset
    iIRDA        : in  std_logic;      -- IR code input
    oDATA_READY  : out std_logic;      -- data ready
    oDATA        : out std_logic_vector -- decode data output
                  (31 downto 0)
  );
end IR_RECEIVE;

--  PARAMETER declarations

architecture rtl of IR_RECEIVE is
constant IDLE               : std_logic_vector(1 downto 0) := "00"; -- always high voltage level
constant GUIDANCE           : std_logic_vector(1 downto 0) := "01"; -- 9ms low voltage and 4.5 ms high voltage
constant DATAREAD           : std_logic_vector(1 downto 0) := "10"; -- 0.6ms low voltage start and with 0.52ms high voltage is 0, with 1.66ms high voltage is 1, 32-bit in sum
constant jedna: unsigned(5 downto 0) := "000001";
constant IDLE_HIGH_DUR      : integer := 262143; -- data_count 262143*0.02us = 5.24ms, threshold for DATAREAD -----> IDLE
constant GUIDE_LOW_DUR      : integer := 230000; -- idle_count 230000*0.02us = 4.60ms, threshold for IDLE -----> GUIDANCE
constant GUIDE_HIGH_DUR     : integer := 210000; -- state_count 210000*0.02us = 4.20ms, 4.5-4.2 = 0.3ms < BIT_AVAILABLE_DUR = 0.4ms, threshold for GUIDANCE -----> DATAREAD
constant DATA_HIGH_DUR      : integer := 41500;  -- data_count 41500 *0.02us = 0.83ms, sample time from the posedge of iIRDA
constant BIT_AVAILABLE_DUR  : integer := 20000;  -- data_count 20000 *0.02us = 0.4ms, the sample bit pointer, can inhibit the interference from iIRDA signal

-- WARNING unsigned or std_logic_vector?? Not sure
-- Signal Declarations
--signal oDATA            : std_logic_vector(31 downto 0); -- data output
signal idle_count       : unsigned(17 downto 0);         -- idle_count counter works under data_read state
signal idle_count_flag  : std_logic;                     -- idle_count conter flag
signal state_count      : unsigned(17 downto 0);         -- state_count counter works under guide state
signal state_count_flag : std_logic;                     -- state_count conter flag
signal data_count       : unsigned(17 downto 0);         -- data_count counter works under data_read state
signal data_count_flag  : std_logic;                     -- data_count conter flag
signal bitcount         : unsigned(5 downto 0);           -- sample bit pointer
signal state            : std_logic_vector(1 downto 0);           -- state reg
signal data             : std_logic_vector(31 downto 0);  -- data reg
signal data_buf         : std_logic_vector(31 downto 0);  -- data buf
signal data_ready       : std_logic;                     -- data ready flag


--oDATA_READY <= data_ready;

begin
oDATA_READY <= data_ready;

--idle counter works on iclk under IDLE state only
idle_count_process: process(iCLK, iRST_n)
begin
	if iRST_n = '0' then
		idle_count <= (others => '0'); -- asynchronous reset
	elsif rising_edge(iCLK) then
		if idle_count_flag = '1' then
			idle_count <= idle_count + 1; --increment the counter
		else
			idle_count <= (others => '0'); --reset to 0
		end if;
	end if;
end process idle_count_process;

--idle counter switch when iIRDA is low under IDLE state
idle_count_flag_process: process(iCLK, iRST_n)
begin
	if iRST_n = '0' then
		idle_count_flag <= '0';
	elsif rising_edge(iCLK) then
		if state = IDLE and (iIRDA = '0') then
			idle_count_flag <= '1';
		else
			idle_count_flag <= '0';
		end if;
	end if;
end process idle_count_flag_process;

     
--state counter works on iclk under GUIDE state only
process(iCLK, iRST_n)
begin
	if iRST_n = '0' then
		state_count <= (others => '0');
	elsif rising_edge(iCLK) then
		if (state_count_flag = '1') then
			state_count <= state_count + 1;
		else
			state_count <= (others => '0');
		end if;
	end if;
end process;

--state counter switch when iIRDA is high under GUIDE state
process(iCLK, iRST_n)
begin
	if iRST_n = '0' then
		state_count_flag <= '0';
	elsif rising_edge(iCLK) then
		if state = GUIDANCE and iIRDA = '1' then
			state_count_flag <= '1';
		else
			state_count_flag <= '0';
		end if;
	end if;
end process;

--data read decode counter based on iCLK
process(iCLK, iRST_n)
begin
	if iRST_n = '0' then
		 data_count <= (others => '0');
	elsif rising_edge(iCLK) then
		if data_count_flag = '1' then  -- the counter works when the flag is 1
			 data_count <= data_count + 1;
		else
			 data_count <= (others => '0');  -- the counter resets when the flag is 0
		end if;
	end if;
end process;

--data counter switch
process(iCLK, iRST_n)
begin
	if iRST_n = '0' then
		data_count_flag <= '0';
	elsif rising_edge(iCLK) then
		if (state = DATAREAD) and iIRDA = '1' then
			data_count_flag <= '1';
		else
			data_count_flag <= '0';
		end if;
	end if;
end process;


--data reg pointer counter  
process(iCLK, iRST_n)
begin
	if iRST_n = '0' then
		bitcount <= (others => '0');
	elsif rising_edge(iCLK) then
		if (state = DATAREAD) then
			if (data_count = 20000) then
				bitcount <= bitcount + 1; --add 1 when iIRDA posedge
			end if;
		else
			bitcount <= (others => '0');
		end if;
	end if;
end process;
 

--state change between IDLE,GUIDE,DATA_READ according to irda edge or counter
process(iCLK, iRST_n)
begin
	if iRST_n = '0' then
		state <= IDLE;
	elsif rising_edge(iCLK) then
		case state is
			when IDLE =>
				if (idle_count > GUIDE_LOW_DUR) then
					state <= GUIDANCE;
				end if;
			when GUIDANCE =>
				if (state_count > GUIDE_HIGH_DUR) then
					state <= DATAREAD;
				end if;
			when DATAREAD =>
				if ((data_count >= IDLE_HIGH_DUR) or (bitcount >= 33)) then
					state <= IDLE;
				end if;
			when others =>
				state <= IDLE;
		end case;
	end if;
end process;


--data decode base on the value of data_count
	process(iCLK, iRST_n)
	begin
		if iRST_n = '0' then
			data <= (others => '0');
		elsif rising_edge(iCLK) then
			 if (state = DATAREAD) then
					if (data_count >= DATA_HIGH_DUR) then  --2^15 = 32767*0.02us = 0.64us
					--data(bitcount-1 downto 0) <= data(bitcount-1 downto 0) & '1'; -- concatenate the bit 1 to the previous bits
					data(to_integer(bitcount)-1) <= '1'; -- concatenate the bit 1 to the previous bits
					end if;
			 else
					data <= (others => '0');
			 end if;
		end if;
	end process;
	
--set the data_ready flag
process(iCLK, iRST_n)
begin
	 if iRST_n = '0' then
		  data_ready <= '0';
    elsif rising_edge(iCLK) then
        if(bitcount = 32) then
                if(data(31 downto 24) = not data(23 downto 16)) then
                    data_buf <= data;
                    data_ready <= '1';
                else
                    data_ready <= '0';
                end if;
        else
            data_ready <= '0';
        end if;
    end if;
end process;


-- read data
process(iCLK, iRST_n)
begin
	if iRST_n = '0' then
		oDATA <= (others => '0');
	elsif rising_edge(iCLK) then
		if (data_ready = '1') then
			oDATA <= data_buf;  -- output
		end if;
	end if;
end process;

end rtl;