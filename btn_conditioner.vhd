LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY btn_conditioner IS
   GENERIC ( DEBOUNCE_CYCLES : INTEGER := 500000;   -- 10 ms a 50 MHz
             ACTIVE_LOW      : BOOLEAN := TRUE );   
   PORT (    clk       : IN  STD_LOGIC;
             rst       : IN  STD_LOGIC;
             btn_in    : IN  STD_LOGIC;            
             btn_level : OUT STD_LOGIC;            
             btn_pulse : OUT STD_LOGIC );          
END ENTITY btn_conditioner;

ARCHITECTURE rtl OF btn_conditioner IS
   SIGNAL raw      : STD_LOGIC;
   SIGNAL sync_1   : STD_LOGIC;
   SIGNAL sync_2   : STD_LOGIC;
   SIGNAL stable   : STD_LOGIC;
   SIGNAL stable_d : STD_LOGIC;
   SIGNAL cnt      : INTEGER RANGE 0 TO DEBOUNCE_CYCLES;
BEGIN

   raw <= (NOT btn_in) WHEN ACTIVE_LOW ELSE btn_in;


   synchronizer : PROCESS (clk, rst)
   BEGIN
      IF (rst = '1') THEN
         sync_1 <= '0';
         sync_2 <= '0';
      ELSIF (rising_edge(clk)) THEN
         sync_1 <= raw;
         sync_2 <= sync_1;
      END IF;
   END PROCESS synchronizer;


   debounce : PROCESS (clk, rst)
   BEGIN
      IF (rst = '1') THEN
         stable <= '0';
         cnt    <= 0;
      ELSIF (rising_edge(clk)) THEN
         IF (sync_2 = stable) THEN
            cnt <= 0;
         ELSIF (cnt = DEBOUNCE_CYCLES - 1) THEN
            stable <= sync_2;
            cnt    <= 0;
         ELSE
            cnt <= cnt + 1;
         END IF;
      END IF;
   END PROCESS debounce;


   edge_detect : PROCESS (clk, rst)
   BEGIN
      IF (rst = '1') THEN
         stable_d <= '0';
      ELSIF (rising_edge(clk)) THEN
         stable_d <= stable;
      END IF;
   END PROCESS edge_detect;

   btn_level <= stable;
   btn_pulse <= stable AND (NOT stable_d);
END ARCHITECTURE rtl;
