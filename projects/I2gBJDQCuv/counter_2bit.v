library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity counter_2bit is
    Port (
        clk     : in  STD_LOGIC;
        rst     : in  STD_LOGIC;
        count   : out STD_LOGIC_VECTOR (1 downto 0)
    );
end counter_2bit;

architecture Behavioral of counter_2bit is
    signal count_reg : STD_LOGIC_VECTOR (1 downto 0) := "00";
begin
    process(clk, rst)
    begin
        if rst = '1' then
            count_reg <= "00";
        elsif rising_edge(clk) then
            count_reg <= count_reg + 1;
        end if;
    end process;
    count <= count_reg;
end Behavioral;