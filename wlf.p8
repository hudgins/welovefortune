pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
--[[
 HISTORY:
 - Sept 26, 2023:
   - 7879 used before refactor
   - 7960 used after just putting colours in object :/
   - 7879 using c_ prefix
   - 7861 using c_ prefix for sounds
   - 7911 after much refactoring :-(
   - 7749 this dropped a lot due to only having a few puzzles.
   - 7680 same as above but with short if statements
   - 7725 same as above but with int constants for states :(
 - Sept 30, 2023:
   - 7584 back to strings for states but use a table of methods for each state
   - less tokens because no if statement for each state
 - oct 2, 2023:
   - 8005 - lots of fixes, shake only white cells, better pausing between actions
   - make space for larger money, use unsigned int solution for larger numbers
   - toggle total money display on player one idle
   - spin power is circle inside wheel
   - sound for spin power is better, sound for letter landing is better
 - oct 3, 2023:
   - 8011 - bug fixes to bonus round, identified more bugs
 - oct 4, 2023:
   - 8166 - running out of tokens for puzzles
   - fixed solving bonus round
   - added the cut-off corner pieces in the puzzle board
   - added the proper yellow background thing with flat bottom like real life
   - added perfect spin reward for full speed spin
 - oct 6, 2023:
   - 8153 - will try global vars for views
   - 8019 - removed widgets object in favour of w_puzzleboard, etc.
   - 7978 - removed widget.init/draw in favour of widget_init/_draw
   - 7757 - all widget refs are single global variables now
 - oct 7, 2023:
   - 7742 - refactored some of the picker logic
 - oct 21, 2023:
   - 7939 - compressed puzzles and letter arrays into strings

 ### todo
 TO FIX:
 - doesn't add the right score for cpu players to the champions list
 - doesn't tell you that only vowels are left in the puzzle

TO DO:
 - rapid fire game mode between rounds
   - just show a puzzle and start revealing letters and money ticks down and you buzz in to solve
   - can the cpu players participate? I guess so

 - make it so three computer players can do the whole game

 - Computer skill levels
   - dumb ones can't solve
   - smartest ones solve early
 - Sound effects for everything

 - figure out how to load puzzles from another cartridge?
 - save puzzles already seen

 - music!

 - could just spin to pick a random name?
 - could spin to select random opponents!
 - keep opponent from being the same twice

PROBLEMS TO SOLVE:
 - how to fit a lot of puzzles
   - don't, just update the game weekly with new puzzles?
   - permalink to the latest version?
 - performance issues:
   - none obvious, but it definitely spins a lot and recreates functions
     over and over in some of the wait states
   - need to purge items from the queue after invokation

 ⬅️ ➡️ ⬆️ ⬇️ 🅾️ ❎
]]--

-- constants
c_clr_black = 0
c_clr_dark_blue = 1
c_clr_dark_purple = 2
c_clr_dark_green = 3
c_clr_brown = 4
c_clr_dark_gray = 5
c_clr_light_gray = 6
c_clr_white = 7
c_clr_red = 8
c_clr_orange = 9
c_clr_yellow = 10
c_clr_green = 11
c_clr_blue = 12
c_clr_indigo = 13
c_clr_pink = 14
c_clr_peach = 15

c_btn_left = 0
c_btn_right = 1
c_btn_up = 2
c_btn_down = 3
c_btn_o = 4
c_btn_x = 5

c_snd_money = 0
c_snd_tick = 1
c_snd_reveal = 2
c_snd_bankrupt = 3
c_snd_loseturn = 4
c_snd_wrong = 5
c_snd_freespin = 6
c_snd_win = 6
c_snd_spin = 7
c_snd_button_dir = 8
c_snd_button_x = 9
c_snd_button_o = 10
c_snd_super_spin = 15

c_num_vowel_cost = 250
c_num_grand_prize = 25000
-- c_num_full_power_prize = 37
-- c_num_full_power_prize_max_factor = 3

c_letters = {
 letters = split("a_b_c_d_e_f_g_h_i_j_k_l_m_n_o_p_q_r_s_t_u_v_w_x_y_z", "_"),
 consonants = split("b_c_d_f_g_h_j_k_l_m_n_p_q_r_s_t_v_w_x_y_z", "_"),
 vowels = split("a_e_i_o_u", "_"),
 symbols = split("-_'_._,_?_!_%_@_#_$_&_-", "_"),
 ranked = {
  letters = split("e_a_r_i_o_t_n_s_l_c_u_d_p_m_h_g_b_f_y_w_k_v_x_z_j_q", "_"),
  consonants = split("r_t_n_s_l_c_d_p_m_h_g_b_f_y_w_k_v_x_z_j_q", "_"),
  vowels = split("e_a_i_o_u", "_")
 }
}

-- end constants

mode_name = ""

opponents = {
 "james_1_fudge_yay_tax considerations",
 "benny_2_poopy diaper_special_stomach upset",
 "barry_3_gosh_excellent_diarrhea",
 "frank_4_crap_yessir_tummy troubles",
 "sarah_5_dammit_amazing_insane itchiness",
 "petey_6_damn_awesome_fear of letters",
 "bjorn_7_poop_great_feeling sleepy",
 "wanda_8_bummer_sweet_climate change",
 "gordy_9_shoot_let's go_stage fright",
 "agnes_10_darn_hooray_covid-19"
}

game = {}

puzzle = {}
puzzle_render_idx = 1
puzzles_seen = {}

wait_until = 0
wait_callback = nil
wait_for_reader = 2

screens = {}
screens.start = {}
function screens.start.init()
 local view = {
  animating = "not"
 }
 screens.start.view = view
end
function screens.start.draw()
 w_arches_draw()
 w_puzzleboard_draw("start")
 print("press any button", 32, 100, next_selection_colour())
 print("by allan hudgins", 32, 111, c_clr_white)
 color(c_clr_blue)
 print("heavily-inspired by", 26, 117)
 print("the commodore 64 game", 22, 123)
end
function screens.start.update()
 local start = screens.start.view
 if (start.animating == "active") then
  local delta = flr((w_arches.y - 2) / 12)
  if (w_puzzleboard.y - delta < 2) delta = w_puzzleboard.y - 2
  w_arches.y -= delta
  w_puzzleboard.y -= delta
  if (w_puzzleboard.y == 2) then
   w_arches.orig_x = w_arches.x
   w_arches.orig_y = w_arches.y
   w_puzzleboard.orig_x = w_puzzleboard.x
   w_puzzleboard.orig_y = w_puzzleboard.y
   start.animating = "done"
  end
  return
 elseif (any_button() and start.animating == "not") then
  start.animating = "active"
 elseif (start.animating == "done") then
  screen_name = "setup"
  screens.setup.start_setup()
 end
end

screens.intermission = {}
function screens.intermission.init()
 local view = {
  x = 0,
  y = 74,
  w = 127,
  h = 127 - 74
 }
 screens.intermission.view = view
end
function screens.intermission.draw()
 local view = screens.intermission.view
 local x0 = view.x
 local y0 = view.y
 local x1 = view.x + view.w
 local y1 = view.y + view.h
 rectfill(x0, y0, x1, y1, c_clr_blue)
 color(c_clr_black)
 rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1)
 print("did you know...", x0 + 4, y0 + 4)
 -- TODO: turn this into a 'lines' board and update during update, not draw
 if (game.round == 1) then
  print("the ancient greeks played", x0 + 4, y0 + 16)
  print("a game almost identical to", x0 + 4, y0 + 24)
  print("wheel of fortune?", x0 + 4, y0 + 32)
  print("it's true!", x0 + 4, y0 + 44)
 elseif (game.round == 2) then
  print("wheel of fortune", x0 + 4, y0 + 16)
  print("is more popular", x0 + 4, y0 + 24)
  print("than fortnite?", x0 + 4, y0 + 32)
  print("it's true!", x0 + 4, y0 + 44)
 elseif (game.round == 3) then
  print("wheel of fortune", x0 + 4, y0 + 16)
  print("has correctly predicted the", x0 + 4, y0 + 24)
  print("winner of every us election?", x0 + 4, y0 + 32)
  print("it's true!", x0 + 4, y0 + 44)
 elseif (game.round == 4) then
  print("wheel of fortune", x0 + 4, y0 + 16)
  print("is an excellent", x0 + 4, y0 + 24)
  print("source of calcium?", x0 + 4, y0 + 32)
  print("it's true!", x0 + 4, y0 + 44)
 end
 w_arches_draw()
 w_puzzleboard_draw()
end
function screens.intermission.update()
 if (any_button()) next_round(game.round + 1)
end

screens.setup = {}
function screens.setup.draw()
 w_arches_draw()
 w_puzzleboard_draw()
 draw_clue()
 w_letterboard_draw()

 local x = 20
 local y = 80
 local time_remaining = ceil(game.players.one.name_timeout - time())
 color(c_clr_light_gray)
 if (time_remaining > 0) then
  print("starting game in... "..tostr(time_remaining), x, y + 32)
 else
  print("⬅️ ➡️ ⬆️ ⬇️ to select", x, y)
  print("❎ (x) to add a letter", x, y + 10)
  print("🅾️ (z) to undo", x, y + 20)
 end
end
function screens.setup.update()
 if (not game.players.one.named) then
  game.players.one.named = #game.players.one.name > 1 and game.players.one.name_timeout < time()
  if (game.players.one.named) then
   start_game()
  elseif (any_button()) then
   game.players.one.name_timeout = time() + 2
  end
 end
end
function screens.setup.start_setup()
 w_puzzleboard_init("normal")
 puzzle = to_puzzle("deener", "your name")
 puzzle.revealed = false
 game.players.one.named = false
 game.players.one.name = ""
 game.players.one.name_chars = {}

 local function on_pick()
  add(game.players.one.name_chars, w_letterboard.letter)
  insert_puzzle_guess_letter(w_letterboard.letter)
  game.players.one.name = ""
  for i in all(game.players.one.name_chars) do
   game.players.one.name = game.players.one.name..i
  end
  if (#game.players.one.name < 6) then
   select_letter_tile_to_insert()
  else
   game.players.one.named = true
   start_game()
  end
 end
 local function on_undo()
  deli(game.players.one.name_chars)
  undo_letter_tile_insertion()
 end
 w_letterboard_activate("letters", on_pick, on_undo)
end

screens.round = {}
function screens.round.draw()
 w_arches_draw()
 w_puzzleboard_draw()
 draw_clue()

 print("round: "..game.round, 127 - 35, w_puzzleboard.y + 43, c_clr_blue)

 w_letterboard_draw()
 w_wheel_draw()

 -- power
 if (w_wheel.speed > 0) then
  local center_colour = w_wheel.speed > 100 and next_selection_colour(c_clr_green, true) or c_clr_green
  circfill(w_wheel.x, w_wheel.y, (w_wheel.middle_radius) * (w_wheel.speed / 100), center_colour)
 end

 w_wheel_draw_wheel_item()

 w_scoreboard_draw()
 w_messageboard_draw()
end
function screens.round.update()
 w_letterboard_update_remaining_letter_flags()
 if (screens.round[game.state]) screens.round[game.state]()
end
function screens.round.state_wait_action()
 update_chosen_action()
 if (player_chose_spin()) action_spin()
 if (player_chose_vowel()) screens.round.guess_vowel()
 if (player_chose_solve()) action_solve()
end
function screens.round.state_wait_free_spin()
 update_chosen_action()
 if (player_uses_free_spin()) then
  game.active_player.free_spins -= 1
  update_action_choices()
 elseif (player_passes()) then
  next_player()
 end
end
function screens.round.state_spin()
 if (not w_wheel.spinning and player_adjusting_power()) then
  if (w_wheel.start_power_sound) then
   sfx(c_snd_spin, 2)
   w_wheel.start_power_sound = false
  else
   if (w_wheel.speed < 30 and w_wheel.speed > 20) then
    w_wheel.start_power_sound = true
   end
  end
  adjust_power() 
 else
  sfx(-2, 2)
  if (w_wheel.spinning) adjust_spin() else start_stop_spin()
 end
end
function screens.round.state_spin_completed()
 game.state = "state_wait"
 if (w_wheel.item_name == "bankrupt") then
  sfx(c_snd_bankrupt)
  w_messageboard_set_message(game.active_player.cuss.."!")
  wait(wait_for_reader, event_bankrupt)
 elseif (w_wheel.item_name == "freespin") then
  sfx(c_snd_freespin)
  w_messageboard_set_message(game.active_player.cheer.."!")
  wait(wait_for_reader, event_freespin)
 elseif (w_wheel.item_name == "loseturn") then
  sfx(c_snd_loseturn)
  w_messageboard_set_message(game.active_player.cuss.."!")
  wait(wait_for_reader, event_loseturn)
 else
  sfx(c_snd_money)
  wait(wait_for_reader, screens.round.guess_letter)
 end
end
function screens.round.guess_letter()
 w_messageboard_set_message("choose a letter")
 if (game.active_player == game.players.one) then
  local function on_pick()
   mode_name = "" -- todo: can we just always do this after calling on_pick?
   guess_letter("consonant", w_letterboard.letter)
  end
  w_letterboard_activate("consonants", on_pick)
 else
  guess_letter("consonant", cpu_player_guess_letter("consonants"))
 end
end
function screens.round.guess_vowel()
 if (not game.can_buy_vowel) return

 w_messageboard_set_message("i'd like to", "buy a vowel!")
 if (game.active_player == game.players.one) then
  local function on_pick()
   mode_name = "" -- todo: see above
   guess_letter("vowel", w_letterboard.letter)
  end
  w_letterboard_activate("vowels", on_pick)
 else
  if (game.active_player != game.players.one) then
   guess_letter("vowel", cpu_player_guess_letter("vowels"))
  end
 end
end

screens.bonus = {}
function screens.bonus.draw()
 w_arches_draw()
 w_puzzleboard_draw()
 draw_clue()
 w_letterboard_draw()

 local x0 = w_letterboard.x
 local y0 = w_letterboard.y + w_letterboard.h + 3
 local x1 = w_letterboard.x + w_letterboard.w
 local y1 = y0 + (128 - y0)
 rectfill(x0, y0, x1, y1, c_clr_yellow)
 color(c_clr_black)
 rect(x0 + 1, y0 + 1, x1 - 1, y1 - 2)
 for line in all(w_bonusboard.lines) do
  y0 += 7
  print(line, x0 + 6, y0)
 end
end
function screens.bonus.update()
 w_letterboard_update_remaining_letter_flags()
 if (screens.round[game.state]) screens.round[game.state]()
end
function screens.bonus.choose_letters()
 game.state = "state_bonus_letters"
 w_bonusboard.lines = {
  "      bonus round",
  "",
  "choose 3 consonants:",
  "_ _ _",
  "and one vowel:",
  "_"
 }
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
   w_letterboard_set_letters("consonants")
  else
   w_bonusboard.vowels += 1
   add(w_bonusboard.letters, letter)
   w_bonusboard.lines[w_bonusboard.vowel_line] = letter
  end
  if (w_bonusboard.consonants == 3 and w_bonusboard.vowels == 0) then
   w_letterboard_set_letters("vowels")
   w_bonusboard.idx = 7
  elseif (w_bonusboard.vowels == 1) then
   mode_name = ""
   w_bonusboard.lines = {
    "",
    " let's see how you did!",
    "",
    "",
    "",
    ""
   }
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

screens.champions = {}
function screens.champions.init()
 local view = {
  x = 0,
  y = 0,
  w = 127,
  h = 127
 }
 screens.champions.view = view
end
function screens.champions.draw()
 local view = screens.champions.view
 local x0 = view.x
 local y0 = view.y
 local x1 = view.x + view.w
 local y1 = view.y + view.h
 rectfill(x0, y0, x1, y1, c_clr_orange)
 color(c_clr_black)
 rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1)
 x0 += 10
 y0 += 10
 print("champions", x0 + 36, y0)
 line(x0 + 36, y0 + 6, x0 + 70, y0 + 6)
 x0 += 10
 y0 += 15
 -- game.active_player.name = "barry"
 for i=1,#champions_list do
  local name = champions_list[i].name
  local score = u32_tostr(champions_list[i].score)
  local name_colour = name == game.active_player.name and next_selection_colour(c_clr_black, true) or c_clr_black
  print(i..". "..name, x0, y0, name_colour)
  print("$"..score, x0 + 80 - (#score * 4), y0)
  y0 += 7
 end
 print("press any button", 32, y0 + 20, c_clr_white)
end
function screens.champions.update()
 if (any_button()) restart()
end
function screens.champions.show()
 screen_name = "champions"
 save_champs()
end

widgets = {}
w_arches = {}
function w_arches_init()
 w_arches = {
  lx = 39,
  rx = 87,
  y = 56,
  outr = 38,
  inr = 28,
  color = c_clr_yellow
 }
end
function w_arches_draw()
 local y = w_arches.y
 local lx = w_arches.lx
 local rx = w_arches.rx
 circfill(lx, y, w_arches.outr, w_arches.color)
 circfill(rx, y, w_arches.outr, w_arches.color)
 color(c_clr_black)
 circfill(lx, y, w_arches.inr)
 circfill(rx, y, w_arches.inr)
 rectfill(lx + 20, y - 21, rx - 20, y - 20)
 rectfill(lx - 13, y + 20, rx + 13, y + 38)
 rectfill(lx - 13, y + 26, rx + 13, y + 35, w_arches.color)
 color(c_clr_dark_green)
 local yds = { -19, -17, -16, -15, -13, -11 }
 local sides = { 1, -1 }
 local xd = 19
 local xdr = 107
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
 -- rectfill(lx - 28, y - 10, rx + 28, y + 10, c_clr_black)
end

w_puzzleboard = {}
function w_puzzleboard_init(mode)
 w_puzzleboard = {
  x = 4,
  y = mode == "normal" and 2 or 37,
  shake = 0
 }
 w_puzzleboard.orig_x = w_puzzleboard.x
 w_puzzleboard.orig_y = w_puzzleboard.y

 -- puzzleboard letters as widgets
 local w = 6
 local h = 8
 w_puzzleboard.cells = {}
 for row = 1,4 do
  for col = 1,13 do
   local edge_offset = (row == 1 or row == 4) and w + 2 or 0
   if ((row == 1 or row == 4) and col > 11) then
   else
    local cell_view = {
     x = w * col + (col * 2) + w_puzzleboard.x + edge_offset,
     y = h *(row - 1) + ((row - 1) * 2) + w_puzzleboard.y,
     w = w,
     h = h,
     row = row,
     col = col,
     shake = 0,
    }
    add(w_puzzleboard.cells, cell_view)
   end
  end
 end
end
function w_puzzleboard_draw(mode)
 for c in all(w_puzzleboard.cells) do
  local w = c.w
  local h = c.h
  local row = c.row
  local col = c.col
  local x = c.x
  local y = c.y
  if (mode == "start") then
   local edge_offset = (row == 1 or row == 4) and w + 2 or 0
   x = w * col + (col * 2) + w_puzzleboard.x + edge_offset
   y = h *(row - 1) + ((row - 1) * 2) + w_puzzleboard.y
  end
  rectfill(x, y, x + w, y + h, c_clr_dark_green)
  if (#puzzle.tiles[row] >= col) then
   local cell = puzzle.tiles[row][col]
   if (cell.letter) then
    c.letter = cell.letter
    c.revealed = cell.revealed
    if (cell.revealed or puzzle.revealed) then
     rectfill(x, y, x + w, y + h, c_clr_white)
     print(cell.letter, x + 2, y + 2, c_clr_black)
    elseif (cell.selected) then
     rectfill(x, y, x + w, y + h, next_selection_colour(c_clr_yellow))
    elseif (cell.guessed_letter) then
     rectfill(x, y, x + w, y + h, c_clr_white)
     print(cell.guessed_letter, x + 2, y + 2, c_clr_black)
    else
     rectfill(x , y, x + w, y + h, c_clr_light_gray)
    end
   end
  end
 end
end

w_letterboard = {}
function w_letterboard_init()
 w_letterboard = {
  x = 5 + 6,
  y = 52,
  h = 20,
  shake = 0,
  cellh = 8,
  cellw = 6,
  list = "letters",
  letter = "a",
  letter_idx = 1,
  remaining = {}
 }
 w_letterboard.orig_x = w_letterboard.x
 w_letterboard.orig_y = w_letterboard.y
 w_letterboard.w = (w_letterboard.cellw*13) + (2*13)
 for l in all(c_letters.letters) do
  w_letterboard.remaining[l] = { letter = l, available = true, selected = false }
 end
end
function w_letterboard_draw()
 local h = w_letterboard.cellh
 local w = w_letterboard.cellw
 local fullw = w_letterboard.w
 rectfill(w_letterboard.x, w_letterboard.y,
          w_letterboard.x + fullw,
          w_letterboard.y + w_letterboard.h, c_clr_dark_gray)
 local x = w_letterboard.x + 1
 local y = w_letterboard.y + 1
 for l in all(c_letters.letters) do
  if (l == "n") then
   y += 10
   x = w_letterboard.x + 1
  end
  if (w_letterboard.remaining[l].available) then
   if (w_letterboard.remaining[l].selected) then
    rectfill(x, y, x + w, y + h, next_selection_colour(c_clr_yellow))
    print(l, x + 2, y + 2, c_clr_black)
   elseif (w_letterboard.remaining[l].hidden) then
    rectfill(x, y, x + w, y + h, c_clr_dark_blue)
    print(l, x + 2, y + 2, c_clr_black)
   else
    rectfill(x, y, x + w, y + h, c_clr_dark_blue)
    print(l, x + 2, y + 2, c_clr_white)
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
 if (btnp(c_btn_left)) dir = "left"
 if (btnp(c_btn_right)) dir = "right"
 if (btnp(c_btn_up)) dir = "up"
 if (btnp(c_btn_down)) dir = "down"

 if (not dir and (starting_letter.hidden or not starting_letter.available)) dir = "right"
 if (dir) then
  select_letter(dir)

  if (w_letterboard.letter) w_letterboard.remaining[w_letterboard.letter].selected = false

  local selected_letter = false
  while (not selected_letter) do
   -- w_letterboard.letter = letters[w_letterboard.letter_idx]
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

 if (btnp(c_btn_x) and w_letterboard.on_pick) then
  w_letterboard.on_pick()
  w_letterboard.remaining[w_letterboard.letter].selected = false
 end
 if (btnp(c_btn_o) and w_letterboard.on_undo) w_letterboard.on_undo()
end
function w_letterboard_unhide_all()
 for letter in all(c_letters.letters) do
  local l = w_letterboard.remaining[letter]
  l.hidden = false
 end
end
function w_letterboard_update_remaining_letter_flags()
 game.only_vowels_remain_in_puzzle = true
 game.only_vowels_remain_on_board = true
 game.no_vowels_remain_on_board = true
 game.all_letters_revealed = true
 game.can_spin = false
 game.can_buy_vowel = false

 for letter in all(c_letters.letters) do
  local l = w_letterboard.remaining[letter]
  if (l.available) then
   if (is_vowel(l.letter)) game.no_vowels_remain_on_board = false else game.only_vowels_remain_on_board = false
  end
 end

 for row in all(puzzle.tiles) do
  for cell in all(row) do
   if (cell.letter and not cell.revealed) then
    game.all_letters_revealed = false
    if (not is_vowel(cell.letter)) game.only_vowels_remain_in_puzzle = false
   end
  end
 end

 game.can_spin = not game.all_letters_revealed and not game.only_vowels_remain_in_puzzle and not game.only_vowels_remain_on_board
 -- TODO: rename this method or fix this surprise
 game.can_buy_vowel = not game.all_letters_revealed and not game.no_vowels_remain_on_board and game.active_player.round_total >= shr(c_num_vowel_cost, 16)
end
function w_letterboard_activate(list, on_pick, on_undo)
 mode_name = "letter_pick"
 w_letterboard.list = list
 w_letterboard.on_pick = on_pick
 w_letterboard.on_undo = on_undo
end
function w_letterboard_set_letters(list)
 w_letterboard.list = list
end

w_scoreboard = {}
function w_scoreboard_init()
 w_scoreboard = {
  x = 56,
  y = 74,
  w = 128 - 56,
  h = 34
 }
end
function w_scoreboard_draw()
 local x0 = w_scoreboard.x
 local y0 = w_scoreboard.y
 local x1 = w_scoreboard.x + w_scoreboard.w
 local y1 = w_scoreboard.y + w_scoreboard.h
 -- scoreboard
 rectfill(x0, y0, x1, y1, c_clr_blue)

 -- names
 color(c_clr_white)
 if (game.active_player == game.players.one) then
  rectfill(x0, y0 + 2, x1, y0 + 12)
 elseif (game.active_player == game.players.cpu1) then
  rectfill(x0, y0 + 12, x1, y0 + 22)
 else
  rectfill(x0, y0 + 22, x1, y0 + 32)
 end
 color(c_clr_black)
 rect(x0, y0 + 2, x1, y0 + 12)
 rect(x0, y0 + 12, x1, y0 + 12)
 rect(x0, y0 + 22, x1, y0 + 12)
 rect(x0, y0 + 32, x1, y0 + 2)
 rect(x0, y0, x1, y1)
 -- 1st divider
 line(x0 + 30, y0, x0 + 30, y1)
 -- 2nd divider
 -- line(x0 + 50, y0, x0 + 50, y1)
 
 -- free spins
 for i=1,game.players.one.free_spins do
  local xx0 = x0 + 2
  local yy0 = y0 + 12 - i * 2
  line(xx0, yy0, xx0, yy0)
 end
 for i=1,game.players.cpu1.free_spins do
  local xx0 = x0 + 2
  local yy0 = y0 + 22 - i * 2
  line(xx0, yy0, xx0, yy0)
 end
 for i=1,game.players.cpu2.free_spins do
  local xx0 = x0 + 2
  local yy0 = y0 + 32 - i * 2
  line(xx0, yy0, xx0, yy0)
 end

 -- game totals
 -- print(game.players.one.game_total, x0 + 34, y0 + 5)
 -- print(game.players.cpu1.game_total, x0 + 34, y0 + 15)
 -- print(game.players.cpu2.game_total, x0 + 34, y0 + 25)

 -- alternate showing round/game totals
 local total_to_show = "round_total"
 if (game.round > 1 and
     game.state == "state_wait_action" and
     game.active_player == game.players.one and
     time_since_input + 5 < time()) then
  total_to_show = "game_total"
  print("total", x0 + 4, y0 + 5)
  print("total", x0 + 4, y0 + 15)
  print("total", x0 + 4, y0 + 25)
 else
  print(game.players.one.name, x0 + 4, y0 + 5)
  print(game.players.cpu1.name, x0 + 4, y0 + 15)
  print(game.players.cpu2.name, x0 + 4, y0 + 25)
 end
 print("$"..u32_tostr(game.players.one[total_to_show]), x0 + 34, y0 + 5)
 print("$"..u32_tostr(game.players.cpu1[total_to_show]), x0 + 34, y0 + 15)
 print("$"..u32_tostr(game.players.cpu2[total_to_show]), x0 + 34, y0 + 25)
end

w_wheel = {}
function w_wheel_init(round)
 if (round > 3) return
 w_wheel = {
  x = 24,
  y = 100,
  orig_x = 24,
  orig_y = 100,
  shake = 0,
  radius = 24,
  middle_radius = 8,
  power = "up",
  speed = 0,
  tick = 0.01,
  pick = 1,
  spinning = false,
  item_name = "bankrupt",
  item_value = 0,
  item_colour = 0,
  colours = {},
  spokes = {}
 }
 if (round == 1) then
  w_wheel.items = {
   "bankrupt_0", -- 1
   "350_14", -- 2
   "250_13", -- 3
   "600_9", -- 4
   "400_8", -- 5
   "150_12", -- 6
   "250_14", -- 7
   "400_9", -- 8
   "200_13", -- 9
   "loseturn_10", -- 10
   "450_8", -- 11
   "150_12", -- 12
   "200_9", -- 13
   "700_14", -- 14
   "freespin_11", -- 15
   "200_8", -- 16
   "300_12", -- 17
   "400_13", -- 18
   "500_10", -- 19
   "1000_14", -- 20
   "200_9", -- 21
   "300_8", -- 22
   "800_12", -- 23
   "750_10", -- 24
  }
 elseif (round == 2) then
  w_wheel.items = {
   "bankrupt_0", -- 1
   "600_14", -- 2
   "200_12", -- 3
   "1000_10", -- 4
   "600_8", -- 5
   "300_14", -- 6
   "700_9", -- 7
   "450_12", -- 8
   "150_13", -- 9
   "800_8", -- 10
   "loseturn_10", -- 11
   "500_14", -- 12
   "400_12", -- 13
   "250_13", -- 14
   "bankrupt_0", -- 15
   "900_9", -- 16
   "300_8", -- 17
   "250_12", -- 18
   "900_10", -- 19
   "200_14", -- 20
   "400_12", -- 21
   "550_13", -- 22
   "200_9", -- 23
   "500_8", -- 24
  }
 elseif (round == 3) then
  w_wheel.items = {
   "bankrupt_0", -- 1
   "1500_10", -- 2
   "350_14", -- 3
   "900_9", -- 4
   "300_8", -- 5
   "250_12", -- 6
   "900_10", -- 7
   "200_14", -- 8
   "400_12", -- 9
   "550_13", -- 10
   "200_9", -- 11
   "500_8", -- 12
   "bankrupt_0", -- 13
   "600_14", -- 14
   "200_12", -- 15
   "loseturn_10", -- 16
   "350_13", -- 17
   "250_8", -- 18
   "500_12", -- 19
   "5000_7", -- 20
   "300_14", -- 21
   "800_8", -- 22
   "500_12", -- 23
   "700_13", -- 24
  }
 -- else -- bonus prize
 --  w_wheel.items = {
 --   "book_0_20", -- 1
 --   "car_10_40000", -- 2
 --   "shed_14_1000", -- 3
 --   "lamp_9_200", -- 4
 --   "vacation_8_6000", -- 5
 --   "boat_12_80000", -- 6
 --   "skidoo_10_8000", -- 7
 --   "console_14_800", -- 8
 --   "shoes_4_500", -- 9
 --   "purse_13_700", -- 10
 --   "bitcoin_9_100000", -- 11
 --   "diamond_8_20000", -- 12
 --   "meal_0_100", -- 13
 --   "cruise_14_4000", -- 14
 --   "truck_12_60000", -- 15
 --   "bicycle_10_900", -- 16
 --   "tv_13_3000", -- 17
 --   "desk_8_600", -- 18
 --   "artwork_12_30000", -- 19
 --   "gold bar_7_70000", -- 20
 --   "diamond_14_25000", -- 21
 --   "couch_8_2000", -- 22
 --   "cat_12_501", -- 23
 --   "dog_13_502", -- 24
 --  }
 end
 for s=1,#w_wheel.items do
  w_wheel.colours[s] = split(w_wheel.items[s], "_")[2]
 end

 -- generate spokes to fill out wheel
 local f = 100
 local slices = 24
 local lines = slices * f
 local slice = 0
 local prev_x
 local prev_y
 for i=1,lines do
  slice = ceil(i/f)
  local delta = (i-1)/lines - w_wheel.tick
  local x = flr(w_wheel.x + cos(delta) * w_wheel.radius)
  local y = flr(w_wheel.y + sin(delta) * w_wheel.radius)
  if (prev_x != x or prev_y != y) then
   add(w_wheel.spokes, { x = x, y = y })
   prev_x = x
   prev_y = y
  end
 end
 -- printh("spokes: "..#w_wheel.spokes)
end
function w_wheel_draw()
 local start_spoke = flr((w_wheel.tick * 1000) / (1000 / #w_wheel.spokes)) + 1
 local spokes_per_slice = #w_wheel.spokes / 24
 for i=1,#w_wheel.spokes do
  local spoke = w_wheel.spokes[i]
  local slice = flr((start_spoke + (i-1)) / spokes_per_slice) + 1
  -- printh("slice: "..slice..", start_spoke: "..start_spoke)
  if (slice > 24) slice -= 24
  line(w_wheel.x, w_wheel.y, spoke.x, spoke.y, w_wheel.colours[slice])
 end
 circfill(w_wheel.x, w_wheel.y, w_wheel.middle_radius, c_clr_dark_green)
end
-- function w_wheel_draw() -- works like the c64 one
--  local start_slice = flr((w_wheel.tick * 1000) / (1000 / 24)) + 1 -- 24 slices
--  for i=1,#w_wheel.spokes do
--   local spoke = w_wheel.spokes[i]
--   local slice = flr(start_slice + i/8)
--   if (slice > 24) slice -= 24
--   line(w_wheel.x, w_wheel.y, spoke.x, spoke.y, w_wheel.colours[slice])
--  end
--  circfill(w_wheel.x, w_wheel.y, w_wheel.middle_radius, c_clr_dark_green)
-- end
-- function w_wheel_draw() -- original, non-performant
--  local f = 100
--  local slices = 24
--  local lines = slices * f
--  local slice = 0
--  local prev_x
--  local prev_y
--  for i=1,lines do
--   slice = ceil(i/f)
--   local delta = (i-1)/lines - w_wheel.tick
--   local x = flr(w_wheel.x + cos(delta) * w_wheel.radius)
--   local y = flr(w_wheel.y + sin(delta) * w_wheel.radius)
--   if (prev_x != x or prev_y != y) then
--    line(w_wheel.x, w_wheel.y, x, y, w_wheel.colours[slice])
--    prev_x = x
--    prev_y = y
--   end
--  end
--  circfill(w_wheel.x, w_wheel.y, w_wheel.middle_radius, c_clr_dark_green)
-- end
function w_wheel_draw_wheel_item()
 local bg_colour = w_wheel.item_colour
 local fg_colour = bg_colour == c_clr_black and c_clr_white or c_clr_black
 local border_colour = bg_colour == c_clr_white and c_clr_black or c_clr_white
 local x = 49
 local y = 75
 rectfill(x, y, x + 6, y + 50, bg_colour)
 rect(x, y, x + 6, y + 50, border_colour)
 rectfill(x - 3, y + 25, x, y + 27, border_colour) 
 if (w_wheel.just_ticked) then
  line(x - 5, y + 28, x - 1, y + 26, c_clr_red) 
 else
  line(x - 5, y + 26, x - 1, y + 26, c_clr_red) 
 end
 local i = 1
 y = y - 4
 for l in all(w_wheel.item_name) do
  print(l, x + 2, y + 6 * i, fg_colour)
  i += 1
 end
end


w_messageboard = {}
function w_messageboard_init()
 w_messageboard = {
  selection = "spin",
  selection_idx = 1,
  choices = { "spin", "solve" }
 }
end
function w_messageboard_draw()
 local x0 = w_scoreboard.x + 1
 local y0 = w_scoreboard.y + w_scoreboard.h + 1
 local x1 = w_scoreboard.x + w_scoreboard.w - 1
 local y1 = y0 + 16
 rectfill(x0, y0, x1, y1, c_clr_yellow)
 local indicator_colour = c_clr_black
 if (mode_name == "action") indicator_colour = next_selection_colour()
 color(c_clr_black)
 if (w_messageboard.message_displayed
  or game.state == "state_spin"
  or game.state == "state_guess_puzzle"
  or game.state == "state_revealing_letters"
  or game.state == "state_spin_completed") then
  print(w_messageboard.line1, x0 + 3, y0 + 3)
  print(w_messageboard.line2, x0 + 3, y0 + 9)
 elseif (game.state == "state_wait_action") then
  -- spin
  if (game.can_spin) then
   if (w_messageboard.selection == "spin") then
    print("❎", x0 + 6, y0 + 2, indicator_colour)
   end
   print("spin", x0 + 2, y0 + 9, c_clr_black)
  end
  -- buy vowel
  if (game.can_buy_vowel) then
   if (w_messageboard.selection == "vowel") then
    print("❎", x0 + 22 + 8, y0 + 2, indicator_colour)
   end
   print("vowel", x0 + 22, y0 + 9, c_clr_black)
  end
  -- solve
  if (w_messageboard.selection == "solve") then
   print("❎", x0 + 48 + 6, y0 + 2, indicator_colour)
  end
  print("solve", x0 + 48, y0 + 9, c_clr_black)
 elseif (game.state == "state_wait_free_spin") then
  -- spin
  if (w_messageboard.selection == "spin") then
   print("❎", x0 + 6, y0 + 3, indicator_colour)
  end
  print("free spin", x0 + 2, y0 + 9, c_clr_black)
  -- no spin
  if (w_messageboard.selection == "pass") then
   print("❎", x0 + 48 + 8, y0 + 3, indicator_colour)
  end
  print("pass", x0 + 48 + 2, y0 + 9, c_clr_black)
 end
end
function w_messageboard_set_message(line1, line2, display)
 w_messageboard.line1 = line1 or ""
 w_messageboard.line2 = line2 or ""
 w_messageboard.message_displayed = true
end

w_bonusboard = {}
function w_bonusboard_init()
 w_bonusboard = {
  lines = {},
  letters = {},
  consonant_line = 4,
  vowel_line = 6,
  consonants = 0,
  vowels = 0
 }
end

-- max 8
champions_list = {}

function _init()
 cartdata("wof_champs_v1")
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
  champions_list[entry + 1] = { name = current_name, score = dget(entry * 7 + 6) }
 end
 -- if champions list is empty, fill it with defaults
 if (champions_list[1].name == "") then
  for i=1,8 do
   champions_list[i] = { name = opponents[i].name, score = shr(34000 - i * 4000, 16) }
  end
 end
end

function save_champs()
 -- wipe data area to ensure everything is overwritten
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
 event_queue = {}
 mode_name = ""
 screen_name = "start"

 game.state = "state_start"
 game.round = 1
 game.only_vowels_remain_in_puzzle = false
 game.only_vowels_remain_on_board = false
 game.no_vowels_remain_on_board = false
 game.all_letters_revealed = false
 game.can_spin = true
 game.can_buy_vowel = false
 game.players = {}
 game.players.one = create_player("")
 game.players.one.name_timeout = 0
 game.players.one.name_chars = {}
 game.players.cpu1 = create_player()
 game.players.cpu2 = create_player()
 game.active_player = game.players.one

 puzzle = to_puzzle("we love fortune", "")
 -- puzzle = to_puzzle("wheel of fortune", "")
 -- puzzle = to_puzzle("a a aaa aa. bbbb bbb bbb. cccc c c ccc. ddd dd dd .", "")
 -- puzzle = to_puzzle("a a aaa aa. bbbb bbb bbb. cccc c c ccc. ddd dd dd .", "")
 -- puzzle = to_puzzle("can you do any can you do any can you do any", "")
 -- puzzle = to_puzzle("super blood hockey", "")
 -- new_puzzle()
 puzzle.revealed = true

 w_arches_init()
 w_puzzleboard_init()
 w_letterboard_init()
 w_messageboard_init()
 w_scoreboard_init()
 w_wheel_init(1)
 w_bonusboard_init()

 for name,screen in pairs(screens) do
  if (screen.init) screen.init()
 end
end

function create_player(player_name)
 return {
  name = player_name,
  free_spins = 0,
  game_total = 0,
  round_total = 0,
  cuss = "no fair",
  cheer = "nice"
 }
end

function wait(seconds, cb)
 -- printh("set up wait: "..seconds..", overriding callback: "..tostr(not not wait_callback))
 wait_until = time() + seconds
 wait_callback = cb
end

event_queue = {}
time_since_input = time()

function queue(fn, on_time)
 add(event_queue, { run = fn, time = on_time })
end

function acknowledge_player_input()
 if (game.active_player != game.players.one or player_adjusting_power()) return

 if (btnp(c_btn_left) or
  btnp(c_btn_right) or
  btnp(c_btn_up) or
  btnp(c_btn_down)) then
  sfx(c_snd_button_dir)
  time_since_input = time()
 elseif (btnp(c_btn_o)) then
  sfx(c_snd_button_o)
  time_since_input = time()
 elseif (btnp(c_btn_x)) then
  sfx(c_snd_button_x)
  time_since_input = time()
 end
end

function _update()
 if (wait_until > time()) return
 if (wait_callback) then
  -- printh("calling callback")
  local cb = wait_callback
  wait_callback = nil
  cb()
 end

 if (#event_queue > 0) then
  local event_pending = false
  for event in all(event_queue) do
   if (not event.invoked and event.time < time()) then
    event.invoked = true
    -- printh("calling event")
    event.run()
   elseif (not event.invoked) then
    event_pending = true
   end
  end
  if (not event_pending) then
   -- printh("purging events: "..#event_queue)
   event_queue = {}
  end
 end

 acknowledge_player_input()

 if (mode_name == "letter_pick") w_letterboard_update() else w_letterboard_unhide_all()

 if (screens[screen_name] and screens[screen_name].update) screens[screen_name].update()
end

function player_chose_spin()
 if (game.active_player == game.players.one) then
  return btnp(c_btn_x) and w_messageboard.selection == "spin"
 else
  return cpu_player_choose_action() == "spin"
 end
end

function cpu_player_choose_action()
 local other_cpu = game.players.cpu1
 if (game.active_player == game.players.cpu1) other_cpu = game.players.cpu2
  
 local choice = "solve"
 local count = count_letter_in_puzzle("*")
 -- if not many letters remaining
 if (count < #puzzle.letters / 4) then
  -- and player will be in the lead
  if (game.active_player.game_total + game.active_player.round_total > other_cpu.game_total) then
   choice = "solve"
  end
 elseif (game.can_buy_vowel) then
  choice = "vowel"
 elseif (game.can_spin) then
  choice = "spin"
 end
 return choice
end

function player_chose_vowel()
 if (game.active_player == game.players.one) then
  return btnp(c_btn_x) and w_messageboard.selection == "vowel"
 else
  return cpu_player_choose_action() == "vowel"
 end
end

function cpu_player_guess_letter(kind)
 if (kind == "puzzle") return "*"

 local choice = nil
 local offset = 1
 while (not choice) do
  local n
  local l
  if (game.active_player.skill > 0) then
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

function player_chose_solve()
 if (game.active_player == game.players.one) then
  return btnp(c_btn_x) and w_messageboard.selection == "solve"
 else
  return cpu_player_choose_action() == "solve"
 end
end

function player_adjusting_power()
 if (game.state != "state_spin") return false
 if (game.active_player == game.players.one) then
  return btn(c_btn_x) and w_messageboard.selection == "spin"
 else
  return ceil(rnd(100)) < 95
 end
end

function player_uses_free_spin()
 if (game.active_player == game.players.one) then
  return btnp(c_btn_x) and w_messageboard.selection == "spin"
 else
  return true
 end
end

function player_passes()
 if (game.active_player == game.players.one) then
  return btnp(c_btn_x) and w_messageboard.selection == "pass"
 else
  return false
 end
end

function update_chosen_action()
 if (btnp(c_btn_left)) then
  w_messageboard.selection_idx -= 1
  if (not w_messageboard.choices[w_messageboard.selection_idx]) then
   w_messageboard.selection_idx = 1
  end
 elseif (btnp(c_btn_right)) then
  w_messageboard.selection_idx += 1
  if (not w_messageboard.choices[w_messageboard.selection_idx]) then
   w_messageboard.selection_idx = #w_messageboard.choices
  end
 end
 w_messageboard.selection = w_messageboard.choices[w_messageboard.selection_idx]
end

function puzzle_guess_letter(letter, custom_handling)
 local all_done = insert_puzzle_guess_letter(letter)
 local correct = false
 if (all_done) then
  correct = check_puzzle_correctness()
  if (correct) then
   game.state = "state_won"
   sfx(c_snd_win)
   if (custom_handling) return all_done, correct

   w_messageboard_set_message("congratulations!", "you are correct!")
   wait(wait_for_reader, end_round)
  else
   start_shake(20)
   sfx(c_snd_wrong)
   if (custom_handling) return all_done, correct

   w_messageboard_set_message("sorry, that is", "not correct")
   wait(wait_for_reader, event_loseturn)
  end
 end
 return all_done, correct
end

function update_action_choices(state)
 game.state = state or "state_wait_action"
 mode_name = "action"
 w_messageboard.message_displayed = false
 w_messageboard.choices = {}
 if (game.state == "state_wait_free_spin") then
  add(w_messageboard.choices, "spin")
  add(w_messageboard.choices, "pass")
 else
  if (game.can_spin) add(w_messageboard.choices, "spin")
  if (game.can_buy_vowel) add(w_messageboard.choices, "vowel")
  add(w_messageboard.choices, "solve")
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
    if (correct and cell.guessed_letter == cell.letter) cell.revealed = true
    cell.guessed_letter = nil
    cell.selected = false
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
    cell.selected = false
    cell.guessed_letter = nil
    if (prev) then
     prev.selected = true
     prev.guessed_letter = nil
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
    if (letter == "*") cell.guessed_letter = cell.letter
    done = true
    break
   end
  end
 end

 local all_done = true
 for row in all(puzzle.tiles) do
  for cell in all(row) do
   if (cell.letter and not cell.revealed and not cell.guessed_letter) return false
  end
 end

 return all_done
end

function is_vowel(letter)
 for v in all (c_letters.vowels) do
  if (v == letter) return true
 end
 return false
end

function guess_letter(kind, letter)
 w_letterboard.remaining[letter].available = false
 w_letterboard.remaining[letter].selected = false
 game.state = "state_revealing_letters"

 local count = count_letter_in_puzzle(letter)
 if (count > 0) then
  local winnings = 0
  if (kind == "consonant") winnings = w_wheel.item_value
  local function on_reveal()
   if (kind == "consonant") game.active_player.round_total += shr(winnings, 16)
   if (count == 1) then
    w_messageboard_set_message("there is one", letter.." in the puzzle")
   else
    w_messageboard_set_message("yes, "..tostr(count).." "..letter.."'s", "in the puzzle")
   end
  end

  local function on_reveal_done()
   if (kind == "vowel") game.active_player.round_total -= shr(c_num_vowel_cost, 16)

   if (puzzle_fully_revealed()) then
    w_messageboard_set_message("you", "won!")
    wait(wait_for_reader, end_round)
   else
    wait(wait_for_reader, update_action_choices)
   end
  end

  reveal_puzzle_letter(letter, on_reveal, on_reveal_done)

  return
 end

 local function cb()
  w_messageboard_set_message("sorry, no "..letter.."'s")
  sfx(c_snd_wrong)
  start_shake(10)
  wait(wait_for_reader, event_loseturn)
 end
 wait(wait_for_reader, cb)
end

shakey_dakeys = {}
function start_shake(amount)
 shakey_dakeys = {}
 for c in all(w_puzzleboard.cells) do
  -- todo: if puzzle guess, only shake wrong letters
  -- todo: if letter guess, shake non-revealed letters
  if (c.letter and not c.revealed) add(shakey_dakeys, c)
 end
 for dakey in all(shakey_dakeys) do
  dakey.shake = amount
  dakey.orig_x = dakey.x
  dakey.orig_y = dakey.y
 end
end

function shake()
 for dakey in all(shakey_dakeys) do
  if (dakey.shake > 0) dakey.shake -= 1
  if (dakey.x < dakey.orig_x) dakey.x = dakey.orig_x + flr(rnd(dakey.shake)) else dakey.x = dakey.orig_x - flr(rnd(dakey.shake))
  if (dakey.y < dakey.orig_y) dakey.y = dakey.orig_y + flr(rnd(dakey.shake)) else dakey.y = dakey.orig_y - flr(rnd(dakey.shake))
 end
end

function reveal_letter(letter)
 w_letterboard.remaining[letter].available = false
 w_letterboard.remaining[letter].selected = false

 local count = count_letter_in_puzzle(letter)
 if (count > 0) reveal_puzzle_letter(letter)
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

function letter_already_guessed(letter)
 return false
end

function puzzle_fully_revealed()
 return false
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
   sfx(c_snd_reveal)
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
 game.active_player.round_total = 0
 if (game.active_player.free_spins > 0) update_action_choices("state_wait_free_spin") else next_player()
end

function event_freespin()
 game.active_player.free_spins += 1
 update_action_choices()
end

function event_loseturn()
 if (game.active_player.free_spins > 0) update_action_choices("state_wait_free_spin") else next_player()
end

function next_player()
 if (game.active_player == game.players.one) then
  game.active_player = game.players.cpu1
 elseif (game.active_player == game.players.cpu1) then
  game.active_player = game.players.cpu2
 else
  game.active_player = game.players.one
 end
 w_messageboard.selection_idx = 1
 update_action_choices()
end

function end_round()
 local winner = game.active_player
 if (winner.round_total < shr(c_num_vowel_cost, 16)) winner.round_total = shr(c_num_vowel_cost, 16)
 winner.game_total += winner.round_total

 -- TODO: LOL
 screen_name = "intermission"
 mode_name = "intermission"
 game.state = "state_intermission"
end

function next_round(round)
 screen_name = "round"
 game.round = round
 game.players.one.round_total = 0
 game.players.cpu1.round_total = 0
 game.players.cpu2.round_total = 0
 w_puzzleboard_init("normal")
 w_wheel_init(game.round)

 if (game.round == 1) then
  game.active_player = game.players.one
 elseif (game.round == 2) then
  game.active_player = game.players.cpu1
 elseif (game.round == 3) then
  game.active_player = game.players.cpu2
 elseif (game.round == 4) then
  -- todo: why do i need this?
  if (not game.active_player) game.active_player = game.players.cpu2
  start_bonus_round()
  return
 end

 update_action_choices()
 new_puzzle()
end

function end_game()
 mode_name = ""
 if (game.state == "state_lost") then
  puzzle.revealed = true
  local remove_player = false
  for i=1,#champions_list do
   if (champions_list[i].name == game.active_player.name) then
    remove_player = true
   end
   if (remove_player) then
    champions_list[i] = champions_list[i+1]
   end
  end
 else -- won
  game.active_player.game_total += shr(c_num_grand_prize, 16)
  w_bonusboard.lines[6] = "       $"..u32_tostr(game.active_player.game_total)
  local existing_player = false
  for i=1,#champions_list do
   if (champions_list[i].name == game.active_player.name) then
    -- todo: support total scores higher than 32k
    champions_list[i].score += game.active_player.game_total
    existing_player = true
   end
  end
  if (not existing_player) then
   for i=1,#champions_list do
    if (game.active_player.game_total > champions_list[i].score) then
     for j=#champions_list,i+1,-1 do
      champions_list[j] = champions_list[j-1]
     end
     champions_list[i] = { name = game.active_player.name, score = game.active_player.game_total }
     break
    end
   end
  end
 end
 wait(wait_for_reader * 4, screens.champions.show)
end

function new_puzzle()
 local already_played = true
 local puz_idx
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
 
 for x in all(c_letters.symbols) do
  reveal_puzzle_letter(x)
 end

 w_letterboard_init()
end

function start_bonus_round()
 mode_name = ""
 screen_name = "bonus"
 local winner = game.players.one
 local totals = {
  game.players.one.game_total,
  game.players.cpu1.game_total,
  game.players.cpu2.game_total
 }
 if (totals[1] < totals[2] or totals[1] < totals[3]) then
  if (totals[2] >= totals[3]) winner = game.players.cpu1 else winner = game.players.cpu2
 end
 if (winner != game.players.one) then
  -- tax considerations
  w_bonusboard.lines = {
   winner.name.." has won, but",
   "regrettably has decided",
   "not to participate in",
   "the bonus round due to",
   winner.excuse.."."
  }
  game.state = "state_won"
  wait(wait_for_reader * 2, end_game)
 else
  new_puzzle()
  w_bonusboard.lines = {
   "      bonus round",
   "",
   "we give you:",
   "  r s t l n",
   "and",
   "  e",
  }
  reveal_letters({"r", "s", "t", "l", "n", "e"}, screens.bonus.choose_letters)
 end
end

function action_spin()
 if (not game.can_spin) return
 mode_name = "spin"
 game.state = "state_spin"
 w_messageboard_set_message("i'd like to", "spin the wheel!")
 adjust_power() 
end

function action_solve()
 local is_bonus_round = game.round == 4
 local on_all_incorrect_fn
 local on_all_correct_fn
 local player_one = game.active_player == game.players.one
 game.state = "state_guess_puzzle"

 if (is_bonus_round) then
   w_bonusboard.lines = {
    "",
    "   solve the puzzle!",
    "",
    "",
    "",
    ""
   }
  local function on_all_correct()
   sfx(c_snd_win)
   game.state = "state_won"
   w_bonusboard.lines = {
    "    congratulations!",
    "",
    "",
    "  your total winnings:",
    "",
    ""
   }
   wait(wait_for_reader, end_game)
  end
  local function on_all_incorrect()
   w_bonusboard.lines = {
    "",
    "wrong!",
    "",
    "too bad.",
    "",
    ""
   }
   game.state = "state_lost"
   start_shake(20)
   sfx(c_snd_wrong)
   wait(wait_for_reader, end_game)
  end

  on_all_correct_fn = on_all_correct
  on_all_incorrect_fn = on_all_incorrect
 else
  w_messageboard_set_message("i will solve", "the puzzle!")
 end

 local count = count_letter_in_puzzle("*")
 if (count == 0) then
  puzzle_guess_letter("*", is_bonus_round)
  if (on_all_correct_fn) on_all_correct_fn()
  return
 end

 if (player_one) then
  select_letter_tile_to_insert()
  local function on_pick()
   local all_done, correct = puzzle_guess_letter(w_letterboard.letter, is_bonus_round)
   if (all_done) then
    w_letterboard.remaining[w_letterboard.letter].selected = false
    if (is_bonus_round) then
     if (correct) on_all_correct_fn() else on_all_incorrect_fn()
    end
   else
    select_letter_tile_to_insert()
   end
  end
  w_letterboard_activate("letters", on_pick, undo_letter_tile_insertion)
 else
  repeat
   local all_done, correct = puzzle_guess_letter(cpu_player_guess_letter("puzzle"), is_bonus_round)
  until all_done
  if (is_bonus_round) then
   if (correct) on_all_correct_fn() else on_all_incorrect_fn()
  end
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
  btnp(c_btn_left) or
  btnp(c_btn_right) or
  btnp(c_btn_up) or
  btnp(c_btn_down) or
  btnp(c_btn_o) or
  btnp(c_btn_x)
end

function start_game()
 set_opponent_player(game.players.cpu1)
 set_opponent_player(game.players.cpu2)
 next_round(1) -- skip rounds here
end
function set_opponent_player(player)
 local opponent_fields = split(opponents[ceil(rnd(#opponents))], "_")
 player.name = opponent_fields[1]
 player.skill = opponent_fields[2]
 player.cuss = opponent_fields[3]
 player.cheer = opponent_fields[4]
 player.excuse = opponent_fields[5]
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
  if (w_wheel.speed == 100) then
   w_wheel.speed = 150
   -- local perfect_spin_bonus = c_num_full_power_prize * (ceil(rnd(c_num_full_power_prize_max_factor)))
   -- game.active_player.round_total += shr(perfect_spin_bonus, 16)
   w_messageboard_set_message("super-spin!")
   -- w_messageboard.line2 = "reward: $"..perfect_spin_bonus
   sfx(c_snd_super_spin)
  end
  w_wheel.spinning = true
  mode_name = ""
 elseif (not w_wheel.spinning) then
  w_wheel.speed = 0
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
  w_wheel.item_value = tonum(item[1]) or 0
  w_wheel.item_name = "$"..w_wheel.item_value
  w_wheel.item_colour = item[2]
  if (w_wheel.item_value == 0) w_wheel.item_name = item[1]
  if (item[3]) w_wheel.item_value = tonum(item[3]) -- bonus prize
  if (prev_item != w_wheel.item_name) then
   w_wheel.just_ticked = true
   sfx(c_snd_tick, 2)
  else
   w_wheel.just_ticked = false
  end
 else
  -- w_wheel.speed = 1 -- comment out these three lines to have infinite spin
  w_wheel.speed = 0
  w_wheel.spinning = false
  game.state = "state_spin_completed"
 end
end
 
function _draw()
 cls()
 shake()

 if (screens[screen_name] and screens[screen_name].draw) screens[screen_name].draw()

 -- these are centering guides
 -- rect(0, 0, 127, 127, c_clr_red)
 -- line(63, 0, 63, 127, c_clr_green)
end

function draw_clue()
 local x = w_puzzleboard.x
 local y = w_puzzleboard.y + 43
 rectfill(x, y - 2, 126, 51, c_clr_black)
 print("clue: "..puzzle.clue, x, y, c_clr_yellow)
 -- print(""..w_wheel.tick..","..w_wheel.pick, x, y, c_clr_red)
end

-- decides how to fit a puzzle
-- into the 11,13,13,11 grid
-- returns it as a puzzle obj
function to_puzzle(puzzle_letters, clue)
 local puzzle = { clue = clue }
 local words = {}
 words[1] = {}
 local wordcount = 0
 local inword = false
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
 local maxcols = { 11, 13, 13, 11 }
 local row = 1
 local rowcol = 1

 local tiles = {}
 for r=1,4 do
  tiles[r] = {}
  for col=1,13 do
   tiles[r][col] = { letter = nil }
  end
 end

 local word = 1
 local rows_used = {}
 while (word <= count(puz.words)) do
  if (row > 4) break
  -- if (rowcol == 1 and (row == 1 or row == 4)) rowcol = 2
  local len = count(puz.words[word])
  -- if the word fits on this row
  if (len + rowcol - 1 <= maxcols[row]) then
   local i = 0
   for l in all(puz.words[word]) do
    tiles[row][rowcol+i] = { letter = l }
    -- printh("cell["..row.."]["..rowcol+i.."] = "..l)
    i += 1
   end
   tiles[row][rowcol+i] = { letter = nil }
   word += 1
   rowcol += len + 1
   rows_used[row] = true
  else
   row += 1
   rowcol = 1
  end
 end

 -- print_board(tiles)

 -- center puzzle vertically
 local row_adjust = 0
 if (#rows_used < 3) then
  row_adjust = 1
  for row=#rows_used,1,-1 do
   for i=1,maxcols[row] do
    tiles[row+row_adjust][i] = tiles[row][i]
    tiles[row][i] = { letter = nil }
   end
  end
 end

 -- print_board(tiles)

 -- center puzzle horizontally
 for row=1,4 do
  local linelen = get_line_len(tiles[row])
  if (linelen > 0) then
   local adjust = flr((maxcols[row] - linelen) / 2)
   -- printh("row: "..row..", max: "..maxcols[row]..", adjust: "..adjust..", linelen: "..linelen)
   if (adjust > 0) then
    for i=linelen + 1,2,-1 do
     tiles[row][i+adjust-1] = tiles[row][i-1]
     tiles[row][i-1] = { letter = nil }
    end
   end
  end
 end

 -- print_board(tiles)

 return tiles
end

-- function print_board(tiles)
--  printh("-------------")
--  for row=1,4 do
--   local str = ""
--   for col=1,13 do
--    local l = tiles[row][col].letter
--    if (l == nil) l = "."
--    str ..= l
--   end
--   printh(str)
--  end
--  printh("-------------")
-- end

function get_line_len(line)
 local len = 0
 local spaces = 0
 local last = nil
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

current_selection_colour = 0
current_selection_colour_dir = 1
function next_selection_colour(default, instant)
 if (not instant and time() < time_since_input + 5) return default or c_clr_black
 if (current_selection_colour == 15) then
  current_selection_colour_dir = -1
 elseif (current_selection_colour == 7) then -- cycle through the brighter colours
  current_selection_colour_dir = 1
 end
 current_selection_colour += current_selection_colour_dir
 return current_selection_colour
end

--[[
-- old slow black and white pulse
current_selection_colour = 0
selected_colours = {
 c_clr_black,
 c_clr_dark_gray,
 c_clr_light_gray,
 c_clr_white
}
next_selection_colour_delay_max = 4
next_selection_colour_delay = next_selection_colour_delay_max * 20
next_selection_colour_dir = 1
function next_selection_colour()
 if (time() < time_since_input + 5) return c_clr_black
 if (next_selection_colour_delay > 0) then
  next_selection_colour_delay -= 1
  return selected_colours[current_selection_colour]
 end
 next_selection_colour_delay = next_selection_colour_delay_max
 current_selection_colour += next_selection_colour_dir
 if (current_selection_colour > #selected_colours) then
  next_selection_colour_dir = -1
  current_selection_colour += next_selection_colour_dir
 elseif (current_selection_colour < 0) then
  next_selection_colour_dir = 1
  current_selection_colour += next_selection_colour_dir
  next_selection_colour_delay = next_selection_colour_delay_max * 20
 end
 return selected_colours[current_selection_colour]
end
--]]

-- https://www.lexaloffle.com/bbs/?pid=22809#p
-- modified to add commas
function u32_tostr(v)
 local orig_v = v
 local s=""
 local i=0
 repeat
  local t=v>>>1
  s=(t%0x0.0005<<17)+(v<<16&1)..s
  v=t/5
  i+=1
  if (i == 3 and v != 0 and orig_v > 0.15258) then -- add comma over 9999
   s = ","..s
   i = 0
  end
 until v==0
 return s
end

puzzles = {
 "celebrity_abby russell",
 "celebrity_alex navarro",
 "celebrity_brad shoemaker",
 "celebrity_dan ryckert",
 "celebrity_david letterman",
 "celebrity_drew scanlon",
 "celebrity_jeff gerstmann",
 "celebrity_vinny caravella",
 "game_crokinole",
 "game_wheel of fortune",
 "lyrics_dappity-doh dappity-doh dappity-doh dappity-doh",
 "lyrics_piledriver! seems like a bloody mistake",
 "quote_another visitor! stay a while...",
 "quote_bomb in my briefcase",
 "quote_can you do any less!?",
 "quote_chautauqua! chautauqua!",
 "quote_from frog to frog to frog to frog",
 "quote_hush up, puppy boy",
 "quote_not all salmon, zena. the dead ones",
 "quote_you don't wanna watch a three hour movie?",
 "quote_you wrecked my bed!",
 "slogan_blaze your glory",
 "slogan_i adore my commodore",
 "slogan_the lowest price is the law",
 "tv show_fraggle rock",
 "tv show_garfield and friends",
 "video game_frantic freddie",
 "video game_great giana sisters",
 "video game_kings of the beach",
 "video game_super blood hockey",
 "video game_super mario brothers",
 "video game_superstar ice hockey",
 "video game_toy bizarre",
 --[[
 --[[
 "testing_rstlne cmda",
 "statement_goodbye bitcoin depot",
 "statement_rest in peace bitaccess",
 "statement_i am out of here",
 "statement_time to move on",
 "place_nelson british columbia",
 "activity_programming in lua"


 "wrong guess_the photos of their kids",
 "close but no cigar_trojan horsey",
 "hudgzackism_is it time for food for durdles?",
 "hudgzackism_it's too hard for this one",
 "hudgzackism_all my hard work",
 "hudgzackism_supper is served in the dining room",
 "hudgzackism_dant some food",
 "hudgzackism_jar farter",
 "hudgzackism_durdley courtesy",
 "hudgzackism_she's so durdley",
 "hudgzackism_and she's a schoochum too",
 "hudgzackism_oh no bisa durdley",
 "hudgzackism_such a little durdley",
 "hudgzackism_it's not time for food for durdles"
 "hack_fart"
 --]]
}
__sfx__
000900001e0501c000110501b05015050000002805000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000d00020650206000000000000000000000000000000000000000000000000000006600066000760008600096000a6000a6000a6000960008600076000000000000000000000000000000000000000000
000a000023050230502304023030230202302023020230202400027000290002a0002c0002d0002e0002e0002f0002f0002f00030000300003000030000300003000030000300003100031000320003200033000
000900001e0501e0501e0501e0501e0501e0501d0501c0501a05018050150501305011050100500e0500b05009050070500405001050000500e0000b000090000800007000070000600005000030000000000000
001000001e0501e0501e0501d0501b0501905014050100500c0500805003050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00040000090600906014000000000d000090600906014000140001900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000000000000000000000015050190501d0502105024050270502c0502f0503205000000000002c0502e05032050360503805000000000002c0502e0503105034050370503b05000000000000000000000
0005000001050020500305004050070500b05011050170501f0502805031050330003f00032000360003f00000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100003a05027000000001300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100002d05033050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100001d05016050270500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000010605000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000010805000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000010a05000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000010e05000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0003000021050220502305025050290502f050350503a0503e05029000200002f0502e0502e0502f050310503305036050380503b0503c0503d0503d0503d0503c0503b050370503605036050340503205030050
