pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- slider
-- by 0xcafed00d

-- #include intro.lua
cafed00d_intro = {
	zxpal = {
		{0, 0, 0},
		{0, 34, 199},
		{0, 43, 251},
		{214, 40, 22},
		{255, 51, 28},
		{212, 51, 199},
		{255, 64, 252},
		{0, 197, 37},
		{0, 249, 47},
		{0, 199, 201},
		{0, 251, 254},
		{204, 200, 42},
		{255, 252, 54},
		{202, 202, 202},
		{255, 255, 255}
	},

	gfx = [[00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777700000770000077770000777700000070000777777000777700077777700077770000777700000000000070000000000000000007000000000000007700
07000770007070000700007007000070000770000700000007000000000000700700007007000070007770000070000000077700000007000077700000070000
07007070000070000000007000007700007070000777770007777700000007000077770007000070000007000077770000700000007777000700070000077000
07070070000070000077770000000070070070000000007007000070000070000700007000777770007777000070007000700000070007000777700000070000
07700070000070000700000007000070077777700700007007000070000700000700007000000070070007000070007000700000070007000700000000070000
00777700007777700777777000777700000070000077770000777700000700000077770000777700007777000077770000077700007777000077770000070000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000700007777000077700007707000007770000077700000000000000000000000000000000000000000000000000000000000000000000000000000000000
00707000070007000000070007070700070007000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00070000070007000077770007070700077770000077700000000000000000000000000000000000000000000000000000000000000000000000000000000000
00707000007777000700070007070700070000000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000700000007000077770007070700007777000777700000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000i0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
]],

	hex = {0, 16, 0xc, 0xa, 0xf, 0xe, 0xd, 0, 0, 0xd},
	hexx = {-1, -1, 0, 0, 0, 0, 0, 0, 0, 0}, 
	stage = 0,

	pico8_colors = {red = 8, green = 11, white = 7, yellow = 10, blue = 12},
	tac08_colors = {red = 4, green = 8, white = 14, yellow = 11, blue = 1},
	colors = {}
}

function cafed00d_intro:init()
	cls()

	self.colors = self.pico8_colors

	if __tac08__ then
		for i = 1, #self.zxpal do
			local rgb = self.zxpal[i] 
			__tac08__.setpal(i-1, rgb[1], rgb[2], rgb[3])
		end
		self.colors = self.tac08_colors
	end

	memcpy(0x4300, 0, 128*16)

	local x = 0
	local y = 0
	for i = 0, #self.gfx do 
		local s = sub(self.gfx, i, i)
		if s == "0" or s == "7" then 
			sset(x, y, s + 0)
			x += 1
			if x == 128 then
				x = 0
				y += 1
			end
		end
	end
end

function cafed00d_intro:update()
	if self.stage == 0 then
		local allcorrect = true
		for i = 1, #self.hexx do
			if self.hexx[i] ~= -1 then
				self.hexx[i] = flr(rnd(16))
				if self.hexx[i] == self.hex[i] then
					self.hexx[i] = -1
				else
					allcorrect = false
				end
			end
		end
		if allcorrect then 
			self.stage += 1
			self.countdown = 45
		end
	elseif self.stage == 1 then 
		self.countdown -= 1
		if self.countdown == 0 then
			self.stage += 1
		end
	elseif self.stage == 2 then
		return true 
	end
	return false
end

function cafed00d_intro:draw()
	cls(0)
	local col = self.colors

	if self.stage == 2 then
		return true 
	end

	if self.stage == 0 then 
		for y = 0,96 do 
			local c = col.yellow
			if rnd(1) < 0.5 then 
				c = col.blue
			end
			line (0, y, 127, y, c)
		end
	end
	 
	rectfill (16, 16, 112, 80, col.white)

	palt(0, false)
	pal(0, col.white)
	pal(7, 0)

	if self.stage == 1 then 
		spr(17, 44, 50, 5, 1)
	end

	local x = 24
	for i = 1, #self.hex do
		if self.hexx[i] == -1 then
			pal(0, col.green)
			spr(self.hex[i], x, 40)
		else
			pal(0, col.red)
			spr(self.hexx[i], x, 40)
		end
		x += 8
	end 

	pal()
end

function cafed00d_intro:cleanup()
	memcpy(0, 0x4300, 128*16)
	palt()
	pal()
	camera()
	if __tac08__ then
		__tac08__.resetpal()
	end

end
-- #include slider.lua

function _init()
	cartdata("0xcafed00d_slider")
	poke(0x5f2d, 1)

	--apix = __tac08__
	if apix then
		apix.cursor(false)
		apix.screen(128, 192)
		musicid = apix.wavload("music1.wav")
		if stat(102) == "PLATFORM_MOBILE_ANDROID" then
			menuitem(3, "privacy policy", function() apix.open_url("https://0xcafed00d.github.io/docs/privacy_policy_free.html") end) 
			menuitem(4, "my other games", function() apix.open_url("https://play.google.com/store/search?q=pub%3A0xcafed00d&c=apps") end) 
		end
	end

	score:init()
	state_goto(intro_state)
end

function _update60()
	if apix then
		local x, y = stat(32), stat(33)
		if stat(34) ~= 0 and apix.p_in_r(x, y, 0, 0, 10, 10) then
			apix.showmenu()
			return 
		end
	end
	current_state:update()
	score:update()
end

function _draw() 
	cls(1)
	current_state:draw()
end

function state_goto(state)
	current_state = state
	current_state:init()	
end

-->8
-- intro state
intro_state = {
	intro = cafed00d_intro,
	frame = 0
}

function intro_state:init()
	camera(0, -16)
	if apix then
		camera(0, -48)
	end
	self.intro:init()
end

function intro_state:update()
	if self.frame == 0 then
		if self.intro:update() then
			self.intro:cleanup()
			music(true)
			soundfx(true)	
			state_goto(play_state) 
		end
		self.frame = 3
	end
	self.frame -= 1
end

function intro_state:draw()
	self.intro:draw()
end

-->8
-- play state
play_state = {
	playline = 32,
	stacktop = 40
}

function play_state:init()
	self.barwidth = 6
	self.stack = { self:newbar() }
	self.stack[1].cx = 64
	self.playbar = self:newbar()
	self.cur_update = self.update_play
	self.stacktop_offset = 0
	self.dropping = {}
	self.base_score = 10
	self.clicker = mclick:new()
	
	score:init()
end

function play_state:newbar()
	local col = (flr(rnd(6)) + 1) + 9

	local ani = {}
	for i = 1, self.barwidth do 
		local a = {frame=flr(rnd(10)) + 1, count=flr(rnd(180))+180}
		add(ani, a)
	end

	return {col=col, w=self.barwidth, cx=0, cy=-8, dy = 0, bounce = 4, slidepos = rnd(1), ani = ani}
end

function play_state:update()
	self.clicker:update()
	self:cur_update()
	self:update_dropping()
end

function play_state:update_play()
	local pb = self.playbar

	if pb.bounce > 0 then
		pb.cy += pb.dy
		pb.dy += 0.3
		if pb.cy > self.playline then
			pb.dy = -pb.dy * 0.5
			pb.bounce -= 1
			playsfx(0)
		end
	else 
		pb.cy = self.playline
		if btnp(4) or btnp(5) or self.clicker:clicked() then
			self.cur_update = self.update_next		
		end	
	end

	pb.cx = 64+sin(pb.slidepos) * 64
	pb.slidepos += 0.005	

	update_bar_animation(pb.ani)
end

function play_state:update_next()
	if self.playbar then
		self.playbar = self:checkbar(self.playbar) 
		
		if self.playbar.w <= 0 then
			state_goto(gameover_state)
			return
		end

		for i = 1, self.playbar.w do 
			self.playbar.ani[i].frame = 2
			self.playbar.ani[i].count = flr(rnd(180))+300
		end

		self.barwidth = self.playbar.w

		score:add(self.base_score * self.score_mult)
		score:inc_level()
		self.base_score += 1

		add(self.stack, {col = self.playbar.col, w = self.playbar.w, cx = self.playbar.cx, ani = self.playbar.ani})
		
		if #self.stack > 21 then 
			del(self.stack, self.stack[1])
		end
		
		self.playbar = nil
		self.stacktop_offset = -8 
	end

	self.stacktop_offset+=1
	if self.stacktop_offset == 0 then
		self.cur_update = self.update_play
		self.playbar = self:newbar()
	end
end

function play_state:update_dropping()
	for i=#self.dropping, 1, -1 do
		local d = self.dropping[i] 
		d.y += d.dy
		d.dy += 0.04
		if d.y > 200 then 
			del(self.dropping, d)
		end
	end	
end

function play_state:checkbarl(bar)
	if bar.w == 0 then 
		return false
	end	

	local st = self.stack[#self.stack]
	local stw = st.w * 8
	local stl = st.cx - stw/2 

	local bw = bar.w * 8
	local bl = bar.cx - bw/2

	if stl-bl > 4.5 then
		bar.w -= 1
		bar.cx += 4
		add(self.dropping, {col=bar.col, x=bl, y=self.playline, dy=0})
		return true
	end
	return false 
end

function play_state:checkbarr(bar)
	if bar.w == 0 then 
		return false
	end	
	
	local st = self.stack[#self.stack]
	local stw = st.w * 8
	local str = st.cx + stw/2 

	local bw = bar.w * 8
	local br = bar.cx + bw/2

	if br-str > 4.5 then
		bar.w -= 1
		bar.cx -= 4
		add(self.dropping, {col=bar.col, x=br-8, y=self.playline, dy=0})
		return true
	end
	return false 
end

function play_state:checkbar(bar)
	local top = self.stack[#self.stack]
	
	local dist = abs(flr(top.cx) - flr(bar.cx))
	if dist == 0 then 
		self.score_mult = 5
		self.message = {msg = "perfect x 5", count = 60}
		playsfx(4)
	elseif dist <= 2 then 
		self.score_mult = 2
		self.message = {msg = " good x 2", count = 60}
		playsfx(3)
	else 
		self.score_mult = 1	
		playsfx(2)
	end

	while self:checkbarl(bar) do
	end
	while self:checkbarr(bar) do
	end
	return bar
end

function play_state:draw()
	drawstack(self.stack, self.stacktop+self.stacktop_offset)
	if self.playbar then 
		drawbar(self.playbar.cx, self.playbar.cy, self.playbar.col, self.playbar.w, self.playbar.ani)
	end
	if self.message then 
		print(self.message.msg, 50, 18, 7)
		self.message.count -= 1
		if self.message.count == 0 then
			self.message = nil
		end
	end

	if apix then
		spr(15, 0, 0)
	end

	self:draw_dropping()
	score:draw()
end

function play_state:draw_dropping() 
	for d in all(self.dropping) do
		pal(8, d.col)
		spr (11, d.x, d.y)
		pal()
	end
end

-->8
-- gameover state
gameover_state = {
}

function gameover_state:init()
	self.count = 0
	score:sync()
	playsfx(1)
	self.clicker = mclick:new()
end

function gameover_state:update()
	self.clicker:update()

	play_state:update_dropping()
	if self.count > 60 then
		if btnp(4) or btnp(5) or self.clicker:clicked() then
			state_goto(play_state)
		end
	else 
		self.count += 1
	end
end

function gameover_state:draw()
	play_state:draw()
	for x = -1, 1 do
		for y = -1, 1 do
			print("game over", 48+x, 18+y, 8)	
		end
	end
	print("game over", 48, 18, 7)
	
	if self.count > 60 then 
		print("tap to play again", 28, 26, 7)
	end

end

-->8
-- drawing functions

function drawstack (stack, cy)
	-- the stack
	for i = #stack,1,-1 do
		drawbar(stack[i].cx, cy, stack[i].col, stack[i].w, stack[i].ani)
		update_bar_animation(stack[i].ani)
		cy = cy + 8
	end
	cy = cy - 4
	-- ground
	rectfill (0, cy, 128, 192, 11)
	
	-- logo
	palt(0, false)
	spr(16, 8, cy+2, 16, 5)
	palt()
	
	-- description
	print ("by 0Xcafed00d", 30, cy+46, 0)
	print ("stack blocks for hi-score!", 12, cy+56, 0)
	print (" how high can you go!!!", 12, cy+64, 0)
	print (" tap to place block", 12, cy+74, 0)

end

function drawbar (cx, cy, col, w, ani)
	cx = cx - w * 4
	cy = cy - 4
	pal(8, col)
	for i=0, w-1 do 
		spr (ani[i+1].frame, cx+i*8, cy)
	end
	pal()
end

function update_bar_animation (ani)
	for i= 1, #ani do
		ani[i].count -= 1
		if ani[i].count < 0 then 
			ani[i].frame=flr(rnd(10))+1
			ani[i].count=flr(rnd(180))+180
		end
	end
end

-->8
-- score

score = {}

function score:init()
	self.score_cur = 0
	self.score_disp = 0
	self.score_hi = dget (1)

	self.level = 1
	self.level_hi = dget (2)
	if self.level_hi == 0 then
		self.level_hi = 1
	end
	self.new_hi = false
	self.new_hi_lev = false
	self.count = 0
end

function score:update()
	if(self.score_disp < self.score_cur) self.score_disp+=1
	if(self.score_disp > self.score_hi) then 
		self.score_hi = self.score_disp
		self.new_hi = true
	end
	if(self.level > self.level_hi) then 
		self.level_hi = self.level
		self.new_hi_lev = true
	end
end

function score:sync()
	self.score_disp = self.score_cur
	self:update() 
	dset (1, self.score_hi)
	dset (2, self.level_hi)
end

function score:add (s)
	self.score_cur+=s
end

function score:inc_level()
	self.level += 1
end

function score:drawstr(x, y, scr, str, colour)
	local s = tostr(scr)
	str = sub(str,0,#str-#s)..s
	print(str, x+1, y+1, 0)
	print(str, x, y, colour)
end

function score:draw()

	local scorex = 4
	if apix then 
		scorex += 8
	end

	self:drawstr(scorex,1,self.score_disp,"score:000000", 7)
	
	local col = 7
	if self.new_hi and band(self.count, 0x8) == 0 then 
		col = 9
	end
	self:drawstr(scorex+12,8,self.score_hi,"hi:000000", col)


	self:drawstr(76,1,self.level,"level:000000", 7)
	col = 7
	if self.new_hi_lev and band(self.count, 0x8) == 0 then 
		col = 9
	end
	self:drawstr(88,8,self.level_hi,"hi:000000", col)
	
	self.count += 1
end

-->8
-- sound

function playsfx(id)
	if _sfxenabled then
		sfx(id)
	end
end

function music(enabled) 
	if apix then
		if enabled then 
			apix.wavplay(musicid, 3, true)
			menuitem(1, "music off", function() music(false) end) 
		else
			apix.wavstop(3)	
			menuitem(1, "music on", function() music(true) end) 
		end
	end
end

function soundfx(enabled) 
	if enabled then 
		_sfxenabled = true
		menuitem(2, "sound fx off", function() soundfx(false) end) 
	else
		_sfxenabled = false
		menuitem(2, "sound fx on", function() soundfx(true) end) 
	end
end

-->8
-- sound

function fromclass (c)
	local t = {}
	c.__index = c
	setmetatable(t, c)
	return t
end 

mclick = {}

function mclick:new ()
	local t = fromclass(mclick)
	t.lockout = false;
	t.isClicked = false;
	return t
end

function mclick:update ()
	if stat(34) ~= 0 then
		local y = stat(33)
		if y > 192 then 
			self.lockout = true
		end
		if not self.lockout then 
			self.isClicked = true
		end
	else
		self.lockout = false
		self.isClicked = false
	end
end

function mclick:clicked () 
	return self.isClicked
end

__gfx__
00000000077777700777777007777770077777700777777007777770077777700777777007777770077777700777777000000000000000000000000055555555
0000000078888886788888867188188678818816781881867888888678888886788888867888888678188186788888860000000000000000000000005aaaaa55
00700700781881867818818671881886788188167888888678188186788888867888888678881886717117167818818600000000000000000000000055111115
0007700078188186788888867888888678888886781111867888888678888886788888867888881678188186788888860000000000000000000000005aaaaa55
00077000788888867188881678188886788888867166661678811886718818867888181678188886788888867811118600000000000000000000000055111115
0070070078811886781111867888888678881186716777167816618678888886788888867881888678811886718888160000000000000000000000005aaaaa55
00000000788888867888888678888886788888867811118678811886781188867888811678881886788888867888888600000000000000000000000055111115
00000000066666600666666006666660066666600666666006666660066666600666666006666660066666600666666000000000000000000000000055555555
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb3333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb333303333bbbbbbbbbbbbbbbbbbbb33333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb33300000333bbbbbbbbbbbbbbbbbb3333003333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbb33333333333333bb330088800333bbbbbbbbbbbbbbbb333000000333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbb33333333000000003333b3308888800333bbbbbbbbbbbbbb33300888800333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbb333330000000000000003333008878880033bbbbbbbbbbbbb333008888880033bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbb3333000000888888888800333008877888033bbbbbbbbbbbbb330088877888033bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbb33300088888888888888880030088877788003bbbbbbbbbbbbb330888777788003bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbb333008888888877777777888000088777788003bbbbbbbbbbbbb300887777788003bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbb330088887777777777777788000088777788003bbbbbbbbbbbbb300887777788003bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbb33088877777777777777778800008877778800333333bbbbbbbb300887777788003bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbb300887777777777777777788000088777788000003333bbbbbbb300887777788003bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbb3008877777777788888888880000887777880000000333bbbbbb300887777788003bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbb30088777777888888888888000008877778800888800333bbbbb300887777788003bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbb30088777777778888880000000008877778808888880033bbbbb300887777788003bb33333333333bbbbbbbbbbb333333333333bbbbbbbbbbbbbbbbbbbb
bbbbb33088877777777778888880000088877788888877888033bbbbb30088777778800333333000003333bbbbbbb3333330000003333bbbbbbbbbbbbbbbbbbb
bbbbb33008887777777777788888800088777788088777788003bbbbb300887777788003330000000000333bbbb3333300000000000333bbbbbbbbbbbbbbbbbb
bbbbb33300888877777777777788880088777788088877788003bbbbb3008877777880000000888888800333b3333300008888888800333bbbbbbbbbbbbbbbbb
bbbbbb3330088888777777777777888088777788008877788003333333008877777880000888888888880033333300088888888888800333bbbbbbbbbbbbbbbb
bbbbbbb333000888887777777777788088777788008888888033333000008877777880008888877777888000000008888887777778880033bbbbbbbbbbbbbbbb
bbbbbbbb33330008888887777777788888777788000888880003000000088877777880088877777777788000000888887777777777888033bbbbbbbbbbbbbbbb
bbbbbbbbb3333300088888877777778888777788008880000000008888888877777880888777777777788808888888777777777777788003bbbbbbbbbbbbbbbb
bbbbbbbbbbb33330000088888777778888777788088888000008888888887777777888887777777777778888888877777777777777788003bbbbbbbbbbbbbbbb
bbbbbbb333333300000088888777778888777788888788800888888777777777777888877777788777788888777777777777888887888033bbbbbbbbbbbbbbbb
bbbbbb3333000000088888877777778888777888887778888888777777777777777888877777877777788888777777777888888888880033bbbbbbbbbbbbbbbb
bbbbb33300000088888887777777778887777880887777888877777777777777777888777777777777888887777777788888800088800333bbbbbbbbbbbbbbbb
bbbb33300888888888777777777778888777788088777788877777777777777777888877777777777888888777777888880000000000333bbbbbbbbbbbbbbbbb
bbbb3300888888877777777777777888877778808877778877777777778888888888887777777777888888877777888800003333303333bbbbbbbbbbbbbbbbbb
bbbb330888777777777777777778888887777880887777887777777788888888777788777777777777777887777888000333333333333bbbbbbbbbbbbbbbbbbb
bbbb300887777777777777777788880887777880887777887777777777777777777788877777777777777787777880003333bbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbb3008877777777777777888880008877778808877778877777777777777777777888777777777777778877778800333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbb30088777777777778888888000088777788088777788877777777777777777888888777777777777788777788003bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbb33088877777788888888000000088777788088877788888777777777777888888088888777777778888887888033bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbb33008888888888888000003333088888888008888888888888888888888888800008888888888888888888880033bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbb33300888888880000003333333008888880000888880008888888888888800000000008888888888000088800333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbb333000000000000333333bb3330000000000000000000000000000000000033333300000000000000000000333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbb33330000003333333bbbbbb33330000333333000333330000000000003333333333330000000033333303333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbb333333333333bbbbbbbbbbb333333333333333333333333333333333333bbbbbb333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
__label__
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111771177117717771777111117771777177717771777177711111111111111111111111117111777171717771711111117771777177717771777171111111
11117100710071707070700017117070707070707070107010701111111111111111111111117011700070707000701117117070707070707070707070111111
11117771701170707710771111017070707070707070117077701111111111111111111111117011771170707711701111017070707070707070707077711111
11111070701170707071700117117070707070707070117070001111111111111111111111117011700177707001701117117070707070707070707070701111
11117710177177107070777111017770777077707770117077711111111111111111111111117771777117007771777111017770777077707770777077701111
11111001110010011010100011111000100010001000111010001111111111111111111111111000100011011000100011111000100010001000100010001111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111117171777111117771777177717171777177711111111111111111111111111111111111117171777111117771777177717771771171111111
11111111111111117070170017117070707070707070107010701111111111111111111111111111111111117070170017117070707070707070170170111111
11111111111111117770170111017070707070707770177011701111111111111111111111111111111111117770170111017070707070707070170177711111
11111111111111117070170117117070707070701070117011701111111111111111111111111111111111117070170117117070707070707070170170701111
11111111111111117070777111017770777077701170777011701111111111111111111111111111111111117070777111017770777077707770777177701111
11111111111111111010100011111000100010001110100011101111111111111111111111111111111111111010100011111000100010001000100010001111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111777777117777771177777711777777111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111117eeeeee67ee1ee167eeeeee67e1ee1e611111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111117e1ee1e67ee1ee167e1ee1e67eeeeee611111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111117eeeeee67eeeeee67eeeeee67e1111e611111111111111111111111111111111111111111111111
111111111111111111111111111111111111111111111111171eeee167eeeeee671eeee167166661611111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111117e1111e67eee11e67e1111e67167771611111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111117eeeeee67eeeeee67eeeeee67e1111e611111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111666666116666661166666611666666111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111177777711777777117777771177777711111111111111111111111111111111111111111111111
111111111111111111111111111111111111111111111111117dddddd67dddddd67dddddd67dddddd61111111111111111111111111111111111111111111111
111111111111111111111111111111111111111111111111117d1dd1d67d1dd1d67d1dd1d67d1dd1d61111111111111111111111111111111111111111111111
111111111111111111111111111111111111111111111111117dddddd67dddddd67dddddd67dddddd61111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111171dddd1671dddd1671dddd1671dddd161111111111111111111111111111111111111111111111
111111111111111111111111111111111111111111111111117d1111d67d1111d67d1111d67d1111d61111111111111111111111111111111111111111111111
111111111111111111111111111111111111111111111111117dddddd67dddddd67dddddd67dddddd61111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111166666611666666116666661166666611111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111117777771177777711777777117777771111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111117aaaaaa67aaaaaa67aaaaaa67aaaaaa6111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111117a1aa1a67a1aa1a67a1aa1a67a1aa1a6111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111117aaaaaa67aaaaaa67aaaaaa67aaaaaa6111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111171aaaa1671aaaa1671aaaa1671aaaa16111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111117a1111a67a1111a67a1111a67a1111a6111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111117aaaaaa67aaaaaa67aaaaaa67aaaaaa6111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111116666661166666611666666116666661111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111777777117777771177777711777777117777771111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117cccccc67cccccc67cccccc67cccccc67cccccc6111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117c1cc1c67c1cc1c67c1cc1c67c1cc1c67c1cc1c6111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117cccccc67cccccc67cccccc67cccccc67cccccc6111111111111111111111111111111111111111111111111
111111111111111111111111111111111111111171cccc1671cccc1671cccc1671cccc1671cccc16111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117c1111c67c1111c67c1111c67c1111c67c1111c6111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117cccccc67cccccc67cccccc67cccccc67cccccc6111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111666666116666661166666611666666116666661111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777771177777711777777117777771177777711111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111117b1bb1b67bbbbbb671bb1bb67bbbbbb67bbbbbb61111111111111111111111111111111111111111111111111
111111111111111111111111111111111111111717117167b1bb1b671bb1bb67b1bb1b67b1bb1b61111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111117b1bb1b67bbbbbb67bbbbbb67b1bb1b67bbbbbb61111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111117bbbbbb67bb11bb67b1bbbb67bbbbbb671bbbb161111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111117bb11bb67b1661b67bbbbbb67bb11bb67b1111b61111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111117bbbbbb67bb11bb67bbbbbb67bbbbbb67bbbbbb61111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111116666661166666611666666116666661166666611111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111117777771177777711777777117777771177777711111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111117eeeeee67ee1ee167eeeeee671ee1ee67eeeeee61111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111117eee1ee67ee1ee167eee1ee671ee1ee67e1ee1e61111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111117eeeee167eeeeee67eeeee167eeeeee67eeeeee61111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111117e1eeee67eeeeee67e1eeee67e1eeee671eeee161111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111117ee1eee67eee11e67ee1eee67eeeeee67e1111e61111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111117eee1ee67eeeeee67eee1ee67eeeeee67eeeeee61111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111116666661166666611666666116666661166666611111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111777777117777771177777711777777117777771177777711111111111111111111111111111111111111111
11111111111111111111111111111111111111117dddddd671dd1dd67dddddd67dddddd67d1dd1d671dd1dd61111111111111111111111111111111111111111
11111111111111111111111111111111111111117dddddd671dd1dd67d1dd1d67ddd1dd67171171671dd1dd61111111111111111111111111111111111111111
11111111111111111111111111111111111111117dddddd67dddddd67dddddd67ddddd167d1dd1d67dddddd61111111111111111111111111111111111111111
11111111111111111111111111111111111111117ddd1d167d1dddd671dddd167d1dddd67dddddd67d1dddd61111111111111111111111111111111111111111
11111111111111111111111111111111111111117dddddd67dddddd67d1111d67dd1ddd67dd11dd67dddddd61111111111111111111111111111111111111111
11111111111111111111111111111111111111117dddd1167dddddd67dddddd67ddd1dd67dddddd67dddddd61111111111111111111111111111111111111111
11111111111111111111111111111111111111111666666116666661166666611666666116666661166666611111111111111111111111111111111111111111
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb3333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb333303333bbbbbbbbbbbbbbbbbbbb33333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb33300000333bbbbbbbbbbbbbbbbbb3333003333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbb33333333333333bb330088800333bbbbbbbbbbbbbbbb333000000333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbb33333333000000003333b3308888800333bbbbbbbbbbbbbb33300888800333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbb333330000000000000003333008878880033bbbbbbbbbbbbb333008888880033bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbb3333000000888888888800333008877888033bbbbbbbbbbbbb330088877888033bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbb33300088888888888888880030088877788003bbbbbbbbbbbbb330888777788003bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbb333008888888877777777888000088777788003bbbbbbbbbbbbb300887777788003bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbb330088887777777777777788000088777788003bbbbbbbbbbbbb300887777788003bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbb33088877777777777777778800008877778800333333bbbbbbbb300887777788003bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbb300887777777777777777788000088777788000003333bbbbbbb300887777788003bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbb3008877777777788888888880000887777880000000333bbbbbb300887777788003bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbb30088777777888888888888000008877778800888800333bbbbb300887777788003bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbb30088777777778888880000000008877778808888880033bbbbb300887777788003bb33333333333bbbbbbbbbbb333333333333bbbbbbbbbbbb
bbbbbbbbbbbbb33088877777777778888880000088877788888877888033bbbbb30088777778800333333000003333bbbbbbb3333330000003333bbbbbbbbbbb
bbbbbbbbbbbbb33008887777777777788888800088777788088777788003bbbbb300887777788003330000000000333bbbb3333300000000000333bbbbbbbbbb
bbbbbbbbbbbbb33300888877777777777788880088777788088877788003bbbbb3008877777880000000888888800333b3333300008888888800333bbbbbbbbb
bbbbbbbbbbbbbb3330088888777777777777888088777788008877788003333333008877777880000888888888880033333300088888888888800333bbbbbbbb
bbbbbbbbbbbbbbb333000888887777777777788088777788008888888033333000008877777880008888877777888000000008888887777778880033bbbbbbbb
bbbbbbbbbbbbbbbb33330008888887777777788888777788000888880003000000088877777880088877777777788000000888887777777777888033bbbbbbbb
bbbbbbbbbbbbbbbbb3333300088888877777778888777788008880000000008888888877777880888777777777788808888888777777777777788003bbbbbbbb
bbbbbbbbbbbbbbbbbbb33330000088888777778888777788088888000008888888887777777888887777777777778888888877777777777777788003bbbbbbbb
bbbbbbbbbbbbbbb333333300000088888777778888777788888788800888888777777777777888877777788777788888777777777777888887888033bbbbbbbb
bbbbbbbbbbbbbb3333000000088888877777778888777888887778888888777777777777777888877777877777788888777777777888888888880033bbbbbbbb
bbbbbbbbbbbbb33300000088888887777777778887777880887777888877777777777777777888777777777777888887777777788888800088800333bbbbbbbb
bbbbbbbbbbbb33300888888888777777777778888777788088777788877777777777777777888877777777777888888777777888880000000000333bbbbbbbbb
bbbbbbbbbbbb3300888888877777777777777888877778808877778877777777778888888888887777777777888888877777888800003333303333bbbbbbbbbb
bbbbbbbbbbbb330888777777777777777778888887777880887777887777777788888888777788777777777777777887777888000333333333333bbbbbbbbbbb
bbbbbbbbbbbb300887777777777777777788880887777880887777887777777777777777777788877777777777777787777880003333bbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbb3008877777777777777888880008877778808877778877777777777777777777888777777777777778877778800333bbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbb30088777777777778888888000088777788088777788877777777777777777888888777777777777788777788003bbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbb33088877777788888888000000088777788088877788888777777777777888888088888777777778888887888033bbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbb33008888888888888000003333088888888008888888888888888888888888800008888888888888888888880033bbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbb33300888888880000003333333008888880000888880008888888888888800000000008888888888000088800333bbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbb333000000000000333333bb3330000000000000000000000000000000000033333300000000000000000000333bbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbb33330000003333333bbbbbb33330000333333000333330000000000003333333333330000000033333303333bbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbb333333333333bbbbbbbbbbb333333333333333333333333333333333333bbbbbb333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb

__sfx__
00010000155561a5661e5762257624566245461e5260b516005060050600506005060050600506005060050600506005060050600506005060050600506005060050600506005060050600506005060050600506
01100000305532f5532c55328553235531f553135530b543055230050300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003
000500002d3502d3302d3100030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
000400001615016150271502715027140271302712027110271000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
000500002815028150321503215032140321303212032110271000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
