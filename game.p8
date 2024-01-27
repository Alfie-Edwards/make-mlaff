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

-- laughs ----------------------
-- speed, pitch, fun
laughs = {
    {
        {23, 58, 59},
        {50, 56, 57},
        {49, 54, 55},
    },
    {
        {30, 26, 29},
        {51, 38, 52},
        {21, 22, 53},
    },
    {
        {25, 46, 47},
        {43, 44, 45},
        {40, 41, 42},
    },
}

-- laugh durations ------------
laugh_durations = { 2, 1.25, 0.75 }

-- Speech bubble dimensions ---
max_line_len = 30
max_lines = 6

function _init()
	poke(0x5F2D, 1)
	pal_light_red()
	update_mouse()

	init_people()

    timers = {}
    laughing = false

    sliders = {
        length = { name_x = 8, y = 100, value = 1, grabbed = false },
        speed = { name_x = 12, y = 107, value = 1, grabbed = false },
        pitch = { name_x = 12, y = 114, value = 1, grabbed = false },
        fun = { name_x = 20, y = 121, value = 1, grabbed = false },
    }

    buttons = {
        submit = { x = 110, y = 113, r = 7, on_click = function()
            choose({
                speed = sliders.speed.value - 1,
                pitch = sliders.pitch.value - 1,
                fun = sliders.fun.value - 1,
                length = sliders.length.value - 1, })
            end
        },
    }
end

function restart()
	health = max_health
	score = 0
	lost = false
	_init()
end

function _update60()
    update_mouse()

    if lost and btn(5) then
        restart()
    elseif saying then
        if saying_para_done() then
            if any_input() then
                saying.para += 1
                saying.char = 1
                if saying.para > #saying.paras then
                    saying = nil
                end
            end
        else
            saying.char = saying.char + 1
            if saying.char == #saying.paras then
                t_para_completed = t()
            end
        end
    elseif ready_for_next_person then
        next_person()
        ready_for_next_person = false
    else
        -- Grab and ungrab slider handles.
        if mouse.pressed then
            for _, slider in pairs(sliders) do
                local handle = slider_handle_pos(slider)
                if sqdst(mouse.x, mouse.y, handle.x, handle.y) <= 8 then
                    slider.grabbed = true
                end
            end
        elseif mouse.released then
            for _, slider in pairs(sliders) do
                slider.grabbed = false
            end
        end

        -- Move grabbed slider handles to the nearest point to the mouse.
        for _, slider in pairs(sliders) do
            if slider.grabbed then
                local nearest = {}
                local nearest_dist = 32000
                for value=1, 3 do
                    local handle = slider_handle_pos(slider, value)
                    local dst = sqdst(mouse.x, mouse.y, handle.x, handle.y)
                    if dst < nearest_dist then
                        nearest_dist = dst
                        nearest = value
                    end
                end
                slider.value = nearest
            end
        end

        -- Press buttons.
        if mouse.pressed then
            for _, button in pairs(buttons) do
                if sqdst(mouse.x, mouse.y, button.x, button.y) <= (button.r * button.r) + 2 then
                    button.on_click()
                end
            end
        end
    end

    -- Update timers.
    local i = 1
    while i <= #timers do
        if ((t() - timers[i].t0) >= timers[i].length) and (timers[i].cond == nil or timers[i].cond()) then
            timers[i].action()
            deli(timers, i)
        else
            i += 1
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

    -- Head

    -- Laugh maker
    pal_dark_blue()
    color(1)
    rectfill(0, 98, 127, 127)
    for name, slider in pairs(sliders) do
        color(5)
        print(name, slider.name_x, slider.y)
        color(4)
        line(40, slider.y + 2, 80, slider.y + 2)
        color(5)
        local h = slider_handle_pos(slider)
        rectfill(h.x - 1, h.y - 1, h.x + 1, h.y + 1)
    end
    color(5)
    circfill(buttons.submit.x, buttons.submit.y, buttons.submit.r)

    -- Speech bubble
    if saying then
        pal_light_red()
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

    -- Cursor
    color(0)
    circfill(mouse.x, mouse.y, 1)
end

function slider_handle_pos(slider, value)
    value = value or slider.value
    if value == 1 then
        return { x = 42, y = slider.y + 2}
    elseif value == 2 then
        return { x = 60, y = slider.y + 2}
    else
        return { x = 78, y = slider.y + 2}
    end
end

function sqdst(x1, y1, x2, y2)
    return (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2)
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
    pal({[0] = 0, 2, -8, 8, 14, 7})
end

function pal_dark_blue()
    pal({[0] = 0, -15, 1, -4, 12, 7})
end

function lose()
	say("lose!!!!!!!!!!!!!!!!!!")
	say("your score was "..score)
	lost = true
end

function play_laugh(laugh_params)
    laughing = true
    local sound = laughs[laugh_params.speed + 1][laugh_params.pitch + 1][laugh_params.fun + 1]
    sfx(sound)
    local action = {}

    -- If length > 1, queue up laugh to replay again after it's over (with length - 1).
    if laugh_params.length > 0 then
        action = function()
            play_laugh({
                speed = laugh_params.speed,
                pitch = laugh_params.pitch,
                fun = laugh_params.fun,
                length = laugh_params.length - 1,
            })
        end
    else
        -- If length = 1, queue up setting laughing = false after it's over.
        action = function()
            laughing = false
        end
    end
    add(timers, {
        t0 = t(),
        length = laugh_durations[laugh_params.speed + 1] * 0.75,
        action = action,
    })

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

function show_rejected(text)
	say(text)
end

function strobe(period, offset)
    return (t() - (offset or 0) + period) % (period * 2) < period
end

function any_input()
    return btn(4) or btn(5) or mouse.pressed
end

function update_mouse()
    local down_last = mouse ~= nil and mouse.down
    local down = (stat(34) & 1) != 0
    mouse = {
        x = stat(32) - 1,
        y = stat(33) - 1,
        pressed = (down and not down_last),
        released = (down_last and not down),
        down = down,
    }
end

__gfx__
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd11111111dddddddd
dddddddddddddddddddddddddddd111111ffff1111111122fff72222dddddddddddddddddddddddddddddddddddddddddddddddddddddddd11111111dddddddd
dddddddddddddddddddddddddd11122222fffffffffffffff2222222222dddddddddddddddddddddddddd22222222222dddddddddddddddd11111111dddddddd
dddddddddddddddddddddddd11122222fffffffffffffffffff2222222222ddddddddddddddddddddd1222fffffffffff77ddddddddddddd11111111dddd333d
ddddddddddddddddddddddd1122222ffffffffffffffffffffffffffff22222dddddddddddddddddd122ffffffffffffff77dddddddddddd11111111ddd13333
ddddddddddddddddddddd11122222ffffffffffffffffffffffffffffffff2222ddddddddddddddd122fffff722222fffff77ddddddddddd11111111ddd13333
dddddddddddddddddddd1122222fffffffffffffffffffffffffffffffffffff22dddddddddddddd122ffff777111222ffff7ddddddddddd11111111ddd11331
ddddddddddddddddddd1122222ffffffffffffffffffffffffffffffffffffffff22dddddddddddd122fffff771111122fff77dddddddddd11111111dddd111d
dddddddddddddddddd1122222fffff77777ffffffffffffffffffffffffffffffff22ddddddddddddddddddddd555ddddddddddddddddddddddddddddddddddd
ddddddddddddddddd1122222fffff7777777fffffffffffffffffffffffffffffffff2dddddddddddddddddddd5555dddddddddddddddddddddddddddddddddd
dddddddddddddddd112222ffffff7f7f77777ffffffffffffffffffffffffffffffffffddddddddddddddddddd25555ddddddddddd9dddddd2ddddddddddddd9
ddddddddddddddd112222ffffff7f77f777777ffffffffffffffffffffffffffffffffffdddddddddddddd5d22222255999ddddddd9ddddddd21ddddddddddd9
dddddddddddddd112222ffffff7f7f7f7777777ffffffffffffffffffffffffffffffffffdddddddddddd5555522222955a9ddddddd9ddddd11d9ddddddddd9d
ddddddddddddd1112222ffffff7fff7f7777777fffffffffffffffffffffffffffffffffffdddddddddd25552252222dd25a9dddddd9dddd12d9a9dddddddd9d
dddddddddddd1112222fffffff7fffff7777777fffffffffffffffffff7fffffffffffffff7ddddddddd225552222222dd22dddddddd9dd2dd9aaa9dddddd9dd
ddddddddddd11122222fffffff7fffff777777ffffffffffffffffffff7ffffffffffffffff7ddddddddd2255522251111dddddddd111999999aaaa999999ddd
dddddddddd11112222ffffffffffffff777777ffffffffffffffffffff77fffffffffffffff7ddddddddddd225555177771dddddd11111d9aaaaaaaaaaaa9ddd
dddddddd111112222fffffffffffffff77777fffffffffffffffffffff77ffffffffffffff777dddddddddddd22217777771dddd11221119aaaaaaaaaaaa9ddd
ddddddd111112222fffffffffffffffff77fffffffffffffffffffffff777ffffffffffffff77dddddddddddddd1777717771ddd1dddd119aaaaaaaaaaaa9ddd
dddddd1111222222ffffffffffffffffffffffffffffffffffffffffff777fffffffffffff7f77dddddddddddd177777117771dd1dddd219aaaaaaaaaaaa9ddd
ddddd1111222222ffffffffffffffffffffffffffffffffffffffffff7f77ffffffffffffff777ddddddddddd17777771177771ddddddd19aaaaaaaaaaaa9ddd
ddddd112222222fffffffffffffffffffffffffffffffffffffffffff77777fffffffffffffff7ddddddddddd17777771177771ddddddd29aaaaaaaaaaaa9ddd
dddd112222222ffffffffffffffffffffffffffffffffffffffffffff777777fffffffffffff777dddddddddd17777771177771ddddddd29aaaaaaaaaaaa9ddd
ddd11222222fffffffffffffffffffffffffffffffffffffffffffff7f77777ffffffffffffff77dddddddddd17777771177771dddddddd9aaaaaaaaaaaa9ddd
dd1122222ffffffffffffffffffffffffffffffffffffffffffffff777777777fffffffffffff77ddddddddddd177777117771ddddddddd9aaaaaaaaaaaa9ddd
dd122222fffffffffffffffffffffffff22222fffffffffffffffff7f7777777ffffffffff7f777dddddddddddd1777717771dddddddddd9aaaaaaaaaaaa9ddd
d112222fffffffffffffffffffffffff2122222222222222fffff7fff7777777ffffffffff7f7777dddddddddddd17777771ddddddddddd9a333333333aa9ddd
d11222fffffffffffffffffffffffff112ffffffffffffffffffff77777777777fffffffff7f7777ddddddddddddd177711dddddddddddd93bbb333bbbba9ddd
112222fffffffffffffffffffffffff12fffffffffffffffffff7777777777777fffffffff777777dddddddddddddd111dddddddddddddd93bbbb3bbbbbb9ddd
112222ffffffffffffffffffffffff112f7ffffffffffff777777777777777777fffffff7f7f7777dddddddddddddddddddddddddddddddd93bbb3bbbbb9dddd
11222fffffffffffffffffffffffff11277f77777777777777777777777777777fffffff7f7f7777ddddddddddddddddddddddddddddddddd9bbbbbbbb9ddddd
11222fffffffffffffffffffffffff11277777777777777777777777777777777fffffff7f7f7777ddddddddddddddddddddddddddddddddd999999999dddddd
dddddddddddddddddddddddddddddddddddddddddddddccccccddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddccccccccccddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
ddddddddddddddddddddddddddddddddddddddddddccccccccccccdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddccc777ccc77cccddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddcc7ccc7c7cc7ccddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd4cc7ccc7c7cc7cccdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd4cc7ccccc7cc7cccdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd4cc7ccccc7cc7cccdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
f77ffffffffffffffffffff2ddddfffffff555554cc7c777c7cc7cccdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
fffffffffffffffffffffff2dddd7ffffffff5554cc7ccc7c7cc7cccdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
7fffff55555555555ffffff2ddddf7ffffffff224cc7ccc7c7cc7cccdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
ffff55522222222221fffff2ddddf77fffffff22d4cc7777cc77cccddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
ff555222222ffffffffffff2ddddfffffffffff2d4cccccccccccccddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
ff552222ffffffffffffffffddddfffffffffff2dd4cccccccccccdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
ff222fffff77ffffffffffffddddfffffffffff2ddd44ccccccccddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
ff2222777777772fffffffffddddffffffffff22ddddd4444444dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
2222225555555522ffffffffddddffffffffffffdddddddddddddddddddddddddd11122222ffffffdddddddddddddddddddddddddddddddddddddddddddddddd
22222555557522222fffffffddddffffffff222fdddddddddddddddddddddd5000011122222fffffdddddddddddddddddddddddddddddddddddddddddddddddd
2222255575752fffffffffffddddfffff2555555dddddddddddddddddddddd5000001112222222ffdddddddddddddddddddddddddddddddddddddddddddddddd
222225555522ffffffffffffddddfffff2277777dddddddddddddddddddddd500000001122222222dddddddddddddddddddddddddddddddddddddddddddddddd
22222255522fffffffffffffddddffff22f2ffffdddddddddddddddddddddd500000000112222222dddddddddddddddddddddddddddddddddddddddddddddddd
22ffffffffffffffffffffffddddffffffff2222dddddddddddddddddddddd500000000011112222dddddddddddddddddddddddddddddddddddddddddddddddd
22ffffffffffffffffffffffddddfffffffffff2dddddddddddddddddddddd500000000000111111dddddddddddddddddddddddddddddddddddddddddddddddd
2fffffffffffffffffffffffddddfffffffffff2dddddddddddddddddddd00500000000000661111dddddddddddddddddddddddddddddddddddddddddddddddd
2ffffffffffff7ffffffffffddddffffffffff22dddddddddddddddd000000050000000000666666dddddddddddddddddddddddddddddddddddddddddddddddd
2fffffffff77777fffffffffdddd2ffffff77777dddddddddddd0000000000005500000000667777dddddddddddddddddddddddddddddddddddddddddddddddd
22ffffff77777777ffffffffdddd22ffff777777ddddddddd0000000000000000555000000677777dddddddddddddddddddddddddddddddddddddddddddddddd
22ffffff777777777fffffffdddd222ff7fff777ddddddd000000000000000000000500000677777dddddddddddddddddddddddddddddddddddddddddddddddd
22ffffff7777777777ffffffdddd222fffffffffddddd00000000000000000000000050000677777dddddddddddddddddddddddddddddddddddddddddddddddd
22ffffff77777777777fffffdddd2222ffffffffddddd00000000000000000000000000500666777dddddddddddddddddddddddddddddddddddddddddddddddd
12fffff777777777777fffffdddd2222ffffffffddddd00000000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddd
2ffffff777777777777fffffdddd12222fffffffddddd00000000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d00000d99999dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d00000d90009dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d00000d90009dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d00000d90009dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d00000d99999dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d11111daaaaadddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d1eee1da222adddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d1eee1da222adddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d1eee1da222adddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d11111daaaaadddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d22222dbbbbbdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d2eee2db333bdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d2eee2db333bdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d2eee2db333bdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d22222dbbbbbdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d33333dcccccdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d3eee3dcccccdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d3eee3dcccccdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d3eee3dcccccdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d33333dcccccdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d44444deeeeedddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d43334deeeeedddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d43334deeeeedddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d43334deeeeedddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d44444deeeeedddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d55555dfffffdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d50005dfffffdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d50005dfffffdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d50005dfffffdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d55555dfffffdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d66666dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d66666dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d66666dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d66666dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d66666dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d77777dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d77777dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d77777dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d77777dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d77777dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d88888dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d81118dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d81118dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d81118dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d88888dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
__map__
1001020304050607080900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011121314151617181900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2021222324252627282900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3031323334353637383900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f1000200305000000270502c0001d0501b05005000160500000000000110501105000000140500000000000030500000027050390001d0501b050050001605000000000000d0500d0500a0000f0500f05000000
0e1000200305000000270502c0001d0501b05005000160500000000000110501105000000140500000000000030500000027050390001d0501b05005000160500000000000110501105000000140000000000000
921000203a65002200046000b6703a6503a6000020003300107000c6000b6703a6003a6500000000000000003a65002200046000b6703a6503a600002000330000000000000b6703a6003a650376003d6303b600
001000200a3500c3501035016350073500a3500e350123500a3500d3500f35013350073500a3500f350123500c35010350153501c35011350153501a3502135015350183501c35022350173501a3501e35025350
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
491000100b25000000112500d20011250112401424000000122400f2000c200052300000000000082000e20007200000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000000100301006010090200c0400d05010050110501105011050100500d0500a05007050050500405004050040500405004050060500705008050090500905008050080500604005030040200101001010
0002000000000010100202005020090300c0400e0400f05010050100500f0500d0500c0500a050090500805007050060500605007050090500d0501005011050110500f0500d0500905006050040400303002010
00020000222102322025220272302a2402c2502d2502e2502f2502f2503025030250302502f2502e2502d2502d2502d2502d2502d2502e2503025031250322503225031250302503025031250322303422035210
00020000272102b2302d2303025033250352503725038250392503a2503825034250312502e2502d2502d2502d2502e2502f250312503425037250392503a2503a2503a2503825035250312502d2402a22028210
580200001055014550195501d5502155024550265502755027550245501f5501a5501755017550195501b5501e550215502355026550275502855027550255502455021550205501f5501c550185501655016550
50020000167101a730207302475026750297502a7502a75029750297502875027750267502575023750217501e7501a750197501a7501c7501e750227502475026750277502675024750227401f7201c71017700
a60200002440028420304403744039450324502944025430264402e450344503845038450324502643026400294502e4503445038450384503144025400264102b450364503a440344402a430264202541025400
080200001f110201202313025120281202b1102d1102e1102e1202e1202b12028120261202412023120231102411026110281102a1202c1302d1302b130281302612025120241202412024120241202412023120
010800001b1001d1002010022100261102a1402e1503315035140371403713036120347103271000000000001e1002210025120291502c1502e150301503015031150301502f1302d1302c1202b1102911028110
480200000f3001230014300173001b3001f3002230026330263502535023350213501e3501e3401d320193001830018310183201a3401c3401e3501f350213502235022350203501f3501d3401b3301832017310
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
480200002e720317303674038740397503875037750317402e7302b7202a7402d740307403375034750357503475032750307502d7502b750287402774027730287402b7502e7502f7402d730297202771026710
00050000353002e7502e7502d7501f30010300043002d7502c7502b7502e3001f300013002a75029750287502a700003002875027750267503f300323002a300277502675025750257001d7001f3001a70019700
080500002a7502d7502e7502e7502b7000f4002b7002b7502b750297502d7002c70027700287002675025750247502a7002a7002970024700217502275020750077002870028700287001f750207501f7501e700
9408000011760107600000000000000000000007700067000b7700a77007700077000000007700097500875000000000000000000000077500675005700057000000000000067500575004750000000000000000
000600001305015050140501305011050100500000000000000000000000000090500a0500b0500b05008050000000000000000000000000000000060000600009000090000a0000605007050080500605000000
00030000093500a3500a3500935000000063000735007350063500000000000063000635005350043500000000000003000435004350043500530001300013000435003350033500330000300000000000000000
9c0500000a3500a3500a350093500740000000083500a3500835008350000000d4000d40007350073500635005350054000640005350043500335003350034000340004350043500335002350044000000000000
010400000000034250322503125030200332503125030250302500000031250302502f250000002f2502e2502d250000002f2502d2502c250302002d2502c2502b250292002b2502a250292502d2002b2002b200
140a000017650136500e6500b6002a600256000f6500e6500d650000000000000000000000b6500b6500b6500a6500a6500965008650086500765007650076500765008650096500965009650000000000000000
58060000093500b3500c3500b35009450000000940004350073500435003450000000c3500d350093500245001400000000000000000034000235001450014500000000000024000240001350004500000000000
480500000615007150071500615006100091000910006100061000415005150051500415004100041000310005150051500415004100031000310004150031500315002100021000210002150021500115000000
080300003755036550365003350028500345503255032500305002f50031550305502d5002b5002f500305502e55000000000002e5002d5502c5500000000000000002c5002b50000000000002a5002950000000
00060000311502f1502e7502d100000002b15029150277502b1002b10028150271502675026100000002715025150241502315023150227502210022100221002210000000000000000000000000000000000000
0003000021250202501f2501d2301e1001f100201002625025250232502325000000000002925027250272500000000000302502f2502d2502c25000000000002d200292502a2402924028250252002220022200
00050000394503845036450144002240033400364503545032450344003340032400334003245031450304502e4002e400000002e4502d4502d450000002e4002d4502c4502b4500000000000000000000000000
000300001b4001b4001b4001c4501e4501c25019250162502c7002c70016450164501845019450172501625029700000000000016450194501a4501c450192501625015250297002870027700267000000000000
000400000d250212501025013200000000000000000000000b250222501125000000000000000000000000000000009250212500c250000000000000000000000000000000000000000000000000000000000000
000700001b0501a050190502c2001a150181501815018100192501825018250180001835017350163500000018450164501645000000175501555015550197001770017750167501575000000000000000000000
50050000164501745018450152501425000000000000000000000114501245013450112501025000000000000f45010450114500e2500c250000000000000000094500b4500c4500925007250000000000000000
580500000c0000d0001745016450144500e2500c25006200000000900017450164500e2500d2500b25000000000000000015450134500c2500b250092500000006400064500d2500925007250062500000000000
000300003655035550354000000000000345503355000000000000000033550325500000000000000003355032550000000000031550305502b50019500015000000000000000000000000000000000000000000
080300003b2503925038250000003f2003c2503b2503925000000000003a250382503725030200000000000033250322503125033200000003325032250302503220030200302000000000000000000000000000
1603000038450363503435000000364003540000000314502f3502f350364003540000000000000000000000314502f3502d350000000000039400394503a4503b4503935038340334002e4002f4502d3502c350
0003000024560235602356000000000000000022550215502550000000000001f5501e5501e50023500225001e5401d5401b50000000215001b5501a5501a5001950000000205001e5001d500000000000000000
090300001d2601f2701e250000001f2001d2001d2501b25000000000001e2001d2301a2301820000000000001a250192501a20000000182501725017250152501620015200142000000000000000000000000000
140300001f4502345024450203501e35000000000001d4501f4501a35019350163000000016450184501535014350164001845014350123501230016450194501535013350133501235012350143500000000000
08030000054500a4500d350093300d5000d50008500064300a350083300b500095000950003430053500435004330000000000006500014500335002340065000650006500004500135000330013000000000000
140300000b250102501325015250102500b4500645004200000000a2500925006450034000820008200092500825006250092000c2000a2000820007250062500625003250052000720007250042500325002250
000600003475036750330503105032500000000000000000327503375031050300502f0002e500305000000000000000000000033500347503575033050310503100032000000000000000000000000000000000
4808000034050330503100000000000000000000000330403204031000310000000000000000000000032040310402f0002f0000000000000000000000032040310402f000000000000000000000003103030030
480800001f7701e7701d7000000000000047001d7501c7501d700000000000000000000001b7501a7501b70000000000000000000000000001a750197501c700000000000000000000001a760197601b70000000
480500001f4001445015450142501325012250152001a4001a400134501445013250122501125018200000001240012450134501325012250112501b400184001a400114501245011250102500f2501220000000
10050000174501a4501d45016250142501225010400124001245014450164501325011250102500000012400144501645019450142501225011250000000c4000f4000c45011450154500f2500b2500a25000000
100500002d0503005034050387503875038750000002e7002e7502d7502b700000002d7002c7502a7502970029700000002b75029750287502470000000277502675025750257502570000000000000000000000
0808000034050330503000030000000003000031050300502e000000002f000300502e0502d0500000000000000002c0002f0502e0502d0502d000000000000000000000002d0402c0402b050280000000000000
1008000039050380503873038720397103a70033020350503505033000000000000035000310503305033050000000000000000000003105032050320502f0002e0002e0003800039000300002f0502e05000000
080900001e0501f7502370021700000001d0501c0501b750197001b7000000000000000001b7501a7501970000000000001a7001a750197501875000000000000000018750177501670000000000000000000000
100800001c0501b0501b7501c750197001e7000000000000000001c7501b0501a050000000000000000000001a000190001b75019050000001900019750180500000000000187501705000000000000000000000
9c08000013750190501a05018030167100000000000000000f7500e7500d7500f7000000000000000000c7500b7500000000000000000b7500a75000000000000000009750087500000000000000000000000000
a4090000185301a7601a760187601674000000000001775016740147300000000000000001703017760167501475013700000000000013740127301370012700137301172012700127201172000000107100f710
__music__
00 01020304
01 0142034a
02 41020349
03 0b424344
03 0c4e4f44
00 0d105152
03 14424344
00 18424344