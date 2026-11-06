--[[
    ============================================================================
    GCHEATS v1.4 - ROBLOX ANTI-CHEAT STRESS TESTING TOOLKIT (CLAY MENU EDITION)
    Lokalizacja: StarterPlayer -> StarterPlayerScripts (LocalScript)
    Klawisz menu: RightShift

    v1.4:
      * Nowa zakladka "Visual": Rainbow Mode + wybor obiektow
        (Tesla / G-Klasa / Humvee / Vintage Pistol)
      * Nowa zakladka "Config": wczytywanie gotowych konfiguracji
        (Default, ConfigGTopka)
      * Suwaki i wybory odswiezaja sie po wczytaniu configu
    ============================================================================
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local function GetCamera()
	return Workspace.CurrentCamera
end

--------------------------------------------------------------------------------
-- USTAWIENIA (DOMYŚLNIE WYŁĄCZONE)
--------------------------------------------------------------------------------
local Settings = {
	ESP = {
		Enabled = false,
		Boxes = false,
		BoxStyle = "Corner",      -- "Corner" | "Full"
		Fill = false,
		Outline = true,
		Names = false,
		Distance = false,
		Health = false,
		HPGradient = true,
		Tracers = false,
		TracerOrigin = "Bottom",  -- "Bottom" | "Center" | "Top" | "Mouse"
		Skeleton = false,
		ShowNPC = true,
		IgnoreDummy = true,
		MaxDistance = 1000,
	},
	Aimbot = {
		Enabled = false,
		HoldKey = Enum.UserInputType.MouseButton2, -- PPM
		TargetPart = "Head",
		Smoothness = 20,
		FOV = 150,
		MaxDistance = 500,
		WallCheck = true,
		ShowFOV = false,
		IgnoreDummy = true,
		CenterLock = false,
		MaxSpeed = 600,
		HeadExpand = false,
		HeadSize = 2,
		HeadVisible = true,
	},
	Visual = {
		Rainbow = false,
		RainbowSpeed = 1,
		Tesla = false,
		GKlasa = false,
		Humvee = false,
		VintagePistol = false,
	},
}

-- migawka ustawien domyslnych (uzywana przez Config -> Default)
local DefaultSettings = {}
for cat, t in pairs(Settings) do
	local c = {}
	for k, v in pairs(t) do
		c[k] = v
	end
	DefaultSettings[cat] = c
end

local DUMMY_KEYWORD = "dummy"

local IsHoldingAimKey = false

--------------------------------------------------------------------------------
-- MOTYW (CLAY)
--------------------------------------------------------------------------------
local Theme = {
	Accent = Color3.fromRGB(147, 51, 234),
	Window = Color3.fromRGB(38, 35, 50),
	Card = Color3.fromRGB(48, 44, 64),
	Off = Color3.fromRGB(66, 62, 88),
	Edge = Color3.fromRGB(92, 86, 120),
	Text = Color3.fromRGB(242, 240, 252),
	SubText = Color3.fromRGB(150, 146, 178),
}

local Presets = {
	{ "Fiolet", Color3.fromRGB(147, 51, 234) },
	{ "Cyan", Color3.fromRGB(34, 211, 238) },
	{ "Róż", Color3.fromRGB(244, 114, 182) },
	{ "Zieleń", Color3.fromRGB(74, 222, 128) },
	{ "Pomarańcz", Color3.fromRGB(251, 146, 60) },
	{ "Czerwień", Color3.fromRGB(248, 113, 113) },
}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local AccentBinds = {}
local function BindAccent(fn)
	table.insert(AccentBinds, fn)
	fn()
end
local function SetAccent(color)
	Theme.Accent = color
	for _, fn in ipairs(AccentBinds) do
		fn()
	end
end

--------------------------------------------------------------------------------
-- NARZĘDZIA UI
--------------------------------------------------------------------------------
local function Tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function New(class, props)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

-- ustawia Visible tylko gdy wartość faktycznie się zmienia
local function Vis(inst, v)
	if inst.Visible ~= v then
		inst.Visible = v
	end
end

local function Corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = typeof(r) == "UDim" and r or UDim.new(0, r or 8)
	c.Parent = parent
	return c
end

local function Stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function Gradient(parent, c0, c1, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c0, c1)
	g.Rotation = rot or 90
	g.Parent = parent
	return g
end

local function Label(parent, text, size, color, font, boxSize, pos, align)
	return New("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		Font = font or Enum.Font.GothamMedium,
		Size = boxSize or UDim2.fromScale(1, 1),
		Position = pos or UDim2.new(),
		TextXAlignment = align or Enum.TextXAlignment.Left,
		Parent = parent,
	})
end

local Orders = {}
local function NextOrder(page)
	Orders[page] = (Orders[page] or 0) + 1
	return Orders[page]
end

-- Karta w stylu clay: miękki gradient + podświetlona krawędź + hover
local function ClayCard(parent, height, clickable, base)
	base = base or Theme.Card
	local card = Instance.new(clickable and "TextButton" or "Frame")
	card.Size = UDim2.new(1, -6, 0, height)
	card.BackgroundColor3 = base
	card.BorderSizePixel = 0
	card:SetAttribute("Base", base)
	if clickable then
		card.Text = ""
		card.AutoButtonColor = false
	end
	card.LayoutOrder = NextOrder(parent)
	card.Parent = parent
	Corner(card, 14)
	Gradient(card, WHITE, Color3.fromRGB(196, 190, 220), 90)
	local s = Stroke(card, Theme.Edge, 1.2, 0.3)
	Gradient(s, WHITE, Color3.fromRGB(70, 66, 92), 90)

	card.MouseEnter:Connect(function()
		Tween(card, 0.15, { BackgroundColor3 = card:GetAttribute("Base"):Lerp(WHITE, 0.08) })
	end)
	card.MouseLeave:Connect(function()
		Tween(card, 0.2, { BackgroundColor3 = card:GetAttribute("Base") })
	end)
	return card
end

--------------------------------------------------------------------------------
-- REJESTR HUMANOIDÓW (z cache części ciała)
--------------------------------------------------------------------------------
local Registry = {}
local TargetList = {}

local function IsDummyName(name)
	return string.find(string.lower(name), DUMMY_KEYWORD, 1, true) ~= nil
end

--------------------------------------------------------------------------------
-- FRIENDZ
--------------------------------------------------------------------------------
local FRIEND_COLOR = Color3.fromRGB(70, 255, 110)
local FriendSet = {}
local FriendVersion = 0

local function FriendKey(text)
	return string.lower((string.gsub(text, "^%s*(.-)%s*$", "%1")))
end

local function IsFriend(e)
	local pl = e.Player
	if not pl then
		return false
	end
	if e.FriendVer ~= FriendVersion or e.FriendPlayer ~= pl then
		e.FriendVer = FriendVersion
		e.FriendPlayer = pl
		e.IsFriend = FriendSet[string.lower(pl.Name)] == true or FriendSet[string.lower(pl.DisplayName)] == true
	end
	return e.IsFriend
end

local function ResolveFriendKey(text)
	local key = FriendKey(text)
	if key == "" then
		return nil
	end
	local match, count = nil, 0
	for _, pl in ipairs(Players:GetPlayers()) do
		local n, d = string.lower(pl.Name), string.lower(pl.DisplayName)
		if n == key or d == key then
			return n
		end
		if string.sub(n, 1, #key) == key or string.sub(d, 1, #key) == key then
			match, count = n, count + 1
		end
	end
	if count == 1 then
		return match
	end
	return key
end

local function AddFriend(text)
	local key = ResolveFriendKey(text)
	if not key then
		return false, "Wpisz nick gracza."
	end
	if FriendSet[key] then
		return false, key .. " jest już na liście."
	end
	FriendSet[key] = true
	FriendVersion += 1
	return true, "Dodano: " .. key
end

local function RemoveFriend(key)
	if FriendSet[key] then
		FriendSet[key] = nil
		FriendVersion += 1
	end
end

local function RegisterHumanoid(desc)
	if not desc:IsA("Humanoid") then
		return
	end
	local model = desc.Parent
	if not (model and model:IsA("Model")) or Registry[model] then
		return
	end
	local e = {
		Model = model,
		Humanoid = desc,
		Root = nil,
		Head = nil,
		Player = Players:GetPlayerFromCharacter(model),
		PlayerCheck = 0,
		IsDummy = IsDummyName(model.Name),
		Checked = 0,
		Valid = false,
	}
	e.NameConn = model:GetPropertyChangedSignal("Name"):Connect(function()
		e.IsDummy = IsDummyName(model.Name)
	end)
	Registry[model] = e
end

local function UnregisterHumanoid(desc)
	if desc:IsA("Humanoid") then
		local model = desc.Parent
		local e = model and Registry[model]
		if e and e.Humanoid == desc then
			e.NameConn:Disconnect()
			Registry[model] = nil
		end
	end
end

for _, desc in ipairs(Workspace:GetDescendants()) do
	RegisterHumanoid(desc)
end
Workspace.DescendantAdded:Connect(RegisterHumanoid)
Workspace.DescendantRemoving:Connect(UnregisterHumanoid)

local function GetRoot(e)
	local r = e.Root
	if r and r.Parent then
		return r
	end
	r = e.Model:FindFirstChild("HumanoidRootPart") or e.Model.PrimaryPart
	if r and not r:IsA("BasePart") then
		r = nil
	end
	e.Root = r
	return r
end

local function GetHead(e)
	local h = e.Head
	if h and h.Parent then
		return h
	end
	h = e.Model:FindFirstChild("Head")
	if h and not h:IsA("BasePart") then
		h = nil
	end
	e.Head = h
	return h
end

local function GetTorso(e)
	local t = e.Torso
	if t and t.Parent then
		return t
	end
	local m = e.Model
	t = m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso")
	if t and not t:IsA("BasePart") then
		t = nil
	end
	e.Torso = t
	return t
end

local function GetBodyParts(e)
	local list = e.BodyParts
	local now = os.clock()
	if list and now - (e.BodyBuilt or 0) < 1.5 then
		local ok = true
		for i = 1, #list do
			if not list[i].Parent then
				ok = false
				break
			end
		end
		if ok then
			return list
		end
	end
	list = {}
	for _, c in ipairs(e.Model:GetChildren()) do
		if c:IsA("BasePart") and c.Name ~= "HeadVisual" then
			list[#list + 1] = c
			if #list >= 24 then
				break
			end
		end
	end
	if #list == 0 then
		local h, r = GetHead(e), GetRoot(e)
		if h then list[#list + 1] = h end
		if r then list[#list + 1] = r end
	end
	e.BodyParts = list
	e.BodyBuilt = now
	return list
end

local function ValidateEntry(e)
	local model, hum = e.Model, e.Humanoid
	if not model:IsDescendantOf(Workspace) then
		return false
	end
	local cam = Workspace.CurrentCamera
	if cam and model:IsDescendantOf(cam) then
		return false
	end
	local mine = LocalPlayer.Character
	if mine and (model == mine or model:IsDescendantOf(mine)) then
		return false
	end
	if e.Player == LocalPlayer or model.Name == LocalPlayer.Name then
		return false
	end
	if hum:GetState() == Enum.HumanoidStateType.Dead or hum.Health <= 0 then
		return false
	end
	if not GetRoot(e) or not GetHead(e) then
		return false
	end
	return true
end

local function GetTargets(now)
	table.clear(TargetList)
	for model, e in pairs(Registry) do
		local hum = e.Humanoid
		if not model.Parent or hum.Parent ~= model then
			e.NameConn:Disconnect()
			Registry[model] = nil
		else
			if now - e.Checked > 0.5 then
				e.Checked = now
				e.Valid = ValidateEntry(e)
			end
			if e.Valid and hum.Health > 0 then
				if not e.Player and now - e.PlayerCheck > 1 then
					e.PlayerCheck = now
					e.Player = Players:GetPlayerFromCharacter(model)
				end
				TargetList[#TargetList + 1] = e
			end
		end
	end
	return TargetList
end

--------------------------------------------------------------------------------
-- GŁÓWNE GUI
--------------------------------------------------------------------------------
local W, H = 600, 430

local ESPGui = New("ScreenGui", {
	Name = "GCHEATS_ESP",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 1,
	Parent = PlayerGui,
})

local MenuGui = New("ScreenGui", {
	Name = "GCHEATS_GUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 10,
	Parent = PlayerGui,
})

local Root = New("Frame", {
	Name = "Root",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(W, H),
	BackgroundTransparency = 1,
	Parent = MenuGui,
})
local Scale = Instance.new("UIScale")
Scale.Parent = Root

local Shadows = {}
for _, info in ipairs({ { 34, 0.86, 8 }, { 16, 0.7, 6 } }) do
	local sh = New("Frame", {
		Size = UDim2.new(1, info[1], 1, info[1]),
		Position = UDim2.new(0, -info[1] / 2, 0, -info[1] / 2 + info[3]),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = info[2],
		BorderSizePixel = 0,
		Parent = Root,
	})
	Corner(sh, 32)
	table.insert(Shadows, { sh, info[2] })
end

local Main = New("CanvasGroup", {
	Name = "Main",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Theme.Window,
	BorderSizePixel = 0,
	Parent = Root,
})
Corner(Main, 24)
Gradient(Main, WHITE, Color3.fromRGB(168, 162, 196), 90)
local MainStroke = Stroke(Main, Theme.Edge, 1.5, 0.2)
Gradient(MainStroke, WHITE, Color3.fromRGB(60, 56, 80), 90)

local Header = New("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 62),
	BackgroundTransparency = 1,
	Parent = Main,
})

local Title = Label(Header, "GCHEATS", 26, WHITE, Enum.Font.GothamBlack, UDim2.fromOffset(150, 32), UDim2.fromOffset(22, 8))
local TitleGrad = Instance.new("UIGradient")
TitleGrad.Offset = Vector2.new(-1, 0)
TitleGrad.Parent = Title
BindAccent(function()
	TitleGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.Accent),
		ColorSequenceKeypoint.new(0.5, WHITE),
		ColorSequenceKeypoint.new(1, Theme.Accent),
	})
end)
TweenService:Create(TitleGrad, TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Offset = Vector2.new(1, 0) }):Play()

Label(Header, "By Gamerek", 11, Theme.SubText, Enum.Font.GothamMedium, UDim2.fromOffset(220, 16), UDim2.fromOffset(23, 38))

local Chip = New("Frame", {
	Size = UDim2.fromOffset(86, 22),
	Position = UDim2.fromOffset(150, 15),
	BackgroundColor3 = Theme.Off,
	BorderSizePixel = 0,
	Parent = Header,
})
Corner(Chip, 11)
local ChipText = Label(Chip, "1.4", 11, Theme.Accent, Enum.Font.GothamBold, UDim2.fromScale(1, 1), UDim2.new(), Enum.TextXAlignment.Center)
BindAccent(function()
	ChipText.TextColor3 = Theme.Accent
end)

local CloseBtn = New("TextButton", {
	Size = UDim2.fromOffset(28, 28),
	Position = UDim2.new(1, -44, 0, 17),
	BackgroundColor3 = Color3.fromRGB(235, 90, 110),
	Text = "×",
	TextColor3 = WHITE,
	TextSize = 20,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = false,
	Parent = Header,
})
Corner(CloseBtn, UDim.new(1, 0))
Gradient(CloseBtn, WHITE, Color3.fromRGB(200, 190, 200), 90)
CloseBtn.MouseEnter:Connect(function()
	Tween(CloseBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(250, 120, 135), Size = UDim2.fromOffset(31, 31), Position = UDim2.new(1, -45.5, 0, 15.5) })
end)
CloseBtn.MouseLeave:Connect(function()
	Tween(CloseBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(235, 90, 110), Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -44, 0, 17) })
end)

local Sidebar = New("Frame", {
	Position = UDim2.fromOffset(16, 70),
	Size = UDim2.fromOffset(130, H - 70 - 50),
	BackgroundTransparency = 1,
	Parent = Main,
})
do
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = Sidebar
end

local Content = New("Frame", {
	Position = UDim2.fromOffset(160, 70),
	Size = UDim2.fromOffset(W - 160 - 14, H - 70 - 50),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	Parent = Main,
})

local Footer = New("Frame", {
	Position = UDim2.new(0, 0, 1, -40),
	Size = UDim2.new(1, 0, 0, 40),
	BackgroundTransparency = 1,
	Parent = Main,
})
New("Frame", {
	Size = UDim2.new(1, -40, 0, 1),
	Position = UDim2.fromOffset(20, 0),
	BackgroundColor3 = Theme.Edge,
	BackgroundTransparency = 0.6,
	BorderSizePixel = 0,
	Parent = Footer,
})
Label(Footer, "RightShift – ukryj / pokaż menu", 11, Theme.SubText, Enum.Font.GothamMedium, UDim2.fromOffset(240, 40), UDim2.fromOffset(22, 1))
local StatsLabel = Label(Footer, "Cele: 0", 11, Theme.SubText, Enum.Font.GothamBold, UDim2.fromOffset(160, 40), UDim2.new(1, -182, 0, 1), Enum.TextXAlignment.Right)

--------------------------------------------------------------------------------
-- KOMPONENTY
--------------------------------------------------------------------------------
local Refreshers = {}

local function CreatePage()
	local p = New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		Parent = Content,
	})
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = p
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 2)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = p
	BindAccent(function()
		p.ScrollBarImageColor3 = Theme.Accent
	end)
	return p
end

local function CreateSection(page, text)
	local f = New("Frame", {
		Size = UDim2.new(1, -6, 0, 22),
		BackgroundTransparency = 1,
		LayoutOrder = NextOrder(page),
		Parent = page,
	})
	local dot = New("Frame", {
		Size = UDim2.fromOffset(7, 7),
		Position = UDim2.new(0, 6, 0.5, -3),
		BorderSizePixel = 0,
		Parent = f,
	})
	Corner(dot, UDim.new(1, 0))
	BindAccent(function()
		dot.BackgroundColor3 = Theme.Accent
	end)
	Label(f, string.upper(text), 11, Theme.SubText, Enum.Font.GothamBold, UDim2.new(1, -24, 1, 0), UDim2.fromOffset(20, 0))
end

local function CreateToggle(page, text, category, key, onChange)
	local card = ClayCard(page, 42, true)
	Label(card, text, 13, Theme.Text, Enum.Font.GothamMedium, UDim2.new(1, -90, 1, 0), UDim2.fromOffset(16, 0))

	local pill = New("Frame", {
		Size = UDim2.fromOffset(46, 24),
		Position = UDim2.new(1, -62, 0.5, -12),
		BackgroundColor3 = Theme.Off,
		BorderSizePixel = 0,
		Parent = card,
	})
	Corner(pill, UDim.new(1, 0))
	Gradient(pill, WHITE, Color3.fromRGB(190, 184, 214), 90)

	local knob = New("Frame", {
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.new(0, 3, 0.5, -9),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Parent = pill,
	})
	Corner(knob, UDim.new(1, 0))
	Gradient(knob, WHITE, Color3.fromRGB(215, 210, 230), 90)

	local function apply(animated)
		local on = Settings[category][key]
		local t = animated and 0.2 or 0
		Tween(pill, t, { BackgroundColor3 = on and Theme.Accent or Theme.Off })
		Tween(knob, t, { Position = on and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9) }, Enum.EasingStyle.Back)
	end
	apply(false)
	BindAccent(function()
		apply(false)
	end)
	table.insert(Refreshers, function()
		apply(true)
	end)

	card.MouseButton1Click:Connect(function()
		Settings[category][key] = not Settings[category][key]
		apply(true)
		if onChange then
			onChange()
		end
	end)
end

local function CreateSlider(page, text, category, key, minV, maxV, step, suffix)
	suffix = suffix or ""
	local card = ClayCard(page, 58, false)
	Label(card, text, 13, Theme.Text, Enum.Font.GothamMedium, UDim2.new(1, -110, 0, 22), UDim2.fromOffset(16, 8))
	local valLbl = Label(card, "", 13, Theme.Accent, Enum.Font.GothamBold, UDim2.fromOffset(90, 22), UDim2.new(1, -106, 0, 8), Enum.TextXAlignment.Right)
	BindAccent(function()
		valLbl.TextColor3 = Theme.Accent
	end)

	local track = New("Frame", {
		Size = UDim2.new(1, -36, 0, 8),
		Position = UDim2.fromOffset(18, 40),
		BackgroundColor3 = Theme.Off,
		BorderSizePixel = 0,
		Parent = card,
	})
	Corner(track, UDim.new(1, 0))
	local fill = New("Frame", {
		Size = UDim2.fromScale(0, 1),
		BorderSizePixel = 0,
		Parent = track,
	})
	Corner(fill, UDim.new(1, 0))
	Gradient(fill, WHITE, Color3.fromRGB(190, 184, 214), 90)
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.fromScale(0, 0.5),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Parent = track,
	})
	Corner(knob, UDim.new(1, 0))
	local knobStroke = Stroke(knob, Theme.Accent, 2.5, 0)
	BindAccent(function()
		fill.BackgroundColor3 = Theme.Accent
		knobStroke.Color = Theme.Accent
	end)

	local function render()
		local v = Settings[category][key]
		local rel = (v - minV) / (maxV - minV)
		fill.Size = UDim2.fromScale(rel, 1)
		knob.Position = UDim2.fromScale(rel, 0.5)
		valLbl.Text = string.format("%g", v) .. suffix
	end
	render()
	table.insert(Refreshers, render) -- odswiezenie po wczytaniu configu

	local function setFromX(x)
		local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local val = math.floor((minV + (maxV - minV) * rel) / step + 0.5) * step
		Settings[category][key] = math.clamp(val, minV, maxV)
		render()
	end

	local hit = New("TextButton", {
		Size = UDim2.new(1, -24, 0, 28),
		Position = UDim2.fromOffset(12, 30),
		BackgroundTransparency = 1,
		Text = "",
		Parent = card,
	})

	local dragging = false
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			Tween(knob, 0.12, { Size = UDim2.fromOffset(21, 21) })
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			Tween(knob, 0.15, { Size = UDim2.fromOffset(16, 16) })
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
end

local function CreateChoice(page, text, category, key, options)
	local card = ClayCard(page, 42, true)
	Label(card, text, 13, Theme.Text, Enum.Font.GothamMedium, UDim2.new(1, -150, 1, 0), UDim2.fromOffset(16, 0))
	local chip = New("TextLabel", {
		Size = UDim2.fromOffset(112, 26),
		Position = UDim2.new(1, -126, 0.5, -13),
		BackgroundColor3 = Theme.Off,
		BorderSizePixel = 0,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		Text = "",
		Parent = card,
	})
	Corner(chip, 10)
	BindAccent(function()
		chip.TextColor3 = Theme.Accent
	end)

	local function apply()
		for _, o in ipairs(options) do
			if o[1] == Settings[category][key] then
				chip.Text = o[2]
				return
			end
		end
		chip.Text = tostring(Settings[category][key])
	end
	apply()
	table.insert(Refreshers, apply) -- odswiezenie po wczytaniu configu

	card.MouseButton1Click:Connect(function()
		local idx = 1
		for i, o in ipairs(options) do
			if o[1] == Settings[category][key] then
				idx = i
				break
			end
		end
		idx = idx % #options + 1
		Settings[category][key] = options[idx][1]
		apply()
		chip.Size = UDim2.fromOffset(104, 24)
		Tween(chip, 0.25, { Size = UDim2.fromOffset(112, 26) }, Enum.EasingStyle.Back)
	end)
end

local function CreateColorRow(page, text)
	local card = ClayCard(page, 72, false)
	Label(card, text, 13, Theme.Text, Enum.Font.GothamMedium, UDim2.new(1, -32, 0, 22), UDim2.fromOffset(16, 8))
	local row = New("Frame", {
		Position = UDim2.fromOffset(16, 34),
		Size = UDim2.new(1, -32, 0, 30),
		BackgroundTransparency = 1,
		Parent = card,
	})
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 12)
	l.Parent = row

	local swatches = {}
	for _, p in ipairs(Presets) do
		local b = New("TextButton", {
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = p[2],
			Text = "",
			AutoButtonColor = false,
			Parent = row,
		})
		Corner(b, UDim.new(1, 0))
		Gradient(b, WHITE, Color3.fromRGB(180, 175, 200), 90)
		local st = Stroke(b, WHITE, 2.5, 1)
		table.insert(swatches, { b, st, p[2] })
		b.MouseButton1Click:Connect(function()
			SetAccent(p[2])
		end)
		b.MouseEnter:Connect(function()
			Tween(b, 0.12, { Size = UDim2.fromOffset(32, 32) })
		end)
		b.MouseLeave:Connect(function()
			Tween(b, 0.12, { Size = UDim2.fromOffset(28, 28) })
		end)
	end
	BindAccent(function()
		for _, s in ipairs(swatches) do
			Tween(s[2], 0.2, { Transparency = (s[3] == Theme.Accent) and 0 or 1 })
		end
	end)
end

local function CreateInfo(page, text, height)
	local card = ClayCard(page, height, false)
	local l = Label(card, text, 12, Theme.SubText, Enum.Font.GothamMedium, UDim2.new(1, -32, 1, -16), UDim2.fromOffset(16, 8))
	l.TextWrapped = true
	l.TextYAlignment = Enum.TextYAlignment.Top
end

local function CreateButton(page, text, getColor, callback)
	local card = ClayCard(page, 42, true)
	local lbl = Label(card, text, 13, WHITE, Enum.Font.GothamBold, UDim2.fromScale(1, 1), UDim2.new(), Enum.TextXAlignment.Center)
	BindAccent(function()
		local c = getColor()
		card:SetAttribute("Base", c)
		card.BackgroundColor3 = c
	end)
	card.MouseButton1Click:Connect(function()
		lbl.TextSize = 11
		Tween(lbl, 0.25, { TextSize = 13 }, Enum.EasingStyle.Back)
		callback()
	end)
end

--------------------------------------------------------------------------------
-- ZAKŁADKI
--------------------------------------------------------------------------------
local Tabs = {}
local CurrentTab = nil

local function CreateTab(name, order)
	local btn = New("TextButton", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order,
		Parent = Sidebar,
	})
	Corner(btn, 14)
	Gradient(btn, WHITE, Color3.fromRGB(190, 180, 220), 90)
	local lbl = Label(btn, name, 13, Theme.SubText, Enum.Font.GothamBold, UDim2.new(1, -20, 1, 0), UDim2.fromOffset(18, 0))
	BindAccent(function()
		btn.BackgroundColor3 = Theme.Accent
	end)
	local page = CreatePage()
	Tabs[name] = { Button = btn, Label = lbl, Page = page }

	btn.MouseEnter:Connect(function()
		if CurrentTab ~= name then
			Tween(btn, 0.15, { BackgroundTransparency = 0.85 })
		end
	end)
	btn.MouseLeave:Connect(function()
		if CurrentTab ~= name then
			Tween(btn, 0.15, { BackgroundTransparency = 1 })
		end
	end)
	btn.MouseButton1Click:Connect(function()
		if CurrentTab == name then
			return
		end
		CurrentTab = name
		for n, t in pairs(Tabs) do
			local active = n == name
			Tween(t.Button, 0.2, { BackgroundTransparency = active and 0 or 1 })
			Tween(t.Label, 0.2, { TextColor3 = active and WHITE or Theme.SubText })
			if active then
				t.Page.Position = UDim2.fromOffset(0, 18)
				t.Page.Visible = true
				Tween(t.Page, 0.28, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quart)
			else
				t.Page.Visible = false
			end
		end
	end)
	return page
end

local PageESP = CreateTab("ESP", 1)
local PageAim = CreateTab("Aimbot", 2)
local PageVisual = CreateTab("Visual", 3)
local PageFriends = CreateTab("Friendz", 4)
local PageConfig = CreateTab("Config", 5)
local PageSet = CreateTab("Ustawienia", 6)

-- ESP
CreateSection(PageESP, "Główne")
CreateToggle(PageESP, "Włącz ESP", "ESP", "Enabled")
CreateToggle(PageESP, "Pokaż NPC / Humanoidy", "ESP", "ShowNPC")
CreateToggle(PageESP, "Ignoruj Dummy", "ESP", "IgnoreDummy")
CreateSlider(PageESP, "Maksymalny dystans", "ESP", "MaxDistance", 100, 3000, 50, " st")
CreateSection(PageESP, "Box")
CreateToggle(PageESP, "Box 2D", "ESP", "Boxes")
CreateChoice(PageESP, "Styl boxa", "ESP", "BoxStyle", { { "Corner", "Narożniki" }, { "Full", "Pełny" } })
CreateToggle(PageESP, "Wypełnienie boxa", "ESP", "Fill")
CreateToggle(PageESP, "Czarny obrys", "ESP", "Outline")
CreateSection(PageESP, "Informacje")
CreateToggle(PageESP, "Nickname / Nazwa", "ESP", "Names")
CreateToggle(PageESP, "Dystans", "ESP", "Distance")
CreateToggle(PageESP, "Pasek HP (po lewej)", "ESP", "Health")
CreateToggle(PageESP, "HP gradient (zielony → czerwony)", "ESP", "HPGradient")
CreateSection(PageESP, "Linie")
CreateToggle(PageESP, "Tracer", "ESP", "Tracers")
CreateChoice(PageESP, "Początek tracera", "ESP", "TracerOrigin", { { "Bottom", "Dół" }, { "Center", "Środek" }, { "Top", "Góra" }, { "Mouse", "Kursor" } })
CreateToggle(PageESP, "Szkielet (R6 / R15)", "ESP", "Skeleton")

-- Aimbot
CreateSection(PageAim, "Główne")
CreateToggle(PageAim, "Włącz Aimbot (przytrzymaj PPM)", "Aimbot", "Enabled")
CreateToggle(PageAim, "Pokaż okrąg FOV", "Aimbot", "ShowFOV")
CreateToggle(PageAim, "WallCheck (widoczność)", "Aimbot", "WallCheck")
CreateToggle(PageAim, "Ignoruj Dummy", "Aimbot", "IgnoreDummy")
CreateToggle(PageAim, "Tryb środka (kursor na środek)", "Aimbot", "CenterLock")
CreateChoice(PageAim, "Cel", "Aimbot", "TargetPart", { { "Head", "Głowa" }, { "HumanoidRootPart", "Tułów" } })
CreateSection(PageAim, "Parametry")
CreateSlider(PageAim, "Płynność (wyższa = wolniej)", "Aimbot", "Smoothness", 5, 50, 1)
CreateSlider(PageAim, "Promień FOV", "Aimbot", "FOV", 30, 500, 5, " px")
CreateSlider(PageAim, "Maksymalny dystans", "Aimbot", "MaxDistance", 50, 2000, 10, " st")
CreateSlider(PageAim, "Maks. prędkość obrotu", "Aimbot", "MaxSpeed", 100, 1500, 25, " °/s")
CreateSection(PageAim, "Hitbox głowy")
CreateToggle(PageAim, "Powiększ głowę (+ hitbox)", "Aimbot", "HeadExpand")
CreateToggle(PageAim, "Widoczna duża głowa (fiolet)", "Aimbot", "HeadVisible")
CreateSlider(PageAim, "Rozmiar głowy", "Aimbot", "HeadSize", 1, 12, 0.25, "x")

-- Visual
local VisualHolder
local function UpdateVisualVis()
	if VisualHolder then
		VisualHolder.Visible = Settings.Visual.Rainbow == true
	end
end

CreateSection(PageVisual, "Rainbow")
CreateToggle(PageVisual, "Rainbow Mode", "Visual", "Rainbow", UpdateVisualVis)
CreateSlider(PageVisual, "Prędkość rainbow", "Visual", "RainbowSpeed", 0.1, 5, 0.1, "x")

VisualHolder = New("Frame", {
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = NextOrder(PageVisual),
	Parent = PageVisual,
})
do
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = VisualHolder
end
CreateSection(VisualHolder, "Obiekty (świecą na rainbow)")
CreateToggle(VisualHolder, "Tesla", "Visual", "Tesla")
CreateToggle(VisualHolder, "G-Klasa", "Visual", "GKlasa")
CreateToggle(VisualHolder, "Humvee", "Visual", "Humvee")
CreateToggle(VisualHolder, "Vintage Pistol", "Visual", "VintagePistol")
UpdateVisualVis()
table.insert(Refreshers, UpdateVisualVis)

CreateInfo(PageVisual, "Rainbow działa tylko lokalnie (po stronie klienta). Opcje obiektów pojawiają się po włączeniu Rainbow Mode.", 60)

-- Friendz
local RebuildFriendRows

CreateSection(PageFriends, "Dodaj znajomego")
do
	local card = ClayCard(PageFriends, 96, false)
	Label(card, "Nick gracza (Name lub DisplayName)", 13, Theme.Text, Enum.Font.GothamMedium, UDim2.new(1, -32, 0, 22), UDim2.fromOffset(16, 8))

	local box = New("TextBox", {
		Size = UDim2.new(1, -124, 0, 30),
		Position = UDim2.fromOffset(16, 34),
		BackgroundColor3 = Theme.Off,
		BorderSizePixel = 0,
		Text = "",
		PlaceholderText = "wpisz nick...",
		PlaceholderColor3 = Theme.SubText,
		TextColor3 = Theme.Text,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = card,
	})
	Corner(box, 10)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = box

	local addBtn = New("TextButton", {
		Size = UDim2.fromOffset(84, 30),
		Position = UDim2.new(1, -100, 0, 34),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Text = "Dodaj",
		TextColor3 = WHITE,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = false,
		Parent = card,
	})
	Corner(addBtn, 10)
	Gradient(addBtn, WHITE, Color3.fromRGB(190, 184, 214), 90)
	BindAccent(function()
		addBtn.BackgroundColor3 = Theme.Accent
	end)

	local status = Label(card, "", 11, Theme.SubText, Enum.Font.GothamMedium, UDim2.new(1, -32, 0, 20), UDim2.fromOffset(16, 68))

	local function submit()
		local ok, msg = AddFriend(box.Text)
		status.Text = msg
		status.TextColor3 = ok and FRIEND_COLOR or Color3.fromRGB(248, 113, 113)
		if ok then
			box.Text = ""
			RebuildFriendRows()
		end
	end
	addBtn.MouseButton1Click:Connect(submit)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)
end

CreateSection(PageFriends, "Lista znajomych")
local FriendHolder = New("Frame", {
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = NextOrder(PageFriends),
	Parent = PageFriends,
})
do
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = FriendHolder
end

RebuildFriendRows = function()
	for _, c in ipairs(FriendHolder:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	Orders[FriendHolder] = 0

	local keys = {}
	for k in pairs(FriendSet) do
		keys[#keys + 1] = k
	end
	table.sort(keys)

	if #keys == 0 then
		local card = ClayCard(FriendHolder, 38, false)
		Label(card, "Lista jest pusta", 12, Theme.SubText, Enum.Font.GothamMedium, UDim2.new(1, -32, 1, 0), UDim2.fromOffset(16, 0))
		return
	end

	for _, key in ipairs(keys) do
		local card = ClayCard(FriendHolder, 40, false)
		local dot = New("Frame", {
			Size = UDim2.fromOffset(9, 9),
			Position = UDim2.new(0, 16, 0.5, -4),
			BackgroundColor3 = FRIEND_COLOR,
			BorderSizePixel = 0,
			Parent = card,
		})
		Corner(dot, UDim.new(1, 0))
		Label(card, key, 13, Theme.Text, Enum.Font.GothamMedium, UDim2.new(1, -90, 1, 0), UDim2.fromOffset(34, 0))

		local rm = New("TextButton", {
			Size = UDim2.fromOffset(28, 28),
			Position = UDim2.new(1, -44, 0.5, -14),
			BackgroundColor3 = Color3.fromRGB(235, 90, 110),
			BorderSizePixel = 0,
			Text = "×",
			TextColor3 = WHITE,
			TextSize = 18,
			Font = Enum.Font.GothamBold,
			AutoButtonColor = false,
			Parent = card,
		})
		Corner(rm, UDim.new(1, 0))
		rm.MouseButton1Click:Connect(function()
			RemoveFriend(key)
			RebuildFriendRows()
		end)
	end
end
RebuildFriendRows()

-- Config
do
	-- Gotowe konfiguracje. Data = nadpisania na wartosciach domyslnych (Default).
	local Configs = {
		{
			Name = "Default",
			Desc = "Ustawienia domyślne, wszystko wyłączone",
			Data = {},
		},
		{
			Name = "ConfigGTopka",
			Desc = "Aimbot + głowa 5x, ESP wyłączone",
			Data = {
				ESP = { Enabled = false },
				Aimbot = {
					Enabled = true,
					ShowFOV = false,
					WallCheck = true,
					IgnoreDummy = true,
					CenterLock = false,
					Smoothness = 20,
					FOV = 150,
					MaxDistance = 500,
					MaxSpeed = 600,
					HeadExpand = true,
					HeadVisible = false,
					HeadSize = 5,
				},
			},
		},
	}

	local CurrentConfig = "Default"
	local Marks = {}

	local function RefreshMarks()
		for name, chip in pairs(Marks) do
			local on = name == CurrentConfig
			chip.Text = on and "AKTYWNY" or "WCZYTAJ"
			chip.TextColor3 = on and WHITE or Theme.SubText
			chip.BackgroundColor3 = on and Theme.Accent or Theme.Off
		end
	end

	local function ApplyConfig(name)
		local cfg
		for _, c in ipairs(Configs) do
			if c.Name == name then
				cfg = c
				break
			end
		end
		if not cfg then
			return
		end
		-- 1) reset do wartosci domyslnych
		for cat, t in pairs(DefaultSettings) do
			local dst = Settings[cat]
			for k, v in pairs(t) do
				dst[k] = v
			end
		end
		-- 2) nalozenie wartosci configu
		for cat, t in pairs(cfg.Data) do
			local dst = Settings[cat]
			if dst then
				for k, v in pairs(t) do
					dst[k] = v
				end
			end
		end
		CurrentConfig = name
		for _, r in ipairs(Refreshers) do
			r()
		end
		RefreshMarks()
	end

	CreateSection(PageConfig, "Konfiguracje")
	for _, c in ipairs(Configs) do
		local card = ClayCard(PageConfig, 56, true)
		Label(card, c.Name, 13, Theme.Text, Enum.Font.GothamBold, UDim2.new(1, -130, 0, 22), UDim2.fromOffset(16, 8))
		Label(card, c.Desc, 11, Theme.SubText, Enum.Font.GothamMedium, UDim2.new(1, -130, 0, 18), UDim2.fromOffset(16, 30))
		local chip = New("TextLabel", {
			Size = UDim2.fromOffset(88, 26),
			Position = UDim2.new(1, -104, 0.5, -13),
			BackgroundColor3 = Theme.Off,
			BorderSizePixel = 0,
			TextSize = 11,
			Font = Enum.Font.GothamBold,
			Text = "",
			Parent = card,
		})
		Corner(chip, 10)
		Marks[c.Name] = chip
		card.MouseButton1Click:Connect(function()
			ApplyConfig(c.Name)
		end)
	end
	BindAccent(RefreshMarks)

	CreateSection(PageConfig, "Informacje")
	CreateInfo(PageConfig, "Wczytanie configu resetuje opcje ESP, Aimbot i Visual do domyślnych, a potem ustawia wartości wybranej konfiguracji. Lista Friendz zostaje bez zmian.", 76)
end

-- Ustawienia
CreateSection(PageSet, "Wygląd")
CreateColorRow(PageSet, "Kolor motywu (menu + ESP)")
CreateSection(PageSet, "Szybkie akcje")
CreateButton(PageSet, "Włącz pełne ESP", function()
	return Theme.Accent:Lerp(BLACK, 0.3)
end, function()
	local e = Settings.ESP
	e.Enabled, e.Boxes, e.Names, e.Distance, e.Health, e.Tracers, e.Skeleton = true, true, true, true, true, true, true
	for _, r in ipairs(Refreshers) do
		r()
	end
end)
CreateButton(PageSet, "Wyłącz wszystko (Panic)", function()
	return Color3.fromRGB(150, 55, 75)
end, function()
	Settings.ESP.Enabled = false
	Settings.Aimbot.Enabled = false
	Settings.Aimbot.HeadExpand = false
	Settings.Visual.Rainbow = false
	for _, r in ipairs(Refreshers) do
		r()
	end
end)
CreateSection(PageSet, "Informacje")
CreateInfo(PageSet, "Menu: RightShift (ukryj / pokaż)\nAimbot: przytrzymaj prawy przycisk myszy\nOkno można przeciągać za nagłówek.\nGCHEATS v1.4 – Clay Menu", 84)

-- Start na zakładce ESP
do
	CurrentTab = "ESP"
	local t = Tabs["ESP"]
	t.Button.BackgroundTransparency = 0
	t.Label.TextColor3 = WHITE
	t.Page.Visible = true
end

--------------------------------------------------------------------------------
-- OTWIERANIE / ZAMYKANIE / PRZECIĄGANIE
--------------------------------------------------------------------------------
local MenuOpen = false
local function SetMenu(open)
	if open == MenuOpen then
		return
	end
	MenuOpen = open
	if open then
		Root.Visible = true
		Main.GroupTransparency = 1
		Scale.Scale = 0.86
		Tween(Main, 0.25, { GroupTransparency = 0 })
		Tween(Scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		for _, s in ipairs(Shadows) do
			s[1].BackgroundTransparency = 1
			Tween(s[1], 0.3, { BackgroundTransparency = s[2] })
		end
	else
		Tween(Main, 0.18, { GroupTransparency = 1 })
		for _, s in ipairs(Shadows) do
			Tween(s[1], 0.18, { BackgroundTransparency = 1 })
		end
		local tw = Tween(Scale, 0.18, { Scale = 0.92 })
		tw.Completed:Connect(function()
			if not MenuOpen then
				Root.Visible = false
			end
		end)
	end
end
SetMenu(true)

CloseBtn.MouseButton1Click:Connect(function()
	SetMenu(false)
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if not gp and input.KeyCode == Enum.KeyCode.RightShift then
		SetMenu(not MenuOpen)
	end
end)

local dragging, dragStart, startPos = false, Vector3.new(), UDim2.new()
Header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = Root.Position
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local d = input.Position - dragStart
		Root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

--------------------------------------------------------------------------------
-- AIMBOT (ruch jak myszką: delta yaw / pitch)
--------------------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gp)
	if not gp and input.UserInputType == Settings.Aimbot.HoldKey then
		IsHoldingAimKey = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Settings.Aimbot.HoldKey then
		IsHoldingAimKey = false
	end
end)

local FOVCircle = New("Frame", {
	Name = "FOVCircle",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = ESPGui,
})
Corner(FOVCircle, UDim.new(1, 0))
local FOVStroke = Stroke(FOVCircle, Theme.Accent, 1.5, 0.25)

local AimEntry, AimPart = nil, nil
local AimRayParams = RaycastParams.new()
AimRayParams.FilterType = Enum.RaycastFilterType.Exclude
AimRayParams.IgnoreWater = true
AimRayParams.RespectCanCollide = true

local MAX_PITCH = math.rad(80)
local DEADZONE_PX = 0.75

local function GetFocal(cam)
	local cf = cam.CFrame
	local v = cam:WorldToViewportPoint(cf.Position + cf.LookVector * 10 + cf.RightVector * 10)
	local f = v.X - cam.ViewportSize.X / 2
	if f > 1 then
		return f
	end
	return (cam.ViewportSize.Y / 2) / math.tan(math.rad(cam.FieldOfView) / 2)
end

local function IsVisible(cam, part)
	if not Settings.Aimbot.WallCheck then
		return true
	end
	local char = LocalPlayer.Character
	AimRayParams.FilterDescendantsInstances = char and { char, cam, part.Parent } or { cam, part.Parent }
	local origin = cam.CFrame.Position
	return Workspace:Raycast(origin, part.Position - origin, AimRayParams) == nil
end

local function GetAimPart(e)
	if Settings.Aimbot.TargetPart == "Head" then
		return GetHead(e) or GetTorso(e) or GetRoot(e)
	end
	return GetTorso(e) or GetRoot(e) or GetHead(e)
end

local VisLostAt = nil

local function StickyValid(cam, ref)
	local cfg = Settings.Aimbot
	local e, part = AimEntry, AimPart
	if not (e and part and part.Parent and e.Model.Parent) then
		return false
	end
	if e.Humanoid.Health <= 0 or (cfg.IgnoreDummy and e.IsDummy) or IsFriend(e) then
		return false
	end
	if part ~= GetAimPart(e) then
		return false
	end
	if (part.Position - cam.CFrame.Position).Magnitude > cfg.MaxDistance then
		return false
	end
	local sp, on = cam:WorldToViewportPoint(part.Position)
	if not on or (Vector2.new(sp.X, sp.Y) - ref).Magnitude > cfg.FOV * 1.25 then
		return false
	end
	if IsVisible(cam, part) then
		VisLostAt = nil
		return true
	end
	local now = os.clock()
	VisLostAt = VisLostAt or now
	return now - VisLostAt < 0.2
end

local function FindTarget(cam, targets, ref)
	local cfg = Settings.Aimbot
	local bestE, bestPart
	local shortest = cfg.FOV
	local camPos = cam.CFrame.Position
	local maxD2 = cfg.MaxDistance * cfg.MaxDistance

	for _, e in ipairs(targets) do
		if not (cfg.IgnoreDummy and e.IsDummy) and not IsFriend(e) then
			local part = GetAimPart(e)
			if part then
				local pos = part.Position
				local off = pos - camPos
				if off:Dot(off) <= maxD2 then
					local sp, on = cam:WorldToViewportPoint(pos)
					if on then
						local d = (Vector2.new(sp.X, sp.Y) - ref).Magnitude
						if d < shortest and IsVisible(cam, part) then
							shortest = d
							bestE, bestPart = e, part
						end
					end
				end
			end
		end
	end
	return bestE, bestPart
end

local function AimAt(cam, part, ref, dt)
	local cfg = Settings.Aimbot
	local vp = cam.ViewportSize
	local sp = cam:WorldToViewportPoint(part.Position)

	local dxPx = sp.X - ref.X
	local dyPx = sp.Y - ref.Y
	if math.abs(dxPx) < DEADZONE_PX and math.abs(dyPx) < DEADZONE_PX then
		return
	end

	local cx, cy = vp.X / 2, vp.Y / 2
	local focal = GetFocal(cam)

	local dYaw = math.atan((sp.X - cx) / focal) - math.atan((ref.X - cx) / focal)
	local dPitch = math.atan((sp.Y - cy) / focal) - math.atan((ref.Y - cy) / focal)

	local k = 120 / math.max(cfg.Smoothness, 1)
	local alpha = math.clamp(1 - math.exp(-k * dt), 0.01, 1)

	local sYaw, sPitch = dYaw * alpha, dPitch * alpha
	local maxStep = math.rad(cfg.MaxSpeed) * dt
	local mag = math.sqrt(sYaw * sYaw + sPitch * sPitch)
	if mag > maxStep and mag > 0 then
		local k2 = maxStep / mag
		sYaw, sPitch = sYaw * k2, sPitch * k2
	end

	local rx, ry = cam.CFrame:ToOrientation()
	rx = math.clamp(rx - sPitch, -MAX_PITCH, MAX_PITCH)
	ry = ry - sYaw

	cam.CFrame = CFrame.new(cam.CFrame.Position) * CFrame.fromOrientation(rx, ry, 0)
end

--------------------------------------------------------------------------------
-- POWIEKSZANIE GLOWY (hitbox) – tylko po stronie klienta
--------------------------------------------------------------------------------
local HEAD_COLOR = Color3.fromRGB(147, 51, 234)
local HEAD_TRANSPARENCY = 0.4

local function RemoveHeadClone(e)
	local c = e.HeadClone
	e.HeadClone = nil
	if c then
		c:Destroy()
	end
end

local function MakeHeadClone(e, head)
	if e.CloneFailed then
		return false
	end
	local c = head:Clone()
	if not c then
		e.CloneFailed = true
		return false
	end
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Attachment") or d:IsA("Constraint")
			or d:IsA("JointInstance") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	c.Name = "HeadVisual"
	c.Size = e.OrigSize
	c.Color = e.OrigColor
	c.Transparency = e.OrigTransp
	c.Anchored = false
	c.CanCollide = false
	c.CanTouch = false
	c.CanQuery = false
	c.Massless = true
	c.CFrame = head.CFrame
	c.Parent = e.Model
	local w = Instance.new("WeldConstraint")
	w.Part0 = head
	w.Part1 = c
	w.Parent = c
	e.HeadClone = c
	return true
end

local function RestoreHead(e)
	RemoveHeadClone(e)
	e.CloneFailed = nil
	local h = e.HeadPart
	e.HeadPart = nil
	if h and h.Parent then
		h.Size = e.OrigSize
		h.Color = e.OrigColor
		h.Transparency = e.OrigTransp
		h.CanCollide = e.OrigCollide
		h.Massless = e.OrigMassless
	end
end

local function ApplyHead(e, scale)
	local head = GetHead(e)
	if not head then
		return
	end
	if e.HeadPart ~= head then
		if e.HeadPart then
			RestoreHead(e)
		end
		e.HeadPart = head
		e.OrigSize = head.Size
		e.OrigColor = head.Color
		e.OrigTransp = head.Transparency
		e.OrigCollide = head.CanCollide
		e.OrigMassless = head.Massless
	end

	local want = e.OrigSize * scale
	if head.Size ~= want then
		head.Size = want
	end
	if head.CanCollide then
		head.CanCollide = false
	end
	if not head.Massless then
		head.Massless = true
	end

	local hidden = false
	if Settings.Aimbot.HeadVisible then
		RemoveHeadClone(e)
	else
		if not (e.HeadClone and e.HeadClone.Parent) then
			MakeHeadClone(e, head)
		end
		hidden = e.HeadClone ~= nil and e.HeadClone.Parent ~= nil
	end

	if hidden then
		if head.Transparency ~= 1 then
			head.Transparency = 1
		end
	else
		if head.Color ~= HEAD_COLOR then
			head.Color = HEAD_COLOR
		end
		if HEAD_TRANSPARENCY and head.Transparency ~= HEAD_TRANSPARENCY then
			head.Transparency = HEAD_TRANSPARENCY
		end
	end
end

local function ProcessHeads(targets)
	local cfg = Settings.Aimbot
	local scale = math.max(cfg.HeadSize, 1)
	for _, e in ipairs(targets) do
		local want = cfg.HeadExpand and not IsFriend(e) and not (cfg.IgnoreDummy and e.IsDummy)
		if want then
			ApplyHead(e, scale)
		elseif e.HeadPart then
			RestoreHead(e)
		end
	end
end

local SavedBehavior = nil

local function ReleaseCenterLock()
	if SavedBehavior then
		UserInputService.MouseBehavior = SavedBehavior
		SavedBehavior = nil
	end
end

local function ProcessAimbot(dt, cam, targets)
	local cfg = Settings.Aimbot
	local vp = cam.ViewportSize
	local hk = cfg.HoldKey
	if IsHoldingAimKey
		and (hk == Enum.UserInputType.MouseButton1 or hk == Enum.UserInputType.MouseButton2 or hk == Enum.UserInputType.MouseButton3)
		and not UserInputService:IsMouseButtonPressed(hk) then
		IsHoldingAimKey = false
	end
	local active = cfg.Enabled and IsHoldingAimKey
	local centerMode = active and cfg.CenterLock

	if centerMode then
		if not SavedBehavior then
			SavedBehavior = UserInputService.MouseBehavior
		end
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
	else
		ReleaseCenterLock()
	end

	local ref = centerMode and Vector2.new(vp.X / 2, vp.Y / 2) or UserInputService:GetMouseLocation()

	local showFov = cfg.ShowFOV and cfg.Enabled
	Vis(FOVCircle, showFov)
	if showFov then
		FOVCircle.Size = UDim2.fromOffset(cfg.FOV * 2, cfg.FOV * 2)
		FOVCircle.Position = UDim2.fromOffset(ref.X, ref.Y)
	end

	local locked = false
	if active then
		if not StickyValid(cam, ref) then
			AimEntry, AimPart = FindTarget(cam, targets, ref)
			VisLostAt = nil
		end
		if AimPart then
			locked = true
			AimAt(cam, AimPart, ref, dt)
		end
	else
		AimEntry, AimPart = nil, nil
	end
	if showFov then
		FOVStroke.Color = locked and WHITE or Theme.Accent
	end
end

--------------------------------------------------------------------------------
-- VISUAL: RAINBOW (Tesla / G-Klasa / Humvee / Vintage Pistol) – tylko klient
--------------------------------------------------------------------------------
local ProcessVisual
do
	local NEON = Enum.Material.Neon
	local CATS = { "Tesla", "GKlasa", "Humvee", "VintagePistol" }

	local Orig = setmetatable({}, { __mode = "k" }) -- [part] = oryginalny stan
	local Roots = { Tesla = {}, GKlasa = {}, Humvee = {} } -- [instancja] = { Parts, Built }
	local Painted = { Tesla = {}, GKlasa = {}, Humvee = {}, VintagePistol = {} } -- [part] = stamp
	local Lists = { Tesla = {}, GKlasa = {}, Humvee = {}, VintagePistol = {} }
	local PistolCache = {}
	local Stamp = 0
	local lastPaint = 0
	local pistolBuilt = 0

	-- Rozpoznawanie po nazwie:
	--  Tesla   -> nazwy zaczynajace sie od "BODY_" (np. BODY_Black_Details_1)
	--  G-Klasa -> nazwy zawierajace "__"  (np. Body__Rubber, Door_FL__Glass_Smoke)
	--  Humvee  -> model o nazwie zawierajacej "humvee" lub "hummer"
	local function Classify(inst)
		local isPart = inst:IsA("BasePart")
		local isModel = inst:IsA("Model")
		if not (isPart or isModel) then
			return
		end
		local n = inst.Name
		if string.sub(n, 1, 5) == "BODY_" then
			Roots.Tesla[inst] = {}
		end
		if string.find(n, "__", 1, true) then
			Roots.GKlasa[inst] = {}
		end
		if isModel then
			local l = string.lower(n)
			if string.find(l, "humvee", 1, true) or string.find(l, "hummer", 1, true) then
				Roots.Humvee[inst] = {}
			end
		end
	end

	for _, d in ipairs(Workspace:GetDescendants()) do
		Classify(d)
	end
	Workspace.DescendantAdded:Connect(Classify)
	Workspace.DescendantRemoving:Connect(function(inst)
		Roots.Tesla[inst] = nil
		Roots.GKlasa[inst] = nil
		Roots.Humvee[inst] = nil
	end)

	local function Paint(p, color)
		local o = Orig[p]
		if not o then
			o = { Color = p.Color, Material = p.Material }
			if p:IsA("MeshPart") then
				o.Tex = p.TextureID
			end
			o.SA = p:FindFirstChildOfClass("SurfaceAppearance")
			local sm = p:FindFirstChildOfClass("SpecialMesh")
			if sm then
				o.SM = sm
				o.SMTex = sm.TextureId
			end
			Orig[p] = o
		end
		-- SurfaceAppearance nadpisuje Color, wiec na czas rainbow jest zdejmowane
		if o.SA and o.SA.Parent == p then
			o.SA.Parent = nil
		end
		-- Texture ID usuwany (inaczej tekstura przykrywa kolor)
		if o.Tex ~= nil and p.TextureID ~= "" then
			pcall(function()
				p.TextureID = ""
			end)
		end
		if o.SM and o.SM.TextureId ~= "" then
			o.SM.TextureId = ""
		end
		if p.Material ~= NEON then
			p.Material = NEON
		end
		p.Color = color
	end

	local function Restore(p)
		local o = Orig[p]
		if not o then
			return
		end
		Orig[p] = nil
		if p.Parent then
			p.Color = o.Color
			p.Material = o.Material
			if o.Tex ~= nil then
				pcall(function()
					p.TextureID = o.Tex
				end)
			end
			if o.SA and not o.SA.Parent then
				o.SA.Parent = p
			end
			if o.SM and o.SM.Parent then
				o.SM.TextureId = o.SMTex
			end
		end
	end

	local function Collect(cat, now, out)
		local roots = Roots[cat]
		for root, info in pairs(roots) do
			if not root.Parent then
				roots[root] = nil
			elseif root:IsA("BasePart") then
				out[#out + 1] = root
			else
				local parts = info.Parts
				if not parts or now - (info.Built or 0) > 2 then
					parts = {}
					for _, d in ipairs(root:GetDescendants()) do
						if d:IsA("BasePart") then
							parts[#parts + 1] = d
						end
					end
					info.Parts = parts
					info.Built = now
				end
				for i = 1, #parts do
					local p = parts[i]
					if p.Parent then
						out[#out + 1] = p
					end
				end
			end
		end
	end

	-- Workspace -> [gracz] -> PistoletTP -> Vintage -> Default
	local function CollectPistol(now, out)
		if now - pistolBuilt > 0.4 then
			pistolBuilt = now
			table.clear(PistolCache)
			local char = LocalPlayer.Character or Workspace:FindFirstChild(LocalPlayer.Name)
			local tp = (char and char:FindFirstChild("PistoletTP")) or Workspace:FindFirstChild("PistoletTP")
			local vin = tp and tp:FindFirstChild("Vintage")
			local def = vin and vin:FindFirstChild("Default")
			if def then
				if def:IsA("BasePart") then
					PistolCache[1] = def
				elseif def:IsA("DataModelMesh") then
					if def.Parent and def.Parent:IsA("BasePart") then
						PistolCache[1] = def.Parent
					end
				else
					for _, d in ipairs(def:GetDescendants()) do
						if d:IsA("BasePart") then
							PistolCache[#PistolCache + 1] = d
						end
					end
				end
			end
		end
		for i = 1, #PistolCache do
			local p = PistolCache[i]
			if p.Parent then
				out[#out + 1] = p
			end
		end
	end

	ProcessVisual = function(dt)
		local v = Settings.Visual
		local now = os.clock()
		local paintNow = v.Rainbow and now - lastPaint >= 1 / 30
		if paintNow then
			lastPaint = now
		end
		local color = Color3.fromHSV((now * 0.25 * v.RainbowSpeed) % 1, 1, 1)

		for _, cat in ipairs(CATS) do
			local painted = Painted[cat]
			if v.Rainbow and v[cat] then
				if paintNow then
					Stamp += 1
					local list = Lists[cat]
					table.clear(list)
					if cat == "VintagePistol" then
						CollectPistol(now, list)
					else
						Collect(cat, now, list)
					end
					for i = 1, #list do
						local p = list[i]
						painted[p] = Stamp
						Paint(p, color)
					end
					-- czesci, ktore wypadly z listy (usuniete / zmiana broni) -> przywroc
					for p, s in pairs(painted) do
						if s ~= Stamp then
							Restore(p)
							painted[p] = nil
						end
					end
				end
			elseif next(painted) ~= nil then
				for p in pairs(painted) do
					Restore(p)
					painted[p] = nil
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- ESP (RYSOWANIE 2D PRZEZ GUI) + POOLING
--------------------------------------------------------------------------------
local R15Bones = {
	{ "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
	{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
	{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
	{ "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}
local R6Bones = {
	{ "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
	{ "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}
local MAX_BONES = 14
local POOL_LIMIT = 40

local ESPObjects = {}
local ESPPool = {}
local ESPSeen = {}

local function MakeLine(parent)
	return New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderSizePixel = 0,
		Visible = false,
		Parent = parent,
	})
end

local function SetLine(l, a, b, color, thickness)
	local d = b - a
	l.Size = UDim2.fromOffset(d.Magnitude, thickness)
	l.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	l.Rotation = math.deg(math.atan2(d.Y, d.X))
	l.BackgroundColor3 = color
	Vis(l, true)
end

local function SetRect(f, x, y, w, h)
	f.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
	f.Size = UDim2.fromOffset(math.floor(w + 0.5), math.floor(h + 0.5))
end

local function CreateESPObject()
	local o = {}
	o.HP = nil
	o.BoneList = {}
	o.BoneModel = nil
	o.BoneBuilt = 0
	o.Holder = New("Frame", {
		Name = "ESP",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = ESPGui,
	})

	o.BoxOutline = New("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, Parent = o.Holder })
	Stroke(o.BoxOutline, BLACK, 4, 0.35)

	o.Box = New("Frame", { BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, Parent = o.Holder })
	o.BoxStroke = Stroke(o.Box, Theme.Accent, 1.6, 0)
	local fg = Instance.new("UIGradient")
	fg.Rotation = 90
	fg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.75) })
	fg.Parent = o.Box

	o.Corners = {}
	o.CornerStrokes = {}
	for i = 1, 8 do
		local c = New("Frame", { BorderSizePixel = 0, Visible = false, Parent = o.Holder })
		o.CornerStrokes[i] = Stroke(c, BLACK, 1, 0.2)
		o.Corners[i] = c
	end

	o.HPBg = New("Frame", { BackgroundColor3 = Color3.fromRGB(12, 12, 16), BackgroundTransparency = 0.25, BorderSizePixel = 0, Visible = false, Parent = o.Holder })
	Corner(o.HPBg, 3)
	o.HPFill = New("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 1, 1, -1), BorderSizePixel = 0, Parent = o.HPBg })
	Corner(o.HPFill, 2)
	o.HPText = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(30, 12),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		Parent = o.Holder,
	})

	o.Name = New("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(220, 14),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.25,
		Visible = false,
		Parent = o.Holder,
	})
	o.Dist = New("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(120, 12),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(215, 212, 235),
		TextStrokeTransparency = 0.3,
		Visible = false,
		Parent = o.Holder,
	})

	o.Tracer = MakeLine(o.Holder)
	o.Bones = {}
	return o
end

local function AcquireESP()
	local o = table.remove(ESPPool)
	if o then
		o.HP = nil
		o.BoneModel = nil
		return o
	end
	return CreateESPObject()
end

local function ReleaseESP(o)
	Vis(o.Holder, false)
	if #ESPPool >= POOL_LIMIT then
		o.Holder:Destroy()
	else
		ESPPool[#ESPPool + 1] = o
	end
end

local function BuildBones(o, e)
	local defs = e.Humanoid.RigType == Enum.HumanoidRigType.R15 and R15Bones or R6Bones
	local list = {}
	for _, pair in ipairs(defs) do
		local a = e.Model:FindFirstChild(pair[1])
		local b = e.Model:FindFirstChild(pair[2])
		if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
			list[#list + 1] = { a, b }
		end
	end
	o.BoneList = list
	o.BoneModel = e.Model
	o.BoneBuilt = os.clock()
	o.BoneExpected = #defs
end

local function UpdateOne(o, e, cam, viewport, dt, camPos, focal)
	local cfg = Settings.ESP
	local model, hum, holder = e.Model, e.Humanoid, o.Holder

	local head = GetHead(e)
	if not head then
		Vis(holder, false)
		return
	end
	local hp = head.Position
	if hp.X ~= hp.X or hp.Y ~= hp.Y or hp.Z ~= hp.Z then
		Vis(holder, false)
		return
	end
	local off = hp - camPos
	local dist = math.sqrt(off:Dot(off))

	local parts = GetBodyParts(e)
	local rootPart = GetRoot(e)
	local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
	local rootX, used = nil, 0
	for i = 1, #parts do
		local part = parts[i]
		local cf = part.CFrame
		local pos = cf.Position
		local d = pos - hp
		if d:Dot(d) <= 144 then
			local v = cam:WorldToViewportPoint(pos)
			if v.Z < 0.3 then
				Vis(holder, false)
				return
			end
			local sz = (part == e.HeadPart and e.OrigSize) or part.Size
			local horiz = math.max(sz.X, sz.Z) * 0.5
			local vert = sz.Y * 0.5
			local up = math.abs(cf.UpVector.Y)
			local rx = (horiz * up + vert * (1 - up)) * focal / v.Z
			local ry = (vert * up + horiz * (1 - up)) * focal / v.Z
			if v.X - rx < minX then minX = v.X - rx end
			if v.X + rx > maxX then maxX = v.X + rx end
			if v.Y - ry < minY then minY = v.Y - ry end
			if v.Y + ry > maxY then maxY = v.Y + ry end
			if part == rootPart then
				rootX = v.X
			end
			used += 1
		end
	end
	if used == 0 then
		Vis(holder, false)
		return
	end

	local y = minY - 2
	local h = (maxY - minY) + 4
	if h ~= h or h < 4 or h > viewport.Y * 4 then
		Vis(holder, false)
		return
	end
	local xr = maxX - minX
	local w = math.max(h * 0.5, xr)
	local cx = (rootX and xr <= h * 0.6) and rootX or (minX + maxX) / 2
	local x = cx - w / 2

	local friend = IsFriend(e)
	local color = friend and FRIEND_COLOR or Theme.Accent

	if not cfg.Tracers and (x > viewport.X or x + w < 0 or y > viewport.Y or y + h < 0) then
		Vis(holder, false)
		return
	end

	Vis(holder, true)

	local full = cfg.Boxes and cfg.BoxStyle == "Full"
	local corner = cfg.Boxes and cfg.BoxStyle == "Corner"
	local boxVisible = full or (cfg.Boxes and cfg.Fill)

	Vis(o.BoxOutline, full and cfg.Outline)
	Vis(o.Box, boxVisible)
	if boxVisible then
		SetRect(o.Box, x, y, w, h)
		SetRect(o.BoxOutline, x, y, w, h)
		o.Box.BackgroundColor3 = color
		o.Box.BackgroundTransparency = cfg.Fill and 0.8 or 1
		o.BoxStroke.Enabled = full
		o.BoxStroke.Color = color
	end

	if corner then
		local lx, ly, t = w * 0.28, h * 0.2, 2
		local x2, y2 = x + w, y + h
		SetRect(o.Corners[1], x, y, lx, t)
		SetRect(o.Corners[2], x, y, t, ly)
		SetRect(o.Corners[3], x2 - lx, y, lx, t)
		SetRect(o.Corners[4], x2 - t, y, t, ly)
		SetRect(o.Corners[5], x, y2 - t, lx, t)
		SetRect(o.Corners[6], x, y2 - ly, t, ly)
		SetRect(o.Corners[7], x2 - lx, y2 - t, lx, t)
		SetRect(o.Corners[8], x2 - t, y2 - ly, t, ly)
		for i = 1, 8 do
			local c = o.Corners[i]
			c.BackgroundColor3 = color
			o.CornerStrokes[i].Enabled = cfg.Outline
			Vis(c, true)
		end
	else
		for i = 1, 8 do
			Vis(o.Corners[i], false)
		end
	end

	if cfg.Health then
		local maxHp = math.max(hum.MaxHealth, 1)
		local target = math.clamp(hum.Health / maxHp, 0, 1)
		o.HP = o.HP or target
		o.HP = o.HP + (target - o.HP) * math.min(1, dt * 10)
		local ratio = o.HP

		SetRect(o.HPBg, x - 9, y - 1, 5, h + 2)
		Vis(o.HPBg, true)
		o.HPFill.Size = UDim2.new(1, -2, ratio, -2 * ratio)
		o.HPFill.BackgroundColor3 = cfg.HPGradient and Color3.fromHSV(ratio * 0.33, 0.85, 1) or color

		o.HPText.Text = tostring(math.floor(hum.Health + 0.5))
		local ty = math.clamp(y + h * (1 - ratio), y + 6, y + h - 6)
		o.HPText.Position = UDim2.fromOffset(math.floor(x - 12), math.floor(ty))
		Vis(o.HPText, true)
	else
		Vis(o.HPBg, false)
		Vis(o.HPText, false)
	end

	if cfg.Names then
		o.Name.Text = e.Player and e.Player.Name or model.Name
		o.Name.TextColor3 = friend and FRIEND_COLOR or WHITE
		o.Name.Position = UDim2.fromOffset(math.floor(cx), math.floor(y - 3))
		Vis(o.Name, true)
	else
		Vis(o.Name, false)
	end

	if cfg.Distance then
		o.Dist.Text = string.format("[%d m]", math.floor(dist + 0.5))
		o.Dist.Position = UDim2.fromOffset(math.floor(cx), math.floor(y + h + 2))
		Vis(o.Dist, true)
	else
		Vis(o.Dist, false)
	end

	if cfg.Tracers then
		local origin
		if cfg.TracerOrigin == "Center" then
			origin = Vector2.new(viewport.X / 2, viewport.Y / 2)
		elseif cfg.TracerOrigin == "Top" then
			origin = Vector2.new(viewport.X / 2, 0)
		elseif cfg.TracerOrigin == "Mouse" then
			origin = UserInputService:GetMouseLocation()
		else
			origin = Vector2.new(viewport.X / 2, viewport.Y)
		end
		SetLine(o.Tracer, origin, Vector2.new(cx, y + h), color, 1.5)
	else
		Vis(o.Tracer, false)
	end

	if cfg.Skeleton then
		if o.BoneModel ~= model or (#o.BoneList < (o.BoneExpected or 0) and os.clock() - o.BoneBuilt > 2) then
			BuildBones(o, e)
		end
		local list = o.BoneList
		for i = #o.Bones + 1, #list do
			o.Bones[i] = MakeLine(o.Holder)
		end
		for i = 1, #o.Bones do
			local line = o.Bones[i]
			local pair = list[i]
			local drawn = false
			if pair then
				local a, b = pair[1], pair[2]
				if a.Parent and b.Parent then
					local pa = cam:WorldToViewportPoint(a.Position)
					local pb = cam:WorldToViewportPoint(b.Position)
					if pa.Z > 0 and pb.Z > 0 then
						SetLine(line, Vector2.new(pa.X, pa.Y), Vector2.new(pb.X, pb.Y), color, 1.6)
						drawn = true
					end
				else
					o.BoneModel = nil
				end
			end
			if not drawn then
				Vis(line, false)
			end
		end
	else
		for i = 1, #o.Bones do
			Vis(o.Bones[i], false)
		end
	end
end

local ESPErrWarned = false

local function ProcessESP(dt, cam, targets)
	local cfg = Settings.ESP
	table.clear(ESPSeen)

	if cfg.Enabled then
		local viewport = cam.ViewportSize
		local camPos = cam.CFrame.Position
		local maxD2 = cfg.MaxDistance * cfg.MaxDistance
		local focal = GetFocal(cam)

		for _, e in ipairs(targets) do
			if (cfg.ShowNPC or e.Player) and not (cfg.IgnoreDummy and e.IsDummy) then
				local head = GetHead(e)
				if head then
					local off = head.Position - camPos
					if off:Dot(off) <= maxD2 then
						local model = e.Model
						ESPSeen[model] = true
						local obj = ESPObjects[model]
						if not obj then
							obj = AcquireESP()
							ESPObjects[model] = obj
						end
						local ok, err = pcall(UpdateOne, obj, e, cam, viewport, dt, camPos, focal)
						if not ok then
							Vis(obj.Holder, false)
							if not ESPErrWarned then
								ESPErrWarned = true
								warn("[GCHEATS] ESP: " .. tostring(err))
							end
						end
					end
				end
			end
		end
	end

	for model, obj in pairs(ESPObjects) do
		if not ESPSeen[model] then
			ReleaseESP(obj)
			ESPObjects[model] = nil
		end
	end
end

--------------------------------------------------------------------------------
-- GŁÓWNA PĘTLA
--------------------------------------------------------------------------------
local Warned = {}
local function Safe(tag, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and not Warned[tag] then
		Warned[tag] = true
		warn("[GCHEATS] " .. tag .. ": " .. tostring(err))
	end
	return ok
end

local lastStats = 0

-- Aimbot zaraz po kamerze Robloxa
RunService:BindToRenderStep("GCHEATS_Aim", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local cam = GetCamera()
	if not cam then
		return
	end
	local targets = GetTargets(os.clock())
	Safe("Heads", ProcessHeads, targets)
	Safe("Aimbot", ProcessAimbot, dt, cam, targets)
	Safe("Visual", ProcessVisual, dt)
end)

-- ESP na samym koncu klatki
RunService:BindToRenderStep("GCHEATS_ESP", Enum.RenderPriority.Last.Value, function(dt)
	local cam = GetCamera()
	if not cam then
		return
	end
	Safe("ESP", ProcessESP, dt, cam, TargetList)

	local now = os.clock()
	if now - lastStats > 0.5 then
		lastStats = now
		local n = 0
		local ignore = Settings.ESP.IgnoreDummy
		for _, e in ipairs(TargetList) do
			if not (ignore and e.IsDummy) then
				n += 1
			end
		end
		StatsLabel.Text = "Cele: " .. n
	end
end)
