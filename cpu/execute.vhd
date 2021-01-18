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
      dec_microop_i   : in  std_logic_vector(3 downto 0);
      dec_opcode_i    : in  std_logic_vector(3 downto 0);
      reg_flags_i     : in  std_logic_vector(15 downto 0);
      reg_src_val_i   : in  std_logic_vector(15 downto 0);
      reg_dst_val_i   : in  std_logic_vector(15 downto 0);
      reg_addr_i      : in  std_logic_vector(3 downto 0);
      mem_addr_i      : in  std_logic_vector(15 downto 0);

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
      reg_flags_we_o  : out std_logic;
      reg_flags_o     : out std_logic_vector(15 downto 0);
      reg_we_o        : out std_logic;
      reg_addr_o      : out std_logic_vector(3 downto 0);
      reg_val_o       : out std_logic_vector(15 downto 0)
   );
end entity execute;

architecture synthesis of execute is

   constant C_MEM_READ_SRC : integer := 3;
   constant C_MEM_READ_DST : integer := 2;
   constant C_MEM_WRITE    : integer := 1;
   constant C_REG_WRITE    : integer := 0;

   -- ALU
   signal alu_oper         : std_logic_vector(3 downto 0);
   signal alu_flags        : std_logic_vector(15 downto 0);
   signal alu_src_val      : std_logic_vector(15 downto 0);
   signal alu_dst_val      : std_logic_vector(15 downto 0);
   signal alu_res_val      : std_logic_vector(15 downto 0);
   signal alu_res_flags    : std_logic_vector(15 downto 0);

   signal mem_src_val : std_logic_vector(15 downto 0) := (others => '0');
   signal mem_dst_val : std_logic_vector(15 downto 0) := (others => '0');

begin

   dec_ready_o   <= not wb_stall_i;
   alu_oper      <= dec_opcode_i;
   alu_flags     <= reg_flags_i;
   alu_src_val   <= mem_src_val when dec_microop_i(C_MEM_READ_SRC) = '1' else reg_src_val_i;
   alu_dst_val   <= mem_dst_val when dec_microop_i(C_MEM_READ_DST) = '1' else reg_dst_val_i;

   reg_flags_o    <= alu_res_flags;
   reg_flags_we_o <= '1';

   p_microop : process (clk_i)
   begin
      if rising_edge(clk_i) then
         reg_we_o   <= '0';
         reg_addr_o <= (others => '0');
         reg_val_o  <= (others => '0');

         if wb_stall_i = '0' then
            wb_stb_o  <= '0';
            wb_we_o   <= '0';
            wb_addr_o <= (others => '0');
            wb_dat_o  <= (others => '0');
         end if;

         if wb_ack_i = '1' then
            wb_cyc_o  <= '0';
            wb_stb_o  <= '0';
            wb_we_o   <= '0';
            wb_addr_o <= (others => '0');
            wb_dat_o  <= (others => '0');
         end if;

         if dec_valid_i = '1' and dec_ready_o = '1' then
            if dec_microop_i(C_MEM_READ_SRC) = '1' then
               wb_cyc_o  <= '1';
               wb_stb_o  <= '1';
               wb_addr_o <= mem_addr_i;
               wb_we_o   <= '0';
               wb_dat_o  <= (others => '0');
            end if;

            if dec_microop_i(C_MEM_READ_DST) = '1' then
               wb_cyc_o  <= '1';
               wb_stb_o  <= '1';
               wb_addr_o <= mem_addr_i;
               wb_we_o   <= '0';
               wb_dat_o  <= (others => '0');
            end if;

            if dec_microop_i(C_MEM_WRITE) = '1' then
               wb_cyc_o  <= '1';
               wb_stb_o  <= '1';
               wb_addr_o <= mem_addr_i;
               wb_we_o   <= '1';
               wb_dat_o  <= alu_res_val;
            end if;

            if dec_microop_i(C_REG_WRITE)    = '1' and
               dec_microop_i(C_MEM_READ_SRC) = '0' and
               dec_microop_i(C_MEM_READ_DST) = '0'
            then
               reg_we_o   <= '1';
               reg_addr_o <= reg_addr_i;
               reg_val_o  <= alu_res_val;
            end if;
         end if;

         if wb_ack_i = '1' then
            if dec_microop_i(C_MEM_READ_SRC) = '1' then
               mem_src_val <= wb_data_i;
            end if;

            if dec_microop_i(C_MEM_READ_DST) = '1' then
               mem_dst_val <= wb_data_i;
            end if;

            if dec_microop_i(C_REG_WRITE) = '1' then
               reg_we_o   <= '1';
               reg_addr_o <= reg_addr_i;
               reg_val_o  <= alu_res_val;
            end if;
         end if;

         if rst_i = '1' then
            wb_cyc_o  <= '0';
            wb_stb_o  <= '0';
            wb_addr_o <= (others => '0');
            wb_we_o   <= '0';
            wb_dat_o  <= (others => '0');
         end if;
      end if;
   end process p_microop;

   i_alu : entity work.alu
      port map (
         clk_i       => clk_i,
         rst_i       => rst_i,
         opcode_i    => alu_oper,
         sr_i        => alu_flags,
         src_data_i  => alu_src_val,
         dst_data_i  => alu_dst_val,
         res_data_o  => alu_res_val,
         sr_o        => alu_res_flags
      ); -- i_alu

end architecture synthesis;

