LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY bcd_counter IS
   GENERIC ( LIMIT : INTEGER := 9 );
   PORT (    clk      : IN  STD_LOGIC;
             rst      : IN  STD_LOGIC;
             syn_clr  : IN  STD_LOGIC;
             ena      : IN  STD_LOGIC;
             bcd      : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
             max_tick : OUT STD_LOGIC );
END ENTITY bcd_counter;

ARCHITECTURE rtl OF bcd_counter IS
   SIGNAL count_s : INTEGER RANGE 0 TO LIMIT;
BEGIN
   counter : PROCESS (clk, rst)
   BEGIN
      IF (rst = '1') THEN
         count_s <= 0;
      ELSIF (rising_edge(clk)) THEN
         IF (syn_clr = '1') THEN
            count_s <= 0;
         ELSIF (ena = '1') THEN
            IF (count_s = LIMIT) THEN
               count_s <= 0;
            ELSE
               count_s <= count_s + 1;
            END IF;
         END IF;
      END IF;
   END PROCESS counter;

   bcd      <= STD_LOGIC_VECTOR(to_unsigned(count_s, 4));
   max_tick <= '1' WHEN (count_s = LIMIT) ELSE '0';
END ARCHITECTURE rtl;
