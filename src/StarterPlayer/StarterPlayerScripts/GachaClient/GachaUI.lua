--[[
    GachaUI.lua
    가차 UI — 뽑기 버튼, 확률표, 결과 연출
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Modules.Constants)
local ItemDatabase = require(ReplicatedStorage.Modules.ItemDatabase)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GachaUI = {}

-------------------------------------------------------
-- 가차 패널 생성
-------------------------------------------------------
function GachaUI.Create(parentGui)
    local panel = Instance.new("Frame")
    panel.Name = "GachaPanel"
    panel.Size = UDim2.new(0, 500, 0, 600)
    panel.Position = UDim2.new(0.5, -250, 0.5, -300)
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
    title.Text = "가차"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextSize = 28
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

    -- 가차 머신 이미지 영역 (플레이스홀더)
    local machineFrame = Instance.new("Frame")
    machineFrame.Name = "MachineFrame"
    machineFrame.Size = UDim2.new(0, 200, 0, 200)
    machineFrame.Position = UDim2.new(0.5, -100, 0, 60)
    machineFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    machineFrame.Parent = panel

    local machineCorner = Instance.new("UICorner")
    machineCorner.CornerRadius = UDim.new(0, 100) -- 원형
    machineCorner.Parent = machineFrame

    local machineLabel = Instance.new("TextLabel")
    machineLabel.Size = UDim2.new(1, 0, 1, 0)
    machineLabel.BackgroundTransparency = 1
    machineLabel.Text = "GACHA"
    machineLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
    machineLabel.TextSize = 32
    machineLabel.Font = Enum.Font.GothamBold
    machineLabel.Parent = machineFrame

    -- 뽑기 버튼 영역
    local buttonArea = Instance.new("Frame")
    buttonArea.Name = "ButtonArea"
    buttonArea.Size = UDim2.new(1, -40, 0, 200)
    buttonArea.Position = UDim2.new(0, 20, 0, 280)
    buttonArea.BackgroundTransparency = 1
    buttonArea.Parent = panel

    -- 코인 1연 뽑기
    local singleCoinBtn = GachaUI._createPullButton(
        buttonArea, "SingleCoinBtn",
        "1연 뽑기 (100 Coin)",
        UDim2.new(0, 0, 0, 0),
        Color3.fromRGB(255, 180, 50)
    )

    -- 코인 10연 뽑기
    local multiCoinBtn = GachaUI._createPullButton(
        buttonArea, "MultiCoinBtn",
        "10연 뽑기 (900 Coin)",
        UDim2.new(0, 0, 0, 55),
        Color3.fromRGB(255, 130, 30)
    )

    -- 티켓 뽑기
    local ticketBtn = GachaUI._createPullButton(
        buttonArea, "TicketBtn",
        "티켓 뽑기 (1 Ticket)",
        UDim2.new(0, 0, 0, 110),
        Color3.fromRGB(100, 180, 255)
    )

    -- 확률 보기 버튼
    local oddsBtn = Instance.new("TextButton")
    oddsBtn.Name = "OddsBtn"
    oddsBtn.Size = UDim2.new(1, 0, 0, 35)
    oddsBtn.Position = UDim2.new(0, 0, 0, 170)
    oddsBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    oddsBtn.Text = "확률표 보기"
    oddsBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    oddsBtn.TextSize = 14
    oddsBtn.Font = Enum.Font.Gotham
    oddsBtn.Parent = buttonArea

    local oddsBtnCorner = Instance.new("UICorner")
    oddsBtnCorner.CornerRadius = UDim.new(0, 6)
    oddsBtnCorner.Parent = oddsBtn

    -- 보유 재화 표시
    local currencyInfo = Instance.new("TextLabel")
    currencyInfo.Name = "CurrencyInfo"
    currencyInfo.Size = UDim2.new(1, -40, 0, 30)
    currencyInfo.Position = UDim2.new(0, 20, 1, -50)
    currencyInfo.BackgroundTransparency = 1
    currencyInfo.Text = "Coin: 0 | Ticket: 0"
    currencyInfo.TextColor3 = Color3.fromRGB(180, 180, 180)
    currencyInfo.TextSize = 14
    currencyInfo.Font = Enum.Font.Gotham
    currencyInfo.Parent = panel

    GachaUI.panel = panel
    return panel
end

function GachaUI._createPullButton(parent, name, text, position, color)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(1, 0, 0, 45)
    btn.Position = position
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextSize = 16
    btn.Font = Enum.Font.GothamBold
    btn.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    return btn
end

-- 패널 열기/닫기
function GachaUI.Toggle()
    if GachaUI.panel then
        GachaUI.panel.Visible = not GachaUI.panel.Visible
    end
end

function GachaUI.Show()
    if GachaUI.panel then GachaUI.panel.Visible = true end
end

function GachaUI.Hide()
    if GachaUI.panel then GachaUI.panel.Visible = false end
end

-- 재화 업데이트
function GachaUI.UpdateCurrency(coins, tickets)
    if GachaUI.panel then
        local label = GachaUI.panel:FindFirstChild("CurrencyInfo")
        if label then
            label.Text = "Coin: " .. tostring(coins) .. " | Ticket: " .. tostring(tickets)
        end
    end
end

-------------------------------------------------------
-- 결과 카드 표시 (가차 연출 후 호출)
-------------------------------------------------------
function GachaUI.ShowResult(items)
    if not GachaUI.panel then return end

    local resultGui = playerGui:FindFirstChild("GachaResult")
    if resultGui then resultGui:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "GachaResult"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 100
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = playerGui

    -- 배경 오버레이 (클릭 가능하도록 TextButton)
    local overlay = Instance.new("TextButton")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.ZIndex = 1
    overlay.Text = ""
    overlay.AutoButtonColor = false
    overlay.Parent = screenGui

    -- 결과 컨테이너
    local container = Instance.new("ScrollingFrame")
    container.Name = "ResultContainer"
    container.Size = UDim2.new(0, 480, 0, 500)
    container.Position = UDim2.new(0.5, -240, 0.5, -250)
    container.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    container.ScrollBarThickness = 4
    container.ZIndex = 2
    container.Parent = screenGui

    local containerCorner = Instance.new("UICorner")
    containerCorner.CornerRadius = UDim.new(0, 12)
    containerCorner.Parent = container

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 140, 0, 180)
    gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = container

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.Parent = container

    -- 아이템 카드 생성
    for i, item in ipairs(items) do
        local card = GachaUI._createResultCard(item, i)
        card.Parent = container
    end

    -- 캔버스 크기 자동 조절
    local rows = math.ceil(#items / 3)
    container.CanvasSize = UDim2.new(0, 0, 0, rows * 190 + 20)

    -- 닫기 버튼
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseResultBtn"
    closeBtn.Size = UDim2.new(0, 200, 0, 45)
    closeBtn.Position = UDim2.new(0.5, -100, 0.5, 270)
    closeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    closeBtn.Text = "확인"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.ZIndex = 10
    closeBtn.Active = true
    closeBtn.Parent = screenGui

    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 8)
    closeBtnCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)

    -- 배경 클릭 시에도 닫기
    overlay.MouseButton1Click:Connect(function()
        if screenGui and screenGui.Parent then
            screenGui:Destroy()
        end
    end)

    overlay.Active = true
end

function GachaUI._createResultCard(item, index)
    local rarityInfo = Constants.RarityInfo[item.rarity] or Constants.RarityInfo.Common

    local card = Instance.new("Frame")
    card.Name = "Card_" .. index
    card.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    card.LayoutOrder = index

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 8)
    cardCorner.Parent = card

    -- 희귀도 테두리
    local stroke = Instance.new("UIStroke")
    stroke.Color = rarityInfo.color
    stroke.Thickness = 2
    stroke.Parent = card

    -- 희귀도 라벨
    local rarityLabel = Instance.new("TextLabel")
    rarityLabel.Size = UDim2.new(1, 0, 0, 20)
    rarityLabel.Position = UDim2.new(0, 0, 0, 5)
    rarityLabel.BackgroundTransparency = 1
    rarityLabel.Text = rarityInfo.displayName
    rarityLabel.TextColor3 = rarityInfo.color
    rarityLabel.TextSize = 12
    rarityLabel.Font = Enum.Font.GothamBold
    rarityLabel.Parent = card

    -- 아이콘 영역 (플레이스홀더)
    local iconFrame = Instance.new("Frame")
    iconFrame.Size = UDim2.new(0, 80, 0, 80)
    iconFrame.Position = UDim2.new(0.5, -40, 0, 28)
    iconFrame.BackgroundColor3 = rarityInfo.color
    iconFrame.BackgroundTransparency = 0.7
    iconFrame.Parent = card

    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, 8)
    iconCorner.Parent = iconFrame

    -- 아이템 이름
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -10, 0, 18)
    nameLabel.Position = UDim2.new(0, 5, 0, 112)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = item.name or "???"
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextSize = 13
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = card

    -- 아이템 설명
    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -10, 0, 24)
    descLabel.Position = UDim2.new(0, 5, 0, 132)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = item.description or ""
    descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    descLabel.TextSize = 10
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextWrapped = true
    descLabel.TextTruncate = Enum.TextTruncate.AtEnd
    descLabel.Parent = card

    -- Flavor Text
    local flavorLabel = Instance.new("TextLabel")
    flavorLabel.Size = UDim2.new(1, -10, 0, 16)
    flavorLabel.Position = UDim2.new(0, 5, 0, 158)
    flavorLabel.BackgroundTransparency = 1
    flavorLabel.Text = "\"" .. (item.flavorText or "") .. "\""
    flavorLabel.TextColor3 = Color3.fromRGB(180, 180, 255)
    flavorLabel.TextSize = 9
    flavorLabel.Font = Enum.Font.Gotham
    flavorLabel.TextWrapped = true
    flavorLabel.TextTruncate = Enum.TextTruncate.AtEnd
    flavorLabel.Parent = card

    -- NEW / 중복 표시
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 0, 18)
    statusLabel.Position = UDim2.new(0, 0, 0, 176)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextSize = 11
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.Parent = card

    if item.isNew then
        statusLabel.Text = "NEW!"
        statusLabel.TextColor3 = Color3.fromRGB(50, 255, 50)
    elseif item.isDuplicate then
        statusLabel.Text = "+" .. tostring(item.duplicateCoins) .. " Coin"
        statusLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    end

    return card
end

-------------------------------------------------------
-- 확률표 패널
-------------------------------------------------------
function GachaUI.ShowOddsTable(oddsData)
    local existing = playerGui:FindFirstChild("OddsPanel")
    if existing then existing:Destroy() end

    if not oddsData then return end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "OddsPanel"
    screenGui.DisplayOrder = 10
    screenGui.Parent = playerGui

    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 350, 0, 320)
    panel.Position = UDim2.new(0.5, -175, 0.5, -160)
    panel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    panel.Parent = screenGui

    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 12)
    panelCorner.Parent = panel

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Text = "확률표 - " .. (oddsData.poolName or "")
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextSize = 20
    title.Font = Enum.Font.GothamBold
    title.Parent = panel

    -- 확률 목록
    local yOffset = 50
    local rarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

    for _, rarity in ipairs(rarityOrder) do
        local info = oddsData.odds[rarity]
        if info then
            local rarityInfo = Constants.RarityInfo[rarity]

            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -30, 0, 35)
            row.Position = UDim2.new(0, 15, 0, yOffset)
            row.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
            row.Parent = panel

            local rowCorner = Instance.new("UICorner")
            rowCorner.CornerRadius = UDim.new(0, 6)
            rowCorner.Parent = row

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(0.5, 0, 1, 0)
            nameLabel.Position = UDim2.new(0, 10, 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = info.displayName
            nameLabel.TextColor3 = rarityInfo and rarityInfo.color or Color3.new(1, 1, 1)
            nameLabel.TextSize = 16
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.Parent = row

            local percentLabel = Instance.new("TextLabel")
            percentLabel.Size = UDim2.new(0.4, 0, 1, 0)
            percentLabel.Position = UDim2.new(0.6, 0, 0, 0)
            percentLabel.BackgroundTransparency = 1
            percentLabel.Text = tostring(info.percent) .. "%"
            percentLabel.TextColor3 = Color3.new(1, 1, 1)
            percentLabel.TextSize = 16
            percentLabel.Font = Enum.Font.GothamBold
            percentLabel.TextXAlignment = Enum.TextXAlignment.Right
            percentLabel.Parent = row

            yOffset = yOffset + 42
        end
    end

    -- 닫기 버튼
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(1, -30, 0, 35)
    closeBtn.Position = UDim2.new(0, 15, 0, yOffset + 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    closeBtn.Text = "닫기"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.TextSize = 16
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = panel

    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 6)
    closeBtnCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
end

return GachaUI
