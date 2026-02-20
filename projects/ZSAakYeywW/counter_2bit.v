library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity counter_2bit is
    Port ( clk : in STD_LOGIC;
           rst : in STD_LOGIC;
           count : out STD_LOGIC_VECTOR (1 downto 0));
end counter_2bit;

architecture Behavioral of counter_2bit is
    signal cnt : STD_LOGIC_VECTOR (1 downto 0) := "00";
begin
    process(clk, rst)
    begin
        if rst = '1' then
            cnt <= "00";
        elsif rising_edge(clk) then
            cnt <= cnt + 1;
        end if;
    end process;
    count <= cnt;
end Behavioral;