--[[
    HubUI.lua
    메인 HUD — 재화 표시, 네비게이션 버튼, 각 UI 패널 토글
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Modules.Constants)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local HubUI = {}

-- 재화 정보 (서버에서 업데이트)
HubUI.currency = { Coins = 0, Tickets = 0 }

-- 현재 열려있는 패널
HubUI.activePanel = nil

-------------------------------------------------------
-- 메인 ScreenGui 생성
-------------------------------------------------------
function HubUI.CreateMainGui()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MainHUD"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    -- 상단 재화 바
    local currencyBar = Instance.new("Frame")
    currencyBar.Name = "CurrencyBar"
    currencyBar.Size = UDim2.new(0, 300, 0, 40)
    currencyBar.Position = UDim2.new(1, -310, 0, 10)
    currencyBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    currencyBar.BackgroundTransparency = 0.2
    currencyBar.Parent = screenGui

    local currencyCorner = Instance.new("UICorner")
    currencyCorner.CornerRadius = UDim.new(0, 8)
    currencyCorner.Parent = currencyBar

    -- 코인 표시
    local coinLabel = Instance.new("TextLabel")
    coinLabel.Name = "CoinLabel"
    coinLabel.Size = UDim2.new(0.5, 0, 1, 0)
    coinLabel.Position = UDim2.new(0, 0, 0, 0)
    coinLabel.BackgroundTransparency = 1
    coinLabel.Text = "🪙 0"
    coinLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    coinLabel.TextSize = 18
    coinLabel.Font = Enum.Font.GothamBold
    coinLabel.Parent = currencyBar

    -- 티켓 표시
    local ticketLabel = Instance.new("TextLabel")
    ticketLabel.Name = "TicketLabel"
    ticketLabel.Size = UDim2.new(0.5, 0, 1, 0)
    ticketLabel.Position = UDim2.new(0.5, 0, 0, 0)
    ticketLabel.BackgroundTransparency = 1
    ticketLabel.Text = "🎫 0"
    ticketLabel.TextColor3 = Color3.fromRGB(150, 220, 255)
    ticketLabel.TextSize = 18
    ticketLabel.Font = Enum.Font.GothamBold
    ticketLabel.Parent = currencyBar

    -- 하단 메뉴 버튼 바
    local menuBar = Instance.new("Frame")
    menuBar.Name = "MenuBar"
    menuBar.Size = UDim2.new(0, 400, 0, 60)
    menuBar.Position = UDim2.new(0.5, -200, 1, -70)
    menuBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    menuBar.BackgroundTransparency = 0.2
    menuBar.Parent = screenGui

    local menuCorner = Instance.new("UICorner")
    menuCorner.CornerRadius = UDim.new(0, 12)
    menuCorner.Parent = menuBar

    local menuLayout = Instance.new("UIListLayout")
    menuLayout.FillDirection = Enum.FillDirection.Horizontal
    menuLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    menuLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    menuLayout.Padding = UDim.new(0, 10)
    menuLayout.Parent = menuBar

    -- 메뉴 버튼 생성
    local buttons = {
        { name = "GachaBtn", text = "가차", color = Color3.fromRGB(255, 100, 100) },
        { name = "InventoryBtn", text = "인벤토리", color = Color3.fromRGB(100, 200, 100) },
        { name = "CodexBtn", text = "도감", color = Color3.fromRGB(100, 150, 255) },
        { name = "MinigameBtn", text = "미니게임", color = Color3.fromRGB(255, 180, 50) },
    }

    for _, btnInfo in ipairs(buttons) do
        local btn = Instance.new("TextButton")
        btn.Name = btnInfo.name
        btn.Size = UDim2.new(0, 85, 0, 45)
        btn.BackgroundColor3 = btnInfo.color
        btn.Text = btnInfo.text
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.TextSize = 14
        btn.Font = Enum.Font.GothamBold
        btn.Parent = menuBar

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = btn
    end

    HubUI.screenGui = screenGui
    return screenGui
end

-- 재화 업데이트
function HubUI.UpdateCurrency(currencyData)
    HubUI.currency = currencyData
    local gui = HubUI.screenGui
    if not gui then return end

    local bar = gui:FindFirstChild("CurrencyBar")
    if bar then
        local coinLabel = bar:FindFirstChild("CoinLabel")
        local ticketLabel = bar:FindFirstChild("TicketLabel")
        if coinLabel then
            coinLabel.Text = "Coin " .. tostring(currencyData.Coins or 0)
        end
        if ticketLabel then
            ticketLabel.Text = "Ticket " .. tostring(currencyData.Tickets or 0)
        end
    end
end

return HubUI
