--[[
    UGCPipeline.lua
    전체 UGC 자동화 파이프라인
    텍스트 프롬프트 → GLM-4.7 → Blender → Roblox UGC → 가차 풀 등록
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

-- 모듈 참조
local UGCAutoUpload = require(script.Parent.UGCAutoUpload)
local UGCDatabase = require(game.ReplicatedStorage.Modules.UGCDatabase)
local GachaConfig = require(game.ReplicatedStorage.Modules.GachaConfig)

local UGCPipeline = {}

-- 설정
UGCPipeline.Config = {
    -- 백엔드 API
    backendUrl = "http://localhost:3001",
    apiSecret = "dev-secret",

    -- 타임아웃 (LLM + Blender 총 소요 시간 고려)
    requestTimeout = 300, -- 5분
}

local function makeVisualSpec(spec, prompt, options)
    options = options or {}
    spec = spec or {}

    -- 절차적 생성에 필요한 최소 필드만 보관 (blenderInstructions 등은 제외)
    return {
        prompt = prompt,
        theme = options.theme,
        name = spec.name,
        category = spec.category,
        rarity = spec.rarity,
        attachmentPoint = spec.attachmentPoint,
        shape = spec.shape,
        style = spec.style,
        motifs = spec.motifs,
        vfx = spec.vfx,
        seed = spec.seed,
    }
end

-- ─── Phase 1: 모델링 가이드 생성 (GLM-4.7) ───────────────────────────
--[[
    GLM-4.7로 모델링 스펙 생성
    @param prompt 사용자 프롬프트
    @param options 옵션 (rarity, category, theme 등)
    @return 스펙 또는 nil
]]
function UGCPipeline.GenerateModelingSpec(prompt, options)
    options = options or {}

    print("[UGCPipeline] Phase 1: 모델링 가이드 생성...")
    print("[UGCPipeline] 프롬프트:", prompt)

    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = UGCPipeline.Config.backendUrl .. "/api/modeling/guide",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["X-Api-Secret"] = UGCPipeline.Config.apiSecret,
            },
            Body = HttpService:JSONEncode({
                prompt = prompt,
                rarity = options.rarity or "Rare",
                category = options.category or "Hat",
                theme = options.theme or "default",
                attachmentPoint = options.attachmentPoint,
            }),
        })
    end)

    if success and response.StatusCode == 200 then
        local data = HttpService:JSONDecode(response.Body)
        if data.success then
            print("[UGCPipeline] ✓ 스펙 생성 성공:", data.data.name)
            return data.data
        end
    end

    warn("[UGCPipeline] ✗ 스펙 생성 실패")
    return nil
end

-- ─── Spec-only: Procedural UGC 생성 (FBX 없이 즉시 착용 가능) ─────────
--[[
    백엔드에서 스펙만 생성하고, 게임 내에서 절차적으로 액세서리를 생성/장착합니다.
    - Blender/FBX Import 없이도 "게임 플레이용" UGC를 즉시 만들 수 있습니다.
]]
function UGCPipeline.GenerateProceduralUGC(prompt, options)
    options = options or {}

    local spec = UGCPipeline.GenerateModelingSpec(prompt, options)
    if not spec then
        return nil
    end

    local templateId = UGCDatabase.RegisterItem({
        name = spec.name or prompt,
        description = spec.description,
        flavorText = spec.flavorText or "AI가 생성한 아이템",
        rarity = spec.rarity or options.rarity or "Rare",
        ugcType = spec.category or options.category or "Hat",
        stats = spec.stats or {},
        weight = spec.weight or 100,
        visualSpec = makeVisualSpec(spec, prompt, options),
    })

    if templateId then
        GachaConfig.RefreshPool("standard_v1")
        print("[UGCPipeline] ✓ Procedural UGC 등록 완료:", templateId)
    end

    return {
        templateId = templateId,
        spec = spec,
    }
end

-- ─── Phase 2: Blender 모델링 (FBX 생성) ───────────────────────────────
--[[
    Blender로 FBX 파일 생성
    @param prompt 사용자 프롬프트
    @param spec 모델링 스펙 (nil이면 프롬프트로 자동 생성)
    @return {spec, fbxPath, filename, downloadUrl} 또는 nil
]]
function UGCPipeline.GenerateModel(prompt, spec)
    print("[UGCPipeline] Phase 2: Blender 모델링...")

    -- 스펙이 없으면 생성
    if not spec then
        spec = UGCPipeline.GenerateModelingSpec(prompt)
        if not spec then
            return nil
        end
    end

    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = UGCPipeline.Config.backendUrl .. "/api/modeling/generate",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["X-Api-Secret"] = UGCPipeline.Config.apiSecret,
            },
            Body = HttpService:JSONEncode({
                prompt = prompt,
                rarity = spec.rarity,
                category = spec.category,
                theme = spec.theme or "default",
                attachmentPoint = spec.attachmentPoint,
            }),
        })
    end)

    if success and response.StatusCode == 200 then
        local data = HttpService:JSONDecode(response.Body)
        if data.success then
            print("[UGCPipeline] ✓ FBX 생성 성공:", data.filename)
            return {
                spec = data.spec,
                fbxPath = data.fbxPath,
                filename = data.filename,
                downloadUrl = data.downloadUrl,
                studioLuaScript = data.studioLuaScript,
                importInstructions = data.importInstructions,
            }
        end
    end

    warn("[UGCPipeline] ✗ FBX 생성 실패")
    return nil
end

-- ─── Phase 3: Studio Import 가이드 제공 ───────────────────────────────
--[[
    FBX 파일 Import 가이드 출력 (Roblox API 제약으로 수동 작업 필요)
    @param result Phase 2 결과
    @return importGuide (가이드 정보)
]]
function UGCPipeline.GetImportGuide(result)
    print("[UGCPipeline] Phase 3: Studio Import 가이드 제공...")

    local importGuide = {
        filename = result.filename,
        fbxPath = result.fbxPath,
        downloadUrl = result.downloadUrl,
        steps = {
            "[1] Roblox Studio 열기",
            "[2] Avatar 탭 → Import 3D 클릭",
            "[3] 파일 선택: " .. result.filename,
            "[4] Import 후 Accessory Fitting Tool 실행",
            "[5] 생성된 Lua 스크립트로 메타데이터 설정",
        },
        luaScript = result.studioLuaScript or "-- 스크립트가 제공되지 않았습니다",
    }

    print("[UGCPipeline] ===== Import 가이드 =====")
    for i, step in ipairs(importGuide.steps) do
        print("[UGCPipeline] " .. step)
    end
    print("[UGCPipeline] FBX 파일: " .. importGuide.fbxPath)
    print("[UGCPipeline] ==========================")

    return importGuide
end

-- ─── 전체 파이프라인 실행 ─────────────────────────────────────────────
--[[
    텍스트 프롬프트 하나로 FBX 생성 및 Import 가이드 제공
    @param prompt 사용자 프롬프트
    @param options 옵션
    @return {spec, fbxPath, filename, importGuide, templateId} 또는 nil
]]
function UGCPipeline.FullAutoGenerate(prompt, options)
    options = options or {}

    print(" ")
    print("[UGCPipeline] ══════════════════════════════════════════════")
    print("[UGCPipeline] 🚀 UGC 자동화 파이프라인 시작")
    print("[UGCPipeline] 프롬프트:", prompt)
    print("[UGCPipeline] ══════════════════════════════════════════════")
    print(" ")

    local startTime = os.time()

    -- Phase 1 & 2: 모델 생성 (백엔드에서 한 번에 처리)
    local result = UGCPipeline.GenerateModel(prompt, nil)
    if not result then
        warn("[UGCPipeline] 모델 생성 실패로 파이프라인 중단")
        return nil
    end

    -- Phase 3: Import 가이드 제공 (수동 작업 필요)
    local importGuide = UGCPipeline.GetImportGuide(result)

    -- Phase 4: UGCDatabase에 등록 + 가차 풀 갱신
    local templateId = UGCPipeline.RegisterToDatabase(result, options, prompt)

    if templateId and importGuide then
        table.insert(importGuide.steps,
            "[6] Accessory 생성 후 Accessory를 선택 → UGCTools.LinkSelectedAccessory(\"" .. templateId .. "\", { destination = \"ServerStorage\" }) 실행")
        table.insert(importGuide.steps, "[7] 게임 실행 후 인벤토리에서 해당 UGC 장착 테스트")
    end

    local elapsed = os.time() - startTime

    print(" ")
    print("[UGCPipeline] ══════════════════════════════════════════════")
    print("[UGCPipeline] ⏱️ 총 소요 시간:", elapsed, "초")
    print("[UGCPipeline] ✅ FBX 파일 생성 완료!")
    if templateId then
        print("[UGCPipeline] 📦 가차 풀 등록 완료:", templateId)
    end
    print("[UGCPipeline] 📋 위 가이드를 따라 Studio에 Import하세요")
    print("[UGCPipeline] ══════════════════════════════════════════════")
    print(" ")

    return {
        spec = result.spec,
        fbxPath = result.fbxPath,
        filename = result.filename,
        downloadUrl = result.downloadUrl,
        importGuide = importGuide,
        elapsedSeconds = elapsed,
        templateId = templateId,
    }
end

-- ─── UGCDatabase 등록 ─────────────────────────────────────────────────
--[[
    생성된 UGC를 UGCDatabase에 등록하고 가차 풀 갱신
    @param result GenerateModel 결과
    @param options 옵션
    @return templateId 또는 nil
]]
-- prompt는 선택 (spec-only/procedural에서도 동일 구조로 저장하기 위해 포함)
function UGCPipeline.RegisterToDatabase(result, options, prompt)
    options = options or {}

    if not result or not result.spec then
        warn("[UGCPipeline] 등록할 스펙이 없음")
        return nil
    end

    local spec = result.spec

    local templateId = UGCDatabase.RegisterItem({
        name = spec.name,
        description = spec.description,
        flavorText = spec.flavorText or "AI가 생성한 아이템",
        rarity = spec.rarity or "Rare",
        ugcType = spec.category or "Hat",
        fbxPath = result.fbxPath,
        visualSpec = makeVisualSpec(spec, prompt, options),
        stats = spec.stats or {},
        weight = spec.weight or 100,
    })

    if templateId then
        GachaConfig.RefreshPool("standard_v1")
        print("[UGCPipeline] ✓ 가차 풀 갱신 완료")
    end

    return templateId
end

-- ─── 관리자 명령어 핸들러 ───────────────────────────────────────────
--[[
    게임 내 관리자 명령어 처리
    !ugc_make <프롬프트> 형식
    !ugc_list - 등록된 UGC 아이템 목록
    !ugc_refresh - 가차 풀 갱신
]]
function UGCPipeline.SetupAdminCommands()
    -- 개발자 UserId (실제 개발자 UserId로 교체 필요)
    local ADMIN_USER_IDS = {
        12345678, -- 예시 UserId
        -- 추가 관리자 UserId
    }

    local function isAdmin(player)
        return RunService:IsStudio() or (table.find(ADMIN_USER_IDS, player.UserId) ~= nil)
    end

    local function handleCommand(player, message)
        if type(message) ~= "string" then
            return
        end

        if not isAdmin(player) then
            return
        end

        if message == "" then
            return
        end

            -- !ugc_gen [<category>] [<rarity>] <프롬프트>
            local genPrefix = "!ugc_gen "
            if message:sub(1, genPrefix:len()) == genPrefix then
                local raw = message:sub(genPrefix:len() + 1)
                local tokens = {}
                for t in string.gmatch(raw, "%S+") do
                    table.insert(tokens, t)
                end

                local category = "Hat"
                local rarity = "Rare"
                local startIndex = 1

                local validCategory = {
                    Hat = true,
                    Hair = true,
                    Face = true,
                    Back = true,
                    Front = true,
                    Shoulder = true,
                    Waist = true,
                }

                local validRarity = {
                    Common = true,
                    Rare = true,
                    Epic = true,
                    Legendary = true,
                    Mythic = true,
                }

                if tokens[startIndex] and validCategory[tokens[startIndex]] then
                    category = tokens[startIndex]
                    startIndex += 1
                end

                if tokens[startIndex] and validRarity[tokens[startIndex]] then
                    rarity = tokens[startIndex]
                    startIndex += 1
                end

                local prompt = table.concat(tokens, " ", startIndex)
                if prompt ~= "" then
                    task.spawn(function()
                        local result = UGCPipeline.GenerateProceduralUGC(prompt, {
                            rarity = rarity,
                            category = category,
                            theme = "default",
                        })

                        if not result or not result.templateId then
                            warn("[UGCPipeline] Procedural UGC 생성 실패")
                            return
                        end

                        local templateId = result.templateId

                        -- 즉시 지급 + 장착(테스트용)
                        local DataManager = require(script.Parent.DataManager)
                        local InventoryService = require(script.Parent.InventoryService)
                        local UGCEquipService = require(script.Parent.UGCEquipService)

                        local data = DataManager.GetData(player.UserId)
                        if not data then
                            warn("[UGCPipeline] 데이터 없음")
                            return
                        end

                        local okAdd, addOrErr = InventoryService.AddItem(player.UserId, templateId)
                        if okAdd then
                            InventoryService.Equip(player.UserId, addOrErr.slotIndex)
                        else
                            warn(string.format("[UGCPipeline] 인벤토리 지급 실패(무시하고 장착 시도): %s", tostring(addOrErr)))
                        end

                        local okEquip = UGCEquipService.Equip(player, templateId)
                        print(string.format("[UGCPipeline] Procedural UGC 생성/장착 %s: %s (%s/%s)",
                            okEquip and "성공" or "실패",
                            templateId,
                            rarity,
                            category))
                    end)
                end
            end

            -- !ugc_make <프롬프트>
            local prefix = "!ugc_make "
            if message:sub(1, prefix:len()) == prefix then
                local prompt = message:sub(prefix:len() + 1)

                if prompt ~= "" then
                    -- 비동기 실행
                    task.spawn(function()
                        local result = UGCPipeline.FullAutoGenerate(prompt, {
                            rarity = "Rare",
                            category = "Hat",
                        })

                        -- 결과 알림
                        if result then
                            local msg = "✅ UGC FBX 생성 완료!\n\n"
                                .. "파일: " .. result.filename .. "\n"
                                .. "위치: " .. result.fbxPath .. "\n"
                                .. "템플릿 ID: " .. (result.templateId or "N/A") .. "\n\n"
                                .. "Studio에서 Import 3D로 불러오세요!"

                            print("[UGCPipeline] " .. msg)

                            -- 가이드 출력
                            print("[UGCPipeline] ===== Import 가이드 =====")
                            for i, step in ipairs(result.importGuide.steps) do
                                print("[UGCPipeline] " .. step)
                            end
                            print("[UGCPipeline] ==========================")
                        else
                            warn("[UGCPipeline] UGC 생성 실패")
                        end
                    end)
                end
            end

            -- !ugc_list
            if message == "!ugc_list" then
                local items = UGCDatabase.GetAll()
                local count = UGCDatabase.GetCount()
                print(string.format("[UGCPipeline] 등록된 UGC 아이템: %d개", count))
                for templateId, item in pairs(items) do
                    print(string.format("  - %s: %s (%s)", templateId, item.name, item.rarity))
                end
            end

            -- !ugc_give <templateId> (테스트용: 인벤토리에 즉시 지급)
            local givePrefix = "!ugc_give "
            if message:sub(1, givePrefix:len()) == givePrefix then
                local templateId = message:sub(givePrefix:len() + 1)
                if templateId ~= "" then
                    local InventoryService = require(script.Parent.InventoryService)
                    local ok, resultOrErr = InventoryService.AddItem(player.UserId, templateId)
                    if ok then
                        print(string.format("[UGCPipeline] 지급 완료: %s → %s", player.Name, templateId))
                    else
                        warn(string.format("[UGCPipeline] 지급 실패: %s", tostring(resultOrErr)))
                    end
                end
            end

            -- !ugc_equip <templateId> (테스트용: 즉시 장착)
            local equipPrefix = "!ugc_equip "
            if message:sub(1, equipPrefix:len()) == equipPrefix then
                local templateId = message:sub(equipPrefix:len() + 1)
                if templateId ~= "" then
                    local DataManager = require(script.Parent.DataManager)
                    local InventoryService = require(script.Parent.InventoryService)
                    local UGCEquipService = require(script.Parent.UGCEquipService)

                    local data = DataManager.GetData(player.UserId)
                    if not data then
                        warn("[UGCPipeline] 데이터 없음")
                        return
                    end

                    local slotIndex = nil
                    for i, inv in ipairs(data.inventory) do
                        if inv.templateId == templateId then
                            slotIndex = i
                            break
                        end
                    end

                    if not slotIndex then
                        local ok, resultOrErr = InventoryService.AddItem(player.UserId, templateId)
                        if not ok then
                            warn(string.format("[UGCPipeline] 장착 실패(지급 실패): %s", tostring(resultOrErr)))
                            return
                        end
                        slotIndex = resultOrErr.slotIndex
                    end

                    InventoryService.Equip(player.UserId, slotIndex)
                    local okEquip = UGCEquipService.Equip(player, templateId)
                    print(string.format("[UGCPipeline] 장착 %s: %s", okEquip and "성공" or "실패", templateId))
                end
            end

            -- !ugc_refresh
            if message == "!ugc_refresh" then
                GachaConfig.RefreshPool("standard_v1")
                print("[UGCPipeline] 가차 풀 갱신 완료")
            end
    end

    -- Legacy chat (Player.Chatted) — 신형 채팅에서는 호출되지 않을 수 있음
    if TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService then
        Players.PlayerAdded:Connect(function(player)
            if not isAdmin(player) then
                return
            end

            print("[UGCPipeline] 관리자 접속:", player.Name)

            player.Chatted:Connect(function(message)
                handleCommand(player, message)
            end)
        end)
    end

    -- New chat (TextChatService) — Player.Chatted 대신 여기로 들어옴
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        if UGCPipeline._textChatHooked then
            return
        end
        UGCPipeline._textChatHooked = true

        local previous = TextChatService.OnIncomingMessage
        TextChatService.OnIncomingMessage = function(textChatMessage)
            local props = nil
            if previous then
                props = previous(textChatMessage)
            end

            local textSource = textChatMessage and textChatMessage.TextSource
            if not textSource then
                return props
            end

            local player = Players:GetPlayerByUserId(textSource.UserId)
            if not player then
                return props
            end

            handleCommand(player, textChatMessage.Text)

            return props
        end
    end
end

-- ─── 백엔드 API 테스트 ─────────────────────────────────────────────────
--[[
    백엔드 API가 정상 작동하는지 테스트
    @return 성공 여부
]]
function UGCPipeline.TestBackendConnection()
    print("[UGCPipeline] 백엔드 연결 테스트...")

    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = UGCPipeline.Config.backendUrl .. "/api/health",
            Method = "GET",
        })
    end)

    if success and response.StatusCode == 200 then
        print("[UGCPipeline] ✓ 백엔드 연결 성공")
        return true
    else
        warn("[UGCPipeline] ✗ 백엔드 연결 실패")
        warn("[UGCPipeline] 백엔드 서버가 실행 중인지 확인하세요:")
        warn("[UGCPipeline]   cd backend && npm run dev")
        return false
    end
end

return UGCPipeline
