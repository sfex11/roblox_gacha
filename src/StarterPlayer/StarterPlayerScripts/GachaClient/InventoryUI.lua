--[[
    InventoryUI.lua
    인벤토리/장착 UI
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Modules.Constants)
local ItemDatabase = require(ReplicatedStorage.Modules.ItemDatabase)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local InventoryUI = {}

-- 외부(메인 클라이언트)에서 주입하는 액션 콜백
InventoryUI._actions = {
    onEquip = nil,    -- function(slotIndex)
    onUnequip = nil,  -- function(category)
}

function InventoryUI.BindActions(actions)
    InventoryUI._actions.onEquip = actions and actions.onEquip or nil
    InventoryUI._actions.onUnequip = actions and actions.onUnequip or nil
end

function InventoryUI.Create(parentGui)
    local panel = Instance.new("Frame")
    panel.Name = "InventoryPanel"
    panel.Size = UDim2.new(0, 550, 0, 500)
    panel.Position = UDim2.new(0.5, -275, 0.5, -250)
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
    title.Text = "인벤토리"
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

    -- 장착 슬롯 영역
    local equipArea = Instance.new("Frame")
    equipArea.Name = "EquipArea"
    equipArea.Size = UDim2.new(1, -30, 0, 80)
    equipArea.Position = UDim2.new(0, 15, 0, 55)
    equipArea.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    equipArea.Parent = panel

    local equipCorner = Instance.new("UICorner")
    equipCorner.CornerRadius = UDim.new(0, 8)
    equipCorner.Parent = equipArea

    local equipLayout = Instance.new("UIListLayout")
    equipLayout.FillDirection = Enum.FillDirection.Horizontal
    equipLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    equipLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    equipLayout.Padding = UDim.new(0, 10)
    equipLayout.Parent = equipArea

    -- 장착 슬롯 4개 (무기/펫/코스튬/UGC)
    for _, cat in ipairs({"Weapon", "Pet", "Costume", "UGC"}) do
        local category = cat
        local slot = Instance.new("Frame")
        slot.Name = "EquipSlot_" .. category
        slot.Size = UDim2.new(0, 60, 0, 65)
        slot.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
        slot.Parent = equipArea

        local slotCorner = Instance.new("UICorner")
        slotCorner.CornerRadius = UDim.new(0, 8)
        slotCorner.Parent = slot

        local slotLabel = Instance.new("TextLabel")
        slotLabel.Size = UDim2.new(1, 0, 0, 15)
        slotLabel.Position = UDim2.new(0, 0, 1, 0)
        slotLabel.BackgroundTransparency = 1
        slotLabel.Text = Constants.CategoryInfo[category].displayName
        slotLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        slotLabel.TextSize = 11
        slotLabel.Font = Enum.Font.Gotham
        slotLabel.Parent = slot

        local itemLabel = Instance.new("TextLabel")
        itemLabel.Name = "ItemLabel"
        itemLabel.Size = UDim2.new(1, -4, 1, -4)
        itemLabel.Position = UDim2.new(0, 2, 0, 2)
        itemLabel.BackgroundTransparency = 1
        itemLabel.Text = "-"
        itemLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
        itemLabel.TextSize = 11
        itemLabel.Font = Enum.Font.Gotham
        itemLabel.TextWrapped = true
        itemLabel.Parent = slot

        -- 슬롯 클릭으로 해제 요청
        local unequipBtn = Instance.new("TextButton")
        unequipBtn.Name = "UnequipBtn"
        unequipBtn.Size = UDim2.new(1, 0, 1, 0)
        unequipBtn.BackgroundTransparency = 1
        unequipBtn.Text = ""
        unequipBtn.Parent = slot

        unequipBtn.MouseButton1Click:Connect(function()
            if InventoryUI._actions.onUnequip then
                InventoryUI._actions.onUnequip(category)
            end
        end)
    end

    -- 인벤토리 그리드
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ItemGrid"
    scrollFrame.Size = UDim2.new(1, -30, 0, 330)
    scrollFrame.Position = UDim2.new(0, 15, 0, 150)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.Parent = panel

    local scrollCorner = Instance.new("UICorner")
    scrollCorner.CornerRadius = UDim.new(0, 8)
    scrollCorner.Parent = scrollFrame

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 95, 0, 95)
    gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = scrollFrame

    local gridPadding = Instance.new("UIPadding")
    gridPadding.PaddingTop = UDim.new(0, 8)
    gridPadding.PaddingLeft = UDim.new(0, 8)
    gridPadding.Parent = scrollFrame

    InventoryUI.panel = panel
    return panel
end

-- 인벤토리 데이터로 UI 갱신
function InventoryUI.Refresh(inventoryData, equippedData, templatesById)
    if not InventoryUI.panel then return end

    local grid = InventoryUI.panel:FindFirstChild("ItemGrid")
    if not grid then return end

    local function getTemplate(templateId)
        if templatesById and templatesById[templateId] then
            return templatesById[templateId]
        end
        return ItemDatabase.GetTemplate(templateId)
    end

    -- 기존 아이템 카드 제거
    for _, child in ipairs(grid:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    -- 장착 슬롯 업데이트
    local equipArea = InventoryUI.panel:FindFirstChild("EquipArea")
    if equipArea then
        -- 초기화(해제 시 라벨 잔상 방지)
        for _, cat in ipairs({"Weapon", "Pet", "Costume", "UGC"}) do
            local slot = equipArea:FindFirstChild("EquipSlot_" .. cat)
            if slot then
                local itemLabel = slot:FindFirstChild("ItemLabel")
                if itemLabel then
                    itemLabel.Text = "-"
                    itemLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
                end
            end
        end

        if equippedData then
            for cat, info in pairs(equippedData) do
                local slot = equipArea:FindFirstChild("EquipSlot_" .. cat)
                if slot then
                    local itemLabel = slot:FindFirstChild("ItemLabel")
                    local template = getTemplate(info.templateId)
                    if itemLabel and template then
                        itemLabel.Text = template.name
                        local rarityInfo = Constants.RarityInfo[template.rarity]
                        if rarityInfo then
                            itemLabel.TextColor3 = rarityInfo.color
                        end
                    end
                end
            end
        end
    end

    -- 인벤토리 아이템 카드 생성
    if inventoryData then
        for i, item in ipairs(inventoryData) do
            local template = getTemplate(item.templateId)
            if template then
                local card = InventoryUI._createItemCard(template, i)
                card.Parent = grid
            end
        end

        -- 캔버스 크기
        local rows = math.ceil(#inventoryData / 5)
        grid.CanvasSize = UDim2.new(0, 0, 0, rows * 133 + 16)
    end
end

function InventoryUI._createItemCard(template, slotIndex)
    local rarityInfo = Constants.RarityInfo[template.rarity]

    local card = Instance.new("Frame")
    card.Name = "Item_" .. slotIndex
    card.Size = UDim2.new(0, 100, 0, 130)  -- 높이 증가
    card.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    card.LayoutOrder = slotIndex

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 6)
    cardCorner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = rarityInfo and rarityInfo.color or Color3.fromRGB(100, 100, 100)
    stroke.Thickness = 1.5
    stroke.Parent = card

    -- 카테고리 아이콘 (텍스트 대체)
    local catLabel = Instance.new("TextLabel")
    catLabel.Size = UDim2.new(1, 0, 0, 14)
    catLabel.Position = UDim2.new(0, 0, 0, 3)
    catLabel.BackgroundTransparency = 1
    catLabel.Text = Constants.CategoryInfo[template.category] and Constants.CategoryInfo[template.category].displayName or ""
    catLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    catLabel.TextSize = 9
    catLabel.Font = Enum.Font.Gotham
    catLabel.Parent = card

    -- 이름
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -6, 0, 22)
    nameLabel.Position = UDim2.new(0, 3, 0, 18)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = template.name
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextSize = 11
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextWrapped = true
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = card

    -- 설명 (추가)
    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -6, 0, 40)
    descLabel.Position = UDim2.new(0, 3, 0, 43)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = template.description or ""
    descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    descLabel.TextSize = 8
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextWrapped = true
    descLabel.TextTruncate = Enum.TextTruncate.AtEnd
    descLabel.TextYAlignment = Enum.TextYAlignment.Top
    descLabel.Parent = card

    -- 희귀도
    local rarityLabel = Instance.new("TextLabel")
    rarityLabel.Size = UDim2.new(1, 0, 0, 14)
    rarityLabel.Position = UDim2.new(0, 0, 1, -30)
    rarityLabel.BackgroundTransparency = 1
    rarityLabel.Text = rarityInfo and rarityInfo.displayName or ""
    rarityLabel.TextColor3 = rarityInfo and rarityInfo.color or Color3.new(1, 1, 1)
    rarityLabel.TextSize = 10
    rarityLabel.Font = Enum.Font.GothamBold
    rarityLabel.Parent = card

    -- 장착 버튼 (클릭)
    local equipBtn = Instance.new("TextButton")
    equipBtn.Name = "EquipBtn"
    equipBtn.Size = UDim2.new(1, 0, 1, 0)
    equipBtn.BackgroundTransparency = 1
    equipBtn.Text = ""
    equipBtn.Parent = card
    equipBtn.MouseButton1Click:Connect(function()
        -- 장착
        if InventoryUI._actions.onEquip then
            InventoryUI._actions.onEquip(slotIndex)
        end
    end)

    return card
end

-- 아이템 상세 정보 팝업
function InventoryUI.ShowItemDetail(item)
    if not InventoryUI.panel then return end

    -- 기존 팝업 제거
    local existing = playerGui:FindFirstChild("ItemDetailPopup")
    if existing then existing:Destroy() end

    local popup = Instance.new("ScreenGui")
    popup.Name = "ItemDetailPopup"
    popup.DisplayOrder = 50
    popup.Parent = playerGui

    -- 배경 오버레이
    local overlay = Instance.new("TextButton")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.Text = ""
    overlay.AutoButtonColor = false
    overlay.Parent = popup

    -- 상세 패널
    local detailPanel = Instance.new("Frame")
    detailPanel.Size = UDim2.new(0, 350, 0, 280)
    detailPanel.Position = UDim2.new(0.5, -175, 0.5, -140)
    detailPanel.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    detailPanel.Parent = popup

    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 12)
    panelCorner.Parent = detailPanel

    local rarityInfo = Constants.RarityInfo[item.rarity] or {}

    -- 희귀도 헤더
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 50)
    header.BackgroundColor3 = rarityInfo.color or Color3.fromRGB(100, 100, 100)
    header.Parent = detailPanel

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 12)
    headerCorner.Parent = header

    -- 희귀도 텍스트
    local rarityText = Instance.new("TextLabel")
    rarityText.Size = UDim2.new(1, 0, 1, 0)
    rarityText.BackgroundTransparency = 1
    rarityText.Text = rarityInfo.displayName or item.rarity
    rarityText.TextColor3 = Color3.new(1, 1, 1)
    rarityText.TextSize = 20
    rarityText.Font = Enum.Font.GothamBold
    rarityText.Parent = header

    -- 아이템 이름
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -20, 0, 30)
    nameLabel.Position = UDim2.new(0, 10, 0, 60)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = item.name
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextSize = 18
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = detailPanel

    -- 카테고리
    local catLabel = Instance.new("TextLabel")
    catLabel.Size = UDim2.new(1, -20, 0, 20)
    catLabel.Position = UDim2.new(0, 10, 0, 95)
    catLabel.BackgroundTransparency = 1
    catLabel.Text = Constants.CategoryInfo[item.category] and Constants.CategoryInfo[item.category].displayName or ""
    catLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    catLabel.TextSize = 12
    catLabel.Font = Enum.Font.Gotham
    catLabel.TextXAlignment = Enum.TextXAlignment.Left
    catLabel.Parent = detailPanel

    -- 설명
    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -20, 0, 60)
    descLabel.Position = UDim2.new(0, 10, 0, 125)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = item.description or ""
    descLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    descLabel.TextSize = 13
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextWrapped = true
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextYAlignment = Enum.TextYAlignment.Top
    descLabel.Parent = detailPanel

    -- Flavor Text
    local flavorLabel = Instance.new("TextLabel")
    flavorLabel.Size = UDim2.new(1, -20, 0, 40)
    flavorLabel.Position = UDim2.new(0, 10, 0, 195)
    flavorLabel.BackgroundTransparency = 1
    flavorLabel.Text = "\"" .. (item.flavorText or "") .. "\""
    flavorLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
    flavorLabel.TextSize = 11
    flavorLabel.Font = Enum.Font.Gotham
    flavorLabel.TextWrapped = true
    flavorLabel.TextXAlignment = Enum.TextXAlignment.Left
    flavorLabel.TextYAlignment = Enum.TextYAlignment.Top
    flavorLabel.Parent = detailPanel

    -- 닫기 버튼
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 80, 0, 30)
    closeBtn.Position = UDim2.new(0.5, -40, 1, -40)
    closeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    closeBtn.Text = "닫기"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = detailPanel

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn

    local function closePopup()
        popup:Destroy()
    end

    closeBtn.MouseButton1Click:Connect(closePopup)
    overlay.MouseButton1Click:Connect(closePopup)
end

function InventoryUI.Toggle()
    if InventoryUI.panel then
        InventoryUI.panel.Visible = not InventoryUI.panel.Visible
    end
end

function InventoryUI.Show()
    if InventoryUI.panel then InventoryUI.panel.Visible = true end
end

function InventoryUI.Hide()
    if InventoryUI.panel then InventoryUI.panel.Visible = false end
end

return InventoryUI
