--[[
    UGCEquipService.lua
    UGC 액세서리 착용/해제 관리
    - 캐릭터에 실제 액세서리 부착
    - UGC 타입별 Attachment 처리
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local InsertService = game:GetService("InsertService")

local Constants = require(ReplicatedStorage.Modules.Constants)
local UGCDatabase = require(ReplicatedStorage.Modules.UGCDatabase)
local UGCProceduralBuilder = require(script.Parent.UGCProceduralBuilder)

local UGCEquipService = {}

-- UGC 타입별 Attachment 매핑
local ATTACHMENT_MAP = {
    [Constants.UGCType.Hat] = "HatAttachment",
    [Constants.UGCType.Hair] = "HairAttachment",
    [Constants.UGCType.Face] = "FaceFrontAttachment",
    [Constants.UGCType.Back] = "BodyBackAttachment",
    [Constants.UGCType.Front] = "BodyFrontAttachment",
    [Constants.UGCType.Shoulder] = "LeftShoulderAttachment",
    [Constants.UGCType.Waist] = "WaistCenterAttachment",
}

-- HumanoidDescription 액세서리 슬롯 매핑
local DESCRIPTION_ACCESSORY_FIELDS = {
    [Constants.UGCType.Hat] = "HatAccessory",
    [Constants.UGCType.Hair] = "HairAccessory",
    [Constants.UGCType.Face] = "FaceAccessory",
    [Constants.UGCType.Back] = "BackAccessory",
    [Constants.UGCType.Front] = "FrontAccessory",
    [Constants.UGCType.Shoulder] = "ShouldersAccessory",
    [Constants.UGCType.Waist] = "WaistAccessory",
}

-- 희귀도별 색상
local RARITY_COLORS = {
    [Constants.Rarity.Common] = Color3.fromRGB(180, 180, 180),
    [Constants.Rarity.Rare] = Color3.fromRGB(70, 130, 255),
    [Constants.Rarity.Epic] = Color3.fromRGB(170, 70, 255),
    [Constants.Rarity.Legendary] = Color3.fromRGB(255, 200, 50),
    [Constants.Rarity.Mythic] = Color3.fromRGB(255, 80, 120),
}

-- 플레이어별 장착된 UGC 추적
UGCEquipService._equippedUGC = {}
UGCEquipService._warnedMissingSource = {}

local function normalizeAssetId(assetId)
    if type(assetId) == "number" then
        return assetId
    end

    if type(assetId) ~= "string" then
        return nil
    end

    local digits = assetId:match("%d+")
    if not digits then
        return nil
    end

    return tonumber(digits)
end

local function getUGCAssetsFolder()
    return ServerStorage:FindFirstChild("UGCAssets") or ReplicatedStorage:FindFirstChild("UGCAssets")
end

local function findLinkedAccessory(templateId)
    local folder = getUGCAssetsFolder()
    if not folder then
        return nil
    end

    local direct = folder:FindFirstChild(templateId)
    if direct and direct:IsA("Accessory") then
        return direct
    end

    for _, descendant in ipairs(folder:GetDescendants()) do
        if descendant:IsA("Accessory") then
            local linkedTemplateId = descendant:GetAttribute("UGC_TemplateId")
            if linkedTemplateId == templateId or descendant.Name == templateId then
                return descendant
            end
        end
    end

    return nil
end

local function findFirstAccessory(container)
    if not container then
        return nil
    end

    if container:IsA("Accessory") then
        return container
    end

    for _, descendant in ipairs(container:GetDescendants()) do
        if descendant:IsA("Accessory") then
            return descendant
        end
    end

    return nil
end

local function stripScripts(root)
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("Script") or descendant:IsA("LocalScript") then
            descendant:Destroy()
        end
    end
end

local function equipViaHumanoidDescription(humanoid, ugcType, assetId)
    local field = DESCRIPTION_ACCESSORY_FIELDS[ugcType]
    if not field then
        return false, "unsupported_ugc_type"
    end

    local description = humanoid:GetAppliedDescription()
    local previousValue = description[field]
    description[field] = tostring(assetId)

    local ok, err = pcall(function()
        humanoid:ApplyDescription(description)
    end)
    if not ok then
        return false, err
    end

    return true, {
        mode = "description",
        field = field,
        previousValue = previousValue,
        assetId = assetId,
    }
end

local function equipViaInsertService(humanoid, character, assetId)
    local ok, assetModelOrErr = pcall(function()
        return InsertService:LoadAsset(assetId)
    end)
    if not ok then
        return false, assetModelOrErr
    end

    local assetModel = assetModelOrErr
    local accessory = findFirstAccessory(assetModel)
    if not accessory then
        assetModel:Destroy()
        return false, "no_accessory_in_asset"
    end

    stripScripts(accessory)
    accessory.Parent = character
    local ok2, err2 = pcall(function()
        humanoid:AddAccessory(accessory)
    end)
    if not ok2 then
        accessory:Destroy()
        assetModel:Destroy()
        return false, err2
    end

    assetModel:Destroy()

    return true, {
        mode = "accessory",
        accessory = accessory,
        assetId = assetId,
    }
end

--[[
    UGC 액세서리 생성
    @param templateId string - UGC 템플릿 ID
    @param character Model - 플레이어 캐릭터
    @return Accessory|nil
]]
function UGCEquipService.CreateAccessory(templateId, character)
    local ugcItem = UGCDatabase.GetItem(templateId)
    if not ugcItem then
        warn("[UGCEquipService] UGC 아이템을 찾을 수 없음:", templateId)
        return nil
    end

    local ugcType = ugcItem.ugcType or Constants.UGCType.Hat
    local attachmentName = ATTACHMENT_MAP[ugcType] or "HatAttachment"
    local rarityColor = RARITY_COLORS[ugcItem.rarity] or Color3.fromRGB(128, 128, 128)

    local ok, accessoryOrErr = pcall(function()
        return UGCProceduralBuilder.BuildAccessory(templateId, ugcItem, attachmentName, rarityColor)
    end)

    if ok and accessoryOrErr then
        return accessoryOrErr, attachmentName
    end

    warn(string.format("[UGCEquipService] Procedural UGC 생성 실패, 폴백 사용: %s", tostring(accessoryOrErr)))

    -- 폴백: 단순 구형
    local accessory = Instance.new("Accessory")
    accessory.Name = ugcItem.name

    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.6, 0.6, 0.6)
    handle.Color = rarityColor
    handle.Material = Enum.Material.SmoothPlastic
    handle.CanCollide = false
    handle.CanQuery = false
    handle.CanTouch = false
    handle.Anchored = false
    handle.Massless = true
    handle.Parent = accessory

    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Scale = Vector3.new(0.9, 0.9, 0.9)
    mesh.Parent = handle

    local attachment = Instance.new("Attachment")
    attachment.Name = attachmentName
    attachment.Parent = handle

    accessory:SetAttribute("UGC_TemplateId", templateId)
    accessory:SetAttribute("UGC_Type", ugcType)
    accessory:SetAttribute("UGC_Rarity", ugcItem.rarity)

    return accessory, attachmentName
end

--[[
    UGC 착용
    @param player Player
    @param templateId string
    @return boolean
]]
function UGCEquipService.Equip(player, templateId)
    local character = player.Character
    if not character then
        warn("[UGCEquipService] 캐릭터 없음")
        return false
    end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then
        warn("[UGCEquipService] Humanoid 없음")
        return false
    end

    -- 이미 장착된 UGC가 있으면 해제
    UGCEquipService.Unequip(player)

    local ugcItem = UGCDatabase.GetItem(templateId)
    if not ugcItem then
        warn("[UGCEquipService] UGC 아이템을 찾을 수 없음:", templateId)
        return false
    end

    local ugcType = ugcItem.ugcType or Constants.UGCType.Hat

    -- 1) ReplicatedStorage/UGCAssets에 링크된 Accessory가 있으면 우선 사용
    local linked = findLinkedAccessory(templateId)
    if linked then
        local accessory = linked:Clone()
        stripScripts(accessory)
        accessory.Parent = character
        local ok, err = pcall(function()
            humanoid:AddAccessory(accessory)
        end)
        if not ok then
            accessory:Destroy()
            warn(string.format("[UGCEquipService] 링크된 액세서리 장착 실패: %s", tostring(err)))
            return false
        end

        UGCEquipService._equippedUGC[player.UserId] = {
            templateId = templateId,
            mode = "accessory",
            accessory = accessory,
            source = "linked",
        }

        print(string.format("[UGCEquipService] UGC 착용(링크): %s (%s)", ugcItem.name, ugcItem.rarity))
        return true
    end

    -- 2) assetId가 있으면 InsertService 또는 HumanoidDescription으로 장착 시도
    local assetId = normalizeAssetId(ugcItem.assetId)
    if assetId then
        local ok, metaOrErr = equipViaInsertService(humanoid, character, assetId)
        if ok then
            UGCEquipService._equippedUGC[player.UserId] = {
                templateId = templateId,
                mode = metaOrErr.mode,
                accessory = metaOrErr.accessory,
                assetId = assetId,
                source = "insert",
            }

            print(string.format("[UGCEquipService] UGC 착용(InsertService): %s (%s) assetId=%d", ugcItem.name, ugcItem.rarity, assetId))
            return true
        end

        warn(string.format("[UGCEquipService] InsertService 장착 실패 (assetId=%s): %s", tostring(assetId), tostring(metaOrErr)))

        local ok2, metaOrErr2 = equipViaHumanoidDescription(humanoid, ugcType, assetId)
        if ok2 then
            UGCEquipService._equippedUGC[player.UserId] = {
                templateId = templateId,
                mode = metaOrErr2.mode,
                field = metaOrErr2.field,
                previousValue = metaOrErr2.previousValue,
                assetId = assetId,
                source = "description",
            }

            print(string.format("[UGCEquipService] UGC 착용(HumanoidDescription): %s (%s) assetId=%d field=%s", ugcItem.name, ugcItem.rarity, assetId, metaOrErr2.field))
            return true
        end

        warn(string.format("[UGCEquipService] HumanoidDescription 장착 실패 (assetId=%s): %s", tostring(assetId), tostring(metaOrErr2)))
    elseif ugcItem.assetId ~= nil and not UGCEquipService._warnedMissingSource[templateId] then
        UGCEquipService._warnedMissingSource[templateId] = true
        warn(string.format("[UGCEquipService] assetId 형식이 올바르지 않습니다: templateId=%s assetId=%s", tostring(templateId), tostring(ugcItem.assetId)))
    end

    -- 3) 최종 폴백: 기본 구체 액세서리 생성
    if not ugcItem.assetId and not UGCEquipService._warnedMissingSource[templateId] then
        UGCEquipService._warnedMissingSource[templateId] = true
        warn(string.format("[UGCEquipService] 링크된 Accessory/assetId가 없습니다. Studio에서 UGCTools.LinkSelectedAccessory(\"%s\")로 UGCAssets에 등록하세요.", tostring(templateId)))
    end

    local accessory = UGCEquipService.CreateAccessory(templateId, character)
    if not accessory then
        return false
    end

    accessory.Parent = character
    local ok3, err3 = pcall(function()
        humanoid:AddAccessory(accessory)
    end)
    if not ok3 then
        accessory:Destroy()
        warn(string.format("[UGCEquipService] 폴백 액세서리 장착 실패: %s", tostring(err3)))
        return false
    end

    UGCEquipService._equippedUGC[player.UserId] = {
        templateId = templateId,
        mode = "accessory",
        accessory = accessory,
        source = "fallback",
    }

    print(string.format("[UGCEquipService] UGC 착용(폴백): %s (%s)", ugcItem.name, ugcItem.rarity))

    return true
end

--[[
    UGC 해제
    @param player Player
    @return boolean
]]
function UGCEquipService.Unequip(player)
    local equipped = UGCEquipService._equippedUGC[player.UserId]
    if not equipped then
        return true
    end

    if equipped.mode == "description" then
        local character = player.Character
        local humanoid = character and character:FindFirstChild("Humanoid")
        if humanoid and equipped.field then
            local description = humanoid:GetAppliedDescription()
            description[equipped.field] = equipped.previousValue or ""
            pcall(function()
                humanoid:ApplyDescription(description)
            end)
        end
    else
        local accessory = equipped.accessory
        if accessory and accessory.Parent then
            accessory:Destroy()
        end
    end

    UGCEquipService._equippedUGC[player.UserId] = nil

    print("[UGCEquipService] UGC 해제")
    return true
end

--[[
    현재 장착된 UGC 조회
    @param userId number
    @return table|nil
]]
function UGCEquipService.GetEquipped(userId)
    return UGCEquipService._equippedUGC[userId]
end

--[[
    플레이어 리스폰 시 UGC 재장착
    @param player Player
    @param templateId string?
]]
function UGCEquipService.OnCharacterRespawn(player, templateId)
    -- 데이터에서 장착된 UGC 조회
    if not templateId then
        local DataManager = require(script.Parent.DataManager)
        local data = DataManager.GetData(player.UserId)
        if data and data.equipped and data.equipped[Constants.Category.UGC] then
            local slotIndex = data.equipped[Constants.Category.UGC]
            local item = data.inventory[slotIndex]
            if item then
                templateId = item.templateId
            end
        end
    end

    if templateId then
        task.wait(0.5) -- 캐릭터 로딩 대기
        UGCEquipService.Equip(player, templateId)
    end
end

-- 플레이어 퇴장 시 정리
Players.PlayerRemoving:Connect(function(player)
    UGCEquipService._equippedUGC[player.UserId] = nil
end)

return UGCEquipService
