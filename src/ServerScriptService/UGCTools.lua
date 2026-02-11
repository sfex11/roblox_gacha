--[[
    UGCTools.lua
    Roblox Studio에서 UGC 아이템을 자동으로 설정하는 도구 모음

    사용법:
    1. 백엔드 API로 FBX 생성
    2. Studio에서 Import 3D로 FBX Import
    3. Import된 모델 선택
    4. UGCTools.SetupImportedModel(spec) 실행
]]

local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local UGCTools = {}

-- ─── 상수 ─────────────────────────────────────────────────────────────
UGCTools.RARITY_COLORS = {
    Common = Color3.fromRGB(178, 178, 178),      -- 회색
    Rare = Color3.fromRGB(74, 144, 217),         -- 파란색
    Epic = Color3.fromRGB(163, 53, 238),         -- 보라색
    Legendary = Color3.fromRGB(255, 215, 0),     -- 금색
}

UGCTools.CATEGORY_ATTACHMENTS = {
    Hat = "HatAttachment",
    Hair = "HairAttachment",
    Back = "BodyBackAttachment",
    Front = "BodyFrontAttachment",
    Shoulder = "LeftShoulderAttachment",
    Waist = "WaistCenterAttachment",
    Face = "FaceFrontAttachment",
}

-- ─── 메인 함수: Import된 모델 설정 ────────────────────────────────────
--[[
    Import된 모델을 자동으로 설정
    @param model Import된 모델 (Model 또는 MeshPart)
    @param spec 아이템 스펙
    @return 설정된 itemData
]]
function UGCTools.SetupImportedModel(model, spec)
    spec = spec or {}

    local category = spec.category or "Hat"

    local itemData = {
        name = spec.name or "Unknown Item",
        description = spec.description or "",
        rarity = spec.rarity or "Common",
        category = category,
        attachmentPoint = spec.attachmentPoint or UGCTools.CATEGORY_ATTACHMENTS[category] or UGCTools.CATEGORY_ATTACHMENTS.Hat,
    }

    print(" ")
    print("═══════════════════════════════════════════════════════")
    print("🎨 UGC 아이템 자동 설정")
    print("═══════════════════════════════════════════════════════")

    -- 모델 이름 변경
    if model:IsA("Model") then
        model.Name = itemData.name
    elseif model:IsA("BasePart") then
        model.Name = itemData.name .. "_Mesh"
    end

    print("이름:", itemData.name)

    -- 메타데이터 설정 (Attributes)
    UGCTools.SetMetadata(model, itemData)

    -- 색상 적용
    if spec.style and spec.style.primaryColor then
        local color = UGCTools.HexToColor3(spec.style.primaryColor)
        UGCTools.ApplyColorToMesh(model, color)
        print("색상:", spec.style.primaryColor)
    end

    print("═══════════════════════════════════════════════════════")
    print(" ")

    -- 변경 사항 기록
    ChangeHistoryService:SetWaypoint("UGC Setup: " .. itemData.name)

    return itemData
end

-- ─── 메타데이터 설정 ─────────────────────────────────────────────────
--[[
    모델에 UGC 메타데이터를 Attributes로 설정
    @param object 모델 또는 파트
    @param itemData 아이템 데이터
]]
function UGCTools.SetMetadata(object, itemData)
    object:SetAttribute("UGC_Name", itemData.name)
    object:SetAttribute("UGC_Description", itemData.description)
    object:SetAttribute("UGC_Rarity", itemData.rarity)
    object:SetAttribute("UGC_Category", itemData.category)
    object:SetAttribute("UGC_AttachmentPoint", itemData.attachmentPoint)
    object:SetAttribute("UGC_CreatedAt", os.time())

    print("✅ 메타데이터 설정 완료")
end

-- ─── 색상 적용 ───────────────────────────────────────────────────────
--[[
    모델의 모든 MeshPart/Part에 색상 적용
    @param object 루트 객체
    @param color Color3 값
]]
function UGCTools.ApplyColorToMesh(object, color)
    if object:IsA("MeshPart") or object:IsA("Part") then
        -- 흰색 또는 기본 색상인 경우만 변경
        if object.Color == Color3.new(1, 1, 1) then
            object.Color = color
            object.Material = Enum.Material.SmoothPlastic
        end
    end

    for _, child in ipairs(object:GetChildren()) do
        UGCTools.ApplyColorToMesh(child, color)
    end
end

-- ─── HEX to Color3 변환 ─────────────────────────────────────────────
--[[
    HEX 색상 코드를 Color3로 변환
    @param hex "#RRGGBB" 형식의 문자열
    @return Color3 값
]]
function UGCTools.HexToColor3(hex)
    if type(hex) ~= "string" then
        return Color3.new(1, 1, 1)
    end

    hex = hex:gsub("#", "")

    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255

    return Color3.new(r, g, b)
end

-- ─── Accessory 생성 가이드 ───────────────────────────────────────────
--[[
    Accessory Fitting Tool 사용 가이드 출력
    @param itemData 아이템 데이터
]]
function UGCTools.PrintAccessoryGuide(itemData)
    print(" ")
    print("═══════════════════════════════════════════════════════")
    print("📋 Accessory 생성 가이드")
    print("═══════════════════════════════════════════════════════")
    print("1. Plugin 탭 → Accessory Fitting Tool 실행")
    print("2. Attachment Point:", itemData.attachmentPoint)
    print("3. 'Create' 클릭")
    print("4. 생성된 Accessory 확인")
    print("═══════════════════════════════════════════════════════")
    print(" ")
end

-- ─── 선택한 모델 설정 (Studio Command Bar용) ─────────────────────────
--[[
    현재 선택된 모델을 자동 설정
    Studio Command Bar에서 실행 가능

    예시:
    local UGCTools = require(game.ServerScriptService.UGCTools)
    UGCTools.SetupSelected({
        name = "내 모자",
        description = "귀여운 모자",
        rarity = "Rare",
        category = "Hat"
    })
]]
function UGCTools.SetupSelected(spec)
    local selection = game.Selection:Get()

    if #selection == 0 then
        warn("⚠️ 모델을 선택한 후 실행하세요")
        return nil
    end

    local model = selection[1]
    return UGCTools.SetupImportedModel(model, spec)
end

-- ─── 백엔드 API에서 스펙 가져오기 ───────────────────────────────────
--[[
    백엔드 API에서 생성된 스펙을 가져와서 모델 설정
    @param filename FBX 파일명
]]
function UGCTools.SetupFromBackend(filename)
    -- TODO: 백엔드 API에서 스펙 가져오기
    -- 현재는 수동으로 스펙을 입력해야 함

    warn("⚠️ 아직 백엔드 API 연동이 필요합니다")
    warn("현재는 SetupSelected()를 사용하여 수동으로 설정하세요")
end

-- ─── UGC 액세서리 링크 (런타임 장착용) ───────────────────────────────
--[[
    Accessory를 templateId에 연결해서 ServerStorage/ReplicatedStorage에 보관
    - UGCEquipService는 UGCAssets 폴더에서 templateId 매칭 Accessory를 우선 사용합니다.

    사용 예시 (Command Bar):
    local UGCTools = require(game.ServerScriptService.UGCTools)
    UGCTools.LinkSelectedAccessory("UGC_HAT_0001", { destination = "ServerStorage" })
]]
local function stripScripts(root)
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("Script") or descendant:IsA("LocalScript") then
            descendant:Destroy()
        end
    end
end

function UGCTools.LinkAccessory(accessory, templateId, options)
    options = options or {}

    if type(templateId) ~= "string" or templateId == "" then
        warn("⚠️ templateId가 필요합니다 (예: UGC_HAT_0001)")
        return nil
    end

    if not accessory or not accessory:IsA("Accessory") then
        warn("⚠️ Accessory 인스턴스가 필요합니다")
        return nil
    end

    local destination = options.destination or "ServerStorage" -- "ServerStorage" | "ReplicatedStorage"
    local parentService = destination == "ReplicatedStorage" and ReplicatedStorage or ServerStorage

    local folder = parentService:FindFirstChild("UGCAssets")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "UGCAssets"
        folder.Parent = parentService
    end

    local existing = folder:FindFirstChild(templateId)
    if existing then
        existing:Destroy()
    end

    local linked = accessory:Clone()
    linked.Name = templateId
    linked:SetAttribute("UGC_TemplateId", templateId)
    stripScripts(linked)
    linked.Parent = folder

    ChangeHistoryService:SetWaypoint("UGC Link: " .. templateId)
    print(string.format("✅ UGC 링크 완료: %s → %s.UGCAssets", templateId, parentService.Name))

    return linked
end

function UGCTools.LinkSelectedAccessory(templateId, options)
    options = options or {}

    if type(templateId) ~= "string" or templateId == "" then
        warn("⚠️ templateId가 필요합니다 (예: UGC_HAT_0001)")
        return nil
    end

    local selection = game.Selection:Get()
    if #selection == 0 then
        warn("⚠️ Accessory를 선택한 후 실행하세요")
        return nil
    end

    local selected = selection[1]
    local accessory = selected:IsA("Accessory") and selected or selected:FindFirstChildWhichIsA("Accessory", true)
    if not accessory then
        warn("⚠️ 선택한 오브젝트에서 Accessory를 찾을 수 없습니다")
        return nil
    end

    return UGCTools.LinkAccessory(accessory, templateId, options)
end

function UGCTools.LinkAccessoryByName(templateId, accessoryName, options)
    options = options or {}

    if type(accessoryName) ~= "string" or accessoryName == "" then
        warn("⚠️ accessoryName이 필요합니다")
        return nil
    end

    local matches = {}
    for _, inst in ipairs(game:GetDescendants()) do
        if inst:IsA("Accessory") and inst.Name == accessoryName then
            table.insert(matches, inst)
        end
    end

    if #matches == 0 then
        warn("⚠️ Accessory를 찾을 수 없습니다:", accessoryName)
        return nil
    end

    if #matches > 1 then
        warn(string.format("⚠️ 같은 이름의 Accessory가 %d개 있습니다. 첫 번째를 사용합니다: %s", #matches, accessoryName))
    end

    return UGCTools.LinkAccessory(matches[1], templateId, options)
end

return UGCTools
