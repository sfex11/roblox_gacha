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
    equipLayout.Padding = UDim.new(0, 15)
    equipLayout.Parent = equipArea

    -- 장착 슬롯 3개 (무기/펫/코스튬)
    for _, cat in ipairs({"Weapon", "Pet", "Costume"}) do
        local slot = Instance.new("Frame")
        slot.Name = "EquipSlot_" .. cat
        slot.Size = UDim2.new(0, 65, 0, 65)
        slot.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
        slot.Parent = equipArea

        local slotCorner = Instance.new("UICorner")
        slotCorner.CornerRadius = UDim.new(0, 8)
        slotCorner.Parent = slot

        local slotLabel = Instance.new("TextLabel")
        slotLabel.Size = UDim2.new(1, 0, 0, 15)
        slotLabel.Position = UDim2.new(0, 0, 1, 0)
        slotLabel.BackgroundTransparency = 1
        slotLabel.Text = Constants.CategoryInfo[cat].displayName
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
function InventoryUI.Refresh(inventoryData, equippedData)
    if not InventoryUI.panel then return end

    local grid = InventoryUI.panel:FindFirstChild("ItemGrid")
    if not grid then return end

    -- 기존 아이템 카드 제거
    for _, child in ipairs(grid:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    -- 장착 슬롯 업데이트
    local equipArea = InventoryUI.panel:FindFirstChild("EquipArea")
    if equipArea and equippedData then
        for cat, info in pairs(equippedData) do
            local slot = equipArea:FindFirstChild("EquipSlot_" .. cat)
            if slot then
                local itemLabel = slot:FindFirstChild("ItemLabel")
                local template = ItemDatabase.GetTemplate(info.templateId)
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

    -- 인벤토리 아이템 카드 생성
    if inventoryData then
        for i, item in ipairs(inventoryData) do
            local template = ItemDatabase.GetTemplate(item.templateId)
            if template then
                local card = InventoryUI._createItemCard(template, i)
                card.Parent = grid
            end
        end

        -- 캔버스 크기
        local rows = math.ceil(#inventoryData / 5)
        grid.CanvasSize = UDim2.new(0, 0, 0, rows * 103 + 16)
    end
end

function InventoryUI._createItemCard(template, slotIndex)
    local rarityInfo = Constants.RarityInfo[template.rarity]

    local card = Instance.new("Frame")
    card.Name = "Item_" .. slotIndex
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
    catLabel.TextSize = 10
    catLabel.Font = Enum.Font.Gotham
    catLabel.Parent = card

    -- 이름
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -6, 0, 30)
    nameLabel.Position = UDim2.new(0, 3, 0.5, -5)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = template.name
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextSize = 12
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextWrapped = true
    nameLabel.Parent = card

    -- 희귀도
    local rarityLabel = Instance.new("TextLabel")
    rarityLabel.Size = UDim2.new(1, 0, 0, 14)
    rarityLabel.Position = UDim2.new(0, 0, 1, -17)
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
    -- 클릭 이벤트는 MainClient에서 연결

    return card
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
