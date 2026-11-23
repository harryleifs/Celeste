LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY pixel_gen IS
   PORT (    clk         : IN  STD_LOGIC;
             pix_ce      : IN  STD_LOGIC;
             hsync_i     : IN  STD_LOGIC;
             vsync_i     : IN  STD_LOGIC;
             video_on    : IN  STD_LOGIC;
             pixel_x     : IN  STD_LOGIC_VECTOR(9 DOWNTO 0);
             pixel_y     : IN  STD_LOGIC_VECTOR(9 DOWNTO 0);
             -- personaje
             pos_x       : IN  INTEGER RANGE -64 TO 1023;
             pos_y       : IN  INTEGER RANGE -64 TO 1023;
             facing_left : IN  STD_LOGIC;
             duck_on     : IN  STD_LOGIC;
             dash_avail  : IN  STD_LOGIC;
             -- estado del juego: 000 menu | 001 juego | 010 pausa | 011 victoria | 100 game over
             game_state  : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
             -- salidas hacia el conector VGA
             vga_hs      : OUT STD_LOGIC;
             vga_vs      : OUT STD_LOGIC;
             vga_r       : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
             vga_g       : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
             vga_b       : OUT STD_LOGIC_VECTOR(3 DOWNTO 0) );
END ENTITY pixel_gen;

ARCHITECTURE rtl OF pixel_gen IS
 
   SUBTYPE uint08 IS STD_LOGIC_VECTOR(7 DOWNTO 0);

   TYPE ColorT IS RECORD
      R : uint08;
      G : uint08;
      B : uint08;
   END RECORD ColorT;

   TYPE SpriteRowT IS ARRAY (0 TO 15) OF INTEGER RANGE 0 TO 7;
   TYPE SpriteT    IS ARRAY (0 TO 15) OF SpriteRowT;
   TYPE PaletteT   IS ARRAY (0 TO 7)  OF ColorT;

   -- Colores
   CONSTANT C_BLACK  : ColorT := (R => X"00", G => X"00", B => X"00");
   CONSTANT C_WHITE  : ColorT := (R => X"FF", G => X"FF", B => X"FF");
   CONSTANT C_SKY_1  : ColorT := (R => X"10", G => X"14", B => X"2E");
   CONSTANT C_SKY_2  : ColorT := (R => X"1D", G => X"2B", B => X"53");
   CONSTANT C_SKY_3  : ColorT := (R => X"3A", G => X"3F", B => X"7A");
   CONSTANT C_ROCK   : ColorT := (R => X"5F", G => X"57", B => X"4F");
   CONSTANT C_ROCK_D : ColorT := (R => X"3F", G => X"39", B => X"34");
   CONSTANT C_SNOW   : ColorT := (R => X"FF", G => X"F1", B => X"E8");
   CONSTANT C_BERRY  : ColorT := (R => X"FF", G => X"00", B => X"4D");
   CONSTANT C_LEAF   : ColorT := (R => X"00", G => X"87", B => X"51");
   CONSTANT C_SPIKE  : ColorT := (R => X"C2", G => X"C3", B => X"C7");
   CONSTANT C_HAIR_B : ColorT := (R => X"29", G => X"AD", B => X"FF");

   -- Paleta del personaje 
   CONSTANT PALETTE : PaletteT := (
      0 => (R => X"00", G => X"00", B => X"00"),   -- transparente
      1 => (R => X"0B", G => X"0B", B => X"14"),   -- contorno / ojos / botas
      2 => (R => X"FF", G => X"00", B => X"4D"),   -- cabello rojo
      3 => (R => X"FF", G => X"CC", B => X"AA"),   -- piel
      4 => (R => X"29", G => X"AD", B => X"FF"),   -- chaqueta azul
      5 => (R => X"FF", G => X"F1", B => X"E8"),   -- blanco (ojos / cierre)
      6 => (R => X"7E", G => X"25", B => X"53"),   -- sombra del cabello
      7 => (R => X"FF", G => X"77", B => X"A8")    -- mejilla rosada
   );

   -- Sprite 16x16 mirando a la derecha
   CONSTANT SPRITE : SpriteT := (
      (0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,0),   --  0
      (0,0,0,1,2,2,2,2,2,2,2,1,0,0,0,0),   --  1
      (0,0,1,2,2,6,2,2,2,2,2,2,1,0,0,0),   --  2
      (0,1,2,2,6,2,2,3,3,3,3,2,2,1,0,0),   --  3
      (0,1,2,2,2,2,3,3,3,3,3,3,2,1,0,0),   --  4
      (0,1,2,2,2,3,3,5,1,3,5,1,3,1,0,0),   --  5
      (0,1,2,2,2,3,3,3,1,3,3,1,3,1,0,0),   --  6
      (0,0,1,2,2,3,3,3,3,3,7,3,3,1,0,0),   --  7
      (0,0,1,2,2,2,3,3,3,3,3,3,1,0,0,0),   --  8
      (0,0,0,1,2,2,1,1,1,1,1,1,0,0,0,0),   --  9
      (0,0,0,1,2,4,4,4,4,4,4,4,1,0,0,0),   -- 10
      (0,0,1,3,4,4,4,5,5,4,4,4,3,1,0,0),   -- 11
      (0,0,1,3,4,4,4,4,4,4,4,4,3,1,0,0),   -- 12
      (0,0,0,1,4,4,4,4,4,4,4,1,0,0,0,0),   -- 13
      (0,0,0,0,1,4,4,1,1,4,4,1,0,0,0,0),   -- 14
      (0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0)    -- 15
   );

   PURE FUNCTION shade (c : ColorT; r_add : INTEGER; g_add : INTEGER;
                        b_add : INTEGER) RETURN ColorT IS
      VARIABLE o : ColorT;
   BEGIN
      o.R := STD_LOGIC_VECTOR(to_unsigned(to_integer(unsigned(c.R)) / 2 + r_add, 8));
      o.G := STD_LOGIC_VECTOR(to_unsigned(to_integer(unsigned(c.G)) / 2 + g_add, 8));
      o.B := STD_LOGIC_VECTOR(to_unsigned(to_integer(unsigned(c.B)) / 2 + b_add, 8));
      RETURN o;
   END FUNCTION shade;

   PURE FUNCTION iabs (v : INTEGER) RETURN INTEGER IS
   BEGIN
      IF (v < 0) THEN RETURN -v; ELSE RETURN v; END IF;
   END FUNCTION iabs;

   PURE FUNCTION imin (a : INTEGER; b : INTEGER) RETURN INTEGER IS
   BEGIN
      IF (a < b) THEN RETURN a; ELSE RETURN b; END IF;
   END FUNCTION imin;

   -- Señales
   SIGNAL rom_row  : STD_LOGIC_VECTOR(3 DOWNTO 0);
   SIGNAL rom_col  : STD_LOGIC_VECTOR(4 DOWNTO 0);
   SIGNAL rom_tile : STD_LOGIC_VECTOR(2 DOWNTO 0);
   SIGNAL rgb_comb : ColorT;
BEGIN
  
   rom_row <= pixel_y(8 DOWNTO 5);
   rom_col <= pixel_x(9 DOWNTO 5);

   tile_u : ENTITY work.tile_rom
      PORT MAP ( clk => clk, row => rom_row, col => rom_col, tile => rom_tile );
      
   -- Generacion del color
      
   pixel_generate : PROCESS (pixel_x, pixel_y, video_on, rom_tile, pos_x, pos_y,
                             facing_left, duck_on, dash_avail, game_state)
      VARIABLE x, y     : INTEGER;
      VARIABLE lx, ly   : INTEGER;
      VARIABLE t        : INTEGER RANGE 0 TO 7;
      VARIABLE u, h     : INTEGER;
      VARIABLE sx, sy   : INTEGER;
      VARIABLE idx      : INTEGER RANGE 0 TO 7;
      VARIABLE top_box  : INTEGER;
      VARIABLE in_box   : BOOLEAN;
      VARIABLE icon     : BOOLEAN;
      VARIABLE dx, dy   : INTEGER;
      VARIABLE color    : ColorT;
   BEGIN
      x  := to_integer(unsigned(pixel_x));
      y  := to_integer(unsigned(pixel_y));
      lx := to_integer(unsigned(pixel_x(4 DOWNTO 0)));
      ly := to_integer(unsigned(pixel_y(4 DOWNTO 0)));
      t  := to_integer(unsigned(rom_tile));

      -- 1) Fondo: cielo nocturno en tres bandas
      IF (y < 160) THEN
         color := C_SKY_1;
      ELSIF (y < 320) THEN
         color := C_SKY_2;
      ELSE
         color := C_SKY_3;
      END IF;

      -- 2) Casillas del mapa
      CASE t IS
         WHEN 1 =>                                   -- roca
            IF (lx = 0 OR ly = 0) THEN
               color := C_ROCK_D;
            ELSE
               color := C_ROCK;
            END IF;
         WHEN 2 =>                                   -- roca con nieve
            IF (ly < 8) THEN
               color := C_SNOW;
            ELSIF (lx = 0) THEN
               color := C_ROCK_D;
            ELSE
               color := C_ROCK;
            END IF;
         WHEN 3 =>                                   -- fresa (meta)
            IF ((iabs(lx - 16) + iabs(ly - 18)) < 11) THEN
               color := C_BERRY;
            ELSIF (ly >= 3 AND ly < 8 AND lx >= 13 AND lx <= 19) THEN
               color := C_LEAF;
            END IF;
         WHEN 4 =>                                   -- pinchos 
            u := lx MOD 16;
            h := 2 * imin(u, 15 - u) + 2;
            IF ((31 - ly) < h) THEN
               color := C_SPIKE;
            END IF;
         WHEN OTHERS =>
            NULL;
      END CASE;

      -- 3) Personaje
      IF (duck_on = '1') THEN
         top_box := pos_y + 16;
      ELSE
         top_box := pos_y;
      END IF;
      in_box := (x >= pos_x) AND (x <= pos_x + 31) AND (y >= top_box) AND (y <= pos_y + 31);
      IF (in_box) THEN
         sx := (x - pos_x) / 2;
         IF (duck_on = '1') THEN
            sy := y - top_box;
         ELSE
            sy := (y - top_box) / 2;
         END IF;
         IF (facing_left = '1') THEN
            sx := 15 - sx;
         END IF;
         idx := SPRITE(sy)(sx);
         IF (idx = 2 AND dash_avail = '0') THEN
            color := C_HAIR_B;                       -- sin dash: cabello azul
         ELSIF (idx /= 0) THEN
            color := PALETTE(idx);
         END IF;
      END IF;

      -- 4) Pantallas de estado
      icon := FALSE;
      CASE game_state IS
         WHEN "000" =>                               -- MENU
            color := shade(color, 0, 0, 0);
            dx := x - 280;
            IF (dx >= 0 AND dx <= 80 AND iabs(y - 240) <= (80 - dx) / 2) THEN
               icon := TRUE;
            END IF;
         WHEN "010" =>                               -- PAUSA
            color := shade(color, 0, 0, 0);
            IF (y >= 200 AND y <= 280 AND
                ((x >= 288 AND x <= 312) OR (x >= 328 AND x <= 352))) THEN
               icon := TRUE;
            END IF;
         WHEN "011" =>                               -- VICTORIA
            color := shade(color, 0, 80, 0);
            dx := x - 270;
            IF (dx >= 0 AND dx <= 30 AND iabs((y - 250) - dx) <= 6) THEN
               icon := TRUE;
            END IF;
            dx := x - 300;
            IF (dx >= 0 AND dx <= 70 AND iabs((y - 280) + dx) <= 6) THEN
               icon := TRUE;
            END IF;
         WHEN "100" =>                               -- GAME OVER
            color := shade(color, 80, 0, 0);
            dx := x - 270;
            dy := y - 190;
            IF (dx >= 0 AND dx <= 100 AND dy >= 0 AND dy <= 100 AND
                (iabs(dx - dy) <= 6 OR iabs(dx + dy - 100) <= 6)) THEN
               icon := TRUE;
            END IF;
         WHEN OTHERS =>
            NULL;
      END CASE;
      IF (icon) THEN
         color := C_WHITE;
      END IF;

      -- 5) Fuera de la zona visible el color debe ser negro
      IF (video_on = '0') THEN
         color := C_BLACK;
      END IF;

      rgb_comb <= color;
   END PROCESS pixel_generate;

   vga_out : PROCESS (clk)
   BEGIN
      IF (rising_edge(clk)) THEN
         IF (pix_ce = '1') THEN
            vga_hs <= hsync_i;
            vga_vs <= vsync_i;
            vga_r  <= rgb_comb.R(7 DOWNTO 4);
            vga_g  <= rgb_comb.G(7 DOWNTO 4);
            vga_b  <= rgb_comb.B(7 DOWNTO 4);
         END IF;
      END IF;
   END PROCESS vga_out;
END ARCHITECTURE rtl;
