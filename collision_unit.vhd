--------------------------------------------------------------------------------
-- Proyecto Final - Diseño de Sistemas Digitales (Mini videojuego estilo Celeste)
-- Archivo : collision_unit.vhd
-- Funcion : Consulta de colisiones. Dado un rectangulo de 32 px de ancho y alto
--           box_h con esquina superior izquierda (box_x, box_y), revisa sus 4
--           esquinas en la ROM del mapa y reporta:
--              solid : toca roca (o sale por los lados / el techo)
--              goal  : toca la meta   spike : toca pinchos   pit : cayo al foso
--           FSM de 2 procesos (pr_state / nx_state) como en el curso.
--           Uso: pulso de 1 ciclo en req con la caja estable; el resultado es
--           valido cuando done = '1' (1 ciclo).
-- Librerias: ieee.std_logic_1164, ieee.numeric_std
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
--------------------------------------------------------------------------------
ENTITY collision_unit IS
   PORT (    clk   : IN  STD_LOGIC;
             rst   : IN  STD_LOGIC;
             req   : IN  STD_LOGIC;
             box_x : IN  INTEGER RANGE -64 TO 1023;
             box_y : IN  INTEGER RANGE -64 TO 1023;
             box_h : IN  INTEGER RANGE 1 TO 32;
             done  : OUT STD_LOGIC;
             solid : OUT STD_LOGIC;
             goal  : OUT STD_LOGIC;
             spike : OUT STD_LOGIC;
             pit   : OUT STD_LOGIC );
END ENTITY collision_unit;
--------------------------------------------------------------------------------
ARCHITECTURE rtl OF collision_unit IS
   TYPE state IS (st_idle, st_addr, st_read, st_done);
   SIGNAL pr_state, nx_state : state;

   SIGNAL k       : INTEGER RANGE 0 TO 3;       -- esquina que se esta revisando
   SIGNAL cx, cy  : INTEGER RANGE -64 TO 1100;
   SIGNAL in_map  : STD_LOGIC;
   SIGNAL rom_row : STD_LOGIC_VECTOR(3 DOWNTO 0);
   SIGNAL rom_col : STD_LOGIC_VECTOR(4 DOWNTO 0);
   SIGNAL rom_tile: STD_LOGIC_VECTOR(2 DOWNTO 0);

   SIGNAL f_solid, f_goal, f_spike, f_pit : STD_LOGIC;
BEGIN
   ------------------------------------------------ COORDENADAS DE LA ESQUINA k
   cx <= box_x          WHEN (k = 0 OR k = 2) ELSE box_x + 31;
   cy <= box_y          WHEN (k = 0 OR k = 1) ELSE box_y + box_h - 1;

   in_map <= '1' WHEN (cx >= 0 AND cx < 640 AND cy >= 0 AND cy < 480) ELSE '0';

   rom_row <= STD_LOGIC_VECTOR(to_unsigned(cy / 32, 4)) WHEN in_map = '1'
              ELSE (OTHERS => '0');
   rom_col <= STD_LOGIC_VECTOR(to_unsigned(cx / 32, 5)) WHEN in_map = '1'
              ELSE (OTHERS => '0');

   rom_u : ENTITY work.tile_rom
      PORT MAP ( clk => clk, row => rom_row, col => rom_col, tile => rom_tile );

   -------------------------------------------------------- Sequential section
   sequential : PROCESS (rst, clk)
   BEGIN
      IF (rst = '1') THEN
         pr_state <= st_idle;
      ELSIF (rising_edge(clk)) THEN
         pr_state <= nx_state;
      END IF;
   END PROCESS sequential;

   ------------------------------------------------------ Combinational section
   combinational : PROCESS (pr_state, req, k)
   BEGIN
      CASE pr_state IS
         WHEN st_idle =>
            done <= '0';
            IF (req = '1') THEN
               nx_state <= st_addr;
            ELSE
               nx_state <= st_idle;
            END IF;
         WHEN st_addr =>                -- la ROM captura la direccion
            done     <= '0';
            nx_state <= st_read;
         WHEN st_read =>                -- el dato de la ROM ya es valido
            done <= '0';
            IF (k = 3) THEN
               nx_state <= st_done;
            ELSE
               nx_state <= st_addr;
            END IF;
         WHEN st_done =>
            done     <= '1';
            nx_state <= st_idle;
      END CASE;
   END PROCESS combinational;

   -------------------------------------------------- Datapath (banderas y k)
   datapath : PROCESS (clk, rst)
      VARIABLE t : INTEGER RANGE 0 TO 7;
   BEGIN
      IF (rst = '1') THEN
         k       <= 0;
         f_solid <= '0';
         f_goal  <= '0';
         f_spike <= '0';
         f_pit   <= '0';
      ELSIF (rising_edge(clk)) THEN
         IF (pr_state = st_idle) THEN
            k       <= 0;
            f_solid <= '0';
            f_goal  <= '0';
            f_spike <= '0';
            f_pit   <= '0';
         ELSIF (pr_state = st_read) THEN
            IF (k /= 3) THEN
               k <= k + 1;
            END IF;
            IF (cy >= 480) THEN
               f_pit <= '1';
            ELSIF (cx < 0 OR cx >= 640 OR cy < 0) THEN
               f_solid <= '1';
            ELSE
               t := to_integer(unsigned(rom_tile));
               IF (t = 1 OR t = 2) THEN
                  f_solid <= '1';
               ELSIF (t = 3) THEN
                  f_goal <= '1';
               ELSIF (t = 4) THEN
                  f_spike <= '1';
               END IF;
            END IF;
         END IF;
      END IF;
   END PROCESS datapath;

   solid <= f_solid;
   goal  <= f_goal;
   spike <= f_spike;
   pit   <= f_pit;
END ARCHITECTURE rtl;