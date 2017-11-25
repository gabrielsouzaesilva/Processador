library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity maquinaEstados_tb is
end entity;

architecture a_maquinaEstados_tb of maquinaEstados_tb is
	component maquinaEstados
	port (	clk : in std_logic;
			rst : in std_logic;
			estado : out unsigned(1 downto 0)
		 );
	end component;

	signal clk, rst: std_logic;
	signal estado: unsigned(1 downto 0);

	begin
		uut: maquinaEstados port map (clk => clk, rst => rst, estado => estado);

	process
	begin 
		clk <= '0';
		wait for 50 ns;
		clk <= '1';
		wait for 50 ns;
	end process;

	process
	begin
		rst <= '1';
		wait for 10 ns;
		rst <= '0';
		wait for 10 ns;
		wait;
	end process;
end architecture;