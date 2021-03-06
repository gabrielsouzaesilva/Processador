library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity processador is
	port ( processadorClk : in std_logic; -- clk geral
		   rstProcessador : in std_logic; -- Reset 
		   constante: in unsigned(15 downto 0); -- constante qualquer 
		   ULAout : out unsigned (15 downto 0); -- Saida ULA
		   estado_p: out unsigned(1 downto 0); -- Pino saida estado da maquina de estados
		   pcOut: out unsigned(15 downto 0); -- Pino saida PC
		   romOut: out unsigned(15 downto 0); -- Pino saida data ROM
		   bacnoRegOut_A: out unsigned(15 downto 0); -- Pino saida regA
		   bacnoRegOut_B: out unsigned(15 downto 0); -- Pino saida regB
		   ramOut:	out unsigned(15 downto 0) -- Pina saida RAM
		 );
end entity;

architecture a_processador of processador is
	component bancoReg is
		port( 	clk			: in std_logic; -- clock
		  		rst 		: in std_logic; -- reset
		  		write_en	: in std_logic;	-- write enable
		  		write_data 	: in unsigned(15 downto 0); -- valor a ser escrito em write_reg
		  		reg_sel_write : in unsigned(2 downto 0); -- registrador a ser escrito
		  		reg_sel_A: in unsigned(2 downto 0); -- entrada de dados
		  		reg_sel_B: in unsigned(2 downto 0); -- entrada de dados
		  		data_out_A: out unsigned(15 downto 0); -- saida de dados
		  		data_out_B: out unsigned(15 downto 0) -- saida de dados
			);
	end component;

	component ula is
		port( 	in_a : in unsigned(15 downto 0); -- entrada a 16 bits 
		  		in_b : in unsigned(15 downto 0); -- entrada b 16 bits 
		  		sel_op : in unsigned(2 downto 0); -- seletor para operação (3 bits)
		  		out_a : out unsigned(15	 downto 0) -- saida 16 bits 
		 	);
	end component;

	component pc is
		port (	clk : in std_logic;
				write_en : in std_logic;
				rst : in std_logic;
				data_in : in unsigned(15 downto 0);
				data_out : out unsigned(15 downto 0)
		);
	end component;

	component rom is
		port( 	clk : in std_logic;
			  	address : in unsigned(15 downto 0);
			  	data : out unsigned(15 downto 0)
			);
	end component;

	component maquinaEstados is
		port (	clk : in std_logic;
				rst : in std_logic;
				estado : out unsigned(1 downto 0)
			);
	end component;

	component ram is
		port(	clk		: in std_logic;
				address	: in unsigned(15 downto 0);
				write_en: in std_logic;
				data_in	: in unsigned(15 downto 0);
				data_out: out unsigned(15 downto 0)
		);
	end component;

	signal data_regB, data_regA, signal_write_data, ula_in_a,ula_in_b, data_in_pc, data_out_pc, data_rom_out: unsigned(15 downto 0);
	signal jump_address, bReg_in, regData_out, rel_address, data_out_ram, address_ram,writeReg_data: unsigned(15 downto 0);
	signal immediate: unsigned(6 downto 0);
	signal opcode: unsigned(5 downto 0);
	signal ALUOp_s, regWrite_s, regA_s, regB_s: unsigned(2 downto 0);
	signal estado_s,AluSrcB_s: unsigned(1 downto 0);
	signal writeReg_s, writePC_s, AluSrcA_s, jump_en, writeRAM_s: std_logic;

begin

	-- Unidades usadas:

	-- Banco de registradores
	registers: bancoReg port map (	clk => processadorClk,
								 	rst => rstProcessador,
								    write_en => writeReg_s, 
								    write_data => writeReg_data, 
								    reg_sel_write => regWrite_s,
								    reg_sel_A => regA_s,  
								    reg_sel_B => regB_s,
								    data_out_A => data_regA, -- saida banco reg => in_a ula
								    data_out_B => data_regB -- Vai para mux seleção entrada ULA_B
								    );

	-- ULA
	alu: ula port map ( in_a => ula_in_a , in_b => ula_in_b , sel_op => ALUOp_s, out_a => signal_write_data);

	-- PC
	pc_p: pc port map(clk => processadorClk, write_en => writePC_s, rst => rstProcessador, data_in => data_in_pc, data_out => data_out_pc);

	-- ROM
	rom_p: rom port map(clk => processadorClk, address => data_out_pc, data => data_rom_out);

	-- RAM
	ram_p: ram port map(clk => processadorClk, address=> address_ram, write_en => writeRAM_s, data_in => data_regB, data_out =>data_out_ram);

	-- Maquina de estados
	stateMachine: maquinaEstados port map(clk => processadorClk, rst => rstProcessador, estado => estado_s);

	-- Operações:

	-- Recebe opcode
	opcode <= data_rom_out(15 downto 10) when estado_s = "00"; 

	-- Prepara constante
	immediate <= data_rom_out(6 downto 0) when estado_s = "00";

	-- Escrita RAM
	writeRAM_s <= '1' when opcode = "011001" else
				  '0';

	-- Relative jump
	rel_address <= "000000000000" & data_rom_out(3 downto 0) when data_rom_out(3) = '0' and opcode = "001010" else
				   "111111111111" & data_rom_out(3 downto 0) when data_rom_out(3) = '1' and opcode = "001010" else
				   "000000000000" & data_rom_out(3 downto 0) when data_rom_out(3) = '0' and opcode = "001110" else
				   "111111111111" & data_rom_out(3 downto 0) when data_rom_out(3) = '1' and opcode = "001110";

	-- Prepara endereço de jump
	jump_address <= signal_write_data when opcode = "111111" else -- Recebe valor de jump absoluto
					data_out_pc + rel_address when opcode = "001010" or opcode = "001110"; -- Recebe valor de jump relativo (PC <= PC + signed(imm))

	-- Ativa jump
	jump_en <= '1' when opcode = "111111" else -- Ativa jump quando detecta a instrução de jump absoluto
			   '1' when opcode = "001010" and signal_write_data = "0000000000000001" else -- Ativa quando detecta salto em bgt
			   '1' when opcode = "001110" and signal_write_data = "0000000000000001" else -- Ativa quando detecta salto em beq
			   '0';

	--Mux seleciona a entrada A da ULA
	AluSrcA_s <=  '1' when opcode = "111110" else -- Recebe data_out_pc quando bCond
				  '0'; -- Outros casos recebe saida do bancoReg
				 
	-- Mux seleciona a entrada B da ULA
	AluSrcB_s <= "00" when opcode(5 downto 3) = "001" else -- Instruções 001uuu ULA
				 "10" when opcode(5 downto 3) = "011" else -- Acesso ram (AddressRAM + 0)
				 "00" when opcode = "010001" else -- Mov regA, regB
				 "01" when opcode = "010000" else -- Mov imm, regB
				 "01" when opcode = "010010" else -- Add imm, regB
				 "00" when opcode = "111111" else -- reg0 no jump
				 "01" when opcode = "111110" else -- imm no  bCond
 				 "00";

	-- Escolhe operação da ULA
	ALUOp_s <= opcode(2 downto 0) when opcode(5 downto 3) = "001" else -- Instruções da ULA
			   "000" when opcode = "010000" else -- Usar soma +0 quando for MOV IMM
			   "000" when opcode = "010001" else -- Usar soma +0 quando for MOV REG
			   "000" when opcode = "010010" else -- Usar soma quando for ADDI
			   "000" when opcode = "111111" else -- Usar soma +0 quando for jump
			   "000" when opcode = "111110" else -- Usar soma +0 quando for bCond
			   "000";

	-- Verifica qual registrador é lido na entrada A
	regA_s  <= data_rom_out(9 downto 7) when opcode(5 downto 3) = "001" else -- Instruções da ULA : regA
			   data_rom_out(9 downto 7) when opcode(5 downto 3) = "011" else -- Acesso RAM (address)
			   data_rom_out(9 downto 7) when opcode = "010001" else -- mov rA,rB (rB <= rA)
			   data_rom_out(9 downto 7) when opcode = "010010" else -- mov imm, rB (rB<=rB+imm)
			   data_rom_out(9 downto 7) when opcode = "111111" else -- jump
			   "000" when opcode = "010000" else -- mov imm, rB (rB<= imm + r0)
			   "000";

	-- Verifica qual registrador é lido na entrada B
	regB_s <= data_rom_out(6 downto 4) when opcode(5 downto 3) = "001" else  -- Instruções da ULA
			  data_rom_out(6 downto 4) when opcode = "011001" else -- st.w ra, RC
			  "000" when opcode = "010000" else -- mov imm, rB
			  "000" when opcode = "010001" else -- mov rA,rB
			  "000" when opcode = "010010" else -- add imm, rB
			  "000" when opcode = "111111" else -- jump
			  "000"; 

	-- Verifica qual registrador deve ser escrito
	regWrite_s <= data_rom_out(6 downto 4) when opcode(5 downto 3) = "001" and opcode(2 downto 0) /= "010"  and opcode(2 downto 0) /= "110" else -- Instruções ULA
				  data_rom_out(6 downto 4) when opcode = "010001" else -- mov rA,rB
				  data_rom_out(6 downto 4) when opcode = "011000" else -- sld.w rA, rB
				  data_rom_out(9 downto 7) when opcode = "010000" else -- mov imm, rB
				  data_rom_out(9 downto 7) when opcode = "010010" else -- add imm, rB
				  "000"; 

	-- Enable PC em "10"
	writePC_s <= '1' when estado_s = "10" else
				 '0';

	-- Executa jump ou PC+1
	data_in_pc  <= data_out_pc+1 when estado_s = "10" and jump_en = '0' else -- pc+1
				   jump_address when estado_s = "10" and jump_en = '1' else -- jump
				   data_out_pc;

	-- Mux entrada B da ULA
	ula_in_b <= data_regB when AluSrcB_s = "00" and estado_s = "01" else
				"000000000" & immediate when AluSrcB_s = "01" and immediate(6) = '0' and estado_s = "01" else -- Add immediate positivo
				"111111111" & immediate when AluSrcB_s = "01" and immediate(6) = '1' and estado_s = "01" else -- Add immediate negativo
				constante when AluSrcB_s = "10" and estado_s = "01";-- Constante externa = 0


	-- Mux entrada A da ULA
	ula_in_a <= data_out_pc when AluSrcA_s = '1' and estado_s = "01" else  -- Recebe saida PC
				data_regA when estado_s = "01"; -- Recebe o valor de um registrador

	-- Escreve no registrador
	writeReg_s <= '1' when estado_s = "10" and opcode = "001000" else
				  '1' when estado_s = "10" and opcode = "001001" else
				  '1' when estado_s = "10" and opcode = "001011" else
				  '1' when estado_s = "10" and opcode = "001100" else
				  '1' when estado_s = "10" and opcode = "001101" else
				  '1' when estado_s = "10" and opcode = "010000" else
				  '1' when estado_s = "10" and opcode = "010001" else
 				  '1' when estado_s = "10" and opcode = "010010" else
				  '0';



	-- Escrita na RAM
	address_ram <= data_regA when opcode = "011000" and estado_s = "01" else
				   data_regA when opcode = "011001" and estado_s = "01";

	-- Dado vem da RAM ou ULA
	writeReg_data <= data_out_ram when opcode = "011000" else
					 signal_write_data;

	-- Liga os pinos de saida

	ULAout <= signal_write_data;
	estado_p <= estado_s;
	pcOut <= data_out_pc;
	romOut <= data_rom_out;
	bacnoRegOut_B <= data_regB;
	bacnoRegOut_A <= data_regA;
	ramOut <= data_out_ram;


end architecture;