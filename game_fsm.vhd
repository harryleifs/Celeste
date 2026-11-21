--------------------------------------------------------------------------------
-- Proyecto Final - Diseño de Sistemas Digitales (Mini videojuego estilo Celeste)
-- Archivo : game_fsm.vhd
-- Funcion : FSM principal del juego (MENU, JUEGO, PAUSA, VICTORIA, GAME OVER) y
--           contador de vidas. FSM de 2 procesos (estilo del curso).
--           state_code: 000 menu | 001 juego | 010 pausa | 011 victoria | 100 game over
-- Librerias: ieee.std_logic_1164, ieee.numeric_std
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
--------------------------------------------------------------------------------
ENTITY game_fsm IS
   GENERIC ( START_LIVES : INTEGER := 3 );
   PORT (    clk        : IN  STD_LOGIC;
             rst        : IN  STD_LOGIC;
             start_p    : IN  STD_LOGIC;                      -- pulso del boton Start
             goal_ev    : IN  STD_LOGIC;                      -- el jugador toco la meta
             dead_ev    : IN  STD_LOGIC;                      -- el jugador murio
             run_en     : OUT STD_LOGIC;                      -- 1 mientras se juega
             init       : OUT STD_LOGIC;                      -- pulso: nueva partida
             state_code : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
             lives      : OUT STD_LOGIC_VECTOR(3 DOWNTO 0) );
END ENTITY game_fsm;
--------------------------------------------------------------------------------
ARCHITECTURE rtl OF game_fsm IS
   TYPE state IS (st_menu, st_play, st_pause, st_win, st_over);
   SIGNAL pr_state, nx_state : state;
   SIGNAL init_s  : STD_LOGIC;
   SIGNAL lives_s : INTEGER RANGE 0 TO 9;
BEGIN
   -------------------------------------------------------- Sequential section
   sequential : PROCESS (rst, clk)
   BEGIN
      IF (rst = '1') THEN
         pr_state <= st_menu;
      ELSIF (rising_edge(clk)) THEN
         pr_state <= nx_state;
      END IF;
   END PROCESS sequential;

   ------------------------------------------------------ Combinational section
   combinational : PROCESS (pr_state, start_p, goal_ev, lives_s)
   BEGIN
      CASE pr_state IS
         WHEN st_menu =>
            run_en     <= '0';
            state_code <= "000";
            IF (start_p = '1') THEN
               init_s   <= '1';
               nx_state <= st_play;
            ELSE
               init_s   <= '0';
               nx_state <= st_menu;
            END IF;
         WHEN st_play =>
            run_en     <= '1';
            state_code <= "001";
            init_s     <= '0';
            IF (goal_ev = '1') THEN
               nx_state <= st_win;
            ELSIF (lives_s = 0) THEN
               nx_state <= st_over;
            ELSIF (start_p = '1') THEN
               nx_state <= st_pause;
            ELSE
               nx_state <= st_play;
            END IF;
         WHEN st_pause =>
            run_en     <= '0';
            state_code <= "010";
            init_s     <= '0';
            IF (start_p = '1') THEN
               nx_state <= st_play;
            ELSE
               nx_state <= st_pause;
            END IF;
         WHEN st_win =>
            run_en     <= '0';
            state_code <= "011";
            init_s     <= '0';
            IF (start_p = '1') THEN
               nx_state <= st_menu;
            ELSE
               nx_state <= st_win;
            END IF;
         WHEN st_over =>
            run_en     <= '0';
            state_code <= "100";
            init_s     <= '0';
            IF (start_p = '1') THEN
               nx_state <= st_menu;
            ELSE
               nx_state <= st_over;
            END IF;
      END CASE;
   END PROCESS combinational;

   init <= init_s;

   ---------------------------------------------------------- Contador de vidas
   lives_counter : PROCESS (clk, rst)
   BEGIN
      IF (rst = '1') THEN
         lives_s <= START_LIVES;
      ELSIF (rising_edge(clk)) THEN
         IF (init_s = '1') THEN
            lives_s <= START_LIVES;
         ELSIF (dead_ev = '1' AND pr_state = st_play AND lives_s /= 0) THEN
            lives_s <= lives_s - 1;
         END IF;
      END IF;
   END PROCESS lives_counter;

   lives <= STD_LOGIC_VECTOR(to_unsigned(lives_s, 4));
END ARCHITECTURE rtl;