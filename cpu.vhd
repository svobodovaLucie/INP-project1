-- cpu.vhd: Simple 8-bit CPU (BrainLove interpreter)
-- Copyright (C) 2021 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): xsvobo1x
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet ROM
   CODE_ADDR : out std_logic_vector(11 downto 0); -- adresa do pameti
   CODE_DATA : in std_logic_vector(7 downto 0);   -- CODE_DATA <- rom[CODE_ADDR] pokud CODE_EN='1'
   CODE_EN   : out std_logic;                     -- povoleni cinnosti
   
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(9 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- ram[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_WREN  : out std_logic;                    -- cteni z pameti (DATA_WREN='0') / zapis do pameti (DATA_WREN='1')
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA obsahuje stisknuty znak klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna pokud IN_VLD='1'
   IN_REQ    : out std_logic;                     -- pozadavek na vstup dat z klavesnice
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- pokud OUT_BUSY='1', LCD je zaneprazdnen, nelze zapisovat,  OUT_WREN musi byt '0'
   OUT_WREN : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is
	-- PC
	signal pc_inc			: std_logic;
	signal pc_dec			: std_logic;
	signal pc_code_addr		: std_logic_vector (11 downto 0);
	signal pc_clear			: std_logic;

	-- CNT
	signal cnt_num			: std_logic_vector (7 downto 0);
	signal cnt_inc			: std_logic;
	signal cnt_dec			: std_logic;
	
	-- PTR
	signal ptr_inc			: std_logic;
	signal ptr_dec			: std_logic;
	signal ptr_data_addr		: std_logic_vector (9 downto 0);
	signal ptr_clear		: std_logic;
 
   -- MUX
	signal mux_sel			: std_logic_vector (1 downto 0) := (others => '0');
	signal mux_out			: std_logic_vector (7 downto 0) := (others => '0');
		
	-- DC
	type ins is (
		I_PTR_INC,
 		I_PTR_DEC,
		I_DATA_INC,
		I_DATA_DEC,
		I_PRINT,
		I_LOAD,
		I_WHILE_BEG,
		I_WHILE_END,
		I_BREAK,
		I_RETURN,
		I_OTHERS
	);
	signal dc_ins : ins := I_OTHERS;
	
	-- FSM
	type state_t is (	
		S_IDLE,
		S_FETCH,
		S_DECODE,
		S_PTR_INC,
 		S_PTR_DEC,
		S_DATA_INC,
		S_DATA_INC1,
		S_DATA_INC2,
		S_DATA_DEC,
		S_DATA_DEC1,
		S_DATA_DEC2,	
		S_PRINT,
		S_PRINT1,
		S_PRINT2,
		S_LOAD,
		S_LOAD1,
		S_WHILE_BEG,
		S_WHILE_BEG1,
		S_WHILE_BEG2,
		S_WHILE_BEG3,
		S_WHILE_END,
		S_WHILE_END1,
		S_WHILE_END2,
		S_WHILE_END3,
		S_WHILE_END4,
		S_BREAK,
		S_BREAK1,
		S_BREAK2,
		S_RETURN,
		s_OTHERS, 	
		S_CMD_NULL
	);
	signal pstate : state_t := S_IDLE;
	signal nstate : state_t;

begin
	-- PC ------------------------------------------------------------------
	pc: process (CLK, RESET, pc_inc, pc_dec, pc_clear)
	begin 
		if (RESET = '1') then
			pc_code_addr <= (others => '0');
		elsif (CLK'event) and (CLK = '1') then
			if (pc_inc = '1') then
				pc_code_addr <= pc_code_addr + 1;
			elsif (pc_dec = '1') then
				pc_code_addr <= pc_code_addr - 1;
			elsif (pc_clear = '1') then
				pc_code_addr <= (others => '0');
			end if;
		end if;
	end process;
	CODE_ADDR <= pc_code_addr;
	-------------------------------------------------------------------------
	
	-- DC -------------------------------------------------------------------
	dc: process (CLK, RESET, CODE_DATA)
	begin
		case CODE_DATA is
			when X"3E" 	=>	dc_ins <= I_PTR_INC;
			when X"3C" 	=>	dc_ins <= I_PTR_DEC;							
			when X"2B" 	=>	dc_ins <= I_DATA_INC;
			when X"2D" 	=>	dc_ins <= I_DATA_DEC;	
			when X"5B" 	=>	dc_ins <= I_WHILE_BEG;
			when X"5D" 	=>	dc_ins <= I_WHILE_END;
			when X"2E" 	=>	dc_ins <= I_PRINT;
			when X"2C" 	=>	dc_ins <= I_LOAD;
			when X"7E" 	=>	dc_ins <= I_BREAK;
			when X"00" 	=>	dc_ins <= I_RETURN;
			when others	=>	dc_ins <= I_OTHERS;
		end case;
	end process;
	-------------------------------------------------------------------------
	
	-- CNT ------------------------------------------------------------------
	cnt: process (CLK, RESET, cnt_inc, cnt_dec)
	begin
		if (RESET = '1') then
			cnt_num <= (others => '0');
		elsif (CLK'event) and (CLK = '1') then
			if (cnt_inc = '1') then
				cnt_num <= cnt_num + 1;
			elsif (cnt_dec = '1') then
				cnt_num <= cnt_num - 1;
			end if;
		end if;
	end process;
	-------------------------------------------------------------------------
	
	-- PTR ------------------------------------------------------------------
	ptr: process (CLK, RESET, ptr_inc, ptr_dec, ptr_clear)
	begin 	
		if (RESET = '1') then
			ptr_data_addr <= (others => '0');
		elsif (CLK'event) and (CLK = '1') then
			if (ptr_inc = '1') then
				ptr_data_addr <= ptr_data_addr + 1;
			elsif (ptr_dec = '1') then
				ptr_data_addr <= ptr_data_addr - 1;
			elsif (ptr_clear = '1') then
				ptr_data_addr <= (others => '0');
			end if;
		end if;
	end process;
	DATA_ADDR <= ptr_data_addr;
	-------------------------------------------------------------------------
	
	-- MUX ------------------------------------------------------------------
	mux: process (CLK, RESET, mux_sel)
	begin
		if (RESET = '1') then
			mux_out <= (others => '0');
		elsif (CLK'event) and (CLK = '1') then
			case mux_sel is
				when "00" 	=>	mux_out <= IN_DATA;
				when "01" 	=>	mux_out <= DATA_RDATA + 1;
				when "10" 	=>	mux_out <= DATA_RDATA - 1;
				when "11" 	=>	mux_out <= DATA_RDATA;
				when others =>	null;
			end case;
		end if;
	end process;
	DATA_WDATA <= mux_out;
	-------------------------------------------------------------------------
	
	-- FSM ------------------------------------------------------------------
	-- present state logic
	pstate_logic: process (CLK, RESET, EN)
	begin
		if (RESET = '1') then 
			pstate <= S_IDLE;
		elsif (CLK'event) and (CLK = '1') then
			if (EN = '1') then 
				pstate <= nstate;
			end if;
		end if;
	end process;
	
	-- next state logic
	nstate_logic: process (pstate, OUT_BUSY, IN_VLD, dc_ins, DATA_RDATA) is
	begin
		-- inicializace 
		pc_inc		<= '0';
		pc_dec		<= '0';
		pc_clear	<= '0';
		ptr_inc		<= '0';
		ptr_dec		<= '0';
		ptr_clear	<= '0';
		cnt_inc 	<= '0';
		cnt_dec		<= '0';
		mux_sel		<= "00";

		CODE_EN		<= '0';
		DATA_EN		<= '0';
		DATA_WREN	<= '0';
		OUT_WREN	<= '0';
		IN_REQ		<= '0';

		case pstate is
			when S_IDLE =>	ptr_clear <= '1';
					pc_clear  <= '1';
					nstate 	 <= S_FETCH;	
			
			when S_FETCH =>	CODE_EN <= '1';
					nstate <= S_DECODE;	
			
			when S_DECODE =>	case dc_ins is
							when I_PTR_INC		=> nstate 	<= S_PTR_INC;
							when I_PTR_DEC 		=> nstate	<= S_PTR_DEC;							
							when I_DATA_INC 	=> nstate	<= S_DATA_INC;
							when I_DATA_DEC		=> nstate	<= S_DATA_DEC;
							when I_WHILE_BEG	=> nstate	<= S_WHILE_BEG;
							when I_WHILE_END	=> nstate	<= S_WHILE_END;
							when I_PRINT		=> nstate	<= S_PRINT;
							when I_LOAD		=> nstate	<= S_LOAD;
							when I_BREAK 		=> nstate	<= S_BREAK;
							when I_RETURN		=> nstate	<= S_RETURN;
							when I_OTHERS		=> nstate	<= S_OTHERS;
							when others		=> nstate	<= S_OTHERS;
						end case;
			
			when S_PTR_INC =>	pc_inc	<= '1';
						ptr_inc	<= '1';
						nstate	<= S_FETCH;
					
			when S_PTR_DEC =>	pc_inc	<= '1';
						ptr_dec	<= '1';
						nstate <= S_FETCH;
			
			when S_DATA_INC => 	DATA_EN		<= '1';
						DATA_WREN	<= '0';
						nstate		<= S_DATA_INC1;
			when S_DATA_INC1 =>	mux_sel   	<= "01";
						nstate  	<= S_DATA_INC2;
			when S_DATA_INC2 =>	DATA_EN		<= '1';
						DATA_WREN	<= '1';
						pc_inc		<= '1';
						nstate  	<= S_FETCH;
						
			when S_DATA_DEC =>	DATA_EN 	<= '1';
						DATA_WREN	<= '0';
						nstate 		<= S_DATA_DEC1;
			when S_DATA_DEC1 =>	mux_sel   	<= "10";
						nstate 		<= S_DATA_DEC2;
			when S_DATA_DEC2 =>	DATA_EN 	<= '1';
						DATA_WREN 	<= '1';
						pc_inc 		<= '1';
						nstate 		<= S_FETCH;
			
			when S_PRINT =>	DATA_EN 	<= '1';
					DATA_WREN 	<= '0';
					nstate		<= S_PRINT1;
			when S_PRINT1 =>	if (OUT_BUSY = '1') then
							nstate 	<= S_PRINT;
						else
							OUT_DATA <= DATA_RDATA;
							OUT_WREN <= '1';
							pc_inc 	<= '1';
							nstate 	<= S_FETCH;
						end if;
									
			when S_LOAD =>	IN_REQ 	<= '1';
					mux_sel	<= "00";
					nstate	<= S_LOAD1;
			when S_LOAD1 =>	if (IN_VLD = '0') then
						DATA_EN		<= '1';
						DATA_WREN	<= '1';
						pc_inc		<= '1';
						nstate 		<= S_FETCH;
					else
						nstate		<= S_LOAD;
					end if;
								
			when S_WHILE_BEG =>	DATA_EN		<= '1';
						DATA_WREN	<= '0';
						pc_inc		<= '1';
						nstate 		<= S_WHILE_BEG1;
			when S_WHILE_BEG1 =>	if (DATA_RDATA /= "00000000") then
							nstate 	<= S_FETCH;
						else
							cnt_inc <= '1';
							nstate 	<= S_WHILE_BEG2;
						end if;
			when S_WHILE_BEG2 =>	CODE_EN		<= '1';
						nstate 		<= S_WHILE_BEG3;
			when S_WHILE_BEG3 => 	if (cnt_num = "00000000") then
							nstate	<= S_FETCH;
						else
							if (CODE_DATA = x"5B") then 
								cnt_inc 	<= '1';
							elsif (CODE_DATA = x"5D") then
								cnt_dec 	<= '1';
							end if;
							pc_inc 	<= '1';
							nstate 	<= S_WHILE_BEG2;
						end if;

			when S_WHILE_END =>	DATA_EN 	<= '1';
						DATA_WREN 	<= '0';
						nstate 		<= S_WHILE_END1;
			when S_WHILE_END1 => 	if (DATA_RDATA = "00000000") then
							pc_inc 	<= '1';
							nstate 	<= S_FETCH;
						else
							cnt_inc <= '1';
							pc_dec 	<= '1';
							nstate 	<= S_WHILE_END2;
						end if;
			when S_WHILE_END2 =>	CODE_EN 	<= '1';
						nstate		<= S_WHILE_END3;
			when S_WHILE_END3 => 	if (cnt_num = "00000000") then
							nstate <= S_FETCH;
						else
							if (CODE_DATA = X"5D") then
								cnt_inc <= '1';
							elsif (CODE_DATA = X"5B") then
								cnt_dec <= '1';
							end if;
							nstate <= S_WHILE_END4;
						end if;
			when S_WHILE_END4 =>	if (cnt_num = "00000000") then
							pc_inc <= '1';
						else
							pc_dec <= '1';
						end if;
						nstate <= S_WHILE_END2;
									
			when S_BREAK => pc_inc		<= '1';
					cnt_inc 	<= '1';
					nstate		<= S_BREAK1;
			when S_BREAK1 =>	if (cnt_num = "00000000") then
							nstate	<= S_FETCH;
						else
							CODE_EN	<= '1';
							nstate	<= S_BREAK2;
						end if;
			when S_BREAK2 => if (CODE_DATA = X"5B") then
						cnt_inc	<= '1';
					elsif (CODE_DATA = X"5D") then
						cnt_dec	<= '1';
					end if;
					pc_inc <= '1';
					nstate <= S_BREAK1;
								
			when S_RETURN =>	nstate <= S_RETURN;

			when S_OTHERS =>	pc_inc <= '1';
						nstate <= S_FETCH;
						
			when others =>		null;
		end case;
	end process;
	-------------------------------------------------------------------------
end behavioral;
