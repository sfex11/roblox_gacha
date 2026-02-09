--[[
    MinigameUI.lua
    미니게임 대기/진행/결과 UI
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Modules.Constants)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MinigameUI = {}

function MinigameUI.Create(parentGui)
    local panel = Instance.new("Frame")
    panel.Name = "MinigamePanel"
    panel.Size = UDim2.new(0, 400, 0, 350)
    panel.Position = UDim2.new(0.5, -200, 0.5, -175)
    panel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    panel.BackgroundTransparency = 0.05
    panel.Visible = false
    panel.Parent = parentGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = panel

    -- 제목
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 50)
    title.BackgroundTransparency = 1
    title.Text = "웨이브 디펜스"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextSize = 24
    title.Font = Enum.Font.GothamBold
    title.Parent = panel

    -- 닫기 버튼
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 36, 0, 36)
    closeBtn.Position = UDim2.new(1, -44, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = panel

    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 8)
    closeBtnCorner.Parent = closeBtn

    -- 설명
    local desc = Instance.new("TextLabel")
    desc.Name = "Description"
    desc.Size = UDim2.new(1, -40, 0, 60)
    desc.Position = UDim2.new(0, 20, 0, 55)
    desc.BackgroundTransparency = 1
    desc.Text = "3웨이브의 몬스터를 물리치고 보상을 획득하세요!\n장착한 무기와 펫이 전투에 영향을 줍니다."
    desc.TextColor3 = Color3.fromRGB(180, 180, 180)
    desc.TextSize = 13
    desc.Font = Enum.Font.Gotham
    desc.TextWrapped = true
    desc.Parent = panel

    -- 보상 안내
    local rewardInfo = Instance.new("Frame")
    rewardInfo.Name = "RewardInfo"
    rewardInfo.Size = UDim2.new(1, -40, 0, 100)
    rewardInfo.Position = UDim2.new(0, 20, 0, 125)
    rewardInfo.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    rewardInfo.Parent = panel

    local rewardCorner = Instance.new("UICorner")
    rewardCorner.CornerRadius = UDim.new(0, 8)
    rewardCorner.Parent = rewardInfo

    local rewardTitle = Instance.new("TextLabel")
    rewardTitle.Size = UDim2.new(1, 0, 0, 25)
    rewardTitle.BackgroundTransparency = 1
    rewardTitle.Text = "보상 안내"
    rewardTitle.TextColor3 = Color3.fromRGB(255, 200, 50)
    rewardTitle.TextSize = 14
    rewardTitle.Font = Enum.Font.GothamBold
    rewardTitle.Parent = rewardInfo

    local rewardText = Instance.new("TextLabel")
    rewardText.Size = UDim2.new(1, -16, 0, 70)
    rewardText.Position = UDim2.new(0, 8, 0, 25)
    rewardText.BackgroundTransparency = 1
    rewardText.Text = "Wave 1: 30~50 Coin\nWave 2: 50~80 Coin + Ticket(30%)\nWave 3: 100~150 Coin + Ticket(확정)\n올클리어 보너스: +50 Coin"
    rewardText.TextColor3 = Color3.fromRGB(180, 180, 180)
    rewardText.TextSize = 12
    rewardText.Font = Enum.Font.Gotham
    rewardText.TextWrapped = true
    rewardText.TextYAlignment = Enum.TextYAlignment.Top
    rewardText.Parent = rewardInfo

    -- 대기열 상태
    local queueLabel = Instance.new("TextLabel")
    queueLabel.Name = "QueueLabel"
    queueLabel.Size = UDim2.new(1, -40, 0, 25)
    queueLabel.Position = UDim2.new(0, 20, 0, 240)
    queueLabel.BackgroundTransparency = 1
    queueLabel.Text = ""
    queueLabel.TextColor3 = Color3.fromRGB(150, 220, 255)
    queueLabel.TextSize = 14
    queueLabel.Font = Enum.Font.Gotham
    queueLabel.Parent = panel

    -- 참가 버튼
    local joinBtn = Instance.new("TextButton")
    joinBtn.Name = "JoinBtn"
    joinBtn.Size = UDim2.new(1, -40, 0, 50)
    joinBtn.Position = UDim2.new(0, 20, 0, 275)
    joinBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
    joinBtn.Text = "참가하기"
    joinBtn.TextColor3 = Color3.new(1, 1, 1)
    joinBtn.TextSize = 20
    joinBtn.Font = Enum.Font.GothamBold
    joinBtn.Parent = panel

    local joinBtnCorner = Instance.new("UICorner")
    joinBtnCorner.CornerRadius = UDim.new(0, 10)
    joinBtnCorner.Parent = joinBtn

    MinigameUI.panel = panel
    return panel
end

-- 대기열 상태 업데이트
function MinigameUI.UpdateQueue(data)
    if not MinigameUI.panel then return end
    local label = MinigameUI.panel:FindFirstChild("QueueLabel")
    if label and data then
        if data.success then
            label.Text = data.message or "대기 중..."
        else
            label.Text = data.error or ""
        end
    end
end

-- 결과 화면
function MinigameUI.ShowResult(resultData)
    local existing = playerGui:FindFirstChild("MinigameResult")
    if existing then existing:Destroy() end

    if not resultData then return end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MinigameResult"
    screenGui.DisplayOrder = 10
    screenGui.Parent = playerGui

    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.Parent = screenGui

    local resultPanel = Instance.new("Frame")
    resultPanel.Size = UDim2.new(0, 350, 0, 280)
    resultPanel.Position = UDim2.new(0.5, -175, 0.5, -140)
    resultPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    resultPanel.Parent = screenGui

    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 12)
    panelCorner.Parent = resultPanel

    local resultTitle = Instance.new("TextLabel")
    resultTitle.Size = UDim2.new(1, 0, 0, 50)
    resultTitle.BackgroundTransparency = 1
    resultTitle.Text = resultData.allClear and "ALL CLEAR!" or "결과"
    resultTitle.TextColor3 = resultData.allClear and Color3.fromRGB(255, 215, 0) or Color3.new(1, 1, 1)
    resultTitle.TextSize = 28
    resultTitle.Font = Enum.Font.GothamBold
    resultTitle.Parent = resultPanel

    local details = Instance.new("TextLabel")
    details.Size = UDim2.new(1, -30, 0, 120)
    details.Position = UDim2.new(0, 15, 0, 60)
    details.BackgroundTransparency = 1
    details.Text = string.format(
        "클리어 웨이브: %d / %d\n처치 수: %d\n\n획득 코인: %d\n획득 티켓: %d",
        resultData.wavesCleared or 0,
        Constants.Minigame.WaveCount,
        resultData.kills or 0,
        resultData.coins or 0,
        resultData.tickets or 0
    )
    details.TextColor3 = Color3.new(1, 1, 1)
    details.TextSize = 16
    details.Font = Enum.Font.Gotham
    details.TextWrapped = true
    details.Parent = resultPanel

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(1, -30, 0, 40)
    closeBtn.Position = UDim2.new(0, 15, 0, 220)
    closeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    closeBtn.Text = "확인"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = resultPanel

    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 8)
    closeBtnCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
end

function MinigameUI.Toggle()
    if MinigameUI.panel then
        MinigameUI.panel.Visible = not MinigameUI.panel.Visible
    end
end

function MinigameUI.Show()
    if MinigameUI.panel then MinigameUI.panel.Visible = true end
end

function MinigameUI.Hide()
    if MinigameUI.panel then MinigameUI.panel.Visible = false end
end

return MinigameUI
