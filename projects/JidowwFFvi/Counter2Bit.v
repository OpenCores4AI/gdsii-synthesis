library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity Counter2Bit is
    Port (
        clk   : in  STD_LOGIC;
        reset : in  STD_LOGIC;
        count : out STD_LOGIC_VECTOR (1 downto 0)
    );
end Counter2Bit;

architecture Behavioral of Counter2Bit is
    signal counter: STD_LOGIC_VECTOR (1 downto 0) := "00";
begin
    process(clk, reset)
    begin
        if reset = '1' then
            counter <= "00";
        elsif rising_edge(clk) then
            counter <= counter + 1;
        end if;
    end process;
    
    count <= counter;
end Behavioral;