local Version = "beta"

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

local Settings = {
	ESP = {
		Enabled = false,
		Boxes = false,
		BoxStyle = "Corner",
		Fill = false,
		Outline = true,
		Names = false,
		Distance = false,
		Health = false,
		HPGradient = true,
		Tracers = false,
		TracerOrigin = "Bottom",
		Skeleton = false,
		MaxDistance = 1000,
		RainbowColor = false,
	},
	Aimbot = {
		Enabled = false,
		HoldKey = Enum.UserInputType.MouseButton2,
		TargetPart = "Head",
		Smoothness = 20,
		FOV = 150,
		MaxDistance = 500,
		WallCheck = true,
		MultiRay = true,
		ShowFOV = false,
		IgnoreDummy = true,
		PlayersOnly = false,
		TeamCheck = false,
		Priority = "Crosshair",
		Prediction = false,
		PredictTime = 0.12,
		AutoPredict = true,
		AimMode = "Snap",
		SilentAim = false,
		SilentChance = 100,
		StickySwitch = 0.12,
		StickyTolerance = 1.3,
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
		AlienFit = false,
		AlienRainbow = false,
	},
	Movement = {
		Fly = false,
		FlyKey = Enum.KeyCode.Unknown,
		FlyFaceCamera = true,
		FlySpeed = 60,
		SpeedEnabled = false,
		WalkSpeed = 32,
		JumpEnabled = false,
		JumpPower = 100,
		InfJump = false,
		Noclip = false,
	},
}

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

local Theme = {
	Accent = Color3.fromRGB(147, 51, 234),
}

local Presets = {
	{ "Fiolet", Color3.fromRGB(147, 51, 234) },
	{ "Cyan", Color3.fromRGB(34, 211, 238) },
	{ "Róż", Color3.fromRGB(244, 114, 182) },
	{ "Zieleń", Color3.fromRGB(74, 222, 128) },
	{ "Pomarańcz", Color3.fromRGB(251, 146, 60) },
	{ "Czerwień", Color3.fromRGB(248, 113, 113) },
	{ "Biały", Color3.fromRGB(255, 255, 255) },
	{ "Czarny", Color3.fromRGB(0, 0, 0) },
	{ "Żółty", Color3.fromRGB(250, 204, 21) },
	{ "Niebieski", Color3.fromRGB(59, 130, 246) },
	{ "Turkus", Color3.fromRGB(20, 184, 166) },
	{ "Limonka", Color3.fromRGB(163, 230, 53) },
	{ "Magenta", Color3.fromRGB(217, 70, 239) },
	{ "Szary", Color3.fromRGB(148, 163, 184) },
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

local VisCache = setmetatable({}, { __mode = "k" })
local function Vis(inst, v)
	v = v and true or false
	if VisCache[inst] ~= v then
		VisCache[inst] = v
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

local Registry = {}
local TargetList = {}

local function IsDummyName(name)
	return string.find(string.lower(name), DUMMY_KEYWORD, 1, true) ~= nil
end

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
	FriendVersion = FriendVersion + 1
	return true, "Dodano: " .. key
end

local function RemoveFriend(key)
	if FriendSet[key] then
		FriendSet[key] = nil
		FriendVersion = FriendVersion + 1
	end
end

-- Szuka czesci po nazwie najpierw jako bezposredniego dziecka (typowy rig), a jesli jej tam
-- nie ma, przeszukuje caly model w glab. Niektore gry chowaja Head / HumanoidRootPart w dodatkowym
-- folderze/podmodelu (np. Character -> Rig -> Head), a sama nazwa "FindFirstChild" bez rekurencji
-- tego nie znajduje - stad gracz "nie jest wykrywany" mimo ze fizycznie tam jest.
local function FindPart(model, name)
	local p = model:FindFirstChild(name)
	if p and p:IsA("BasePart") then
		return p
	end
	p = model:FindFirstChild(name, true)
	if p and p:IsA("BasePart") then
		return p
	end
	return nil
end

-- Mapa Humanoid -> Model, niezalezna od tego gdzie fizycznie siedzi Humanoid w hierarchii;
-- uzywana do bezpiecznego wyrejestrowania bez zgadywania po .Parent.
local HumanoidOwnerModel = setmetatable({}, { __mode = "k" })

-- Ustala, do kogo nalezy dany Humanoid: jesli jest potomkiem ktoregokolwiek z aktualnych
-- Player.Character, uzywamy TEGO modelu jako klucza rejestru (gwarantowany prawidlowy gracz,
-- nawet gdy Humanoid jest zagniezdzony glebiej niz bezposrednio pod postacia gracza). W innym
-- wypadku traktujemy to jako NPC i bierzemy najblizszy Model-rodzic (stare zachowanie).
local function FindOwningCharacter(desc)
	for _, pl in ipairs(Players:GetPlayers()) do
		local char = pl.Character
		if char and desc:IsDescendantOf(char) then
			return pl, char
		end
	end
	return nil, nil
end

local function RegisterHumanoid(desc)
	if not desc:IsA("Humanoid") then
		return
	end
	local owner, ownerChar = FindOwningCharacter(desc)
	local model = ownerChar or desc.Parent
	if not (model and model:IsA("Model")) then
		return
	end

	local existing = Registry[model]
	if existing then
		-- ten sam model (np. respawn z ponownie uzytym rigiem) - tylko doczep nowy Humanoid/gracza
		existing.Humanoid = desc
		if owner then
			existing.Player = owner
		end
		existing.Root, existing.Head, existing.Torso = nil, nil, nil
		HumanoidOwnerModel[desc] = model
		return
	end

	local e = {
		Model = model,
		Humanoid = desc,
		Root = nil,
		Head = nil,
		Player = owner or Players:GetPlayerFromCharacter(model),
		PlayerCheck = 0,
		IsDummy = IsDummyName(model.Name),
		Checked = 0,
		Valid = false,
	}
	e.NameConn = model:GetPropertyChangedSignal("Name"):Connect(function()
		e.IsDummy = IsDummyName(model.Name)
	end)
	Registry[model] = e
	HumanoidOwnerModel[desc] = model
end

local function UnregisterHumanoid(desc)
	if not desc:IsA("Humanoid") then
		return
	end
	local model = HumanoidOwnerModel[desc]
	HumanoidOwnerModel[desc] = nil
	if not model then
		return
	end
	local e = Registry[model]
	if e and e.Humanoid == desc then
		e.NameConn:Disconnect()
		Registry[model] = nil
	end
end

for _, desc in ipairs(Workspace:GetDescendants()) do
	RegisterHumanoid(desc)
end
Workspace.DescendantAdded:Connect(RegisterHumanoid)
Workspace.DescendantRemoving:Connect(UnregisterHumanoid)

-- Siatka bezpieczenstwa: niezaleznie od skanowania Workspace, kazdy Humanoid pod postacia
-- gracza (istniejacego lub nowego/odradzajacego sie) zostaje zarejestrowany wprost ze zdarzen
-- Players, zamiast polegac wylacznie na kolejnosci DescendantAdded. To naprawia gry, w ktorych
-- postac buduje sie stopniowo albo Humanoid pojawia sie zanim gra w pelni ustawi Player.Character.
local function ScanCharacter(char)
	if not (char and char.Parent) then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid") or char:FindFirstChildWhichIsA("Humanoid", true)
	if hum then
		RegisterHumanoid(hum)
	end
end

local function HookPlayer(pl)
	pl.CharacterAdded:Connect(function(char)
		task.defer(ScanCharacter, char)
		task.delay(0.5, ScanCharacter, char)
		task.delay(2, ScanCharacter, char)
	end)
	if pl.Character then
		task.defer(ScanCharacter, pl.Character)
	end
end

for _, pl in ipairs(Players:GetPlayers()) do
	HookPlayer(pl)
end
Players.PlayerAdded:Connect(HookPlayer)

local function GetRoot(e)
	local r = e.Root
	if r and r.Parent then
		return r
	end
	r = FindPart(e.Model, "HumanoidRootPart") or e.Model.PrimaryPart
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
	h = FindPart(e.Model, "Head")
	e.Head = h
	return h
end

local function GetTorso(e)
	local t = e.Torso
	if t and t.Parent then
		return t
	end
	local m = e.Model
	t = FindPart(m, "UpperTorso") or FindPart(m, "Torso")
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

local PlayerList = {}

local function GetTargets(now)
	table.clear(TargetList)
	table.clear(PlayerList)
	for model, e in pairs(Registry) do
		local hum = e.Humanoid
		if not model.Parent or hum.Parent ~= model then
			e.NameConn:Disconnect()
			Registry[model] = nil
		else
			if not e.Player and now - e.PlayerCheck > 0.5 then
				e.PlayerCheck = now
				e.Player = Players:GetPlayerFromCharacter(model)
			end
			if now - e.Checked > 0.5 then
				e.Checked = now
				e.Valid = ValidateEntry(e)
			end
			if e.Valid and hum.Health > 0 then
				TargetList[#TargetList + 1] = e
				if e.Player then
					PlayerList[#PlayerList + 1] = e
				end
			end
		end
	end
	return TargetList
end

local UI = {
	Bg = Color3.fromRGB(9, 9, 11),
	Side = Color3.fromRGB(13, 13, 16),
	Card = Color3.fromRGB(20, 20, 24),
	Line = Color3.fromRGB(34, 34, 40),
	Off = Color3.fromRGB(44, 44, 52),
	Blue = Color3.fromRGB(100, 188, 255),
	BlueDim = Color3.fromRGB(46, 96, 140),
	BlueDark = Color3.fromRGB(38, 104, 178),
	Red = Color3.fromRGB(122, 44, 56),
}

local VERSION_YELLOW = Color3.fromRGB(255, 205, 40)
local function VersionColor()
	if string.lower(tostring(Version)) == "beta" then
		return VERSION_YELLOW
	end
	return UI.Blue
end
local function VersionLabel()
	if string.lower(tostring(Version)) == "beta" then
		return "BETA"
	end
	return tostring(Version)
end
local function ToHex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local W, H = 640, 440
local SIDE_W, HEADER_H, FOOT_H = 152, 54, 36
local BODY_H = H - HEADER_H - 1 - FOOT_H

local ESPGui = New("ScreenGui", {
	Name = "PolishMafia_ESP",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 1,
	Parent = PlayerGui,
})

local MenuGui = New("ScreenGui", {
	Name = "PolishMafia_GUI",
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
	Visible = false,
	Parent = MenuGui,
})

local Main = New("CanvasGroup", {
	Name = "Main",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = UI.Bg,
	BorderSizePixel = 0,
	Parent = Root,
})
Corner(Main, 12)
local MainStroke = Stroke(Main, UI.Line, 1, 0)
local MainStrokeGradient = Instance.new("UIGradient")
MainStrokeGradient.Color = ColorSequence.new(Color3.fromRGB(70, 70, 82), UI.Line)
MainStrokeGradient.Rotation = 90
MainStrokeGradient.Parent = MainStroke

local Header = New("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, HEADER_H),
	BackgroundTransparency = 1,
	Parent = Main,
})
New("Frame", {
	Position = UDim2.fromOffset(0, HEADER_H),
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = UI.Line,
	BorderSizePixel = 0,
	Parent = Main,
})

local TitleRow = New("Frame", {
	Position = UDim2.fromOffset(22, 0),
	Size = UDim2.new(0, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	Parent = Header,
})
do
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, 10)
	l.Parent = TitleRow

	local bar = New("Frame", {
		Size = UDim2.fromOffset(4, 20),
		BackgroundColor3 = UI.Blue,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Parent = TitleRow,
	})
	Corner(bar, 2)
	New("TextLabel", {
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = "Polish Mafia",
		TextSize = 20,
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBold,
		LayoutOrder = 2,
		Parent = TitleRow,
	})

	local vc = VersionColor()
	local badge = New("Frame", {
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = vc,
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		LayoutOrder = 3,
		Parent = TitleRow,
	})
	Corner(badge, 6)
	Stroke(badge, vc, 1.5, 0)
	do
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 9)
		pad.PaddingRight = UDim.new(0, 9)
		pad.Parent = badge
	end
	New("TextLabel", {
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = VersionLabel(),
		TextSize = 14,
		TextColor3 = vc,
		Font = Enum.Font.GothamBold,
		Parent = badge,
	})
end

local DragBar = New("Frame", {
	Name = "DragBar",
	Size = UDim2.new(1, -60, 1, 0),
	BackgroundTransparency = 1,
	Parent = Header,
})

local CloseBtn = New("TextButton", {
	Size = UDim2.fromOffset(30, 30),
	Position = UDim2.new(1, -44, 0.5, -15),
	BackgroundColor3 = UI.Card,
	BackgroundTransparency = 1,
	Text = "×",
	TextColor3 = WHITE,
	TextSize = 22,
	Font = Enum.Font.GothamMedium,
	AutoButtonColor = false,
	Parent = Header,
})
Corner(CloseBtn, 8)
CloseBtn.MouseEnter:Connect(function()
	Tween(CloseBtn, 0.15, { BackgroundTransparency = 0, BackgroundColor3 = UI.Red })
end)
CloseBtn.MouseLeave:Connect(function()
	Tween(CloseBtn, 0.2, { BackgroundTransparency = 1 })
end)

local Sidebar = New("Frame", {
	Position = UDim2.fromOffset(0, HEADER_H + 1),
	Size = UDim2.fromOffset(SIDE_W, BODY_H),
	BackgroundColor3 = UI.Side,
	BorderSizePixel = 0,
	Parent = Main,
})
New("Frame", {
	Position = UDim2.new(1, -1, 0, 0),
	Size = UDim2.new(0, 1, 1, 0),
	BackgroundColor3 = UI.Line,
	BorderSizePixel = 0,
	Parent = Sidebar,
})
local TabList = New("Frame", {
	Position = UDim2.fromOffset(10, 12),
	Size = UDim2.new(1, -21, 1, -24),
	BackgroundTransparency = 1,
	Parent = Sidebar,
})
do
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 4)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = TabList
end

local Content = New("Frame", {
	Position = UDim2.fromOffset(SIDE_W + 1 + 16, HEADER_H + 1 + 12),
	Size = UDim2.fromOffset(W - SIDE_W - 1 - 16 - 8, BODY_H - 12),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	Parent = Main,
})

local Footer = New("Frame", {
	Position = UDim2.new(0, 0, 1, -FOOT_H),
	Size = UDim2.new(1, 0, 0, FOOT_H),
	BackgroundTransparency = 1,
	Parent = Main,
})
New("Frame", {
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = UI.Line,
	BorderSizePixel = 0,
	Parent = Footer,
})
do
	local hint = Label(Footer, "RightShift – ukryj / pokaż menu", 11, WHITE, Enum.Font.GothamMedium, UDim2.fromOffset(240, FOOT_H), UDim2.fromOffset(22, 0))
	hint.TextTransparency = 0.45
end
local StatsLabel = Label(Footer, "Gracze: 0", 11, WHITE, Enum.Font.GothamMedium, UDim2.fromOffset(160, FOOT_H), UDim2.new(1, -182, 0, 0), Enum.TextXAlignment.Right)
StatsLabel.TextTransparency = 0.45

local Refreshers = {}

local function CreatePage()
	local group = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		Parent = Content,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = group
	local p = New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = UI.Blue,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = group,
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
	return p, group
end

local function Card(parent, height, clickable, base)
	base = base or UI.Card
	local card = Instance.new(clickable and "TextButton" or "Frame")
	card.Size = UDim2.new(1, 0, 0, height)
	card.BackgroundColor3 = base
	card.BorderSizePixel = 0
	if clickable then
		card.Text = ""
		card.AutoButtonColor = false
	end
	card.LayoutOrder = NextOrder(parent)
	card.Parent = parent
	Corner(card, 8)
	local s = Stroke(card, UI.Line, 1, 0)

	if clickable then
		card.MouseEnter:Connect(function()
			Tween(card, 0.15, { BackgroundColor3 = base:Lerp(WHITE, 0.07) })
			Tween(s, 0.15, { Color = UI.BlueDim })
		end)
		card.MouseLeave:Connect(function()
			Tween(card, 0.2, { BackgroundColor3 = base })
			Tween(s, 0.2, { Color = UI.Line })
		end)
		card.MouseButton1Down:Connect(function()
			Tween(card, 0.08, { BackgroundColor3 = base:Lerp(BLACK, 0.3) })
		end)
		card.MouseButton1Up:Connect(function()
			Tween(card, 0.15, { BackgroundColor3 = base:Lerp(WHITE, 0.07) })
		end)
	end
	return card
end

local function CreateSection(page, text)
	local f = New("Frame", {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		LayoutOrder = NextOrder(page),
		Parent = page,
	})
	local sq = New("Frame", {
		Size = UDim2.fromOffset(6, 6),
		Position = UDim2.new(0, 2, 0.5, -3),
		BackgroundColor3 = UI.Blue,
		BorderSizePixel = 0,
		Parent = f,
	})
	Corner(sq, 1)
	local l = Label(f, string.upper(text), 11, WHITE, Enum.Font.GothamBold, UDim2.new(1, -20, 1, 0), UDim2.fromOffset(16, 0))
	l.TextTransparency = 0.35
end

local function CreateToggle(page, text, category, key, onChange)
	local card = Card(page, 40, true)
	Label(card, text, 13, WHITE, Enum.Font.GothamMedium, UDim2.new(1, -80, 1, 0), UDim2.fromOffset(14, 0))

	local pill = New("Frame", {
		Size = UDim2.fromOffset(38, 20),
		Position = UDim2.new(1, -52, 0.5, -10),
		BackgroundColor3 = UI.Off,
		BorderSizePixel = 0,
		Parent = card,
	})
	Corner(pill, UDim.new(1, 0))

	local knob = New("Frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.new(0, 3, 0.5, -7),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Parent = pill,
	})
	Corner(knob, UDim.new(1, 0))

	local function apply(animated)
		local on = Settings[category][key]
		local t = animated and 0.22 or 0
		Tween(pill, t, { BackgroundColor3 = on and UI.Blue or UI.Off })
		Tween(knob, t, { Position = on and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7) }, Enum.EasingStyle.Back)
	end
	apply(false)
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
	local card = Card(page, 54, false)
	Label(card, text, 13, WHITE, Enum.Font.GothamMedium, UDim2.new(1, -110, 0, 22), UDim2.fromOffset(14, 8))
	local valLbl = Label(card, "", 13, UI.Blue, Enum.Font.GothamBold, UDim2.fromOffset(90, 22), UDim2.new(1, -104, 0, 8), Enum.TextXAlignment.Right)

	local track = New("Frame", {
		Size = UDim2.new(1, -28, 0, 4),
		Position = UDim2.fromOffset(14, 38),
		BackgroundColor3 = UI.Off,
		BorderSizePixel = 0,
		Parent = card,
	})
	Corner(track, UDim.new(1, 0))
	local fill = New("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = UI.Blue,
		BorderSizePixel = 0,
		Parent = track,
	})
	Corner(fill, UDim.new(1, 0))
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		Position = UDim2.fromScale(0, 0.5),
		BackgroundColor3 = UI.Blue,
		BorderSizePixel = 0,
		Parent = track,
	})
	Corner(knob, UDim.new(1, 0))
	Stroke(knob, UI.Card, 2, 0)

	local function render()
		local v = Settings[category][key]
		local rel = (v - minV) / (maxV - minV)
		fill.Size = UDim2.fromScale(rel, 1)
		knob.Position = UDim2.fromScale(rel, 0.5)
		valLbl.Text = string.format("%g", v) .. suffix
	end
	render()
	table.insert(Refreshers, render)

	local function setFromX(x)
		local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local val = math.floor((minV + (maxV - minV) * rel) / step + 0.5) * step
		Settings[category][key] = math.clamp(val, minV, maxV)
		render()
	end

	local hit = New("TextButton", {
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 28),
		BackgroundTransparency = 1,
		Text = "",
		Parent = card,
	})

	local dragging = false
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			Tween(knob, 0.12, { Size = UDim2.fromOffset(16, 16) }, Enum.EasingStyle.Back)
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			Tween(knob, 0.15, { Size = UDim2.fromOffset(12, 12) })
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
end

local function CreateChoice(page, text, category, key, options)
	local card = Card(page, 40, true)
	Label(card, text, 13, WHITE, Enum.Font.GothamMedium, UDim2.new(1, -150, 1, 0), UDim2.fromOffset(14, 0))
	local chip = New("TextLabel", {
		Size = UDim2.fromOffset(112, 24),
		Position = UDim2.new(1, -126, 0.5, -12),
		BackgroundColor3 = UI.Off,
		BorderSizePixel = 0,
		TextSize = 12,
		TextColor3 = UI.Blue,
		Font = Enum.Font.GothamBold,
		Text = "",
		Parent = card,
	})
	Corner(chip, 6)

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
	table.insert(Refreshers, apply)

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
		chip.Size = UDim2.fromOffset(104, 22)
		Tween(chip, 0.25, { Size = UDim2.fromOffset(112, 24) }, Enum.EasingStyle.Back)
	end)
end

local Binding, BindJustSet = nil, 0

local function CreateBind(page, text, category, key)
	local card = Card(page, 40, true)
	Label(card, text, 13, WHITE, Enum.Font.GothamMedium, UDim2.new(1, -150, 1, 0), UDim2.fromOffset(14, 0))
	local chip = New("TextLabel", {
		Size = UDim2.fromOffset(112, 24),
		Position = UDim2.new(1, -126, 0.5, -12),
		BackgroundColor3 = UI.Off,
		BorderSizePixel = 0,
		TextSize = 12,
		TextColor3 = UI.Blue,
		Font = Enum.Font.GothamBold,
		Text = "",
		Parent = card,
	})
	Corner(chip, 6)

	local mine = {}
	local function apply()
		if Binding == mine then
			chip.Text = "Naciśnij..."
			chip.TextColor3 = WHITE
		else
			local k = Settings[category][key]
			chip.Text = (k == nil or k == Enum.KeyCode.Unknown) and "Brak" or k.Name
			chip.TextColor3 = UI.Blue
		end
	end
	apply()
	table.insert(Refreshers, apply)

	card.MouseButton1Click:Connect(function()
		Binding = (Binding == mine) and nil or mine
		apply()
	end)

	UserInputService.InputBegan:Connect(function(input)
		if Binding ~= mine or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			Settings[category][key] = Enum.KeyCode.Unknown
		else
			Settings[category][key] = input.KeyCode
		end
		Binding = nil
		BindJustSet = os.clock()
		apply()
	end)
end

local function CreateColorRow(page, text)
	local card = Card(page, 108, false)
	Label(card, text, 13, WHITE, Enum.Font.GothamMedium, UDim2.new(1, -28, 0, 22), UDim2.fromOffset(14, 8))
	local row = New("Frame", {
		Position = UDim2.fromOffset(14, 36),
		Size = UDim2.new(1, -28, 0, 62),
		BackgroundTransparency = 1,
		Parent = card,
	})
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Wraps = true
	l.Padding = UDim.new(0, 10)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = row

	local RING = Color3.fromRGB(80, 80, 92)
	local swatches = {}
	for i, p in ipairs(Presets) do
		local b = New("TextButton", {
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = p[2],
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = i,
			Parent = row,
		})
		Corner(b, UDim.new(1, 0))
		local st = Stroke(b, RING, 2, 0)
		table.insert(swatches, { b, st, p[2] })
		b.MouseButton1Click:Connect(function()
			SetAccent(p[2])
		end)
		b.MouseEnter:Connect(function()
			if Theme.Accent ~= p[2] then
				Tween(st, 0.12, { Color = WHITE })
			end
		end)
		b.MouseLeave:Connect(function()
			if Theme.Accent ~= p[2] then
				Tween(st, 0.12, { Color = RING })
			end
		end)
	end
	BindAccent(function()
		for _, s in ipairs(swatches) do
			Tween(s[2], 0.2, { Color = (s[3] == Theme.Accent) and UI.Blue or RING })
		end
	end)
end

local function CreateInfo(page, text, height)
	local card = Card(page, height, false)
	local l = Label(card, text, 12, WHITE, Enum.Font.GothamMedium, UDim2.new(1, -28, 1, -16), UDim2.fromOffset(14, 8))
	l.TextTransparency = 0.35
	l.TextWrapped = true
	l.TextYAlignment = Enum.TextYAlignment.Top
end

local function CreateButton(page, text, color, callback)
	local card = Card(page, 40, true, color)
	local lbl = Label(card, text, 13, WHITE, Enum.Font.GothamBold, UDim2.fromScale(1, 1), UDim2.new(), Enum.TextXAlignment.Center)
	card.MouseButton1Click:Connect(function()
		lbl.TextSize = 11
		Tween(lbl, 0.25, { TextSize = 13 }, Enum.EasingStyle.Back)
		callback()
	end)
end

local Tabs = {}
local CurrentTab = nil

local function SelectTab(name, instant)
	if CurrentTab == name then
		return
	end
	CurrentTab = name
	local d = instant and 0 or 0.22
	for n, t in pairs(Tabs) do
		local active = n == name
		Tween(t.Marker, d, { Size = active and UDim2.fromOffset(8, 8) or UDim2.fromOffset(0, 0) }, active and Enum.EasingStyle.Back or Enum.EasingStyle.Quad)
		Tween(t.Label, d, { TextTransparency = active and 0 or 0.4, Position = active and UDim2.fromOffset(32, 0) or UDim2.fromOffset(30, 0) })
		Tween(t.Button, d, { BackgroundTransparency = active and 0 or 1 })

		for _, tw in ipairs(t.Tweens) do
			tw:Cancel()
		end
		table.clear(t.Tweens)

		local g, sc = t.Group, t.Scale
		if active then
			g.Visible = true
			if instant then
				g.Position = UDim2.new()
				if sc then
					sc.Scale = 1
				end
			else
				g.Position = UDim2.fromOffset(0, 16)
				t.Tweens[1] = Tween(g, 0.28, { Position = UDim2.new() }, Enum.EasingStyle.Quart)
				if sc then
					sc.Scale = 0.975
					t.Tweens[2] = Tween(sc, 0.28, { Scale = 1 }, Enum.EasingStyle.Quart)
				end
			end
		else
			g.Visible = false
			g.Position = UDim2.new()
			if sc then
				sc.Scale = 1
			end
		end
	end
end

local function CreateTab(name, order)
	local btn = New("TextButton", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = UI.Card,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order,
		Parent = TabList,
	})
	Corner(btn, 8)

	local marker = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = UI.Blue,
		BorderSizePixel = 0,
		Parent = btn,
	})
	Corner(marker, 2)

	local lbl = Label(btn, name, 13, WHITE, Enum.Font.GothamBold, UDim2.new(1, -36, 1, 0), UDim2.fromOffset(30, 0))
	lbl.TextTransparency = 0.4

	local page, group = CreatePage()
	Tabs[name] = { Button = btn, Label = lbl, Marker = marker, Group = group, Scale = group:FindFirstChildOfClass("UIScale"), Page = page, Tweens = {} }

	btn.MouseEnter:Connect(function()
		if CurrentTab ~= name then
			Tween(lbl, 0.15, { TextTransparency = 0.1 })
			Tween(btn, 0.15, { BackgroundTransparency = 0.6 })
		end
	end)
	btn.MouseLeave:Connect(function()
		if CurrentTab ~= name then
			Tween(lbl, 0.15, { TextTransparency = 0.4 })
			Tween(btn, 0.15, { BackgroundTransparency = 1 })
		end
	end)
	btn.MouseButton1Click:Connect(function()
		SelectTab(name, false)
	end)
	return page
end

local PageESP = CreateTab("ESP", 1)
local PageAim = CreateTab("Aimbot", 2)
local PageVisual = CreateTab("Visual", 3)
local PageMove = CreateTab("Movement", 4)
local PageFriends = CreateTab("Friendz", 5)
local PageConfig = CreateTab("Config", 6)
local PageSet = CreateTab("Ustawienia", 7)

CreateSection(PageESP, "Główne")
CreateToggle(PageESP, "Włącz ESP (tylko gracze)", "ESP", "Enabled")
CreateSlider(PageESP, "Maksymalny dystans", "ESP", "MaxDistance", 100, 3000, 50, " st")
CreateToggle(PageESP, "Rainbow kolor ESP", "ESP", "RainbowColor")
CreateSection(PageESP, "Box")
CreateToggle(PageESP, "Box 2D", "ESP", "Boxes")
CreateChoice(PageESP, "Styl boxa", "ESP", "BoxStyle", { { "Corner", "Narożniki" }, { "Full", "Pełny" } })
CreateToggle(PageESP, "Wypełnienie boxa", "ESP", "Fill")
CreateToggle(PageESP, "Czarny obrys", "ESP", "Outline")
CreateSection(PageESP, "Informacje")
CreateToggle(PageESP, "Nickname", "ESP", "Names")
CreateToggle(PageESP, "Dystans", "ESP", "Distance")
CreateToggle(PageESP, "Pasek HP (po lewej)", "ESP", "Health")
CreateToggle(PageESP, "HP gradient (zielony → czerwony)", "ESP", "HPGradient")
CreateSection(PageESP, "Linie")
CreateToggle(PageESP, "Tracer", "ESP", "Tracers")
CreateChoice(PageESP, "Początek tracera", "ESP", "TracerOrigin", { { "Bottom", "Dół" }, { "Center", "Środek" }, { "Top", "Góra" }, { "Mouse", "Kursor" } })
CreateToggle(PageESP, "Szkielet (R6 / R15)", "ESP", "Skeleton")

local SilentStatusLabel
local AimStatusLabel, AimStatusDot

CreateSection(PageAim, "Status")
do
	local card = Card(PageAim, 40, false)
	AimStatusDot = New("Frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.new(0, 14, 0.5, -4),
		BackgroundColor3 = UI.Off,
		BorderSizePixel = 0,
		Parent = card,
	})
	Corner(AimStatusDot, 4)
	AimStatusLabel = Label(card, "Aimbot: wyłączony", 13, WHITE, Enum.Font.GothamMedium, UDim2.new(1, -40, 1, 0), UDim2.fromOffset(32, 0))
	AimStatusLabel.TextTransparency = 0.25
end

CreateSection(PageAim, "Główne")
CreateToggle(PageAim, "Włącz Aimbot (przytrzymaj PPM)", "Aimbot", "Enabled")
CreateChoice(PageAim, "Tryb celowania", "Aimbot", "AimMode", { { "Snap", "Natychmiast" }, { "Smooth", "Płynny" } })
CreateToggle(PageAim, "Pokaż okrąg FOV", "Aimbot", "ShowFOV")
CreateToggle(PageAim, "WallCheck (widoczność)", "Aimbot", "WallCheck")
CreateToggle(PageAim, "MultiRay (odporny WallCheck)", "Aimbot", "MultiRay")
CreateToggle(PageAim, "Tylko gracze (bez NPC)", "Aimbot", "PlayersOnly")
CreateToggle(PageAim, "Ignoruj Dummy", "Aimbot", "IgnoreDummy")
CreateToggle(PageAim, "Team Check (pomiń drużynę)", "Aimbot", "TeamCheck")
CreateToggle(PageAim, "Tryb środka (kursor na środek)", "Aimbot", "CenterLock")
CreateChoice(PageAim, "Cel", "Aimbot", "TargetPart", { { "Head", "Głowa" }, { "HumanoidRootPart", "Tułów" } })
CreateChoice(PageAim, "Priorytet celu", "Aimbot", "Priority", { { "Crosshair", "Celownik" }, { "Distance", "Dystans" } })
CreateSection(PageAim, "Parametry")
CreateSlider(PageAim, "Płynność (tryb Płynny)", "Aimbot", "Smoothness", 5, 50, 1)
CreateSlider(PageAim, "Promień FOV", "Aimbot", "FOV", 30, 500, 5, " px")
CreateSlider(PageAim, "Maksymalny dystans", "Aimbot", "MaxDistance", 50, 2000, 10, " st")
CreateSlider(PageAim, "Maks. prędkość obrotu (tryb Płynny)", "Aimbot", "MaxSpeed", 100, 1500, 25, " °/s")
CreateSection(PageAim, "Stabilizacja celu")
CreateSlider(PageAim, "Tolerancja trzymania celu", "Aimbot", "StickyTolerance", 1, 2.5, 0.05, "x")
CreateInfo(PageAim, "Wyższa tolerancja = aimbot trzyma już namierzony cel nawet gdy na chwilę wypadnie poza środek FOV, zamiast migać między kilkoma graczami.", 50)
CreateSection(PageAim, "Predykcja")
CreateToggle(PageAim, "Predykcja ruchu celu", "Aimbot", "Prediction")
CreateToggle(PageAim, "Auto-predykcja (wg dystansu)", "Aimbot", "AutoPredict")
CreateSlider(PageAim, "Bazowy czas predykcji", "Aimbot", "PredictTime", 0.02, 0.5, 0.01, " s")
CreateSection(PageAim, "Silent Aim")
CreateToggle(PageAim, "Silent Aim (bez ruszania kamerą)", "Aimbot", "SilentAim")
CreateSlider(PageAim, "Szansa trafienia", "Aimbot", "SilentChance", 1, 100, 1, " %")
do
	local card = Card(PageAim, 30, false)
	SilentStatusLabel = Label(card, "Silent Aim: wyłączony", 11, WHITE, Enum.Font.GothamMedium, UDim2.new(1, -28, 1, 0), UDim2.fromOffset(14, 0))
	SilentStatusLabel.TextTransparency = 0.3
end
CreateInfo(PageAim, "Silent Aim kieruje strzał na cel najbliżej środka FOV (głowa), bez ruszania kamerą. Używa FOV, dystansu, WallCheck, Team Check i Tylko gracze z ustawień powyżej. Wymaga executora z hookmetamethod i działa w grach celujących przez Mouse.Hit / Raycast / ScreenPointToRay.", 92)
CreateSection(PageAim, "Hitbox głowy")
CreateToggle(PageAim, "Powiększ głowę (+ hitbox)", "Aimbot", "HeadExpand")
CreateToggle(PageAim, "Widoczna duża głowa (fiolet)", "Aimbot", "HeadVisible")
CreateSlider(PageAim, "Rozmiar głowy", "Aimbot", "HeadSize", 1, 12, 0.25, "x")

local VisualHolder
local AlienStatusLabel
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
CreateToggle(VisualHolder, "Pistol", "Visual", "VintagePistol")
CreateToggle(VisualHolder, "Alien Fit (rainbow)", "Visual", "AlienRainbow")
UpdateVisualVis()
table.insert(Refreshers, UpdateVisualVis)

CreateSection(PageVisual, "Outfit")
CreateToggle(PageVisual, "Alien Fit (zdejmuje akcesoria)", "Visual", "AlienFit")
do
	local card = Card(PageVisual, 30, false)
	AlienStatusLabel = Label(card, "Alien Fit: wyłączony", 11, WHITE, Enum.Font.GothamMedium, UDim2.new(1, -28, 1, 0), UDim2.fromOffset(14, 0))
	AlienStatusLabel.TextTransparency = 0.3
end
CreateInfo(PageVisual, "Rainbow i Alien Fit działają tylko lokalnie (po stronie klienta). Alien Fit wymaga executora z game:GetObjects. Opcje obiektów pojawiają się po włączeniu Rainbow Mode.", 76)

CreateSection(PageMove, "Latanie (Fly)")
CreateToggle(PageMove, "Włącz Fly (działa też w aucie)", "Movement", "Fly")
CreateBind(PageMove, "Bind Fly (kliknij i naciśnij klawisz)", "Movement", "FlyKey")
CreateToggle(PageMove, "Auto w 3 os. obraca się za kamerą", "Movement", "FlyFaceCamera")
CreateSlider(PageMove, "Prędkość Fly", "Movement", "FlySpeed", 10, 300, 5, " st/s")
CreateSection(PageMove, "Chodzenie i skok")
CreateToggle(PageMove, "Zmień prędkość chodu", "Movement", "SpeedEnabled")
CreateSlider(PageMove, "Prędkość chodu", "Movement", "WalkSpeed", 16, 150, 1)
CreateToggle(PageMove, "Zmień siłę skoku", "Movement", "JumpEnabled")
CreateSlider(PageMove, "Siła skoku", "Movement", "JumpPower", 50, 300, 5)
CreateToggle(PageMove, "Nieskończony skok", "Movement", "InfJump")
CreateToggle(PageMove, "Noclip (przenikanie)", "Movement", "Noclip")
CreateSection(PageMove, "Informacje")
CreateInfo(PageMove, "Fly nie ma domyślnego klawisza: kliknij „Bind Fly”, naciśnij wybrany klawisz (Esc = usuń). Lot: W / A / S / D względem kamery, Spacja = w górę, Ctrl lub Q = w dół. Siedząc w aucie (Seat) leci cały pojazd i obraca się przodem tam, gdzie patrzy kamera.", 84)

local RebuildFriendRows

CreateSection(PageFriends, "Dodaj znajomego")
do
	local card = Card(PageFriends, 92, false)
	Label(card, "Nick gracza (Name lub DisplayName)", 13, WHITE, Enum.Font.GothamMedium, UDim2.new(1, -28, 0, 22), UDim2.fromOffset(14, 8))

	local box = New("TextBox", {
		Size = UDim2.new(1, -120, 0, 30),
		Position = UDim2.fromOffset(14, 32),
		BackgroundColor3 = UI.Off,
		BorderSizePixel = 0,
		Text = "",
		PlaceholderText = "wpisz nick...",
		PlaceholderColor3 = Color3.fromRGB(150, 150, 160),
		TextColor3 = WHITE,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = card,
	})
	Corner(box, 6)
	local boxStroke = Stroke(box, UI.Line, 1, 0)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = box
	box.Focused:Connect(function()
		Tween(boxStroke, 0.15, { Color = UI.Blue })
	end)
	box.FocusLost:Connect(function()
		Tween(boxStroke, 0.15, { Color = UI.Line })
	end)

	local addBtn = New("TextButton", {
		Size = UDim2.fromOffset(84, 30),
		Position = UDim2.new(1, -98, 0, 32),
		BackgroundColor3 = UI.BlueDark,
		BorderSizePixel = 0,
		Text = "Dodaj",
		TextColor3 = WHITE,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = false,
		Parent = card,
	})
	Corner(addBtn, 6)
	addBtn.MouseEnter:Connect(function()
		Tween(addBtn, 0.15, { BackgroundColor3 = UI.BlueDark:Lerp(WHITE, 0.12) })
	end)
	addBtn.MouseLeave:Connect(function()
		Tween(addBtn, 0.2, { BackgroundColor3 = UI.BlueDark })
	end)

	local status = Label(card, "", 11, WHITE, Enum.Font.GothamMedium, UDim2.new(1, -28, 0, 20), UDim2.fromOffset(14, 66))
	status.TextTransparency = 0.3

	local function submit()
		local ok, msg = AddFriend(box.Text)
		status.Text = msg
		status.TextColor3 = ok and FRIEND_COLOR or Color3.fromRGB(248, 113, 113)
		status.TextTransparency = 0
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
		local card = Card(FriendHolder, 36, false)
		local l = Label(card, "Lista jest pusta", 12, WHITE, Enum.Font.GothamMedium, UDim2.new(1, -28, 1, 0), UDim2.fromOffset(14, 0))
		l.TextTransparency = 0.4
		return
	end

	for _, key in ipairs(keys) do
		local card = Card(FriendHolder, 38, false)
		local dot = New("Frame", {
			Size = UDim2.fromOffset(8, 8),
			Position = UDim2.new(0, 14, 0.5, -4),
			BackgroundColor3 = FRIEND_COLOR,
			BorderSizePixel = 0,
			Parent = card,
		})
		Corner(dot, 2)
		Label(card, key, 13, WHITE, Enum.Font.GothamMedium, UDim2.new(1, -90, 1, 0), UDim2.fromOffset(32, 0))

		local rm = New("TextButton", {
			Size = UDim2.fromOffset(26, 26),
			Position = UDim2.new(1, -38, 0.5, -13),
			BackgroundColor3 = UI.Red,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "×",
			TextColor3 = WHITE,
			TextSize = 18,
			Font = Enum.Font.GothamMedium,
			AutoButtonColor = false,
			Parent = card,
		})
		Corner(rm, 6)
		rm.MouseEnter:Connect(function()
			Tween(rm, 0.15, { BackgroundTransparency = 0 })
		end)
		rm.MouseLeave:Connect(function()
			Tween(rm, 0.2, { BackgroundTransparency = 1 })
		end)
		rm.MouseButton1Click:Connect(function()
			RemoveFriend(key)
			RebuildFriendRows()
		end)
	end
end
RebuildFriendRows()

do
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
		{
			Name = "ConfigGTopkaESP",
			Desc = "Jak ConfigGTopka + ESP: szkielet i wszystkie informacje",
			Data = {
				ESP = {
					Enabled = true,
					Skeleton = true,
					Names = true,
					Distance = true,
					Health = true,
					HPGradient = true,
				},
				Aimbot = {
					Enabled = true,
					ShowFOV = true,
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
		for name, m in pairs(Marks) do
			local on = name == CurrentConfig
			m.Chip.Text = on and "AKTYWNY" or "WCZYTAJ"
			Tween(m.Chip, 0.2, { BackgroundColor3 = on and UI.BlueDark or UI.Off, TextTransparency = on and 0 or 0.35 })
			Tween(m.Square, 0.25, { Size = on and UDim2.fromOffset(8, 8) or UDim2.fromOffset(0, 0) }, on and Enum.EasingStyle.Back or Enum.EasingStyle.Quad)
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
		for cat, t in pairs(DefaultSettings) do
			local dst = Settings[cat]
			for k, v in pairs(t) do
				dst[k] = v
			end
		end
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
		local card = Card(PageConfig, 54, true)
		local sq = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 18, 0.5, 0),
			Size = UDim2.fromOffset(0, 0),
			BackgroundColor3 = UI.Blue,
			BorderSizePixel = 0,
			Parent = card,
		})
		Corner(sq, 2)
		Label(card, c.Name, 13, WHITE, Enum.Font.GothamBold, UDim2.new(1, -140, 0, 20), UDim2.fromOffset(34, 8))
		local desc = Label(card, c.Desc, 11, WHITE, Enum.Font.GothamMedium, UDim2.new(1, -140, 0, 16), UDim2.fromOffset(34, 29))
		desc.TextTransparency = 0.45
		local chip = New("TextLabel", {
			Size = UDim2.fromOffset(88, 24),
			Position = UDim2.new(1, -102, 0.5, -12),
			BackgroundColor3 = UI.Off,
			BorderSizePixel = 0,
			TextSize = 11,
			TextColor3 = WHITE,
			Font = Enum.Font.GothamBold,
			Text = "",
			Parent = card,
		})
		Corner(chip, 6)
		Marks[c.Name] = { Chip = chip, Square = sq }
		card.MouseButton1Click:Connect(function()
			ApplyConfig(c.Name)
		end)
	end
	RefreshMarks()

	CreateSection(PageConfig, "Informacje")
	CreateInfo(PageConfig, "Wczytanie configu resetuje opcje ESP, Aimbot, Visual i Movement do domyślnych, a potem ustawia wartości wybranej konfiguracji. Lista Friendz zostaje bez zmian.", 76)
end

CreateSection(PageSet, "Wygląd")
CreateColorRow(PageSet, "Kolor ESP")
do
	local card = Card(PageSet, 150, false)
	Label(card, "Własny kolor RGB", 13, WHITE, Enum.Font.GothamMedium, UDim2.new(1, -90, 0, 22), UDim2.fromOffset(14, 8))
	local preview = New("Frame", {
		Size = UDim2.fromOffset(40, 20),
		Position = UDim2.new(1, -54, 0, 9),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = card,
	})
	Corner(preview, 6)
	Stroke(preview, UI.Line, 1, 0)

	local chans = {
		{ "R", Color3.fromRGB(248, 113, 113) },
		{ "G", Color3.fromRGB(74, 222, 128) },
		{ "B", Color3.fromRGB(96, 165, 250) },
	}
	local vals = { 0, 0, 0 }
	local renders = {}

	for i, ch in ipairs(chans) do
		local y = 38 + (i - 1) * 36
		Label(card, ch[1], 12, WHITE, Enum.Font.GothamBold, UDim2.fromOffset(16, 22), UDim2.fromOffset(14, y))
		local valLbl = Label(card, "0", 12, ch[2], Enum.Font.GothamBold, UDim2.fromOffset(34, 22), UDim2.new(1, -48, 0, y), Enum.TextXAlignment.Right)
		local track = New("Frame", {
			Size = UDim2.new(1, -110, 0, 4),
			Position = UDim2.fromOffset(36, y + 9),
			BackgroundColor3 = UI.Off,
			BorderSizePixel = 0,
			Parent = card,
		})
		Corner(track, UDim.new(1, 0))
		local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = ch[2], BorderSizePixel = 0, Parent = track })
		Corner(fill, UDim.new(1, 0))
		local knob = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(12, 12),
			Position = UDim2.fromScale(0, 0.5),
			BackgroundColor3 = ch[2],
			BorderSizePixel = 0,
			Parent = track,
		})
		Corner(knob, UDim.new(1, 0))
		Stroke(knob, UI.Card, 2, 0)

		renders[i] = function()
			local rel = vals[i] / 255
			fill.Size = UDim2.fromScale(rel, 1)
			knob.Position = UDim2.fromScale(rel, 0.5)
			valLbl.Text = tostring(vals[i])
		end

		local function setFromX(x)
			local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
			vals[i] = math.floor(rel * 255 + 0.5)
			SetAccent(Color3.fromRGB(vals[1], vals[2], vals[3]))
		end

		local hit = New("TextButton", {
			Size = UDim2.new(1, -100, 0, 26),
			Position = UDim2.fromOffset(31, y - 1),
			BackgroundTransparency = 1,
			Text = "",
			Parent = card,
		})
		local drag = false
		hit.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				drag = true
				setFromX(input.Position.X)
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if drag and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
				drag = false
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				setFromX(input.Position.X)
			end
		end)
	end

	BindAccent(function()
		local c = Theme.Accent
		vals[1] = math.floor(c.R * 255 + 0.5)
		vals[2] = math.floor(c.G * 255 + 0.5)
		vals[3] = math.floor(c.B * 255 + 0.5)
		for i = 1, 3 do
			renders[i]()
		end
		preview.BackgroundColor3 = c
	end)
end
CreateSection(PageSet, "Szybkie akcje")
CreateButton(PageSet, "Włącz pełne ESP", UI.BlueDark, function()
	local e = Settings.ESP
	e.Enabled, e.Boxes, e.Names, e.Distance, e.Health, e.Tracers, e.Skeleton = true, true, true, true, true, true, true
	for _, r in ipairs(Refreshers) do
		r()
	end
end)
CreateButton(PageSet, "Wyłącz wszystko (Panic)", UI.Red, function()
	Settings.ESP.Enabled = false
	Settings.Aimbot.Enabled = false
	Settings.Aimbot.SilentAim = false
	Settings.Aimbot.HeadExpand = false
	Settings.Visual.Rainbow = false
	Settings.Visual.AlienFit = false
	Settings.Movement.Fly = false
	Settings.Movement.SpeedEnabled = false
	Settings.Movement.JumpEnabled = false
	Settings.Movement.InfJump = false
	Settings.Movement.Noclip = false
	for _, r in ipairs(Refreshers) do
		r()
	end
end)
CreateSection(PageSet, "Informacje")
CreateInfo(PageSet, "Menu: RightShift (ukryj / pokaż)\nAimbot: przytrzymaj prawy przycisk myszy\nOkno można przeciągać za nagłówek.\nPolish Mafia " .. Version, 84)

SelectTab("ESP", true)

local MenuOpen = false
local Loading = true
local MenuToken = 0
local MenuTweens = {}

local function SetMenu(open)
	if Loading or open == MenuOpen then
		return
	end
	MenuOpen = open
	MenuToken = MenuToken + 1
	local token = MenuToken
	for _, tw in ipairs(MenuTweens) do
		tw:Cancel()
	end
	table.clear(MenuTweens)

	if open then
		Root.Visible = true
		Main.GroupTransparency = 1
		Main.Position = UDim2.fromOffset(0, 12)
		MenuTweens[1] = Tween(Main, 0.28, { GroupTransparency = 0, Position = UDim2.new() }, Enum.EasingStyle.Quart)
	else
		local tw = Tween(Main, 0.2, { GroupTransparency = 1, Position = UDim2.fromOffset(0, 10) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		MenuTweens[1] = tw
		tw.Completed:Connect(function()
			if MenuToken == token and not MenuOpen then
				Root.Visible = false
			end
		end)
	end
end

CloseBtn.MouseButton1Click:Connect(function()
	SetMenu(false)
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if not gp and input.KeyCode == Enum.KeyCode.RightShift then
		SetMenu(not MenuOpen)
	end
end)

local DragTarget = Vector2.new(0, 0)
local DragCurrent = Vector2.new(0, 0)
local dragging = false
local dragStart = Vector2.new(0, 0)
local dragOrigin = Vector2.new(0, 0)

local function ClampOffset(v)
	local vp = MenuGui.AbsoluteSize
	local mx = math.max(0, (vp.X - W) / 2)
	local my = math.max(0, (vp.Y - H) / 2)
	return Vector2.new(math.clamp(v.X, -mx, mx), math.clamp(v.Y, -my, my))
end

DragBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = Vector2.new(input.Position.X, input.Position.Y)
		dragOrigin = DragTarget
		MainStrokeGradient.Enabled = false
		Tween(MainStroke, 0.15, { Color = UI.Blue })
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local d = Vector2.new(input.Position.X, input.Position.Y) - dragStart
		DragTarget = ClampOffset(dragOrigin + d)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		dragging = false
		local tw = Tween(MainStroke, 0.25, { Color = UI.Line })
		tw.Completed:Connect(function()
			MainStrokeGradient.Enabled = true
		end)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if not MenuOpen then
		return
	end
	DragTarget = ClampOffset(DragTarget)
	local diff = DragTarget - DragCurrent
	if diff.Magnitude > 0.05 then
		local alpha = 1 - math.exp(-20 * dt)
		DragCurrent = DragCurrent + diff * alpha
		Root.Position = UDim2.new(0.5, DragCurrent.X, 0.5, DragCurrent.Y)
	elseif diff.Magnitude > 0 then
		DragCurrent = DragTarget
		Root.Position = UDim2.new(0.5, DragCurrent.X, 0.5, DragCurrent.Y)
	end
end)

task.spawn(function()
	local box = New("Frame", {
		Name = "Loader",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(240, 240),
		BackgroundColor3 = UI.Bg,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = MenuGui,
	})
	Corner(box, 10)
	local boxStroke = Stroke(box, UI.Line, 1, 1)

	local title = New("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -62),
		Size = UDim2.fromOffset(220, 30),
		BackgroundTransparency = 1,
		Text = "Polish Mafia",
		TextSize = 22,
		TextColor3 = WHITE,
		TextTransparency = 1,
		Font = Enum.Font.GothamBold,
		Parent = box,
	})

	local safeVersion = string.gsub(VersionLabel(), "[&<>]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" })
	local verLabel = New("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 62),
		Size = UDim2.fromOffset(220, 20),
		BackgroundTransparency = 1,
		RichText = true,
		Text = "Wersja: <font color=\"" .. ToHex(VersionColor()) .. "\">" .. safeVersion .. "</font>",
		TextSize = 17,
		TextColor3 = WHITE,
		TextTransparency = 1,
		Font = Enum.Font.GothamBold,
		Parent = box,
	})

	local row = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(4 * 40 + 3 * 12, 40),
		BackgroundTransparency = 1,
		Parent = box,
	})
	do
		local l = Instance.new("UIListLayout")
		l.FillDirection = Enum.FillDirection.Horizontal
		l.Padding = UDim.new(0, 12)
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Parent = row
	end

	local cellStrokes, stars = {}, {}
	for i = 1, 4 do
		local cell = New("Frame", {
			Size = UDim2.fromOffset(40, 40),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = row,
		})
		Corner(cell, 6)
		cellStrokes[i] = Stroke(cell, WHITE, 2, 1)
		stars[i] = New("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 7),
			Size = UDim2.fromOffset(40, 40),
			BackgroundTransparency = 1,
			Text = "*",
			TextSize = 20,
			TextColor3 = WHITE,
			TextTransparency = 1,
			Font = Enum.Font.GothamBold,
			Parent = cell,
		})
	end

	Tween(box, 0.45, { BackgroundTransparency = 0 })
	Tween(boxStroke, 0.45, { Transparency = 0 })
	task.wait(0.3)
	Tween(title, 0.45, { TextTransparency = 0 })
	Tween(verLabel, 0.45, { TextTransparency = 0 })
	for i = 1, 4 do
		Tween(cellStrokes[i], 0.35, { Transparency = 0 })
		task.wait(0.09)
	end
	task.wait(0.55)

	for i = 1, 4 do
		stars[i].TextSize = 20
		Tween(stars[i], 0.18, { TextTransparency = 0 })
		Tween(stars[i], 0.3, { TextSize = 38 }, Enum.EasingStyle.Back)
		task.wait(0.42)
	end
	task.wait(0.2)

	for _ = 1, 3 do
		for i = 1, 4 do
			Tween(stars[i], 0.32, { TextTransparency = 0.78 }, Enum.EasingStyle.Sine)
		end
		task.wait(0.34)
		for i = 1, 4 do
			Tween(stars[i], 0.32, { TextTransparency = 0 }, Enum.EasingStyle.Sine)
		end
		task.wait(0.34)
	end

	Tween(title, 0.25, { TextTransparency = 1 })
	Tween(verLabel, 0.25, { TextTransparency = 1 })
	for i = 1, 4 do
		Tween(stars[i], 0.25, { TextTransparency = 1 })
		Tween(cellStrokes[i], 0.3, { Transparency = 1 })
	end
	task.wait(0.2)
	local grow = Tween(box, 0.6, { Size = UDim2.fromOffset(W, H) }, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
	grow.Completed:Wait()

	Main.GroupTransparency = 0
	Main.Position = UDim2.new()
	Root.Visible = true
	MenuOpen = true
	Loading = false
	box:Destroy()
end)

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

local AIM_GREEN = Color3.fromRGB(74, 222, 128)
local AIM_GREY = Color3.fromRGB(80, 80, 92)
local LastAimStatus = nil

local function SetAimStatus(text, color)
	if LastAimStatus == text then
		return
	end
	LastAimStatus = text
	if AimStatusLabel then
		AimStatusLabel.Text = text
	end
	if AimStatusDot then
		Tween(AimStatusDot, 0.15, { BackgroundColor3 = color or AIM_GREY })
	end
end

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

-- punkty wokol czesci ciala uzywane przez MultiRay (gorny/dolny/lewy/prawy brzeg + srodek)
local VIS_OFFSETS = {
	Vector3.new(0, 0, 0),
	Vector3.new(0, 0.4, 0),
	Vector3.new(0, -0.4, 0),
	Vector3.new(0.4, 0, 0),
	Vector3.new(-0.4, 0, 0),
}

local function IsVisible(cam, part)
	local cfg = Settings.Aimbot
	if not cfg.WallCheck then
		return true
	end
	local char = LocalPlayer.Character
	AimRayParams.FilterDescendantsInstances = char and { char, cam, part.Parent } or { cam, part.Parent }
	local origin = cam.CFrame.Position
	local size = part.Size

	if not cfg.MultiRay then
		return Workspace:Raycast(origin, part.Position - origin, AimRayParams) == nil
	end

	-- kilka promieni rozlozonych po hitboxie: cel jest widoczny jesli chociaz jeden trafia bez przeszkody
	for i = 1, #VIS_OFFSETS do
		local off = VIS_OFFSETS[i]
		local target = part.Position + Vector3.new(off.X * size.X, off.Y * size.Y, off.Z * size.Z)
		if Workspace:Raycast(origin, target - origin, AimRayParams) == nil then
			return true
		end
	end
	return false
end

local function GetAimPart(e)
	if Settings.Aimbot.TargetPart == "Head" then
		return GetHead(e) or GetTorso(e) or GetRoot(e)
	end
	return GetTorso(e) or GetRoot(e) or GetHead(e)
end

local function AimAllowed(e)
	local cfg = Settings.Aimbot
	if cfg.PlayersOnly and not e.Player then
		return false
	end
	if cfg.IgnoreDummy and e.IsDummy then
		return false
	end
	if IsFriend(e) then
		return false
	end
	if cfg.TeamCheck and e.Player and LocalPlayer.Team ~= nil and e.Player.Team == LocalPlayer.Team then
		return false
	end
	return true
end

local AccelCache = setmetatable({}, { __mode = "k" }) -- [part] = {Vel, Time}

-- Predykcja: do predkosci liniowej celu dolicza krotki wklad przyspieszenia (zmiana predkosci
-- w ostatniej klatce), co lepiej lapie gwaltowne skrety / strafe niz sam liniowy wektor.
local function AimPos(part, camPos)
	local cfg = Settings.Aimbot
	local p = part.Position
	if not cfg.Prediction then
		return p
	end

	local vel = part.AssemblyLinearVelocity
	local t = cfg.PredictTime

	if cfg.AutoPredict then
		-- dluzszy dystans = dluzszy czas lotu / reakcji, lekko skalowane
		local dist = camPos and (p - camPos).Magnitude or 0
		t = math.clamp(cfg.PredictTime + dist * 0.00035, 0.02, 0.5)
	end

	local now = os.clock()
	local c = AccelCache[part]
	local accel = Vector3.zero
	if c and now - c.Time > 0 and now - c.Time < 0.25 then
		accel = (vel - c.Vel) / (now - c.Time)
	end
	AccelCache[part] = { Vel = vel, Time = now }

	return p + vel * t + 0.5 * accel * t * t
end

local VisLostAt = nil

local function StickyValid(cam, ref)
	local cfg = Settings.Aimbot
	local e, part = AimEntry, AimPart
	if not (e and part and part.Parent and e.Model.Parent) then
		return false
	end
	if e.Humanoid.Health <= 0 or not AimAllowed(e) then
		return false
	end
	if part ~= GetAimPart(e) then
		return false
	end
	if (part.Position - cam.CFrame.Position).Magnitude > cfg.MaxDistance then
		return false
	end
	local sp, on = cam:WorldToViewportPoint(part.Position)
	if not on or (Vector2.new(sp.X, sp.Y) - ref).Magnitude > cfg.FOV * cfg.StickyTolerance then
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

-- Wybor celu: lacznie bierze pod uwage odleglosc na ekranie / w swiecie (wg Priorytetu)
-- oraz lekki bonus "histerezy" dla celu juz zablokowanego, zeby aimbot nie skakal
-- miedzy dwoma blisko stojacymi graczami co klatke.
local function FindTarget(cam, targets, ref)
	local cfg = Settings.Aimbot
	local bestE, bestPart
	local bestScore = math.huge
	local camPos = cam.CFrame.Position
	local maxD2 = cfg.MaxDistance * cfg.MaxDistance
	local byDistance = cfg.Priority == "Distance"
	local curModel = AimEntry and AimEntry.Model

	for _, e in ipairs(targets) do
		if AimAllowed(e) then
			local part = GetAimPart(e)
			if part then
				local pos = part.Position
				local off = pos - camPos
				local d2 = off:Dot(off)
				if d2 <= maxD2 then
					local sp, on = cam:WorldToViewportPoint(pos)
					if on then
						local d = (Vector2.new(sp.X, sp.Y) - ref).Magnitude
						if d <= cfg.FOV then
							local score = byDistance and d2 or d
							if e.Model == curModel then
								score = score * 0.8
							end
							if score < bestScore and IsVisible(cam, part) then
								bestScore = score
								bestE, bestPart = e, part
							end
						end
					end
				end
			end
		end
	end
	return bestE, bestPart
end

-- Aimbot: tryb Snap = natychmiastowe przyklejenie kamery do celu (glowa),
-- tryb Smooth = plynny obrot z limitem predkosci.
local function AimAt(cam, part, ref, dt)
	local cfg = Settings.Aimbot
	local vp = cam.ViewportSize
	local aimPos = AimPos(part, cam.CFrame.Position)
	local sp = cam:WorldToViewportPoint(aimPos)
	if sp.Z <= 0 then
		return
	end

	local cx, cy = vp.X / 2, vp.Y / 2
	local snap = cfg.AimMode ~= "Smooth"

	-- Snap + celownik na srodku ekranu: kamera patrzy dokladnie w glowe
	if snap and math.abs(ref.X - cx) < 2 and math.abs(ref.Y - cy) < 2 then
		local pos = cam.CFrame.Position
		if (aimPos - pos).Magnitude > 0.01 then
			local rx, ry = CFrame.lookAt(pos, aimPos):ToOrientation()
			rx = math.clamp(rx, -MAX_PITCH, MAX_PITCH)
			cam.CFrame = CFrame.new(pos) * CFrame.fromOrientation(rx, ry, 0)
		end
		return
	end

	local dxPx = sp.X - ref.X
	local dyPx = sp.Y - ref.Y
	if math.abs(dxPx) < DEADZONE_PX and math.abs(dyPx) < DEADZONE_PX then
		return
	end

	local focal = GetFocal(cam)

	local dYaw = math.atan((sp.X - cx) / focal) - math.atan((ref.X - cx) / focal)
	local dPitch = math.atan((sp.Y - cy) / focal) - math.atan((ref.Y - cy) / focal)

	local sYaw, sPitch
	if snap then
		-- pelna korekta w jednej klatce (kursor / celownik laduje na glowie)
		sYaw, sPitch = dYaw, dPitch
	else
		local k = 120 / math.max(cfg.Smoothness, 1)
		local alpha = math.clamp(1 - math.exp(-k * dt), 0.01, 1)
		sYaw, sPitch = dYaw * alpha, dPitch * alpha
		local maxStep = math.rad(cfg.MaxSpeed) * dt
		local mag = math.sqrt(sYaw * sYaw + sPitch * sPitch)
		if mag > maxStep and mag > 0 then
			local k2 = maxStep / mag
			sYaw, sPitch = sYaw * k2, sPitch * k2
		end
	end

	local rx, ry = cam.CFrame:ToOrientation()
	rx = math.clamp(rx - sPitch, -MAX_PITCH, MAX_PITCH)
	ry = ry - sYaw

	cam.CFrame = CFrame.new(cam.CFrame.Position) * CFrame.fromOrientation(rx, ry, 0)
end

-- SILENT AIM: kamera sie nie rusza. Gra dostaje podmienione Mouse.Hit / Mouse.Target /
-- Mouse.UnitRay oraz podmienione promienie (Raycast, FindPartOnRay*, Screen/ViewportPointToRay),
-- tak jakby celownik byl na glowie najblizszego celu w FOV.
-- Wymaga executora z hookmetamethod + checkcaller + getnamecallmethod.
local UpdateSilent
do
	local Silent = {
		Part = nil,
		Pos = nil,
		Cam = nil,
		CamPos = Vector3.zero,
		Look = Vector3.zAxis,
		HeadPos = nil,
		Ready = false,
		Tried = false,
		Err = nil,
		LastStatus = nil,
	}
	local GREEN = Color3.fromRGB(74, 222, 128)
	local RED = Color3.fromRGB(248, 113, 113)

	local function SetStatus(text, color)
		if Silent.LastStatus == text then
			return
		end
		Silent.LastStatus = text
		if SilentStatusLabel then
			SilentStatusLabel.Text = text
			SilentStatusLabel.TextColor3 = color or WHITE
		end
	end

	local function Roll()
		local c = Settings.Aimbot.SilentChance
		return c >= 100 or math.random(1, 100) <= c
	end

	-- tylko "strzalowe" promienie: dlugie, startujace przy kamerze / glowie i lecace mniej wiecej tam, gdzie patrzysz
	-- (krotkie promienie gry, kamery, podlogi itp. zostaja nietkniete)
	local function RayOk(origin, dir)
		local mag = dir.Magnitude
		if mag < 80 then
			return false
		end
		if (origin - Silent.CamPos).Magnitude > 15 then
			local hp = Silent.HeadPos
			if not (hp and (origin - hp).Magnitude <= 15) then
				return false
			end
		end
		return (dir / mag):Dot(Silent.Look) > 0.64
	end

	local function Install()
		Silent.Tried = true
		local HM, NC, CC, GNM, SNM = hookmetamethod, newcclosure, checkcaller, getnamecallmethod, setnamecallmethod
		if not (HM and CC and GNM) then
			Silent.Err = "Silent Aim: niedostępny (executor nie ma hookmetamethod)"
			return
		end
		local wrap = NC or function(f)
			return f
		end
		local mouse = LocalPlayer:GetMouse()

		local ok, err = pcall(function()
			local oldIndex
			oldIndex = HM(game, "__index", wrap(function(self, key)
				if self == mouse and Silent.Pos and Settings.Aimbot.SilentAim and not CC() and Roll() then
					if key == "Hit" then
						return CFrame.new(Silent.Pos)
					elseif key == "Target" then
						return Silent.Part
					elseif key == "UnitRay" then
						return Ray.new(Silent.CamPos, (Silent.Pos - Silent.CamPos).Unit)
					end
				end
				return oldIndex(self, key)
			end))

			local oldNamecall
			oldNamecall = HM(game, "__namecall", wrap(function(self, ...)
				local method = GNM()
				local pos = Silent.Pos
				if pos and Settings.Aimbot.SilentAim and not CC() and Roll() then
					if self == Workspace then
						if method == "Raycast" then
							local origin, dir, params = ...
							if typeof(origin) == "Vector3" and typeof(dir) == "Vector3" and RayOk(origin, dir) then
								if SNM then
									SNM(method)
								end
								return oldNamecall(self, origin, (pos - origin).Unit * dir.Magnitude, params)
							end
						elseif method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" then
							local ray, a2, a3, a4 = ...
							if typeof(ray) == "Ray" and RayOk(ray.Origin, ray.Direction) then
								local nr = Ray.new(ray.Origin, (pos - ray.Origin).Unit * ray.Direction.Magnitude)
								if SNM then
									SNM(method)
								end
								return oldNamecall(self, nr, a2, a3, a4)
							end
						end
					elseif self == Silent.Cam and (method == "ScreenPointToRay" or method == "ViewportPointToRay") then
						if SNM then
							SNM(method)
						end
						local ray = oldNamecall(self, ...)
						return Ray.new(ray.Origin, (pos - ray.Origin).Unit)
					end
				end
				if SNM then
					SNM(method)
				end
				return oldNamecall(self, ...)
			end))
		end)

		if ok then
			Silent.Ready = true
		else
			Silent.Err = "Silent Aim: błąd hooków (" .. tostring(err) .. ")"
		end
	end

	UpdateSilent = function(cam, targets, ref)
		local cfg = Settings.Aimbot
		if not cfg.SilentAim then
			Silent.Part, Silent.Pos = nil, nil
			SetStatus("Silent Aim: wyłączony", WHITE)
			return
		end
		if not Silent.Tried then
			Install()
		end
		if not Silent.Ready then
			Silent.Part, Silent.Pos = nil, nil
			SetStatus(Silent.Err or "Silent Aim: niedostępny", RED)
			return
		end

		local cf = cam.CFrame
		Silent.Cam, Silent.CamPos, Silent.Look = cam, cf.Position, cf.LookVector
		local char = LocalPlayer.Character
		local head = char and char:FindFirstChild("Head")
		Silent.HeadPos = head and head.Position or nil

		local e, part = FindTarget(cam, targets, ref)
		if part then
			Silent.Part, Silent.Pos = part, AimPos(part, Silent.CamPos)
			SetStatus("Silent Aim: cel – " .. (e.Player and e.Player.Name or e.Model.Name), GREEN)
		else
			Silent.Part, Silent.Pos = nil, nil
			SetStatus("Silent Aim: aktywny, brak celu w FOV", WHITE)
		end
	end
end

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

local HeadsDirty = false

local function ProcessHeads(targets)
	local cfg = Settings.Aimbot
	if not cfg.HeadExpand and not HeadsDirty then
		return
	end
	local scale = math.max(cfg.HeadSize, 1)
	local any = false
	for _, e in ipairs(targets) do
		if cfg.HeadExpand and AimAllowed(e) then
			ApplyHead(e, scale)
			any = true
		elseif e.HeadPart then
			RestoreHead(e)
		end
	end
	HeadsDirty = any
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

	-- Silent Aim (niezalezny od Aimbota: dziala bez przytrzymywania PPM)
	UpdateSilent(cam, targets, ref)

	local showFov = cfg.ShowFOV and (cfg.Enabled or cfg.SilentAim)
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

	if not cfg.Enabled then
		SetAimStatus("Aimbot: wyłączony", AIM_GREY)
	elseif not IsHoldingAimKey then
		SetAimStatus("Aimbot: gotowy (przytrzymaj PPM)", UI.Blue)
	elseif locked then
		local nm = AimEntry and (AimEntry.Player and AimEntry.Player.Name or AimEntry.Model.Name) or "?"
		SetAimStatus("Aimbot: cel – " .. nm, AIM_GREEN)
	else
		SetAimStatus("Aimbot: szukam celu w FOV...", UI.Blue)
	end
end

local Move = {
	Flying = false,
	Vel = Vector3.zero,
	Body = nil,
	Hum = nil,
	PlatformSet = false,
}
local MoveOrig = setmetatable({}, { __mode = "k" })
local NoclipSet = {}

local function GetCharParts()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return char, hum, hrp
end

local function GetSeat(hum, hrp)
	local s = hum.SeatPart
	if s then
		return s
	end
	if hum.Sit then
		for _, j in ipairs(hrp:GetJoints()) do
			if j:IsA("JointInstance") then
				local other = (j.Part0 == hrp) and j.Part1 or j.Part0
				if other and (other:IsA("Seat") or other:IsA("VehicleSeat")) then
					return other
				end
			end
		end
	end
	return nil
end

local function StopFly()
	if not Move.Flying then
		return
	end
	Move.Flying = false
	local hum, body = Move.Hum, Move.Body
	if Move.PlatformSet and hum and hum.Parent then
		hum.PlatformStand = false
		pcall(function()
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end)
	end
	Move.PlatformSet = false
	if body and body.Parent and not body.Anchored then
		body.AssemblyLinearVelocity = Vector3.zero
		body.AssemblyAngularVelocity = Vector3.zero
	end
	Move.Vel = Vector3.zero
	Move.Body, Move.Hum = nil, nil
end

local function UpdateFly(dt, cam)
	local m = Settings.Movement
	local char, hum, hrp = GetCharParts()
	if not (m.Fly and char and hum and hrp and hum.Health > 0) then
		StopFly()
		return
	end

	local seat = GetSeat(hum, hrp)
	local body = hrp
	if seat then
		body = seat.AssemblyRootPart or seat
	end
	if body.Anchored then
		return
	end

	if Move.Body ~= body then
		Move.Vel = body.AssemblyLinearVelocity
		Move.Body = body
	end
	Move.Hum = hum
	Move.Flying = true

	if seat then
		if Move.PlatformSet then
			hum.PlatformStand = false
			Move.PlatformSet = false
		end
	else
		if not hum.PlatformStand then
			hum.PlatformStand = true
			Move.PlatformSet = true
		end
	end

	local d = Vector3.zero
	if not UserInputService:GetFocusedTextBox() then
		local look, right = cam.CFrame.LookVector, cam.CFrame.RightVector
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then d = d + look end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then d = d - look end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then d = d + right end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then d = d - right end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then d = d + Vector3.yAxis end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then
			d = d - Vector3.yAxis
		end
	end
	if d.Magnitude > 0 then
		d = d.Unit
	end

	Move.Vel = Move.Vel:Lerp(d * m.FlySpeed, 1 - math.exp(-10 * dt))

	body.AssemblyLinearVelocity = Move.Vel + Vector3.new(0, Workspace.Gravity * dt, 0)
	body.AssemblyAngularVelocity = Vector3.zero

	if seat and m.FlyFaceCamera and d.Magnitude > 0 then
		local cl = cam.CFrame.LookVector
		local flat = Vector3.new(cl.X, 0, cl.Z)
		if flat.Magnitude > 0.05 then
			local sc = seat.CFrame
			local want = CFrame.lookAt(sc.Position, sc.Position + flat)
			local newSeat = sc:Lerp(want, 1 - math.exp(-6 * dt))
			body.CFrame = newSeat * sc:ToObjectSpace(body.CFrame)
		end
	end

	if not seat then
		local look = cam.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			local p = hrp.Position
			hrp.CFrame = CFrame.lookAt(p, p + flat)
		end
	end
end

local function ApplyStats(hum, m)
	local o = MoveOrig[hum]
	if not o then
		o = {}
		MoveOrig[hum] = o
	end
	if m.SpeedEnabled then
		if o.Walk == nil then
			o.Walk = hum.WalkSpeed
		end
		if hum.WalkSpeed ~= m.WalkSpeed then
			hum.WalkSpeed = m.WalkSpeed
		end
	elseif o.Walk ~= nil then
		hum.WalkSpeed = o.Walk
		o.Walk = nil
	end

	if m.JumpEnabled then
		if o.Jump == nil then
			o.Jump = hum.JumpPower
			o.UseJP = hum.UseJumpPower
		end
		if not hum.UseJumpPower then
			hum.UseJumpPower = true
		end
		if hum.JumpPower ~= m.JumpPower then
			hum.JumpPower = m.JumpPower
		end
	elseif o.Jump ~= nil then
		hum.UseJumpPower = o.UseJP
		hum.JumpPower = o.Jump
		o.Jump = nil
	end
end

local function ProcessMovement(dt)
	local cam = GetCamera()
	local m = Settings.Movement
	if cam then
		UpdateFly(dt, cam)
	end
	local _, hum = GetCharParts()
	if hum then
		ApplyStats(hum, m)
	end
end

local function ProcessNoclip()
	local char = LocalPlayer.Character
	if Settings.Movement.Noclip and char then
		for _, p in ipairs(char:GetChildren()) do
			if p:IsA("BasePart") and p.CanCollide then
				NoclipSet[p] = true
				p.CanCollide = false
			end
		end
	elseif next(NoclipSet) ~= nil then
		for p in pairs(NoclipSet) do
			if p.Parent then
				p.CanCollide = true
			end
			NoclipSet[p] = nil
		end
	end
end

UserInputService.JumpRequest:Connect(function()
	if Settings.Movement.InfJump then
		local _, hum = GetCharParts()
		if hum then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp or Loading then
		return
	end
	if Binding == nil and os.clock() - BindJustSet > 0.25
		and Settings.Movement.FlyKey ~= Enum.KeyCode.Unknown
		and input.KeyCode == Settings.Movement.FlyKey then
		Settings.Movement.Fly = not Settings.Movement.Fly
		for _, r in ipairs(Refreshers) do
			r()
		end
	end
end)

local CollectAlienParts, SetAlienTint
local ProcessVisual
do

	local NEON = Enum.Material.Neon
	local CATS = { "Tesla", "GKlasa", "Humvee", "VintagePistol", "AlienRainbow" }
	local REBUILD = { Tesla = 1, GKlasa = 1, Humvee = 1, VintagePistol = 0.5, AlienRainbow = 0.5 }
	local PAINT_HZ = 15

	local Orig = setmetatable({}, { __mode = "k" })
	local Roots = { Tesla = {}, GKlasa = {}, Humvee = {} }
	local Lists = { Tesla = {}, GKlasa = {}, Humvee = {}, VintagePistol = {}, AlienRainbow = {} }
	local Painted = { Tesla = {}, GKlasa = {}, Humvee = {}, VintagePistol = {}, AlienRainbow = {} }
	local Built = { Tesla = 0, GKlasa = 0, Humvee = 0, VintagePistol = 0, AlienRainbow = 0 }
	local AddConn, RemConn = nil, nil
	local ScanId = 0
	local lastPaint = 0

	local function Classify(inst)
		local isPart = inst:IsA("BasePart")
		local isModel = inst:IsA("Model")
		if not (isPart or isModel) then
			return
		end
		local n = inst.Name
		if string.sub(n, 1, 5) == "BODY_" then
			Roots.Tesla[inst] = Roots.Tesla[inst] or {}
		end
		if string.find(n, "__", 1, true) then
			Roots.GKlasa[inst] = Roots.GKlasa[inst] or {}
		end
		if isModel then
			local l = string.lower(n)
			if string.find(l, "humvee", 1, true) or string.find(l, "hummer", 1, true) then
				Roots.Humvee[inst] = Roots.Humvee[inst] or {}
			end
		end
	end

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
		if o.SA and o.SA.Parent == p then
			o.SA.Parent = nil
		end
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
				if not parts or now - (info.Built or 0) > 4 then
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

	local function AddParts(root, out, seen)
		if root:IsA("BasePart") and not seen[root] then
			seen[root] = true
			out[#out + 1] = root
		end
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BasePart") and not seen[d] then
				seen[d] = true
				out[#out + 1] = d
			end
		end
	end

	local function CollectPistol(out)
		local seen = {}
		local function scan(root)
			if not root then
				return
			end
			if root.Name == "PistoletTP" then
				AddParts(root, out, seen)
			end
			for _, d in ipairs(root:GetDescendants()) do
				if d.Name == "PistoletTP" then
					AddParts(d, out, seen)
				end
			end
		end
		scan(LocalPlayer.Character)
		scan(LocalPlayer:FindFirstChild("Backpack"))
	end

	local function ClearCat(cat)
		local painted = Painted[cat]
		for p in pairs(painted) do
			Restore(p)
			painted[p] = nil
		end
		table.clear(Lists[cat])
		Built[cat] = 0
		if cat == "AlienRainbow" and SetAlienTint then
			SetAlienTint(nil)
		end
	end

	local function Enable()
		ScanId = ScanId + 1
		local id = ScanId
		AddConn = Workspace.DescendantAdded:Connect(Classify)
		RemConn = Workspace.DescendantRemoving:Connect(function(inst)
			Roots.Tesla[inst] = nil
			Roots.GKlasa[inst] = nil
			Roots.Humvee[inst] = nil
		end)

		task.spawn(function()
			local n = 0
			for _, d in ipairs(Workspace:GetDescendants()) do
				if ScanId ~= id then
					return
				end
				Classify(d)
				n = n + 1
				if n % 1500 == 0 then
					task.wait()
				end
			end
		end)
	end

	local function Disable()
		ScanId = ScanId + 1
		if AddConn then
			AddConn:Disconnect()
			AddConn = nil
		end
		if RemConn then
			RemConn:Disconnect()
			RemConn = nil
		end
		for _, cat in ipairs(CATS) do
			ClearCat(cat)
		end
		for _, r in pairs(Roots) do
			table.clear(r)
		end
	end

	local function Rebuild(cat, now, color)
		Built[cat] = now
		local list = Lists[cat]
		table.clear(list)
		if cat == "VintagePistol" then
			CollectPistol(list)
		elseif cat == "AlienRainbow" then
			if CollectAlienParts then
				CollectAlienParts(list)
			end
		else
			Collect(cat, now, list)
		end
		local painted = Painted[cat]
		local keep = {}
		for i = 1, #list do
			local p = list[i]
			keep[p] = true
			painted[p] = true
			Paint(p, color)
		end
		for p in pairs(painted) do
			if not keep[p] then
				Restore(p)
				painted[p] = nil
			end
		end
	end

	ProcessVisual = function(dt)
		local v = Settings.Visual
		if not v.Rainbow then
			if AddConn then
				Disable()
			end
			return
		end
		if not AddConn then
			Enable()
		end

		local now = os.clock()
		if now - lastPaint < 1 / PAINT_HZ then
			return
		end
		lastPaint = now
		local color = Color3.fromHSV((now * 0.25 * v.RainbowSpeed) % 1, 1, 1)

		for _, cat in ipairs(CATS) do
			if v[cat] then
				if now - Built[cat] >= REBUILD[cat] then
					Rebuild(cat, now, color)
				else

					local list = Lists[cat]
					for i = 1, #list do
						local p = list[i]
						if p.Parent then
							p.Color = color
						end
					end
				end
				if cat == "AlienRainbow" and SetAlienTint then
					SetAlienTint(color)
				end
			elseif next(Painted[cat]) ~= nil then
				ClearCat(cat)
			end
		end
	end
end

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
local POOL_LIMIT = 40

local ESPObjects = {}
local ESPPool = {}
local ESPSeen = {}

local PropCache = setmetatable({}, { __mode = "k" })
local RectCache = setmetatable({}, { __mode = "k" })
local PosCache = setmetatable({}, { __mode = "k" })

local function SP(inst, prop, val)
	local t = PropCache[inst]
	if not t then
		t = {}
		PropCache[inst] = t
	end
	if t[prop] ~= val then
		t[prop] = val
		inst[prop] = val
	end
end

local function SetRect(f, x, y, w, h)
	local c = RectCache[f]
	if c then
		if c[1] == x and c[2] == y and c[3] == w and c[4] == h then
			return
		end
	else
		c = {}
		RectCache[f] = c
	end
	c[1], c[2], c[3], c[4] = x, y, w, h
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
end

local function SetPos(f, x, y)
	local c = PosCache[f]
	if c then
		if c[1] == x and c[2] == y then
			return
		end
	else
		c = {}
		PosCache[f] = c
	end
	c[1], c[2] = x, y
	f.Position = UDim2.fromOffset(x, y)
end

local function MakeLine(parent)
	return New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderSizePixel = 0,
		Visible = false,
		Parent = parent,
	})
end

local function SetLine(l, ax, ay, bx, by, color, thickness)
	local dx, dy = bx - ax, by - ay
	l.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), thickness)
	l.Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2)
	l.Rotation = math.deg(math.atan2(dy, dx))
	SP(l, "BackgroundColor3", color)
	Vis(l, true)
end

local function CreateESPObject()
	local o = { BoneList = {}, Bones = {}, Proj = {}, BoneBuilt = 0 }
	local h = New("Frame", {
		Name = "ESP",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = ESPGui,
	})
	o.Holder = h

	o.BoxOutline = New("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, Parent = h })
	Stroke(o.BoxOutline, BLACK, 3, 0.3)

	o.Box = New("Frame", { BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, Parent = h })
	o.BoxStroke = Stroke(o.Box, Theme.Accent, 1.6, 0)

	o.CBack, o.CFront = {}, {}
	for i = 1, 8 do
		o.CBack[i] = New("Frame", { BackgroundColor3 = BLACK, BackgroundTransparency = 0.25, BorderSizePixel = 0, Visible = false, Parent = h })
	end
	for i = 1, 8 do
		o.CFront[i] = New("Frame", { BorderSizePixel = 0, Visible = false, Parent = h })
	end

	o.HPBg = New("Frame", { BackgroundColor3 = Color3.fromRGB(12, 12, 16), BackgroundTransparency = 0.25, BorderSizePixel = 0, Visible = false, Parent = h })
	o.HPFill = New("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 1, 1, -1), BorderSizePixel = 0, Parent = o.HPBg })
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
		Parent = h,
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
		Parent = h,
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
		Parent = h,
	})

	o.Tracer = MakeLine(h)
	return o
end

local function ResetESPState(o)
	o.HP = nil
	o.HPStep = nil
	o.HPN = nil
	o.DN = nil
	o.BoneModel = nil
	o.Col = nil
	o.CS = nil
	o.CornerDirty = true
	o.bx, o.by, o.bw, o.bh = nil, nil, nil, nil
end

local function AcquireESP()
	local o = table.remove(ESPPool)
	if o then
		ResetESPState(o)
		return o
	end
	o = CreateESPObject()
	ResetESPState(o)
	return o
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

local function ApplyESPColor(o, color, cfg)
	o.Col = color
	for i = 1, 8 do
		SP(o.CFront[i], "BackgroundColor3", color)
	end
	SP(o.Box, "BackgroundColor3", color)
	SP(o.BoxStroke, "Color", color)
	o.HPStep = nil
end

local function UpdateOne(o, e, cam, viewport, dt, camPos, accent, ox, oy)
	local cfg = Settings.ESP
	local model, hum, holder = e.Model, e.Humanoid, o.Holder

	local head, root = GetHead(e), GetRoot(e)
	if not (head and root) then
		Vis(holder, false)
		return
	end
	local hp = head.Position
	if hp.X ~= hp.X or hp.Y ~= hp.Y or hp.Z ~= hp.Z then
		Vis(holder, false)
		return
	end
	local rp = root.Position

	local hs = (e.HeadPart == head and e.OrigSize) or head.Size
	local topV = cam:WorldToViewportPoint(Vector3.new(hp.X, hp.Y + hs.Y * 0.5 + 0.2, hp.Z))
	local botV = cam:WorldToViewportPoint(Vector3.new(rp.X, rp.Y - root.Size.Y * 1.5, rp.Z))
	if topV.Z < 0.3 or botV.Z < 0.3 then
		Vis(holder, false)
		return
	end

	local rawH = botV.Y - topV.Y
	if rawH ~= rawH or rawH < 1 or rawH > viewport.Y * 4 then
		Vis(holder, false)
		return
	end
	local cx = (topV.X + botV.X) / 2
	local y = topV.Y - 2
	local h = rawH + 4
	local w = h * 0.52
	local x = cx - w / 2

	if not cfg.Tracers and (x > viewport.X or x + w < 0 or y > viewport.Y or y + h < 0) then
		Vis(holder, false)
		return
	end

	Vis(holder, true)

	local off = hp - camPos
	local dist = math.sqrt(off:Dot(off))

	local friend = IsFriend(e)
	local color = friend and FRIEND_COLOR or accent
	if o.Col ~= color then
		ApplyESPColor(o, color, cfg)
	end

	local bx, by = math.floor(x + 0.5), math.floor(y + 0.5)
	local bw, bh = math.floor(w + 0.5), math.floor(h + 0.5)
	local moved = o.bx ~= bx or o.by ~= by or o.bw ~= bw or o.bh ~= bh
	if moved then
		o.bx, o.by, o.bw, o.bh = bx, by, bw, bh
	end

	local full = cfg.Boxes and cfg.BoxStyle == "Full"
	local corner = cfg.Boxes and cfg.BoxStyle ~= "Full"
	local fillOn = cfg.Boxes and cfg.Fill and true or false
	local boxVisible = full or fillOn

	Vis(o.Box, boxVisible)
	Vis(o.BoxOutline, (full and cfg.Outline) and true or false)
	if boxVisible then
		SetRect(o.Box, bx, by, bw, bh)
		SetRect(o.BoxOutline, bx, by, bw, bh)
		SP(o.Box, "BackgroundTransparency", fillOn and 0.8 or 1)
		SP(o.BoxStroke, "Enabled", full and true or false)
	end

	local cs = corner and (cfg.Outline and 2 or 1) or 0
	if o.CS ~= cs then
		o.CS = cs
		o.CornerDirty = true
		for i = 1, 8 do
			Vis(o.CFront[i], cs > 0)
			Vis(o.CBack[i], cs == 2)
		end
	end
	if cs > 0 and (moved or o.CornerDirty) then
		o.CornerDirty = false
		local lx, ly, t = math.floor(bw * 0.28), math.floor(bh * 0.2), 2
		local x2, y2 = bx + bw, by + bh
		local F, B = o.CFront, o.CBack
		local rects = {
			{ bx, by, lx, t }, { bx, by, t, ly },
			{ x2 - lx, by, lx, t }, { x2 - t, by, t, ly },
			{ bx, y2 - t, lx, t }, { bx, y2 - ly, t, ly },
			{ x2 - lx, y2 - t, lx, t }, { x2 - t, y2 - ly, t, ly },
		}
		for i = 1, 8 do
			local r = rects[i]
			SetRect(F[i], r[1], r[2], r[3], r[4])
			SetRect(B[i], r[1] - 1, r[2] - 1, r[3] + 2, r[4] + 2)
		end
	end

	if cfg.Health then
		local maxHp = math.max(hum.MaxHealth, 1)
		local target = math.clamp(hum.Health / maxHp, 0, 1)
		o.HP = o.HP or target
		o.HP = o.HP + (target - o.HP) * math.min(1, dt * 10)
		local ratio = o.HP

		SetRect(o.HPBg, bx - 9, by - 1, 5, bh + 2)
		Vis(o.HPBg, true)

		local step = math.floor(ratio * 100 + 0.5) * 2 + (cfg.HPGradient and 1 or 0)
		if o.HPStep ~= step then
			o.HPStep = step
			o.HPFill.Size = UDim2.new(1, -2, ratio, -2 * ratio)
			o.HPFill.BackgroundColor3 = cfg.HPGradient and Color3.fromHSV(ratio * 0.33, 0.85, 1) or color
		end
		local hpn = math.floor(hum.Health + 0.5)
		if o.HPN ~= hpn then
			o.HPN = hpn
			o.HPText.Text = tostring(hpn)
		end
		local lo, hi = by + 6, by + bh - 6
		if hi < lo then
			hi = lo
		end
		local ty = math.min(math.max(by + math.floor(bh * (1 - ratio)), lo), hi)
		SetPos(o.HPText, bx - 12, ty)
		Vis(o.HPText, true)
	else
		Vis(o.HPBg, false)
		Vis(o.HPText, false)
	end

	if cfg.Names then
		SP(o.Name, "Text", e.Player and e.Player.Name or model.Name)
		SP(o.Name, "TextColor3", friend and FRIEND_COLOR or WHITE)
		SetPos(o.Name, math.floor(cx), by - 3)
		Vis(o.Name, true)
	else
		Vis(o.Name, false)
	end

	if cfg.Distance then
		local dn = math.floor(dist + 0.5)
		if o.DN ~= dn then
			o.DN = dn
			o.Dist.Text = "[" .. dn .. " m]"
		end
		SetPos(o.Dist, math.floor(cx), by + bh + 2)
		Vis(o.Dist, true)
	else
		Vis(o.Dist, false)
	end

	if cfg.Tracers then
		SetLine(o.Tracer, ox, oy, cx, y + h, color, 1.5)
	else
		Vis(o.Tracer, false)
	end

	if cfg.Skeleton and dist < 300 then
		if o.BoneModel ~= model or (#o.BoneList < (o.BoneExpected or 0) and os.clock() - o.BoneBuilt > 2) then
			BuildBones(o, e)
		end
		local list = o.BoneList
		for i = #o.Bones + 1, #list do
			o.Bones[i] = MakeLine(holder)
		end
		local proj = o.Proj
		table.clear(proj)
		for i = 1, #o.Bones do
			local line, pair = o.Bones[i], list[i]
			local drawn = false
			if pair then
				local a, b = pair[1], pair[2]
				if a.Parent and b.Parent then
					local pa = proj[a]
					if not pa then
						pa = cam:WorldToViewportPoint(a.Position)
						proj[a] = pa
					end
					local pb = proj[b]
					if not pb then
						pb = cam:WorldToViewportPoint(b.Position)
						proj[b] = pb
					end
					if pa.Z > 0 and pb.Z > 0 then
						SetLine(line, pa.X, pa.Y, pb.X, pb.Y, color, 1.6)
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
		o.SkelOn = true
	elseif o.SkelOn then
		for i = 1, #o.Bones do
			Vis(o.Bones[i], false)
		end
		o.SkelOn = false
	end
end

local ESPErrWarned = {}

local function ProcessESP(dt, cam, players)
	local cfg = Settings.ESP
	table.clear(ESPSeen)

	if cfg.Enabled then
		local viewport = cam.ViewportSize
		local camPos = cam.CFrame.Position
		local maxD2 = cfg.MaxDistance * cfg.MaxDistance

		local accent = Theme.Accent
		if cfg.RainbowColor then
			accent = Color3.fromHSV((math.floor(os.clock() * 20) / 20 * 0.25) % 1, 0.9, 1)
		end

		local ox, oy = viewport.X / 2, viewport.Y
		if cfg.Tracers then
			local mode = cfg.TracerOrigin
			if mode == "Center" then
				ox, oy = viewport.X / 2, viewport.Y / 2
			elseif mode == "Top" then
				ox, oy = viewport.X / 2, 0
			elseif mode == "Mouse" then
				local m = UserInputService:GetMouseLocation()
				ox, oy = m.X, m.Y
			end
		end

		for i = 1, #players do
			local e = players[i]
			local pl = e.Player
			if pl and pl.Parent == Players and pl.Character == e.Model then
				local root = GetRoot(e)
				if root then
					local off = root.Position - camPos
					if off:Dot(off) <= maxD2 then
						local model = e.Model
						ESPSeen[model] = true
						local obj = ESPObjects[model]
						if not obj then
							obj = AcquireESP()
							ESPObjects[model] = obj
						end
						local ok, err = pcall(UpdateOne, obj, e, cam, viewport, dt, camPos, accent, ox, oy)
						if not ok then
							Vis(obj.Holder, false)
							local key = tostring(err)
							if not ESPErrWarned[key] then
								ESPErrWarned[key] = true
								warn("[PolishMafia] ESP: " .. key)
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

local ProcessAlien
do
	local FACE_ID = "rbxassetid://210879420742319"
	local HEAD_SCALE = 1.25
	local ALIEN_GREEN = Color3.fromRGB(0, 255, 70)
	local FACE_COLOR = Color3.fromRGB(0, 255, 70)
	local ALIEN_ORANGE = Color3.fromRGB(255, 190, 60)

	local BC_PROPS = { "HeadColor3", "LeftArmColor3", "RightArmColor3", "TorsoColor3", "LeftLegColor3", "RightLegColor3" }

	local Alien = {
		Char = nil,
		Applied = false,
		Tint = nil,
		S = nil,
	}

	local function NewState()
		return { Parts = {}, Clothes = {}, Accs = {}, Hidden = {}, HiddenSet = {}, Mine = nil }
	end
	Alien.S = NewState()

	local function AlienStatus(text, color)
		if AlienStatusLabel then
			AlienStatusLabel.Text = text
			AlienStatusLabel.TextColor3 = color or WHITE
		end
	end

	local function UpdateAlienStatus()
		if not Settings.Visual.AlienFit then
			AlienStatus("Alien Fit: wyłączony", WHITE)
		elseif Alien.Applied then
			AlienStatus("Alien Fit: aktywny", ALIEN_GREEN)
		else
			AlienStatus("Alien Fit: nakładanie...", ALIEN_ORANGE)
		end
	end

	local function HideOldFaces(head, S)
		for _, d in ipairs(head:GetDescendants()) do
			if (d:IsA("Decal") or d:IsA("Texture")) and string.lower(d.Name) == "face" and d ~= S.Mine then
				if not S.HiddenSet[d] then
					S.HiddenSet[d] = true
					S.Hidden[#S.Hidden + 1] = { Inst = d, Parent = d.Parent }
				end
				d.Parent = nil
			end
		end
	end

	local function EnsureMyFace(head, S)
		local f = S.Mine
		if not (f and f.Parent == head) then
			if f then
				f:Destroy()
			end
			f = Instance.new("Decal")
			f.Name = "PM_AlienFace"
			f.Face = Enum.NormalId.Front
			f.Transparency = 0
			f.Parent = head
			S.Mine = f
		end
		if f.Texture ~= FACE_ID then
			f.Texture = FACE_ID
		end
		if f.Color3 ~= FACE_COLOR then
			f.Color3 = FACE_COLOR
		end
	end

	local function Apply(char)
		local S = Alien.S
		local tint = Alien.Tint or ALIEN_GREEN

		-- akcesoria -> usuń
		for _, c in ipairs(char:GetChildren()) do
			if c:IsA("Accessory") then
				S.Accs[#S.Accs + 1] = c
				c.Parent = nil
			end
		end

		-- głowa: powiększenie, usunięcie starej twarzy, nowa twarz
		local head = char:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			local mesh = head:FindFirstChildOfClass("SpecialMesh")
			if mesh then
				if not S.HeadMesh then
					S.HeadMesh = { Mesh = mesh, Scale = mesh.Scale }
				end
				local want = S.HeadMesh.Scale * HEAD_SCALE
				if mesh.Scale ~= want then
					mesh.Scale = want
				end
			else
				if not S.HeadSize then
					S.HeadSize = { Part = head, Size = head.Size }
				end
				local want = S.HeadSize.Size * HEAD_SCALE
				if head.Size ~= want then
					head.Size = want
				end
			end

			HideOldFaces(head, S)
			EnsureMyFace(head, S)
		end

		-- BodyColors
		local bc = char:FindFirstChildOfClass("BodyColors")
		if not bc then
			bc = Instance.new("BodyColors")
			bc.Parent = char
			S.BC = { Inst = bc, Created = true }
		elseif not S.BC then
			local orig = {}
			for _, p in ipairs(BC_PROPS) do
				orig[p] = bc[p]
			end
			S.BC = { Inst = bc, Orig = orig }
		end
		for _, p in ipairs(BC_PROPS) do
			if bc[p] ~= tint then
				bc[p] = tint
			end
		end

		-- kolor części ciała bezpośrednio
		for _, c in ipairs(char:GetChildren()) do
			if c:IsA("BasePart") and c.Name ~= "HumanoidRootPart" then
				if S.Parts[c] == nil then
					S.Parts[c] = c.Color
				end
				if c.Color ~= tint then
					c.Color = tint
				end
			end
		end

		-- koszulka, spodnie, grafika -> 0
		for _, c in ipairs(char:GetChildren()) do
			if c:IsA("Shirt") then
				if S.Clothes[c] == nil then
					S.Clothes[c] = c.ShirtTemplate
				end
				if c.ShirtTemplate ~= "rbxassetid://0" then
					c.ShirtTemplate = "rbxassetid://0"
				end
			elseif c:IsA("Pants") then
				if S.Clothes[c] == nil then
					S.Clothes[c] = c.PantsTemplate
				end
				if c.PantsTemplate ~= "rbxassetid://0" then
					c.PantsTemplate = "rbxassetid://0"
				end
			elseif c:IsA("ShirtGraphic") then
				if S.Clothes[c] == nil then
					S.Clothes[c] = c.Graphic
				end
				if c.Graphic ~= "rbxassetid://0" then
					c.Graphic = "rbxassetid://0"
				end
			end
		end
	end

	local function Restore()
		local S = Alien.S

		if S.HeadMesh and S.HeadMesh.Mesh and S.HeadMesh.Mesh.Parent then
			S.HeadMesh.Mesh.Scale = S.HeadMesh.Scale
		end
		if S.HeadSize and S.HeadSize.Part and S.HeadSize.Part.Parent then
			S.HeadSize.Part.Size = S.HeadSize.Size
		end

		-- usuń moją twarz, przywróć oryginalne
		if S.Mine then
			S.Mine:Destroy()
			S.Mine = nil
		end
		for _, h in ipairs(S.Hidden) do
			if h.Inst and h.Parent and h.Parent.Parent then
				h.Inst.Parent = h.Parent
			end
		end

		if S.BC and S.BC.Inst and S.BC.Inst.Parent then
			if S.BC.Created then
				S.BC.Inst:Destroy()
			elseif S.BC.Orig then
				for p, v in pairs(S.BC.Orig) do
					S.BC.Inst[p] = v
				end
			end
		end

		for part, col in pairs(S.Parts) do
			if part.Parent then
				part.Color = col
			end
		end

		for inst, val in pairs(S.Clothes) do
			if inst.Parent then
				if inst:IsA("Shirt") then
					inst.ShirtTemplate = val
				elseif inst:IsA("Pants") then
					inst.PantsTemplate = val
				else
					inst.Graphic = val
				end
			end
		end

		local char = Alien.Char
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if char and char.Parent and hum then
			for _, acc in ipairs(S.Accs) do
				local ok = pcall(function()
					hum:AddAccessory(acc)
				end)
				if not ok then
					acc.Parent = char
				end
			end
		end

		Alien.S = NewState()
		Alien.Char = nil
		Alien.Applied = false
	end

	ProcessAlien = function()
		local want = Settings.Visual.AlienFit
		local char = LocalPlayer.Character

		if want then
			if not (char and char.Parent and char:FindFirstChildOfClass("Humanoid")) then
				return
			end
			if Alien.Char ~= char then
				Alien.S = NewState()
				Alien.Char = char
			end
			local ok, err = pcall(Apply, char)
			if not ok then
				warn("[PolishMafia] Alien Fit: " .. tostring(err))
			end
			Alien.Applied = true
		else
			if Alien.Applied then
				pcall(Restore)
			end
		end
		UpdateAlienStatus()
	end

	CollectAlienParts = function(out)
	end

	-- rainbow zmienia tylko ciało, twarz zawsze zostaje zielona
	SetAlienTint = function(color)
		Alien.Tint = color
		if Alien.Applied and Settings.Visual.AlienFit and Alien.Char and Alien.Char.Parent then
			pcall(Apply, Alien.Char)
		end
	end
end

local Warned = {}
local function Safe(tag, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and not Warned[tag] then
		Warned[tag] = true
		warn("[PolishMafia] " .. tag .. ": " .. tostring(err))
	end
	return ok
end

local lastStats = 0
local alienAcc = 0

RunService:BindToRenderStep("PolishMafia_Aim", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local cam = GetCamera()
	if not cam then
		return
	end
	local targets = GetTargets(os.clock())
	Safe("Heads", ProcessHeads, targets)
	Safe("Aimbot", ProcessAimbot, dt, cam, targets)
	Safe("Visual", ProcessVisual, dt)
end)

RunService.Heartbeat:Connect(function(dt)
	Safe("Movement", ProcessMovement, dt)
	alienAcc = alienAcc + dt
	if alienAcc >= 0.5 then
		alienAcc = 0
		Safe("Alien", ProcessAlien)
	end
end)
RunService.Stepped:Connect(function()
	Safe("Noclip", ProcessNoclip)
end)

RunService:BindToRenderStep("PolishMafia_ESP", Enum.RenderPriority.Last.Value, function(dt)
	local cam = GetCamera()
	if not cam then
		return
	end
	Safe("ESP", ProcessESP, dt, cam, PlayerList)

	local now = os.clock()
	if now - lastStats > 0.5 then
		lastStats = now
		StatsLabel.Text = "Gracze: " .. #PlayerList
	end
end)
