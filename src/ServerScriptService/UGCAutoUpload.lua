--[[
    UGCAutoUpload.lua
    Studio MCP를 통한 Roblox UGC 자동 업로드
    (현재는 Placeholder - Studio MCP 연동 시 실제 구현)
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UGCAutoUpload = {}

-- 설정
UGCAutoUpload.Config = {
    -- 백엔드에서 생성된 FBX 다운로드 URL
    backendExportsUrl = "http://localhost:3001/exports/ugc/",
    -- Studio MCP Server URL (향후 연동 시)
    studioMcpUrl = "http://localhost:9877",
}

-- ─── FBX 파일 다운로드 및 Studio Import ────────────────────────────
--[[
    백엔드에서 생성된 FBX 파일을 가져와 Studio로 Import
    @param filename FBX 파일명 (예: "초록색_구_모자.fbx")
    @return 성공 여부
]]
function UGCAutoUpload.ImportFromBackend(filename)
    local fbxUrl = UGCAutoUpload.Config.backendExportsUrl .. filename

    -- 현재는 Placeholder
    -- Studio MCP 연동 시:
    -- 1. FBX 다운로드
    -- 2. 임시 파일로 저장
    -- 3. Studio MCP Import API 호출

    warn("[UGCAutoUpload] ImportFromBackend: " .. filename .. " (Studio MCP 연동 필요)")
    warn("[UGCAloUpload] FBX URL: " .. fbxUrl)

    -- TODO: Studio MCP 연동
    -- local success = UGCAutoUpload.CallStudioMCP("import_3d", {
    --     filePath = tempPath,
    --     fileType = "fbx"
    -- })

    return false -- Placeholder
end

-- ─── Accessory Fitting ────────────────────────────────────────────
--[[
    Accessory Fitting Tool 실행
    @param attachmentPoint 어태치먼트 포인트 (예: "HatAttachment")
    @return 성공 여부
]]
function UGCAutoUpload.FitAccessory(attachmentPoint)
    warn("[UGCAutoUpload] FitAccessory: " .. attachmentPoint .. " (Studio MCP 연동 필요)")

    -- TODO: Studio MCP 연동
    -- return UGCAutoUpload.CallStudioMCP("fit_accessory", {
    --     attachmentPoint = attachmentPoint,
    --     testAllAvatarTypes = true
    -- })

    return false
end

-- ─── MeshPart Accessory 생성 ───────────────────────────────────────
--[[
    MeshPart Accessory 생성
    @return 성공 여부
]]
function UGCAutoUpload.CreateMeshPartAccessory()
    warn("[UGCAutoUpload] CreateMeshPartAccessory (Studio MCP 연동 필요)")

    -- TODO: Studio MCP 연동
    -- return UGCAutoUpload.CallStudioMCP("create_accessory", {})

    return false
end

-- ─── Roblox에 UGC 업로드 ───────────────────────────────────────────
--[[
    Roblox 카탈로그에 UGC 업로드
    @param itemData 아이템 데이터
    @return 성공 시 Asset ID, 실패 시 nil
]]
function UGCAutoUpload.PublishToRoblox(itemData)
    warn("[UGCAutoUpload] PublishToRoblox: " .. itemData.name .. " (Studio MCP 연동 필요)")

    -- TODO: Studio MCP 연동
    -- return UGCAutoUpload.CallStudioMCP("publish_ugc", {
    --     name = itemData.name,
    --     description = itemData.description,
    --     price = itemData.price or 100,
    -- })

    return nil
end

-- ─── Studio MCP API 호출 헬퍼 ───────────────────────────────────────
--[[
    Studio MCP Server에 API 요청
    @param method API 메서드명
    @param params 요청 파라미터
    @return 응답 데이터 또는 nil
]]
function UGCAutoUpload.CallStudioMCP(method, params)
    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = UGCAutoUpload.Config.studioMcpUrl .. "/api/" .. method,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(params)
        })
    end)

    if success and response.StatusCode == 200 then
        return HttpService:JSONDecode(response.Body)
    end

    return nil
end

-- ─── 전체 업로드 파이프라인 ────────────────────────────────────────
--[[
    FBX 파일부터 Roblox 업로드까지 전체 과정 실행
    @param filename FBX 파일명
    @param spec 모델링 스펙
    @return Asset ID 또는 nil
]]
function UGCAutoUpload.FullUploadPipeline(filename, spec)
    print("[UGCAutoUpload] ========== 업로드 파이프라인 시작 ==========")
    print("[UGCAutoUpload] 파일:", filename)
    print("[UGCAutoUpload] 스펙:", spec.name)

    -- Step 1: Import
    print("[UGCAutoUpload] Step 1: FBX Import...")
    local importSuccess = UGCAutoUpload.ImportFromBackend(filename)
    if not importSuccess then
        warn("[UGCAutoUpload] Import 실패")
        return nil
    end

    -- Step 2: Fitting
    print("[UGCAutoUpload] Step 2: Accessory Fitting...")
    local fitSuccess = UGCAutoUpload.FitAccessory(spec.attachmentPoint)
    if not fitSuccess then
        warn("[UGCAutoUpload] Fitting 실패")
        return nil
    end

    -- Step 3: Create Accessory
    print("[UGCAutoUpload] Step 3: Create MeshPart Accessory...")
    local createSuccess = UGCAutoUpload.CreateMeshPartAccessory()
    if not createSuccess then
        warn("[UGCAutoUpload] Accessory 생성 실패")
        return nil
    end

    -- Step 4: Publish
    print("[UGCAutoUpload] Step 4: Publish to Roblox...")
    local assetId = UGCAutoUpload.PublishToRoblox({
        name = spec.name,
        description = spec.description,
        price = 100,
    })

    if assetId then
        print("[UGCAutoUpload] ========== 업로드 성공! Asset ID:", assetId, "==========")
    else
        warn("[UGCAutoUpload] ========== 업로드 실패 ==========")
    end

    return assetId
end

return UGCAutoUpload
