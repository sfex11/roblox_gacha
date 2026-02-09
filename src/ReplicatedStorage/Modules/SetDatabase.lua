--[[
    SetDatabase.lua
    세트/도감 정의
]]

local SetDatabase = {}

SetDatabase.Sets = {
    SET_BEGINNER = {
        setId = "SET_BEGINNER",
        displayName = "초보 모험가 세트",
        description = "모험의 첫 발을 내딛는 당신을 위한 세트.",
        requiredItems = {
            "WPN_SWORD_01",
            "PET_CAT_01",
            "CST_HOOD_01",
        },
        rewards = {
            title = "첫 걸음",
            coins = 500,
        },
    },
}

function SetDatabase.GetSet(setId)
    return SetDatabase.Sets[setId]
end

function SetDatabase.GetAllSets()
    return SetDatabase.Sets
end

-- 특정 아이템이 속한 세트 목록 반환
function SetDatabase.GetSetsForItem(templateId)
    local result = {}
    for setId, setData in pairs(SetDatabase.Sets) do
        for _, itemId in ipairs(setData.requiredItems) do
            if itemId == templateId then
                table.insert(result, setId)
                break
            end
        end
    end
    return result
end

return SetDatabase
