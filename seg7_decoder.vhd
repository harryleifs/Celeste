LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY seg7_decoder IS
   GENERIC ( ACTIVE_LOW : BOOLEAN := TRUE );
   PORT (    bcd : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
             seg : OUT STD_LOGIC_VECTOR(6 DOWNTO 0) );
END ENTITY seg7_decoder;

ARCHITECTURE rtl OF seg7_decoder IS
   SIGNAL code : STD_LOGIC_VECTOR(6 DOWNTO 0);     
BEGIN
   decode : PROCESS (bcd)
   BEGIN
      CASE bcd IS
         WHEN "0000" => code <= "1000000";   -- 0
         WHEN "0001" => code <= "1111001";   -- 1
         WHEN "0010" => code <= "0100100";   -- 2
         WHEN "0011" => code <= "0110000";   -- 3
         WHEN "0100" => code <= "0011001";   -- 4
         WHEN "0101" => code <= "0010010";   -- 5
         WHEN "0110" => code <= "0000010";   -- 6
         WHEN "0111" => code <= "1111000";   -- 7
         WHEN "1000" => code <= "0000000";   -- 8
         WHEN "1001" => code <= "0010000";   -- 9
         WHEN OTHERS => code <= "1111111";   -- apagado
      END CASE;
   END PROCESS decode;

   seg <= code WHEN ACTIVE_LOW ELSE NOT code;
END ARCHITECTURE rtl;
