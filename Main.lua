local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

local autoFarm = false
local autoStart = false
local autoSkill = false
local autoNextLv = false
local autoRPlay = false
local autoRLobby = false
local lastClickTime = 0
local clickDelay = 0.3
local stayBehindDistance = 10
local minY = 10

-- === Tìm mob gần nhất ===
function getNearestEnemy()
    local nearest, shortestDistance = nil, math.huge
    for _, enemy in pairs(workspace:WaitForChild("Enemy"):WaitForChild("Mob"):GetChildren()) do
        if enemy:FindFirstChild("HumanoidRootPart") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
            local dist = (hrp.Position - enemy.HumanoidRootPart.Position).Magnitude
            if dist < shortestDistance then
                shortestDistance = dist
                nearest = enemy
            end
        end
    end
    return nearest
end

-- === Gán bạn là Target + Teleport sau lưng ===
function setTargetOnMob(mob)
    local target = mob:FindFirstChild("Target")
    if target and target:IsA("ObjectValue") then
        target.Value = player.Character
    end
end

function stayBehindMob(enemy)
    local enemyHRP = enemy:FindFirstChild("HumanoidRootPart")
    if not enemyHRP then return end

    local backPos = enemyHRP.Position - enemyHRP.CFrame.LookVector * stayBehindDistance
    local sunkenY = backPos.Y - 3.0 -- Giảm xuống đất một chút

    local newPos = Vector3.new(backPos.X, sunkenY, backPos.Z)
    local lookAt = Vector3.new(enemyHRP.Position.X, sunkenY, enemyHRP.Position.Z)

    hrp.CFrame = CFrame.new(newPos, lookAt)
end

-- === Kiểm tra nếu không còn kẻ thù gần ===
function isNoEnemiesNearby()
    local enemy = getNearestEnemy()
    return not enemy or enemy.Humanoid.Health <= 0
end

-- === AutoFarm loop ===
RunService.RenderStepped:Connect(function()
    if autoFarm and character and hrp then
        local enemy = getNearestEnemy()
        if not enemy or enemy.Humanoid.Health <= 0 then return end

        setTargetOnMob(enemy)
        stayBehindMob(enemy)

        if tick() - lastClickTime >= clickDelay then
            local target = enemy:FindFirstChild("Target")
            if target and target.Value == player.Character then
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                wait(0.000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
                lastClickTime = tick()
            end
        end

        if hrp.Position.Y < -50 then
            hrp.CFrame = CFrame.new(0, 25, 0)
            warn("[ANTI-FALL] Đã kéo về mặt đất.")
        end
    end
end)

-- === AutoSkill loop ===
task.spawn(function()
    while true do
        if autoSkill then
            local enemy = getNearestEnemy()
            if enemy then
                for _, key in ipairs({"Z", "X", "C"}) do
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode[key], false, game)
                    wait(0.01)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode[key], false, game)
                    wait(0.00000000000000000000000000000001)
                end
            end
        end
        wait(0.0000000000000000000000000001)
    end
end)

-- === AutoNextLv loop ===
task.spawn(function()
    while true do
        if autoNextLv then
            -- Đợi cho tới khi không còn kẻ thù gần
            if isNoEnemiesNearby() then
                wait(5)  -- Đợi thêm 5 giây
                local args = {"NextLv"}
                game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("WinEvent"):WaitForChild("Buttom"):FireServer(unpack(args))
                wait(1)  -- Thêm một khoảng thời gian nhỏ để tránh gọi quá nhanh
            else
                wait(0.5)  -- Chờ thêm nếu còn kẻ thù gần
            end
        end
        wait(1)
    end
end)

-- === AutoRPlay loop ===
task.spawn(function()
    while true do
        if autoRPlay then
            -- Đợi cho tới khi không còn kẻ thù gần
            if isNoEnemiesNearby() then
                wait(5)  -- Đợi thêm 5 giây
                local args = {"RPlay"}
                game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("WinEvent"):WaitForChild("Buttom"):FireServer(unpack(args))
                wait(1)  -- Thêm một khoảng thời gian nhỏ để tránh gọi quá nhanh
            else
                wait(0.5)  -- Chờ thêm nếu còn kẻ thù gần
            end
        end
        wait(1)
    end
end)

-- === AutoRLobby loop ===
task.spawn(function()
    while true do
        if autoRLobby then
            -- Đợi cho tới khi không còn kẻ thù gần
            if isNoEnemiesNearby() then
                wait(5)  -- Đợi thêm 5 giây
                local args = {"RLobby"}
                game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("WinEvent"):WaitForChild("Buttom"):FireServer(unpack(args))
                wait(1)  -- Thêm một khoảng thời gian nhỏ để tránh gọi quá nhanh
            else
                wait(0.5)  -- Chờ thêm nếu còn kẻ thù gần
            end
        end
        wait(1)
    end
end)



-- === Rayfield UI ===
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "TJWAN - HUB",
    Icon = 6902422218,
    LoadingTitle = "TJWAN Loading...",
    LoadingSubtitle = "AutoFarm + Skill",
    Theme = "Default",
    ConfigurationSaving = {
        Enabled = true,
        FileName = "TJWAN-Settings"
    },

    ConfigurationSaving = {
      Enabled = true,
      FolderName = "tjw", -- Create a custom folder for your hub/game
      FileName = "config"
   }
})

local MainTab = Window:CreateTab("Auto", 4483362458)

MainTab:CreateToggle({
    Name = "Auto Farm",
    CurrentValue = autoFarm,
    Flag = "AutoFarmToggle",
    Callback = function(state)
        autoFarm = state
    end
})

MainTab:CreateToggle({
    Name = "Auto Skill Z/X/C",
    CurrentValue = autoSkill,
    Flag = "AutoSkillToggle",
    Callback = function(state)
        autoSkill = state
    end
})

MainTab:CreateToggle({
    Name = "Auto Next Level",
    CurrentValue = autoNextLv,
    Flag = "AutoNextLvToggle",
    Callback = function(state)
        autoNextLv = state
    end
})

MainTab:CreateToggle({
    Name = "Auto RPlay",
    CurrentValue = autoRPlay,
    Flag = "AutoRPlayToggle",
    Callback = function(state)
        autoRPlay = state
    end
})

MainTab:CreateToggle({
    Name = "Auto RLobby",
    CurrentValue = autoRLobby,
    Flag = "AutoRLobbyToggle",
    Callback = function(state)
        autoRLobby = state
    end
})

-- Tạo Toggle cho Auto Start (chỉ hoạt động khi toggle bật)
MainTab:CreateToggle({
    Name = "Auto Start Game",
    CurrentValue = autoStart,
    Flag = "AutoStartToggle",
    Callback = function(state)
        autoStart = state  -- Cập nhật trạng thái toggle
    end
})

-- === Kiểm Tra Mỗi Lần Có `StartButton` ===
task.spawn(function()
    while true do
        if autoStart then
            -- Chờ game sẵn sàng (Map tồn tại)
            if not workspace:FindFirstChild("Map") then
                wait(0.1)  -- Đợi nếu Map chưa có sẵn
            else
                -- Tìm RoomUi và các child cần thiết
                local roomUi = player.PlayerGui:FindFirstChild("RoomUi")
                if roomUi then
                    -- Kiểm tra xem StartButton có sẵn không
                    local startButton = roomUi:FindFirstChild("Ready"):FindFirstChild("Frame"):FindFirstChild("StartButton")
                    if startButton then
                        local buttonScript = startButton:WaitForChild("Butom"):WaitForChild("LocalScript")
                        local remote = buttonScript:WaitForChild("RemoteEvent")

                        -- Gửi yêu cầu Start
                        remote:FireServer() 

                        -- Chờ một khoảng thời gian ngắn rồi kiểm tra lại
                        wait(0.5)  -- Có thể điều chỉnh thời gian nếu cần
                    end
                else
                    warn("RoomUi không tồn tại trong PlayerGui!")
                end
            end
        else
            wait(0.1)  -- Nếu toggle tắt, chỉ đợi để kiểm tra lại toggle
        end
    end
end)
