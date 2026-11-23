LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY celeste IS
   GENERIC ( DEBOUNCE_CYCLES : INTEGER := 500000;
             BTN_ACTIVE_LOW  : BOOLEAN := TRUE;
             FRAMES_PER_SEC  : INTEGER := 60;
             SPAWN_X         : INTEGER := 64;
             SPAWN_Y         : INTEGER := 384;
             H_DISP : INTEGER := 639;  H_FP : INTEGER := 16;
             H_RET  : INTEGER := 96;   H_BP : INTEGER := 48;
             V_DISP : INTEGER := 479;  V_FP : INTEGER := 10;
             V_RET  : INTEGER := 2;    V_BP : INTEGER := 33 );
   PORT (    CLOCK_50  : IN  STD_LOGIC;
             Reset_n   : IN  STD_LOGIC;
             -- controles externos
             btn_left  : IN  STD_LOGIC;
             btn_right : IN  STD_LOGIC;
             btn_jump  : IN  STD_LOGIC;
             btn_dash  : IN  STD_LOGIC;
             btn_duck  : IN  STD_LOGIC;
             btn_start : IN  STD_LOGIC;
             -- VGA
             VGA_HS    : OUT STD_LOGIC;
             VGA_VS    : OUT STD_LOGIC;
             VGA_R     : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
             VGA_G     : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
             VGA_B     : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
             -- displays de 7 segmentos 
             HEX0      : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
             HEX1      : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
             HEX2      : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
             HEX3      : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
             -- LEDs de depuracion
             LEDG      : OUT STD_LOGIC_VECTOR(9 DOWNTO 0) );
END ENTITY celeste;

ARCHITECTURE rtl OF celeste IS
   SIGNAL rst : STD_LOGIC;

   -- botones acondicionados
   SIGNAL left_lv, right_lv, jump_lv, dash_lv, duck_lv, start_lv : STD_LOGIC;
   SIGNAL left_p,  right_p,  jump_p,  dash_p,  duck_p,  start_p  : STD_LOGIC;

   -- VGA
   SIGNAL pix_ce, hsync_i, vsync_i, video_on, frame_tick : STD_LOGIC;
   SIGNAL pixel_x, pixel_y : STD_LOGIC_VECTOR(9 DOWNTO 0);

   -- juego
   SIGNAL run_en, init_p       : STD_LOGIC;
   SIGNAL game_state           : STD_LOGIC_VECTOR(2 DOWNTO 0);
   SIGNAL lives                : STD_LOGIC_VECTOR(3 DOWNTO 0);
   SIGNAL goal_ev, dead_ev     : STD_LOGIC;

   -- personaje
   SIGNAL pos_x, pos_y         : INTEGER RANGE -64 TO 1023;
   SIGNAL facing_left, duck_on : STD_LOGIC;
   SIGNAL dash_avail, on_ground, jumps_left : STD_LOGIC;
   SIGNAL mode_code            : STD_LOGIC_VECTOR(2 DOWNTO 0);

   -- tiempo
   SIGNAL sec_u, sec_t, sec_h  : STD_LOGIC_VECTOR(3 DOWNTO 0);
BEGIN
   rst <= NOT Reset_n;                  

   
   btn_left_u : ENTITY work.btn_conditioner
      GENERIC MAP ( DEBOUNCE_CYCLES => DEBOUNCE_CYCLES, ACTIVE_LOW => BTN_ACTIVE_LOW )
      PORT MAP ( clk => CLOCK_50, rst => rst, btn_in => btn_left,
                 btn_level => left_lv, btn_pulse => left_p );
   btn_right_u : ENTITY work.btn_conditioner
      GENERIC MAP ( DEBOUNCE_CYCLES => DEBOUNCE_CYCLES, ACTIVE_LOW => BTN_ACTIVE_LOW )
      PORT MAP ( clk => CLOCK_50, rst => rst, btn_in => btn_right,
                 btn_level => right_lv, btn_pulse => right_p );
   btn_jump_u : ENTITY work.btn_conditioner
      GENERIC MAP ( DEBOUNCE_CYCLES => DEBOUNCE_CYCLES, ACTIVE_LOW => BTN_ACTIVE_LOW )
      PORT MAP ( clk => CLOCK_50, rst => rst, btn_in => btn_jump,
                 btn_level => jump_lv, btn_pulse => jump_p );
   btn_dash_u : ENTITY work.btn_conditioner
      GENERIC MAP ( DEBOUNCE_CYCLES => DEBOUNCE_CYCLES, ACTIVE_LOW => BTN_ACTIVE_LOW )
      PORT MAP ( clk => CLOCK_50, rst => rst, btn_in => btn_dash,
                 btn_level => dash_lv, btn_pulse => dash_p );
   btn_duck_u : ENTITY work.btn_conditioner
      GENERIC MAP ( DEBOUNCE_CYCLES => DEBOUNCE_CYCLES, ACTIVE_LOW => BTN_ACTIVE_LOW )
      PORT MAP ( clk => CLOCK_50, rst => rst, btn_in => btn_duck,
                 btn_level => duck_lv, btn_pulse => duck_p );
   btn_start_u : ENTITY work.btn_conditioner
      GENERIC MAP ( DEBOUNCE_CYCLES => DEBOUNCE_CYCLES, ACTIVE_LOW => BTN_ACTIVE_LOW )
      PORT MAP ( clk => CLOCK_50, rst => rst, btn_in => btn_start,
                 btn_level => start_lv, btn_pulse => start_p );


   sync_u : ENTITY work.vga_sync
      GENERIC MAP ( H_DISP => H_DISP, H_FP => H_FP, H_RET => H_RET, H_BP => H_BP,
                    V_DISP => V_DISP, V_FP => V_FP, V_RET => V_RET, V_BP => V_BP )
      PORT MAP ( clk => CLOCK_50, rst => rst, pix_ce => pix_ce,
                 hsync => hsync_i, vsync => vsync_i, video_on => video_on,
                 pixel_x => pixel_x, pixel_y => pixel_y, frame_tick => frame_tick );

   ----------------------------------------------------------- FSM del juego
   game_u : ENTITY work.game_fsm
      PORT MAP ( clk => CLOCK_50, rst => rst, start_p => start_p,
                 goal_ev => goal_ev, dead_ev => dead_ev,
                 run_en => run_en, init => init_p,
                 state_code => game_state, lives => lives );

   --------------------------------------------------- Personaje (fisicas)
   player_u : ENTITY work.player_engine
      GENERIC MAP ( SPAWN_X => SPAWN_X, SPAWN_Y => SPAWN_Y )
      PORT MAP ( clk => CLOCK_50, rst => rst, frame_tick => frame_tick,
                 run_en => run_en, init => init_p,
                 btn_left => left_lv, btn_right => right_lv, btn_duck => duck_lv,
                 btn_jump_lv => jump_lv,
                 jump_pulse => jump_p, dash_pulse => dash_p,
                 pos_x => pos_x, pos_y => pos_y, facing_left => facing_left,
                 duck_on => duck_on, dash_avail_o => dash_avail,
                 on_ground_o => on_ground, jumps_left_o => jumps_left,
                 mode_code => mode_code, goal_ev => goal_ev, dead_ev => dead_ev );

   ------------------------------------------------------------- Cronometro
   time_u : ENTITY work.time_counter
      GENERIC MAP ( FRAMES_PER_SEC => FRAMES_PER_SEC )
      PORT MAP ( clk => CLOCK_50, rst => rst, clr => init_p, ena => run_en,
                 frame_tick => frame_tick,
                 sec_u => sec_u, sec_t => sec_t, sec_h => sec_h );

   ---------------------------------------------------------- Pixel Generate
   pixel_u : ENTITY work.pixel_gen
      PORT MAP ( clk => CLOCK_50, pix_ce => pix_ce,
                 hsync_i => hsync_i, vsync_i => vsync_i, video_on => video_on,
                 pixel_x => pixel_x, pixel_y => pixel_y,
                 pos_x => pos_x, pos_y => pos_y, facing_left => facing_left,
                 duck_on => duck_on, dash_avail => dash_avail,
                 game_state => game_state,
                 vga_hs => VGA_HS, vga_vs => VGA_VS,
                 vga_r => VGA_R, vga_g => VGA_G, vga_b => VGA_B );


   hex3_u : ENTITY work.seg7_decoder PORT MAP ( bcd => lives, seg => HEX3 );
   hex2_u : ENTITY work.seg7_decoder PORT MAP ( bcd => sec_h, seg => HEX2 );
   hex1_u : ENTITY work.seg7_decoder PORT MAP ( bcd => sec_t, seg => HEX1 );
   hex0_u : ENTITY work.seg7_decoder PORT MAP ( bcd => sec_u, seg => HEX0 );
      
   LEDG(0)          <= on_ground;
   LEDG(1)          <= dash_avail;
   LEDG(2)          <= jumps_left;
   LEDG(3)          <= duck_on;
   LEDG(6 DOWNTO 4) <= mode_code;
   LEDG(9 DOWNTO 7) <= game_state;

END ARCHITECTURE rtl;
