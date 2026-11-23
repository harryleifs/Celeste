LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY player_engine IS
   GENERIC ( SPAWN_X : INTEGER := 64;
             SPAWN_Y : INTEGER := 384 );
   PORT (    clk          : IN  STD_LOGIC;
             rst          : IN  STD_LOGIC;
             frame_tick   : IN  STD_LOGIC;     
             run_en       : IN  STD_LOGIC;     
             init         : IN  STD_LOGIC;     
             btn_left     : IN  STD_LOGIC;     
             btn_right    : IN  STD_LOGIC;
             btn_duck     : IN  STD_LOGIC;
             btn_jump_lv  : IN  STD_LOGIC;
             jump_pulse   : IN  STD_LOGIC;     
             dash_pulse   : IN  STD_LOGIC;
             pos_x        : OUT INTEGER RANGE -64 TO 1023;
             pos_y        : OUT INTEGER RANGE -64 TO 1023;
             facing_left  : OUT STD_LOGIC;
             duck_on      : OUT STD_LOGIC;
             dash_avail_o : OUT STD_LOGIC;
             on_ground_o  : OUT STD_LOGIC;
             jumps_left_o : OUT STD_LOGIC;
             mode_code    : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
             goal_ev      : OUT STD_LOGIC;     
             dead_ev      : OUT STD_LOGIC );   
END ENTITY player_engine;

ARCHITECTURE rtl OF player_engine IS
   -- Constantes
   CONSTANT WALK_SPD    : INTEGER := 4;
   CONSTANT CRAWL_SPD   : INTEGER := 2;
   CONSTANT JUMP_V      : INTEGER := 15;
   CONSTANT GRAV        : INTEGER := 1;
   CONSTANT MAX_FALL    : INTEGER := 12;
   CONSTANT DASH_SPD    : INTEGER := 12;
   CONSTANT DASH_FRAMES : INTEGER := 8;

   -- Estados
   TYPE mode_t  IS (st_ground, st_duck, st_jump, st_fall, st_dash);
   TYPE phase_t IS (ph_idle, ph_prep,
                    ph_x_req, ph_x_wait, ph_y_req, ph_y_wait,
                    ph_g_req, ph_g_wait, ph_s_req, ph_s_wait,
                    ph_h_req, ph_h_wait, ph_end);

   SIGNAL pr_state, nx_state : mode_t;
   SIGNAL pr_phase, nx_phase : phase_t;

   -- Registros
   SIGNAL px, py       : INTEGER RANGE -64 TO 1023;
   SIGNAL vx, vy       : INTEGER RANGE -64 TO 64;
   SIGNAL dash_dx      : INTEGER RANGE -1 TO 1;
   SIGNAL dash_dy      : INTEGER RANGE -1 TO 1;
   SIGNAL dash_cnt     : INTEGER RANGE 0 TO DASH_FRAMES;
   SIGNAL facing_l     : STD_LOGIC;
   SIGNAL on_gnd       : STD_LOGIC;
   SIGNAL jumps_l      : STD_LOGIC;
   SIGNAL dash_av      : STD_LOGIC;
   SIGNAL stand_ok     : STD_LOGIC;
   SIGNAL jump_lat     : STD_LOGIC;
   SIGNAL dash_lat     : STD_LOGIC;
   SIGNAL dead_r       : STD_LOGIC;
   SIGNAL goal_r       : STD_LOGIC;
   SIGNAL respawn_r    : STD_LOGIC;

   -- Senales de control
   SIGNAL act_gjump, act_ajump, act_dash : STD_LOGIC;
   SIGNAL commit       : STD_LOGIC;
   SIGNAL force_mode   : STD_LOGIC;
   SIGNAL box_h        : INTEGER RANGE 1 TO 32;
   SIGNAL tent_x       : INTEGER RANGE -128 TO 1100;
   SIGNAL tent_y       : INTEGER RANGE -128 TO 1100;

   -- Interfaz collision_unit
   SIGNAL cu_req   : STD_LOGIC;
   SIGNAL cu_x     : INTEGER RANGE -64 TO 1023;
   SIGNAL cu_y     : INTEGER RANGE -64 TO 1023;
   SIGNAL cu_h     : INTEGER RANGE 1 TO 32;
   SIGNAL cu_done  : STD_LOGIC;
   SIGNAL cu_solid : STD_LOGIC;
   SIGNAL cu_goal  : STD_LOGIC;
   SIGNAL cu_spike : STD_LOGIC;
   SIGNAL cu_pit   : STD_LOGIC;
BEGIN
   -- Consulta de colisiones
   coll_u : ENTITY work.collision_unit
      PORT MAP ( clk => clk, rst => rst, req => cu_req,
                 box_x => cu_x, box_y => cu_y, box_h => cu_h,
                 done => cu_done, solid => cu_solid, goal => cu_goal,
                 spike => cu_spike, pit => cu_pit );

   box_h  <= 16 WHEN (pr_state = st_duck) ELSE 32;
   tent_x <= px + vx;
   tent_y <= py + vy;

   commit     <= '1' WHEN (pr_phase = ph_prep) ELSE '0';
   force_mode <= init OR respawn_r;

   -- FSM DE MOVIMIENTO 
   mode_sequential : PROCESS (rst, clk)
   BEGIN
      IF (rst = '1') THEN
         pr_state <= st_fall;
      ELSIF (rising_edge(clk)) THEN
         IF (force_mode = '1') THEN
            pr_state <= st_fall;
         ELSIF (commit = '1') THEN
            pr_state <= nx_state;
         END IF;
      END IF;
   END PROCESS mode_sequential;
   mode_combinational : PROCESS (pr_state, jump_lat, dash_lat, btn_duck, on_gnd,
                                 vy, dash_cnt, jumps_l, dash_av, stand_ok)
   BEGIN
      CASE pr_state IS
         WHEN st_ground =>
            act_gjump <= '0';  act_ajump <= '0';  act_dash <= '0';
            IF (dash_lat = '1' AND dash_av = '1') THEN
               act_dash <= '1';
               nx_state <= st_dash;
            ELSIF (jump_lat = '1') THEN
               act_gjump <= '1';
               nx_state  <= st_jump;
            ELSIF (btn_duck = '1') THEN
               nx_state <= st_duck;
            ELSIF (on_gnd = '0') THEN
               nx_state <= st_fall;
            ELSE
               nx_state <= st_ground;
            END IF;

         WHEN st_duck =>
            act_gjump <= '0';  act_ajump <= '0';  act_dash <= '0';
            IF (dash_lat = '1' AND dash_av = '1' AND stand_ok = '1') THEN
               act_dash <= '1';
               nx_state <= st_dash;
            ELSIF (jump_lat = '1' AND stand_ok = '1') THEN
               act_gjump <= '1';
               nx_state  <= st_jump;
            ELSIF (btn_duck = '0' AND stand_ok = '1') THEN
               nx_state <= st_ground;
            ELSIF (on_gnd = '0') THEN
               nx_state <= st_fall;
            ELSE
               nx_state <= st_duck;
            END IF;

         WHEN st_jump =>
            act_gjump <= '0';  act_ajump <= '0';  act_dash <= '0';
            IF (dash_lat = '1' AND dash_av = '1') THEN
               act_dash <= '1';
               nx_state <= st_dash;
            ELSIF (jump_lat = '1' AND jumps_l = '1') THEN
               act_ajump <= '1';
               nx_state  <= st_jump;
            ELSIF (vy >= 0) THEN
               nx_state <= st_fall;
            ELSE
               nx_state <= st_jump;
            END IF;

         WHEN st_fall =>
            act_gjump <= '0';  act_ajump <= '0';  act_dash <= '0';
            IF (dash_lat = '1' AND dash_av = '1') THEN
               act_dash <= '1';
               nx_state <= st_dash;
            ELSIF (jump_lat = '1' AND jumps_l = '1') THEN
               act_ajump <= '1';
               nx_state  <= st_jump;
            ELSIF (on_gnd = '1') THEN
               nx_state <= st_ground;
            ELSE
               nx_state <= st_fall;
            END IF;

         WHEN st_dash =>
            act_gjump <= '0';  act_ajump <= '0';  act_dash <= '0';
            IF (dash_cnt <= 1) THEN
               IF (on_gnd = '1') THEN
                  nx_state <= st_ground;
               ELSE
                  nx_state <= st_fall;
               END IF;
            ELSE
               nx_state <= st_dash;
            END IF;
      END CASE;
   END PROCESS mode_combinational;
         
   -- FSM DE FASES
   phase_sequential : PROCESS (rst, clk)
   BEGIN
      IF (rst = '1') THEN
         pr_phase <= ph_idle;
      ELSIF (rising_edge(clk)) THEN
         pr_phase <= nx_phase;
      END IF;
   END PROCESS phase_sequential;
         
   phase_combinational : PROCESS (pr_phase, frame_tick, run_en, cu_done)
   BEGIN
      CASE pr_phase IS
         WHEN ph_idle =>
            IF (frame_tick = '1' AND run_en = '1') THEN
               nx_phase <= ph_prep;
            ELSE
               nx_phase <= ph_idle;
            END IF;
         WHEN ph_prep   => nx_phase <= ph_x_req;
         WHEN ph_x_req  => nx_phase <= ph_x_wait;
         WHEN ph_x_wait =>
            IF (cu_done = '1') THEN nx_phase <= ph_y_req; ELSE nx_phase <= ph_x_wait; END IF;
         WHEN ph_y_req  => nx_phase <= ph_y_wait;
         WHEN ph_y_wait =>
            IF (cu_done = '1') THEN nx_phase <= ph_g_req; ELSE nx_phase <= ph_y_wait; END IF;
         WHEN ph_g_req  => nx_phase <= ph_g_wait;
         WHEN ph_g_wait =>
            IF (cu_done = '1') THEN nx_phase <= ph_s_req; ELSE nx_phase <= ph_g_wait; END IF;
         WHEN ph_s_req  => nx_phase <= ph_s_wait;
         WHEN ph_s_wait =>
            IF (cu_done = '1') THEN nx_phase <= ph_h_req; ELSE nx_phase <= ph_s_wait; END IF;
         WHEN ph_h_req  => nx_phase <= ph_h_wait;
         WHEN ph_h_wait =>
            IF (cu_done = '1') THEN nx_phase <= ph_end; ELSE nx_phase <= ph_h_wait; END IF;
         WHEN ph_end    => nx_phase <= ph_idle;
      END CASE;
   END PROCESS phase_combinational;

   probe_mux : PROCESS (pr_phase, px, py, tent_x, tent_y, box_h)
   BEGIN
      cu_req <= '0';
      cu_x   <= px;
      cu_y   <= py + (32 - box_h);
      cu_h   <= box_h;
      CASE pr_phase IS
         WHEN ph_x_req  => cu_req <= '1';  cu_x <= tent_x;
         WHEN ph_x_wait => cu_x <= tent_x;
         WHEN ph_y_req  => cu_req <= '1';  cu_y <= tent_y + (32 - box_h);
         WHEN ph_y_wait => cu_y <= tent_y + (32 - box_h);
         WHEN ph_g_req  => cu_req <= '1';  cu_y <= py + (32 - box_h) + 1;
         WHEN ph_g_wait => cu_y <= py + (32 - box_h) + 1;
         WHEN ph_s_req  => cu_req <= '1';  cu_y <= py;  cu_h <= 32;
         WHEN ph_s_wait => cu_y <= py;  cu_h <= 32;
         WHEN ph_h_req  => cu_req <= '1';
         WHEN OTHERS    => NULL;
      END CASE;
   END PROCESS probe_mux;
         
   -- Datapath
   datapath : PROCESS (clk, rst)
      VARIABLE rgt, lft : BOOLEAN;
      VARIABLE ndx, ndy : INTEGER RANGE -1 TO 1;
      VARIABLE dx, dy   : INTEGER RANGE -1 TO 1;
      VARIABLE top      : INTEGER RANGE -128 TO 1100;
   BEGIN
      IF (rst = '1') THEN
         px <= SPAWN_X;  py <= SPAWN_Y;
         vx <= 0;        vy <= 0;
         dash_dx <= 1;   dash_dy <= 0;   dash_cnt <= 0;
         facing_l <= '0';  on_gnd <= '0';  jumps_l <= '1';  dash_av <= '1';
         stand_ok <= '1';  jump_lat <= '0';  dash_lat <= '0';
         dead_r <= '0';  goal_r <= '0';  respawn_r <= '0';
      ELSIF (rising_edge(clk)) THEN
         dead_r    <= '0';
         goal_r    <= '0';
         respawn_r <= '0';

         IF (init = '1') THEN
            -- nueva partida
            px <= SPAWN_X;  py <= SPAWN_Y;
            vx <= 0;        vy <= 0;
            dash_dx <= 1;   dash_dy <= 0;   dash_cnt <= 0;
            facing_l <= '0';  on_gnd <= '0';  jumps_l <= '1';  dash_av <= '1';
            stand_ok <= '1';  jump_lat <= '0';  dash_lat <= '0';
         ELSE
            CASE pr_phase IS

               -- PREP
               WHEN ph_prep =>
                  rgt := (btn_right = '1' AND btn_left = '0');
                  lft := (btn_left = '1' AND btn_right = '0');

                  IF (lft) THEN
                     facing_l <= '1';
                  ELSIF (rgt) THEN
                     facing_l <= '0';
                  END IF;

                  -- direccion del dash 
                  ndx := 0;  ndy := 0;
                  IF (rgt) THEN ndx := 1; ELSIF (lft) THEN ndx := -1; END IF;
                  IF (btn_jump_lv = '1' AND btn_duck = '0') THEN
                     ndy := -1;
                  ELSIF (btn_duck = '1' AND btn_jump_lv = '0') THEN
                     ndy := 1;
                  END IF;
                  IF (ndx = 0 AND ndy = 0) THEN
                     IF (facing_l = '1') THEN ndx := -1; ELSE ndx := 1; END IF;
                  END IF;

                  IF (act_dash = '1') THEN
                     dash_dx  <= ndx;  dash_dy <= ndy;
                     dash_cnt <= DASH_FRAMES;
                     dash_av  <= '0';
                     dx := ndx;  dy := ndy;
                  ELSE
                     dx := dash_dx;  dy := dash_dy;
                     IF (pr_state = st_dash AND dash_cnt > 0) THEN
                        dash_cnt <= dash_cnt - 1;
                     END IF;
                  END IF;

                  -- velocidad vertical
                  IF (act_gjump = '1') THEN
                     vy <= -JUMP_V;
                  ELSIF (act_ajump = '1') THEN
                     vy      <= -JUMP_V;
                     jumps_l <= '0';
                  ELSIF (nx_state = st_dash) THEN
                     vy <= dy * DASH_SPD;
                  ELSIF (pr_state = st_dash) THEN
                     vy <= 0;
                  ELSIF (on_gnd = '1') THEN
                     vy <= 0;
                  ELSIF (vy + GRAV > MAX_FALL) THEN
                     vy <= MAX_FALL;
                  ELSE
                     vy <= vy + GRAV;
                  END IF;

                  -- velocidad horizontal
                  IF (nx_state = st_dash) THEN
                     vx <= dx * DASH_SPD;
                  ELSIF (nx_state = st_duck) THEN
                     IF (rgt) THEN vx <= CRAWL_SPD;
                     ELSIF (lft) THEN vx <= -CRAWL_SPD;
                     ELSE vx <= 0; END IF;
                  ELSE
                     IF (rgt) THEN vx <= WALK_SPD;
                     ELSIF (lft) THEN vx <= -WALK_SPD;
                     ELSE vx <= 0; END IF;
                  END IF;

                  jump_lat <= '0';
                  dash_lat <= '0';

               -- X
               WHEN ph_x_wait =>
                  IF (cu_done = '1') THEN
                     IF (cu_solid = '1') THEN
                        IF (vx > 0) THEN
                           px <= ((tent_x + 31) / 32) * 32 - 32;
                        ELSIF (vx < 0) THEN
                           IF (tent_x < 0) THEN
                              px <= 0;
                           ELSE
                              px <= (tent_x / 32 + 1) * 32;
                           END IF;
                        END IF;
                        IF (pr_state = st_dash) THEN
                           dash_cnt <= 0;
                        END IF;
                     ELSE
                        px <= tent_x;
                     END IF;
                  END IF;

               -- Y
               WHEN ph_y_wait =>
                  IF (cu_done = '1') THEN
                     IF (cu_solid = '1') THEN
                        IF (vy > 0) THEN
                           py <= ((tent_y + 31) / 32) * 32 - 32;
                           vy <= 0;
                        ELSIF (vy < 0) THEN
                           top := tent_y + (32 - box_h);
                           IF (top < 0) THEN
                              py <= -(32 - box_h);
                           ELSE
                              py <= (top / 32 + 1) * 32 - (32 - box_h);
                           END IF;
                           vy <= 0;
                        END IF;
                     ELSE
                        py <= tent_y;
                     END IF;
                  END IF;

               -- G (piso)
               WHEN ph_g_wait =>
                  IF (cu_done = '1') THEN
                     IF (cu_solid = '1' AND vy >= 0) THEN
                        on_gnd  <= '1';
                        jumps_l <= '1';
                        IF (pr_state /= st_dash) THEN
                           dash_av <= '1';
                        END IF;
                     ELSE
                        on_gnd <= '0';
                     END IF;
                  END IF;

               -- S (pararse)
               WHEN ph_s_wait =>
                  IF (cu_done = '1') THEN
                     IF (pr_state = st_duck) THEN
                        stand_ok <= NOT cu_solid;
                     ELSE
                        stand_ok <= '1';
                     END IF;
                  END IF;

               -- H (peligros)
               WHEN ph_h_wait =>
                  IF (cu_done = '1') THEN
                     IF (cu_spike = '1' OR cu_pit = '1') THEN
                        dead_r    <= '1';
                        respawn_r <= '1';
                        px <= SPAWN_X;  py <= SPAWN_Y;
                        vx <= 0;        vy <= 0;
                        dash_cnt <= 0;
                        on_gnd   <= '0';  jumps_l <= '1';  dash_av <= '1';
                        stand_ok <= '1';
                     ELSIF (cu_goal = '1') THEN
                        goal_r <= '1';
                     END IF;
                  END IF;

               WHEN OTHERS =>
                  NULL;
            END CASE;
            IF (run_en = '0') THEN
               jump_lat <= '0';
               dash_lat <= '0';
            ELSE
               IF (jump_pulse = '1') THEN jump_lat <= '1'; END IF;
               IF (dash_pulse = '1') THEN dash_lat <= '1'; END IF;
            END IF;
         END IF;
      END IF;
   END PROCESS datapath;

   -- Salidas
   pos_x        <= px;
   pos_y        <= py;
   facing_left  <= facing_l;
   duck_on      <= '1' WHEN (pr_state = st_duck) ELSE '0';
   dash_avail_o <= dash_av;
   on_ground_o  <= on_gnd;
   jumps_left_o <= jumps_l;
   goal_ev      <= goal_r;
   dead_ev      <= dead_r;

   mode_code <= "000" WHEN (pr_state = st_ground) ELSE
                "001" WHEN (pr_state = st_duck)   ELSE
                "010" WHEN (pr_state = st_jump)   ELSE
                "011" WHEN (pr_state = st_fall)   ELSE
                "100";
END ARCHITECTURE rtl;
