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
local antiAfkConnection = nil

if isfile(configFileName) then
    local data = readfile(configFileName)
    local settings = HttpService:JSONDecode(data)

    autoFarmActive = settings.autoFarm
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
local autoFarmDungeon = false


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
local autoRejoinDungeon = false
local function RejoinDungeon()
	local guiPath = Players.LocalPlayer:WaitForChild("PlayerGui")
	local dungeonInfo = guiPath:WaitForChild("Hud"):WaitForChild("UpContainer"):WaitForChild("DungeonInfo")

	while autoRejoinDungeon do
		task.wait(1) -- mỗi giây kiểm tra một lần
		if dungeonInfo.Text == "Dungeon In End" then
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
-- Tải Fluent UI Library
local Library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
-- Âm thanh khởi động
local startupSound = Instance.new("Sound")
startupSound.SoundId = "rbxassetid://127760651205950"
startupSound.Volume = 5 -- Điều chỉnh âm lượng nếu cần
startupSound.Looped = false -- Không lặp lại âm thanh
startupSound.Parent = game.CoreGui-- Đặt parent vào CoreGui để đảm bảo âm thanh phát
startupSound:Play() -- Phát âm thanh khi script chạy
-- Tạo cửa sổ chính
local Window = Library:CreateWindow{
    Title = "#OlwenTh",
    SubTitle = "@kevinproxlucky",
    TabWidth = ,
    Size = UDim2.fromOffset(1280, 860),
    Resize = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl -- Phím thu nhỏ
}

-- Tạo ScreenGui chứa nút điều khiển
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ControlGUI"
screenGui.Parent = game.CoreGui

-- Tạo nút (ImageButton)
local toggleButton = Instance.new("ImageButton")
toggleButton.Size = UDim2.new(0, 50, 0, 50) -- Kích thước nhỏ, hình vuông
toggleButton.Position = UDim2.new(1, -60, 0, 10) -- Vị trí gần góc phải trên
toggleButton.Image = "rbxassetid://139059673305771" -- Hình ảnh của nút
toggleButton.BackgroundTransparency = 1 -- Không có nền
toggleButton.Parent = screenGui

-- Biến lưu trạng thái hiển thị Fluent UI
local isFluentVisible = true

-- Di chuyển nút
local dragging, dragInput, dragStart, startPos

local function update(input)
    local delta = input.Position - dragStart
    toggleButton.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end

toggleButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = toggleButton.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

toggleButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        update(input)
    end
end)

-- Ẩn/Hiện Fluent UI khi nhấn nút
toggleButton.MouseButton1Click:Connect(function()
    isFluentVisible = not isFluentVisible

    if isFluentVisible then
        -- Hiện Fluent UI
        Window:Minimize(false) -- Mở lại cửa sổ
    else
        -- Ẩn Fluent UI
        Window:Minimize(true) -- Thu nhỏ cửa sổ
    end
end
local Tabs = {
    MainTab = Window:CreateTab{
        Title = "Main",
        Icon = "phosphor-users-bold"
    },
    DungeonTab = Window:CreateTab{
        Title = "Dungeon"
        Icon = ""
    },
    Settings = Window:CreateTab{
        Title = "Settings",
        Icon = "settings"
    }
}


Tabs.MainTab:AddToggle({
	Title = "Auto Boss Dragonball",
	Default = autoFarmActive,
	Description = "Auto Farm Big at Dragonball island",
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

Tabs.MainTab:AddToggle({
	Title = "Auto Destroy",
	Default = autoDestroy,
	Callback = function(state)
		autoDestroy = state
		saveConfig()
		if state then
			task.spawn(fireDestroy)
		end
	end
})

Tabs.MainTab:AddToggle({
	Title = "Auto Click",
	Default = AutoClicked,
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

Tabs.MainTab:AddToggle({
	Title = "Anti AFK",
	Default = (antiAfkConnection ~= nil),
	Callback = function(enabled)
		saveConfig()
		if enabled then
			print("Đã bật Anti AFK")
			if not antiAfkConnection then
				antiAfkConnection = LocalPlayer.Idled:Connect(function()
					VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
					task.wait(1)
					VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
				end)
			end
		else
			print("Đã tắt Anti AFK")
			if antiAfkConnection then
				antiAfkConnection:Disconnect()
				antiAfkConnection = nil
			end
		end
	end
})



Tabs.DungeonTab:AddButton({
	Title = "Bypass Dungeon",
    Description = "Join Dungeon Everytime",
	Callback = function()
		startDungeonSequence()
	end
})

Tabs.DungeonTab:AddToggle({
	Title = "Auto Rejoin When End Dungeon",
	Default = autoRejoinDungeon,
	Callback = function(state)
		autoRejoinDungeon = state
		if state then
			task.spawn(RejoinDungeon)
		end
	end			
})

Tabs.DungeonTab:AddToggle({
	Title = "Auto Farm In Dungeon",
	Default = autoFarmDungeon,
	Callback = function(dabat)
		autoFarmDungeon = dabat
		if dabat then
			task.spawn(autoFarmDungeonTeleport)
		end
	end			
})

DungeonTab:CreateSlider({
	Title = "Delay Teleport Farm",
	Default = teleportDelay, -- Giá trị mặc định của thanh trượt
    Min = 0, -- Giá trị tối thiểu của thanh trượt
	Max = 3, -- Giá trị tối đa của thanh trượt
	Rounding = 0.1, -- Số chữ số thập phân sau dấu phẩy
	Callback = function(Value)
		
				teleportDelay = Value
	end,
 })














