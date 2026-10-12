--[[ ValzZHub v4.0 | GitHub-hosted build ]]
--[[ upload ke GitHub, load via:
     loadstring(game:HttpGet("https://raw.githubusercontent.com/USERNAME/REPO/main/valzzhub.lua"))()
]]

--============================================================
-- RAYFIELD LOADER (multi-URL + retry)
--============================================================
local Rayfield
do
    local urls = {
        "https://sirius.menu/rayfield",
        "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua",
        "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/master/source.lua",
        "https://cdn.jsdelivr.net/gh/SiriusSoftwareLtd/Rayfield@main/source.lua",
        "https://cdn.jsdelivr.net/gh/SiriusSoftwareLtd/Rayfield@master/source.lua",
        "https://rawcdn.githack.com/SiriusSoftwareLtd/Rayfield/main/source.lua",
        "https://gitcdn.link/cdn/SiriusSoftwareLtd/Rayfield/main/source.lua",
    }
    local loaded = false
    for attempt = 1, 3 do
        if loaded then break end
        for _, url in ipairs(urls) do
            if loaded then break end
            local ok, res = pcall(function()
                local src = game:HttpGet(url, true)
                return loadstring(src)()
            end)
            if ok and res then
                Rayfield = res
                loaded = true
                print("[Valz] Rayfield loaded: " .. url)
            end
        end
        if not loaded then task.wait(1) end
    end
    if not loaded then
        warn("[Valz] Semua sumber Rayfield gagal. Coba lagi nanti.")
        return
    end
end

local Window = Rayfield:CreateWindow({
    Name = "ValzZHub", Icon = 93349170559446,
    LoadingTitle = "ValzZHub", LoadingSubtitle = "Violence District",
    Theme = "Default", ConfigurationSaving = { Enabled = false }, KeySystem = false,
})

local Tabs = {
    Info = Window:CreateTab("Info", 4483362458),
    Survivor = Window:CreateTab("Survivor", 4483362458),
    Killer = Window:CreateTab("Killer", 4483362458),
    Safety = Window:CreateTab("Safety", 4483362458),
    Teleport = Window:CreateTab("Teleport", 4483362458),
    Utility = Window:CreateTab("Utility", 4483362458),
    ESP = Window:CreateTab("ESP", 4483362458),
    Misc = Window:CreateTab("Misc", 4483362458),
    Visual = Window:CreateTab("Visual", 4483362458),
}

--============================================================
-- SERVICES
--============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Camera = workspace.CurrentCamera

local CarryEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Carry"):WaitForChild("CarrySurvivorEvent")
local HookEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Carry"):WaitForChild("HookEvent")
local AttackEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Attacks"):WaitForChild("BasicAttack")

--============================================================
-- CONFIG STATE
--============================================================
local ESP = { Survivor=false, Killer=false, Generator=false, Pallet=false, Window=false, Distance=1000 }
local GenColor = Color3.fromRGB(255,170,0)
local PalColor = Color3.fromRGB(74,255,181)
local WinColor = Color3.fromRGB(74,255,181)
local TeamColors = { Killer = Color3.fromRGB(255,60,60), Survivor = Color3.fromRGB(60,255,120) }
local Auto = { SkillCheck=false, Parry=false, ParryDistance=8, FaceStiffness=1, Wiggle=false, WiggleSpam=5, ParryMode="Hybrid" }
local Safety = { AutoDodge=false, DodgeDistance=30, ProximityAlert=false, AlertDistance=50 }
local NewFeatures = { KillerHUD=false, KillerArrow=false, CharacterReset=false, AutoMedkit=false }
local Utility = { AntiAFK=false }
local AutoFlee = { Enabled=false, DetectDistance=50, Cooldown=0.1 }
local LastFlee = 0
local Killer = { KillAll=false, AutoAttack=false, AutoCarry=false, KillAura=false, KillAuraRange=15 }
local KillerBusy, KillerTarget = false, nil
local Masked = { CurrentPower="Cobra" }
local MaskedPowers = {"Cobra","Richter","Brandon","Rabbit","Alex"}
local Moonwalk = { Enabled=false, SpamSpeed=30, Intensity=35, SavedAutoRotate=false }
local MoonwalkConnection = nil
local CameraZoom = { UnlimitedZoom=false, MaxDistance=1000, MinDistance=0, FOVEnabled=false, FOV=70, DefaultFOV=workspace.CurrentCamera.FieldOfView }
local AutoStalk = { Enabled=false, StalkRange=150 }
local CustomParry = { Enabled=false, Key=Enum.KeyCode.Q }
local ParryRangeColor = Color3.fromRGB(255,80,80)

local Invisible = { Enabled=false, EyeGui=nil, BlinkThread=nil, SavedProps={} }
local SelfUnhook = { Enabled=false, WasHooked=false, OriginalCF=nil, Offset=5 }

local LaserESP = { Enabled=false, Color=Color3.fromRGB(255,50,50), Thickness=2, Transparency=0.2 }

local FakePerks = { Enabled=false, Flowstate=false, QuickRecovery=false, PerfectLanding=false, AdrenalineRush=false, Gui=nil }
local PerkDefs = {
    Flowstate = { icon="FL", name="Flowstate", desc="+6 speed 5 detik setelah vault/slide", color=Color3.fromRGB(80,180,255) },
    QuickRecovery = { icon="QR", name="Quick Recovery", desc="+6 speed 3 detik setelah di-heal", color=Color3.fromRGB(80,255,180) },
    PerfectLanding = { icon="PL", name="Perfect Landing", desc="+8 speed 3 detik setelah jatuh", color=Color3.fromRGB(255,200,80) },
    AdrenalineRush = { icon="AR", name="Adrenaline Rush", desc="+6 speed 5 detik saat HP drop ke 50", color=Color3.fromRGB(255,80,80) },
}
local PerkState = { flowBuffUntil=0, quickBuffUntil=0, landingBuffUntil=0, adrenBuffUntil=0, lastHP=nil, lastWasAir=false, lastVaultCheck=0, baseSpeed=16 }

local KillerExtras = { BlockAllVault=false, DropAllPallets=false, AntiBlind=false }

local KillerAnims = {}
local _animRaw = {"105374834496520","113255068724446","118907603246885","129784271201071","117042998468241","122812055447896","78935059863801","74968262036854","78432063483146","132817836308238","133963973694098","111920872708571","80411309607666","98163597193511","82666958311998","110355011987939","139369275981139","135002183282873","121216847022485","130593238885843","117070354890871","106871536134254","138720291317243"}
for _, id in ipairs(_animRaw) do KillerAnims[id] = true; KillerAnims["rbxassetid://"..id] = true end
local function animMatches(a)
    if not a then return false end
    if KillerAnims[a] then return true end
    local n = a:match("%d+"); return n and (KillerAnims[n] or KillerAnims["rbxassetid://"..n]) or false
end

local ParryRangeVisual = { Enabled=false }
local ParryCircle = nil
local PlayerMods = { GodMode=false, AntiKnockDown=false }
local Movement = { JumpPowerEnabled=false, JumpPowerValue=50, OriginalJumpPower=50, WalkSpeedEnabled=false, WalkSpeedValue=17.6, OriginalWalkSpeed=16, NoClip=false }
local AvatarStealer = { TargetUsername="", OriginalDescription=nil }
local FastVault = { Enabled=false, Speed=1.2, ReplaceMap = { ["rbxassetid://83873880822918"]="rbxassetid://136962284480779" } }
local VaultTracks = {}
local Visual = { Fullbright=false, NoShadow=false, NoFog=false }
local original = { Brightness=Lighting.Brightness, ClockTime=Lighting.ClockTime, Ambient=Lighting.Ambient, OutdoorAmbient=Lighting.OutdoorAmbient, GlobalShadows=Lighting.GlobalShadows, FogEnd=Lighting.FogEnd, FogStart=Lighting.FogStart, FogColor=Lighting.FogColor }
local Crosshair = { Enabled=false, Size=8, Thickness=2, Color=Color3.fromRGB(255,255,255), Style="Plus", OffsetX=0, OffsetY=0 }
local CrosshairDrawings = {}
local Aim = { Enabled=false, Holding=false, TargetMode="Killer", Strength=1, Predict=true, PredictStrength=0.12, FOV=250, WallCheck=true, AimPart="HumanoidRootPart" }

local ToggleRefs = {}
local QuickBtn = { Gui = nil, Buttons = {} }
local BtnVis = { INV=true, PRY=true, SKL=true, MOON=true, AIM=true }
local LockButtons = true
local DEFAULT_BTN_POS = {
    SKL  = UDim2.new(1, -80, 0.13, 0),
    INV  = UDim2.new(1, -80, 0.13, 70),
    PRY  = UDim2.new(1, -80, 0.45, 0),
    MOON = UDim2.new(1, -80, 0.45, 70),
    AIM  = UDim2.new(1, -80, 0.45, 140),
}

--============================================================
-- CONFIG MANAGER
--============================================================
local ConfigMgr = { Folder = "ValzZHub_Configs", CurrentName = "" }

local function ensureFolder()
    pcall(function()
        if not isfolder(ConfigMgr.Folder) then makefolder(ConfigMgr.Folder) end
    end)
end

local function serializeValue(v)
    if typeof(v) == "Color3" then return { __type = "Color3", R = v.R, G = v.G, B = v.B } end
    if typeof(v) == "Vector3" then return { __type = "Vector3", X = v.X, Y = v.Y, Z = v.Z } end
    if typeof(v) == "EnumItem" then return { __type = "EnumItem", EnumType = tostring(v.EnumType), Name = v.Name } end
    if type(v) == "table" then
        local o = {}; for k, vv in pairs(v) do o[k] = serializeValue(vv) end; return o
    end
    return v
end

local function deserializeValue(v)
    if type(v) == "table" then
        if v.__type == "Color3" then return Color3.new(v.R, v.G, v.B) end
        if v.__type == "Vector3" then return Vector3.new(v.X, v.Y, v.Z) end
        if v.__type == "EnumItem" then
            local ok, e = pcall(function() return Enum[v.EnumType][v.Name] end)
            if ok then return e end
            return nil
        end
        local o = {}; for k, vv in pairs(v) do o[k] = deserializeValue(vv) end; return o
    end
    return v
end

local function listConfigs()
    local out = {}
    ensureFolder()
    pcall(function()
        for _, f in ipairs(listfiles(ConfigMgr.Folder)) do
            local n = f:match("([^/\\]+)%.json$")
            if n then table.insert(out, n) end
        end
    end)
    table.sort(out)
    return out
end

local function collectConfig()
    return {
        ESP = { Survivor=ESP.Survivor, Killer=ESP.Killer, Generator=ESP.Generator, Pallet=ESP.Pallet, Window=ESP.Window, Distance=ESP.Distance },
        Auto = { SkillCheck=Auto.SkillCheck, Parry=Auto.Parry, ParryDistance=Auto.ParryDistance, FaceStiffness=Auto.FaceStiffness, Wiggle=Auto.Wiggle, WiggleSpam=Auto.WiggleSpam, ParryMode=Auto.ParryMode },
        Safety = Safety, NewFeatures = NewFeatures, Utility = Utility, AutoFlee = AutoFlee, Killer = Killer,
        Moonwalk = { Enabled=Moonwalk.Enabled, SpamSpeed=Moonwalk.SpamSpeed, Intensity=Moonwalk.Intensity },
        CameraZoom = { UnlimitedZoom=CameraZoom.UnlimitedZoom, MaxDistance=CameraZoom.MaxDistance, FOVEnabled=CameraZoom.FOVEnabled, FOV=CameraZoom.FOV },
        AutoStalk = { Enabled=AutoStalk.Enabled, StalkRange=AutoStalk.StalkRange },
        CustomParry = { Enabled=CustomParry.Enabled, Key=CustomParry.Key },
        Invisible = { Enabled=Invisible.Enabled },
        SelfUnhook = { Enabled=SelfUnhook.Enabled, Offset=SelfUnhook.Offset },
        LaserESP = { Enabled=LaserESP.Enabled, Color=LaserESP.Color, Thickness=LaserESP.Thickness, Transparency=LaserESP.Transparency },
        FakePerks = { Enabled=FakePerks.Enabled, Flowstate=FakePerks.Flowstate, QuickRecovery=FakePerks.QuickRecovery, PerfectLanding=FakePerks.PerfectLanding, AdrenalineRush=FakePerks.AdrenalineRush },
        KillerExtras = KillerExtras, PlayerMods = PlayerMods,
        Movement = { JumpPowerEnabled=Movement.JumpPowerEnabled, JumpPowerValue=Movement.JumpPowerValue, WalkSpeedEnabled=Movement.WalkSpeedEnabled, WalkSpeedValue=Movement.WalkSpeedValue, NoClip=Movement.NoClip },
        Visual = Visual,
        Crosshair = { Enabled=Crosshair.Enabled, Size=Crosshair.Size, Thickness=Crosshair.Thickness, Color=Crosshair.Color, Style=Crosshair.Style, OffsetX=Crosshair.OffsetX, OffsetY=Crosshair.OffsetY },
        Aim = { Enabled=Aim.Enabled, TargetMode=Aim.TargetMode, Strength=Aim.Strength, Predict=Aim.Predict, PredictStrength=Aim.PredictStrength, FOV=Aim.FOV, WallCheck=Aim.WallCheck, AimPart=Aim.AimPart },
        BtnVis = BtnVis, LockButtons = LockButtons,
        FastVault = { Enabled=FastVault.Enabled, Speed=FastVault.Speed },
    }
end

local function saveConfig(name)
    if not name or name == "" then return false, "Nama kosong" end
    ensureFolder()
    local encoded = HttpService:JSONEncode(serializeValue(collectConfig()))
    local ok, err = pcall(function() writefile(ConfigMgr.Folder .. "/" .. name .. ".json", encoded) end)
    if ok then ConfigMgr.CurrentName = name; return true end
    return false, tostring(err)
end

local function loadConfig(name)
    if not name or name == "" then return false, "Nama kosong" end
    local ok, contents = pcall(function() return readfile(ConfigMgr.Folder .. "/" .. name .. ".json") end)
    if not ok then return false, "Gagal baca file" end
    local ok2, decoded = pcall(function() return HttpService:JSONDecode(contents) end)
    if not ok2 then return false, "JSON invalid" end
    local data = deserializeValue(decoded)
    local function mergeInto(t, s)
        if type(s) ~= "table" then return end
        for k, v in pairs(s) do
            if type(v) == "table" and type(t[k]) == "table" then mergeInto(t[k], v)
            else t[k] = v end
        end
    end
    pcall(function()
        if data.ESP then mergeInto(ESP, data.ESP) end
        if data.Auto then mergeInto(Auto, data.Auto) end
        if data.Safety then mergeInto(Safety, data.Safety) end
        if data.NewFeatures then mergeInto(NewFeatures, data.NewFeatures) end
        if data.Utility then mergeInto(Utility, data.Utility) end
        if data.AutoFlee then mergeInto(AutoFlee, data.AutoFlee) end
        if data.Killer then mergeInto(Killer, data.Killer) end
        if data.Moonwalk then mergeInto(Moonwalk, data.Moonwalk) end
        if data.CameraZoom then mergeInto(CameraZoom, data.CameraZoom) end
        if data.AutoStalk then mergeInto(AutoStalk, data.AutoStalk) end
        if data.CustomParry then mergeInto(CustomParry, data.CustomParry) end
        if data.Invisible then mergeInto(Invisible, data.Invisible) end
        if data.SelfUnhook then mergeInto(SelfUnhook, data.SelfUnhook) end
        if data.LaserESP then mergeInto(LaserESP, data.LaserESP) end
        if data.FakePerks then mergeInto(FakePerks, data.FakePerks) end
        if data.KillerExtras then mergeInto(KillerExtras, data.KillerExtras) end
        if data.PlayerMods then mergeInto(PlayerMods, data.PlayerMods) end
        if data.Movement then mergeInto(Movement, data.Movement) end
        if data.Visual then mergeInto(Visual, data.Visual) end
        if data.Crosshair then mergeInto(Crosshair, data.Crosshair) end
        if data.Aim then mergeInto(Aim, data.Aim) end
        if data.BtnVis then mergeInto(BtnVis, data.BtnVis) end
        if data.LockButtons ~= nil then LockButtons = data.LockButtons end
        if data.FastVault then mergeInto(FastVault, data.FastVault) end
    end)
    task.spawn(function()
        if Moonwalk.Enabled then toggleMoonwalk(true) else toggleMoonwalk(false) end
        if Invisible.Enabled then applyInvisible(); startEyeBlink() else restoreInvisible() end
        if FakePerks.Enabled then
            buildFakePerkHUD(); if FakePerks.Gui then FakePerks.Gui.Enabled = true end
            rebuildPerkSlots()
        else if FakePerks.Gui then FakePerks.Gui.Enabled = false end end
        if KillerExtras.BlockAllVault then enableBlockAllVault() else disableBlockAllVault() end
        if KillerExtras.AntiBlind then enableAntiBlind() else disableAntiBlind() end
        if Auto.Parry then ParryRangeVisual.Enabled = true end
        if Movement.WalkSpeedEnabled then applyWalkSpeed() end
        if Movement.JumpPowerEnabled then applyJumpPower() end
        if Movement.NoClip then toggleNoClip(true) end
        if CameraZoom.FOVEnabled then applyCameraFOV() end
        if CameraZoom.UnlimitedZoom then applyUnlimitedZoom() end
        applyButtonVisibility()
    end)
    ConfigMgr.CurrentName = name
    return true
end

local function deleteConfig(name)
    if not name or name == "" then return false end
    return pcall(function() delfile(ConfigMgr.Folder .. "/" .. name .. ".json") end)
end

--============================================================
-- HELPERS
--============================================================
local function getRoot() return LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") end
local function normalizeId(id) local n = tostring(id):match("%d+"); return n and ("rbxassetid://"..n) end
local function isKillerTeam(p) if not p or not p.Team then return false end return p.Team.Name == "Killer" or p.Team.Name == "Killers" end
local function isSurvivorTeam(p) if not p or not p.Team then return false end return p.Team.Name == "Survivor" or p.Team.Name == "Survivors" end

local function GetDowned()
    local root = getRoot(); if not root then return nil end
    local best, dist = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local h = p.Character:FindFirstChildOfClass("Humanoid"); local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if h and hrp and h.Health > 0 and h.Health <= h.MaxHealth*0.25 then
                local d = (hrp.Position - root.Position).Magnitude
                if d < dist then dist = d; best = p.Character end
            end
        end
    end
    return best
end
local function GetHook()
    local root = getRoot(); if not root then return nil end
    local best, shortest = nil, math.huge
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name == "HookPoint" and obj:IsA("BasePart") then
            local d = (obj.Position - root.Position).Magnitude
            if d < shortest and d < 400 then shortest = d; best = obj end
        end
    end
    return best
end
local function applyJumpPower()
    if not Movement.JumpPowerEnabled then return end
    local c = LocalPlayer.Character; if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid"); if h then h.JumpPower = Movement.JumpPowerValue end
end
local WalkSpeedConn = nil
local function applyWalkSpeed()
    if WalkSpeedConn then WalkSpeedConn:Disconnect(); WalkSpeedConn = nil end
    WalkSpeedConn = RunService.Heartbeat:Connect(function()
        if not Movement.WalkSpeedEnabled then return end
        local c = LocalPlayer.Character; if not c then return end
        local h = c:FindFirstChildOfClass("Humanoid"); if not h then return end
        if h.Health <= 0 then return end
        if h.WalkSpeed ~= Movement.WalkSpeedValue then h.WalkSpeed = Movement.WalkSpeedValue end
    end)
end
local function isClimbable(p)
    if not p then return false end
    if p:IsA("TrussPart") then return true end
    local n = string.lower(p.Name)
    return string.find(n,"ladder",1,true) or string.find(n,"truss",1,true) or p.Material == Enum.Material.Ladder
end
local NoClipConn = nil
local function toggleNoClip(s)
    Movement.NoClip = s
    if s then
        if NoClipConn then NoClipConn:Disconnect() end
        NoClipConn = RunService.RenderStepped:Connect(function()
            local c = LocalPlayer.Character; if not c then return end
            for _, v in pairs(c:GetDescendants()) do
                if v:IsA("BasePart") then
                    if isClimbable(v) then v.CanCollide = true else v.CanCollide = not Movement.NoClip end
                end
            end
        end)
    else
        if NoClipConn then NoClipConn:Disconnect(); NoClipConn = nil end
        local c = LocalPlayer.Character
        if c then for _, v in pairs(c:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = true end end end
    end
end
local function applyGodMode()
    if not PlayerMods.GodMode then return end
    local c = LocalPlayer.Character; if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid"); if not h then return end
    if h.Health < h.MaxHealth then pcall(function() h.Health = h.MaxHealth end) end
    local st = h:GetState()
    if st == Enum.HumanoidStateType.Dead or st == Enum.HumanoidStateType.FallingDown
    or st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.PlatformStanding then
        pcall(function() h:ChangeState(Enum.HumanoidStateType.Running) end)
    end
end
local function isDowned()
    local c = LocalPlayer.Character; if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid"); if not h then return false end
    return h.Health <= 0 or h.Health < 2 or c:GetAttribute("Downed") == true or c:GetAttribute("Knocked") == true
end
local function applyUnlimitedZoom()
    if CameraZoom.UnlimitedZoom then
        LocalPlayer.CameraMaxZoomDistance = CameraZoom.MaxDistance
        LocalPlayer.CameraMinZoomDistance = CameraZoom.MinDistance
    else
        LocalPlayer.CameraMaxZoomDistance = 128
        LocalPlayer.CameraMinZoomDistance = 0.5
    end
end
local function applyCameraFOV()
    local cam = workspace.CurrentCamera; if not cam then return end
    if CameraZoom.FOVEnabled then cam.FieldOfView = CameraZoom.FOV else cam.FieldOfView = CameraZoom.DefaultFOV end
end

--============================================================
-- INVISIBLE
--============================================================
local function applyInvisToPart(v, char)
    if not Invisible.Enabled or not v or not v.Parent then return end
    local cur = v; local insideTool = false
    while cur and cur ~= char do
        if cur:IsA("Tool") then insideTool = true; break end
        cur = cur.Parent
    end
    if insideTool then return end
    if v:IsA("BasePart") then
        if not Invisible.SavedProps[v] then
            Invisible.SavedProps[v] = { Material=v.Material, MaterialVariant=v.MaterialVariant, Transparency=v.Transparency, Reflectance=v.Reflectance, CastShadow=v.CastShadow }
        end
        if v.Material ~= Enum.Material.ForceField then
            v.Material = Enum.Material.ForceField
            v.MaterialVariant = ""
            v.Transparency = 0.7
            v.Reflectance = 0
            v.CastShadow = false
        end
    elseif v:IsA("Decal") or v:IsA("Texture") then
        if not Invisible.SavedProps[v] then Invisible.SavedProps[v] = { Transparency = v.Transparency } end
        if v.Transparency ~= 0.7 then v.Transparency = 0.7 end
    elseif v:IsA("Accessory") then
        if v:FindFirstChild("Handle") then applyInvisToPart(v.Handle, char) end
    elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
        or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
        if not Invisible.SavedProps[v] then Invisible.SavedProps[v] = { Enabled = v.Enabled } end
        if v.Enabled then v.Enabled = false end
    end
end

local function createEyeGui()
    if Invisible.EyeGui then return end
    local sg = Instance.new("ScreenGui")
    sg.Name = "ValzInvisEyes"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
    if gethui then pcall(function() sg.Parent = gethui() end) else sg.Parent = PlayerGui end
    local bg = Instance.new("BillboardGui")
    bg.Size = UDim2.fromOffset(48, 18); bg.StudsOffsetWorldSpace = Vector3.new(0, 2.55, 0)
    bg.AlwaysOnTop = true; bg.LightInfluence = 0; bg.MaxDistance = 500
    bg.Enabled = false; bg.Parent = sg
    local left = Instance.new("Frame")
    left.Size = UDim2.fromOffset(7, 7); left.Position = UDim2.new(0, 12, 0.5, -3.5)
    left.BackgroundColor3 = Color3.fromRGB(255, 30, 30); left.BorderSizePixel = 0; left.Parent = bg
    local lc = Instance.new("UICorner"); lc.CornerRadius = UDim.new(1, 0); lc.Parent = left
    local right = Instance.new("Frame")
    right.Size = UDim2.fromOffset(7, 7); right.Position = UDim2.new(1, -19, 0.5, -3.5)
    right.BackgroundColor3 = Color3.fromRGB(255, 30, 30); right.BorderSizePixel = 0; right.Parent = bg
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(1, 0); rc.Parent = right
    Invisible.EyeGui = sg
end

local function startEyeBlink()
    if Invisible.BlinkThread then pcall(function() task.cancel(Invisible.BlinkThread) end) end
    Invisible.BlinkThread = task.spawn(function()
        while Invisible.Enabled do
            task.wait(3)
            if not Invisible.Enabled then break end
            if Invisible.EyeGui then Invisible.EyeGui.Enabled = false end
            task.wait(0.15)
            if Invisible.Enabled and Invisible.EyeGui then Invisible.EyeGui.Enabled = true end
        end
    end)
end
local function stopEyeBlink()
    if Invisible.BlinkThread then pcall(function() task.cancel(Invisible.BlinkThread) end); Invisible.BlinkThread = nil end
end

local InvisCharConn = nil
local function applyInvisible()
    if not Invisible.Enabled then return end
    local char = LocalPlayer.Character; if not char then return end
    for _, v in ipairs(char:GetDescendants()) do applyInvisToPart(v, char) end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.NameDisplayDistance = 0; hum.HealthDisplayDistance = 0 end
    if InvisCharConn then InvisCharConn:Disconnect() end
    InvisCharConn = char.DescendantAdded:Connect(function(v)
        if Invisible.Enabled then applyInvisToPart(v, char) end
    end)
    createEyeGui()
    local head = char:FindFirstChild("Head")
    if head and Invisible.EyeGui then
        for _, d in ipairs(Invisible.EyeGui:GetDescendants()) do
            if d:IsA("BillboardGui") then d.Adornee = head; d.Enabled = true end
        end
    end
end

local function restoreInvisible()
    local char = LocalPlayer.Character
    if char then
        for _, v in ipairs(char:GetDescendants()) do
            local s = Invisible.SavedProps[v]
            if s then
                if v:IsA("BasePart") then
                    v.Material = s.Material or v.Material
                    v.MaterialVariant = s.MaterialVariant or ""
                    v.Transparency = s.Transparency or 0
                    v.Reflectance = s.Reflectance or 0
                    v.CastShadow = (s.CastShadow == nil) and true or s.CastShadow
                elseif v:IsA("Decal") or v:IsA("Texture") then
                    v.Transparency = s.Transparency or 0
                elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
                    or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
                    v.Enabled = (s.Enabled == nil) and true or s.Enabled
                end
            end
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.NameDisplayDistance = 100; hum.HealthDisplayDistance = 100 end
    end
    if InvisCharConn then InvisCharConn:Disconnect(); InvisCharConn = nil end
    if Invisible.EyeGui then Invisible.EyeGui.Enabled = false end
    stopEyeBlink()
    Invisible.SavedProps = {}
end

LocalPlayer.CharacterAdded:Connect(function(c)
    task.wait(1.5)
    Invisible.SavedProps = {}
    if Invisible.Enabled then applyInvisible(); startEyeBlink() end
end)

--============================================================
-- SELF UNHOOK
--============================================================
local function getNearestKillerPlayer()
    local char = LocalPlayer.Character; if not char then return nil end
    local myRoot = char:FindFirstChild("HumanoidRootPart"); if not myRoot then return nil end
    local best, bestD = nil, 300
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isKillerTeam(p) and p.Character then
            local r = p.Character:FindFirstChild("HumanoidRootPart")
            if r then
                local d = (r.Position - myRoot.Position).Magnitude
                if d < bestD then bestD = d; best = p end
            end
        end
    end
    return best
end
local function isHooked()
    local char = LocalPlayer.Character; if not char then return false end
    for _, a in ipairs({"Hooked","IsHooked","IsGrabbed","IsSpiked","Carried","HookedState"}) do
        if char:GetAttribute(a) == true then return true end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        local st = hum:GetState()
        if st == Enum.HumanoidStateType.PlatformStanding then return true end
        if st == Enum.HumanoidStateType.Physics then return true end
    end
    return false
end
local function setCharCollision(canCollide)
    local char = LocalPlayer.Character; if not char then return end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") and not isClimbable(v) then
            pcall(function() v.CanCollide = canCollide end)
        end
    end
end
task.spawn(function()
    while true do
        task.wait()
        if not SelfUnhook.Enabled then
            if SelfUnhook.WasHooked then setCharCollision(true); SelfUnhook.WasHooked = false; SelfUnhook.OriginalCF = nil end
            continue
        end
        local char = LocalPlayer.Character; if not char then continue end
        local root = char:FindFirstChild("HumanoidRootPart"); if not root then continue end
        local hooked = isHooked()
        if hooked then
            if not SelfUnhook.WasHooked then
                SelfUnhook.WasHooked = true
                SelfUnhook.OriginalCF = root.CFrame
                setCharCollision(false)
            end
            local killer = getNearestKillerPlayer()
            if killer and killer.Character then
                local kRoot = killer.Character:FindFirstChild("HumanoidRootPart")
                if kRoot then
                    pcall(function() root.CFrame = kRoot.CFrame - Vector3.new(0, SelfUnhook.Offset, 0) end)
                end
            end
        elseif SelfUnhook.WasHooked then
            setCharCollision(true)
            if SelfUnhook.OriginalCF then pcall(function() root.CFrame = SelfUnhook.OriginalCF end) end
            SelfUnhook.WasHooked = false; SelfUnhook.OriginalCF = nil
            Rayfield:Notify({Title="Self Unhook",Content="Lepas!",Duration=3})
        end
    end
end)

--============================================================
-- ESP LASER
--============================================================
local LaserDrawings = {}
local function clearLaserDrawings()
    for _, d in ipairs(LaserDrawings) do if d.Remove then d:Remove() end end
    LaserDrawings = {}
end
local function getMuzzlePosition()
    local char = LocalPlayer.Character; if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        local muzzle = tool:FindFirstChild("Muzzle", true) or tool:FindFirstChild("MuzzlePoint", true) or tool:FindFirstChild("Barrel", true)
        if muzzle and muzzle:IsA("BasePart") then return muzzle.Position end
        local handle = tool:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then return handle.Position end
    end
    local rArm = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand")
    if rArm and rArm:IsA("BasePart") then return rArm.Position end
    return nil
end
local function getAimTarget()
    local cam = workspace.CurrentCamera
    local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
    local cl, sh = nil, Aim.FOV
    if Aim.TargetMode == "Killer" or Aim.TargetMode == "Survivor" then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local match = (Aim.TargetMode == "Killer" and isKillerTeam(p)) or (Aim.TargetMode == "Survivor" and isSurvivorTeam(p))
                if match then
                    local hrp = p.Character:FindFirstChild(Aim.AimPart); local h = p.Character:FindFirstChildOfClass("Humanoid")
                    if hrp and h and h.Health > 0 then
                        local pos, vis = cam:WorldToViewportPoint(hrp.Position)
                        if vis then
                            local d = (Vector2.new(pos.X,pos.Y) - center).Magnitude
                            if d < sh then sh = d; cl = hrp end
                        end
                    end
                end
            end
        end
    end
    return cl
end
local LaserConn = nil
local function startLaser()
    if LaserConn then LaserConn:Disconnect() end
    LaserConn = RunService.RenderStepped:Connect(function()
        if not LaserESP.Enabled then
            if #LaserDrawings > 0 then clearLaserDrawings() end
            return
        end
        if not Drawing or not Drawing.new then return end
        local target = getAimTarget()
        if not target then
            if #LaserDrawings > 0 then for _, d in ipairs(LaserDrawings) do d.Visible = false end end
            return
        end
        local cam = workspace.CurrentCamera; if not cam then return end
        local fromWorld = getMuzzlePosition() or (cam.CFrame.Position + cam.CFrame.LookVector * 5)
        local toWorld = target.Position
        local fromScreen, fromOnScreen = cam:WorldToViewportPoint(fromWorld)
        local toScreen, toOnScreen = cam:WorldToViewportPoint(toWorld)
        if not toOnScreen then
            for _, d in ipairs(LaserDrawings) do d.Visible = false end
            return
        end
        if #LaserDrawings == 0 then
            local line = Drawing.new("Line")
            line.Thickness = LaserESP.Thickness; line.Transparency = LaserESP.Transparency; line.Visible = false
            table.insert(LaserDrawings, line)
            local glow = Drawing.new("Line")
            glow.Thickness = LaserESP.Thickness + 2; glow.Transparency = LaserESP.Transparency + 0.4; glow.Visible = false
            table.insert(LaserDrawings, glow)
        end
        local origin2D = fromOnScreen and Vector2.new(fromScreen.X, fromScreen.Y) or Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.95)
        LaserDrawings[1].From = origin2D; LaserDrawings[1].To = Vector2.new(toScreen.X, toScreen.Y); LaserDrawings[1].Color = LaserESP.Color; LaserDrawings[1].Visible = true
        LaserDrawings[2].From = origin2D; LaserDrawings[2].To = Vector2.new(toScreen.X, toScreen.Y); LaserDrawings[2].Color = LaserESP.Color; LaserDrawings[2].Visible = true
    end)
end

--============================================================
-- FAKE PERKS
--============================================================
local function buildFakePerkHUD()
    if FakePerks.Gui then return end
    local sg = Instance.new("ScreenGui")
    sg.Name = "ValzFakePerks"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    if gethui then pcall(function() sg.Parent = gethui() end) else sg.Parent = PlayerGui end
    local frame = Instance.new("Frame"); frame.Name = "Root"
    frame.Size = UDim2.fromOffset(240, 60)
    frame.Position = UDim2.new(0, 15, 1, -80)
    frame.BackgroundColor3 = Color3.fromRGB(10, 10, 15); frame.BackgroundTransparency = 0.35
    frame.BorderSizePixel = 0; frame.Parent = sg
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = frame
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(200, 150, 60); s.Thickness = 1.5; s.Parent = frame
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 6)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Parent = frame
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8); pad.Parent = frame
    FakePerks.Gui = sg
end
local function rebuildPerkSlots()
    if not FakePerks.Gui then return end
    local rootFrame = FakePerks.Gui:FindFirstChild("Root"); if not rootFrame then return end
    for _, ch in ipairs(rootFrame:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
    local order = { "Flowstate", "QuickRecovery", "PerfectLanding", "AdrenalineRush" }
    for _, key in ipairs(order) do
        local def = PerkDefs[key]; local enabled = FakePerks[key]
        local slot = Instance.new("Frame")
        slot.Size = UDim2.fromOffset(46, 46)
        slot.BackgroundColor3 = enabled and Color3.fromRGB(30, 25, 15) or Color3.fromRGB(20, 20, 20)
        slot.BackgroundTransparency = enabled and 0 or 0.5
        slot.BorderSizePixel = 0; slot.Parent = rootFrame
        local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 6); sc.Parent = slot
        local ss = Instance.new("UIStroke")
        ss.Color = enabled and def.color or Color3.fromRGB(80, 80, 80)
        ss.Thickness = enabled and 1.5 or 1; ss.Transparency = enabled and 0 or 0.5
        ss.Parent = slot
        local icon = Instance.new("TextLabel")
        icon.Size = UDim2.new(1, 0, 1, 0); icon.BackgroundTransparency = 1
        icon.Text = def.icon
        icon.TextColor3 = enabled and def.color or Color3.fromRGB(120, 120, 120)
        icon.Font = Enum.Font.GothamBold; icon.TextSize = 18; icon.Parent = slot
        local tip = Instance.new("TextLabel")
        tip.Size = UDim2.fromOffset(200, 36); tip.Position = UDim2.new(0.5, -100, -2.0, 0)
        tip.BackgroundColor3 = Color3.fromRGB(0, 0, 0); tip.BackgroundTransparency = 0.25
        tip.Text = def.name .. "\n" .. def.desc
        tip.TextColor3 = enabled and def.color or Color3.fromRGB(160, 160, 160)
        tip.TextWrapped = true; tip.Font = Enum.Font.Gotham; tip.TextSize = 11; tip.Visible = false; tip.Parent = slot
        local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0, 4); tc.Parent = tip
        local tp = Instance.new("UIPadding")
        tp.PaddingTop = UDim.new(0, 3); tp.PaddingBottom = UDim.new(0, 3)
        tp.PaddingLeft = UDim.new(0, 5); tp.PaddingRight = UDim.new(0, 5); tp.Parent = tip
        slot.MouseEnter:Connect(function() tip.Visible = true end)
        slot.MouseLeave:Connect(function() tip.Visible = false end)
    end
end
local function computeActiveBuff()
    local now = tick(); local maxAdd = 0
    if FakePerks.Flowstate and now < PerkState.flowBuffUntil then maxAdd = math.max(maxAdd, 6) end
    if FakePerks.QuickRecovery and now < PerkState.quickBuffUntil then maxAdd = math.max(maxAdd, 6) end
    if FakePerks.PerfectLanding and now < PerkState.landingBuffUntil then maxAdd = math.max(maxAdd, 8) end
    if FakePerks.AdrenalineRush and now < PerkState.adrenBuffUntil then maxAdd = math.max(maxAdd, 6) end
    return maxAdd
end
task.spawn(function()
    while true do
        task.wait(0.1)
        if not FakePerks.Enabled then PerkState.lastHP = nil; PerkState.lastWasAir = false; continue end
        local char = LocalPlayer.Character; if not char then continue end
        local h = char:FindFirstChildOfClass("Humanoid"); local hrp = char:FindFirstChild("HumanoidRootPart")
        if not h or not hrp then continue end
        local now = tick()
        if PerkState.lastHP then
            local threshold = h.MaxHealth * 0.5
            if PerkState.lastHP > threshold and h.Health <= threshold and FakePerks.AdrenalineRush then
                PerkState.adrenBuffUntil = now + 5
                Rayfield:Notify({Title="Adrenaline Rush",Content="+6 speed",Duration=2})
            end
        end
        PerkState.lastHP = h.Health
        local state = h:GetState()
        local isAir = (state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.FallingDown)
        if PerkState.lastWasAir and not isAir and state == Enum.HumanoidStateType.Landed and FakePerks.PerfectLanding then
            PerkState.landingBuffUntil = now + 3
            Rayfield:Notify({Title="Perfect Landing",Content="+8 speed",Duration=2})
        end
        PerkState.lastWasAir = isAir
        local vel = hrp.AssemblyLinearVelocity
        local horiz = Vector3.new(vel.X, 0, vel.Z).Magnitude
        if horiz > 25 and FakePerks.Flowstate then PerkState.flowBuffUntil = now + 5 end
        local target = PerkState.baseSpeed + computeActiveBuff()
        if h.WalkSpeed ~= target then h.WalkSpeed = target end
    end
end)
task.spawn(function()
    local lastHP = nil
    while true do
        task.wait(0.2)
        if not FakePerks.Enabled or not FakePerks.QuickRecovery then lastHP = nil; continue end
        local char = LocalPlayer.Character; if not char then lastHP = nil; continue end
        local h = char:FindFirstChildOfClass("Humanoid"); if not h then lastHP = nil; continue end
        if lastHP and h.Health > lastHP + 5 then
            PerkState.quickBuffUntil = tick() + 3
            Rayfield:Notify({Title="Quick Recovery",Content="+6 speed",Duration=2})
        end
        lastHP = h.Health
    end
end)
LocalPlayer.CharacterAdded:Connect(function(c)
    task.wait(1)
    local h = c:FindFirstChildOfClass("Humanoid")
    if h then PerkState.baseSpeed = h.WalkSpeed or 16 end
end)
if LocalPlayer.Character then
    local h = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if h then PerkState.baseSpeed = h.WalkSpeed or 16 end
end

--============================================================
-- KILLER EXTRAS
--============================================================
local function isVaultLike(o)
    if not o or not o.Parent then return false end
    local n = string.lower(o.Name)
    return n == "window" or n == "vault" or string.find(n, "vault") or string.find(n, "window") or string.find(n, "ledge")
end
local BlockedVaults = setmetatable({}, {__mode = "k"})
local function blockVault(part)
    if not part or BlockedVaults[part] then return end
    BlockedVaults[part] = true
    pcall(function()
        if part:IsA("BasePart") then
            part.CanCollide = true
            part:SetAttribute("Blocked", true); part:SetAttribute("IsBlocked", true); part:SetAttribute("VaultBlocked", true)
        end
        for _, d in ipairs(part:GetDescendants()) do
            if d:IsA("ProximityPrompt") then d.Enabled = false; pcall(function() d.MaxActivationDistance = 0 end) end
            if d:IsA("BasePart") then d.CanCollide = true end
        end
    end)
end
local BlockVaultConn = nil
local function enableBlockAllVault()
    for _, o in ipairs(workspace:GetDescendants()) do if isVaultLike(o) then blockVault(o) end end
    if BlockVaultConn then BlockVaultConn:Disconnect() end
    BlockVaultConn = workspace.DescendantAdded:Connect(function(o)
        if KillerExtras.BlockAllVault and isVaultLike(o) then
            task.defer(function() if KillerExtras.BlockAllVault then blockVault(o) end end)
        end
    end)
end
local function disableBlockAllVault()
    if BlockVaultConn then BlockVaultConn:Disconnect(); BlockVaultConn = nil end
end
local DroppedPallets = setmetatable({}, {__mode = "k"})
local function tryDropPallet(part)
    if not part or DroppedPallets[part] then return end
    DroppedPallets[part] = true
    pcall(function()
        part:SetAttribute("Dropped", true); part:SetAttribute("IsDropped", true); part:SetAttribute("isDroppingPallet", true)
    end)
    local rem = ReplicatedStorage:FindFirstChild("Remotes"); if not rem then return end
    for _, o in ipairs(rem:GetDescendants()) do
        if o:IsA("RemoteEvent") then
            local n = string.lower(o.Name)
            if string.find(n, "drop") and string.find(n, "pallet") then pcall(function() o:FireServer(part) end) end
            if string.find(n, "pallet") and not string.find(n, "drop") then pcall(function() o:FireServer(part, "drop") end) end
        end
    end
end
local function dropAllPallets()
    local count = 0
    for _, o in ipairs(workspace:GetDescendants()) do
        local n = string.lower(o.Name)
        if n == "pallet" or n == "palletwrong" then tryDropPallet(o); count = count + 1 end
    end
    Rayfield:Notify({Title="Drop Pallets", Content="Tried "..count.." pallets", Duration=3})
end
local AntiBlindKeywords = {"blind","flash","stun","screenflash","whiteout","overlay","flashlight","dazzle","flashblind"}
local function isBlindGui(gui)
    if not gui then return false end
    local n = string.lower(gui.Name)
    for _, k in ipairs(AntiBlindKeywords) do if string.find(n, k) then return true end end
    return false
end
local function processAntiBlind()
    if not KillerExtras.AntiBlind then return end
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and isBlindGui(gui) then
            gui.Enabled = false
            for _, d in ipairs(gui:GetDescendants()) do
                if d:IsA("ImageLabel") or d:IsA("Frame") then d.Visible = false end
            end
        end
    end
    pcall(function()
        if Lighting:FindFirstChildOfClass("BlurEffect") then
            local b = Lighting:FindFirstChildOfClass("BlurEffect"); if b.Size > 0 then b.Size = 0 end
        end
        if Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
            local c = Lighting:FindFirstChildOfClass("ColorCorrectionEffect"); if c.Brightness > 0.1 then c.Brightness = 0 end
        end
    end)
end
local AntiBlindGuiConn, AntiBlindTask = nil, nil
local function enableAntiBlind()
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and isBlindGui(gui) then gui.Enabled = false end
    end
    if AntiBlindGuiConn then AntiBlindGuiConn:Disconnect() end
    AntiBlindGuiConn = PlayerGui.DescendantAdded:Connect(function(g)
        if not KillerExtras.AntiBlind then return end
        task.defer(function()
            if not KillerExtras.AntiBlind then return end
            local cur = g
            while cur and cur ~= PlayerGui do
                if cur:IsA("ScreenGui") and isBlindGui(cur) then cur.Enabled = false; break end
                cur = cur.Parent
            end
        end)
    end)
    if not AntiBlindTask then
        AntiBlindTask = task.spawn(function()
            while true do
                task.wait(0.1)
                if KillerExtras.AntiBlind then processAntiBlind() end
            end
        end)
    end
end
local function disableAntiBlind()
    if AntiBlindGuiConn then AntiBlindGuiConn:Disconnect(); AntiBlindGuiConn = nil end
end

--============================================================
-- SKILL CHECK
--============================================================
local function pressSpace()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game); task.wait()
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end)
end
local function GetActionTarget()
    local cur = PlayerGui
    for seg in string.gmatch("Survivor-mob.Controls.action.check", "[^%.]+") do cur = cur and cur:FindFirstChild(seg) end
    return cur
end
local function TriggerMobileButton()
    local b = GetActionTarget()
    if b and b:IsA("GuiObject") then
        local p, s = b.AbsolutePosition, b.AbsoluteSize
        local i = game:GetService("GuiService"):GetGuiInset()
        local cx, cy = p.X + (s.X/2) + i.X, p.Y + (s.Y/2) + i.Y
        pcall(function()
            VirtualInputManager:SendTouchEvent(8822, 0, cx, cy); task.wait(0.01)
            VirtualInputManager:SendTouchEvent(8822, 2, cx, cy)
        end)
    end
end
local SkillHeartbeat, skillBusy = nil, false
local function startSkillCheck()
    if SkillHeartbeat then SkillHeartbeat:Disconnect() end
    SkillHeartbeat = RunService.RenderStepped:Connect(function()
        if not Auto.SkillCheck or skillBusy then return end
        local prompt = PlayerGui:FindFirstChild("SkillCheckPromptGui"); if not prompt then return end
        if prompt:IsA("ScreenGui") and prompt.Enabled == false then return end
        local check = prompt:FindFirstChild("Check"); if not check then return end
        if check:IsA("GuiObject") and check.Visible == false then return end
        local line = check:FindFirstChild("Line"); local goal = check:FindFirstChild("Goal")
        if not line or not goal then return end
        local lr = (line.Rotation or 0) % 360; local gr = (goal.Rotation or 0) % 360
        if lr < 0 then lr = lr + 360 end; if gr < 0 then gr = gr + 360 end
        local sr = (gr + 102) % 360; local er = (gr + 116) % 360
        local success
        if sr > er then success = (lr >= sr or lr <= er) else success = (lr >= sr and lr <= er) end
        if success then
            skillBusy = true
            task.spawn(function()
                if UserInputService.TouchEnabled then TriggerMobileButton() else pressSpace() end
                task.wait(0.05); skillBusy = false
            end)
        end
    end)
end
local function stopSkillCheck()
    if SkillHeartbeat then SkillHeartbeat:Disconnect(); SkillHeartbeat = nil end
end

--============================================================
-- MOONWALK
--============================================================
local function startMoonwalk()
    if MoonwalkConnection then MoonwalkConnection:Disconnect() end
    local lastAng = 0
    MoonwalkConnection = RunService.RenderStepped:Connect(function()
        if not Moonwalk.Enabled or isDowned() then return end
        local c = LocalPlayer.Character; if not c or not c.Parent then return end
        local h = c:FindFirstChildOfClass("Humanoid")
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if not (h and hrp) or h.Health <= 0 then return end
        if h.AutoRotate then Moonwalk.SavedAutoRotate = true; h.AutoRotate = false end
        local ang = math.sin(tick() * Moonwalk.SpamSpeed) * Moonwalk.Intensity
        hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(ang - lastAng), 0)
        lastAng = ang
    end)
end
local function stopMoonwalk()
    if MoonwalkConnection then MoonwalkConnection:Disconnect(); MoonwalkConnection = nil end
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if h and Moonwalk.SavedAutoRotate then h.AutoRotate = true; Moonwalk.SavedAutoRotate = false end
end
local function toggleMoonwalk(s)
    Moonwalk.Enabled = s
    if s then startMoonwalk() else stopMoonwalk() end
    if QuickBtn.Buttons["MOON"] and QuickBtn.Buttons["MOON"].refresh then QuickBtn.Buttons["MOON"].refresh() end
    if ToggleRefs.Moonwalk then
        pcall(function()
            if type(ToggleRefs.Moonwalk.Set) == "function" then ToggleRefs.Moonwalk:Set(s)
            elseif type(ToggleRefs.Moonwalk.set) == "function" then ToggleRefs.Moonwalk:set(s) end
        end)
    end
end

--============================================================
-- QUICK BUTTONS
--============================================================
local function applyButtonVisibility()
    for name, visible in pairs(BtnVis) do
        if QuickBtn.Buttons[name] and QuickBtn.Buttons[name].btn then
            QuickBtn.Buttons[name].btn.Visible = visible
        end
    end
end
local function setUIToggle(refName, value)
    local ref = ToggleRefs[refName]
    if not ref then return end
    pcall(function()
        if type(ref.Set) == "function" then ref:Set(value)
        elseif type(ref.set) == "function" then ref:set(value) end
    end)
end

do
    local sg = Instance.new("ScreenGui")
    sg.Name = "ValzQuick"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    if gethui then pcall(function() sg.Parent = gethui() end) else sg.Parent = PlayerGui end
    QuickBtn.Gui = sg

    local function makeBtn(name, label, getState, setState)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.fromOffset(60, 60)
        btn.BackgroundColor3 = Color3.fromRGB(15, 25, 30); btn.BackgroundTransparency = 0.25
        btn.BorderSizePixel = 0; btn.Text = label
        btn.TextColor3 = Color3.fromRGB(150, 150, 160); btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12; btn.AutoButtonColor = false; btn.Parent = sg
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = btn
        local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(60, 80, 90)
        st.Thickness = 2; st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = btn
        local function update()
            local on = getState()
            if on then
                btn.BackgroundColor3 = Color3.fromRGB(0, 120, 140)
                btn.TextColor3 = Color3.fromRGB(220, 255, 255)
                st.Color = Color3.fromRGB(0, 220, 240)
            else
                btn.BackgroundColor3 = Color3.fromRGB(15, 25, 30)
                btn.TextColor3 = Color3.fromRGB(150, 150, 160)
                st.Color = Color3.fromRGB(60, 80, 90)
            end
        end
        btn.MouseButton1Click:Connect(function()
            local newVal = not getState()
            setState(newVal); update()
        end)
        if name == "AIM" then
            btn.MouseButton1Down:Connect(function() Aim.Holding = true; update() end)
            btn.MouseButton1Up:Connect(function() Aim.Holding = false; update() end)
        end
        local drag, dS, sS = false, nil, nil
        btn.InputBegan:Connect(function(input)
            if LockButtons then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                drag = true; dS = input.Position; sS = btn.Position
                local conn; conn = input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then drag = false; if conn then conn:Disconnect() end end
                end)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if LockButtons then return end
            if not drag then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local d = input.Position - dS
                btn.Position = UDim2.new(sS.X.Scale, sS.X.Offset + d.X, sS.Y.Scale, sS.Y.Offset + d.Y)
            end
        end)
        QuickBtn.Buttons[name] = { btn = btn, refresh = update }
        btn.Position = DEFAULT_BTN_POS[name] or UDim2.new(1, -80, 0.5, 0)
        update()
    end

    makeBtn("SKL", "SKL",
        function() return Auto.SkillCheck end,
        function(v)
            Auto.SkillCheck = v
            if v then startSkillCheck() else stopSkillCheck() end
            setUIToggle("SkillCheck", v)
        end)
    makeBtn("INV", "INV",
        function() return Invisible.Enabled end,
        function(v)
            Invisible.Enabled = v
            if v then applyInvisible(); startEyeBlink() else restoreInvisible() end
            setUIToggle("Invisible", v)
        end)
    makeBtn("PRY", "PRY",
        function() return Auto.Parry end,
        function(v)
            Auto.Parry = v; ParryRangeVisual.Enabled = v
            setUIToggle("AutoParry", v)
            setUIToggle("ShowParryRange", v)
            if QuickBtn.Buttons["PRY"] then QuickBtn.Buttons["PRY"].refresh() end
        end)
    makeBtn("MOON", "MOON",
        function() return Moonwalk.Enabled end,
        function(v) toggleMoonwalk(v) end)
    makeBtn("AIM", "AIM",
        function() return Aim.Holding end,
        function(v) Aim.Holding = v end)

    applyButtonVisibility()
end

--============================================================
-- PARRY
--============================================================
local function isInParryRange(kc)
    local mr = getRoot(); if not mr or not kc then return false end
    local er = kc:FindFirstChild("HumanoidRootPart"); if not er then return false end
    return (er.Position - mr.Position).Magnitude <= Auto.ParryDistance
end
local function getFaceThreshold() return 1.0 - (Auto.FaceStiffness * 0.1) end
local function isFacingTarget(tc)
    local mc = LocalPlayer.Character; if not mc then return false end
    local mr = mc:FindFirstChild("HumanoidRootPart"); local er = tc:FindFirstChild("HumanoidRootPart")
    if not mr or not er then return false end
    local ef = er.CFrame.LookVector; local dm = (mr.Position - er.Position).Unit
    return ef:Dot(dm) >= getFaceThreshold()
end
local parryLocked = false
local function findParryButton()
    local paths = {"Survivor-mob.Controls.Gui-mob","Survivor-mob.Controls","Survivor-mob.Gui-mob"}
    for _, path in ipairs(paths) do
        local cur = PlayerGui
        for seg in string.gmatch(path,"[^%.]+") do cur = cur and cur:FindFirstChild(seg) end
        if cur and cur:IsA("GuiObject") then return cur end
    end
end
local function pressParry()
    if UserInputService.TouchEnabled then
        local b = findParryButton()
        if b then
            local p, s = b.AbsolutePosition, b.AbsoluteSize
            local i = game:GetService("GuiService"):GetGuiInset()
            pcall(function()
                VirtualInputManager:SendTouchEvent(8823,0,p.X+s.X/2+i.X,p.Y+s.Y/2+i.Y); task.wait(0.01)
                VirtualInputManager:SendTouchEvent(8823,2,p.X+s.X/2+i.X,p.Y+s.Y/2+i.Y)
            end)
        end
    else
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(0,0,1,true,game,0); task.wait(0.01)
            VirtualInputManager:SendMouseButtonEvent(0,0,1,false,game,0)
        end)
    end
end
local function doParryBurst()
    if parryLocked then return end
    parryLocked = true
    pressParry()
    task.delay(0.08, function() if Auto.Parry then pressParry() end end)
    task.delay(0.20, function() if Auto.Parry then pressParry() end end)
    task.delay(0.35, function() parryLocked = false end)
end
local function isKillerSwinging(kc)
    local h = kc:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return false end
    local a = h:FindFirstChildOfClass("Animator"); if not a then return false end
    for _, t in ipairs(a:GetPlayingAnimationTracks()) do
        if t.Animation and animMatches(t.Animation.AnimationId) then return true end
    end
    return false
end
local function isKillerTightMelee(kc)
    local h = kc:FindFirstChildOfClass("Humanoid"); local r = kc:FindFirstChild("HumanoidRootPart")
    if not h or not r or h.Health <= 0 then return false end
    local mr = getRoot(); if not mr then return false end
    local d = (r.Position - mr.Position).Magnitude
    if d > 4.0 then return false end
    local el = r.CFrame.LookVector; local dm = (mr.Position - r.Position).Unit
    if el:Dot(dm) < 0.6 then return false end
    return true
end
local function isKillerStationary(kc)
    local r = kc:FindFirstChild("HumanoidRootPart"); if not r then return false end
    local v = r.AssemblyLinearVelocity
    return Vector3.new(v.X, 0, v.Z).Magnitude < 8
end
local function shouldParry(kc)
    if isKillerSwinging(kc) then return true end
    if Auto.ParryMode == "Hybrid" then
        if isKillerTightMelee(kc) and isKillerStationary(kc) then return true end
    end
    return false
end
local hookedKillers = {}
local function hookKiller(char)
    if hookedKillers[char] then return end
    hookedKillers[char] = true
    local h = char:FindFirstChildOfClass("Humanoid"); if not h then return end
    local a = h:FindFirstChildOfClass("Animator")
    if a then
        a.AnimationPlayed:Connect(function(t)
            if not Auto.Parry then return end
            local an = t.Animation; if not an then return end
            if animMatches(an.AnimationId) then
                if not isInParryRange(char) then return end
                if not isFacingTarget(char) then return end
                doParryBurst()
            end
        end)
    end
    task.spawn(function()
        while char.Parent and Auto.Parry do
            task.wait(0.06)
            if not Auto.Parry then break end
            if not isInParryRange(char) then continue end
            if not isFacingTarget(char) then continue end
            if shouldParry(char) then doParryBurst() end
        end
    end)
end
task.spawn(function()
    while task.wait(0.5) do
        if Auto.Parry then
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character and isKillerTeam(p) then hookKiller(p.Character) end
            end
        end
    end
end)
UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if CustomParry.Enabled and i.KeyCode == CustomParry.Key then pressParry() end
end)

--============================================================
-- ESP
--============================================================
local ESPObjects = {}
local function removeESP(obj) if ESPObjects[obj] then ESPObjects[obj]:Destroy(); ESPObjects[obj] = nil end end
workspace.DescendantRemoving:Connect(removeESP)
local function createESP(obj, color)
    if not obj or not obj.Parent then return end
    if ESPObjects[obj] then
        ESPObjects[obj].FillColor = color; ESPObjects[obj].OutlineColor = color; return
    end
    local h = Instance.new("Highlight")
    h.FillColor = color; h.OutlineColor = color
    h.FillTransparency = 0.85; h.OutlineTransparency = 0.2
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = obj
    ESPObjects[obj] = h
end
local ObjCache = { Generators = {}, Pallets = {}, Windows = {} }
task.spawn(function()
    while task.wait(4) do
        if not (ESP.Generator or ESP.Pallet or ESP.Window) then
            ObjCache.Generators = {}; ObjCache.Pallets = {}; ObjCache.Windows = {}; continue
        end
        local gens, pals, wins = {}, {}, {}
        for _, o in ipairs(workspace:GetDescendants()) do
            local n = o.Name
            if n == "Generator" then table.insert(gens, o)
            elseif n == "Pallet" or n == "Palletwrong" then table.insert(pals, o)
            elseif n == "Window" then table.insert(wins, o) end
        end
        ObjCache.Generators = gens; ObjCache.Pallets = pals; ObjCache.Windows = wins
    end
end)
local function GetGameValue(obj, name)
    if not obj then return nil end
    local a = obj:GetAttribute(name); if a ~= nil then return a end
    local c = obj:FindFirstChild(name)
    if c then local ok, v = pcall(function() return c.Value end); if ok then return v end end
    return nil
end
local function UpdateGen(gen)
    if not gen or not gen.Parent then return end
    if not ESP.Generator then
        local o = gen:FindFirstChild("GenESP"); if o then o:Destroy() end
        local h = gen:FindFirstChild("GenHighlight"); if h then h:Destroy() end
        return
    end
    local pct = GetGameValue(gen,"RepairProgress") or GetGameValue(gen,"Progress") or 0
    local b = gen:FindFirstChild("GenESP")
    if pct >= 100 then if b then b:Destroy() end; return end
    local cp = math.clamp(pct,0,100)
    local col = GenColor:Lerp(Color3.fromRGB(0,255,120), cp/100)
    if not b then
        b = Instance.new("BillboardGui"); b.Name = "GenESP"
        b.Size = UDim2.new(0,100,0,30); b.AlwaysOnTop = true
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1,0,1,0); l.BackgroundTransparency = 1
        l.Text = string.format("[%.0f%%]", pct); l.TextColor3 = col
        l.TextStrokeTransparency = 0; l.Font = Enum.Font.GothamBold; l.TextSize = 12
        l.Parent = b; b.Adornee = gen; b.Parent = gen
    else
        local l = b:FindFirstChildOfClass("TextLabel")
        if l then l.Text = string.format("[%.0f%%]", pct); l.TextColor3 = col end
    end
    local h = gen:FindFirstChild("GenHighlight") or Instance.new("Highlight")
    h.Name = "GenHighlight"; h.Adornee = gen
    h.FillColor = col; h.OutlineColor = col
    h.FillTransparency = 0.9; h.OutlineTransparency = 0.3
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; h.Parent = gen
end
local function UpdateMapESP(obj, root, name)
    if not obj or not obj.Parent or not root then return end
    local pos = obj:IsA("Model") and obj:GetPivot().Position or (obj:IsA("BasePart") and obj.Position)
    if not pos then return end
    local d = (pos - root.Position).Magnitude
    if d > ESP.Distance then removeESP(obj); return end
    if name == "Window" then
        if ESP.Window then createESP(obj, WinColor) else removeESP(obj) end
    elseif name == "Pallet" or name == "Palletwrong" then
        if ESP.Pallet then createESP(obj, PalColor) else removeESP(obj) end
    end
end

--============================================================
-- OTHER FEATURES
--============================================================
local function AutoWiggle()
    if not Auto.Wiggle then return end
    local c = LocalPlayer.Character; if not c then return end
    local carried = (c:FindFirstChild("IsCarried") and c.IsCarried.Value) or (c:FindFirstChild("IsCarrying") and c.IsCarrying.Value)
    if not carried then return end
    local rem = ReplicatedStorage:FindFirstChild("Remotes"); if not rem then return end
    local ca = rem:FindFirstChild("Carry"); if not ca then return end
    local ev = ca:FindFirstChild("SelfUnHookEvent"); if not ev then return end
    for i = 1, Auto.WiggleSpam do ev:FireServer() end
end
local function GetNearestKiller()
    local root = getRoot(); if not root then return nil end
    local closest, shortest = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isKillerTeam(p) and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (hrp.Position - root.Position).Magnitude
                if d < shortest then shortest = d; closest = hrp end
            end
        end
    end
    return closest, shortest
end
local function GetFarGenPoint(kRoot)
    if not kRoot then return nil end
    local bp, fd = nil, 0
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("BasePart") and string.match(o.Name,"^GeneratorPoint%d+$") then
            local d = (o.Position - kRoot.Position).Magnitude
            if d > fd then fd = d; bp = o end
        end
    end
    return bp
end
task.spawn(function()
    while task.wait(0.2) do
        if not AutoFlee.Enabled then continue end
        local root = getRoot(); if not root then continue end
        local kr, d = GetNearestKiller()
        if kr and d <= AutoFlee.DetectDistance and tick() - LastFlee > AutoFlee.Cooldown then
            local pt = GetFarGenPoint(kr)
            if pt then LastFlee = tick(); root.CFrame = pt.CFrame + Vector3.new(0,5,0) end
        end
    end
end)
local StalkConn = nil
local function startAutoStalk()
    if StalkConn then return end
    StalkConn = RunService.Heartbeat:Connect(function()
        if not AutoStalk.Enabled then return end
        local root = getRoot(); if not root then return end
        local cl, sh = nil, math.huge
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local h = p.Character:FindFirstChildOfClass("Humanoid")
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if h and hrp and h.Health > 30 then
                    local d = (hrp.Position - root.Position).Magnitude
                    if d <= AutoStalk.StalkRange and d < sh then sh = d; cl = p end
                end
            end
        end
        if cl then
            local ev = ReplicatedStorage:FindFirstChild("Remotes",true) and ReplicatedStorage.Remotes:FindFirstChild("Killers",true)
                and ReplicatedStorage.Remotes.Killers:FindFirstChild("Stalker",true)
                and ReplicatedStorage.Remotes.Killers.Stalker:FindFirstChild("StartStalking")
            if ev then pcall(function() ev:FireServer(cl) end) end
        end
    end)
end
local function stopAutoStalk() if StalkConn then StalkConn:Disconnect(); StalkConn = nil end end

local lastAlert = 0
local killerHUD = Instance.new("ScreenGui")
killerHUD.Name = "ValzKillerHUD"; killerHUD.ResetOnSpawn = false
killerHUD.IgnoreGuiInset = true; killerHUD.Enabled = false
if gethui then pcall(function() killerHUD.Parent = gethui() end) else killerHUD.Parent = PlayerGui end
local killerLabel = Instance.new("TextLabel")
killerLabel.Size = UDim2.fromOffset(280,30); killerLabel.Position = UDim2.new(0.5,-140,0,100)
killerLabel.BackgroundColor3 = Color3.fromRGB(0,0,0); killerLabel.BackgroundTransparency = 0.5
killerLabel.TextColor3 = Color3.fromRGB(255,60,60); killerLabel.Font = Enum.Font.GothamBold
killerLabel.TextSize = 14; killerLabel.Text = "KILLER: --"; killerLabel.Parent = killerHUD
local kcL = Instance.new("UICorner"); kcL.CornerRadius = UDim.new(0,8); kcL.Parent = killerLabel
local killerArrow = Instance.new("TextLabel")
killerArrow.Size = UDim2.fromOffset(60,60); killerArrow.BackgroundTransparency = 1
killerArrow.TextColor3 = Color3.fromRGB(255,60,60); killerArrow.Font = Enum.Font.GothamBlack
killerArrow.TextSize = 40; killerArrow.Text = "▲"; killerArrow.AnchorPoint = Vector2.new(0.5,0.5)
killerArrow.Position = UDim2.new(0.5,0,0.5,-150); killerArrow.Parent = killerHUD
local function playAlertSound(id)
    pcall(function()
        local s = Instance.new("Sound"); s.SoundId = "rbxassetid://"..id; s.Volume = 1.5
        s.Parent = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or Camera
        s:Play(); game:GetService("Debris"):AddItem(s, 3)
    end)
end
RunService.Heartbeat:Connect(function()
    local mr = getRoot(); if not mr then return end
    local kr, d = GetNearestKiller()
    if not kr then return end
    if Safety.ProximityAlert and d and d <= Safety.AlertDistance then
        local now = tick()
        if now - lastAlert > 1.5 then
            lastAlert = now; playAlertSound("9114930439")
            Rayfield:Notify({Title="KILLER DEKAT", Content=string.format("%.0f studs", d), Duration=2})
        end
    end
    if Safety.AutoDodge and d and d <= Safety.DodgeDistance then
        if isDowned() then return end
        local mh = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if not mh then return end
        local aw = (mr.Position - kr.Position)
        if aw.Magnitude > 0.5 then aw = Vector3.new(aw.X,0,aw.Z).Unit; mh:Move(aw, false) end
    end
end)
task.spawn(function()
    while task.wait(0.15) do
        if not Killer.KillAura then continue end
        local root = getRoot(); if not root then continue end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and isSurvivorTeam(p) then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - root.Position).Magnitude < Killer.KillAuraRange then
                    pcall(function() AttackEvent:FireServer(false) end); break
                end
            end
        end
    end
end)
RunService.Heartbeat:Connect(function()
    applyGodMode()
    AutoWiggle()
    if Killer.AutoAttack then pcall(function() AttackEvent:FireServer(false) end) end
    if Killer.AutoCarry and not KillerBusy then
        KillerBusy = true
        task.spawn(function()
            local t = GetDowned(); local root = getRoot()
            if t and root then
                local tr = t:FindFirstChild("HumanoidRootPart")
                if tr then
                    root.CFrame = tr.CFrame * CFrame.new(0,3,-2); task.wait(0.4)
                    for i=1,4 do CarryEvent:FireServer(t); task.wait(0.2) end
                    task.wait(0.6)
                    local hk = GetHook()
                    if hk then
                        root.CFrame = hk.CFrame * CFrame.new(0,4,-3); task.wait(0.7)
                        for i=1,6 do HookEvent:FireServer(hk); task.wait(0.15) end
                    end
                end
            end
            task.wait(2); KillerBusy = false
        end)
    end
    if Killer.KillAll then
        local root = getRoot()
        if root then
            if not KillerTarget or not KillerTarget:FindFirstChild("Humanoid") or KillerTarget.Humanoid.Health <= 35 then
                local b, d0 = nil, math.huge
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        local h = p.Character:FindFirstChildOfClass("Humanoid"); local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if h and hrp and h.Health > 30 then
                            local d = (hrp.Position - root.Position).Magnitude
                            if d < d0 then d0 = d; b = p.Character end
                        end
                    end
                end
                KillerTarget = b
            end
            if KillerTarget then
                local tr = KillerTarget:FindFirstChild("HumanoidRootPart")
                if tr then
                    local tp = tr.Position + tr.AssemblyLinearVelocity * 0.15
                    local bh = tr.CFrame.LookVector * -3
                    root.CFrame = CFrame.new(tp + bh, tp)
                end
                pcall(function() AttackEvent:FireServer(false) end)
            end
        end
    end
end)
local function hookVault(c)
    local h = c:FindFirstChildOfClass("Humanoid"); if not h then return end
    local a = h:FindFirstChildOfClass("Animator"); if not a then return end
    a.AnimationPlayed:Connect(function(t)
        if not FastVault.Enabled then return end
        local an = t.Animation; if not an or not an.AnimationId then return end
        local id = normalizeId(an.AnimationId); if not id then return end
        local rid = FastVault.ReplaceMap[id]; if not rid then return end
        if VaultTracks[t] then return end
        VaultTracks[t] = true; t:Stop()
        local na = Instance.new("Animation"); na.AnimationId = rid
        local nt = a:LoadAnimation(na); nt.Priority = Enum.AnimationPriority.Action
        nt:Play(); nt:AdjustSpeed(FastVault.Speed)
        nt.Stopped:Connect(function() VaultTracks[t] = nil end)
    end)
end
LocalPlayer.CharacterAdded:Connect(function(c) task.wait(0.5); hookVault(c) end)
if LocalPlayer.Character then hookVault(LocalPlayer.Character) end

local LastVisual = { Fullbright=nil, NoShadow=nil, NoFog=nil }
local function applyVisualIfChanged()
    if LastVisual.Fullbright ~= Visual.Fullbright then
        LastVisual.Fullbright = Visual.Fullbright
        if Visual.Fullbright then
            Lighting.Brightness = 2; Lighting.ClockTime = 14
            Lighting.Ambient = Color3.new(1,1,1); Lighting.OutdoorAmbient = Color3.new(1,1,1)
        else
            Lighting.Brightness = original.Brightness; Lighting.ClockTime = original.ClockTime
            Lighting.Ambient = original.Ambient; Lighting.OutdoorAmbient = original.OutdoorAmbient
        end
    end
    if LastVisual.NoShadow ~= Visual.NoShadow then
        LastVisual.NoShadow = Visual.NoShadow
        Lighting.GlobalShadows = not Visual.NoShadow
    end
    if LastVisual.NoFog ~= Visual.NoFog then
        LastVisual.NoFog = Visual.NoFog
        if Visual.NoFog then
            Lighting.FogEnd = 1e6; Lighting.FogStart = 1e6
            pcall(function() Lighting.EnvironmentDiffuseScale = 0; Lighting.EnvironmentSpecularScale = 0 end)
            for _, v in ipairs(Lighting:GetChildren()) do
                if v:IsA("Atmosphere") then pcall(function() v.Density = 0 end) end
            end
        else
            Lighting.FogEnd = original.FogEnd or 100000
            Lighting.FogStart = original.FogStart or 0
            Lighting.FogColor = original.FogColor or Color3.fromRGB(192,192,192)
        end
    end
end
local LastCHStyle, chCreated = nil, false
local function clearCH() for _, v in pairs(CrosshairDrawings) do if v.Remove then v:Remove() end end CrosshairDrawings = {} end
local function drawCH()
    if not Drawing or not Drawing.new then return end
    if not Crosshair.Enabled then for _, v in pairs(CrosshairDrawings) do v.Visible = false end return end
    if LastCHStyle ~= Crosshair.Style then clearCH(); chCreated = false; LastCHStyle = Crosshair.Style end
    local cam = workspace.CurrentCamera; if not cam then return end
    local center = Vector2.new(cam.ViewportSize.X/2 + Crosshair.OffsetX, cam.ViewportSize.Y/2 + Crosshair.OffsetY)
    if not chCreated then
        chCreated = true
        if Crosshair.Style == "Plus" then
            for i=1,4 do local l = Drawing.new("Line"); l.Visible = true; table.insert(CrosshairDrawings, l) end
        elseif Crosshair.Style == "Dot" then
            local d = Drawing.new("Circle"); d.Filled = true; d.Visible = true; table.insert(CrosshairDrawings, d)
        elseif Crosshair.Style == "Circle" then
            local c = Drawing.new("Circle"); c.Filled = false; c.Visible = true; table.insert(CrosshairDrawings, c)
        end
    end
    if Crosshair.Style == "Plus" then
        for _, l in pairs(CrosshairDrawings) do l.Color = Crosshair.Color; l.Thickness = Crosshair.Thickness; l.Visible = true end
        CrosshairDrawings[1].From = center + Vector2.new(-Crosshair.Size,0); CrosshairDrawings[1].To = center + Vector2.new(-2,0)
        CrosshairDrawings[2].From = center + Vector2.new(Crosshair.Size,0); CrosshairDrawings[2].To = center + Vector2.new(2,0)
        CrosshairDrawings[3].From = center + Vector2.new(0,-Crosshair.Size); CrosshairDrawings[3].To = center + Vector2.new(0,-2)
        CrosshairDrawings[4].From = center + Vector2.new(0,Crosshair.Size); CrosshairDrawings[4].To = center + Vector2.new(0,2)
    elseif Crosshair.Style == "Dot" then
        CrosshairDrawings[1].Position = center; CrosshairDrawings[1].Radius = Crosshair.Size/2; CrosshairDrawings[1].Color = Crosshair.Color
    elseif Crosshair.Style == "Circle" then
        CrosshairDrawings[1].Position = center; CrosshairDrawings[1].Radius = Crosshair.Size
        CrosshairDrawings[1].Color = Crosshair.Color; CrosshairDrawings[1].Thickness = Crosshair.Thickness
    end
end
local function updateParryCircle()
    local root = getRoot()
    if not ParryRangeVisual.Enabled or not root then
        if ParryCircle then ParryCircle:Destroy(); ParryCircle = nil end; return
    end
    if not ParryCircle then
        ParryCircle = Instance.new("Part")
        ParryCircle.Shape = Enum.PartType.Cylinder; ParryCircle.Anchored = true
        ParryCircle.CanCollide = false; ParryCircle.Material = Enum.Material.Neon
        ParryCircle.Name = "ParryRangeCircle"; ParryCircle.Parent = workspace
    end
    local size = Auto.ParryDistance*2
    ParryCircle.Size = Vector3.new(0.2,size,size)
    local yo = root.Size.Y/2 + 1.5
    ParryCircle.CFrame = CFrame.new(root.Position - Vector3.new(0,yo,0)) * CFrame.Angles(0,0,math.rad(90))
    ParryCircle.Color = ParryRangeColor; ParryCircle.Transparency = 0.9
end
local lastESP, lastHUD, lastGen = 0, 0, 0
RunService.RenderStepped:Connect(function()
    applyVisualIfChanged()
    drawCH()
    updateParryCircle()
    if CameraZoom.FOVEnabled then
        local cam = workspace.CurrentCamera
        if cam and cam.FieldOfView ~= CameraZoom.FOV then cam.FieldOfView = CameraZoom.FOV end
    end
    local now = tick()
    if now - lastHUD >= 0.15 then
        lastHUD = now
        if not NewFeatures.KillerHUD and not NewFeatures.KillerArrow then
            killerHUD.Enabled = false
        else
            killerHUD.Enabled = true
            if NewFeatures.KillerHUD then
                killerLabel.Visible = true
                local _, d = GetNearestKiller()
                if d then
                    killerLabel.Text = string.format("KILLER: %.0f STUDS", d)
                    killerLabel.TextColor3 = d < 20 and Color3.fromRGB(255,0,0) or d < 50 and Color3.fromRGB(255,180,0) or Color3.fromRGB(255,255,100)
                else killerLabel.Text = "KILLER: ??"; killerLabel.TextColor3 = Color3.fromRGB(150,150,150) end
            else killerLabel.Visible = false end
            if NewFeatures.KillerArrow then
                killerArrow.Visible = true
                local mr = getRoot()
                if not mr then killerArrow.TextTransparency = 1 else
                    local kr = GetNearestKiller()
                    if not kr then killerArrow.TextTransparency = 1 else
                        killerArrow.TextTransparency = 0
                        local cam = workspace.CurrentCamera
                        local cl = cam.CFrame.LookVector
                        local tk = (kr.Position - mr.Position); tk = Vector3.new(tk.X,0,tk.Z).Unit
                        local fl = Vector3.new(cl.X,0,cl.Z).Unit
                        local ang = math.deg(math.atan2(tk.X,tk.Z) - math.atan2(fl.X,fl.Z))
                        killerArrow.Rotation = ang + 180
                    end
                end
            else killerArrow.Visible = false end
        end
    end
    if now - lastESP >= 0.2 then
        lastESP = now
        if ESP.Survivor or ESP.Killer then
            local root = getRoot()
            if root then
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        local char = p.Character
                        local h = char:FindFirstChildOfClass("Humanoid")
                        if h and h.Health > 0 then
                            local hrp = char:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                local d = (hrp.Position - root.Position).Magnitude
                                if d <= ESP.Distance then
                                    if ESP.Survivor and isSurvivorTeam(p) then createESP(char, TeamColors.Survivor)
                                    elseif ESP.Killer and isKillerTeam(p) then createESP(char, TeamColors.Killer)
                                    else removeESP(char) end
                                else removeESP(char) end
                            end
                        else removeESP(char) end
                    end
                end
            end
        end
        if (ESP.Pallet or ESP.Window) and getRoot() then
            local root = getRoot()
            for _, o in ipairs(ObjCache.Pallets) do UpdateMapESP(o, root, o.Name) end
            for _, o in ipairs(ObjCache.Windows) do UpdateMapESP(o, root, o.Name) end
        end
    end
    if ESP.Generator and now - lastGen >= 0.4 then
        lastGen = now
        for _, gen in ipairs(ObjCache.Generators) do UpdateGen(gen) end
    end
end)

--============================================================
-- AIM
--============================================================
local RayP = RaycastParams.new(); RayP.FilterType = Enum.RaycastFilterType.Blacklist
local function isVisAim(p)
    local cam = workspace.CurrentCamera
    RayP.FilterDescendantsInstances = { LocalPlayer.Character }
    local o = cam.CFrame.Position
    local r = workspace:Raycast(o, p.Position - o, RayP)
    return not r or r.Instance:IsDescendantOf(p.Parent)
end
local AimCamConn = nil
local function startAim()
    if AimCamConn then AimCamConn:Disconnect() end
    AimCamConn = RunService.RenderStepped:Connect(function()
        if not Aim.Enabled or not Aim.Holding then return end
        local cam = workspace.CurrentCamera
        local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
        local cl, sh = nil, Aim.FOV
        if Aim.TargetMode == "Killer" or Aim.TargetMode == "Survivor" then
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    local match = (Aim.TargetMode == "Killer" and isKillerTeam(p)) or (Aim.TargetMode == "Survivor" and isSurvivorTeam(p))
                    if match then
                        local hrp = p.Character:FindFirstChild(Aim.AimPart); local h = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and h and h.Health > 0 then
                            local pos, vis = cam:WorldToViewportPoint(hrp.Position)
                            if vis then
                                local d = (Vector2.new(pos.X,pos.Y) - center).Magnitude
                                if d < sh then
                                    if Aim.WallCheck and not isVisAim(hrp) then continue end
                                    sh = d; cl = hrp
                                end
                            end
                        end
                    end
                end
            end
        end
        if not cl then return end
        local pos = cl.Position
        if Aim.Predict then pos = pos + (cl.AssemblyLinearVelocity * Aim.PredictStrength) end
        cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, pos), Aim.Strength)
    end)
end
UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.UserInputType == Enum.UserInputType.MouseButton2 then Aim.Holding = true end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton2 then Aim.Holding = false end
end)
startAim()
startLaser()

--============================================================
-- FPS BOOST
--============================================================
local potOrig = setmetatable({}, {__mode = "k"})
local potatoDone = setmetatable({}, {__mode = "k"})
local potConnW, potConnL = nil, nil
local potatoActive = false
local function saveP(o, p)
    local t = potOrig[o]; if not t then t = {}; potOrig[o] = t end
    if t[p] == nil then pcall(function() t[p] = o[p] end) end
end
local function killObject(o)
    if not o or not o.Parent or potatoDone[o] then return end
    if LocalPlayer.Character and o:IsDescendantOf(LocalPlayer.Character) then return end
    potatoDone[o] = true
    pcall(function()
        if o:IsA("BasePart") or o:IsA("MeshPart") then
            saveP(o, "Material"); o.Material = Enum.Material.SmoothPlastic
            saveP(o, "MaterialVariant"); o.MaterialVariant = ""
            saveP(o, "Reflectance"); o.Reflectance = 0
            saveP(o, "CastShadow"); o.CastShadow = false
            if o:IsA("MeshPart") and o.TextureID and o.TextureID ~= "" then
                saveP(o, "TextureID"); pcall(function() o.TextureID = "" end)
            end
            for _, ch in ipairs(o:GetChildren()) do
                if ch:IsA("SurfaceAppearance") then saveP(ch, "Enabled"); ch.Enabled = false
                elseif ch:IsA("Decal") or ch:IsA("Texture") then saveP(ch, "Transparency"); ch.Transparency = 1 end
            end
        elseif o:IsA("Decal") or o:IsA("Texture") then
            saveP(o, "Transparency"); o.Transparency = 1
        elseif o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Beam")
            or o:IsA("Smoke") or o:IsA("Fire") or o:IsA("Sparkles") then
            saveP(o, "Enabled"); o.Enabled = false
            if o:IsA("ParticleEmitter") then saveP(o, "Rate"); o.Rate = 0 end
        elseif o:IsA("PostEffect") or o:IsA("Light") then
            saveP(o, "Enabled"); o.Enabled = false
        end
    end)
end
local function enablePotato()
    if potatoActive then return end
    potatoActive = true
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1e6; Lighting.FogStart = 1e6
        Lighting.Brightness = 2
        Lighting.OutdoorAmbient = Color3.fromRGB(200,200,200)
        Lighting.Ambient = Color3.fromRGB(180,180,180)
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
        Lighting.ShadowSoftness = 0
        Lighting.ClockTime = 14
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("Sky") or v:IsA("Atmosphere") or v:IsA("Clouds")
            or v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect")
            or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") then
                pcall(function() v.Parent = nil end)
            end
        end
    end)
    task.spawn(function()
        local parts = workspace:GetDescendants()
        for i, o in ipairs(parts) do
            if not potatoActive then break end
            killObject(o)
            if i % 500 == 0 then task.wait() end
        end
    end)
    potConnW = workspace.DescendantAdded:Connect(function(o)
        if potatoActive then task.defer(function() if potatoActive and o.Parent then killObject(o) end end) end
    end)
    potConnL = Lighting.DescendantAdded:Connect(function(o)
        if potatoActive and (o:IsA("Sky") or o:IsA("Atmosphere") or o:IsA("PostEffect")) then
            task.defer(function() if potatoActive then pcall(function() o.Parent = nil end) end end)
        end
    end)
    Rayfield:Notify({Title="FPS Boost", Content="ON", Duration=3})
end
local function disablePotato()
    potatoActive = false
    if potConnW then potConnW:Disconnect(); potConnW = nil end
    if potConnL then potConnL:Disconnect(); potConnL = nil end
    for o, props in pairs(potOrig) do
        if typeof(o) == "Instance" and o.Parent then
            for p, v in pairs(props) do pcall(function() o[p] = v end) end
        end
    end
    potOrig = setmetatable({}, {__mode = "k"}); potatoDone = setmetatable({}, {__mode = "k"})
    Rayfield:Notify({Title="FPS Boost", Content="OFF", Duration=3})
end

-- FPS counter
local fpsGui = Instance.new("ScreenGui")
fpsGui.Name = "ValzFPS"; fpsGui.ResetOnSpawn = false
fpsGui.IgnoreGuiInset = true; fpsGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
if gethui then pcall(function() fpsGui.Parent = gethui() end) else fpsGui.Parent = PlayerGui end
local fpsLbl = Instance.new("TextLabel")
fpsLbl.Name = "FPS"; fpsLbl.BackgroundTransparency = 1
fpsLbl.Size = UDim2.fromOffset(140,26); fpsLbl.Position = UDim2.new(1,-150,0.5,-13)
fpsLbl.Font = Enum.Font.GothamBold; fpsLbl.TextSize = 16
fpsLbl.TextColor3 = Color3.fromRGB(0,220,240); fpsLbl.TextXAlignment = Enum.TextXAlignment.Right
fpsLbl.Text = "FPS: 0"; fpsLbl.Parent = fpsGui
do
    local fr, lt = 0, tick()
    RunService.RenderStepped:Connect(function()
        fr += 1; local n = tick()
        if n - lt >= 0.5 then
            fpsLbl.Text = "FPS: "..math.floor(fr/(n-lt)+0.5)
            fpsLbl.TextColor3 = Color3.fromHSV((tick()*0.35)%1,1,1)
            fr, lt = 0, n
        end
    end)
end

-- Emote
local Emote = { Selected = "Mannrobics" }
local EmoteList = {"Mannrobics","Arm Swing","Schadenfreude","Kyoufuu","Backflip","Griddy","Friday Night","Floating Rest","OnePlays","Quick Combo","WarCry","Wave"}
local EmoteRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EmoteHandler")
local EmoteBtnGui = nil
local function playEmote(n) pcall(function() EmoteRemote:FireServer(n) end) end
local function createEmoteBtn()
    if EmoteBtnGui then EmoteBtnGui:Destroy() end
    local g = Instance.new("ScreenGui"); g.Name = "EmoteGui"; g.ResetOnSpawn = false; g.Parent = PlayerGui
    local b = Instance.new("ImageButton")
    b.Size = UDim2.new(0,50,0,50); b.Position = UDim2.new(0.55,0,0.75,0)
    b.BackgroundColor3 = Color3.fromRGB(255,255,255); b.BackgroundTransparency = 0.9
    b.Image = "rbxassetid://93349170559446"; b.ImageTransparency = 0.1; b.Parent = g
    local co = Instance.new("UICorner"); co.CornerRadius = UDim.new(1,0); co.Parent = b
    b.MouseButton1Click:Connect(function() playEmote(Emote.Selected) end)
    EmoteBtnGui = g
end
local function removeEmoteBtn() if EmoteBtnGui then EmoteBtnGui:Destroy(); EmoteBtnGui = nil end end

-- Anti AFK + Server
local antiAFKConn = nil
local function startAntiAfk()
    if antiAFKConn then antiAFKConn:Disconnect(); antiAFKConn = nil end
    antiAFKConn = LocalPlayer.Idled:Connect(function()
        if not Utility.AntiAFK then return end
        pcall(function() local VU = game:GetService("VirtualUser"); VU:CaptureController(); VU:ClickButton2(Vector2.new()) end)
    end)
end
local function serverHop()
    Rayfield:Notify({Title="Server Hop", Content="Cari server...", Duration=3})
    pcall(function()
        local req = request or http_request or syn_request
        if not req then return end
        local url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
        local data = HttpService:JSONDecode(req({Url=url, Method="GET"}).Body).data
        for _, s in ipairs(data) do
            if s.id ~= game.JobId and s.playing < s.maxPlayers then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer); return
            end
        end
    end)
end
local function rejoin() TeleportService:Teleport(game.PlaceId, LocalPlayer) end
local function tpToNearest(name)
    local root = getRoot(); if not root then return end
    local b, d0 = nil, math.huge
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("BasePart") or o:IsA("Model") then
            if string.find(string.lower(o.Name), string.lower(name)) then
                local pos = o:IsA("Model") and o:GetPivot().Position or o.Position
                local d = (pos - root.Position).Magnitude
                if d < d0 then d0 = d; b = o end
            end
        end
    end
    if b then
        local pos = b:IsA("Model") and b:GetPivot().Position or b.Position
        root.CFrame = CFrame.new(pos + Vector3.new(0,4,0))
        Rayfield:Notify({Title="TP", Content="To "..b.Name, Duration=2})
    end
end
local function teleportToFinishLine()
    local root = getRoot(); if not root then return end
    for _, o in ipairs(workspace:GetDescendants()) do
        if string.lower(o.Name) == "fininshline" and o:IsA("BasePart") then root.CFrame = o.CFrame + Vector3.new(0,5,0); break end
    end
end
task.spawn(function()
    while task.wait(2) do
        if not NewFeatures.CharacterReset then continue end
        if isDowned() then
            local c = LocalPlayer.Character
            if c then local h = c:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h.Health = 0 end) end end
        end
    end
end)
task.spawn(function()
    while task.wait(1) do
        if not NewFeatures.AutoMedkit then continue end
        local c = LocalPlayer.Character; if not c then continue end
        local h = c:FindFirstChildOfClass("Humanoid"); if not h then continue end
        if h.Health >= h.MaxHealth*0.6 then continue end
        for _, tool in ipairs(c:GetChildren()) do
            if tool:IsA("Tool") and string.find(string.lower(tool.Name),"med") then tool:Activate(); break end
        end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then
            for _, tool in ipairs(bp:GetChildren()) do
                if tool:IsA("Tool") and string.find(string.lower(tool.Name),"med") then
                    pcall(function() h:EquipTool(tool) end); task.wait(0.3); tool:Activate(); break
                end
            end
        end
    end
end)

--============================================================
-- UI BUILD
--============================================================
Tabs.Info:CreateSection("Script Info")
Tabs.Info:CreateLabel("Script: ValzZHub v4.0")
Tabs.Info:CreateLabel("Game: Violence District")

Tabs.Survivor:CreateSection("Aim (hold)")
Tabs.Survivor:CreateToggle({Name="Enable Aim",CurrentValue=false,Callback=function(v) Aim.Enabled = v end})
Tabs.Survivor:CreateDropdown({Name="Target",Options={"Killer","Survivor"},CurrentOption={"Killer"},Callback=function(o) Aim.TargetMode = type(o)=="table" and o[1] or o end})
Tabs.Survivor:CreateDropdown({Name="Aim Part",Options={"Head","HumanoidRootPart","Torso"},CurrentOption={"HumanoidRootPart"},Callback=function(o) Aim.AimPart = type(o)=="table" and o[1] or o end})
Tabs.Survivor:CreateSlider({Name="FOV",Range={50,1000},Increment=10,Suffix="px",CurrentValue=250,Callback=function(v) Aim.FOV = v end})
Tabs.Survivor:CreateSlider({Name="Predict",Range={0,100},Increment=1,Suffix=" /100",CurrentValue=12,Callback=function(v) Aim.PredictStrength = v/100 end})
Tabs.Survivor:CreateSlider({Name="Smoothness",Range={1,100},Increment=1,Suffix=" /100",CurrentValue=100,Callback=function(v) Aim.Strength = v/100 end})
Tabs.Survivor:CreateToggle({Name="Wall Check",CurrentValue=true,Callback=function(v) Aim.WallCheck = v end})
Tabs.Survivor:CreateToggle({Name="Show AIM Button",CurrentValue=true,Callback=function(v) BtnVis.AIM = v; applyButtonVisibility() end})

Tabs.Survivor:CreateSection("ESP Laser")
Tabs.Survivor:CreateToggle({Name="Enable ESP Laser",CurrentValue=false,Callback=function(v) LaserESP.Enabled = v end})
Tabs.Survivor:CreateColorPicker({Name="Laser Color",Color=Color3.fromRGB(255,50,50),Callback=function(c) LaserESP.Color = c end})
Tabs.Survivor:CreateSlider({Name="Laser Thickness",Range={1,6},Increment=1,CurrentValue=2,Callback=function(v) LaserESP.Thickness = v end})
Tabs.Survivor:CreateSlider({Name="Laser Transparency",Range={0,100},Increment=5,CurrentValue=20,Callback=function(v) LaserESP.Transparency = v/100 end})

Tabs.Survivor:CreateSection("Fake Perks")
Tabs.Survivor:CreateToggle({Name="Enable Fake Perks HUD",CurrentValue=false,Callback=function(v)
    FakePerks.Enabled = v
    if v then buildFakePerkHUD(); FakePerks.Gui.Enabled = true; rebuildPerkSlots()
    else if FakePerks.Gui then FakePerks.Gui.Enabled = false end end
end})
Tabs.Survivor:CreateToggle({Name="Flowstate",CurrentValue=false,Callback=function(v)
    FakePerks.Flowstate = v
    if v and FakePerks.Enabled then PerkState.flowBuffUntil = tick() + 5 end
    rebuildPerkSlots()
end})
Tabs.Survivor:CreateToggle({Name="Quick Recovery",CurrentValue=false,Callback=function(v)
    FakePerks.QuickRecovery = v
    if v and FakePerks.Enabled then PerkState.quickBuffUntil = tick() + 3 end
    rebuildPerkSlots()
end})
Tabs.Survivor:CreateToggle({Name="Perfect Landing",CurrentValue=false,Callback=function(v)
    FakePerks.PerfectLanding = v
    if v and FakePerks.Enabled then PerkState.landingBuffUntil = tick() + 3 end
    rebuildPerkSlots()
end})
Tabs.Survivor:CreateToggle({Name="Adrenaline Rush",CurrentValue=false,Callback=function(v)
    FakePerks.AdrenalineRush = v
    rebuildPerkSlots()
end})
Tabs.Survivor:CreateButton({Name="Enable All Fake Perks",Callback=function()
    FakePerks.Flowstate = true; FakePerks.QuickRecovery = true
    FakePerks.PerfectLanding = true; FakePerks.AdrenalineRush = true
    if not FakePerks.Enabled then FakePerks.Enabled = true; buildFakePerkHUD(); FakePerks.Gui.Enabled = true end
    rebuildPerkSlots()
end})
Tabs.Survivor:CreateButton({Name="Disable All Fake Perks",Callback=function()
    FakePerks.Flowstate = false; FakePerks.QuickRecovery = false
    FakePerks.PerfectLanding = false; FakePerks.AdrenalineRush = false
    rebuildPerkSlots()
end})

Tabs.Survivor:CreateSection("Auto Parry")
local parryToggle = Tabs.Survivor:CreateToggle({Name="Auto Parry",CurrentValue=false,Callback=function(v)
    Auto.Parry = v
    ParryRangeVisual.Enabled = v
    if QuickBtn.Buttons["PRY"] and QuickBtn.Buttons["PRY"].refresh then QuickBtn.Buttons["PRY"].refresh() end
    if ToggleRefs.ShowParryRange then
        pcall(function()
            if type(ToggleRefs.ShowParryRange.Set) == "function" then ToggleRefs.ShowParryRange:Set(v)
            elseif type(ToggleRefs.ShowParryRange.set) == "function" then ToggleRefs.ShowParryRange:set(v) end
        end)
    end
end})
ToggleRefs.AutoParry = parryToggle
Tabs.Survivor:CreateDropdown({Name="Parry Mode",Options={"Strict","Hybrid"},CurrentOption={"Hybrid"},Callback=function(o)
    Auto.ParryMode = type(o)=="table" and o[1] or o
end})
Tabs.Survivor:CreateSlider({Name="Face Stiffness (1 = recommend)",Range={1,2},Increment=0.1,Suffix="",CurrentValue=1,Callback=function(v) Auto.FaceStiffness = v end})
local showParryToggle = Tabs.Survivor:CreateToggle({Name="Show Parry Range",CurrentValue=false,Callback=function(v)
    ParryRangeVisual.Enabled = v
    if not v and ParryCircle then ParryCircle:Destroy(); ParryCircle = nil end
end})
ToggleRefs.ShowParryRange = showParryToggle
Tabs.Survivor:CreateColorPicker({Name="Parry Range Color",Color=Color3.fromRGB(255,80,80),Callback=function(c) ParryRangeColor = c end})
Tabs.Survivor:CreateSlider({Name="Parry Radius",Range={3,25},Increment=1,Suffix=" studs",CurrentValue=8,Callback=function(v) Auto.ParryDistance = v end})
Tabs.Survivor:CreateToggle({Name="Show PRY Button",CurrentValue=true,Callback=function(v) BtnVis.PRY = v; applyButtonVisibility() end})

Tabs.Survivor:CreateSection("Auto Skill Check")
local skillToggle = Tabs.Survivor:CreateToggle({Name="Enable Auto Skill Check (Perfect)",CurrentValue=false,Callback=function(v)
    Auto.SkillCheck = v
    if v then startSkillCheck() else stopSkillCheck() end
    if QuickBtn.Buttons["SKL"] and QuickBtn.Buttons["SKL"].refresh then QuickBtn.Buttons["SKL"].refresh() end
end})
ToggleRefs.SkillCheck = skillToggle
Tabs.Survivor:CreateToggle({Name="Show SKL Button",CurrentValue=true,Callback=function(v) BtnVis.SKL = v; applyButtonVisibility() end})

Tabs.Survivor:CreateSection("Invisible")
local invisToggle = Tabs.Survivor:CreateToggle({Name="Enable Invisible",CurrentValue=false,Callback=function(v)
    Invisible.Enabled = v
    if v then applyInvisible(); startEyeBlink() else restoreInvisible() end
    if QuickBtn.Buttons["INV"] and QuickBtn.Buttons["INV"].refresh then QuickBtn.Buttons["INV"].refresh() end
end})
ToggleRefs.Invisible = invisToggle
Tabs.Survivor:CreateToggle({Name="Show INV Button",CurrentValue=true,Callback=function(v) BtnVis.INV = v; applyButtonVisibility() end})

Tabs.Survivor:CreateSection("Moonwalk")
local moonToggle = Tabs.Survivor:CreateToggle({Name="Enable Moonwalk",CurrentValue=false,Callback=function(v) toggleMoonwalk(v) end})
ToggleRefs.Moonwalk = moonToggle
Tabs.Survivor:CreateToggle({Name="Show MOON Button",CurrentValue=true,Callback=function(v) BtnVis.MOON = v; applyButtonVisibility() end})
Tabs.Survivor:CreateKeybind({Name="Toggle Moonwalk (PC)",CurrentKeybind="V",HoldToInteract=false,Callback=function(k) toggleMoonwalk(not Moonwalk.Enabled) end})
Tabs.Survivor:CreateSlider({Name="Spam Speed",Range={1,50},Increment=1,CurrentValue=30,Callback=function(v) Moonwalk.SpamSpeed = v end})
Tabs.Survivor:CreateSlider({Name="Intensity",Range={1,50},Increment=1,CurrentValue=35,Callback=function(v) Moonwalk.Intensity = v end})

Tabs.Survivor:CreateSection("Self Unhook")
Tabs.Survivor:CreateToggle({Name="Enable Self Unhook (TP bawah killer)",CurrentValue=false,Callback=function(v)
    SelfUnhook.Enabled = v
    if not v then setCharCollision(true); SelfUnhook.WasHooked = false; SelfUnhook.OriginalCF = nil end
end})
Tabs.Survivor:CreateSlider({Name="Offset Bawah Killer (studs)",Range={2,15},Increment=1,Suffix=" studs",CurrentValue=5,Callback=function(v) SelfUnhook.Offset = v end})

Tabs.Survivor:CreateSection("God & Anti KD")
Tabs.Survivor:CreateToggle({Name="God Mode",CurrentValue=false,Callback=function(v) PlayerMods.GodMode = v end})
Tabs.Survivor:CreateToggle({Name="Anti KnockDown",CurrentValue=false,Callback=function(v) PlayerMods.AntiKnockDown = v end})

Tabs.Survivor:CreateSection("Abilities")
Tabs.Survivor:CreateToggle({Name="Auto Wiggle",CurrentValue=false,Callback=function(v) Auto.Wiggle = v end})
Tabs.Survivor:CreateToggle({Name="Auto Flee Killer",CurrentValue=false,Callback=function(v) AutoFlee.Enabled = v end})
Tabs.Survivor:CreateToggle({Name="Fast Vault",CurrentValue=false,Callback=function(v) FastVault.Enabled = v end})
Tabs.Survivor:CreateSlider({Name="Vault Speed",Range={10,50},Increment=1,Suffix=" /10",CurrentValue=12,Callback=function(v) FastVault.Speed = v/10 end})

Tabs.Survivor:CreateSection("Custom Parry")
Tabs.Survivor:CreateToggle({Name="Enable Custom Parry Key",CurrentValue=false,Callback=function(v) CustomParry.Enabled = v end})
Tabs.Survivor:CreateKeybind({Name="Parry Key",CurrentKeybind="Q",HoldToInteract=false,Callback=function(k) CustomParry.Key = Enum.KeyCode[k] end})

Tabs.Survivor:CreateSection("Escape")
Tabs.Survivor:CreateButton({Name="Instant Escape",Callback=function() teleportToFinishLine() end})

Tabs.Killer:CreateSection("Auto Stalk")
Tabs.Killer:CreateToggle({Name="Auto Stalk",CurrentValue=false,Callback=function(v) AutoStalk.Enabled = v; if v then startAutoStalk() else stopAutoStalk() end end})
Tabs.Killer:CreateSection("Auto Kill")
Tabs.Killer:CreateToggle({Name="Auto Kill All",CurrentValue=false,Callback=function(v) Killer.KillAll = v end})
Tabs.Killer:CreateToggle({Name="Auto Spam Attack",CurrentValue=false,Callback=function(v) Killer.AutoAttack = v end})
Tabs.Killer:CreateToggle({Name="Auto Carry + Hook",CurrentValue=false,Callback=function(v) Killer.AutoCarry = v end})
Tabs.Killer:CreateToggle({Name="Kill Aura",CurrentValue=false,Callback=function(v) Killer.KillAura = v end})
Tabs.Killer:CreateSlider({Name="Kill Aura Range",Range={5,50},Increment=1,Suffix=" studs",CurrentValue=15,Callback=function(v) Killer.KillAuraRange = v end})
Tabs.Killer:CreateSection("Block All Vault")
Tabs.Killer:CreateToggle({Name="Block All Vault",CurrentValue=false,Callback=function(v)
    KillerExtras.BlockAllVault = v
    if v then enableBlockAllVault() else disableBlockAllVault() end
end})
Tabs.Killer:CreateSection("Drop All Pallets")
Tabs.Killer:CreateToggle({Name="Auto Drop All Pallets",CurrentValue=false,Callback=function(v)
    KillerExtras.DropAllPallets = v
    if v then dropAllPallets() end
end})
Tabs.Killer:CreateButton({Name="Drop All Pallets (1x)",Callback=function() dropAllPallets() end})
Tabs.Killer:CreateSection("Anti Blind")
Tabs.Killer:CreateToggle({Name="Anti Blind",CurrentValue=false,Callback=function(v)
    KillerExtras.AntiBlind = v
    if v then enableAntiBlind() else disableAntiBlind() end
end})
Tabs.Killer:CreateSection("Masked Powers")
Tabs.Killer:CreateDropdown({Name="Select Power",Options=MaskedPowers,CurrentOption={"Cobra"},Callback=function(o) Masked.CurrentPower = type(o)=="table" and o[1] or o end})
Tabs.Killer:CreateButton({Name="Activate Power",Callback=function()
    local ev = ReplicatedStorage:FindFirstChild("Remotes",true) and ReplicatedStorage.Remotes:FindFirstChild("Killers",true)
        and ReplicatedStorage.Remotes.Killers:FindFirstChild("Masked",true)
        and ReplicatedStorage.Remotes.Killers.Masked:FindFirstChild("Activatepower")
    if ev then ev:FireServer(Masked.CurrentPower) end
end})
Tabs.Killer:CreateButton({Name="Deactivate Power",Callback=function()
    local ev = ReplicatedStorage:FindFirstChild("Remotes",true) and ReplicatedStorage.Remotes:FindFirstChild("Killers",true)
        and ReplicatedStorage.Remotes.Killers:FindFirstChild("Masked",true)
        and ReplicatedStorage.Remotes.Killers.Masked:FindFirstChild("Deactivatepower")
    if ev then ev:FireServer() end
end})

Tabs.Safety:CreateSection("Auto Dodge")
Tabs.Safety:CreateToggle({Name="Auto Dodge Killer",CurrentValue=false,Callback=function(v) Safety.AutoDodge = v end})
Tabs.Safety:CreateSlider({Name="Dodge Detect Range",Range={10,80},Increment=1,Suffix=" studs",CurrentValue=30,Callback=function(v) Safety.DodgeDistance = v end})
Tabs.Safety:CreateSection("Killer Alert")
Tabs.Safety:CreateToggle({Name="Proximity Alert (Sound)",CurrentValue=false,Callback=function(v) Safety.ProximityAlert = v end})
Tabs.Safety:CreateSlider({Name="Alert Distance",Range={10,100},Increment=1,Suffix=" studs",CurrentValue=50,Callback=function(v) Safety.AlertDistance = v end})
Tabs.Safety:CreateSection("HUD")
Tabs.Safety:CreateToggle({Name="Killer HUD (Distance)",CurrentValue=false,Callback=function(v) NewFeatures.KillerHUD = v end})
Tabs.Safety:CreateToggle({Name="Killer Direction Arrow",CurrentValue=false,Callback=function(v) NewFeatures.KillerArrow = v end})
Tabs.Safety:CreateSection("Auto Actions")
Tabs.Safety:CreateToggle({Name="Auto Reset if Downed",CurrentValue=false,Callback=function(v) NewFeatures.CharacterReset = v end})
Tabs.Safety:CreateToggle({Name="Auto Medkit (low HP)",CurrentValue=false,Callback=function(v) NewFeatures.AutoMedkit = v end})

Tabs.Teleport:CreateSection("Quick TP")
Tabs.Teleport:CreateButton({Name="TP to Nearest Generator",Callback=function() tpToNearest("Generator") end})
Tabs.Teleport:CreateButton({Name="TP to Nearest Exit",Callback=function() tpToNearest("Exit") end})
Tabs.Teleport:CreateButton({Name="TP to Nearest Window",Callback=function() tpToNearest("Window") end})
Tabs.Teleport:CreateButton({Name="TP to Nearest Pallet",Callback=function() tpToNearest("Pallet") end})
Tabs.Teleport:CreateButton({Name="TP to Finish Line",Callback=function() teleportToFinishLine() end})

Tabs.Utility:CreateSection("AFK")
Tabs.Utility:CreateToggle({Name="Anti-AFK",CurrentValue=false,Callback=function(v) Utility.AntiAFK = v; if v then startAntiAfk() end end})
Tabs.Utility:CreateSection("Server")
Tabs.Utility:CreateButton({Name="Server Hop",Callback=function() serverHop() end})
Tabs.Utility:CreateButton({Name="Rejoin Now",Callback=function() rejoin() end})

Tabs.ESP:CreateSection("Player ESP")
Tabs.ESP:CreateToggle({Name="ESP Survivor",CurrentValue=false,Callback=function(v) ESP.Survivor = v end})
Tabs.ESP:CreateColorPicker({Name="Survivor Color",Color=TeamColors.Survivor,Callback=function(c) TeamColors.Survivor = c end})
Tabs.ESP:CreateToggle({Name="ESP Killer",CurrentValue=false,Callback=function(v) ESP.Killer = v end})
Tabs.ESP:CreateColorPicker({Name="Killer Color",Color=TeamColors.Killer,Callback=function(c) TeamColors.Killer = c end})
Tabs.ESP:CreateSection("Object ESP")
Tabs.ESP:CreateToggle({Name="Generator ESP",CurrentValue=false,Callback=function(v) ESP.Generator = v end})
Tabs.ESP:CreateColorPicker({Name="Generator Color",Color=Color3.fromRGB(255,170,0),Callback=function(c) GenColor = c end})
Tabs.ESP:CreateToggle({Name="Pallet ESP",CurrentValue=false,Callback=function(v) ESP.Pallet = v end})
Tabs.ESP:CreateColorPicker({Name="Pallet Color",Color=Color3.fromRGB(74,255,181),Callback=function(c) PalColor = c end})
Tabs.ESP:CreateToggle({Name="Window ESP",CurrentValue=false,Callback=function(v) ESP.Window = v end})
Tabs.ESP:CreateColorPicker({Name="Window Color",Color=Color3.fromRGB(74,255,181),Callback=function(c) WinColor = c end})
Tabs.ESP:CreateSlider({Name="ESP Radius",Range={50,5000},Increment=50,Suffix=" studs",CurrentValue=1000,Callback=function(v) ESP.Distance = v end})

-- CONFIG MANAGER UI
Tabs.Misc:CreateSection("Config Manager")
local configInput = Tabs.Misc:CreateInput({Name="Config Name",CurrentValue="",PlaceholderText="my_config",RemoveTextAfterFocusLost=false,Callback=function(v) ConfigMgr.CurrentName = v end})
local configDropdown = Tabs.Misc:CreateDropdown({Name="Saved Configs",Options=listConfigs(),CurrentOption={""},Callback=function(o) end})
Tabs.Misc:CreateButton({Name="Refresh Config List",Callback=function()
    local list = listConfigs()
    if #list == 0 then list = {""} end
    pcall(function()
        if configDropdown and configDropdown.Refresh then configDropdown:Refresh(list) end
    end)
    Rayfield:Notify({Title="Config", Content="List refreshed ("..#list..")", Duration=2})
end})
Tabs.Misc:CreateButton({Name="Save Config",Callback=function()
    local name = ConfigMgr.CurrentName
    if not name or name == "" then
        Rayfield:Notify({Title="Config", Content="Isi nama dulu", Duration=3}); return
    end
    local ok, err = saveConfig(name)
    if ok then Rayfield:Notify({Title="Config", Content="Saved: "..name, Duration=3})
    else Rayfield:Notify({Title="Config", Content="Gagal: "..tostring(err), Duration=4}) end
end})
Tabs.Misc:CreateButton({Name="Load Config (dari dropdown)",Callback=function()
    local name = nil
    pcall(function()
        if configDropdown and configDropdown.CurrentOption then
            local c = configDropdown.CurrentOption
            if type(c) == "table" then name = c[1] else name = c end
        end
    end)
    if not name or name == "" then Rayfield:Notify({Title="Config", Content="Pilih dulu", Duration=3}); return end
    local ok, err = loadConfig(name)
    if ok then Rayfield:Notify({Title="Config", Content="Loaded: "..name, Duration=3})
    else Rayfield:Notify({Title="Config", Content="Gagal: "..tostring(err), Duration=4}) end
end})
Tabs.Misc:CreateButton({Name="Delete Config (dari dropdown)",Callback=function()
    local name = nil
    pcall(function()
        if configDropdown and configDropdown.CurrentOption then
            local c = configDropdown.CurrentOption
            if type(c) == "table" then name = c[1] else name = c end
        end
    end)
    if not name or name == "" then return end
    deleteConfig(name)
    Rayfield:Notify({Title="Config", Content="Deleted: "..name, Duration=3})
end})

Tabs.Misc:CreateSection("Buttons")
Tabs.Misc:CreateToggle({Name="Lock Buttons Position",CurrentValue=true,Callback=function(v) LockButtons = v end})
Tabs.Misc:CreateButton({Name="Reset Button Positions",Callback=function()
    for name, pos in pairs(DEFAULT_BTN_POS) do
        if QuickBtn.Buttons[name] and QuickBtn.Buttons[name].btn then
            QuickBtn.Buttons[name].btn.Position = pos
        end
    end
end})

Tabs.Misc:CreateSection("Menu")
Tabs.Misc:CreateButton({Name="Unload Script",Callback=function() clearLaserDrawings(); Rayfield:Destroy() end})

Tabs.Misc:CreateSection("Movement")
Tabs.Misc:CreateToggle({Name="Walk Speed",CurrentValue=false,Callback=function(v)
    Movement.WalkSpeedEnabled = v
    if v then applyWalkSpeed()
    else local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = Movement.OriginalWalkSpeed end end
end})
Tabs.Misc:CreateSlider({Name="Walk Speed Value",Range={16,200},Increment=1,CurrentValue=17,Callback=function(v)
    Movement.WalkSpeedValue = v; if Movement.WalkSpeedEnabled then applyWalkSpeed() end
end})
Tabs.Misc:CreateToggle({Name="No Clip (Ladder Safe)",CurrentValue=false,Callback=function(v) toggleNoClip(v) end})
Tabs.Misc:CreateToggle({Name="Custom Jump Power",CurrentValue=false,Callback=function(v)
    Movement.JumpPowerEnabled = v
    if v then applyJumpPower()
    else local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then h.JumpPower = Movement.OriginalJumpPower end end
end})
Tabs.Misc:CreateSlider({Name="Jump Power Value",Range={0,500},Increment=5,CurrentValue=50,Callback=function(v)
    Movement.JumpPowerValue = v; if Movement.JumpPowerEnabled then applyJumpPower() end
end})

Tabs.Misc:CreateSection("Emote")
Tabs.Misc:CreateDropdown({Name="Select Emote",Options=EmoteList,CurrentOption={"Mannrobics"},Callback=function(o) Emote.Selected = type(o)=="table" and o[1] or o end})
Tabs.Misc:CreateButton({Name="Play Emote",Callback=function() playEmote(Emote.Selected) end})
Tabs.Misc:CreateToggle({Name="Show Emote Button",CurrentValue=false,Callback=function(v) if v then createEmoteBtn() else removeEmoteBtn() end end})

Tabs.Misc:CreateSection("Avatar Stealer")
Tabs.Misc:CreateInput({Name="Target Username",CurrentValue="",PlaceholderText="username...",RemoveTextAfterFocusLost=false,Callback=function(v) AvatarStealer.TargetUsername = v end})
Tabs.Misc:CreateButton({Name="Copy Avatar",Callback=function()
    if not AvatarStealer.TargetUsername or AvatarStealer.TargetUsername == "" then return end
    local c = LocalPlayer.Character; if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid"); if not h then return end
    AvatarStealer.OriginalDescription = h:GetAppliedDescription()
    local ok, uid = pcall(function() return Players:GetUserIdFromNameAsync(AvatarStealer.TargetUsername) end)
    if not ok then return end
    task.spawn(function()
        local d = Players:GetHumanoidDescriptionFromUserId(uid)
        h:ApplyDescriptionClientServer(d)
    end)
end})
Tabs.Misc:CreateButton({Name="Reset to Original",Callback=function()
    if not AvatarStealer.OriginalDescription then return end
    local c = LocalPlayer.Character; if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid"); if not h then return end
    h:ApplyDescriptionClientServer(AvatarStealer.OriginalDescription)
end})

Tabs.Visual:CreateSection("Graphics")
Tabs.Visual:CreateToggle({Name="Fullbright",CurrentValue=false,Callback=function(v) Visual.Fullbright = v end})
Tabs.Visual:CreateToggle({Name="No Shadow",CurrentValue=false,Callback=function(v) Visual.NoShadow = v end})
Tabs.Visual:CreateToggle({Name="No Fog",CurrentValue=false,Callback=function(v) Visual.NoFog = v end})
Tabs.Visual:CreateToggle({Name="Low Graphics",CurrentValue=false,Callback=function(v)
    pcall(function() settings().Rendering.QualityLevel = v and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic end)
end})
Tabs.Visual:CreateToggle({Name="Clean Sky",CurrentValue=false,Callback=function(v)
    if v then for _, o in ipairs(Lighting:GetChildren()) do if o:IsA("Sky") then o:Destroy() end end end
end})
Tabs.Visual:CreateToggle({Name="FPS Boost (Potato Mode)",CurrentValue=false,Callback=function(v) if v then enablePotato() else disablePotato() end end})
Tabs.Visual:CreateSection("Zoom & FOV")
Tabs.Visual:CreateToggle({Name="Unlimited Zoom Out",CurrentValue=false,Callback=function(v) CameraZoom.UnlimitedZoom = v; applyUnlimitedZoom() end})
Tabs.Visual:CreateSlider({Name="Max Zoom Distance",Range={100,5000},Increment=50,CurrentValue=1000,Callback=function(v) CameraZoom.MaxDistance = v; if CameraZoom.UnlimitedZoom then applyUnlimitedZoom() end end})
Tabs.Visual:CreateToggle({Name="Custom FOV",CurrentValue=false,Callback=function(v) CameraZoom.FOVEnabled = v; applyCameraFOV() end})
Tabs.Visual:CreateSlider({Name="Camera FOV",Range={40,120},Increment=1,CurrentValue=70,Callback=function(v) CameraZoom.FOV = v; if CameraZoom.FOVEnabled then applyCameraFOV() end end})
Tabs.Visual:CreateSection("Crosshair")
Tabs.Visual:CreateToggle({Name="Enable Crosshair",CurrentValue=false,Callback=function(v) Crosshair.Enabled = v end})
Tabs.Visual:CreateColorPicker({Name="Crosshair Color",Color=Color3.fromRGB(255,255,255),Callback=function(c) Crosshair.Color = c end})
Tabs.Visual:CreateDropdown({Name="Crosshair Style",Options={"Plus","Dot","Circle"},CurrentOption={"Plus"},Callback=function(o) Crosshair.Style = type(o)=="table" and o[1] or o end})
Tabs.Visual:CreateSlider({Name="Size",Range={2,50},Increment=1,CurrentValue=8,Callback=function(v) Crosshair.Size = v end})
Tabs.Visual:CreateSlider({Name="Thickness",Range={1,10},Increment=1,CurrentValue=2,Callback=function(v) Crosshair.Thickness = v end})

Rayfield:Notify({Title="ValzZHub v4.0",Content="Loaded.",Duration=6})
