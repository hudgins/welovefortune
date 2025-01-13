pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

game_version = "v20250112"

-- fixme - eliminate this dependency
 w_scoreboard = {
  x = 56,
  y = 74,
  w = 128 - 56,
  h = 34,
  slide = "x,56,128",
 }

c_clr_theme = 10 -- 10 yellow, 9 orange

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

mode_name = ""
month = null
day = null
today_played = false
today_played_bypass_count = 0
puzzle = {}

wait_until = 0
wait_callback = nil

function toggle_theme_music(desired_music_playing)
 if (music_playing == desired_music_playing) return
 music_playing = desired_music_playing
 music(desired_music_playing)
end

screens = {}
function screens_start_init()
 screens.start_view = {}
end
function screens.start_draw()
 local start = screens.start_view
 w_arches_draw()
 w_puzzleboard_draw()

 color(12)
 print(game_version, 90, 0, 5)
 if (not today_played) then
  print("❎ to play", 43, 100, clr_flashing(true))
  print("by allan hudgins", 32, 110, 7)
 else
  print("new puzzle tomorrow", 26, 100, clr_flashing(true))
 end
end
function screens.start_update()
 local start = screens.start_view
 if (btnp(5)) then 
  if (not today_played or today_played_bypass_count > 9) then
   start_slide({ w_arches, w_puzzleboard }, "off", next_round)
  else
   today_played_bypass_count += 1
  end
 end
end

screens.round = {}
function screens.round_draw()
 w_arches_draw()
 w_puzzleboard_draw()
 if (bonus_mode == "spin_prize") then
  w_wheel_draw()
  w_messageboard_draw()
 else
  w_clue_draw()
  w_round_draw()
  w_letterboard_draw()
  w_bonusboard_draw()
 end
end
function screens.round_update()
 if (screens.round[game_state]) screens.round[game_state]()
end
function screens.round.state_wait_action()
 update_chosen_action()

 if (btnp(5) and w_messageboard.choice == "spin") action_spin()
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
 if (true) then
  sfx(w_wheel.item_name == "nothing" and 3 or 0)
  if (w_wheel.item_name == "$1000000") then
   w_messageboard_set_message("one million\ndollars!!!!")
  else
   w_messageboard_set_message("a "..w_wheel.item_name.."\nworth "..render_money(w_wheel.item_value).."!")
  end
  num_grand_prize = shr(w_wheel.item_value, 16)
  delay(start_bonus_round, 2)
  -- fixme bankrupt should be possible in bonus round
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
  -- w_messageboard_set_message(game_active_player.cuss.."!~player")
  -- fixme anything here?
  delay(event_bankrupt)
 end
end

function bonus_choose_letters()
 game_state = "state_bonus_letters"
 if (w_wheel.item_name == "$1000000") then
  w_bonusboard.lines = split("for the million dollars^^choose 3 consonants:^_ _ _^and one vowel:^_", "^")
 else
  w_bonusboard.lines = split("for the "..float_to_money_str(num_grand_prize).." "..w_wheel.item_name.."^^choose 3 consonants:^_ _ _^and one vowel:^_", "^")
 end
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

wheel_items = {
 split("$1000000_11_100000,plant_14_3,vacation_10_800,shed_8_85,bicycle_12_70,scooter_10_180,watch_14_12,c64_12_50,toque_13_3,phone_8_120,computer_10_300,tree_12_110,lamp_14_21,tv_12_333,table_10_158,couch_13_423,truck_8_4500,t-shirt_12_1,cat_10_25,dog_14_35,boat_8_2500,hot tub_12_700,car_13_3900,vacuum_10_8"),
}
function w_wheel_init()
 local items = wheel_items[1]
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
  if (w_messageboard.choice == "solve") print("❎", x0 + 48 + 6, y0 + 3, indicator_colour)
  print("solve", x0 + 48, y0 + 9, 0)
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
 print("   bonus", x, y + 2, 12)
end

function _init()
 cartdata("wlftest1")
 restart()
end

function restart()
 unflash()
 event_queue = {}
 mode_name = ""
 screen_name = "start"
 name_timeout = 0
 month = stat(81)
 day = stat(82)
 date = tostr(month)..tostr(day)
 last_played = tostr(dget(0))..tostr(dget(1))
 today_played = date == last_played

 game_state = "state_start"
 bonus_mode = nil
 game_only_vowels_remain_in_puzzle = false
 game_only_vowels_remain_on_board = false
 game_no_vowels_remain_on_board = false
 game_all_letters_revealed = false
 game_can_spin = true
 puzzle = to_puzzle("", "")

 w_arches_init()
 w_puzzleboard_init()
 w_letterboard_init()
 w_messageboard_init()
 w_clue_init()
 w_round_init()
 w_wheel_init()
 w_bonusboard_init()

 screens_start_init()

 local function reveal_puzzle()
  toggle_theme_music(2)
  puzzle = to_puzzle("we love fortune^ daily", "")
  local function reveal_title()
   puzzle.revealed = true
  end
  delay(reveal_title, 0.5)
 end
 delay(reveal_puzzle, 0.5)
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
 if (player_adjusting_power()) return

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

function player_adjusting_power()
 if (game_state != "state_spin") return false
 return btn(5) and w_messageboard.choice == "spin"
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

function puzzle_guess_letter(letter)
 local all_done, correct = insert_puzzle_guess_letter(letter), false
 if (all_done) then
  correct = check_puzzle_correctness()
  if (correct) then
   game_state = "state_won"
   puzzle.revealed = true
   sfx(6)
   return all_done, correct
  else
   start_shake()
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

 game_can_spin = bonus_mode == "spin_prize" or not game_all_letters_revealed and not game_only_vowels_remain_in_puzzle and not game_only_vowels_remain_on_board

 w_messageboard.message_displayed = false
 w_messageboard.choices = {}
 w_messageboard.choice_idx = 1
 if (game_can_spin) add(w_messageboard.choices, "spin")
 if (not bonus_mode) add(w_messageboard.choices, "solve")
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
    next_time += 0.5
    queue(make_reveal(cell), next_time)
   end
  end
 end
 if (on_reveal_done) queue(on_reveal_done, next_time + 0.5)
end

function event_bankrupt()
 -- fixme
 delay(update_actions_available)
end

function end_round()
 w_letterboard.remaining[w_letterboard.letter].selected = false
end

function next_round()
 toggle_theme_music(-1)
 screen_name = "round"
 w_puzzleboard_init("normal")
 w_wheel_init()

 today_played_bypass_count = 0
 mode_name = ""
 bonus_mode = "spin_prize"
 toggle_theme_music(-1)
 local function cb()
  update_actions_available()
  w_messageboard_set_message("hold ❎ to spin\nfor your prize!")
 end
 start_slide({ w_wheel, w_messageboard }, "on", cb)
 return
end

function start_bonus_round()
 local function done()
  bonus_mode = "solve_puzzle"
  w_bonusboard.lines = split("      bonus round^^we give you:^  r s t l n^and^  e", "^")
  start_slide({ w_clue, w_round, w_letterboard, w_bonusboard }, "on", new_puzzle)
 end
 start_slide({ w_wheel, w_messageboard }, "off", done)
end

function end_game()
 mode_name = ""
 puzzle.revealed = true
 dset(0, month)
 dset(1, day)
 -- w_bonusboard.lines[3] = float_to_money_str(game_active_player.game_total).." grand total"
 -- fixme show total stats
 -- games played
 -- streak?
 -- won
 -- lost
 -- total earnings
 delay(restart, 4)
end

function new_puzzle()
 local puzzle_data = split(puzzles[month][day], "_")
 puzzle = to_puzzle(puzzle_data[2], puzzle_data[1])

 w_letterboard_init()

 for x in all(c_letters.symbols) do
  reveal_puzzle_letter(x)
 end

 if (bonus_mode == "solve_puzzle") reveal_letters(split("r,s,t,l,n,e"), bonus_choose_letters)
end

function action_spin()
 if (not game_can_spin) return
 mode_name, game_state = "spin", "state_spin"
 w_messageboard_set_message("wheeeee\neeeeel!~player")
 adjust_power()
end

function action_solve()
 local on_all_incorrect_fn, on_all_correct_fn = true
 game_state = "state_guess_puzzle"

 w_bonusboard.lines = split(",   solve the puzzle!,,,,❎ to enter  🅾️ to undo")
 local function on_all_correct()
  sfx(6)
  game_state = "state_won"
  if (w_wheel.item_name == "$1000000") then
   w_bonusboard.lines = split("congratulations!^^you have won^a million dollars!^^(before tax...)", "^")
  else
   w_bonusboard.lines = split("congratulations!^^the "..float_to_money_str(num_grand_prize).." "..w_wheel.item_name.."^^is yours!", "^")
  end
  delay(end_game)
 end
 local function on_all_incorrect()
  w_bonusboard.lines = split("wrong!,,too bad.,,maybe tomorrow...,")
  game_state = "state_bonus_puzzle_lost"
  start_shake()
  delay(end_game)
 end

 on_all_correct_fn = on_all_correct
 on_all_incorrect_fn = on_all_incorrect

 local function deferred()
  action_solve_deferred(on_all_correct_fn, on_all_incorrect_fn)
 end
 local factor = 0.2
 delay(deferred, factor)
end

function action_solve_deferred(on_all_correct_fn, on_all_incorrect_fn)
 local count = count_letter_in_puzzle("*")
 if (count == 0) then
  puzzle_guess_letter("*")
  if (on_all_correct_fn) on_all_correct_fn()
  return
 end

 select_letter_tile_to_insert()
 local function on_pick()
  local all_done, correct = puzzle_guess_letter(w_letterboard.letter)
  if (all_done) then
   if (correct) on_all_correct_fn() else on_all_incorrect_fn()
  else
   select_letter_tile_to_insert()
  end
 end
 w_letterboard_activate("letters", on_pick, undo_letter_tile_insertion)
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
 next_round()
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
   -- w_messageboard_set_message(game_active_player.shout.."!~player")
   -- fixme anything here?
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
  if (w_wheel.cheat and (w_wheel.item_name == "bankrupt")) then
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

puzzles = {}
puzzles[1] = split("whatcha doin'?_flying in a seaplane~thing_picnic blanket~thing_magazine~song lyrics_baby shark doo doo doo doo doo doo~phrase_flip the page~thing_grocery list~thing_the freezing point~phrase_rise to the occasion~occupation_cake decorator~phrase_what goes up must come down~place_my home gym~fun & games_swing dancing~thing_cement mixer~on the map_fort worth texas~whatcha doin'?_scribbling something~phrase_do not disturb~event_a difficult journey~place_magic shop~thing_covered wagon~thing_felt tip pen~thing_creative writing~fun & games_learning how to sail~thing_fortune cookie~phrase_they owe me a favor~thing_bobby pin~phrase_it's my world you're just living in it~thing_basketball~things_dinosaur fossils~title_saturday night fever~event_kentucky derby~phrase_you won't hear me complaining!", "~")
puzzles[2] = split("thing_comic book~whatcha doin'?_being playful~in the kitchen_paper plates~place_busy train station~whatcha doin'?_sticking the landing~whatcha wearin'?_plush bathrobe~phrase_nothing to do and all day to do it~thing_a quick pivot~whatcha doin'?_managing risk~food & drink_mystery meat~food & drink_buttered popcorn~things_hundreds of pictures~whatcha wearin'?_driving gloves~whatcha doin'?_doodling in my notebook~food & drink_guava cake~whatcha wearin'?_suit of armor~thing_sweet potato~fun & games_aerobic exercise~fun & games_awesome rafting tour~thing_drip-dry shirt~phrase_mighty and powerful~thing_piggy bank~fiction person_count dracula~occupation_cartoonist~event_opening ceremony~thing_hot buttered popcorn~thing_shock absorber~thing_black and blue mark", "~")
puzzles[3] = split("thing_comic book~whatcha doin'?_being playful~in the kitchen_paper plates~place_busy train station~whatcha doin'?_sticking the landing~whatcha wearin'?_plush bathrobe~phrase_nothing to do and all day to do it~thing_a quick pivot~whatcha doin'?_managing risk~food & drink_mystery meat~food & drink_buttered popcorn~things_hundreds of pictures~whatcha wearin'?_driving gloves~whatcha doin'?_doodling in my notebook~food & drink_guava cake~whatcha wearin'?_suit of armor~thing_sweet potato~fun & games_aerobic exercise~fun & games_awesome rafting tour~thing_drip-dry shirt~phrase_mighty and powerful~thing_piggy bank~fiction person_count dracula~occupation_cartoonist~event_opening ceremony~thing_hot buttered popcorn~thing_shock absorber~thing_black and blue mark~fiction person_porky pig~whatcha doin'?_dipping my feet in the ocean~thing_totem pole", "~")
puzzles[4] = split("things_serenity and charm~same letter_cottage condo castle~phrase_smooth sailing~thing_toboggan~food & drink_a bowl of gumbo~event_fancy banquet~thing_laundry list~quotation_remember the alamo~thing_naturally curly hair~fun & games_singing a song~living things_school of tropical fish~living things_baby hippos~food & drink_hot chocolate~thing_crash helmet~on the map_sydney australia~whatcha doin'?_putting on lip gloss~phrase_e t phone home~thing_a knock at the door~phrase_bombs away~thing_ironing board~place_guesthouse~song lyrics_jingle bell rock~whatcha doin'?_scheduling a meeting~thing_jelly doughnut~before & after_bowling trophy wife~thing_coca-cola~phrase_make your next move your best move~thing_buttonhole~whatcha wearin'?_gardening gloves~around the house_coin collection", "~")
puzzles[5] = split("thing_stroke of luck~thing_kangaroo~character_bambi~place_bamboo forest~whatcha doin'?_staying late~thing_railroad timetable~whatcha doin'?_going the extra mile~living thing_ferocious lion~proper name_olympic gold medalist chloe kim~thing_jumping jack~thing_picnic basket~thing_booster shot~occupation_fashion designer~phrase_service with a smile~phrase_breaka promise~whatcha doin'?_hanging out at work~show biz_k-pop band~thing_american flag~fiction person_peter rabbit~phrase_quite perplexing~food & drink_fresh tropical fruit~thing_forklift truck~phrase_somebody has to win~fun & games_taking a quick jog~phrase_smooth a silk~whatcha doin'?_networking~event_valentine's day!~title_ring around the rosy~thing_vaccum cleaner~fun & games_playing a round of miniature golf~phrase_don't you know who i am?", "~")
puzzles[6] = split("place_empty hayloft~thing_collect call~whatcha doin'?_sharing everything~thing_stained glass window~thing_purchase price~same letter_beach ball beach blanket beach bum~phrase_happy hanukkah~around the house_squeaky hinge~thing_belly button~character_frosty the snowman~whatcha doin'?_last-minute shopping~phrase_that was funny~fun & games_lying on my paddleboard~on the map_pacific coast highway~on the map_mount olympus~thing_steam shovel~place_volleyball court~things_stunning photographs~thing_daddy longlegs~on the map_hollywood boulevard~thing_doggie bag~fiction person_captain power~thing_smartphone~event_a perfect ending~phrase_i'm resting my eyes!~thing_praying mantis~phrase_finger licking good~thing_guide dog~fun & games_climbing a tree in the backyard~thing_helicopter", "~")
puzzles[7] = split("things_serenity and charm~same letter_cottage condo castle~phrase_smooth sailing~thing_toboggan~food & drink_a bowl of gumbo~event_fancy banquet~thing_laundry list~quotation_remember the alamo~thing_naturally curly hair~fun & games_singing a song~living things_school of tropical fish~living things_baby hippos~food & drink_hot chocolate~thing_crash helmet~on the map_sydney australia~whatcha doin'?_putting on lip gloss~phrase_e t phone home~thing_a knock at the door~phrase_bombs away~thing_ironing board~place_guesthouse~song lyrics_jingle bell rock~whatcha doin'?_scheduling a meeting~thing_jelly doughnut~before & after_bowling trophy wife~thing_coca-cola~phrase_make your next move your best move~thing_buttonhole~whatcha wearin'?_gardening gloves~around the house_coin collection~people_national guard", "~")
puzzles[8] = split("thing_hologram~title_moby dick~fun & games_a royal flush~in the kitchen_paper towels~phrase_by trial and error~event_a captivating sunset~whatcha doin'?_penny pinching~song lyrics_i feel good i knew that i would~food & drink_cookie dough~place_private patio~thing_blood vessel~living thing_white rhinoceros~show biz_sold-out performance~song lyrics_i'm levitating~whatcha doin'?_basking in my own glory~food & drink_foamy milk~around the house_chrome faucet~thing_tape measure~thing_delayed reaction~whatcha doin'?_talking on the phone~thing_food processor~place_outdoor hockey rink~before & after_mumbo jumbo shrimp~fiction person_optimus prime~people_undergrads~thing_impeccable taste~phrase_an angel in disguise~thing_traffic signal~phrase_much much more than a weekend getaway~fun & games_diving off a diving board~same letter_washington wyoming wisconsin", "~")
puzzles[9] = split("thing_life science~phrase_new and noteworthy~show biz_smile for the camera~event_family reunion~song lyrics_im off the deep end watch as i dive in~phrase_we go way back~phrase_wake the kids~song title_monster mash~people_barbershop quartet~whatcha doin'?_last-second shopping~food & drink_candied pecans~movie title_spider-man: no way home~thing_hockey puck~things_days & nights~thing_french toast~phrase_any suggestions?~whatcha wearin'?_a pair of sunglasses~thing_bill of rights~whatcha doin'?_howling like a wolf~thing_backgammon~thing_talcum powder~living thing_tiger lily~whatcha wearin'?_bedroom slippers~place_undisclosed location~thing_model railroad~phrase_a frog in my throat~thing_cockroach~song lyrics_don't think i fit in at this party~thing_can opener~show biz_taking the stage", "~")
puzzles[10] = split("whatcha doin'?_flying in a seaplane~thing_picnic blanket~thing_magazine~song lyrics_baby shark doo doo doo doo doo doo~phrase_flip the page~thing_grocery list~thing_the freezing point~phrase_rise to the occasion~occupation_cake decorator~phrase_what goes up must come down~place_my home gym~fun & games_swing dancing~thing_cement mixer~on the map_fort worth texas~whatcha doin'?_scribbling something~phrase_do not disturb~event_a difficult journey~place_magic shop~thing_covered wagon~thing_felt tip pen~thing_creative writing~fun & games_learning how to sail~thing_fortune cookie~phrase_they owe me a favor~thing_bobby pin~phrase_it's my world you're just living in it~thing_basketball~things_dinosaur fossils~title_saturday night fever~event_kentucky derby~phrase_you won't hear me complaining!", "~")
puzzles[11] = split("thing_comic book~whatcha doin'?_being playful~in the kitchen_paper plates~place_busy train station~whatcha doin'?_sticking the landing~whatcha wearin'?_plush bathrobe~phrase_nothing to do and all day to do it~thing_a quick pivot~whatcha doin'?_managing risk~food & drink_mystery meat~food & drink_buttered popcorn~things_hundreds of pictures~whatcha wearin'?_driving gloves~whatcha doin'?_doodling in my notebook~food & drink_guava cake~whatcha wearin'?_suit of armor~thing_sweet potato~fun & games_aerobic exercise~fun & games_awesome rafting tour~thing_drip-dry shirt~phrase_mighty and powerful~thing_piggy bank~fiction person_count dracula~occupation_cartoonist~event_opening ceremony~thing_hot buttered popcorn~thing_shock absorber~thing_black and blue mark~fiction person_porky pig~whatcha doin'?_dipping my feet in the ocean", "~")
puzzles[12] = split("thing_life science~phrase_new and noteworthy~show biz_smile for the camera~event_family reunion~song lyrics_im off the deep end watch as i dive in~phrase_we go way back~phrase_wake the kids~song title_monster mash~people_barbershop quartet~whatcha doin'?_last-second shopping~food & drink_candied pecans~movie title_spider-man: no way home~thing_hockey puck~things_days & nights~thing_french toast~phrase_any suggestions?~whatcha wearin'?_a pair of sunglasses~thing_bill of rights~whatcha doin'?_howling like a wolf~thing_backgammon~thing_talcum powder~living thing_tiger lily~whatcha wearin'?_bedroom slippers~place_undisclosed location~thing_model railroad~phrase_a frog in my throat~thing_cockroach~song lyrics_don't think i fit in at this party~thing_can opener~show biz_taking the stage~place_the window seat", "~")

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

