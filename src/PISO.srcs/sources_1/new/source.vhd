library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity project_reti_logiche is
    Port ( 
        i_clk     : in std_logic;
        i_start   : in std_logic;
        i_rst     : in std_logic;
        i_data    : in std_logic_vector(7 downto 0);
        o_address : out std_logic_vector(15 downto 0);
        o_done    : out std_logic;
        o_en      : out std_logic;
        o_we      : out std_logic;
        o_data    : out std_logic_vector(7 downto 0)
    );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is

component Viterbi is
   port(
	clk: in std_logic;
	reset: in std_logic;
	input: in std_logic_vector(7 downto 0);
	start: in std_logic:='0';
	done: out std_logic:='1';
	 output1 : out	std_logic_vector(7 downto 0);
	 output2 : out	std_logic_vector(7 downto 0)
	);
end component;

type state_type is ( IDLE, FETCH_DIMENSION, WAIT_DIMENSION, GET_DIMENSION, CHECK_FINISH, FETCH_NEXT_BYTE,WAIT_BYTE, GET_NEXT_BYTE,
                     ENCODE_SETUP, WAIT_ENCODING, ENCODE, WRITE1, WRITE2, FINISH, END_ENCODING, ENCODED_ENDED, 
                     PADDING, ENCODE_SETUP_FOR_PADDING, WAIT_ENCODING_FOR_PADDING, ENCODE_FOR_PADDING);
signal state_reg, state_next : state_type;
    
signal o_done_next, o_en_next, o_we_next : std_logic := '0';
signal o_data_next : std_logic_vector(7 downto 0) := "00000000";
signal o_address_next : std_logic_vector(15 downto 0) := "0000000000000000";
signal address_reg, address_next : std_logic_vector(15 downto 0) := "0000000000000000";


signal input_register, input_register_next: std_logic_vector(7 downto 0):="00000000";
signal dimension, dimension_next: integer range 0 to 255 := 0;
signal start, start_next: std_logic:='0';

signal output1_register: std_logic_vector(7 downto 0):="00000000";
signal output2_register: std_logic_vector(7 downto 0):="00000000";
signal done_encoding: std_logic:='0';
signal base_write_address,base_write_address_next: std_logic_vector(15 downto 0):="0000001111100101";
signal reset_FSM,reset_FSM_next : std_logic:='0';
signal zero_padding : std_logic_vector(7 downto 0):="00000000";

begin

ViterbiCoder: Viterbi
PORT MAP(
        clk => i_clk,
        reset => reset_fsm,
        input => input_register,
        start => start,
        done => done_encoding,
        output1 => output1_register,
        output2 => output2_register
        );

            process (i_clk, i_rst) 
            begin
                if (i_rst = '1') then
                    --if (state_reg = ENCODE or state_reg = END_ENCODING or state_reg = WAIT_ENCODING) then
                        state_reg <= END_ENCODING;
                       -- else
                        --    reset_fsm <= '1';
                        --    state_reg <= IDLE;
                        -- end if;
                    
                    base_write_address <= "0000001111100101";
                    
                 elsif (i_clk'event and i_clk='1') then
                    o_done <= o_done_next;
                    o_en <= o_en_next;
                    o_we <= o_we_next;
                    o_data <= o_data_next;
                   o_address <= o_address_next;
                    dimension <= dimension_next;
                     address_reg <= address_next;
                    input_register <= input_register_next;
                    start <= start_next;
                    state_reg <= state_next;
                    base_write_address <= base_write_address_next;
                    reset_fsm <= reset_fsm_next;
                   
                end if;
            end process;
            
            process(state_reg, i_data, i_start, input_register, dimension, done_encoding, output1_register, output2_register
            ,start, base_write_address,address_reg, o_address_next, base_write_address_next, zero_padding)
            begin
            
            o_done_next <= '0';
            o_en_next <= '0';
            o_we_next <= '0';
            o_data_next <= "00000000";
            -- o_address_next <= o_address;
            address_next <= address_reg;
            start_next <= start; 
            reset_fsm_next <= '0';
            
            case state_reg is
                        when IDLE =>
                            if (i_start = '1') then
                                state_next <= FETCH_DIMENSION;
                            end if;
            
            when FETCH_DIMENSION =>    -- richiesta numero di byte alla ram
                                            o_en_next <= '1';
                                            o_we_next <= '0';
                                            o_address_next <= "0000000000000000";
                                            state_next <= WAIT_DIMENSION;
                                            
            when WAIT_DIMENSION =>    state_next <= GET_DIMENSION;
                                        
            when GET_DIMENSION =>      
                                           dimension_next <= conv_integer(i_data);
                                           state_next <= CHECK_FINISH;
                                           
             when CHECK_FINISH =>         if (dimension = 0) then 
                                                    state_next <= FINISH;
                                                     o_done_next <= '1';
                                          else state_next <= FETCH_NEXT_BYTE;
                                                
                                                 o_address_next <= address_next; 
                                          end if;
                                          
            when FINISH =>                if (i_start = '0') then
                                          state_next <= PADDING;
                                          address_next <= "0000000000000000";                                          
                                          end if;
                              
            
            when FETCH_NEXT_BYTE =>
                                         o_en_next <= '1';
                                         o_we_next <= '0';
                                         o_address_next <= address_next + "0000000000000001";
                                         state_next <= WAIT_BYTE; 
                                         base_write_address_next <= base_write_address + "0000000000000010"; 
                                         
                                         
                                         
          when WAIT_BYTE =>    state_next <= GET_NEXT_BYTE;
                               address_next <= o_address_next;
          
        
                                         
          when GET_NEXT_BYTE =>          input_register_next <= i_data;
                                         state_next <= ENCODE_SETUP;      
                                         
          when ENCODE_SETUP =>           start_next <= '1';
                                         state_next <= WAIT_ENCODING;  
                             
          when WAIT_ENCODING =>         if ( start = '1' or done_encoding = '1') then state_next <= WAIT_ENCODING;
                                        start_next <= '0';
                                        else
                                        state_next <= ENCODE;
                                        end if;
          
          when ENCODE =>                 if (done_encoding = '0') then state_next <= ENCODE;
                                         else state_next <= WRITE1;
                                        
                                         end if;
                                         
          when WRITE1 =>                 o_en_next <= '1';
                                         o_we_next <= '1';
                                         o_address_next <= base_write_address_next + "0000000000000001";
                                         o_data_next <= output1_register;
                                         state_next <= WRITE2;
                                         dimension_next <= dimension - 1;
                                      
          
          when WRITE2 =>                 o_en_next <= '1';
                                         o_we_next <= '1';
                                         o_address_next <= base_write_address_next + "0000000000000010";
                                         o_data_next <= output2_register;
                                         state_next <= CHECK_FINISH;
                                         
                                                                                                                
           when END_ENCODING =>           if (done_encoding = '0') then state_next <= END_ENCODING;
                                                                                  else 
                                                                                    reset_fsm_next <= '1';
                                                                                    state_next <= ENCODED_ENDED;
                                                                                  end if;
           when ENCODED_ENDED =>                       state_next <= PADDING;    
           when PADDING =>                    input_register_next <= zero_padding;  
                                               state_next <= ENCODE_SETUP_FOR_PADDING; 
           
          when ENCODE_SETUP_FOR_PADDING =>          start_next <= '1';
                                                    state_next <= WAIT_ENCODING_FOR_PADDING;  
          
           when WAIT_ENCODING_FOR_PADDING =>         if ( start = '1' or done_encoding = '1') then state_next <= WAIT_ENCODING_FOR_PADDING;
                                                                                            start_next <= '0';
                                                                                            else
                                                                                            state_next <= ENCODE_FOR_PADDING;
                                                                                            end if; 
                                                                                            
          when ENCODE_FOR_PADDING =>          if (done_encoding = '0') then state_next <= ENCODE_FOR_PADDING;
                                                        else state_next <= IDLE;
                                                             base_write_address_next <= "0000001111100101";
                                                             address_next <= "0000000000000000";  
                                                        end if; 
                                                                                                      
                                                                                                                                                                                   
                 
            end case;                               
            end process;
            
            end Behavioral;

-----------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Viterbi is
   port(
	clk: in std_logic;
	reset: in std_logic;
	input: in std_logic_vector(7 downto 0);
	start: in std_logic:='0';
	done: out std_logic:='1';
	 output1 : out	std_logic_vector(7 downto 0);
	 output2 : out	std_logic_vector(7 downto 0)
	);
end Viterbi;

architecture rtl of Viterbi is

component piso is
    generic (
        g_DATA_WIDTH : integer range 2 to integer'high := 8; -- input parallel data width
        -- least significant bit first of the serialized output
        g_LSB_FIRST : boolean := false
    );
    port (
        i_clk : in std_logic; -- clock signal
        i_rst : in std_logic; -- reset signal
        
        i_start : in  std_logic; -- accept the current input parallel data and serialize them
        i_data  : in  std_logic_vector(g_DATA_WIDTH - 1 downto 0); -- the input parallel data
        o_rdy   : out std_logic; -- the module is ready to accept next parallel data
        
        o_data_start : out std_logic; -- start of the serial output data
        o_data       : out std_logic -- current bit of the serial output data
    );
end component;

component ViterbiSIPO is
   port(
	clk: in std_logic;
	reset: in std_logic;
	data_in: in std_logic;
	start: in std_logic:='0';
	done: out std_logic;
	 output1 : out	std_logic_vector(7 downto 0);
	 output2 : out	std_logic_vector(7 downto 0)
	);
end component;

component D_flipflop is
           port
           (
              clk : in std_logic;
        
              reset : in std_logic;
              ce  : in std_logic;
              
              d : in std_logic;
        
              q : out std_logic
           );
        end component;

signal idata : std_logic;
signal istart : std_logic;
signal idone : std_logic:='1';

begin

 Viterbi: ViterbiSIPO
  PORT MAP (
      clk => clk,
      reset => reset,
      data_in => idata,
      output1 => output1,
      output2 => output2,
      start => istart,
      done => idone
  );

 ParallelToSerial: PISO
 PORT MAP (
       I_clk => clk,
       I_rst => reset,
       i_start => start,
       i_data => input,
       o_data_start => istart,
       o_data => idata
   );
   
  FlipFlopD: D_flipflop
  PORT MAP(
        clk => clk,
        reset => reset,
        ce => '1',
        d => idone,
        q => done
  );

   
   
end rtl;
------------------------
library ieee;
use ieee.std_logic_1164.all;

entity piso is
    generic (
        g_DATA_WIDTH : integer range 2 to integer'high := 8; -- input parallel data width
        -- least significant bit first of the serialized output
        g_LSB_FIRST : boolean := false
    );
    port (
        i_clk : in std_logic; -- clock signal
        i_rst : in std_logic; -- reset signal
        
        i_start : in  std_logic; -- accept the current input parallel data and serialize them
        i_data  : in  std_logic_vector(g_DATA_WIDTH - 1 downto 0); -- the input parallel data
        o_rdy   : out std_logic; -- the module is ready to accept next parallel data
        
        o_data_start : out std_logic; -- start of the serial output data
        o_data       : out std_logic -- current bit of the serial output data
    );
end entity piso;


architecture rtl of piso is
    -- shifter register used for serializing the parallel input data
    signal r_shifter : std_logic_vector(g_DATA_WIDTH - 1 downto 0);
    -- number of transmitted bits (0 value stands for not transmitting state)
    signal r_transmitted_count : integer range 0 to 8;
begin
    
    o_rdy <= '1' when r_transmitted_count = 0 else '0'; -- the module is ready when not transmitting
    
    -- least/most significant bit assign generating
    assign_lsb : if (g_LSB_FIRST) generate
        o_data <= r_shifter(r_shifter'right);
    end generate assign_lsb;
    assign_msb : if (not g_LSB_FIRST) generate
        o_data <= r_shifter(r_shifter'left);
    end generate assign_msb;
    
    -- Description:
    --     Perform one conversion step. It works with the shifter register to serialize the input.
    conversion_step : process (i_clk) is
    begin
        if (rising_edge(i_clk)) then
            if (r_transmitted_count /= 1) then
            o_data_start <= '0';
            end if;
            
            if (i_rst = '1') then -- initialize the module
                r_transmitted_count <= 0; -- non ho ancora trasmesso niente
            else 
            if (r_transmitted_count = 0) then -- if not transmitting
                    if (i_start = '1') then -- if start required
                        o_data_start        <= '1'; -- serial data start
                        r_shifter           <= i_data; -- store converted data internally
                        r_transmitted_count <= r_transmitted_count + 1; -- start the transmitting
                        end if;
                   
                    elsif (r_transmitted_count = 1) then -- if not transmitting
                                        --if (i_start = '1') then -- if start required
                                            --o_data_start        <= '1'; -- serial data start
                                            --r_shifter           <= i_data; -- store converted data internally
                                            r_transmitted_count <= r_transmitted_count + 1; -- start the transmitting
                                        --end if;
                else -- if transmitting
                    if (g_LSB_FIRST) then -- first least significant bit
                        r_shifter <= '-' & r_shifter(r_shifter'left downto 1);
                    else -- first most significant bit
                        r_shifter <= r_shifter(r_shifter'left - 1 downto 0) & '-';
                    end if;
                    
                    if (r_transmitted_count = 8) then -- last transmitted bit
                        r_transmitted_count <= 0; -- stop transmitting
                    else
                        -- increment the transmitted count
                        r_transmitted_count <= r_transmitted_count + 1;
                    end if;
               end if;
                
            end if;
            
        end if;
    end process conversion_step;
    
    
end architecture rtl;
-------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ViterbiSIPO is
   port(
	clk: in std_logic;
	reset: in std_logic;
	data_in: in std_logic;
	start: in std_logic:='0';
	done: out std_logic:='1';
	 output1 : out	std_logic_vector(7 downto 0);
	 output2 : out	std_logic_vector(7 downto 0)
	);
end ViterbiSIPO;

architecture rtl of ViterbiSIPO is

signal idata : std_logic_vector(1 downto 0);
signal idone: std_logic:='1';
signal ifinish: std_logic:='0';
signal ishift : std_logic:='0';
-- signal istart : std_logic:='0';


component shift_register is
   port(
	clk: in std_logic;
	reset: in std_logic;
	shift: in std_logic;
	 input: in std_logic_vector(1 downto 0);
	 output1 : out	std_logic_vector(7 downto 0);
	 output2 : out	std_logic_vector(7 downto 0)
	);
end component;

component counter is

	port(
		clk		 : in	std_logic;
		data_in	 : in	std_logic;
		reset	 : in	std_logic;
		data_out	 : out	std_logic
	);
	
end component;

component moore_4s is

	port(
		clk		 : in	std_logic;
		data_in	 : in	std_logic;
	    done     : in std_logic:='1';
		reset	 : in	std_logic;
		data_out	 : out	std_logic_vector(1 downto 0)
	);
	
end component;


BEGIN

  COUNT: Counter
  PORT MAP (
      clk => clk,
      reset => reset,
      data_in => start, -- -i
      data_out => ifinish
  );
  
  ishift <= not idone; 
    MOORE: moore_4s
  PORT MAP (
      clk => clk,
      reset => reset,
      done => idone,  
      data_in => data_in,
      data_out => idata
  );
  done <= idone;

  SHIFT: shift_register
  PORT MAP (
      clk => clk,
      reset => reset,
      shift => ishift,
      input =>idata,
      output1 => output1,
      output2 => output2
  );

PROCESS(start,clk,ifinish)
begin
if (rising_edge(clk)) then
if (start = '1') then  idone <='0'; --istart <= '1';
end if;

if (ifinish = '1') then  idone <='1'; --istart <= '0'; 
end if;

end if;

end process;


end rtl;

-------------------------------------
-- shift register ad-hoc per l'algoritmo
-------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity shift_register is
   port(
	clk: in std_logic;
	reset: in std_logic;
	shift: in std_logic;
	 input: in std_logic_vector(1 downto 0);
	 output1 : out	std_logic_vector(7 downto 0);
	 output2 : out	std_logic_vector(7 downto 0)
	);
end shift_register;

architecture shift_behav of shift_register is

signal zero: std_logic;
signal uno: std_logic;
signal due: std_logic;
signal tre: std_logic;
signal quattro: std_logic;
signal cinque: std_logic;
signal sei: std_logic;
signal sette: std_logic;
signal otto: std_logic;
signal nove: std_logic;
signal dieci: std_logic;
signal undici: std_logic;
signal dodici: std_logic;
signal tredici: std_logic;
signal quattordici: std_logic;
signal quindici: std_logic;

        component D_flipflop is
           port
           (
              clk : in std_logic;
        
              reset : in std_logic;
              ce  : in std_logic;
              
              d : in std_logic;
        
              q : out std_logic
           );
           end component;

signal ishift : std_logic := '0';
BEGIN

  FF0 : D_flipflop
  PORT MAP (
      D => due,
      ce => ishift,
      clk => clk,
      reset => reset,
      Q => zero
  );

  FF1 : D_flipflop
  PORT MAP (
      D => tre,
      clk => clk,
      ce => ishift,
      reset => reset,
      Q => uno
  );

  FF2 : D_flipflop
  PORT MAP (
      D => quattro,
      clk => clk,
      ce => ishift,
      reset => reset,
      Q => due
  );
  FF3 : D_flipflop
  PORT MAP (
      D => cinque,
      clk => clk,
      ce => ishift,
      reset => reset,
      Q => tre
  );
  FF4 : D_flipflop
  PORT MAP (
      D => sei,
      clk => clk,
      ce => ishift,
      reset => reset,
      Q => quattro
  );
  FF5 : D_flipflop
  PORT MAP (
      D => sette,
      clk => clk,
      ce => ishift,
      reset => reset,
      Q => cinque
  );
  FF6 : D_flipflop
  PORT MAP (
      D => otto,
      clk => clk,
      ce => ishift,
      reset => reset,
      Q => sei
  );
 FF7 : D_flipflop
  PORT MAP (
      D => nove,
      clk => clk,
      ce => ishift,
      reset => reset,
      Q => sette
  );
 FF8 : D_flipflop
  PORT MAP (
      D => dieci,
      clk => clk,
      ce => ishift,
      reset => reset,
      Q => otto
  );
 FF9 : D_flipflop
  PORT MAP (
      D => undici,
      clk => clk,
      ce => ishift,
      reset => reset,
      Q => nove
  );
 FF10 : D_flipflop
  PORT MAP (
      D => dodici,
      clk => clk,
      ce => ishift,
      reset => reset,
      Q => dieci
  );
 FF11 : D_flipflop
  PORT MAP (
      D => tredici,
      clk => clk,
      ce => ishift,
      reset => reset,
      Q => undici
  );
 FF12 : D_flipflop
  PORT MAP (
      D => quattordici,
      clk => clk,
      ce => ishift,
      reset => reset,
      Q => dodici
  );
 FF13 : D_flipflop
  PORT MAP (
      D => quindici,
      clk => clk,
      ce => ishift,
      reset => reset,
      Q => tredici
  );
 FF14 : D_flipflop
  PORT MAP (
      D => input(0),
      clk => clk,
      ce => ishift,
      reset => reset,
      Q => quattordici
  );
 FF15 : D_flipflop
  PORT MAP (
      D => input(1),
      clk => clk,
      ce => ishift,
      reset => reset,
      Q => quindici
  );

output1(7) <= uno;
output1(6) <= zero;
output1(5) <= tre;
output1(4) <= due;
output1(3) <= cinque;
output1(2) <= quattro;
output1(1) <= sette;
output1(0) <= sei;

output2(7) <= nove;
output2(6) <= otto;
output2(5) <= undici;
output2(4) <= dieci;
output2(3) <= tredici;
output2(2) <= dodici;
output2(1) <= quindici;
output2(0) <= quattordici;


process(clk,shift)
begin
if rising_edge(clk) then 
    ishift <= shift;
    end if;
end process;
end shift_behav;
-------------------------------------- 
-- Flip Flop di tipo D (delay), Rising Edge
--------------------------------------
        library IEEE;
        use IEEE.STD_LOGIC_1164.ALL;
        
        entity D_flipflop is
           port
           (
              clk : in std_logic;
        
              reset : in std_logic;
              ce  : in std_logic;
              
              d : in std_logic;
        
              q : out std_logic
           );
        end entity D_flipflop;
         
        architecture Behavioral of D_flipflop is
        
        begin
           process (clk) is
           begin
              if rising_edge(clk) then  
                 if (reset='1') then   
                    q <= '0';
                 elsif (ce='1') then
                    if (d ='1') then
                     q <= '1';
                 elsif (d ='0') then 
                     q<= '0';
                    end if;
                 end if;
              end if;
           end process;
        end architecture Behavioral;
-----------------------------------------------------------------------
-- Contatore modulo 8
-------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity counter is

	port(
		clk		 : in	std_logic;
		data_in	 : in	std_logic;
		reset	 : in	std_logic;
		data_out	 : out	std_logic
	);
	
end entity;

architecture rtl of counter is

	-- Build an enumerated type for the state machine
	type state_type is (s0, s1, s2, s3,s4,s5,s6,s7,s8);
	
	-- Register to hold the current state
	signal state   : state_type;

begin
	-- Logic to advance to the next state
	process (clk, reset)
	begin
		if reset = '1' then
			state <= s0;
		elsif (rising_edge(clk)) then
			case state is
				when s0=>
					if data_in = '1' then
						state <= s1;
					else
						state <= s0;
					end if;
				when s1=>
					--if data_in = '1' then
						state <= s2;
					--else
					--	state <= s0;
					--end if;
				when s2=>
					--if data_in = '1' then
						state <= s3;
					--else
						--state <= s0;
					--end if;
				when s3 =>
					--if data_in = '1' then
						state <= s4;
					--else
						--state <= s0;
					--end if;
				when s4 =>
					--if data_in = '1' then
						state <= s5;
					--else
						--state <= s0;
					--end if;
				when s5 =>
					--if data_in = '1' then
						state <= s6;
					--else
						--state <= s0;
					--end if;
				when s6 =>
					--if data_in = '1' then
						state <= s7;
					--else
						--state <= s0;
					--end if;
					
					when s7 =>
                                        --if data_in = '1' then
                                            state <= s8;
                                        --else
                                            --state <= s0;
                                        --end if;
				when s8 =>
					if data_in = '1' then
						state <= s8;
					else
						state <= s0;
					end if;
                
			end case;
		end if;
	end process;
	
	-- Output depends solely on the current state
	process (state)
	begin
	
		case state is
			when s0 =>
				data_out <= '0';
			when s1 =>
				data_out <= '0';
			when s2 =>
				data_out <= '0';
			when s3 =>
				data_out <= '0';
			when s4 =>
				data_out <= '0';
			when s5 =>
				data_out <= '0';
			when s6 =>
				data_out <= '0';
			when s7 =>
				data_out <= '0';
			when s8 =>
                 data_out <= '1';	
            --when s9 =>
              --        data_out <= '1';    
		end case;
	end process;
	
end rtl;
-----------------------------------------------
-- Moore FSM che calcola l'algoritmo
------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity moore_4s is

	port(
		clk		 : in	std_logic;
		data_in	 : in	std_logic;
		done     : in std_logic:='1';
		reset	 : in	std_logic;
		data_out	 : out	std_logic_vector(1 downto 0)
	);
	
end entity;

architecture rtl of moore_4s is

	-- Build an enumerated type for the state machine
	type state_type is (s00, s01, s10, s11,s20,s21,s30,s31,
	                    s00d, s01d, s10d,s11d,s20d,s21d,s30d,s31d);
	
	-- Register to hold the current state
	signal state   : state_type;

begin
	-- Logic to advance to the next state
	process (clk, reset,done)
	begin
		if reset = '1' then
			state <= s00;
		elsif (rising_edge(clk)) then
			case state is
			
				when s00=>
				    if (done = '0') then
					   if data_in = '1' then
						  state <= s21;
					   else
						  state <= s00;
					   end if;
					elsif (done = '1') then 
					   if data_in = '1' then
                                              state <= s21d;
                                           else
                                              state <= s00d;
                                           end if;
					end if;
					
				when s01=>
				if (done = '0') then
					if data_in = '1' then
						state <= s21;
					else
						state <= s00;
					end if;
					elsif (done = '1') then if data_in = '1' then
                                            state <= s21d;
                                        else
                                            state <= s00d;
                                        end if;
                                        end if;
				when s10=>
				if (done = '0') then
					if data_in = '1' then
						state <= s20;
					else
						state <= s01;
					end if;
					elsif (done = '1') then state <= s10d;
                                        end if;
				when s11 =>
				if (done = '0') then
					if data_in = '1' then
						state <= s20;
					else
						state <= s01;
					end if;
					elsif (done = '1') then state <= s11d;
                                        end if;
				when s20 =>
				if (done = '0') then
					if data_in = '1' then
						state <= s31;
					else
						state <= s10;
					end if;
					elsif (done = '1') then state <= s20d;
                                        end if;
				when s21 =>
				if (done = '0') then
					if data_in = '1' then
						state <= s31;
					else
						state <= s10;
					end if;
					elsif (done = '1') then state <= s21d;
                                        end if;
				when s30 =>
				if (done = '0') then
					if data_in = '1' then
						state <= s30;
					else
						state <= s11;
					end if;
					elsif (done = '1') then state <= s30d;
                                        end if;
				when s31 =>
				if (done = '0') then
					if data_in = '1' then
						state <= s30;
					else
						state <= s11;
					end if;
					elsif (done = '1') then state <= s31d;
                                        end if;
                                        
               
               when s00d=>
                                   if (done = '0') then
                                      if data_in = '1' then
                                         state <= s21;
                                      else
                                         state <= s00;
                                      end if;
                                   elsif (done = '1') then 
                                        state <= s00d;
                                   end if;
                                   
                               when s01d=>
                               if (done = '0') then
                                   if data_in = '1' then
                                       state <= s21;
                                   else
                                       state <= s00;
                                   end if;
                                   elsif (done = '1') then state <= s01d;
                                                       end if;
                               when s10d=>
                               if (done = '0') then
                                   if data_in = '1' then
                                       state <= s20;
                                   else
                                       state <= s01;
                                   end if;
                                   elsif (done = '1') then state <= s10d;
                                                       end if;
                               when s11d =>
                               if (done = '0') then
                                   if data_in = '1' then
                                       state <= s20;
                                   else
                                       state <= s01;
                                   end if;
                                   elsif (done = '1') then state <= s11d;
                                                       end if;
                               when s20d =>
                               if (done = '0') then
                                   if data_in = '1' then
                                       state <= s31;
                                   else
                                       state <= s10;
                                   end if;
                                   elsif (done = '1') then state <= s20d;
                                                       end if;
                               when s21d =>
                               if (done = '0') then
                                   if data_in = '1' then
                                       state <= s31;
                                   else
                                       state <= s10;
                                   end if;
                                   elsif (done = '1') then state <= s21d;
                                                       end if;
                               when s30d =>
                               if (done = '0') then
                                   if data_in = '1' then
                                       state <= s30;
                                   else
                                       state <= s11;
                                   end if;
                                   elsif (done = '1') then state <= s30d;
                                                       end if;
                               when s31d =>
                               if (done = '0') then
                                   if data_in = '1' then
                                       state <= s30;
                                   else
                                       state <= s11;
                                   end if;
                                   elsif (done = '1') then state <= s31d;
                                                       end if;
			end case;
		end if;
	end process;
	
	-- Output depends solely on the current state
	process (state)
	begin
		case state is
			when s00 =>
				data_out <= "00";
			when s01 =>
				data_out <= "11";
			when s10 =>
				data_out <= "01";
			when s11 =>
				data_out <= "10";
			when s20 =>
				data_out <= "00";
			when s21 =>
				data_out <= "11";
			when s30 =>
				data_out <= "01";
			when s31 =>
				data_out <= "10";
			                when s00d =>
                                data_out <= "00";
                            when s01d =>
                                data_out <= "11";
                            when s10d =>
                                data_out <= "01";
                            when s11d =>
                                data_out <= "10";
                            when s20d =>
                                data_out <= "00";
                            when s21d =>
                                data_out <= "11";
                            when s30d =>
                                data_out <= "01";
                            when s31d =>
                                data_out <= "10";
		end case;
	end process;
	
end rtl;