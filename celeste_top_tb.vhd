--------------------------------------------------------------------------------
-- Proyecto Final - Diseño de Sistemas Digitales
-- Mini videojuego de plataformas estilo "Celeste" - Terasic DE0 (Cyclone III)
--
-- Archivo : celeste_top_tb.vhd   (TESTBENCH GENERAL DEL PROYECTO)
--
-- Instancia 4 veces el top (DUT) con distintos GENERIC y un estimulo propio:
--
--   DUT A (VGA acelerado)  : mecanicas del personaje y del juego
--        menu -> juego, caminar, salto, doble salto (y 3er salto ignorado),
--        agacharse, dash en el suelo y en el aire (1 por salto, se recarga),
--        pausa (el cronometro se congela), 3 muertes por el foso -> GAME OVER,
--        volver al menu y reiniciar (vidas y tiempo).
--   DUT B (VGA acelerado)  : aparece junto a la meta -> VICTORIA.
--   DUT D (VGA acelerado)  : aparece junto a los pinchos -> pierde una vida.
--   DUT C (VGA real 640x480@60Hz): revisa el color de pixeles puntuales en el
--        MENU (pantalla oscura + icono) y en el JUEGO (cielo, casillas, sprite
--        del personaje, meta, pinchos) y los displays HEX (3 vidas, tiempo 000).
--
-- "VGA acelerado" = temporizacion VGA muy corta (41 x 19 pixeles) y 10 cuadros
-- por segundo: solo acelera la simulacion de las mecanicas; la logica es la misma.
--
-- Simulacion: ~65 ms de tiempo simulado.   ModelSim:  run -all
-- Resultado : la consola imprime "TODAS LAS PRUEBAS PASARON" o los ERROR.
-- Librerias : ieee.std_logic_1164
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
--------------------------------------------------------------------------------
ENTITY celeste_top_tb IS
END ENTITY celeste_top_tb;
--------------------------------------------------------------------------------
ARCHITECTURE sim OF celeste_top_tb IS
   ------------------------------------------------------------- Tiempos
   CONSTANT CLK_PERIOD : TIME := 20 ns;                 -- 50 MHz
   CONSTANT T_PIX      : TIME := 2 * CLK_PERIOD;        -- 25 MHz

   -- VGA acelerado (41 x 19 pixeles por cuadro)
   CONSTANT F_H_DISP : INTEGER := 31;  CONSTANT F_H_FP : INTEGER := 2;
   CONSTANT F_H_RET  : INTEGER := 3;   CONSTANT F_H_BP : INTEGER := 4;
   CONSTANT F_V_DISP : INTEGER := 15;  CONSTANT F_V_FP : INTEGER := 1;
   CONSTANT F_V_RET  : INTEGER := 1;   CONSTANT F_V_BP : INTEGER := 1;
   CONSTANT FAST_FRAME : TIME :=
      (F_H_DISP + F_H_FP + F_H_RET + F_H_BP + 1) *
      (F_V_DISP + F_V_FP + F_V_RET + F_V_BP + 1) * T_PIX;

   -- VGA real 640x480 @ 60 Hz
   CONSTANT H_PIXELS     : INTEGER := 640 + 16 + 96 + 48;     -- 800
   CONSTANT V_LINES      : INTEGER := 480 + 10 + 2 + 33;      -- 525
   CONSTANT H_PERIOD     : TIME    := H_PIXELS * T_PIX;
   CONSTANT FRAME_PERIOD : TIME    := V_LINES * H_PERIOD;
   CONSTANT V_SYNC_LINE  : INTEGER := 480 + 10;               -- 490

   ---------------------------------------------------------- Senales comunes
   SIGNAL clk_tb   : STD_LOGIC := '0';
   SIGNAL rst_n_tb : STD_LOGIC := '0';
   SIGNAL sim_done : BOOLEAN   := FALSE;

   ---------------------------------------------------------------- DUT A
   SIGNAL a_l, a_r, a_j, a_d, a_u, a_s : STD_LOGIC := '1';   -- 1 = suelto
   SIGNAL a_hs, a_vs : STD_LOGIC;
   SIGNAL a_vr, a_vg, a_vb : STD_LOGIC_VECTOR(3 DOWNTO 0);
   SIGNAL a_hex0, a_hex1, a_hex2, a_hex3 : STD_LOGIC_VECTOR(6 DOWNTO 0);
   SIGNAL a_led : STD_LOGIC_VECTOR(9 DOWNTO 0);
   SIGNAL a_done : BOOLEAN := FALSE;
   SIGNAL a_errs : INTEGER := 0;

   ---------------------------------------------------------------- DUT B
   SIGNAL b_l, b_r, b_j, b_d, b_u, b_s : STD_LOGIC := '1';
   SIGNAL b_hs, b_vs : STD_LOGIC;
   SIGNAL b_vr, b_vg, b_vb : STD_LOGIC_VECTOR(3 DOWNTO 0);
   SIGNAL b_hex0, b_hex1, b_hex2, b_hex3 : STD_LOGIC_VECTOR(6 DOWNTO 0);
   SIGNAL b_led : STD_LOGIC_VECTOR(9 DOWNTO 0);
   SIGNAL b_done : BOOLEAN := FALSE;
   SIGNAL b_errs : INTEGER := 0;

   ---------------------------------------------------------------- DUT D
   SIGNAL d_l, d_r, d_j, d_d, d_u, d_s : STD_LOGIC := '1';
   SIGNAL d_hs, d_vs : STD_LOGIC;
   SIGNAL d_vr, d_vg, d_vb : STD_LOGIC_VECTOR(3 DOWNTO 0);
   SIGNAL d_hex0, d_hex1, d_hex2, d_hex3 : STD_LOGIC_VECTOR(6 DOWNTO 0);
   SIGNAL d_led : STD_LOGIC_VECTOR(9 DOWNTO 0);
   SIGNAL d_done : BOOLEAN := FALSE;
   SIGNAL d_errs : INTEGER := 0;

   ---------------------------------------------------------------- DUT C
   SIGNAL c_l, c_r, c_j, c_d, c_u, c_s : STD_LOGIC := '1';
   SIGNAL c_hs, c_vs : STD_LOGIC;
   SIGNAL c_vr, c_vg, c_vb : STD_LOGIC_VECTOR(3 DOWNTO 0);
   SIGNAL c_hex0, c_hex1, c_hex2, c_hex3 : STD_LOGIC_VECTOR(6 DOWNTO 0);
   SIGNAL c_led : STD_LOGIC_VECTOR(9 DOWNTO 0);
   SIGNAL c_done : BOOLEAN := FALSE;
   SIGNAL c_errs : INTEGER := 0;

   ----------------------------------------------------------- Utilidades
   -- Patron de 7 segmentos (activo en bajo) de un digito
   FUNCTION seg7 (n : INTEGER) RETURN STD_LOGIC_VECTOR IS
   BEGIN
      CASE n IS
         WHEN 0 => RETURN "1000000";
         WHEN 1 => RETURN "1111001";
         WHEN 2 => RETURN "0100100";
         WHEN 3 => RETURN "0110000";
         WHEN 4 => RETURN "0011001";
         WHEN OTHERS => RETURN "1111111";
      END CASE;
   END FUNCTION seg7;

   -- Pulsa un boton (a nivel bajo) durante t
   PROCEDURE press (SIGNAL b : OUT STD_LOGIC; CONSTANT t : IN TIME) IS
   BEGIN
      b <= '0';
      WAIT FOR t;
      b <= '1';
   END PROCEDURE press;

   -- Compara una porcion de los LEDs de depuracion
   PROCEDURE check_led (SIGNAL led : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
                        CONSTANT hi : IN INTEGER; CONSTANT lo : IN INTEGER;
                        CONSTANT val : IN STD_LOGIC_VECTOR;
                        CONSTANT name : IN STRING;
                        VARIABLE errs : INOUT INTEGER) IS
   BEGIN
      IF (led(hi DOWNTO lo) /= val) THEN
         errs := errs + 1;
         REPORT "FALLO  " & name SEVERITY ERROR;
      ELSE
         REPORT "OK     " & name SEVERITY NOTE;
      END IF;
   END PROCEDURE check_led;

   -- Espera (hasta max_f cuadros) a que una porcion de los LEDs valga val
   PROCEDURE wait_led (SIGNAL led : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
                       CONSTANT hi : IN INTEGER; CONSTANT lo : IN INTEGER;
                       CONSTANT val : IN STD_LOGIC_VECTOR;
                       CONSTANT max_f : IN INTEGER;
                       CONSTANT name : IN STRING;
                       VARIABLE errs : INOUT INTEGER) IS
      VARIABLE found : BOOLEAN := FALSE;
   BEGIN
      FOR i IN 1 TO max_f * 4 LOOP
         IF (led(hi DOWNTO lo) = val) THEN
            found := TRUE;
            EXIT;
         END IF;
         WAIT FOR FAST_FRAME / 4;
      END LOOP;
      IF (NOT found) THEN
         errs := errs + 1;
         REPORT "FALLO  " & name SEVERITY ERROR;
      ELSE
         REPORT "OK     " & name SEVERITY NOTE;
      END IF;
   END PROCEDURE wait_led;

   -- Espera a que un display muestre el digito n
   PROCEDURE wait_hex (SIGNAL hex : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
                       CONSTANT n : IN INTEGER;
                       CONSTANT max_f : IN INTEGER;
                       CONSTANT name : IN STRING;
                       VARIABLE errs : INOUT INTEGER) IS
      VARIABLE found : BOOLEAN := FALSE;
   BEGIN
      FOR i IN 1 TO max_f * 4 LOOP
         IF (hex = seg7(n)) THEN
            found := TRUE;
            EXIT;
         END IF;
         WAIT FOR FAST_FRAME / 4;
      END LOOP;
      IF (NOT found) THEN
         errs := errs + 1;
         REPORT "FALLO  " & name SEVERITY ERROR;
      ELSE
         REPORT "OK     " & name SEVERITY NOTE;
      END IF;
   END PROCEDURE wait_hex;

   PROCEDURE check_hex (SIGNAL hex : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
                        CONSTANT n : IN INTEGER;
                        CONSTANT name : IN STRING;
                        VARIABLE errs : INOUT INTEGER) IS
   BEGIN
      IF (hex /= seg7(n)) THEN
         errs := errs + 1;
         REPORT "FALLO  " & name SEVERITY ERROR;
      ELSE
         REPORT "OK     " & name SEVERITY NOTE;
      END IF;
   END PROCEDURE check_hex;

--------------------------------------------------------------------------------
BEGIN

   ---------------------------------------------------------------------- Reloj
   clk_gen : PROCESS
   BEGIN
      WHILE NOT sim_done LOOP
         clk_tb <= '0';
         WAIT FOR CLK_PERIOD / 2;
         clk_tb <= '1';
         WAIT FOR CLK_PERIOD / 2;
      END LOOP;
      WAIT;
   END PROCESS clk_gen;

   ---------------------------------------------------------------------- Reset
   rst_gen : PROCESS
   BEGIN
      rst_n_tb <= '0';
      WAIT FOR 100 ns;
      rst_n_tb <= '1';
      WAIT;
   END PROCESS rst_gen;

   -------------------------------------------------------------------- Watchdog
   watchdog : PROCESS
   BEGIN
      WAIT UNTIL sim_done FOR 120 ms;
      ASSERT sim_done
         REPORT "TIMEOUT: la simulacion no termino a tiempo"
         SEVERITY FAILURE;
      WAIT;
   END PROCESS watchdog;

   ------------------------------------------------------------------------------
   -- DUTs
   ------------------------------------------------------------------------------
   dut_a : ENTITY work.celeste
      GENERIC MAP ( DEBOUNCE_CYCLES => 4, FRAMES_PER_SEC => 10,
                    H_DISP => F_H_DISP, H_FP => F_H_FP, H_RET => F_H_RET, H_BP => F_H_BP,
                    V_DISP => F_V_DISP, V_FP => F_V_FP, V_RET => F_V_RET, V_BP => F_V_BP )
      PORT MAP ( CLOCK_50 => clk_tb, Reset_n => rst_n_tb,
                 btn_left => a_l, btn_right => a_r, btn_jump => a_j,
                 btn_dash => a_d, btn_duck => a_u, btn_start => a_s,
                 VGA_HS => a_hs, VGA_VS => a_vs, VGA_R => a_vr, VGA_G => a_vg, VGA_B => a_vb,
                 HEX0 => a_hex0, HEX1 => a_hex1, HEX2 => a_hex2, HEX3 => a_hex3,
                 LEDG => a_led );

   dut_b : ENTITY work.celeste
      GENERIC MAP ( DEBOUNCE_CYCLES => 4, FRAMES_PER_SEC => 10,
                    SPAWN_X => 192, SPAWN_Y => 96,
                    H_DISP => F_H_DISP, H_FP => F_H_FP, H_RET => F_H_RET, H_BP => F_H_BP,
                    V_DISP => F_V_DISP, V_FP => F_V_FP, V_RET => F_V_RET, V_BP => F_V_BP )
      PORT MAP ( CLOCK_50 => clk_tb, Reset_n => rst_n_tb,
                 btn_left => b_l, btn_right => b_r, btn_jump => b_j,
                 btn_dash => b_d, btn_duck => b_u, btn_start => b_s,
                 VGA_HS => b_hs, VGA_VS => b_vs, VGA_R => b_vr, VGA_G => b_vg, VGA_B => b_vb,
                 HEX0 => b_hex0, HEX1 => b_hex1, HEX2 => b_hex2, HEX3 => b_hex3,
                 LEDG => b_led );

   dut_d : ENTITY work.celeste
      GENERIC MAP ( DEBOUNCE_CYCLES => 4, FRAMES_PER_SEC => 10,
                    SPAWN_X => 352, SPAWN_Y => 384,
                    H_DISP => F_H_DISP, H_FP => F_H_FP, H_RET => F_H_RET, H_BP => F_H_BP,
                    V_DISP => F_V_DISP, V_FP => F_V_FP, V_RET => F_V_RET, V_BP => F_V_BP )
      PORT MAP ( CLOCK_50 => clk_tb, Reset_n => rst_n_tb,
                 btn_left => d_l, btn_right => d_r, btn_jump => d_j,
                 btn_dash => d_d, btn_duck => d_u, btn_start => d_s,
                 VGA_HS => d_hs, VGA_VS => d_vs, VGA_R => d_vr, VGA_G => d_vg, VGA_B => d_vb,
                 HEX0 => d_hex0, HEX1 => d_hex1, HEX2 => d_hex2, HEX3 => d_hex3,
                 LEDG => d_led );

   dut_c : ENTITY work.celeste
      GENERIC MAP ( DEBOUNCE_CYCLES => 4 )          -- VGA real y 60 cuadros/s
      PORT MAP ( CLOCK_50 => clk_tb, Reset_n => rst_n_tb,
                 btn_left => c_l, btn_right => c_r, btn_jump => c_j,
                 btn_dash => c_d, btn_duck => c_u, btn_start => c_s,
                 VGA_HS => c_hs, VGA_VS => c_vs, VGA_R => c_vr, VGA_G => c_vg, VGA_B => c_vb,
                 HEX0 => c_hex0, HEX1 => c_hex1, HEX2 => c_hex2, HEX3 => c_hex3,
                 LEDG => c_led );

   ------------------------------------------------------------------------------
   -- ESTIMULO A: mecanicas del personaje y del juego
   -- LEDG: 0 suelo | 1 dash | 2 doble salto | 3 agachado | 6..4 modo | 9..7 juego
   -- modo: 000 suelo, 001 agachado, 010 salto, 011 caida, 100 dash
   -- juego: 000 menu, 001 juego, 010 pausa, 011 victoria, 100 game over
   ------------------------------------------------------------------------------
   stim_a : PROCESS
      VARIABLE errs : INTEGER := 0;
      VARIABLE hv   : STD_LOGIC_VECTOR(6 DOWNTO 0);
   BEGIN
      WAIT FOR 500 ns;
      WAIT FOR 3 * FAST_FRAME;

      -- Menu inicial
      check_led(a_led, 9, 7, "000", "A: estado inicial MENU", errs);
      check_hex(a_hex3, 3, "A: 3 vidas en HEX3", errs);

      -- Menu -> juego
      press(a_s, 1 us);
      wait_led(a_led, 9, 7, "001", 3, "A: MENU -> JUEGO", errs);
      wait_led(a_led, 6, 4, "000", 10, "A: el personaje queda en el suelo", errs);
      check_led(a_led, 0, 0, "1", "A: LED en suelo", errs);
      check_led(a_led, 1, 1, "1", "A: dash disponible", errs);
      check_led(a_led, 2, 2, "1", "A: doble salto disponible", errs);

      -- Salto basico
      press(a_j, 1 us);
      wait_led(a_led, 6, 4, "010", 4, "A: salto -> modo SALTO", errs);
      check_led(a_led, 0, 0, "0", "A: en el aire", errs);
      wait_led(a_led, 6, 4, "011", 30, "A: SALTO -> CAIDA", errs);
      wait_led(a_led, 6, 4, "000", 30, "A: CAIDA -> SUELO", errs);

      -- Doble salto
      press(a_j, 1 us);
      wait_led(a_led, 6, 4, "010", 4, "A: salto (para el doble salto)", errs);
      WAIT FOR 4 * FAST_FRAME;
      check_led(a_led, 6, 4, "010", "A: aun subiendo", errs);
      press(a_j, 1 us);
      wait_led(a_led, 2, 2, "0", 4, "A: el doble salto consume la recarga", errs);
      wait_led(a_led, 6, 4, "011", 40, "A: cayendo tras el doble salto", errs);
      press(a_j, 1 us);
      WAIT FOR 3 * FAST_FRAME;
      check_led(a_led, 6, 4, "011", "A: el tercer salto se ignora", errs);
      wait_led(a_led, 6, 4, "000", 40, "A: aterriza", errs);
      wait_led(a_led, 2, 2, "1", 5, "A: recarga del doble salto en el suelo", errs);

      -- Agacharse
      a_u <= '0';
      wait_led(a_led, 6, 4, "001", 4, "A: AGACHADO", errs);
      check_led(a_led, 3, 3, "1", "A: LED agachado", errs);
      a_u <= '1';
      wait_led(a_led, 6, 4, "000", 4, "A: se levanta (hay espacio)", errs);

      -- Dash en el suelo (hacia donde mira: derecha)
      press(a_d, 1 us);
      wait_led(a_led, 6, 4, "100", 4, "A: modo DASH", errs);
      check_led(a_led, 1, 1, "0", "A: dash consumido", errs);
      wait_led(a_led, 6, 4, "000", 15, "A: fin del dash en el suelo", errs);
      wait_led(a_led, 1, 1, "1", 5, "A: el dash se recarga en el suelo", errs);

      -- Dash en el aire: solo uno por salto (manteniendo izquierda)
      a_l <= '0';
      press(a_j, 1 us);
      wait_led(a_led, 6, 4, "010", 4, "A: salto antes del dash aereo", errs);
      press(a_d, 1 us);
      wait_led(a_led, 6, 4, "100", 4, "A: dash en el aire", errs);
      wait_led(a_led, 6, 4, "011", 15, "A: fin del dash -> CAIDA", errs);
      press(a_d, 1 us);
      WAIT FOR 3 * FAST_FRAME;
      check_led(a_led, 6, 4, "011", "A: segundo dash aereo bloqueado", errs);
      a_l <= '1';
      wait_led(a_led, 6, 4, "000", 40, "A: aterriza tras el dash aereo", errs);
      wait_led(a_led, 1, 1, "1", 5, "A: dash recargado al aterrizar", errs);

      -- El cronometro avanzo
      ASSERT (a_hex0 /= seg7(0)) OR (a_hex1 /= seg7(0)) OR (a_hex2 /= seg7(0))
         REPORT "FALLO  A: el cronometro no avanzo" SEVERITY ERROR;
      IF NOT ((a_hex0 /= seg7(0)) OR (a_hex1 /= seg7(0)) OR (a_hex2 /= seg7(0))) THEN
         errs := errs + 1;
      END IF;

      -- Pausa: el cronometro se congela
      press(a_s, 1 us);
      wait_led(a_led, 9, 7, "010", 3, "A: JUEGO -> PAUSA", errs);
      WAIT FOR 1 us;
      hv := a_hex0;
      WAIT FOR 25 * FAST_FRAME;
      IF (a_hex0 /= hv) THEN
         errs := errs + 1;
         REPORT "FALLO  A: el cronometro avanza en PAUSA" SEVERITY ERROR;
      ELSE
         REPORT "OK     A: el cronometro se congela en PAUSA" SEVERITY NOTE;
      END IF;
      press(a_s, 1 us);
      wait_led(a_led, 9, 7, "001", 3, "A: PAUSA -> JUEGO", errs);

      -- Tres muertes por el foso -> GAME OVER
      wait_led(a_led, 6, 4, "000", 20, "A: en el suelo antes de las muertes", errs);
      a_r <= '0';
      wait_hex(a_hex3, 2, 150, "A: muerte 1 -> 2 vidas", errs);
      a_r <= '1';
      WAIT FOR 8 * FAST_FRAME;
      a_r <= '0';
      wait_hex(a_hex3, 1, 150, "A: muerte 2 -> 1 vida", errs);
      a_r <= '1';
      WAIT FOR 8 * FAST_FRAME;
      a_r <= '0';
      wait_led(a_led, 9, 7, "100", 150, "A: muerte 3 -> GAME OVER", errs);
      a_r <= '1';
      check_hex(a_hex3, 0, "A: 0 vidas en HEX3", errs);

      -- Game over -> menu -> nueva partida (vidas y tiempo reiniciados)
      press(a_s, 1 us);
      wait_led(a_led, 9, 7, "000", 3, "A: GAME OVER -> MENU", errs);
      WAIT FOR 1 us;                                   -- suelta el boton entre pulsaciones
      press(a_s, 1 us);
      wait_led(a_led, 9, 7, "001", 3, "A: MENU -> JUEGO (nueva partida)", errs);
      WAIT FOR 2 * FAST_FRAME;
      check_hex(a_hex3, 3, "A: vidas reiniciadas a 3", errs);
      check_hex(a_hex0, 0, "A: tiempo reiniciado (unidades)", errs);
      check_hex(a_hex1, 0, "A: tiempo reiniciado (decenas)", errs);

      a_errs <= errs;
      a_done <= TRUE;
      WAIT;
   END PROCESS stim_a;

   ------------------------------------------------------------------------------
   -- ESTIMULO B: victoria (aparece junto a la meta)
   ------------------------------------------------------------------------------
   stim_b : PROCESS
      VARIABLE errs : INTEGER := 0;
   BEGIN
      WAIT FOR 500 ns;
      WAIT FOR 3 * FAST_FRAME;
      press(b_s, 1 us);
      wait_led(b_led, 9, 7, "001", 3, "B: MENU -> JUEGO", errs);
      wait_led(b_led, 6, 4, "000", 10, "B: de pie sobre la plataforma", errs);
      b_l <= '0';
      wait_led(b_led, 9, 7, "011", 40, "B: toca la fresa -> VICTORIA", errs);
      b_l <= '1';
      WAIT FOR 5 * FAST_FRAME;
      check_led(b_led, 9, 7, "011", "B: se mantiene en VICTORIA", errs);
      press(b_s, 1 us);
      wait_led(b_led, 9, 7, "000", 3, "B: VICTORIA -> MENU", errs);

      b_errs <= errs;
      b_done <= TRUE;
      WAIT;
   END PROCESS stim_b;

   ------------------------------------------------------------------------------
   -- ESTIMULO D: pinchos (aparece junto a los pinchos)
   ------------------------------------------------------------------------------
   stim_d : PROCESS
      VARIABLE errs : INTEGER := 0;
   BEGIN
      WAIT FOR 500 ns;
      WAIT FOR 3 * FAST_FRAME;
      press(d_s, 1 us);
      wait_led(d_led, 9, 7, "001", 3, "D: MENU -> JUEGO", errs);
      wait_led(d_led, 6, 4, "000", 10, "D: en el suelo", errs);
      check_hex(d_hex3, 3, "D: 3 vidas", errs);
      d_r <= '0';
      wait_hex(d_hex3, 2, 60, "D: los pinchos quitan una vida", errs);
      d_r <= '1';
      WAIT FOR 8 * FAST_FRAME;
      check_led(d_led, 9, 7, "001", "D: sigue en JUEGO tras reaparecer", errs);

      d_errs <= errs;
      d_done <= TRUE;
      WAIT;
   END PROCESS stim_d;

   ------------------------------------------------------------------------------
   -- ESTIMULO C: video real. Revisa el color de pixeles puntuales.
   -- Referencia: al bajar VSync sale el pixel (0, 490). El pixel (x, y) sale
   -- (y - 490) lineas y x pixeles despues (en el cuadro siguiente si y < 490).
   ------------------------------------------------------------------------------
   stim_c : PROCESS
      VARIABLE errs : INTEGER := 0;
      VARIABLE t_vs : TIME;

      PROCEDURE sample (CONSTANT x : IN INTEGER; CONSTANT y : IN INTEGER;
                        CONSTANT eR : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
                        CONSTANT eG : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
                        CONSTANT eB : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
                        CONSTANT name : IN STRING) IS
         VARIABLE target : TIME;
      BEGIN
         target := t_vs + (y - V_SYNC_LINE) * H_PERIOD + x * T_PIX + T_PIX / 2;
         WHILE target <= NOW LOOP
            target := target + FRAME_PERIOD;
         END LOOP;
         WAIT FOR target - NOW;
         IF (c_vr /= eR) OR (c_vg /= eG) OR (c_vb /= eB) THEN
            errs := errs + 1;
            REPORT "FALLO  " & name & "  (x=" & INTEGER'IMAGE(x) &
                   ", y=" & INTEGER'IMAGE(y) & ")" SEVERITY ERROR;
         ELSE
            REPORT "OK     " & name & "  (x=" & INTEGER'IMAGE(x) &
                   ", y=" & INTEGER'IMAGE(y) & ")" SEVERITY NOTE;
         END IF;
      END PROCEDURE sample;
   BEGIN
      WAIT UNTIL falling_edge(c_vs);
      t_vs := NOW;

      -- MENU: pantalla oscura con icono de play
      check_led(c_led, 9, 7, "000", "C: estado MENU", errs);
      --      x    y    R     G     B
      sample(450,  60, X"0", X"0", X"1", "C: menu - cielo oscurecido (banda 1)");
      sample(450, 200, X"0", X"1", X"2", "C: menu - cielo oscurecido (banda 2)");
      sample(300, 240, X"F", X"F", X"F", "C: menu - icono play (blanco)");
      sample(644, 240, X"0", X"0", X"0", "C: blanking (negro)");

      -- Iniciar el juego (durante el mismo cuadro)
      press(c_s, 1 us);
      WAIT UNTIL falling_edge(c_vs);
      t_vs := NOW;

      -- JUEGO: escena sin oscurecer
      sample(450,  60, X"1", X"1", X"2", "C: juego - cielo banda 1");
      sample(450, 200, X"1", X"2", X"5", "C: juego - cielo banda 2");
      sample(144, 114, X"F", X"0", X"4", "C: juego - fresa (meta)");
      sample( 65, 385, X"3", X"3", X"7", "C: juego - esquina transparente del sprite");
      sample( 77, 387, X"F", X"0", X"4", "C: juego - sprite: cabello rojo");
      sample( 81, 393, X"F", X"C", X"A", "C: juego - sprite: piel");
      sample( 81, 409, X"2", X"A", X"F", "C: juego - sprite: chaqueta azul");
      sample(424, 412, X"C", X"C", X"C", "C: juego - pinchos");
      sample(100, 420, X"F", X"F", X"E", "C: juego - nieve del suelo");
      sample(106, 460, X"5", X"5", X"4", "C: juego - roca del suelo");

      check_led(c_led, 9, 7, "001", "C: estado JUEGO", errs);
      check_hex(c_hex3, 3, "C: 3 vidas en HEX3", errs);
      check_hex(c_hex2, 0, "C: tiempo 0 (centenas)", errs);
      check_hex(c_hex1, 0, "C: tiempo 0 (decenas)", errs);
      check_hex(c_hex0, 0, "C: tiempo 0 (unidades)", errs);

      c_errs <= errs;
      c_done <= TRUE;
      WAIT;
   END PROCESS stim_c;

   ------------------------------------------------------------------------------
   -- Resumen final
   ------------------------------------------------------------------------------
   summary : PROCESS
   BEGIN
      WAIT UNTIL a_done AND b_done AND c_done AND d_done;
      WAIT FOR 1 us;
      IF (a_errs + b_errs + c_errs + d_errs = 0) THEN
         REPORT "=== TODAS LAS PRUEBAS PASARON (A mecanicas, B victoria, C video, D pinchos) ==="
            SEVERITY NOTE;
      ELSE
         REPORT "=== HAY PRUEBAS FALLIDAS: A=" & INTEGER'IMAGE(a_errs) &
                " B=" & INTEGER'IMAGE(b_errs) & " C=" & INTEGER'IMAGE(c_errs) &
                " D=" & INTEGER'IMAGE(d_errs) & " ==="
            SEVERITY ERROR;
      END IF;
      sim_done <= TRUE;
      WAIT;
   END PROCESS summary;
END ARCHITECTURE sim;