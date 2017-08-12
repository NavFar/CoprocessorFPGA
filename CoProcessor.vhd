----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:30:22 07/10/2017 
-- Design Name: 
-- Module Name:    CoProcessor - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.FloatPt.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity CoProcessor is
    Port ( CLK : in  STD_LOGIC;
           RX : in  STD_LOGIC;
			  probe1: inout STD_LOGIC;
           TX : out  STD_LOGIC);
end CoProcessor;

architecture Behavioral of CoProcessor is

--------------------------------RX--------------------------------
component UART_RX is
  generic (
    g_CLKS_PER_BIT : integer      -- Needs to be set correctly
    );
  port (
    i_Clk       : in  std_logic;
    i_RX_Serial : in  std_logic;
    o_RX_DV     : out std_logic;
    o_RX_Byte   : out std_logic_vector(7 downto 0)
    );
end component UART_RX;
--------------------------------TX-------------------------------- 
component  UART_TX is
  generic (
    g_CLKS_PER_BIT : integer      -- Needs to be set correctly
    );
  port (
    i_Clk       : in  std_logic;
    i_TX_DV     : in  std_logic;
    i_TX_Byte   : in  std_logic_vector(7 downto 0);
    o_TX_Active : out std_logic;
    o_TX_Serial : out std_logic;
    o_TX_Done   : out std_logic
    );
end component UART_TX;

constant c_CLKS_PER_BIT : integer := 20000;
type state_t is(state0,state1,state2,state3,state4,state5,state6,state7,state8,state9);
signal curState : state_t:=state0;
Signal sendBuffer        : STD_LOGIC_VECTOR(47 downto 0):=(others=>'0');

------RX Signal------
Signal RXReadyOut       : STD_LOGIC:='0';
Signal RXReady       : STD_LOGIC:='0';
Signal RXReadyBuffer : STD_LOGIC:='0';
Signal RXDataOut     :STD_LOGIC_VECTOR(7 downto 0):=(others=>'0');
Signal RXDataOutBuffer :STD_LOGIC_VECTOR(7 downto 0):=(others=>'0');
------TX Signal------
Signal TXStart       : STD_LOGIC:='0';
Signal TXDataIn      : STD_LOGIC_VECTOR(7 downto 0):=(others=>'0');
Signal TXDone        : STD_LOGIC:='0';
Signal TXDoneOut        : STD_LOGIC:='0';
Signal TXDoneBuffer  : STD_LOGIC:='0';
------CPU Signal-----
Signal CPUInput1        : STD_LOGIC_VECTOR(31 downto 0):=(others=>'0');
Signal CPUInput2        : STD_LOGIC_VECTOR(31 downto 0):=(others=>'0');
Signal CPUOutput0       : STD_LOGIC_VECTOR(31 downto 0):=(others=>'0');
Signal CPUOutput0Buffer : STD_LOGIC_VECTOR(31 downto 0):=(others=>'0');
Signal CPUOutput1       : STD_LOGIC_VECTOR(31 downto 0):=(others=>'0');
Signal CPUOutput1Buffer : STD_LOGIC_VECTOR(31 downto 0):=(others=>'0');
Signal CPUOutput2       : STD_LOGIC_VECTOR(31 downto 0):=(others=>'0');
Signal CPUOutput2Buffer : STD_LOGIC_VECTOR(31 downto 0):=(others=>'0');
Signal CPUenable        : STD_LOGIC_VECTOR(2  downto 0):=(others=>'0');
Signal CPUDoneOut       : STD_LOGIC_VECTOR(2  downto 0):=(others=>'0');
Signal CPUDone          : STD_LOGIC_VECTOR(2  downto 0):=(others=>'0');
Signal CPUDoneBuffer    : STD_LOGIC_VECTOR(2  downto 0):=(others=>'0');
signal MultOVF          :STD_LOGIC:='0';
signal DivOVF          :STD_LOGIC:='0';
begin
adder_Sub: FPP_ADD_SUB port map(CPUInput1,CPUInput2,CLK,'0',CPUenable(0),CPUDoneOut(0),CPUOutput0);
mult: FPP_MULT   port map(CPUInput1,CPUInput2,CLK,'0',CPUenable(1),CPUDoneOut(1),MultOVF,CPUOutput1);
divi: FPP_DIVIDE port map(CPUInput1,CPUInput2,CLK,'0',CPUenable(2),CPUDoneOut(2),DivOVF,CPUOutput2);
sender:  UART_TX generic map (g_CLKS_PER_BIT => c_CLKS_PER_BIT) port map (CLK,TXStart,TXDataIn,open,TX,TXDoneOut);
reciver: UART_RX generic map (g_CLKS_PER_BIT => c_CLKS_PER_BIT) port map (CLK,RX,RXReadyOut,RXDataOut);
----------------main process-------------------
process(CLK)
variable times:integer:=0;
variable which:integer:=0;
begin
	if(rising_edge(CLK)) then
		case curState is
			when state0 =>
					cpuDoneBuffer<=cpuDone;
					times:=4;
					which:=0;
					CPUenable<=(others=>'0');
					TXStart<='0';
					RXReadyBuffer<=RXReady;
					curState<=state1;
					sendBuffer<=(others=>'0');
			when state1 =>
					if(RXReadyBuffer/=RXReady) then
						if(which=0) then
							CPUInput1(8*times-1 downto 8*times-8)<=RXDataOutBuffer;
							times:=times-1;
						elsif(which=1) then
							CPUInput2(8*times-1 downto 8*times-8)<=RXDataOutBuffer;
							times:=times-1;
						else
							CPUenable<=RXDataOutBuffer(2 downto 0);
							cpuDoneBuffer<=cpuDone;
							curState<=state2;
						end if;
					if(times=0) then
						which:=which+1;
						times:=4;
					end if;
					RXReadyBuffer<=RXReady;
					end if;
			when state2 =>
					if(CPUenable(0)='1') then
					if(CPUDone(0)/=CPUDoneBuffer(0)) then
						--sendBuffer(47 downto 16)<=CPUOutput0Buffer;
						sendBuffer(47 downto 16)<=CPUOutput0Buffer;
						curState<=state3;
						CPUenable(0)<='0';
					end if;
					elsif(CPUenable(1)='1') then
					if(CPUDone(1)/=CPUDoneBuffer(1)) then
						sendBuffer(47 downto 16)<=CPUOutput1Buffer;
						sendBuffer(15)<=MultOVF;
						curState<=state3;
						CPUenable(1)<='0';
					end if;					
					elsif(CPUenable(2)='1') then
					if(CPUDone(2)/=CPUDoneBuffer(2)) then
						sendBuffer(47 downto 16)<=CPUOutput2Buffer;
						curState<=state3;
						sendBuffer(15)<=DivOVF;
						CPUenable(2)<='0';
					end if;					
					else
						curState<=state0;
					end if;
			when state3 =>
					TXDoneBuffer<=TXDone;
					TXStart<='1';
					TXDataIn<=sendBuffer(47 downto 40);
					times:=6;
					curState<=state5;
			when state5=>
					TXStart<='0';
					if(times=1) then
							curState<=state0;
					else
						
						TXDoneBuffer<=TXDone;
						times:=times-1;
						curState<=state4;
					end if;
					
			when state4 =>
					if(TXDoneBuffer/=TXDone) then
						TXDataIn<=sendBuffer(8*times-1 downto 8*times-8);
						TXStart<='1';
						TXDoneBuffer<=TXDone;
					curState<=state5;
					end if;
			when others=>
					curState<=state0;
		end case;
		
	end if;
end process;

--------------- add flag----------------
process(CPUDoneOut(0)) 
begin
	if(rising_edge(CPUDoneOut(0)))then
		CPUDone(0)<=not CPUDone(0);
		CPUOutput0Buffer<=CPUOutput0;
	end if;
end process;
-------------- multiplie flag----------------
process(CPUDoneOut(1)) 
begin
	if(rising_edge(CPUDoneOut(1)))then
		CPUDone(1)<=not CPUDone(1);
		CPUOutput1Buffer<=CPUOutput1;
	end if;
end process;
--------------- divide flag----------------
process(CPUDoneOut(2)) 
begin
	if(rising_edge(CPUDoneOut(2)))then
		CPUDone(2)<=not CPUDone(2);
		CPUOutput2Buffer<=CPUOutput2;
	end if;
end process;
--------------- TX flag----------------
process(TXDoneOut) 
begin
	if(rising_edge(TXDoneOut))then
		TXDone<=not TXDone;
	end if;
end process;
--------------- RX flag----------------
process(RXReadyOut) 
begin
	if(rising_edge(RXReadyOut))then
		RXReady<=not RXReady;
		RXDataOutBuffer<=RXDataOut;
		probe1<=not probe1;
	end if;
end process;
end Behavioral;

