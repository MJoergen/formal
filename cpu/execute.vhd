library ieee;
use ieee.std_logic_1164.all;

-- Read src and dst register values and pass on to next stage
-- Split out microops:
-- * MEM_READ_SRC : Read source operand from memory
-- * MEM_READ_DST : Read destination operand from memory
-- * MEM_WRITE : Write result to memory
-- * REG_WRITE : Write result to register
-- Other information passed on is:
-- * OPCODE
-- * Source register value
-- * Destination register value

-- Nearly all instructions update the status register (R14).

entity execute is
   port (
      clk_i           : in  std_logic;
      rst_i           : in  std_logic;

      -- From decode
      dec_valid_i     : in  std_logic;
      dec_ready_o     : out std_logic;
      dec_microop_i   : in  std_logic_vector(1 downto 0);
      dec_opcode_i    : in  std_logic_vector(3 downto 0);
      reg_flags_i     : in  std_logic_vector(15 downto 0);
      reg_src_val_i   : in  std_logic_vector(15 downto 0);
      reg_dst_val_i   : in  std_logic_vector(15 downto 0);
      reg_addr_i      : in  std_logic_vector(3 downto 0);
      mem_addr_i      : in  std_logic_vector(15 downto 0);

      -- ALU
      alu_oper_o      : out std_logic_vector(3 downto 0);
      alu_flags_o     : out std_logic_vector(15 downto 0);
      alu_src_val_o   : out std_logic_vector(15 downto 0);
      alu_dst_val_o   : out std_logic_vector(15 downto 0);
      alu_res_val_i   : in  std_logic_vector(15 downto 0);
      alu_res_flags_i : in  std_logic_vector(15 downto 0);

      -- Memory
      wb_cyc_o        : out std_logic;
      wb_stb_o        : out std_logic;
      wb_stall_i      : in  std_logic;
      wb_addr_o       : out std_logic_vector(15 downto 0);
      wb_we_o         : out std_logic;
      wb_dat_o        : out std_logic_vector(15 downto 0);
      wb_ack_i        : in  std_logic;
      wb_data_i       : in  std_logic_vector(15 downto 0);

      -- Register file
      reg_we_o        : out std_logic;
      reg_addr_o      : out std_logic_vector(3 downto 0);
      reg_val_o       : out std_logic_vector(15 downto 0)
   );
end entity execute;

architecture synthesis of execute is

   constant C_MICRO_MEM_READ_SRC : std_logic_vector(1 downto 0) := "00";
   constant C_MICRO_MEM_READ_DST : std_logic_vector(1 downto 0) := "01";
   constant C_MICRO_MEM_WRITE    : std_logic_vector(1 downto 0) := "10";
   constant C_MICRO_REG_WRITE    : std_logic_vector(1 downto 0) := "11";

begin

   dec_ready_o <= not wb_stall_i;
   alu_oper_o  <= dec_opcode_i;
   alu_flags_o <= reg_flags_i;

   p_microop : process (clk_i)
   begin
      if rising_edge(clk_i) then
         reg_we_o   <= '0';
         reg_addr_o <= (others => '0');
         reg_val_o  <= (others => '0');

         if wb_stall_i = '0' then
            wb_stb_o <= '0';
         end if;

         if dec_valid_i = '1' and dec_ready_o = '1' then
            case dec_microop_i is
               when C_MICRO_MEM_READ_SRC => 
                  wb_cyc_o  <= '1';
                  wb_stb_o  <= '1';
                  wb_addr_o <= mem_addr_i;
                  wb_we_o   <= '0';
                  wb_dat_o  <= (others => '0');

               when C_MICRO_MEM_READ_DST => 
                  wb_cyc_o  <= '1';
                  wb_stb_o  <= '1';
                  wb_addr_o <= mem_addr_i;
                  wb_we_o   <= '0';
                  wb_dat_o  <= (others => '0');

               when C_MICRO_MEM_WRITE => 
                  wb_cyc_o  <= '1';
                  wb_stb_o  <= '1';
                  wb_addr_o <= mem_addr_i;
                  wb_we_o   <= '1';
                  wb_dat_o  <= alu_res_val_i;

               when C_MICRO_REG_WRITE => 
                  reg_we_o   <= '1';
                  reg_addr_o <= reg_addr_i;
                  reg_val_o  <= alu_res_val_i;

               when others =>
                  null;

            end case;
         end if;

         if wb_ack_i = '1' then
            case dec_microop_i is
               when C_MICRO_MEM_READ_SRC => alu_src_val_o <= wb_data_i;
               when C_MICRO_MEM_READ_DST => alu_dst_val_o <= wb_data_i;
               when others => null;
            end case;
         end if;
      end if;
   end process p_microop;

end architecture synthesis;

