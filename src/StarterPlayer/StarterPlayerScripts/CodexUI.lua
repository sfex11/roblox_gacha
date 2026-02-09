--[[
    CodexUI.lua
    도감/세트 진행도 UI
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Modules.Constants)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CodexUI = {}

function CodexUI.Create(parentGui)
    local panel = Instance.new("Frame")
    panel.Name = "CodexPanel"
    panel.Size = UDim2.new(0, 550, 0, 550)
    panel.Position = UDim2.new(0.5, -275, 0.5, -275)
    panel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    panel.BackgroundTransparency = 0.05
    panel.Visible = false
    panel.Parent = parentGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = panel

    -- 제목 + 진행도
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 60)
    header.BackgroundTransparency = 1
    header.Parent = panel

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(0.5, 0, 1, 0)
    title.Position = UDim2.new(0, 15, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "도감"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextSize = 24
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local progressLabel = Instance.new("TextLabel")
    progressLabel.Name = "ProgressLabel"
    progressLabel.Size = UDim2.new(0.4, 0, 0, 25)
    progressLabel.Position = UDim2.new(0.55, 0, 0, 18)
    progressLabel.BackgroundTransparency = 1
    progressLabel.Text = "0 / 15 발견"
    progressLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    progressLabel.TextSize = 14
    progressLabel.Font = Enum.Font.Gotham
    progressLabel.TextXAlignment = Enum.TextXAlignment.Right
    progressLabel.Parent = header

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

    -- 탭 버튼 (전체/무기/펫/코스튬/세트)
    local tabBar = Instance.new("Frame")
    tabBar.Name = "TabBar"
    tabBar.Size = UDim2.new(1, -30, 0, 35)
    tabBar.Position = UDim2.new(0, 15, 0, 60)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent = panel

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 5)
    tabLayout.Parent = tabBar

    local tabs = { "전체", "무기", "펫", "코스튬", "세트" }
    for _, tabName in ipairs(tabs) do
        local tab = Instance.new("TextButton")
        tab.Name = "Tab_" .. tabName
        tab.Size = UDim2.new(0, 90, 1, 0)
        tab.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
        tab.Text = tabName
        tab.TextColor3 = Color3.fromRGB(180, 180, 180)
        tab.TextSize = 13
        tab.Font = Enum.Font.GothamBold
        tab.Parent = tabBar

        local tabCorner = Instance.new("UICorner")
        tabCorner.CornerRadius = UDim.new(0, 6)
        tabCorner.Parent = tab
    end

    -- 도감 그리드
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "CodexGrid"
    scrollFrame.Size = UDim2.new(1, -30, 0, 340)
    scrollFrame.Position = UDim2.new(0, 15, 0, 105)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.Parent = panel

    local scrollCorner = Instance.new("UICorner")
    scrollCorner.CornerRadius = UDim.new(0, 8)
    scrollCorner.Parent = scrollFrame

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 95, 0, 110)
    gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = scrollFrame

    local gridPadding = Instance.new("UIPadding")
    gridPadding.PaddingTop = UDim.new(0, 8)
    gridPadding.PaddingLeft = UDim.new(0, 8)
    gridPadding.Parent = scrollFrame

    -- 세트 진행도 영역
    local setArea = Instance.new("Frame")
    setArea.Name = "SetArea"
    setArea.Size = UDim2.new(1, -30, 0, 80)
    setArea.Position = UDim2.new(0, 15, 0, 455)
    setArea.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    setArea.Visible = false
    setArea.Parent = panel

    local setCorner = Instance.new("UICorner")
    setCorner.CornerRadius = UDim.new(0, 8)
    setCorner.Parent = setArea

    CodexUI.panel = panel
    return panel
end

-- 도감 데이터로 UI 갱신
function CodexUI.Refresh(codexData, setData, progressData)
    if not CodexUI.panel then return end

    -- 진행도 업데이트
    if progressData then
        local header = CodexUI.panel:FindFirstChild("Header")
        if header then
            local label = header:FindFirstChild("ProgressLabel")
            if label then
                label.Text = tostring(progressData[1] or 0) .. " / " .. tostring(progressData[2] or 15) .. " 발견"
            end
        end
    end

    -- 그리드 갱신
    local grid = CodexUI.panel:FindFirstChild("CodexGrid")
    if not grid then return end

    for _, child in ipairs(grid:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    if codexData then
        local index = 0
        for templateId, info in pairs(codexData) do
            index = index + 1
            local card = CodexUI._createCodexCard(info, index)
            card.Parent = grid
        end

        local rows = math.ceil(index / 5)
        grid.CanvasSize = UDim2.new(0, 0, 0, rows * 118 + 16)
    end
end

function CodexUI._createCodexCard(info, index)
    local rarityInfo = Constants.RarityInfo[info.rarity]
    local discovered = info.discovered

    local card = Instance.new("Frame")
    card.Name = "Codex_" .. index
    card.BackgroundColor3 = discovered and Color3.fromRGB(45, 45, 60) or Color3.fromRGB(30, 30, 40)
    card.LayoutOrder = index

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 6)
    cardCorner.Parent = card

    if discovered then
        local stroke = Instance.new("UIStroke")
        stroke.Color = rarityInfo and rarityInfo.color or Color3.fromRGB(100, 100, 100)
        stroke.Thickness = 1.5
        stroke.Parent = card
    end

    -- 아이콘 (플레이스홀더)
    local iconFrame = Instance.new("Frame")
    iconFrame.Size = UDim2.new(0, 50, 0, 50)
    iconFrame.Position = UDim2.new(0.5, -25, 0, 8)
    iconFrame.BackgroundColor3 = discovered
        and (rarityInfo and rarityInfo.color or Color3.fromRGB(100, 100, 100))
        or Color3.fromRGB(40, 40, 40)
    iconFrame.BackgroundTransparency = discovered and 0.6 or 0.2
    iconFrame.Parent = card

    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, 6)
    iconCorner.Parent = iconFrame

    if not discovered then
        local questionMark = Instance.new("TextLabel")
        questionMark.Size = UDim2.new(1, 0, 1, 0)
        questionMark.BackgroundTransparency = 1
        questionMark.Text = "?"
        questionMark.TextColor3 = Color3.fromRGB(60, 60, 60)
        questionMark.TextSize = 24
        questionMark.Font = Enum.Font.GothamBold
        questionMark.Parent = iconFrame
    end

    -- 이름
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -6, 0, 20)
    nameLabel.Position = UDim2.new(0, 3, 0, 62)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = discovered and (info.name or "???") or "???"
    nameLabel.TextColor3 = discovered and Color3.new(1, 1, 1) or Color3.fromRGB(60, 60, 60)
    nameLabel.TextSize = 11
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = card

    -- 희귀도
    local rarityLabel = Instance.new("TextLabel")
    rarityLabel.Size = UDim2.new(1, 0, 0, 14)
    rarityLabel.Position = UDim2.new(0, 0, 0, 84)
    rarityLabel.BackgroundTransparency = 1
    rarityLabel.Text = rarityInfo and rarityInfo.displayName or ""
    rarityLabel.TextColor3 = discovered
        and (rarityInfo and rarityInfo.color or Color3.new(1, 1, 1))
        or Color3.fromRGB(60, 60, 60)
    rarityLabel.TextSize = 10
    rarityLabel.Font = Enum.Font.GothamBold
    rarityLabel.Parent = card

    return card
end

function CodexUI.Toggle()
    if CodexUI.panel then
        CodexUI.panel.Visible = not CodexUI.panel.Visible
    end
end

function CodexUI.Show()
    if CodexUI.panel then CodexUI.panel.Visible = true end
end

function CodexUI.Hide()
    if CodexUI.panel then CodexUI.panel.Visible = false end
end

return CodexUI
