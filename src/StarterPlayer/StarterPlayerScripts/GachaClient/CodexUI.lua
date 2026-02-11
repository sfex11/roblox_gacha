--[[
    CodexUI.lua
    도감/세트 진행도 UI
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Modules.Constants)
local ItemDatabase = require(ReplicatedStorage.Modules.ItemDatabase)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CodexUI = {}

CodexUI._activeTab = "전체"
CodexUI._tabButtons = {}
CodexUI._data = {
    codex = nil,
    sets = nil,
    progress = nil,
}

local function setTabButtonStyle(tabBtn, isActive)
    if not tabBtn then return end
    tabBtn.BackgroundColor3 = isActive and Color3.fromRGB(70, 70, 100) or Color3.fromRGB(50, 50, 70)
    tabBtn.TextColor3 = isActive and Color3.new(1, 1, 1) or Color3.fromRGB(180, 180, 180)
end

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
        local currentTabName = tabName
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

        CodexUI._tabButtons[currentTabName] = tab

        tab.MouseButton1Click:Connect(function()
            CodexUI.SetActiveTab(currentTabName)
        end)
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

    -- 세트 리스트 (세트 탭에서 표시)
    local setList = Instance.new("ScrollingFrame")
    setList.Name = "SetList"
    setList.Size = scrollFrame.Size
    setList.Position = scrollFrame.Position
    setList.BackgroundColor3 = scrollFrame.BackgroundColor3
    setList.ScrollBarThickness = 4
    setList.Visible = false
    setList.Parent = panel

    local setListCorner = Instance.new("UICorner")
    setListCorner.CornerRadius = UDim.new(0, 8)
    setListCorner.Parent = setList

    local setLayout = Instance.new("UIListLayout")
    setLayout.Padding = UDim.new(0, 10)
    setLayout.SortOrder = Enum.SortOrder.LayoutOrder
    setLayout.Parent = setList

    local setPadding = Instance.new("UIPadding")
    setPadding.PaddingTop = UDim.new(0, 10)
    setPadding.PaddingLeft = UDim.new(0, 10)
    setPadding.PaddingRight = UDim.new(0, 10)
    setPadding.Parent = setList

    CodexUI.panel = panel
    CodexUI._setList = setList

    -- 초기 탭 스타일
    CodexUI.SetActiveTab(CodexUI._activeTab)
    return panel
end

function CodexUI.SetActiveTab(tabName)
    CodexUI._activeTab = tabName or "전체"
    for name, btn in pairs(CodexUI._tabButtons) do
        setTabButtonStyle(btn, name == CodexUI._activeTab)
    end
    CodexUI._render()
end

-- 도감 데이터로 UI 갱신
function CodexUI.Refresh(codexData, setData, progressData)
    if not CodexUI.panel then return end

    CodexUI._data.codex = codexData
    CodexUI._data.sets = setData
    CodexUI._data.progress = progressData

    CodexUI._render()
end

function CodexUI._render()
    if not CodexUI.panel then return end

    local codexData = CodexUI._data.codex
    local setData = CodexUI._data.sets
    local progressData = CodexUI._data.progress

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

    local grid = CodexUI.panel:FindFirstChild("CodexGrid")
    local setList = CodexUI._setList
    if not grid or not setList then return end

    if CodexUI._activeTab == "세트" then
        grid.Visible = false
        setList.Visible = true

        for _, child in ipairs(setList:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end

        local cards = {}
        if setData then
            for setId, info in pairs(setData) do
                table.insert(cards, info)
            end
        end
        table.sort(cards, function(a, b)
            return (a.displayName or "") < (b.displayName or "")
        end)

        for i, info in ipairs(cards) do
            local card = CodexUI._createSetCard(info, i)
            card.Parent = setList
        end

        task.defer(function()
            local layout = setList:FindFirstChildOfClass("UIListLayout")
            if layout then
                setList.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
            end
        end)

        return
    end

    grid.Visible = true
    setList.Visible = false

    -- 그리드 갱신
    for _, child in ipairs(grid:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    if codexData then
        local list = {}
        for _, info in pairs(codexData) do
            -- 탭 필터
            if CodexUI._activeTab == "전체"
                or (CodexUI._activeTab == "무기" and info.category == Constants.Category.Weapon)
                or (CodexUI._activeTab == "펫" and info.category == Constants.Category.Pet)
                or (CodexUI._activeTab == "코스튬" and info.category == Constants.Category.Costume) then
                table.insert(list, info)
            end
        end

        table.sort(list, function(a, b)
            local aDiscovered = a.discovered and 1 or 0
            local bDiscovered = b.discovered and 1 or 0
            if aDiscovered ~= bDiscovered then
                return aDiscovered > bDiscovered
            end
            local ao = (Constants.RarityInfo[a.rarity] and Constants.RarityInfo[a.rarity].order) or 999
            local bo = (Constants.RarityInfo[b.rarity] and Constants.RarityInfo[b.rarity].order) or 999
            if ao ~= bo then
                return ao > bo -- 높은 희귀도 우선
            end
            return (a.name or "") < (b.name or "")
        end)

        for i, info in ipairs(list) do
            local card = CodexUI._createCodexCard(info, i)
            card.Parent = grid
        end

        local rows = math.ceil(#list / 5)
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

function CodexUI._createSetCard(info, index)
    local card = Instance.new("Frame")
    card.Name = "Set_" .. index
    card.Size = UDim2.new(1, 0, 0, 140)
    card.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    card.LayoutOrder = index

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.5
    stroke.Color = info.completed and Color3.fromRGB(50, 255, 120) or Color3.fromRGB(90, 90, 120)
    stroke.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 24)
    title.Position = UDim2.new(0, 10, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = (info.displayName or "세트") .. (info.completed and " (완료)" or "")
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card

    local progress = Instance.new("TextLabel")
    progress.Size = UDim2.new(0, 110, 0, 20)
    progress.Position = UDim2.new(1, -120, 0, 10)
    progress.BackgroundTransparency = 1
    progress.Text = tostring(info.ownedCount or 0) .. "/" .. tostring(info.totalCount or 0)
    progress.TextColor3 = Color3.fromRGB(200, 200, 200)
    progress.TextSize = 14
    progress.Font = Enum.Font.GothamBold
    progress.TextXAlignment = Enum.TextXAlignment.Right
    progress.Parent = card

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -20, 0, 34)
    desc.Position = UDim2.new(0, 10, 0, 34)
    desc.BackgroundTransparency = 1
    desc.Text = info.description or ""
    desc.TextColor3 = Color3.fromRGB(170, 170, 170)
    desc.TextSize = 12
    desc.Font = Enum.Font.Gotham
    desc.TextWrapped = true
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextYAlignment = Enum.TextYAlignment.Top
    desc.Parent = card

    -- 구성 아이템 요약
    local itemLines = {}
    if info.items then
        for _, it in ipairs(info.items) do
            local template = ItemDatabase.GetTemplate(it.templateId)
            local itemName = template and template.name or it.templateId
            table.insert(itemLines, (it.owned and "✓ " or "• ") .. itemName)
        end
    end

    local itemsLabel = Instance.new("TextLabel")
    itemsLabel.Size = UDim2.new(1, -20, 0, 46)
    itemsLabel.Position = UDim2.new(0, 10, 0, 72)
    itemsLabel.BackgroundTransparency = 1
    itemsLabel.Text = table.concat(itemLines, "\n")
    itemsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    itemsLabel.TextSize = 12
    itemsLabel.Font = Enum.Font.Gotham
    itemsLabel.TextWrapped = true
    itemsLabel.TextXAlignment = Enum.TextXAlignment.Left
    itemsLabel.TextYAlignment = Enum.TextYAlignment.Top
    itemsLabel.Parent = card

    -- 보상
    local rewardText = ""
    if info.rewards then
        if info.rewards.coins then
            rewardText = rewardText .. "+ " .. tostring(info.rewards.coins) .. " Coin"
        end
        if info.rewards.title then
            if rewardText ~= "" then rewardText = rewardText .. "  " end
            rewardText = rewardText .. "칭호: " .. tostring(info.rewards.title)
        end
    end

    local rewardLabel = Instance.new("TextLabel")
    rewardLabel.Size = UDim2.new(1, -20, 0, 18)
    rewardLabel.Position = UDim2.new(0, 10, 1, -24)
    rewardLabel.BackgroundTransparency = 1
    rewardLabel.Text = rewardText
    rewardLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
    rewardLabel.TextSize = 12
    rewardLabel.Font = Enum.Font.GothamBold
    rewardLabel.TextXAlignment = Enum.TextXAlignment.Left
    rewardLabel.Parent = card

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
