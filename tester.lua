function split (inputstr, sep)
        if sep == nil then
                sep = ","
        end
        local t={}
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                table.insert(t, str)
        end
        return t
end

function to_puzzle(puzzle_letters, clue)
 local puzzle = { clue = clue }
 local words = {}
 words[1] = {}
 local wordcount = 0
 local inword = false
 for i=1,#puzzle_letters do
  l = puzzle_letters:sub(i,i)
  if (l == " ") then
   if (inword) then
    inword = false
   end
  elseif (not inword) then
   inword = true
   wordcount = wordcount + 1
   words[wordcount] = ""
   words[wordcount] = words[wordcount] .. l
  else
   words[wordcount] = words[wordcount] .. l
  end
 end

 wordcount = wordcount + 1

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
 while (word <= #puz.words) do
  if (row > 4) then
   break
  end
  local len = #puz.words[word]
  -- if the word fits on this row
  local force_next_line = false
  if (len + rowcol - 1 <= maxcols[row]) then
   local i = 0
   for x=1,#puz.words[word] do
    l = puz.words[word]:sub(x,x)
    if (l == "^") then
     force_next_line = true
     break
    end
    tiles[row][rowcol+i] = { letter = l }
    i = i + 1
   end
   tiles[row][rowcol+i] = { letter = nil }
   word = word + 1
   if (force_next_line) then
    rowcol = 13
   else
    rowcol = rowcol + len + 1
   end
   rows_used[row] = true
  else
   row = row + 1
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
   local adjust = math.floor((maxcols[row] - linelen) / 2)
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
 local len = 0
 local spaces = 0
 local last = nil
 for i=1,#line do
  col = line[i]
  if (col.letter) then
   len = len + 1
   last = col.letter
  elseif (last) then
   spaces = spaces + 1
   last = nil
  end
 end
 if (not last and spaces > 0) then
  spaces = spaces - 1
 end
 return len + spaces
end

-- puzzle check routines
function check_puzzle(puzzle)
 local puzzle_data = split(puzzle, "_")
 puzzle = to_puzzle(puzzle_data[2], puzzle_data[1])
 local puzzle_rendered = ""
 for row=1,4 do
  local line = ""
  local prev_letter = false
  for col=1,13 do
   local l = puzzle.tiles[row][col].letter
   if (l ~= nil) then
    prev_letter = true
   end
   if (l == nil and prev_letter) then
    prev_letter = false
    l = " "
   end
   if (col == 13 and l ~= nil and l ~= " ") then
    l = l.." "
   end
   if (l ~= nil) then
    line = line..l
   end
  end
  puzzle_rendered = puzzle_rendered..line
 end
 local done = false
 while (not done) do
  end_letter = puzzle_rendered:sub(#puzzle_rendered,#puzzle_rendered)
  if (end_letter == " ") then
   puzzle_rendered = puzzle_rendered:sub(1, #puzzle_rendered - 1)
  else
   done = true
  end
 end

 local letters_minus_hats = ""
 for i=1,#puzzle.letters do
  l = puzzle.letters:sub(i,i)
  if (l ~= "^") then
    letters_minus_hats = letters_minus_hats..l
  end
 end

 if (letters_minus_hats ~= puzzle_rendered) then
  print("render failure: '"..puzzle.letters.."'")
  print("                '"..puzzle_rendered.."'")
  print_board(puzzle.tiles)
  return 1
 end
  print_board(puzzle.tiles)
 if (string.len(puzzle.clue) > 17) then
  print("render failure: '"..puzzle.clue.."'")
  print("                '"..string.sub(puzzle.clue, 1, 17))
  return 1
 end
 return 0
end


function print_board(tiles)
 print("-------------")
 for row=1,4 do
  local str = ""
  for col=1,13 do
   local l = tiles[row][col].letter
   if (row == 1 and col == 1) then
    l = "/"..(l or ".")
   elseif (row == 1 and col == 12) then
    l = "\\"
   elseif (row == 1 and col == 13) then
    l = ""
   elseif (row == 4 and col == 1) then
    l = "\\"..(l or ".")
   elseif (row == 4 and col == 12) then
    l = "/"
   elseif (row == 4 and col == 13) then
    l = ""
   else
     if (l == nil) then
      l = "."
     end
    end
   str = str..l
  end
  print(str)
 end
 print("-------------")
end


-- puzzles = split("movie_the princess bride~movie_raiders of the lost ark~movie_back to the future~movie_when harry met sally...~movie_a nightmare on elm street~movie_ghostbusters~movie_blade runner~movie_ferris bueller's day off~movie_stand by me~tv show_cheers~tv show_night court~tv show_he-man and the masters of the universe~tv show_the facts of life~tv show_the golden girls~tv show_who's the boss?~tv show_family ties~tv show_teenage mutant ninja turtles~song_crazy little thing called love~song_another brick in the wall~song_another one bites the dust~song_bette davis eyes~song_jessie's girl~song_i love rock 'n' roll~song_eye of the tiger~song_every breath you take~song_sweet dreams (are made of this)~song_total eclipse of the heart~song_when doves cry~song_what's love got to do with it~song_i just called to say i love you~song_wake me up before you go-go~song_the power of love~song_money for nothing~song_papa don't preach~song_walk like an egyptian~song_livin' on a prayer~song_i still haven't found what i'm looking for~song_never gonna give you up~song_sweet child o' mine~song_bad medicine~song_every rose has its thorn~song_like a prayer~song_wind beneath my wings~song_blame it on the rain~song_we didn't start the fire~song_another day in paradise~phrase_i'll be back~phrase_i've fallen and i can't get up~phrase_i pity the fool...~phrase_where's the beef?~phrase_pardon me, do you have any grey poupon?~phrase_whatchu talkin' 'bout, willis?~phrase_gag me with a spoon!~phrase_by the power of greyskull!~toys_rubik's cube~toys_hungry hungry hippos~toys_care bears~toys_cabbage patch kids~toys_teddy ruxpin~toys_pound puppies~toys_masters of the universe~toys_sony walkman~toys_transformers~toys_mr. potato head~toys_etch-a-sketch~toys_pez dispenser~computers_commodore 64~computers_ibm personal computer~computers_sinclair zx spectrum~computers_commodore amiga~computers_trs-80 color computer~computers_apple macintosh", "~")
-- puzzles = split("business_backroads brewing company~business_charcuterie totoche~business_craft connection~business_ellison's market~business_epiphany cakes~business_fisherman's market~business_flexy's fresh fruit and vegetables~business_gerick cycle and ski~business_gina's gelato~business_hipperson home hardware~business_kootenay co-op~business_ktk masala shop~business_levity micro gallery~business_lillie & cohoe~business_meteor mushrooms~business_moon monster~business_nature's health products~business_nelson brewing company~business_notably, a book lover's emporium~business_otter books~business_packrat annie's~business_pixie candy shoppe~business_positive apparel~business_reo's video~business_ripping giraffe boardshop~business_shoe la la~business_silverking soya foods~business_soma studio & gallery~business_strange society tattoos~business_the potorium~business_the sacred ride~business_the tickle trunk shop~business_the timber tattoo company~business_the uphill market~business_through the looking glass~business_torchlight brewing company~business_tribute boardshop~business_virtue tea~business_wings grocery~coffee_dominion cafe~coffee_empire coffee~coffee_freshies coffee bar~coffee_java garden cafe~coffee_john ward fine coffee~coffee_no6 coffee company~coffee_oso negro cafe~coffee_sidewinders~coffee_the block at railtown~coffee_the kootenay bakery cafe co-op~coffee_wait's on nelson~highlights_baker street~highlights_cottonwood community market~highlights_cottonwood falls~highlights_downtown local market~highlights_gibson lake loop trail~highlights_gyro park~highlights_kokanee creek old growth forest~highlights_lakeside beach~highlights_marketfest~highlights_nelson artwalk~highlights_nelson fire hall~highlights_nelson leafs hockey~highlights_nelson streetcar~highlights_nelson visitor centre~highlights_nelson's cold war bunker~highlights_pulpit rock trail~highlights_rails to trails~highlights_the capitol theatre~highlights_whitewater ski resort~restaurant_amanda's restaurant~restaurant_ashman's smash burgers and fries~restaurant_awaken cafe~restaurant_beauties~restaurant_big dee's fancy weiners & quality ice cream~restaurant_brixx brewhouse~restaurant_broken hill~restaurant_busaba thai cafe~restaurant_cantina del centro~restaurant_desi donair~restaurant_el taco~restaurant_finley's bar & grill~restaurant_freestyle burrito company~restaurant_full circle cafe~restaurant_how shang shway tea house~restaurant_jackson's hole & grill~restaurant_kc restaurant~restaurant_kootenay tami kitchen~restaurant_kurama sushi~restaurant_leo's pizza and greek taverna~restaurant_louie's steakhouse & lounge~restaurant_main street diner~restaurant_marzano~restaurant_mike's place pub~restaurant_outer clove~restaurant_pitchfork eatery~restaurant_port701 marinaside dining~restaurant_red light ramen~restaurant_rel-ish~restaurant_rose garden cafe~restaurant_sage tapas & wine bar~restaurant_sprout plant-based eatery~restaurant_sushi wood nelson~restaurant_tandoori indian grill & lounge~restaurant_the black cauldron~restaurant_the general store~restaurant_the library lounge~restaurant_the royal~restaurant_the yellow deli~restaurant_thor's pizzeria~restaurant_uptown tavern~restaurant_yum son", "~")
-- puzzles = split("hanyecz_i traded 10,000 bitcoins for pizza~genesis_on brink of second bailout for banks~bishop_if you don't trust people, trust code~carter_restorative, not progressive~colbert_it's gold for nerds~draper_i trust bitcoin more than i trust my bank~finney_seems to be a very promising idea~gamekyuubi_i am hodling~gates_a technological tour de force~gladstein_being weird is one of its defense mechanisms~gore_i am a big fan of bitcoin~kaiser_bitcoin is the currency of resistance~kling_qe is ubi for rich people~mcafee_you can’t stop things like bitcoin~mekhail_bitcoin is cash without the corruption~mekhail_bitcoin is diamonds without the blood~mekhail_bitcoin is gold without the weight~munger_i hope to god my family doesn't buy it~munger_it's noxious poison~odell_stay humble stack sats~satoshi_bitcoin is still very new~satoshi_might make sense to get some in case~satoshi_more like a collectible or commodity~satoshi_not having bitcoin would be the net waste~satoshi_the swarm is headed towards us~saylor_bitcoin is a swarm of cyber hornets~shatner_so bitcoin is cyber snob currency~snowden_bitcoin that can't be sent over the internet~srinivasan_will go up until the old world is replaced~stopndecrypt_an impenetrable fortress of validation~szabo_trusted third parties are security holes~unknown_this is gentlemen~ver_bitcoin never sleeps~voorhees_it will hit thousands of dollars per coin~zhu_bitcoin is a short squeeze on the world", "~")
puzzles = split("thing_the lightning network~thing_paper wallet~thing_space heating bitcoin^ miner~thing_six blockchain confirmations~thing_heavy mempool congestion~thing_segregated witness~thing_merkle tree~thing_distributed ledger technology~thing_blockchain node~thing_twenty-one million circulation cap~thing_low time preference~quote-hanyecz_i traded 10,000 bitcoins for pizza~genesis_chancellor on brink of 2nd bailout for banks~quote-bishop_if you don't trust people, trust code~quote-carter_restorative not progressive technology~quote-colbert_it's gold for nerds~quote-draper_i trust bitcoin more than i trust my bank~quote-finney_seems to be a very promising idea~quote-gamekyuubi_i am hodling~quote-gates_a technological tour de force~quote-gladstein_being weird is one of its defense mechanisms~quote-gore_i am^ a big fan^ of^ bitcoin~quote-kaiser_bitcoin^ is the^ currency of resistance~quote-kling_qe^ is ubi^ for rich people~quote-mcafee_you can't stop things like bitcoin~quote-mekhail_bitcoin^ is cash^ without the corruption~quote-mekhail_bitcoin^ is diamonds without^ the blood~quote-mekhail_bitcoin^ is gold^ without^ the weight~quote-munger_i hope to god my family doesn't^ buy it~quote-munger_it's noxious poison~quote-odell_stay humble stack sats~quote-satoshi_makes sense to get some in case it catches on~quote-satoshi_not having bitcoin would be the net waste~quote-satoshi_the swarm is headed towards us~quote-saylor_bitcoin is a swarm of cyber^ hornets~quote-shatner_so^ bitcoin is^ cyber snob^ currency~quote-snowden_gold's just bitcoin that can't be sent by internet~quote-stpndecrypt_an impenetrable fortress of validation~quote-szabo_trusted third parties are security holes~meme_this is gentlemen~quote-ver_bitcoin never^ sleeps~quote-zhu_bitcoin is a short squeeze on the world", "~")

failures = 0
for i=1,#puzzles do
 print("puzzle: "..puzzles[i])
 failures = failures + check_puzzle(puzzles[i])
end

if (failures > 0) then
  print(failures.." invalid puzzles")
else
  print("all good!")
end

 -- add commas -- ends up taking up too much real estate
 -- local padded = split(units..value..padding, "", false)
 -- local rendered = ""
 -- comma_idx = 0
 -- for i = #padded,1,-1 do
 --  local s = padded[i]
 --  comma_idx += 1
 --  if (comma_idx == 4 and i > 1) then
 --   comma_idx, rendered = 1, ","..rendered
 --  end
 --  rendered = s..rendered
 -- end

-- c_clr_black = 0
-- c_clr_dark_blue = 1
-- c_clr_dark_purple = 2
-- c_clr_dark_green = 3
-- c_clr_brown = 4
-- c_clr_dark_gray = 5
-- c_clr_light_gray = 6
-- c_clr_white = 7
-- c_clr_red = 8
-- c_clr_orange = 9
-- c_clr_yellow = 10
-- c_clr_green = 11
-- c_clr_blue = 12
-- c_clr_indigo = 13
-- c_clr_pink = 14
-- c_clr_peach = 15

-- c_btn_left = 0
-- c_btn_right = 1
-- c_btn_up = 2
-- c_btn_down = 3
-- c_btn_o = 4
-- c_btn_x = 5

-- c_snd_money = 0
-- c_snd_tick = 1
-- c_snd_reveal = 2
-- c_snd_loseseed = 3
-- c_snd_loseturn = 4
-- c_snd_wrong = 5
-- c_snd_freespin = 6
-- c_snd_win = 6
-- c_snd_spin = 7
-- c_snd_button_dir = 8
-- c_snd_button_x = 9
-- c_snd_button_o = 10
-- c_snd_slide = 11
-- c_snd_shake = 12
-- c_snd_super_spin = 15

-- function shake()
--  if (w_wheel.broken) then
--    local nudge_x, nudge_y, nudge_diff, speed = 0, 0, 0, w_wheel.speed
--    if (w_wheel.x + w_wheel.radius >= 128 and w_wheel.break_dx == 1 or w_wheel.x - w_wheel.radius <= 0 and w_wheel.break_dx == -1) w_wheel.break_dx *= -1
--    if (w_wheel.y + w_wheel.radius >= 128 and w_wheel.break_dy == 1 or w_wheel.y - w_wheel.radius <= 0 and w_wheel.break_dy == -1) w_wheel.break_dy *= -1
--    nudge_x = ceil(abs(w_wheel.x - w_wheel.orig_x))
--    nudge_y = ceil(abs(w_wheel.y - w_wheel.orig_y))
--    nudge_diff = nudge_x - nudge_y
--    if (nudge_diff > 5) nudge_x, nudge_y = 1, 0
--    if (nudge_diff < -5) nudge_x, nudge_y = 0, 1
--    if (nudge_x > 1) nudge_x = 1 
--    if (nudge_y > 1) nudge_y = 1 
--    w_wheel.x += flr(w_wheel.break_dx * w_wheel.speed * 0.15) + (nudge_x * w_wheel.break_dx)
--    w_wheel.y += flr(w_wheel.break_dy * w_wheel.speed * 0.15) + (nudge_y * w_wheel.break_dy)
--    printh(tostr(w_wheel.speed)..","..tostr(w_wheel.x)..","..tostr(w_wheel.y)..","..nudge_x..","..nudge_y)
--    w_wheel.broken = w_wheel.x != w_wheel.orig_x or w_wheel.y != w_wheel.orig_y
--  end
-- function break_wheel()
--  sfx(15)
--  w_wheel.orig_x = w_wheel.x
--  w_wheel.orig_y = w_wheel.y
--  w_wheel.broken = true
--  w_wheel.break_dx = rnd(1) > 0.5 and 1 or -1
--  w_wheel.break_dy = rnd(1) > 0.5 and 1 or -1
-- end
