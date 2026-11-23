LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY tile_rom IS
   PORT (    clk  : IN  STD_LOGIC;
             row  : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
             col  : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
             tile : OUT STD_LOGIC_VECTOR(2 DOWNTO 0) );
END ENTITY tile_rom;

ARCHITECTURE rtl OF tile_rom IS
   TYPE map_row_t IS ARRAY (0 TO 19) OF INTEGER RANGE 0 TO 7;
   TYPE map_t     IS ARRAY (0 TO 14) OF map_row_t;
   TYPE mem_type  IS ARRAY (0 TO 511) OF STD_LOGIC_VECTOR(2 DOWNTO 0);


   CONSTANT LEVEL_MAP : map_t := (
      --  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9      fila
      (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),   --  0
      (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),   --  1
      (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),   --  2
      (0,0,0,0,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),   --  3  fresa (meta)
      (0,0,0,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0),   --  4  plataforma C
      (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),   --  5
      (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),   --  6
      (0,0,0,0,0,0,0,0,0,2,2,2,2,0,0,0,0,0,0,0),   --  7  plataforma B
      (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),   --  8
      (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),   --  9
      (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,2,0,0),   -- 10  plataforma A
      (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),   -- 11
      (0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,0,0,0,0),   -- 12  pinchos
      (2,2,2,2,2,2,2,0,0,0,2,2,2,2,2,2,2,2,2,2),   -- 13  suelo (con foso)
      (1,1,1,1,1,1,1,0,0,0,1,1,1,1,1,1,1,1,1,1)    -- 14  base
   );

   FUNCTION init_rom RETURN mem_type IS
      VARIABLE rom : mem_type := (OTHERS => (OTHERS => '0'));
   BEGIN
      FOR r IN 0 TO 14 LOOP
         FOR c IN 0 TO 19 LOOP
            rom(r * 32 + c) := STD_LOGIC_VECTOR(to_unsigned(LEVEL_MAP(r)(c), 3));
         END LOOP;
      END LOOP;
      RETURN rom;
   END FUNCTION init_rom;

   CONSTANT LEVEL_ROM : mem_type := init_rom;
   SIGNAL   data_reg  : STD_LOGIC_VECTOR(2 DOWNTO 0);
   SIGNAL   addr      : STD_LOGIC_VECTOR(8 DOWNTO 0);
BEGIN
   addr <= row & col;
   read_process : PROCESS (clk)
   BEGIN
      IF (rising_edge(clk)) THEN
         data_reg <= LEVEL_ROM(to_integer(unsigned(addr)));
      END IF;
   END PROCESS read_process;

   tile <= data_reg;
END ARCHITECTURE rtl;
