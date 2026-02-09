--[[
    InventoryService.lua
    인벤토리 CRUD / 장착/해제 관리
]]

local DataManager = require(script.Parent.DataManager)
local Constants = require(game.ReplicatedStorage.Modules.Constants)
local ItemDatabase = require(game.ReplicatedStorage.Modules.ItemDatabase)

local InventoryService = {}

-- 인벤토리에 아이템 추가
function InventoryService.AddItem(userId, templateId)
    local data = DataManager.GetData(userId)
    if not data then return false, "데이터 없음" end

    if #data.inventory >= Constants.MaxInventorySlots then
        return false, "인벤토리 가득 참"
    end

    local template = ItemDatabase.GetTemplate(templateId)
    if not template then return false, "존재하지 않는 아이템" end

    local item = {
        templateId = templateId,
        obtainedAt = os.time(),
        slotIndex = #data.inventory + 1,
    }
    table.insert(data.inventory, item)

    return true, item
end

-- 인벤토리에서 아이템 제거 (슬롯 인덱스 기준)
function InventoryService.RemoveItem(userId, slotIndex)
    local data = DataManager.GetData(userId)
    if not data then return false end

    if slotIndex < 1 or slotIndex > #data.inventory then
        return false
    end

    -- 장착 중이면 해제
    local item = data.inventory[slotIndex]
    local template = ItemDatabase.GetTemplate(item.templateId)
    if template and data.equipped[template.category] == slotIndex then
        data.equipped[template.category] = nil
    end

    table.remove(data.inventory, slotIndex)

    -- 슬롯 인덱스 재정렬
    for i, inv in ipairs(data.inventory) do
        inv.slotIndex = i
    end

    -- 장착 인덱스 업데이트
    for cat, eqSlot in pairs(data.equipped) do
        if eqSlot and eqSlot > slotIndex then
            data.equipped[cat] = eqSlot - 1
        end
    end

    return true
end

-- 장착
function InventoryService.Equip(userId, slotIndex)
    local data = DataManager.GetData(userId)
    if not data then return false, "데이터 없음" end

    local item = data.inventory[slotIndex]
    if not item then return false, "아이템 없음" end

    local template = ItemDatabase.GetTemplate(item.templateId)
    if not template then return false, "템플릿 없음" end

    data.equipped[template.category] = slotIndex
    return true
end

-- 해제
function InventoryService.Unequip(userId, category)
    local data = DataManager.GetData(userId)
    if not data then return false end

    data.equipped[category] = nil
    return true
end

-- 장착 정보 조회
function InventoryService.GetEquipped(userId)
    local data = DataManager.GetData(userId)
    if not data then return {} end

    local result = {}
    for category, slotIndex in pairs(data.equipped) do
        if slotIndex and data.inventory[slotIndex] then
            result[category] = {
                slotIndex = slotIndex,
                templateId = data.inventory[slotIndex].templateId,
            }
        end
    end
    return result
end

-- 인벤토리 목록 조회
function InventoryService.GetInventory(userId)
    local data = DataManager.GetData(userId)
    if not data then return {} end
    return data.inventory
end

-- 아이템 보유 여부
function InventoryService.HasItem(userId, templateId)
    local data = DataManager.GetData(userId)
    if not data then return false end

    for _, item in ipairs(data.inventory) do
        if item.templateId == templateId then
            return true
        end
    end
    return false
end

-- 전투 스탯 계산 (장착 아이템 기반)
function InventoryService.GetCombatStats(userId)
    local equipped = InventoryService.GetEquipped(userId)
    local stats = { attack = 0, coinBoost = 0 }

    for _, info in pairs(equipped) do
        local template = ItemDatabase.GetTemplate(info.templateId)
        if template and template.stats then
            if template.stats.attack then
                stats.attack = stats.attack + template.stats.attack
            end
            if template.stats.coinBoost then
                stats.coinBoost = stats.coinBoost + template.stats.coinBoost
            end
        end
    end

    return stats
end

return InventoryService
