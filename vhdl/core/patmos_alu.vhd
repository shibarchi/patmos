-- 
-- Copyright Technical University of Denmark. All rights reserved.
-- This file is part of the time-predictable VLIW Patmos.
-- 
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
-- 
--    1. Redistributions of source code must retain the above copyright notice,
--       this list of conditions and the following disclaimer.
-- 
--    2. Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
-- 
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER ``AS IS'' AND ANY EXPRESS
-- OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
-- OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN
-- NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
-- THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
-- 
-- The views and conclusions contained in the software and documentation are
-- those of the authors and should not be interpreted as representing official
-- policies, either expressed or implied, of the copyright holder.
-- 


--------------------------------------------------------------------------------
-- Short descripton.
--
-- Author: Sahar Abbaspour
-- Author: Martin Schoeberl (martin@jopdesign.com)
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.patmos_type_package.all;

entity patmos_alu is
	port(
		clk										: in  std_logic;
		rst										: in  std_logic;
		decdout									: in  decode_out_type;
		din										: in  alu_in_type;
		doutex									: out execution_out_type;
		memdout									: in mem_out_type
		
	);
end entity patmos_alu;

architecture arch of patmos_alu is

	signal rd, adrs								: std_logic_vector(31 downto 0);
	signal cmp_equal, cmp_result				: std_logic;
	signal predicate, predicate_reg				: std_logic_vector(7 downto 0);
	signal rs1, rs2								: unsigned(31 downto 0);
	signal doutex_alu_result_out				: std_logic_vector(31 downto 0);
	signal doutex_alu_adrs_out					: std_logic_vector(31 downto 0);
	signal doutex_write_back_reg_out			: std_logic_vector(4 downto 0);
	signal doutex_reg_write_out					: std_logic;
	signal din_rs1, din_rs2, alu_src2			: std_logic_vector(31 downto 0);
	signal shamt 								: integer;
	signal shifted_arg							: unsigned(31 downto 0);
begin


	-- we should assign default values;
	process(din_rs1, din_rs2)
	begin
		rs1 <= unsigned(din_rs1);
		rs2 <= unsigned(din_rs2);
	end process;
	
	
	patmos_address_shamt: process(din)
	begin
		case din.adrs_type is
			when word => 
				shamt <= 2;
			when half =>
				shamt <= 1;
			when byte =>
				shamt <= 0;
			when others => null;
		end case;
	end process;
	patmos_address_shift: process(shamt, rs2)
	begin
		shifted_arg <= SHIFT_LEFT(rs2, shamt);
	end process;
	patmos_address: process(rs1, rs2, shifted_arg)
	begin 
		adrs <= std_logic_vector(rs1 + shifted_arg);
	end process;
	
	patmos_predicate: process(din, decdout, predicate, predicate_reg, cmp_result)
	begin
		predicate  <= predicate_reg;
		if (din.is_predicate_inst = '1') then 
			case din.pat_function_type is
				when pat_por => predicate(to_integer(unsigned(decdout.pd_out(2 downto 0)))) <= 					
								(decdout.ps1_out(3) xor predicate_reg(to_integer(unsigned(decdout.ps1_out(2 downto 0)))) ) or 
								(decdout.ps2_out(3) xor predicate_reg(to_integer(unsigned(decdout.ps2_out(2 downto 0)))));
						
				when pat_pand => predicate(to_integer(unsigned(decdout.pd_out(2 downto 0)))) <=
								(decdout.ps1_out(3) xor predicate_reg(to_integer(unsigned(decdout.ps1_out(2 downto 0)))) ) and 
								(decdout.ps2_out(3) xor predicate_reg(to_integer(unsigned(decdout.ps2_out(2 downto 0)))));
						
				when pat_pxor =>  predicate(to_integer(unsigned(decdout.pd_out(2 downto 0)))) <= 
								(decdout.ps1_out(3) xor predicate_reg(to_integer(unsigned(decdout.ps1_out(2 downto 0)))) ) xor 
								(decdout.ps2_out(3) xor predicate_reg(to_integer(unsigned(decdout.ps2_out(2 downto 0)))));
						
				when pat_pnor =>  predicate(to_integer(unsigned(decdout.pd_out(2 downto 0)))) <=
										not ((decdout.ps1_out(3) xor predicate_reg(to_integer(unsigned(decdout.ps1_out(2 downto 0)))) ) or 
											(decdout.ps2_out(3) xor predicate_reg(to_integer(unsigned(decdout.ps2_out(2 downto 0)))))); --nor
				when others =>  predicate(to_integer(unsigned(decdout.pd_out(2 downto 0)))) <= '0';
			end case;
		end if;
		if decdout.instr_cmp='1' then
			predicate(to_integer(unsigned(decdout.pd_out(2 downto 0)))) <= cmp_result;
		end if;
		-- the ever true predicate
		predicate(0) <= '1';
	end process;
	
	patmos_alu: process(din, rs1, rs2) -- ALU
	begin 
		rd <= "00000000000000000000000000000000";
		case din.pat_function_type is
			when pat_add => rd <= std_logic_vector(rs1 + rs2); --add
			when pat_sub => rd <= std_logic_vector(rs1 - rs2); --sub
			when pat_rsub => rd <= std_logic_vector(rs2 - rs1); -- sub invert
			when pat_sl => rd <= std_logic_vector(SHIFT_LEFT(rs1, to_integer(rs2(4 downto 0)))); --sl
			when pat_sr => rd <= std_logic_vector(SHIFT_RIGHT(rs1, to_integer(rs2(4 downto 0)))); -- sr
			when pat_sra => rd <= std_logic_vector(SHIFT_RIGHT(signed(rs1), to_integer(rs2(4 downto 0)))); -- sra
			when pat_or => rd <= std_logic_vector(rs1 or rs2); -- or
			when pat_and => rd <= std_logic_vector(rs1 and rs2); -- and
						-----
			when pat_rl => rd <= std_logic_vector(ROTATE_LEFT(rs1, to_integer(rs2(4 downto 0))));-- rl
			when pat_rr => rd <= std_logic_vector(ROTATE_RIGHT(rs1, to_integer(rs2(4 downto 0))));
			when pat_xor => rd <= std_logic_vector(rs2 xor rs1);
			when pat_nor => rd <= std_logic_vector(rs1 nor rs2);
			when pat_shadd => rd <= std_logic_vector(SHIFT_LEFT(rs1, 1) + rs2);
			when pat_shadd2 => rd <= std_logic_vector(SHIFT_LEFT(rs1, 2) + rs2);
			when pat_sext8 => rd <= std_logic_vector(rs1(7) & rs1(7) & rs1(7) & rs1(7) & rs1(7) & rs1(7) & rs1(7) & rs1(7) & rs1(7) & rs1(7) & rs1(7) & rs1(7) & rs1(7) & rs1(7) & rs1(7) & rs1(7) & rs1(7) & rs1(7) &
									rs1(7) & rs1(7) & rs1(7) & rs1(7) & rs1(7) & rs1(7) & rs1(7 downto 0));
			when pat_sext16 => rd <= std_logic_vector(rs1(15) & rs1(15) & rs1(15) & rs1(15) & rs1(15) & rs1(15) & rs1(15) & rs1(15) & rs1(15) & rs1(15) & rs1(15) & rs1(15) & rs1(15) & rs1(15) & rs1(15) & rs1(15) & rs1(15 downto 0));
			when pat_zext16 => rd <= std_logic_vector("0000000000000000" & rs1(15 downto 0));
			when pat_abs => rd <= std_logic_vector(abs(signed(rs1)));
			when others => rd <= std_logic_vector(rs1 + rs2); -- default add! 
		end case;
	end process;
	
	patmos_compare: process(decdout, cmp_equal, cmp_result, rs1, rs2)
	begin
		cmp_equal <= '0';
		cmp_result <= '0';
		if signed(rs1) = signed(rs2) then
			cmp_equal <= '1';
		end if;
	--	if din.inst_type = ALUp then
		case decdout.ALU_function_type_out(2 downto 0) is
			when "000" => cmp_result <= cmp_equal;
			when "001" => cmp_result <= not cmp_equal;
			when "010" =>  if (signed(rs1) < signed(rs2) ) then cmp_result <= '1'; else cmp_result <= '0' ; end if;
			when "011" =>  if (signed(rs1) <= signed(rs2) ) then cmp_result <= '1'; else cmp_result <= '0' ; end if;
			when "100" =>  if (rs1 < rs2 ) then cmp_result <= '1'; else cmp_result <= '0' ; end if;
			when "101" =>  if (rs1 <= rs2 ) then cmp_result <= '1'; else cmp_result <= '0' ; end if;
			when "110" =>  if (rs1(to_integer(rs2(4 downto 0))) = '1') then cmp_result <= '1'; else cmp_result <= '0' ; end if;
			when others => null;
		end case;
	--	end if;
	end process;
	
	
	process(rd, adrs)
	begin
		doutex.alu_result <= rd;
		doutex.adrs <= adrs;
	end process;
	-- TODO: remove all predicate related stuff from EX out  
	process(rst, clk)
	begin
		if rst = '1' then
			predicate_reg <= "00000001";
			doutex.predicate <= "00000001";
		elsif rising_edge(clk) then
			if predicate_reg(to_integer(unsigned(decdout.predicate_condition))) /= decdout.predicate_bit_out then
				doutex.mem_read_out  <= decdout.mem_read_out;
				doutex.mem_write_out <= decdout.mem_write_out;
				doutex.lm_read_out              <= decdout.lm_read_out;
				doutex.lm_write_out              <= decdout.lm_write_out;
				doutex.reg_write_out <= decdout.reg_write_out;
				
				doutex_reg_write_out <= decdout.reg_write_out;
			--      	doutex.ps_reg_write_out <= decdout.ps_reg_write_out;
			--	test <= '1';
			else
				doutex.mem_read_out     <= '0';
				doutex.mem_write_out    <= '0';
				doutex.lm_read_out              <= '0';
				doutex.lm_write_out              <= '0';
				doutex.reg_write_out    <= '0';
				doutex_reg_write_out <= '0';
			end if;

			doutex.mem_to_reg_out           <= decdout.mem_to_reg_out;
			doutex.alu_result_out           <= rd;
			doutex.adrs_out		      	  <= adrs;
			doutex.write_back_reg_out       <= decdout.rd_out;
			doutex.STT_instruction_type_out <= decdout.STT_instruction_type_out;
			doutex.LDT_instruction_type_out <= decdout.LDT_instruction_type_out;
			-- this should be under predicate condition as well
			doutex.predicate                <= predicate;
			predicate_reg                   <= predicate;
			

			doutex_alu_result_out           <= rd;
			doutex_alu_adrs_out           <= adrs;
			doutex_write_back_reg_out       <= decdout.rd_out;
			
			
		end if;
	end process;
	
	not_registered_out: process(decdout, alu_src2)
	begin
		if predicate_reg(to_integer(unsigned(decdout.predicate_condition))) /= decdout.predicate_bit_out then
				doutex.lm_read_out_not_reg              <= decdout.lm_read_out;
				doutex.lm_write_out_not_reg              <= decdout.lm_write_out;
		else
				doutex.lm_read_out_not_reg              <= '0';
				doutex.lm_write_out_not_reg              <= '0';
		end if;
		doutex.mem_write_data <= alu_src2;
	end process not_registered_out;
	
	forwarding_rs1 : process(doutex_alu_result_out, doutex_write_back_reg_out, doutex_reg_write_out , decdout, memdout)
	begin
		if (decdout.rs1_out = doutex_write_back_reg_out and doutex_reg_write_out = '1' ) then
			din_rs1 <= doutex_alu_result_out;
		elsif (decdout.rs1_out = memdout.write_back_reg_out and memdout.reg_write_out = '1' ) then
			din_rs1 <= memdout.data_out;
		else
			din_rs1 <= decdout.rs1_data_out;
		end if;
	end process forwarding_rs1;
	
	forwarding_rs2 : process(doutex_alu_result_out, doutex_write_back_reg_out, doutex_reg_write_out , decdout, memdout)
	begin
		if (decdout.rs2_out = doutex_write_back_reg_out and doutex_reg_write_out = '1' ) then
			alu_src2 <= doutex_alu_result_out;
		elsif (decdout.rs2_out = memdout.write_back_reg_out and memdout.reg_write_out = '1' ) then
			alu_src2 <= memdout.data_out;
		else
			alu_src2 <= decdout.rs2_data_out;
		end if;
	end process forwarding_rs2;


	process(alu_src2, decdout.ALUi_immediate_out, decdout.alu_src_out)
	begin
		if (decdout.alu_src_out = '0') then
			din_rs2 <= alu_src2;
		else
			din_rs2 <= decdout.ALUi_immediate_out;
		end if;
	end process;
	
	

end arch;




