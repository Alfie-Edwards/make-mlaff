pico-8 cartridge // http://www.pico-8.com
version 41

__lua__

#include people.lua


-- setup -----------------------
max_health = 3
max_adjustments = 3


-- state -----------------------
health = max_health
score = 0
lost = false


function _init()
	pal_light_red()

	init_people()

	-- choose({
	-- 		speed = 2,
	-- 		pitch = 2,
	-- 		fun = 0,
	-- 		length = 0,
	-- })

	-- choose({
	-- 		speed = 2,
	-- 		pitch = 0,
	-- 		fun = 0,
	-- 		length = 1,
	-- })

	-- choose({
	-- 		speed = 2,
	-- 		pitch = 0,
	-- 		fun = 2,
	-- 		length = 1,
	-- })

	-- -- win
	-- choose({
	-- 		speed = 2,
	-- 		pitch = 0,
	-- 		fun = 1,
	-- 		length = 1,
	-- })

	-- -- lose
	-- choose({
	-- 		speed = 1,
	-- 		pitch = 0,
	-- 		fun = 1,
	-- 		length = 1,
	-- })
end

function restart()
	health = max_health
	score = 0
	lost = false
	init_people()
end

function _update60()
    if lost and btn(5) then
        restart()
    elseif saying_para_done() then
        if saying and any_input() then
            saying.para += 1
            saying.char = 1
            if saying.para > #saying.paras then
                saying = nil
                choose({speed = rnd(3),
                        pitch = rnd(3),
                        fun = rnd(3),
                        length = rnd(3)})
            end
        end
    else
        saying.char = saying.char + 1
        if saying.char == #saying.paras then
            t_para_completed = t()
        end
    end
end

function lnpx(text) -- length of text in pixels
	return print(text, 0, 999999)
end

function draw_lose_screen()
	local lost_text = "you lost!"
	local lost_text_y = 40

	local score_start_text = "you made "
	local score_end_text = " laughs"
	local score_text_y = 60
	local score_col = 10

	local replay_start_text = "press "
	local replay_button = "❎"
	local replay_end_text = " to play again"
	local replay_text_y = 80
	local replay_col = -5

	color(7)
	print(lost_text, 64 - lnpx(lost_text) / 2, lost_text_y)

	local score_text_length = lnpx(score_start_text..score..score_end_text)
	print(score_start_text, 64 - score_text_length / 2, score_text_y)
	color(score_col)
	print(score, (64 - score_text_length / 2) + lnpx(score_start_text), score_text_y)
	color(7)
	print(score_end_text, (64 - score_text_length / 2) + lnpx(score_start_text..score), score_text_y)

	local replay_text_length = lnpx(replay_start_text..replay_button..replay_end_text)
	print(replay_start_text, 64 - replay_text_length / 2, replay_text_y)
	color(replay_col)
	print(replay_button, (64 - replay_text_length / 2) + lnpx(replay_start_text), replay_text_y)
	color(7)
	print(replay_end_text, (64 - replay_text_length / 2) + lnpx(replay_start_text..replay_button), replay_text_y)
end

max_line_len = 30
max_lines = 6
function wrap(text)
    local lines = {}
    for _, para in ipairs(split(text, "\n")) do
        add(lines, "")
        for _, word in ipairs(split(para, " ", false)) do
            if (#lines[#lines] + #word + 1) > max_line_len then
                if #word > max_line_len then
                    local i = max_line_len - #lines[#lines]
                    lines[#lines] = lines[#lines]..sub(word, 1, i).." "
                    i += 1
                    while i <= #word do
                        add(lines, sub(word, i, i + max_line_len - 1))
                        i += max_line_len
                    end
                else
                    add(lines, word.." ")
                end
            else
                lines[#lines] = lines[#lines]..word.." "
            end
        end
    end
    local result = ""
    for i, line in ipairs(lines) do
        if i > 1 then
            result = result.."\n"
        end
        result = result..line
    end
    assert(#lines <= max_lines)
    return result
end

function _draw()
    cls(4)

	if lost then
		draw_lose_screen()
		return
	end

    -- Speech bubble
    if saying then
        color(5)
        rectfill(5, 87, 122, 125)
        rectfill(2, 90, 125, 122)
        circfill(5, 90, 3)
        circfill(122, 90, 3)
        circfill(5, 122, 3)
        circfill(122, 122, 3)
        print("◆", 8, 84)

        color(1)
        print(sub(saying.paras[saying.para], 1, saying.char), 4, 89)

        if saying_para_done() and strobe(0.66, t_para_completed) then
            color(5)
            print("♥", 111, 124)
            color(4)
            print("♥", 111, 122)
        end
    end

	-- health
	color(8)
	local health_str = ""
	for i = 0, health - 1 do
		health_str = health_str.."♥"
	end
	print(health_str, 128 - (lnpx(health_str) + 2), 4)
	color(7)

	for i,x in ipairs(people_sequencing) do
		local s = x..", "
		print(s, (i-1) * lnpx(s), 0)
	end
	print(current_person_index, 0, 8)
end

function say(paras)
	if type(paras) == "string" then
		paras = {paras}
	end

	for i,v in ipairs(paras) do
		paras[i] = wrap(v)
	end

	saying = {
		char = 1,
		para = 1,
		paras = paras,
	}
end

function saying_para_done()
	return (not saying) or saying.char == #saying.paras[saying.para]
end

function pal_light_red()
	pal(0, 0)
	pal(1, 2)
	pal(2, -8)
	pal(3, 8)
	pal(4, 14)
	pal(5, 7)
end

function lose()
	say("lose!!!!!!!!!!!!!!!!!!")
	say("your score was "..score)
	lost = true
end

function play_laugh(laugh_params)
	--
end

function show_person(face_idx, skin_tone, name)
	say("set person to "..name..", idx "..face_idx..", skin tone "..skin_tone)
end

function show_initial_prompt(prompt, initial_laugh)
	say(prompt)
	play_laugh(initial_laugh)
end

function show_adjustment_prompt(prompt, chosen_laugh)
	say(prompt)
	play_laugh(chosen_laugh)
end

function show_accepted(text, correct_laugh)
	say(text)
	play_laugh(correct_laugh)
end

function strobe(period, offset)
	return (t() - (offset or 0)) % (period * 2) < period
end

function any_input()
	return btn(4) or btn(5)
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
