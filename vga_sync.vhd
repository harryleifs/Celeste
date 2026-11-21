--------------------------------------------------------------------------------
-- Proyecto Final - Diseño de Sistemas Digitales (Mini videojuego estilo Celeste)
-- Archivo : vga_sync.vhd
-- Funcion : Sincronizacion VGA (Image Sync de la presentacion). Genera pix_ce
--           (habilitador de 25 MHz a partir de 50 MHz), HSync, VSync, VideoOn,
--           PixelX, PixelY y frame_tick (1 pulso por cuadro, al iniciar el
--           blanking vertical). Por defecto 640x480 @ 60 Hz.
--           Los GENERIC permiten acortar la temporizacion solo para simulacion.
-- Librerias: ieee.std_logic_1164, ieee.numeric_std
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
--------------------------------------------------------------------------------
ENTITY vga_sync IS
   GENERIC ( H_DISP : INTEGER := 639;  H_FP : INTEGER := 16;
             H_RET  : INTEGER := 96;   H_BP : INTEGER := 48;
             V_DISP : INTEGER := 479;  V_FP : INTEGER := 10;
             V_RET  : INTEGER := 2;    V_BP : INTEGER := 33 );
   PORT (    clk        : IN  STD_LOGIC;
             rst        : IN  STD_LOGIC;
             pix_ce     : OUT STD_LOGIC;                      -- habilitador de pixel
             hsync      : OUT STD_LOGIC;
             vsync      : OUT STD_LOGIC;
             video_on   : OUT STD_LOGIC;
             pixel_x    : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
             pixel_y    : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
             frame_tick : OUT STD_LOGIC );
END ENTITY vga_sync;
--------------------------------------------------------------------------------
ARCHITECTURE rtl OF vga_sync IS
   CONSTANT H_MAX : INTEGER := H_DISP + H_FP + H_RET + H_BP;
   CONSTANT V_MAX : INTEGER := V_DISP + V_FP + V_RET + V_BP;

   SIGNAL ce_r      : STD_LOGIC;
   SIGNAL hcount    : INTEGER RANGE 0 TO H_MAX;
   SIGNAL vcount    : INTEGER RANGE 0 TO V_MAX;
   SIGNAL tick_r    : STD_LOGIC;
   SIGNAL video_on_i: STD_LOGIC;
BEGIN
   ------------------------------------------------------ HABILITADOR DE PIXEL
   ce_gen : PROCESS (clk, rst)
   BEGIN
      IF (rst = '1') THEN
         ce_r <= '0';
      ELSIF (rising_edge(clk)) THEN
         ce_r <= NOT ce_r;
      END IF;
   END PROCESS ce_gen;

   pix_ce <= ce_r;

   ------------------------------------------------------- CONTADORES H Y V
   counters : PROCESS (clk, rst)
   BEGIN
      IF (rst = '1') THEN
         hcount <= 0;
         vcount <= 0;
      ELSIF (rising_edge(clk)) THEN
         IF (ce_r = '1') THEN
            IF (hcount = H_MAX) THEN
               hcount <= 0;
               IF (vcount = V_MAX) THEN
                  vcount <= 0;
               ELSE
                  vcount <= vcount + 1;
               END IF;
            ELSE
               hcount <= hcount + 1;
            END IF;
         END IF;
      END IF;
   END PROCESS counters;

   ------------------------------------------------- SINCRONISMOS (ACTIVOS EN BAJO)
   hsync <= '0' WHEN (hcount > H_DISP + H_FP) AND (hcount <= H_DISP + H_FP + H_RET)
                ELSE '1';
   vsync <= '0' WHEN (vcount > V_DISP + V_FP) AND (vcount <= V_DISP + V_FP + V_RET)
                ELSE '1';

   video_on_i <= '1' WHEN (hcount <= H_DISP) AND (vcount <= V_DISP) ELSE '0';
   video_on   <= video_on_i;

   pixel_x <= STD_LOGIC_VECTOR(to_unsigned(hcount, 10)) WHEN video_on_i = '1'
              ELSE (OTHERS => '0');
   pixel_y <= STD_LOGIC_VECTOR(to_unsigned(vcount, 10)) WHEN video_on_i = '1'
              ELSE (OTHERS => '0');

   ------------------------------------------- PULSO POR CUADRO (INICIO DEL BLANKING)
   frame_pulse : PROCESS (clk, rst)
   BEGIN
      IF (rst = '1') THEN
         tick_r <= '0';
      ELSIF (rising_edge(clk)) THEN
         IF (ce_r = '1' AND hcount = H_MAX AND vcount = V_DISP) THEN
            tick_r <= '1';
         ELSE
            tick_r <= '0';
         END IF;
      END IF;
   END PROCESS frame_pulse;

   frame_tick <= tick_r;
END ARCHITECTURE rtl;