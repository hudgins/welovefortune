pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

game_version = "v20231202"

c_clr_theme = 10 -- 10 yellow, 9 orange

c_num_vowel_cost = shr(25, 16)

-- c_sat_symbol_render = "\-f\|f\^:041f001f001f0400\n\|9\-e  "
-- c_btc_symbol_render = "\-f\|f\^:0a1f120e121f0a00\n\|9\-e  "
-- c_money_padding = "00000" -- fri nov 24, 2023, 100,000 sats is $37.70 usd

c_letters = {
 letters = split("a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z"),
 consonants = split("b,c,d,f,g,h,j,k,l,m,n,p,q,r,s,t,v,w,x,y,z"),
 vowels = split("a,e,i,o,u"),
 symbols = split("1_2_3_4_5_6_7_8_9_0_-_'_’_._,_?_!_%_@_#_$_&_-_(_)", "_", false),
 article_an = split("a,e,f,h,i,l,m,n,o,r,s,x"),
 ranked = {
  letters = split("e,a,r,i,o,t,n,s,l,c,u,d,p,m,h,g,b,f,y,w,k,v,x,z,j,q"),
  consonants = split("r,t,n,s,l,c,d,p,m,h,g,b,f,y,w,k,v,x,z,j,q"),
  vowels = split("e,a,i,o,u"),
 }
}

opponents = split("james_1_let's go_fudge_yay_tax considerations~benny_2_to the moon_poopy diaper_special_stomach upset~barry_3_come on_gosh_excellent_diarrhea~frank_4_let's do this_crap_yes sir_tummy troubles~sarah_5_yeet_dammit_amazing_insane itchiness~petey_6_number go up_damn_awesome_a weird feeling~bjorn_7_fingers crossed_poop_great_feeling sleepy~wanda_8_go go go_bummer_sweet_climate change~gordy_9_go_shoot_boo-yah_stage fright~agnes_10_big money!\nno whammies_darn_hooray_covid-19", "~")

mode_name = ""
puzzle = {}
puzzles_seen = {}

wait_until = 0
wait_callback = nil

function toggle_theme_music(desired_music_playing)
 if (music_playing == desired_music_playing) return
 music_playing = desired_music_playing
 music(desired_music_playing)
end

screens = {}
function screens_start_init()
 screens.start_view = {
  display_time = time()
 }
end
function screens.start_draw()
 local start = screens.start_view
 w_arches_draw()
 w_puzzleboard_draw()

 if (start.display_time + 3.5 < time()) print("by allan hudgins", 32, 110, 7)
 if (start.display_time + 4.5 < time()) then
  color(12)
  print(" heavily-inspired by\nthe commodore 64 game", 22, 116)
  print(game_version, 90, 0, 5)
 end
 if (start.display_time + 6 < time()) print("press x / ❎ button", 26, 100, clr_flashing(true))
end
function screens.start_update()
 local start = screens.start_view
 if (start.display_time + 6 > time()) return
 if (btnp(4) or start.display_time + 15 < time()) return screens_champions_show()
 if (btnp(5)) start_slide({ w_arches, w_puzzleboard }, "off", screens_setup_show)
end

function screens_intermission_init()
 screens.intermission_view = {
  x = 0,
  y = 60,
  w = 127,
  h = 127 - 60,
  slide = "y,60,128",
 }
end
function screens.intermission_draw()
 w_arches_draw()
 w_puzzleboard_draw()

 local view = screens.intermission_view
 local x0, y0, x1, y1 =
   view.x
 , view.y
 , view.x + view.w
 , view.y + view.h

 draw_box(x0, y0, x1, y1, 12)

 local round_name = "round "..game_round + 1
 if (game_round == 3) round_name = "bonus round"
 local x, y = x0 + 4, y0 + 4
 print(round_name.." coming up!", x, y, 7)
 color(0)
 y += 14
 if (view.show_scores) then
  for player in all(game_players) do
   local xx, yy = x + 30, y + (player.idx - 1) * 10 + 5
   print(player.name, xx, yy)
   print(float_to_money_str(player.game_total), xx + 29, yy)
   line(xx - 1, yy + 6, xx + 60, yy + 6)
  end
 else
   print("did you know...\n\n\n\n\n\n\n\|fit's true!", x, y)
   print(screens.intermission_view.fact, x, y + 14)
 end
end
function screens.intermission_update()
 local view = screens.intermission_view
 if (not view.fact) view.fact = rnd(intermission_facts)
 if (view.show_scores) then
   if (any_button()) view.show_scores = false
 else
   if (any_button()) then
    local function all_off()
     view.fact = nil
     next_round(game_round + 1)
    end
    start_slide({ view }, "off", all_off)
   end
 end
end
function screens_intermission_show()
 screens.intermission_view.show_scores = true
 local function done()
  toggle_theme_music(2)
  screen_name = "intermission"
  mode_name = "intermission"
  game_state = "state_intermission"
  start_slide({ screens.intermission_view }, "on")
 end
 start_slide({ w_clue, w_round, w_letterboard, w_scoreboard, w_messageboard, w_wheel }, "off", done)
end

function screens.setup_draw()
 w_arches_draw()
 w_puzzleboard_draw()
 w_clue_draw()
 w_letterboard_draw()

 local x, y = 20, 80
 local time_remaining = ceil(name_timeout - time())
 color(6)
 print("⬅️ ➡️ ⬆️ ⬇️ to select", x, y)
 print("❎ (x) to enter", x, y + 10)
 print("🅾️ (z) to undo", x, y + 20)
 if (#game_players_one.name > 1 and time_remaining > 0 and time_remaining < 3) print("starting game in... "..tostr(time_remaining), x, y + 32, 7)
end
function screens.setup_update()
 if (#game_players_one.name > 1 and name_timeout < time()) then
  start_game()
 elseif (any_button()) then
  name_timeout = time() + 4
 end
end
function screens_setup_show()
 screen_name = "setup"
 w_puzzleboard_init("normal")
 puzzle = to_puzzle("deener", "your name")
 puzzle.revealed = false
 game_players_one.name = ""

 local function on_pick()
  game_players_one.name ..= w_letterboard.letter
  insert_puzzle_guess_letter(w_letterboard.letter)
  if (#game_players_one.name < 6) select_letter_tile_to_insert() else start_game()
 end
 local function on_undo()
  game_players_one.name = sub(game_players_one.name, 1, #game_players_one.name - 1)
  undo_letter_tile_insertion()
 end
 w_letterboard_activate("letters", on_pick, on_undo)
 start_slide({ w_clue, w_letterboard }, "on")
end

screens.round = {}
function screens.round_draw()
 w_arches_draw()
 w_puzzleboard_draw()
 if (game_round == 4) then
  if (bonus_mode == "spin_prize") then
   w_wheel_draw()
   w_messageboard_draw()
  else
   w_clue_draw()
   w_round_draw()
   w_letterboard_draw()
   w_bonusboard_draw()
  end
 else
  w_clue_draw()
  w_round_draw()
  w_letterboard_draw()
  w_wheel_draw()
  w_scoreboard_draw()
  w_messageboard_draw()
 end
end
function screens.round_update()
 if (screens.round[game_state]) screens.round[game_state]()
end
function screens.round.state_wait_action()
 update_chosen_action()

 if (player_chose_spin()) action_spin()
 if (player_chose_vowel()) action_vowel()
 if (player_chose_solve()) action_solve()
end
function screens.round.state_wait_free_spin()
 update_chosen_action()
 if (player_uses_free_spin()) then
  game_active_player.free_spins -= 1
  update_actions_available()
 elseif (player_passes()) then
  next_player()
 end
end
function screens.round.state_spin()
 if (not w_wheel.spinning and player_adjusting_power()) then
  if (w_wheel.start_power_sound) then
   sfx(7, 2)
   w_wheel.start_power_sound = false
  else
   if (w_wheel.speed < 30 and w_wheel.speed > 20) w_wheel.start_power_sound = true
  end
  adjust_power()
 else
  sfx(-2, 2)
  if (w_wheel.spinning) adjust_spin() else start_stop_spin()
 end
end
function screens.round.state_spin_completed()
 game_state = "state_wait"
 if (game_round == 4) then
  sfx(w_wheel.item_name == "nothing" and 3 or 0)
  w_messageboard_set_message("a "..w_wheel.item_name.."\nworth "..render_money(w_wheel.item_value).."!")
  num_grand_prize = shr(w_wheel.item_value, 16)
  delay(start_bonus_round, 2)
 elseif (w_wheel.item_name == "bankrupt") then
  start_shake(3, 20, {
   w_wheel,
   w_scoreboard,
   w_messageboard,
   w_letterboard,
   w_clue,
   w_round,
   w_arches,
   w_puzzleboard
  })
  w_messageboard_set_message(game_active_player.cuss.."!~player")
  delay(event_bankrupt)
 elseif (w_wheel.item_name == "freespin") then
  sfx(6)
  w_messageboard_set_message(game_active_player.cheer.."!~player")
  delay(event_freespin)
 elseif (w_wheel.item_name == "loseturn") then
  start_shake(4, 10, { w_wheel })
  w_messageboard_set_message(game_active_player.cuss.."!~player")
  delay(event_loseturn)
 else
  sfx(0)
  w_messageboard_set_message(w_wheel.item_name)
  delay(action_consonant)
 end
end
function action_consonant()
 w_messageboard_set_message("choose a letter.")
 if (game_active_player.human) then
  local function on_pick()
   mode_name = ""
   guess_letter("consonant")
  end
  w_letterboard_activate("consonants", on_pick)
 else
  guess_letter("consonant", cpu_player_guess_letter("consonants"))
 end
end
function action_vowel()
 if (not game_can_buy_vowel) return

 w_messageboard_set_message("i'd like to\nbuy a vowel!~player")
 if (game_active_player.human) then
  local function on_pick()
   mode_name = ""
   guess_letter("vowel")
  end
  w_letterboard_activate("vowels", on_pick)
 else
  guess_letter("vowel", cpu_player_guess_letter("vowels"))
 end
end

function bonus_choose_letters()
 game_state = "state_bonus_letters"
 w_bonusboard.lines = split("for the "..float_to_money_str(num_grand_prize).." "..w_wheel.item_name.."^^choose 3 consonants:^_ _ _^and one vowel:^_", "^")
 local function on_pick()
  local letter = w_letterboard.letter
  if (w_bonusboard.consonants < 3) then
   w_bonusboard.consonants += 1
   w_bonusboard.lines[w_bonusboard.consonant_line] = ""
   add(w_bonusboard.letters, letter)
   for i = 1,3 do
    w_bonusboard.lines[w_bonusboard.consonant_line]
     = w_bonusboard.lines[w_bonusboard.consonant_line]..(w_bonusboard.letters[i] or "_").." "
   end
   w_letterboard.list = "consonants"
  else
   w_bonusboard.vowels += 1
   add(w_bonusboard.letters, letter)
   w_bonusboard.lines[w_bonusboard.vowel_line] = letter
  end
  if (w_bonusboard.consonants == 3 and w_bonusboard.vowels == 0) then
   w_letterboard.list = "vowels"
   w_bonusboard.idx = 7
  elseif (w_bonusboard.vowels == 1) then
   mode_name = ""
   w_bonusboard.lines = split(",let's see how you did!")
   reveal_letters(w_bonusboard.letters, action_solve)
  end
 end
 local function on_undo()
  if (w_bonusboard.consonants > 0) then
   w_bonusboard.consonants -= 1
   w_bonusboard.lines[w_bonusboard.consonant_line] = ""
   deli(w_bonusboard.letters)
   for i = 1,3 do
    w_bonusboard.lines[w_bonusboard.consonant_line]
     = w_bonusboard.lines[w_bonusboard.consonant_line]..(w_bonusboard.letters[i] or "_").." "
   end
  end
 end
 w_letterboard_activate("consonants", on_pick, on_undo)
end

function screens_champions_init()
 screens.champions_view = {
  x = 0,
  y = 0,
  w = 127,
  h = 127
 }
end
function screens.champions_draw()
 local view = screens.champions_view
 local x0, y0, x1, y1 =
   view.x
 , view.y
 , view.x + view.w
 , view.y + view.h
 draw_box(x0, y0, x1, y1, c_clr_theme)
 x0 += 10
 y0 += 10
 print("champions", x0 + 36, y0)
 line(x0 + 36, y0 + 6, x0 + 70, y0 + 6)
 x0 += 10
 y0 += 15
 for i=1,#champions_list do
  if (view.display_time + i * 0.1 > time()) break
  local name = champions_list[i].name
  local score = float_to_money_str(champions_list[i].score)
  local name_colour = name == game_active_player.name and clr_flashing(true, 0, c_clr_theme) or 0
  print(i..". "..name, x0, y0, name_colour)
  print(score, x0 + 80 - (#score * 4), y0)
  y0 += 8
 end
 print("press x / ❎ button", 26, 100)
end
function screens.champions_update()
 if (screens.champions_view.display_time + 10 < time() or any_button()) restart()
end
function screens_champions_show()
 toggle_theme_music(0)
 screens.champions_view.display_time = time()
 screen_name = "champions"
 save_champs()
end

function w_arches_init()
 w_arches = {
  x = 0,
  lx = 39,
  rx = 87,
  y = 56,
  slide = "y,56,21",
  outr = 38,
  inr = 28,
  color = c_clr_theme
 }
end
function w_arches_draw()
 local y, lx, rx =
   w_arches.y
 , w_arches.x + w_arches.lx
 , w_arches.x + w_arches.rx
 circfill(lx, y, w_arches.outr, w_arches.color)
 circfill(rx, y, w_arches.outr, w_arches.color)
 color(0)
 circfill(lx, y, w_arches.inr)
 circfill(rx, y, w_arches.inr)
 rectfill(lx + 20, y - 21, rx - 20, y - 20)
 rectfill(lx - 13, y + 20, rx + 13, y + 38)
 rectfill(lx - 13, y + 26, rx + 13, y + 35, w_arches.color)
 color(3)
 local yds = { -19, -17, -16, -15, -13, -11 }
 local sides = { 1, -1 }
 local xd, xdr = 19, 107
 for yd in all(yds) do
  xd -= 1
  xdr += 1
  for side in all(sides) do
   for py = y + yd * side, y + (-11 * side), side do
    pset(xd, py)
    pset(xdr, py)
   end
  end
 end
end

function w_puzzleboard_init(mode)
 w_puzzleboard = {
  x = 4,
  y = mode == "normal" and 2 or 37,
  slide = "y,37,2"
 }

 local w, h = 6, 8
 w_puzzleboard.cells = {}
 for row = 1,4 do
  for col = 1,13 do
   local edge_offset = (row == 1 or row == 4) and w + 2 or 0
   if (not ((row == 1 or row == 4) and col > 11)) then
    add(w_puzzleboard.cells, {
     x = w * col + (col * 2) + w_puzzleboard.x + edge_offset,
     y = h *(row - 1) + ((row - 1) * 2) + w_puzzleboard.y,
     w = w,
     h = h,
     row = row,
     col = col,
    })
   end
  end
 end
end
function w_puzzleboard_draw()
 for c in all(w_puzzleboard.cells) do
  local w, h, row, col, x, y = c.w , c.h , c.row , c.col , c.x , c.y

  if (not c.shake or c.shake == 0) then
   local edge_offset = (row == 1 or row == 4) and w + 2 or 0
   x = w * col + (col * 2) + w_puzzleboard.x + edge_offset
   y = h *(row - 1) + ((row - 1) * 2) + w_puzzleboard.y
  end

  rectfill(x, y, x + w, y + h, 3)
  if (#puzzle.tiles[row] >= col) then
   local cell = puzzle.tiles[row][col]
   if (cell.letter) then
    c.letter = cell.letter
    c.revealed = cell.revealed
    if (cell.revealed or puzzle.revealed) then
     rectfill(x, y, x + w, y + h, 7)
     print(cell.letter, x + 2, y + 2, 0)
    elseif (cell.selected) then
     rectfill(x, y, x + w, y + h, clr_flashing())
    elseif (cell.guessed_letter) then
     rectfill(x, y, x + w, y + h, 7)
     print(cell.guessed_letter, x + 2, y + 2, 0)
    else
     rectfill(x , y, x + w, y + h, 6)
    end
   end
  end
 end
end

function w_letterboard_init()
 w_letterboard = {
  x = 11,
  y = 52,
  h = 20,
  slide = "x,11,128",
  cellh = 8,
  cellw = 6,
  list = "letters",
  letter = "a",
  letter_idx = 1,
  remaining = {}
 }
 w_letterboard.w = (w_letterboard.cellw*13) + (2*13)
 for l in all(c_letters.letters) do
  w_letterboard.remaining[l] = { letter = l, available = true, selected = false }
 end
end
function w_letterboard_draw()
 local h, w, fullw = w_letterboard.cellh, w_letterboard.cellw, w_letterboard.w
 rectfill(w_letterboard.x, w_letterboard.y,
          w_letterboard.x + fullw,
          w_letterboard.y + w_letterboard.h, 5)
 local x, y = w_letterboard.x + 1, w_letterboard.y + 1
 for l in all(c_letters.letters) do
  if (l == "n") then
   y += 10
   x = w_letterboard.x + 1
  end
  if (w_letterboard.remaining[l].available) then
   if (w_letterboard.remaining[l].selected) then
    rectfill(x, y, x + w, y + h, clr_flashing())
    print(l, x + 2, y + 2, 0)
   elseif (w_letterboard.remaining[l].hidden) then
    rectfill(x, y, x + w, y + h, 1)
    print(l, x + 2, y + 2, 0)
   else
    rectfill(x, y, x + w, y + h, 1)
    print(l, x + 2, y + 2, 7)
   end
  end
  x += w + 2
 end
end
function w_letterboard_update()
 local starting_letter = nil
 for letter in all(c_letters.letters) do
  local l = w_letterboard.remaining[letter]
  l.hidden = true
  l.selected = w_letterboard.letter == letter
  if (l.selected) starting_letter = l
 end
 for letter in all(c_letters[w_letterboard.list]) do
  local l = w_letterboard.remaining[letter]
  l.hidden = false
 end

 local dir = nil
 if (btnp(0)) dir = "left"
 if (btnp(1)) dir = "right"
 if (btnp(2)) dir = "up"
 if (btnp(3)) dir = "down"

 if (not dir and (starting_letter.hidden or not starting_letter.available)) dir = "right"
 if (dir) then
  select_letter(dir)

  if (w_letterboard.letter) w_letterboard.remaining[w_letterboard.letter].selected = false

  local selected_letter = false
  while (not selected_letter) do
   w_letterboard.letter = c_letters.letters[w_letterboard.letter_idx]
   if (w_letterboard.letter) then
    local remaining = w_letterboard.remaining[w_letterboard.letter]
    if (remaining.available and not remaining.hidden) then
     w_letterboard.remaining[w_letterboard.letter].selected = true
     selected_letter = true
    else
     select_letter(dir)
    end
   else
    select_letter(dir)
   end
  end
 end

 if (btnp(5) and w_letterboard.on_pick) then
  w_letterboard.remaining[w_letterboard.letter].selected = false
  w_letterboard.on_pick()
 end
 if (btnp(4) and w_letterboard.on_undo) w_letterboard.on_undo()
end
function w_letterboard_unhide_all()
 for letter in all(c_letters.letters) do
  local l = w_letterboard.remaining[letter]
  l.hidden = false
 end
end
function w_letterboard_activate(list, on_pick, on_undo)
 mode_name = "letter_pick"
 w_letterboard.list = list
 w_letterboard.on_pick = on_pick
 w_letterboard.on_undo = on_undo
end

function w_scoreboard_init()
 w_scoreboard = {
  x = 56,
  y = 74,
  w = 128 - 56,
  h = 34,
  slide = "x,56,128",
 }
end
function w_scoreboard_draw()
 local x0, y0, x1, y1 =
   w_scoreboard.x,
   w_scoreboard.y
 , w_scoreboard.x + w_scoreboard.w
 , w_scoreboard.y + w_scoreboard.h
 -- scoreboard
 rectfill(x0, y0, x1, y1, 12)

 -- names
 color(7)
 rectfill(x0, y0 + (game_active_player.idx - 1) * 10 + 2, x1, y0 + game_active_player.idx * 10 + 2)
 color(0)
 rect(x0, y0 + 2, x1, y0 + 12)
 rect(x0, y0 + 12, x1, y0 + 12)
 rect(x0, y0 + 22, x1, y0 + 12)
 rect(x0, y0 + 32, x1, y0 + 2)
 rect(x0, y0, x1, y1)
 line(x0 + 30, y0, x0 + 30, y1) -- divider

 -- free spins
 for player in all(game_players) do
  for i=1,player.free_spins do
   local side = flr(i / 5) -- 0 for right, 1 for left
   local slot = (i < 5 and i or i - 4) * 2
   pset(x0 + 30 - 2 + (side * -26), y0 + (player.idx * 10) + 2 - slot)
  end

  -- alternate showing round/game totals
  local total_to_show = "round_total"
  if (game_round > 1 and
      game_state == "state_wait_action" and
      game_active_player == game_players_one and
      time_since_input + 5 < time()) then
   total_to_show = "game_total"
   if (player.idx == 1) print("prior", x0 + 4, y0 + (player.idx - 1) * 10 + 5)
   if (player.idx == 2) print("rounds", x0 + 4, y0 + (player.idx - 1) * 10 + 5)
   if (player.idx == 3) print("totals", x0 + 4, y0 + (player.idx - 1) * 10 + 5)
  else
   print(player.name, x0 + 4, y0 + (player.idx - 1) * 10 + 5)
  end
  print(float_to_money_str(player[total_to_show]), x0 + 33, y0 + (player.idx -1 ) * 10 + 5)
 end
end

wheel_items = {
 split("bankrupt_0,35_14,25_13,60_9,40_8,15_12,25_14,40_9,20_13,loseturn_10,45_8,15_12,20_9,70_14,freespin_11,20_8,30_12,40_13,50_10,100_14,20_9,30_8,80_12,75_10"),
 split("bankrupt_0,60_14,20_12,100_10,60_8,30_14,70_9,45_12,15_13,80_8,loseturn_10,50_14,40_12,25_13,bankrupt_0,90_9,30_8,25_12,90_10,20_14,40_12,55_13,20_9,50_8"),
 split("bankrupt_0,150_10,35_14,90_9,30_8,25_12,90_10,20_14,40_12,55_13,20_9,50_8,bankrupt_0,60_14,20_12,loseturn_10,35_13,25_8,50_12,500_7,30_14,80_8,50_12,70_13"),
 split("bitcoin_9_9900,plant_14_3,vacation_10_800,shed_8_85,bicycle_12_70,scooter_10_180,watch_14_12,c64_12_50,tuque_13_3,phone_8_120,computer_10_300,tree_12_110,lamp_14_21,tv_12_333,table_10_158,couch_13_423,truck_8_4500,t-shirt_12_1,cat_10_25,dog_14_35,boat_8_2500,hot tub_12_700,car_13_3900,vacuum_10_8"),
}
function w_wheel_init(round)
 if (round > 4) return
 local items = wheel_items[round]
 local first = split(items[1], "_")
 w_wheel = {
  x = 24,
  y = 100,
  slide = "x,24,-48",
  radius = 24,
  middle_radius = 8,
  power = "up",
  speed = 0,
  tick = 0.01,
  pick = 1,
  spinning = false,
  items = items,
  item_name = first[1],
  item_value = first[3] or 0,
  item_colour = first[2],
  item_names = {},
  item_values = {},
  item_colours = {},
  spokes = {}
 }
 for s=1,#items do
  local item = split(items[s], "_")
  w_wheel.item_values[s] = tonum(item[1]) or item[3] or 0
  w_wheel.item_names[s] = item[3] and item[1] or render_money(w_wheel.item_values[s])
  w_wheel.item_colours[s] = item[2]
  if (w_wheel.item_values[s] == 0) w_wheel.item_names[s] = item[1]
 end

 -- generate spokes to fill out wheel
 local f, slices, slice, prev_x, prev_y = 100, 24, 0, nil, nil
 local lines = slices * f
 for i=1,lines do
  slice = ceil(i/f)
  local delta = (i-1)/lines - w_wheel.tick
  local x, y =
    flr(w_wheel.x + cos(delta) * w_wheel.radius)
  , flr(w_wheel.y + sin(delta) * w_wheel.radius)
  if (prev_x != x or prev_y != y) then
   add(w_wheel.spokes, { x = x - w_wheel.x, y = y - w_wheel.y }) -- x,y tied to current wheel x for sliding
   prev_x, prev_y = x, y
  end
 end
end
function w_wheel_draw()
 local start_spoke = flr((w_wheel.tick * 1000) / (1000 / #w_wheel.spokes)) + 1
 local spokes_per_slice = #w_wheel.spokes / 24
 for i=1,#w_wheel.spokes do
  local spoke = w_wheel.spokes[i]
  local slice = flr((start_spoke + (i-1)) / spokes_per_slice) + 1
  if (slice > 24) slice -= 24
  line(w_wheel.x, w_wheel.y, w_wheel.x + spoke.x, w_wheel.y + spoke.y, w_wheel.item_colours[slice])
 end
 circfill(w_wheel.x, w_wheel.y, w_wheel.middle_radius, 3)

 local bg_colour = w_wheel.item_colour
 -- power
 if (w_wheel.speed > 0) then
  local center_colour = w_wheel.speed > 100 and bg_colour or 11
  circfill(w_wheel.x, w_wheel.y, (w_wheel.middle_radius) * (w_wheel.speed / 100), center_colour)
 end
 -- wheel item
 local fg_colour, border_colour  =
   bg_colour == 0 and 7 or 0
 , bg_colour == 7 and 0 or 7
 local x, y, i = w_wheel.x + 25, 75, 1
 rectfill(x, y, x + 6, y + 50, bg_colour)
 rect(x, y, x + 6, y + 50, border_colour)
 rectfill(x - 3, y + 25, x, y + 27, border_colour)
 if (w_wheel.just_ticked) line(x - 5, y + 28, x - 1, y + 26, 8) else line(x - 5, y + 26, x - 1, y + 26, 8)
 y -= 4
 color(fg_colour)
 for l in all(w_wheel.item_name) do
  print(l, x + 2, y + 6 * i)
  i += 1
 end
end

function w_messageboard_init()
 local x, y =
   w_scoreboard.x + 1
 , w_scoreboard.y + w_scoreboard.h + 1
 w_messageboard = {
  x = x,
  y = y,
  slide = "y,"..y..",128",
  choice = "spin",
  choice_idx = 1,
  choices = {}
 }
end
function w_messageboard_draw()
 local x0, y0 =
   w_messageboard.x
 , w_messageboard.y
 local x1, y1 =
   x0 + w_scoreboard.w - 2
 , y0 + 16
 draw_box(x0, y0, x1, y1, c_clr_theme)
 local indicator_colour = 0
 if (mode_name == "action") indicator_colour = clr_flashing(false, 0, c_clr_theme)
 if (w_messageboard.message_displayed) then
  print(w_messageboard.line, x0 + 3, y0 + 3)
  if (w_messageboard.speaker == "player") print("😐", x0 + 61, y0 + 9)
 elseif (game_state == "state_wait_action") then
  if (game_can_spin) then
   if (w_messageboard.choice == "spin") print("❎", x0 + 8, y0 + 3, indicator_colour)
   print("spin", x0 + 4, y0 + 9, 0)
  end
  if (game_can_buy_vowel) then
   if (w_messageboard.choice == "vowel") print("❎", x0 + 24 + 6, y0 + 3, indicator_colour)
   print("vowel", x0 + 24, y0 + 9, 0)
  end
  if (w_messageboard.choice == "solve") print("❎", x0 + 48 + 6, y0 + 3, indicator_colour)
  print("solve", x0 + 48, y0 + 9, 0)
 elseif (game_state == "state_wait_free_spin") then
  if (w_messageboard.choice == "free spin") print("❎", x0 + 18, y0 + 3, indicator_colour)
  print("free spin", x0 + 4, y0 + 9, 0)
  if (w_messageboard.choice == "pass") print("❎", x0 + 48 + 7, y0 + 3, indicator_colour)
  print("pass", x0 + 48 + 3, y0 + 9, 0)
 end
end
function w_messageboard_set_message(message)
 local parsed = split(message, "~")
 w_messageboard.line = parsed[1]
 w_messageboard.message_displayed = true
 w_messageboard.speaker = parsed[2]
end

function w_bonusboard_init()
 w_bonusboard = {
  x = 11,
  y = 75,
  slide = "y,75,128",
  lines = {},
  letters = {},
  consonant_line = 4,
  vowel_line = 6,
  consonants = 0,
  vowels = 0
 }
end
function w_bonusboard_draw()
 local x0, y0 =
   w_bonusboard.x
 , w_bonusboard.y
 local x1, y1 =
   w_bonusboard.x + w_letterboard.w
 , y0 + (127 - y0)
 draw_box(x0, y0, x1, y1, c_clr_theme)

 for line in all(w_bonusboard.lines) do
  y0 += 7
  print(line, x0 + 6, y0)
 end
end

function w_clue_init()
 w_clue = {
  x = 4,
  y = 43,
  slide = "x,4,-128",
 }
end
function w_clue_draw()
 local x, y = w_clue.x, w_clue.y
 rectfill(x - 2, y, x + 128, y + 8, 0)
 print("clue: "..puzzle.clue, x, y + 2, c_clr_theme)
end

function w_round_init()
 w_round = {
  x = 92,
  y = 43,
  slide = "x,92,128",
 }
end
function w_round_draw()
 local x, y = w_round.x, w_round.y
 rectfill(x - 2, y, x + 40, y + 8, 0)
 if (game_round == 4) print("   bonus", x, y + 2, 12) else print("     r-"..game_round, x, y + 2, 12) 
end

-- max 8
champions_list = {}

function _init()
 cartdata("wob_cart_data_v2")
 load_champs()
 restart()
end

function load_champs()
 local entry_width = 7
 for entry=0,7 do -- 8 entries
  local current_name = ""
  for offset=0,5 do -- 6 letters per name
   local char = chr(dget(entry * entry_width + offset))
   if (ord(char) != 0) current_name ..= char
  end
  if (current_name != "") champions_list[entry + 1] = { name = current_name, score = dget(entry * 7 + 6) }
 end
 -- if champions list is empty, fill it with defaults
 if (not champions_list[1]) then
  for i=1,8 do
   champions_list[i] = { name = split(opponents[i], "_")[1], score = shr(340 - i * 40, 16) }
  end
 end
end

function save_champs()
 for i=0,63 do
  dset(i, 0)
 end
 local start = 0
 for entry in all(champions_list) do
  for i=1,6 do
   dset(start, ord(entry.name, i) or 0)
   start += 1
  end
  dset(start, entry.score)
  start += 1
 end
end

function restart()
 unflash()
 event_queue = {}
 mode_name = ""
 screen_name = "start"
 name_timeout = 0

 game_state = "state_start"
 bonus_mode = nil
 game_round = 1
 game_only_vowels_remain_in_puzzle = false
 game_only_vowels_remain_on_board = false
 game_no_vowels_remain_on_board = false
 game_all_letters_revealed = false
 game_can_spin = true
 game_can_buy_vowel = false
 game_players_one = create_player(1, "")
 game_players_cpu1 = create_player(2)
 game_players_cpu2 = create_player(3)
 game_players = { game_players_one, game_players_cpu1, game_players_cpu2 }
 game_active_player = game_players_one
 game_cpu_delay = 0

 puzzle = to_puzzle("", "")

 w_arches_init()
 w_puzzleboard_init()
 w_letterboard_init()
 w_scoreboard_init()
 w_messageboard_init()
 w_clue_init()
 w_round_init()
 w_wheel_init(1)
 w_bonusboard_init()

 screens_start_init()
 screens_intermission_init()
 screens_champions_init()

 local function reveal_puzzle()
  toggle_theme_music(0)
  puzzle = to_puzzle("we love fortune^ -1980's^ edition", "")
  local function reveal_title()
   puzzle.revealed = true
  end
  delay(reveal_title, 0.5)
 end
 delay(reveal_puzzle, 0.5)
end

function create_player(idx, name)
 return {
  idx = idx,
  name = name,
  human = idx == 1,
  free_spins = 0,
  game_total = 0,
  round_total = 0,
  shout = "we love\nfortune",
  cuss = "darnies",
  cheer = "nice"
 }
end

function delay(cb, factor)
 local seconds = 2 * (factor or 1)
 if (wait_until > time()) then
  if (cb and not wait_callback) then
   wait_until += seconds
   wait_callback = cb
  end
 else
  wait_until = time() + seconds
  wait_callback = cb
 end
end

function queue(fn, on_time)
 add(event_queue, { run = fn, time = on_time })
end

function acknowledge_player_input()
 if (not game_active_player.human or player_adjusting_power()) return

 if (btnp(0) or
  btnp(1) or
  btnp(2) or
  btnp(3)) then
  sfx(8)
  unflash()
 elseif (btnp(4)) then
  sfx(10)
  unflash()
 elseif (btnp(5)) then
  sfx(9)
  unflash()
 end
end

function _update()
 if (slide()) return
 shake()

 if (wait_until > time()) return
 if (wait_callback) then
  local cb = wait_callback
  wait_callback = nil
  cb()
 end

 if (#event_queue > 0) then
  local event_pending = false
  for event in all(event_queue) do
   if (not event.invoked and event.time < time()) then
    event.invoked = true
    event.run()
   elseif (not event.invoked) then
    event_pending = true
   end
  end
  if (not event_pending) event_queue = {}
 end

 acknowledge_player_input()

 if (mode_name == "letter_pick") w_letterboard_update() else w_letterboard_unhide_all()

 local update_method = screen_name.."_update"
 if (screens[update_method]) screens[update_method]()
end

function player_chose_spin()
 if (game_active_player.human) then
  return btnp(5) and w_messageboard.choice == "spin"
 else
  return cpu_player_choose_action() == "spin"
 end
end

function cpu_player_choose_action()
 local other_cpu = game_players_cpu1
 if (game_active_player == game_players_cpu1) other_cpu = game_players_cpu2

 local choice = "solve"
 local count = count_letter_in_puzzle("*")
 -- if not many letters remaining
 if (count < #puzzle.letters / 4) then
  -- and player will be in the lead
  if (game_active_player.game_total + game_active_player.round_total > other_cpu.game_total) then
   choice = "solve"
  end
 elseif (game_can_buy_vowel) then
  choice = "vowel"
 elseif (game_can_spin) then
  choice = "spin"
 end
 
 return choice
end

function player_chose_vowel()
 if (game_active_player.human) then
  return btnp(5) and w_messageboard.choice == "vowel"
 else
  return cpu_player_choose_action() == "vowel"
 end
end

function cpu_player_guess_letter(kind)
 if (kind == "puzzle") return "*"

 local choice, offset = nil, 1
 while (not choice) do
  local n, l
  if (game_active_player.skill > 5) then
   n = c_letters.ranked[kind][offset]
   l = w_letterboard.remaining[n]
  else
   n = ceil(rnd(#c_letters[kind]))
   l = w_letterboard.remaining[c_letters[kind][n]]
  end
  if (l.available) then
   choice = l.letter
   return choice
  else
   offset += 1
  end
 end
 return choice
end

function cpu_player_guess_puzzle()
 unflash()
 w_letterboard.remaining[w_letterboard.letter].selected = false
 sfx(9)
 local all_done, actual_letter = insert_puzzle_guess_letter("*")
 w_letterboard.letter = actual_letter
 w_letterboard.remaining[w_letterboard.letter].selected = true
 if (all_done) puzzle_guess_letter("*") else delay(cpu_player_guess_puzzle, rnd(0.25) + 0.05)
end

function player_chose_solve()
 if (game_active_player.human) then
  return btnp(5) and w_messageboard.choice == "solve"
 else
  return cpu_player_choose_action() == "solve"
 end
end

function player_adjusting_power()
 if (game_state != "state_spin") return false
 if (game_active_player.human) then
  return btn(5) and w_messageboard.choice == "spin"
 else
  return ceil(rnd(100)) < 95
 end
end

function player_uses_free_spin()
 if (game_active_player.human) then
  return btnp(5) and w_messageboard.choice == "free spin"
 else
  return true
 end
end

function player_passes()
 if (game_active_player.human) then
  return btnp(5) and w_messageboard.choice == "pass"
 else
  return false
 end
end

function update_chosen_action()
 if (btnp(0)) then
  w_messageboard.choice_idx -= 1
  if (not w_messageboard.choices[w_messageboard.choice_idx]) w_messageboard.choice_idx = 1
 elseif (btnp(1)) then
  w_messageboard.choice_idx += 1
  if (not w_messageboard.choices[w_messageboard.choice_idx]) w_messageboard.choice_idx = #w_messageboard.choices
 end
 w_messageboard.choice = w_messageboard.choices[w_messageboard.choice_idx]
end

function puzzle_guess_letter(letter, custom_handling)
 local all_done, correct = insert_puzzle_guess_letter(letter), false
 if (all_done) then
  correct = check_puzzle_correctness()
  if (correct) then
   game_state = "state_won"
   puzzle.revealed = true
   sfx(6)
   if (custom_handling) return all_done, correct

   w_messageboard_set_message("congratulations!\nthat's correct!")
   delay(end_round)
  else
   start_shake()
   if (custom_handling) return all_done, correct

   w_messageboard_set_message("sorry, that is\nincorrect.")
   delay(event_loseturn)
  end
 end
 return all_done, correct
end

function update_actions_available(state)
 game_state = state or "state_wait_action"
 mode_name = "action"

 game_only_vowels_remain_in_puzzle = true
 game_only_vowels_remain_on_board = true
 game_no_vowels_remain_on_board = true
 game_all_letters_revealed = true
 game_can_spin = false
 game_can_buy_vowel = false

 for letter in all(c_letters.letters) do
  local l = w_letterboard.remaining[letter]
  if (l.available) then
   if (is_vowel(l.letter)) game_no_vowels_remain_on_board = false else game_only_vowels_remain_on_board = false
  end
 end

 for row in all(puzzle.tiles) do
  for cell in all(row) do
   if (cell.letter and not cell.revealed) then
    game_all_letters_revealed = false
    if (not is_vowel(cell.letter)) game_only_vowels_remain_in_puzzle = false
   end
  end
 end

 game_can_spin = not game_all_letters_revealed and not game_only_vowels_remain_in_puzzle and not game_only_vowels_remain_on_board
 game_can_buy_vowel = not game_all_letters_revealed and not game_no_vowels_remain_on_board and game_active_player.round_total >= c_num_vowel_cost

 w_messageboard.message_displayed = false
 w_messageboard.choices = {}
 w_messageboard.choice_idx = 1
 if (game_state == "state_wait_free_spin") then
  add(w_messageboard.choices, "free spin")
  add(w_messageboard.choices, "pass")
 else
  if (game_can_spin) add(w_messageboard.choices, "spin")
  if (game_can_buy_vowel) add(w_messageboard.choices, "vowel")
  if (not bonus_mode) add(w_messageboard.choices, "solve")
 end
end

function check_puzzle_correctness()
 local correct = true
 for row in all(puzzle.tiles) do
  for cell in all(row) do
   if (cell.guessed_letter and cell.guessed_letter != cell.letter) correct = false
  end
 end

 -- unguess or reveal all
 for row in all(puzzle.tiles) do
  for cell in all(row) do
   if (cell.letter) then
    cell.guessed_letter, cell.selected = nil, false
   end
  end
 end

 return correct
end

function select_letter_tile_to_insert()
 for row in all(puzzle.tiles) do
  for cell in all(row) do
   cell.selected = false
   if (cell.letter and not cell.revealed and not cell.guessed_letter) then
    cell.selected = true
    return
   end
  end
 end
end

function undo_letter_tile_insertion()
 local prev = nil
 for row in all(puzzle.tiles) do
  for cell in all(row) do
   if (cell.selected) then
    cell.selected, cell.guessed_letter = false, nil
    if (prev) then
     prev.selected, prev.guessed_letter = true, nil
    end
    return
   end
   if (cell.guessed_letter) prev = cell
  end
 end
end

function insert_puzzle_guess_letter(letter)
 local done = false
 for row in all(puzzle.tiles) do
  if (done) break
  for cell in all(row) do
   if (cell.letter and not cell.revealed and not cell.guessed_letter) then
    cell.guessed_letter = letter
    if (letter == "*") then
     cell.guessed_letter, letter = cell.letter, cell.letter
    end
    done = true
    break
   end
  end
 end

 local all_done = true
 for row in all(puzzle.tiles) do
  for cell in all(row) do
   if (cell.letter and not cell.revealed and not cell.guessed_letter) return false, letter
  end
 end

 return all_done, letter
end

function is_vowel(letter)
 for v in all (c_letters.vowels) do
  if (v == letter) return true
 end
 return false
end

function article(letter)
 for l in all(c_letters.article_an) do
  if (letter == l) return "an"
 end
 return "a"
end
function guess_letter(kind, letter)
 if (not letter) letter = w_letterboard.letter
 w_letterboard.remaining[letter].selected = true -- cpu

 unflash()
 game_state = "state_revealing_letters"
 w_messageboard_set_message("is there "..article(letter).." "..letter.."?~player")

 local count = count_letter_in_puzzle(letter)
 if (count > 0) then
  local winnings = 0
  if (kind == "consonant") winnings = w_wheel.item_value
  local function on_reveal()
   if (kind == "consonant") game_active_player.round_total += shr(winnings, 16)
   if (count == 1) then
    w_messageboard_set_message("there is one "..letter..".")
   else
    w_messageboard_set_message("there are "..tostr(count).." "..letter.."'s.")
   end
  end

  local function on_reveal_done()
   w_letterboard.remaining[letter].available = false
   w_letterboard.remaining[letter].selected = false
   if (kind == "vowel") game_active_player.round_total -= c_num_vowel_cost

   delay(update_actions_available)
  end

  reveal_puzzle_letter(letter, on_reveal, on_reveal_done)
 else
  local function cb()
   w_letterboard.remaining[letter].available = false
   w_letterboard.remaining[letter].selected = false
   w_messageboard_set_message("sorry, no "..letter.."'s.")
   start_shake(5, 10)
   delay(event_loseturn)
  end
  delay(cb)
 end
end

shakey_dakeys = {}
function start_shake(sound, amount, things)
 sfx(sound or 5)
 sfx(12)
 amount = amount or 20
 shakey_dakeys = things or {}
 if (not things) then
  for c in all(w_puzzleboard.cells) do
   if (c.letter and not c.revealed) add(shakey_dakeys, c)
  end
 end
 for dakey in all(shakey_dakeys) do
  dakey.shake = amount
  dakey.orig_x = dakey.x
  dakey.orig_y = dakey.y
 end
end

function shake()
 if (#shakey_dakeys == 0) return
 local shook = false
 for dakey in all(shakey_dakeys) do
  if (dakey.shake > 0) then
   shook = true
   dakey.shake -= 1
   if (dakey.x < dakey.orig_x) dakey.x = dakey.orig_x + flr(rnd(dakey.shake)) else dakey.x = dakey.orig_x - flr(rnd(dakey.shake))
   if (dakey.y < dakey.orig_y) dakey.y = dakey.orig_y + flr(rnd(dakey.shake)) else dakey.y = dakey.orig_y - flr(rnd(dakey.shake))
  end
 end
 if (not shook) shakey_dakeys = {}
end

function reveal_letters(letters, done)
 local letter_idx = 0
 local function reveal_next_letter()
  letter_idx += 1
  local letter = letters[letter_idx]
  if (not letter) return done()

  w_letterboard.remaining[letter].available = false
  w_letterboard.remaining[letter].selected = false
  local count = count_letter_in_puzzle(letter)
  if (count > 0) reveal_puzzle_letter(letter, nil, reveal_next_letter) else reveal_next_letter()
 end
 reveal_next_letter()
end

function count_letter_in_puzzle(letter)
 local count = 0
 for row in all(puzzle.tiles) do
  for cell in all(row) do
   if ((cell.letter == letter or (cell.letter and letter == "*")) and not cell.revealed) count += 1
  end
 end
 return count
end

function reveal_puzzle_letter(letter, on_reveal, on_reveal_done)
 local next_time = time()
 local function make_reveal(cell)
  local function reveal()
   cell.revealed = true
   sfx(2)
   if (on_reveal) on_reveal()
  end
  return reveal
 end
 for row in all(puzzle.tiles) do
  for cell in all(row) do
   if (cell.letter == letter) then
    next_time += 1
    queue(make_reveal(cell), next_time)
   end
  end
 end
 if (on_reveal_done) queue(on_reveal_done, next_time + 1)
end

function event_bankrupt()
 game_active_player.round_total = 0
 if (game_active_player.free_spins > 0) update_actions_available("state_wait_free_spin") else next_player()
end

function event_freespin()
 game_active_player.free_spins += 1
 update_actions_available()
end

function event_loseturn()
 if (game_active_player.free_spins > 0) update_actions_available("state_wait_free_spin") else next_player()
end

function next_player()
 mode_name = "action"
 if (game_active_player == game_players_one) then
  game_active_player = game_players_cpu1
 elseif (game_active_player == game_players_cpu1) then
  game_active_player = game_players_cpu2
 else
  game_active_player = game_players_one
 end
 w_messageboard_set_message("your turn,\n"..game_active_player.name..".")
 delay(update_actions_available)
end

function end_round()
 w_letterboard.remaining[w_letterboard.letter].selected = false
 if (game_active_player.round_total < c_num_vowel_cost) game_active_player.round_total = c_num_vowel_cost
 game_active_player.game_total += game_active_player.round_total

 screens_intermission_show()
end

function next_round(round)
 toggle_theme_music(-1)
 screen_name = "round"
 game_round = round
 game_players_one.round_total = 0
 game_players_cpu1.round_total = 0
 game_players_cpu2.round_total = 0
 w_puzzleboard_init("normal")
 w_wheel_init(game_round)

 -- todo: fix clue sliding on for round 1 even though it's already on the screen -- slide it off first?
 if (game_round < 4) start_slide({ w_clue, w_round, w_letterboard, w_scoreboard, w_messageboard, w_wheel }, "on")

 if (game_round == 1) then
  game_active_player = game_players_one
 elseif (game_round == 2) then
  game_active_player = game_players_cpu1
 elseif (game_round == 3) then
  game_active_player = game_players_cpu2
 elseif (game_round == 4) then
  mode_name = ""
  local winner = game_players_one
  local totals = {
   game_players_one.game_total,
   game_players_cpu1.game_total,
   game_players_cpu2.game_total
  }
  if (totals[1] < totals[2] or totals[1] < totals[3]) then
   if (totals[2] >= totals[3]) winner = game_players_cpu1 else winner = game_players_cpu2
  end
  game_active_player = winner -- set active player to simplify later logic
  if (winner != game_players_one) then
   -- tax considerations
   w_bonusboard.lines = split(winner.name.." has won, but^regrettably has decided^not to participate in^the bonus round due to^"..winner.excuse..".", "^")
   game_state = "state_won"
   delay(end_game, 2)
  else
   bonus_mode = "spin_prize"
   toggle_theme_music(-1)
   local function cb()
    update_actions_available()
    w_messageboard_set_message("spin to choose a\nbonus prize!")
   end
   start_slide({ w_wheel, w_messageboard }, "on", cb)
  end
  return
 end

 new_puzzle()
 w_messageboard_set_message(game_active_player.name.." starts\nthis round.")
 delay(update_actions_available)
end

function start_bonus_round()
 local function done()
  bonus_mode = "solve_puzzle"
  w_bonusboard.lines = split("      bonus round^^we give you:^  r s t l n^and^  e", "^")
  start_slide({ w_clue, w_round, w_letterboard, w_bonusboard }, "on", new_puzzle)
 end
 start_slide({ w_wheel, w_messageboard }, "off", done)
end

function remove_champion(name)
 local remove_player = false
 for i=1,#champions_list do
  if (champions_list[i].name == name) remove_player = true
  if (remove_player) champions_list[i] = champions_list[i+1]
 end
 for i=1,#champions_list do
  if (champions_list[i].name == "") champions_list[i] = nil
 end
end

function end_game()
 mode_name = ""
 if (game_state == "state_won") game_active_player.game_total += num_grand_prize
 if (game_active_player.human) then
  puzzle.revealed = true
  w_bonusboard.lines[3] = float_to_money_str(game_active_player.game_total).." grand total"
 end

 for player in all(game_players) do
  if (player != game_active_player) remove_champion(player.name)
 end

 local existing_player = false
 for i=1,#champions_list do
  if (champions_list[i].name == game_active_player.name) then
   champions_list[i].score += game_active_player.game_total
   existing_player = true
  end
 end
 if (not existing_player) then
  if (#champions_list < 8) then
   champions_list[#champions_list + 1] = { name = game_active_player.name, score = game_active_player.game_total }
  else
   for i=1,#champions_list do
    if (game_active_player.game_total > champions_list[i].score) then
     for j=#champions_list,i+1,-1 do
      champions_list[j] = champions_list[j-1]
     end
     champions_list[i] = { name = game_active_player.name, score = game_active_player.game_total }
     break
    end
   end
  end
 end

 local unsorted = true
 while (unsorted) do
  unsorted = false
  for i=1,#champions_list-1 do
   if (champions_list[i].score < champions_list[i+1].score) then
    unsorted = true
    local tmp = champions_list[i]
    champions_list[i] = champions_list[i+1]
    champions_list[i+1] = tmp
   end
  end
 end
 delay(screens_champions_show, 4)
end

function new_puzzle()
 local already_played, puz_idx = true
 if (#puzzles_seen == #puzzles) then
  for i=1,#puzzles_seen do
   puzzles_seen[i] = false
  end
 end
 while (already_played) do
  puz_idx = ceil(rnd(#puzzles))
  already_played = puzzles_seen[puz_idx]
 end
 local puzzle_data = split(puzzles[puz_idx], "_")
 puzzle = to_puzzle(puzzle_data[2], puzzle_data[1])
 puzzles_seen[puz_idx] = true

 w_letterboard_init()

 for x in all(c_letters.symbols) do
  reveal_puzzle_letter(x)
 end

 if (bonus_mode == "solve_puzzle") reveal_letters(split("r,s,t,l,n,e"), bonus_choose_letters)
end

function action_spin()
 if (not game_can_spin) return
 mode_name, game_state = "spin", "state_spin"
 w_messageboard_set_message("i'd like to spin\nthe wheel!~player")
 adjust_power()
end

function action_solve()
 local is_bonus_round, on_all_incorrect_fn, on_all_correct_fn = game_round == 4
 game_state = "state_guess_puzzle"

 if (is_bonus_round) then
  w_bonusboard.lines = split(",   solve the puzzle!")
  local function on_all_correct()
   sfx(6)
   game_state = "state_won"
   w_bonusboard.lines = split("    congratulations!,,,,,")
   delay(end_game)
  end
  local function on_all_incorrect()
   w_bonusboard.lines = split("wrong!,too bad.,,,,")
   game_state = "state_bonus_puzzle_lost"
   start_shake()
   delay(end_game)
  end

  on_all_correct_fn = on_all_correct
  on_all_incorrect_fn = on_all_incorrect
 else
  w_messageboard_set_message("i will solve\nthe puzzle!~player")
 end

 local function deferred()
  action_solve_deferred(is_bonus_round, on_all_correct_fn, on_all_incorrect_fn)
 end
 local factor = game_active_player.human and 0.2 or 1
 delay(deferred, factor)
end

function action_solve_deferred(is_bonus_round, on_all_correct_fn, on_all_incorrect_fn)
 local count = count_letter_in_puzzle("*")
 if (count == 0) then
  puzzle_guess_letter("*", is_bonus_round)
  if (on_all_correct_fn) on_all_correct_fn()
  return
 end

 if (game_active_player.human) then
  select_letter_tile_to_insert()
  local function on_pick()
   local all_done, correct = puzzle_guess_letter(w_letterboard.letter, is_bonus_round)
   if (all_done) then
    if (is_bonus_round) then
     if (correct) on_all_correct_fn() else on_all_incorrect_fn()
    end
   else
    select_letter_tile_to_insert()
   end
  end
  w_letterboard_activate("letters", on_pick, undo_letter_tile_insertion)
 else
  cpu_player_guess_puzzle()
 end
end

function select_letter(dir)
 if (dir == "left") then
  w_letterboard.letter_idx -= 1
  if (w_letterboard.letter_idx < 1) w_letterboard.letter_idx = 26
 elseif (dir == "right") then
  w_letterboard.letter_idx += 1
  if (w_letterboard.letter_idx > 26) w_letterboard.letter_idx = 1
 elseif (dir == "up") then
  w_letterboard.letter_idx -= 13
  if (w_letterboard.letter_idx < 1) w_letterboard.letter_idx += 26
 elseif (dir == "down") then
  w_letterboard.letter_idx += 13
  if (w_letterboard.letter_idx > 26) w_letterboard.letter_idx -= 26
 end
end

function any_button()
 return
  btnp(0) or
  btnp(1) or
  btnp(2) or
  btnp(3) or
  btnp(4) or
  btnp(5)
end

function start_game()
 set_opponent_player(game_players_cpu1)
 set_opponent_player(game_players_cpu2)
 if (game_players_cpu1.name == game_players_cpu2.name) return start_game()
 next_round(1) -- skip rounds here
end
function set_opponent_player(player)
 local opponent_fields = split(rnd(opponents), "_")
 player.name = opponent_fields[1]
 player.skill = opponent_fields[2]
 player.shout = opponent_fields[3]
 player.cuss = opponent_fields[4]
 player.cheer = opponent_fields[5]
 player.excuse = opponent_fields[6]
end

function adjust_power()
 if (w_wheel.power == "up") then
  if (w_wheel.speed >= 100) then
   w_wheel.power = "down"
   w_wheel.speed -= 5
  else
   w_wheel.speed += 5
  end
 else -- down
  if (w_wheel.speed < 30) then
   w_wheel.power = "up"
   w_wheel.speed += 5
  else
   w_wheel.speed -= 5
  end
 end
end

function start_stop_spin()
 if (w_wheel.speed > 30 and not w_wheel.spinning) then
  if (w_wheel.speed >= 100) then
   w_wheel.cheat = true
   w_wheel.speed = 150 + ceil(rnd(25))
   w_messageboard_set_message("super-spin!")
   start_shake(15, 10, { w_wheel })
  else
   w_messageboard_set_message(game_active_player.shout.."!~player")
  end
  w_wheel.spinning = true
  mode_name = ""
 end
end

function adjust_spin()
 if (w_wheel.speed > 0.02) then
  if (w_wheel.speed < 10) then
   w_wheel.speed *= 0.9
  elseif (w_wheel.speed < 50) then
   w_wheel.speed *= 0.98
  else
   w_wheel.speed *= 0.99
  end
  w_wheel.tick += (w_wheel.speed / 1000)
  w_wheel.tick = w_wheel.tick - flr(w_wheel.tick)
  w_wheel.pick = flr((w_wheel.tick * 1000) / (1000 / 24)) + 1 -- 24 slices
  local prev_item = w_wheel.item_name
  local item = split(w_wheel.items[w_wheel.pick], "_")
  w_wheel.item_value = w_wheel.item_values[w_wheel.pick]
  w_wheel.item_name = w_wheel.item_names[w_wheel.pick]
  w_wheel.item_colour = w_wheel.item_colours[w_wheel.pick]
  if (prev_item != w_wheel.item_name) then
   w_wheel.just_ticked = true
   sfx(1)
  else
   w_wheel.just_ticked = false
  end
 else
  if (w_wheel.cheat and (w_wheel.item_name == "bankrupt" or w_wheel.item_name == "loseturn")) then
   w_wheel.speed = 0.5
   w_messageboard_set_message("awfully\nlucky...")
  else
   w_wheel.cheat = false
   w_wheel.speed = 0
   w_wheel.spinning = false
   game_state = "state_spin_completed"
  end
 end
end

function _draw()
 cls()

 local draw_method = screen_name.."_draw"
 if (screens[draw_method]) screens[draw_method]()

 -- centering guides
 -- rect(0, 0, 127, 127, 8)
 -- line(63, 0, 63, 127, 11)
end

function draw_box(x0, y0, x1, y1, bg_colour)
 rectfill(x0, y0, x1, y1, bg_colour)
 color(0)
 rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1)
 pset(x0, y0)
 pset(x0, y1)
 pset(x1, y0)
 pset(x1, y1)
 color(bg_colour)
 pset(x0 + 1, y0 + 1)
 pset(x0 + 1, y1 - 1)
 pset(x1 - 1, y0 + 1)
 pset(x1 - 1, y1 - 1)
 color(0)
end

sliders = {}
function start_slide(views, mode, done)
 for view in all(views) do
  local slide_params = split(view.slide)
  local axis = slide_params[1]
  local start = mode == "on" and slide_params[3] or slide_params[2]
  local target = mode == "on" and slide_params[2] or slide_params[3]
  view[axis] = start
  add(sliders, { view = view, axis = axis, target = target, done = done })
  done = nil -- only assign callback to one slider
  sfx(11)
 end
end
function slide()
 local in_progress = false
 for slider in all(sliders) do
  local axis = slider.axis
  local delta = flr((slider.target - slider.view[axis]) * 0.3)
  if (delta == 0 and slider.target != slider.view[axis]) then
   delta = flr((slider.target - slider.view[axis]) * 0.9)
  end
  if (delta == 0 and slider.target != slider.view[axis]) delta = slider.target - slider.view[axis]
  if (delta != 0) then
   slider.view[axis] += delta
   in_progress = true
  else
   if (slider.done) then
    slider.done()
    slider.done = nil
   end
  end
 end
 if (not in_progress) sliders = {}
 return in_progress
end

-- decides how to fit a puzzle
-- into the 11,13,13,11 grid
-- returns it as a puzzle obj
function to_puzzle(puzzle_letters, clue)
 local puzzle, words = { clue = clue }, {}
 words[1] = {}
 local wordcount, inword = 0, false
 for l in all(puzzle_letters) do
  if (l == " ") then
   if (inword) inword = false
  elseif (not inword) then
   inword = true
   wordcount += 1
   words[wordcount] = {}
   add(words[wordcount], l)
  else
   add(words[wordcount], l)
  end
 end

 wordcount += 1

 puzzle.letters = puzzle_letters
 puzzle.words = words
 puzzle.wordcount = wordcount
 puzzle.tiles = to_tiles(puzzle)
 return puzzle
end

function to_tiles(puz)
 local maxcols, row, rowcol, tiles, word, rows_used =
   { 11, 13, 13, 11 }
 , 1
 , 1
 , {}
 , 1
 , {}
 for r=1,4 do
  tiles[r] = {}
  for col=1,13 do
   tiles[r][col] = { letter = nil }
  end
 end

 while (word <= count(puz.words)) do
  if (row > 4) break
  local len, force_next_line, i =
    count(puz.words[word])
  , false
  , 0
  -- if the word fits on this row
  if (len + rowcol - 1 <= maxcols[row]) then
   for l in all(puz.words[word]) do
    if (l == "^") then
     force_next_line = true
     break
    end
    tiles[row][rowcol+i] = { letter = l }
    i += 1
   end
   tiles[row][rowcol+i] = { letter = nil }
   word += 1
   if (force_next_line) then
    rowcol = 13
   else
    rowcol += len + 1
   end
   rows_used[row] = true
  else
   row += 1
   rowcol = 1
  end
 end

 -- center puzzle vertically
 if (#rows_used < 3) then
  for row=#rows_used,1,-1 do
   for i=1,maxcols[row] do
    tiles[row+1][i] = tiles[row][i]
    tiles[row][i] = { letter = nil }
   end
  end
 end

 -- center puzzle horizontally
 for row=1,4 do
  local linelen = get_line_len(tiles[row])
  if (linelen > 0) then
   local adjust = flr((maxcols[row] - linelen) / 2)
   if (adjust > 0) then
    for i=linelen + 1,2,-1 do
     tiles[row][i+adjust-1] = tiles[row][i-1]
     tiles[row][i-1] = { letter = nil }
    end
   end
  end
 end

 return tiles
end

function get_line_len(line)
 local len, spaces, last = 0, 0, nil
 for col in all(line) do
  if (col.letter) then
   len += 1
   last = col.letter
  elseif (last) then
   spaces += 1
   last = nil
  end
 end
 if (not last and spaces > 0) spaces -= 1
 return len + spaces
end

flash_colour, flash_interval = nil, 0
function clr_flashing(instant, on_colour, off_colour)
 on_colour = on_colour or c_clr_theme
 off_colour = off_colour or 0
 flash_colour = flash_colour or on_colour
 if (not instant and time() < time_since_input + 15) return on_colour
 flash_interval += 1
 if (flash_interval < 40) return flash_colour
 if (flash_colour == on_colour) then
  flash_colour = off_colour
  flash_interval = 20
 else
  flash_colour = on_colour
  flash_interval = 0
 end
 return flash_colour
end
function unflash()
 flash_colour, time_since_input = nil, time()
end

function render_money(value)
 local padding = (value == "0" or value == 0) and "" or "0"
 local padded = value..padding
 if (#padded < 5) return "$"..padded

 local arr, rendered = split(padded, "", false), ""
 comma_idx = 0
 for i = #arr,1,-1 do
  local s = arr[i]
  comma_idx += 1
  if (comma_idx == 4 and i >= 1) then
   comma_idx, rendered = 1, ","..rendered
  end
  rendered = s..rendered
 end
 return "$"..rendered
end

-- https://www.lexaloffle.com/bbs/?pid=22809#p
function float_to_money_str(v)
 local orig_v, s, i = v, "", 0
 repeat
  local t=v>>>1
  s=(t%0x0.0005<<17)+(v<<16&1)..s
  v=t/5
  i+=1
 until v==0
 return render_money(s)
end

puzzles = split("movie_the princess bride~movie_raiders of the lost ark~movie_back to the future~movie_when harry met sally...~movie_a nightmare on elm street~movie_ghostbusters~movie_blade runner~movie_ferris bueller's day off~movie_stand by me~tv show_cheers~tv show_night court~tv show_he-man and the masters of the universe~tv show_the facts of life~tv show_the golden girls~tv show_who's the boss?~tv show_family ties~tv show_teenage mutant ninja turtles~song_crazy little thing called love~song_another brick in the wall~song_another one bites the dust~song_bette davis eyes~song_jessie's girl~song_i love rock 'n' roll~song_eye of the tiger~song_every breath you take~song_sweet dreams (are made of this)~song_total eclipse of the heart~song_when doves cry~song_what's love got to do with it~song_i just called to say i love you~song_wake me up before you go-go~song_the power of love~song_money for nothing~song_papa don't preach~song_walk like an egyptian~song_livin' on a prayer~song_i still haven't found what i'm looking for~song_never gonna give you up~song_sweet child o' mine~song_bad medicine~song_every rose has its thorn~song_like a prayer~song_wind beneath my wings~song_blame it on the rain~song_we didn't start the fire~song_another day in paradise~phrase_i'll be back~phrase_i've fallen and i can't get up~phrase_i pity the fool...~phrase_where's the beef?~phrase_pardon me, do you have any grey poupon?~phrase_whatchu talkin' 'bout, willis?~phrase_gag me with a spoon!~phrase_by the power of greyskull!~toys_rubik's cube~toys_hungry hungry hippos~toys_care bears~toys_cabbage patch kids~toys_teddy ruxpin~toys_pound puppies~toys_masters of the universe~toys_sony walkman~toys_transformers~toys_mr. potato head~toys_etch-a-sketch~toys_pez dispenser~computers_commodore 64~computers_ibm personal computer~computers_sinclair zx spectrum~computers_commodore amiga~computers_trs-80 color computer~computers_apple macintosh", "~")
intermission_facts = split("the ancient greeks played\na game almost identical to\nwheel of fortune?~wheel of fortune\nis more popular\nthan fortnite?~wheel of fortune\nhas correctly predicted the\nwinner of every us election?~the actual wheel of fortune\nweighs over four hundred\nmillion pounds?~wheel of fortune\nwas originally envisioned\nas a breakfast cereal?~playing wheel of fortune\nhas been proven to reverse\ncellular degeneration?~the letter z\nhas never appeared\nin a word puzzle?~the letter r\nis more popular\nthan soccer?~the letter y\ndid not appear in writing\nuntil 1948?~the letter e\nappears in 99.89%\nof all english words?", "~")

__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000aaaaaaaaaaaaa00000000000000000000000000000000000aaaaaaaaaaaaa0000000000000000000000000000000000
00000000000000000000000000000aaaaaaaaaaaaaaaaaaaaa000000000000000000000000000aaaaaaaaaaaaaaaaaaaaa000000000000000000000000000000
00000000000000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaa000000000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaa000000000000000000000000000
000000000000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa00000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa0000000000000000000000000
0000000000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa0000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa00000000000000000000000
00000000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000000000000000000000
000000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa00000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa0000000000000000000
00000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000000000000000000
0000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa0aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa00000000000000000
00000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000000000000000
0000000000000aaaaaaaaaaaaaaaaaaaaa00000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa00000000000aaaaaaaaaaaaaaaaaaaaa00000000000000
000000000000aaaaaaaaaaaaaaaaaa0000000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaa0000000000000000000aaaaaaaaaaaaaaaaaa0000000000000
00000000000aaaaaaaaaaaaaaaaa00000000000000000000000aaaaaaaaaaaaaaaaaaaaaaaaa00000000000000000000000aaaaaaaaaaaaaaaaa000000000000
0000000000aaaaaaaaaaaaaaaa000000000000000000000000000aaaaaaaaaaaaaaaaaaaaa000000000000000000000000000aaaaaaaaaaaaaaaa00000000000
0000000000aaaaaaaaaaaaaa0000000000000000000000000000000aaaaaaaaaaaaaaaaa0000000000000000000000000000000aaaaaaaaaaaaaa00000000000
000000000aaaaaaaaaaaaaa000000000000000000000000000000000aaaaaaaaaaaaaaa000000000000000000000000000000000aaaaaaaaaaaaaa0000000000
00000000aaaaaaaaaaaaaa00000000000000000000000000000000000aaaaaaaaaaaaa00000000000000000000000000000000000aaaaaaaaaaaaaa000000000
0000000aaaaaaaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000aaaaaaaaaaaaa00000000
0000000aaaaaaaaaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000aaaaaaaaaaaa00000000
000000aaaaaaaaaaaa3033333330333333307777777077777770333333307777777077777770777777707777777033333330333333303aaaaaaaaaaaa0000000
000000aaaaaaaaaaaa3033333330333333307777777077777770333333307777777077777770777777707777777033333330333333303aaaaaaaaaaaa0000000
00000aaaaaaaaaaaa330333333303333333077070770770007703333333077077770777007707707077077000770333333303333333033aaaaaaaaaaaa000000
00000aaaaaaaaaaa33303333333033333330770707707707777033333330770777707707077077070770770777703333333033333330333aaaaaaaaaaa000000
0000aaaaaaaaaaa3333033333330333333307707077077007770333333307707777077070770770707707700777033333330333333303333aaaaaaaaaaa00000
0000aaaaaaaaaaa3333033333330333333307700077077077770333333307707777077070770770007707707777033333330333333303333aaaaaaaaaaa00000
000aaaaaaaaaaa333330333333303333333077000770770007703333333077000770770077707770777077000770333333303333333033333aaaaaaaaaaa0000
000aaaaaaaaaaa333330333333303333333077777770777777703333333077777770777777707777777077777770333333303333333033333aaaaaaaaaaa0000
000aaaaaaaaaa33333303333333033333330777777707777777033333330777777707777777077777770777777703333333033333330333333aaaaaaaaaa0000
00aaaaaaaaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000aaaaaaaaaaa000
00aaaaaaaaaa3333333033333330333333307777777077777770777777707777777077777770777777707777777033333330333333303333333aaaaaaaaaa000
00aaaaaaaaaa3333333033333330333333307777777077777770777777707777777077777770777777707777777033333330333333303333333aaaaaaaaaa000
00aaaaaaaaaa3333333033333330333333307700077077700770770007707700077077070770770077707700077033333330333333303333333aaaaaaaaaa000
0aaaaaaaaaaa3333333033333330333333307707777077070770770707707770777077070770770707707707777033333330333333303333333aaaaaaaaaaa00
0aaaaaaaaaa033333330333333303333333077007770770707707700777077707770770707707707077077007770333333303333333033333330aaaaaaaaaa00
0aaaaaaaaaa033333330333333303333333077077770770707707707077077707770770707707707077077077770333333303333333033333330aaaaaaaaaa00
0aaaaaaaaaa033333330333333303333333077077770770077707707077077707770777007707707077077000770333333303333333033333330aaaaaaaaaa00
0aaaaaaaaaa033333330333333303333333077777770777777707777777077777770777777707777777077777770333333303333333033333330aaaaaaaaaa00
0aaaaaaaaaa033333330333333303333333077777770777777707777777077777770777777707777777077777770333333303333333033333330aaaaaaaaaa00
0aaaaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000aaaaaaaaaa00
0aaaaaaaaaa033333330333333303333333077777770777777707777777077777770777777707777777077777770333333303333333033333330aaaaaaaaaa00
0aaaaaaaaaa033333330333333303333333077777770777777707777777077777770777777707777777077777770333333303333333033333330aaaaaaaaaa00
0aaaaaaaaaa033333330333333303333333077777770770077707700077077000770770007707770777077700770333333303333333033333330aaaaaaaaaa00
0aaaaaaaaaa033333330333333303333333077777770777077707707077077070770770707707707777077077770333333303333333033333330aaaaaaaaaa00
0aaaaaaaaaa033333330333333303333333077000770777077707700077077000770770707707777777077000770333333303333333033333330aaaaaaaaaa00
0aaaaaaaaaaa3333333033333330333333307777777077707770777707707707077077070770777777707777077033333330333333303333333aaaaaaaaaaa00
00aaaaaaaaaa3333333033333330333333307777777077000770777707707700077077000770777777707700777033333330333333303333333aaaaaaaaaa000
00aaaaaaaaaa3333333033333330333333307777777077777770777777707777777077777770777777707777777033333330333333303333333aaaaaaaaaa000
00aaaaaaaaaa3333333033333330333333307777777077777770777777707777777077777770777777707777777033333330333333303333333aaaaaaaaaa000
00aaaaaaaaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000aaaaaaaaaaa000
000aaaaaaaaaa33333303333333033333330777777707777777077777770777777707777777077777770777777703333333033333330333333aaaaaaaaaa0000
000aaaaaaaaaaa333330333333303333333077777770777777707777777077777770777777707777777077777770333333303333333033333aaaaaaaaaaa0000
000aaaaaaaaaaa333330333333303333333077000770770077707700077077000770770007707770077077007770333333303333333033333aaaaaaaaaaa0000
0000aaaaaaaaaaa3333033333330333333307707777077070770777077707770777077707770770707707707077033333330333333303333aaaaaaaaaaa00000
0000aaaaaaaaaaa3333033333330333333307700777077070770777077707770777077707770770707707707077033333330333333303333aaaaaaaaaaa00000
00000aaaaaaaaaaa33303333333033333330770777707707077077707770777077707770777077070770770707703333333033333330333aaaaaaaaaaa000000
00000aaaaaaaaaaaa330333333303333333077000770770007707700077077707770770007707700777077070770333333303333333033aaaaaaaaaaaa000000
000000aaaaaaaaaaaa3033333330333333307777777077777770777777707777777077777770777777707777777033333330333333303aaaaaaaaaaaa0000000
000000aaaaaaaaaaaa3033333330333333307777777077777770777777707777777077777770777777707777777033333330333333303aaaaaaaaaaaa0000000
0000000aaaaaaaaaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000aaaaaaaaaaaa00000000
0000000aaaaaaaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000aaaaaaaaaaaaa00000000
00000000aaaaaaaaaaaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000aaaaaaaaaaaaaa000000000
000000000aaaaaaaaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000aaaaaaaaaaaaaa0000000000
0000000000aaaaaaaaaaaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000aaaaaaaaaaaaaa00000000000
0000000000aaaaaaaaaaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000aaaaaaaaaaaaaaaa00000000000
00000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000000000000
000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa0000000000000
0000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa00000000000000
00000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000000000000000
0000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa00000000000000000
00000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000000000000000000
000000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa0000000000000000000
00000000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000000000000000000000
0000000000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa00000000000000000000000
000000000000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa0000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000aaa0aaa0aaa00aa00aa00000a0a0000000a000000aaaaa000000aaa0a0a0aaa0aaa00aa0aa0000000000000000000000000000
00000000000000000000000000a0a0a0a0a000a000a0000000a0a000000a000000aa0a0aa00000a0a0a0a00a000a00a0a0a0a000000000000000000000000000
00000000000000000000000000aaa0aa00aa00aaa0aaa000000a0000000a000000aaa0aaa00000aa00a0a00a000a00a0a0a0a000000000000000000000000000
00000000000000000000000000a000a0a0a00000a000a00000a0a000000a000000aa0a0aa00000a0a0a0a00a000a00a0a0a0a000000000000000000000000000
00000000000000000000000000a000a0a0aaa0aa00aa000000a0a00000a00000000aaaaa000000aaa00aa00a000a00aa00a0a000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000777070700000777070007000777077000000707070707700077077707700077000000000000000000000000000000000
00000000000000000000000000000000707070700000707070007000707070700000707070707070700007007070700000000000000000000000000000000000
00000000000000000000000000000000770077700000777070007000777070700000777070707070700007007070777000000000000000000000000000000000
00000000000000000000000000000000707000700000707070007000707070700000707070707070707007007070007000000000000000000000000000000000
00000000000000000000000000000000777077700000707077707770707070700000707007707770777077707070770000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000c0c0ccc0ccc0c0c0ccc0c000c0c00000ccc0cc000cc0ccc0ccc0ccc0ccc0cc000000ccc0c0c000000000000000000000000000
00000000000000000000000000c0c0c000c0c0c0c00c00c000c0c000000c00c0c0c000c0c00c00c0c0c000c0c00000c0c0c0c000000000000000000000000000
00000000000000000000000000ccc0cc00ccc0c0c00c00c000ccc0ccc00c00c0c0ccc0ccc00c00cc00cc00c0c00000cc00ccc000000000000000000000000000
00000000000000000000000000c0c0c000c0c0ccc00c00c00000c000000c00c0c000c0c0000c00c0c0c000c0c00000c0c000c000000000000000000000000000
00000000000000000000000000c0c0ccc0c0c00c00ccc0ccc0ccc00000ccc0c0c0cc00c000ccc0c0c0ccc0ccc00000ccc0ccc000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000ccc0c0c0ccc000000cc00cc0ccc0ccc00cc0cc000cc0ccc0ccc00000c000c0c000000cc0ccc0ccc0ccc00000000000000000000000
00000000000000000000000c00c0c0c0000000c000c0c0ccc0ccc0c0c0c0c0c0c0c0c0c0000000c000c0c00000c000c0c0ccc0c0000000000000000000000000
00000000000000000000000c00ccc0cc000000c000c0c0c0c0c0c0c0c0c0c0c0c0cc00cc000000ccc0ccc00000c000ccc0c0c0cc000000000000000000000000
00000000000000000000000c00c0c0c0000000c000c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0000000c0c000c00000c0c0c0c0c0c0c0000000000000000000000000
00000000000000000000000c00c0c0ccc000000cc0cc00c0c0c0c0cc00ccc0cc00c0c0ccc00000ccc000c00000ccc0c0c0c0c0ccc00000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__sfx__
000900001e0501c000110501b05015050000002805000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100002062020600206000000000000000000000000000000000000000000000000000006600066000760008600096000a6000a6000a6000960008600076000000000000000000000000000000000000000000
000a000023050230502304023030230202302023020230202400027000290002a0002c0002d0002e0002e0002f0002f0002f00030000300003000030000300003000030000300003100031000320003200033000
000900001e0501e0501e0501e0501e0501e0501d0501c0501a05018050150501305011050100500e0500b05009050070500405001050000500e0000b000090000800007000070000600005000030000000000000
001000001e0501e0501e0501d0501b0501905014050100500c0500805003050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00040000090600906014000000000d000090600906014000140001900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000000000000000000000015050190501d0502105024050270502c0502f0503205000000000002c0502e05032050360503805000000000002c0502e0503105034050370503b05000000000000000000000
0005000001050020500305004050070500b05011050170501f0502805031050330003f00032000360003f00000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100003a05027000000001300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100002d05033050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100001d05016050270500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000764003630006200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300003a6303c63018630317001b63026630355000000000000226202b6200f620377001b6201062022400000000000034700000000000000000000001d7000000000000000000000000000000000000000000
0020000018555005001f555005001d5551c5551a555185001c55518500185551a555005001a500185551a5551c5551c500185551a555005001b5001a55518555175551a500175551555513555155551755500500
0020000018555007001f555007001d5551c5551a555185001c55518500185551a555005001a500185551a5551c5551c500185551a555185001855517555005001855517700157001370015700177000070000000
0003000021050220502305025050290502f050350503a0503e05029000200002f0502e0502e0502f050310503305036050380503b0503c0503d0503d0503d0503c0503b050370503605036050340503205030050
001400001f0551f0021d0001d0551f0001f0021f0501f0551d0021d0551f0021f05520002200551f0021f0551f0021d0001d0551f0001f0021f0501f0551d0021d0551f0021f05520002200551f0001f05500000
00141e001d0001d0551f0001f0021f0501f0551d0021d0551f0021f05520002200551f00222050227522275222752227522275222752227522275222742227322272200000000000000000000000000000000000
__music__
01 4d104344
02 4e114e44
01 0d424344
02 0e424344

