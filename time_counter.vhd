LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY time_counter IS
   GENERIC ( FRAMES_PER_SEC : INTEGER := 60 );
   PORT (    clk        : IN  STD_LOGIC;
             rst        : IN  STD_LOGIC;
             clr        : IN  STD_LOGIC;                      -- reinicia el tiempo
             ena        : IN  STD_LOGIC;                      -- 1 mientras se juega
             frame_tick : IN  STD_LOGIC;                      -- 1 pulso por cuadro
             sec_u      : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);   -- unidades
             sec_t      : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);   -- decenas
             sec_h      : OUT STD_LOGIC_VECTOR(3 DOWNTO 0) ); -- centenas
END ENTITY time_counter;

ARCHITECTURE rtl OF time_counter IS
   SIGNAL frame_cnt : INTEGER RANGE 0 TO FRAMES_PER_SEC - 1;
   SIGNAL sec_tick  : STD_LOGIC;
   SIGNAL max_u     : STD_LOGIC;
   SIGNAL max_t     : STD_LOGIC;
   SIGNAL max_h     : STD_LOGIC;
   SIGNAL ena_t     : STD_LOGIC;
   SIGNAL ena_h     : STD_LOGIC;
BEGIN

   frame_divider : PROCESS (clk, rst)
   BEGIN
      IF (rst = '1') THEN
         frame_cnt <= 0;
         sec_tick  <= '0';
      ELSIF (rising_edge(clk)) THEN
         sec_tick <= '0';
         IF (clr = '1') THEN
            frame_cnt <= 0;
         ELSIF (ena = '1' AND frame_tick = '1') THEN
            IF (frame_cnt = FRAMES_PER_SEC - 1) THEN
               frame_cnt <= 0;
               sec_tick  <= '1';
            ELSE
               frame_cnt <= frame_cnt + 1;
            END IF;
         END IF;
      END IF;
   END PROCESS frame_divider;

   ena_t <= sec_tick AND max_u;
   ena_h <= sec_tick AND max_u AND max_t;

   -- DIGITOS BCD
   units_digit : ENTITY work.bcd_counter
      GENERIC MAP ( LIMIT => 9 )
      PORT MAP ( clk => clk, rst => rst, syn_clr => clr, ena => sec_tick,
                 bcd => sec_u, max_tick => max_u );

   tens_digit : ENTITY work.bcd_counter
      GENERIC MAP ( LIMIT => 9 )
      PORT MAP ( clk => clk, rst => rst, syn_clr => clr, ena => ena_t,
                 bcd => sec_t, max_tick => max_t );

   hundreds_digit : ENTITY work.bcd_counter
      GENERIC MAP ( LIMIT => 9 )
      PORT MAP ( clk => clk, rst => rst, syn_clr => clr, ena => ena_h,
                 bcd => sec_h, max_tick => max_h );
END ARCHITECTURE rtl;
