local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local enemyContainer = workspace:WaitForChild("__Main"):WaitForChild("__Enemies"):WaitForChild("Server")

local configFolder = "tjwanHUB"
local configFileName = configFolder .. "/dragonball_config.json"

-- create folder nếu chưa có
if not isfolder(configFolder) then
    makefolder(configFolder)
end

--  Load config nếu tồn tại
local autoFarmActive = false
local AutoClicked = false
local autoDestroy = false
local autoRejoinDungeon = false
local autoFarmDungeon = false
local antiAfkConnection = nil

if isfile(configFileName) then
    local data = readfile(configFileName)
    local settings = HttpService:JSONDecode(data)

    autoFarmActive = settings.autoFarm
	autoFarmDungeon = settings.autoFarmDungeon1
	autoRejoinDungeon = settings.autoRejoinDungeon1
    AutoClicked = settings.autoClick
    autoDestroy = settings.autoDestroy

    if settings.antiAfk and not antiAfkConnection then
        antiAfkConnection = LocalPlayer.Idled:Connect(function()
            VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end
end

--  Hàm lưu config
local function saveConfig()
    local settings = {
		autoFarmDungeon1 = autoFarmDungeon,
		autoRejoinDungeon1 = autoRejoinDungeon,
        autoFarm = autoFarmActive,
        autoClick = AutoClicked,
        autoDestroy = autoDestroy,
        antiAfk = (antiAfkConnection ~= nil)
    }

    writefile(configFileName, HttpService:JSONEncode(settings))
end

--  Auto Farm Boss Logic
local enemiesFolder = workspace:WaitForChild("__Main"):WaitForChild("__Enemies"):WaitForChild("Client")
local player = Players.LocalPlayer
local movementMethod = "Teleport" -- Chọn: "Teleport" / "Tween" / "Walk"

local function waitForCharacter()
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		player.CharacterAdded:Wait()
		player.Character:WaitForChild("HumanoidRootPart")
	end
	return player.Character:FindFirstChild("HumanoidRootPart")
end

local targetBossIDs = {
	["DBB1"] = true,
	["DBB2"] = true,
	["DBB3"] = true
}

local function anticheat()
	if player and player.Character then
		local characterScripts = player.Character:FindFirstChild("CharacterScripts")
		if characterScripts then
			local flyingFixer = characterScripts:FindFirstChild("FlyingFixer")
			if flyingFixer then flyingFixer:Destroy() end
			local characterUpdater = characterScripts:FindFirstChild("CharacterUpdater")
			if characterUpdater then characterUpdater:Destroy() end
		end
	end
end

local function moveToTarget(hrp, target)
	if not target or not target:IsA("BasePart") then return end
	local destination = target.CFrame * CFrame.new(0, 0, 6)
	anticheat()
	if movementMethod == "Teleport" then
		local tweenInfo = TweenInfo.new(0, Enum.EasingStyle.Linear)
		local tween = TweenService:Create(hrp, tweenInfo, {CFrame = destination})
		tween:Play()
	elseif movementMethod == "Tween" then
		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
		local tween = TweenService:Create(hrp, tweenInfo, {CFrame = destination})
		tween:Play()
	elseif movementMethod == "Walk" then
		hrp.Parent:MoveTo(target.Position)
	end
end

local function getValidBossParts(container)
	local parts = {}
	for _, part in ipairs(container:GetDescendants()) do
		if part:IsA("BasePart") and targetBossIDs[part:GetAttribute("Id")] then
			table.insert(parts, part)
		end
	end
	return parts
end

local function getClosestValidBoss(hrp, bossParts)
	local closest, shortest = nil, math.huge
	for _, part in ipairs(bossParts) do
		local hp = part:GetAttribute("HP")
		if hp and hp > 0 then
			local dist = (part.Position - hrp.Position).Magnitude
			if dist < shortest then
				shortest = dist
				closest = part
			end
		end
	end
	return closest
end

local function autoTrackBosses()
	local hrp = waitForCharacter()
	local enemyContainer = workspace:WaitForChild("__Main"):WaitForChild("__Enemies"):WaitForChild("Server")
	local currentBoss = nil
	while autoFarmActive do
		task.wait(0.01)
		local bossParts = getValidBossParts(enemyContainer)
		local closest = getClosestValidBoss(hrp, bossParts)
		if closest and closest ~= currentBoss then
			currentBoss = closest
			moveToTarget(hrp, currentBoss)
		end
		if not closest then
			currentBoss = nil
		end
	end
	print(" Đã dừng Auto Farm.")
end
--
local teleportDelay = 0.8 -- Thời gian chờ giữa mỗi lần teleport (giây)



--Auto Farm Dungeon--
local function isInDungeon()
	local worldFolder = workspace:FindFirstChild("__Main"):FindFirstChild("__World")
	if worldFolder then
		local spawnLocation = worldFolder:FindFirstChild("SpawnLocation")
		return spawnLocation ~= nil
	end
	return false
end

local function getEnemyDungeon()
	local parts = {}
	for _, part in ipairs(enemyContainer:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute("HP") ~= nil then
			table.insert(parts, part)
		end
	end
	return parts
end

local function autoFarmDungeonTeleport()
	local hrp = waitForCharacter()
	while autoFarmDungeon do
		local DungeonEnemy = getEnemyDungeon()
		local foundAliveBoss = false

		for _, boss in ipairs(DungeonEnemy) do
			local hp = boss:GetAttribute("HP")
			if hp and hp > 0 then
				foundAliveBoss = true
				moveToTarget(hrp, boss)

				-- Đợi enemydungeon chết
				repeat
					task.wait(0.5)
					hp = boss:GetAttribute("HP")
				until not autoFarmDungeon or hp == 0

				task.wait(teleportDelay) -- Chờ giữa mỗi lần teleport

				if not autoFarmDungeon then break end
			end
		end

		-- Nếu không có boss sống => chờ boss xuất hiện lại
		if not foundAliveBoss then
			repeat
				task.wait(1)
				DungeonEnemy = getEnemyDungeon()
				for _, boss in ipairs(DungeonEnemy) do
					local hp = boss:GetAttribute("HP")
					if hp and hp > 0 then
						foundAliveBoss = true
						break
					end
				end
			until not autoFarmDungeon or foundAliveBoss
		end
	end

	print("Auto Farm Dungeon đã dừng.")
end
--  Auto Destroy
local function fireDestroy()
	while autoDestroy do
		task.wait(0.00001)
		for _, enemy in ipairs(enemiesFolder:GetChildren()) do
			if enemy:IsA("Model") then
				local rootPart = enemy:FindFirstChild("HumanoidRootPart")
				local DestroyPrompt = rootPart and rootPart:FindFirstChild("DestroyPrompt")
				if DestroyPrompt then
					DestroyPrompt:SetAttribute("MaxActivationDistance", 1e100)
					fireproximityprompt(DestroyPrompt)
				end
			end
		end
	end
end

--  Auto Click
local function AutoClickFast()
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	local RANGE = 20
	while AutoClicked do
		task.wait(0)
		local enemies = enemiesFolder:GetChildren()
		local closestEnemy = nil
		local minDistance = RANGE
		for _, enemy in pairs(enemies) do
			local enemyRootPart = enemy:FindFirstChild("HumanoidRootPart")
			if enemyRootPart then
				local distance = (humanoidRootPart.Position - enemyRootPart.Position).Magnitude
				if distance <= minDistance then
					closestEnemy = enemy
					minDistance = distance
				end
			end
		end
		if closestEnemy then
			local enemyId = closestEnemy.Name
			local args = {
				{
					{
						Event = "PunchAttack",
						Enemy = enemyId
					},
					"\4"
				}
			}
			ReplicatedStorage:WaitForChild("BridgeNet2"):WaitForChild("dataRemoteEvent"):FireServer(unpack(args))
		end
	end
end

--  Bypass Dungeon
local remoteEvent = ReplicatedStorage:WaitForChild("BridgeNet2"):WaitForChild("dataRemoteEvent")
local function buyTicket()
	local args = {
		{
			{
				Type = "Gems",
				Event = "DungeonAction",
				Action = "BuyTicket"
			},
			"\n"
		}
	}
	remoteEvent:FireServer(unpack(args))
end

local function createDungeon()
	local args = {
		{
			{
				Event = "DungeonAction",
				Action = "Create"
			},
			"\n"
		}
	}
	remoteEvent:FireServer(unpack(args))
end

local function enterDungeon()
	local args = {
		{
			{
				Event = "DungeonAction",
				Action = "Start"
			},
			"\n"
		}
	}
	remoteEvent:FireServer(unpack(args))
end

local function startDungeonSequence()
	buyTicket()
	task.wait(0)
	createDungeon()
	task.wait(0)
	enterDungeon()
end
--Auto rejoin Dungeon--
-- 📍 Gọi lại dungeon khi "Dungeon In End"

local function RejoinDungeon()
	local guiPath = Players.LocalPlayer:WaitForChild("PlayerGui")
	local dungeonInfo = guiPath:WaitForChild("Hud"):WaitForChild("UpContainer"):WaitForChild("DungeonInfo")

	while autoRejoinDungeon do
		task.wait(1) -- mỗi giây kiểm tra một lần
		if dungeonInfo.Text == "DUNGEON ENDS IN" then
			print("🔁 Phát hiện Dungeon kết thúc! Bắt đầu lại...")
			task.wait(5)
			startDungeonSequence()
			task.wait(1) -- chờ một chút trước khi lặp lại
		end
	end
end
--end auto rejoin --
-- Gọi hàm theo dõi


--  GUI
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
	Name = "TJWAN - HUB",
	Icon = 6902422218, -- Icon in Topbar. Can use Lucide Icons (string) or Roblox Image (number). 0 to use no icon (default).
	LoadingTitle = "Rayfield Interface Suite",
	LoadingSubtitle = "by Sirius",
	Theme = "Default", -- Check https://docs.sirius.menu/rayfield/configuration/themes
 
	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false, -- Prevents Rayfield from warning when the script has a version mismatch with the interface
 
	ConfigurationSaving = {
	   Enabled = true,
	   FolderName = nil, -- Create a custom folder for your hub/game
	   FileName = "TJWAN-HUB"
	},
 
	Discord = {
	   Enabled = false, -- Prompt the user to join your Discord server if their executor supports it
	   Invite = "noinvitelink", -- The Discord invite code, do not include discord.gg/. E.g. discord.gg/ ABCD would be ABCD
	   RememberJoins = true -- Set this to false to make them join the discord every time they load it up
	},
 
	KeySystem = true, -- Set this to true to use our key system
	KeySettings = {
	   Title = "Untitled",
	   Subtitle = "Key System",
	   Note = "No method of obtaining the key is provided", -- Use this to tell the user how to get a key
	   FileName = "Key", -- It is recommended to use something unique as other scripts using Rayfield may overwrite your key file
	   SaveKey = true, -- The user's key will be saved, but if you change the key, they will be unable to use your script
	   GrabKeyFromSite = false, -- If this is true, set Key below to the RAW site you would like Rayfield to get the key from
	   Key = {"tjwanok"} -- List of keys that will be accepted by the system, can be RAW file links (pastebin, github etc) or simple strings ("hello","key22")
	}
 })

 local MainTab = Window:CreateTab("Main", 4483362458) -- Title, Image


MainTab:CreateToggle({
	Name = "Auto Boss Dragonball",
	CurrentValue = autoFarmActive,
	Flag = "Toggle1",
	Callback = function(Goku)
		autoFarmActive = Goku
		saveConfig()
		if Goku then
			task.spawn(autoTrackBosses)
		else
			print(" Tắt auto farm.")
		end
	end
})

MainTab:CreateToggle({
	Name = "Auto Destroy",
	CurrentValue = autoDestroy,
	Flag = "Toggle2",
	Callback = function(state)
		autoDestroy = state
		saveConfig()
		if state then
			task.spawn(fireDestroy)
		end
	end
})

MainTab:CreateToggle({
	Name = "Auto Click",
	CurrentValue = AutoClicked,
	Flag = "Toggle3",
	Callback = function(click)
		AutoClicked = click
		saveConfig()
		if click then
			task.spawn(AutoClickFast)
			print("Auto Click Enable")
		else
			print("Auto Click Disable")
		end
	end
})

MainTab:CreateToggle({
	Name = "Anti AFK",
	CurrentValue = (antiAfkConnection ~= nil),
	Flag = "Toggle4",
	Callback = function(afk)
		if afk and not antiAfkConnection then
			antiAfkConnection = LocalPlayer.Idled:Connect(function()
				VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
				task.wait(1)
				VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
			end)
		elseif not afk and antiAfkConnection then
			antiAfkConnection:Disconnect()
			antiAfkConnection = nil
		end
		saveConfig()
	end
})

local DungeonTab = Window:CreateTab("Dungeon", 4483362458) -- Title, Image

DungeonTab:CreateButton({
	Name = "Bypass Dungeon",
	Callback = function()
		startDungeonSequence()
	end
})

DungeonTab:CreateToggle({
	Name = "Auto Rejoin When End Dungeon",
	CurrentValue = autoRejoinDungeon,
	Flag = "ToggleRJ",
	Callback = function(state)
		autoRejoinDungeon = state
		saveConfig()
		if state then
			task.spawn(RejoinDungeon)
		end
	end			
})

DungeonTab:CreateToggle({
	Name = "Auto Farm In Dungeon",
	CurrentValue = autoFarmDungeon,
	Flag = "ToggleD",
	Callback = function(dabat)
		autoFarmDungeon = dabat
		saveConfig()
		if dabat then
			task.spawn(autoFarmDungeonTeleport)
		end
	end			
})

DungeonTab:CreateSlider({
	Name = "Delay Teleport Farm",
	Range = {0, 3},
	Increment = 0.1,
	Suffix = "s",
	CurrentValue = teleportDelay,
	Flag = "Slider1", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
	Callback = function(Value)
				teleportDelay = Value
	end,
 })














