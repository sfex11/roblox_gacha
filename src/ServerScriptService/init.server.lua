--[[
    MainServer.lua
    서버 진입점 — RemoteEvent 생성 및 서비스 연결
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 서비스 로드 (Rojo: init.server.lua이므로 하위 모듈은 script.X)
local DataManager = require(script.DataManager)
local GachaService = require(script.GachaService)
local CurrencyService = require(script.CurrencyService)
local InventoryService = require(script.InventoryService)
local CodexService = require(script.CodexService)
local MinigameService = require(script.MinigameService)
local LLMClient = require(script.LLMClient)
local GameConfig = require(script.GameConfig)
local UGCPipeline = require(script.UGCPipeline)  -- UGC 자동화 파이프라인
local UGCEquipService = require(script.UGCEquipService)
local UGCDatabase = require(ReplicatedStorage.Modules.UGCDatabase)
local ItemDatabase = require(ReplicatedStorage.Modules.ItemDatabase)
local Constants = require(ReplicatedStorage.Modules.Constants)

-------------------------------------------------------
-- 간단 레이트리밋/입력 검증
-------------------------------------------------------
local lastCallByUser = {} -- [userId] = { [action]=time }

local function isInteger(value)
    return type(value) == "number" and value % 1 == 0
end

local function canCall(player, action, cooldownSeconds)
    local userId = player.UserId
    local now = os.clock()
    lastCallByUser[userId] = lastCallByUser[userId] or {}
    local last = lastCallByUser[userId][action]
    if last and (now - last) < cooldownSeconds then
        return false
    end
    lastCallByUser[userId][action] = now
    return true
end

-------------------------------------------------------
-- RemoteEvent / RemoteFunction 생성
-------------------------------------------------------
local remotes = {}

local function createRemote(name, className)
    className = className or "RemoteEvent"
    local remote = Instance.new(className)
    remote.Name = name
    remote.Parent = ReplicatedStorage
    remotes[name] = remote
    return remote
end

for name, _ in pairs(Constants.Remotes) do
    if name == "RequestOddsTable" or name == "RequestInventory"
        or name == "RequestCodex" or name == "RequestCurrency" then
        createRemote(name, "RemoteFunction")
    else
        createRemote(name)
    end
end

-- 미니게임 서비스에 Remote 주입
MinigameService.SetRemotes(
    remotes[Constants.Remotes.MinigameStateUpdate],
    remotes[Constants.Remotes.MinigameResult]
)

-------------------------------------------------------
-- 플레이어 입장/퇴장
-------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
    local data = DataManager.LoadData(player)
    -- 클라이언트에 로딩 완료 알림
    remotes[Constants.Remotes.PlayerDataLoaded]:FireClient(player, {
        currency = CurrencyService.GetAllCurrency(player.UserId),
    })

    -- 캐릭터 리스폰 시 UGC 재장착
    player.CharacterAdded:Connect(function(character)
        UGCEquipService.OnCharacterRespawn(player)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    MinigameService.RemovePlayer(player)
    DataManager.OnPlayerRemoving(player)
    lastCallByUser[player.UserId] = nil
end)

-------------------------------------------------------
-- 가차 요청 처리
-------------------------------------------------------
remotes[Constants.Remotes.RequestGachaPull].OnServerEvent:Connect(function(player, params)
    if not canCall(player, "gacha_pull", 0.6) then
        remotes[Constants.Remotes.GachaPullResult]:FireClient(player, { success = false, error = "너무 빠릅니다. 잠시 후 다시 시도하세요." })
        return
    end
    if not params or type(params) ~= "table" then return end

    local pullType = params.pullType  -- "single_coin" / "multi_coin" / "single_ticket"
    local result

    if pullType == "single_coin" then
        result = GachaService.PullSingleCoin(player)
    elseif pullType == "multi_coin" then
        result = GachaService.PullMultiCoin(player)
    elseif pullType == "single_ticket" then
        result = GachaService.PullSingleTicket(player)
    else
        result = { success = false, error = "잘못된 뽑기 유형" }
    end

    -- 세트 완성 체크
    if result.success then
        local claimedSets = CodexService.CheckAndClaimSetRewards(player.UserId)
        result.claimedSets = claimedSets
        result.currency = CurrencyService.GetAllCurrency(player.UserId)
    end

    remotes[Constants.Remotes.GachaPullResult]:FireClient(player, result)
end)

-- 확률표 조회
remotes[Constants.Remotes.RequestOddsTable].OnServerInvoke = function(player, poolId)
    if not canCall(player, "odds_table", 0.5) then
        return nil
    end
    return GachaService.GetOddsTable(poolId)
end

-------------------------------------------------------
-- 인벤토리 요청 처리
-------------------------------------------------------
remotes[Constants.Remotes.RequestInventory].OnServerInvoke = function(player)
    if not canCall(player, "request_inventory", 0.12) then
        return nil
    end

    local function serializeTemplate(template)
        if not template or type(template) ~= "table" then
            return nil
        end

        return {
            id = template.id,
            category = template.category,
            rarity = template.rarity,
            name = template.name,
            description = template.description,
            flavorText = template.flavorText,
            ugcType = template.ugcType,
        }
    end

    local inventory = InventoryService.GetInventory(player.UserId)
    local equipped = InventoryService.GetEquipped(player.UserId)

    local templates = {}
    for _, item in ipairs(inventory) do
        local template = ItemDatabase.GetTemplate(item.templateId)
        local serialized = serializeTemplate(template)
        if serialized then
            templates[item.templateId] = serialized
        end
    end

    return {
        inventory = inventory,
        equipped = equipped,
        templates = templates,
    }
end

remotes[Constants.Remotes.RequestEquip].OnServerEvent:Connect(function(player, slotIndex)
    if not canCall(player, "equip", 0.15) then return end
    if not isInteger(slotIndex) or slotIndex < 1 then return end

    local success = InventoryService.Equip(player.UserId, slotIndex)
    if success then
        -- UGC 아이템인 경우 실제 착용 처리
        local data = DataManager.GetData(player.UserId)
        if data and data.inventory[slotIndex] then
            local item = data.inventory[slotIndex]
            local templateId = item.templateId

            -- UGC 카테고리인지 확인
            if templateId:sub(1, 3) == "UGC" then
                local equipped = UGCEquipService.Equip(player, templateId)
                if not equipped then
                    warn(string.format("[MainServer] UGC 장착 실패: userId=%d templateId=%s", player.UserId, tostring(templateId)))
                    InventoryService.Unequip(player.UserId, Constants.Category.UGC)
                end
            end
        end
    end
end)

remotes[Constants.Remotes.RequestUnequip].OnServerEvent:Connect(function(player, category)
    if not canCall(player, "unequip", 0.15) then return end
    if type(category) ~= "string" then return end
    if category ~= Constants.Category.Weapon and category ~= Constants.Category.Pet
        and category ~= Constants.Category.Costume and category ~= Constants.Category.UGC then
        return
    end

    -- UGC 해제 시 실제 액세서리 제거
    if category == Constants.Category.UGC then
        UGCEquipService.Unequip(player)
    end

    InventoryService.Unequip(player.UserId, category)
end)

-------------------------------------------------------
-- 도감 요청 처리
-------------------------------------------------------
remotes[Constants.Remotes.RequestCodex].OnServerInvoke = function(player)
    if not canCall(player, "request_codex", 0.4) then
        return nil
    end
    return {
        codex = CodexService.GetCodex(player.UserId),
        sets = CodexService.GetSetProgress(player.UserId),
        progress = { CodexService.GetCodexProgress(player.UserId) },
    }
end

-------------------------------------------------------
-- 재화 조회
-------------------------------------------------------
remotes[Constants.Remotes.RequestCurrency].OnServerInvoke = function(player)
    if not canCall(player, "request_currency", 0.2) then
        return nil
    end
    return CurrencyService.GetAllCurrency(player.UserId)
end

-------------------------------------------------------
-- 미니게임 요청 처리
-------------------------------------------------------
remotes[Constants.Remotes.JoinMinigame].OnServerEvent:Connect(function(player, action)
    if not canCall(player, "minigame_join", 0.8) then return end
    if action == "join" then
        local result = MinigameService.JoinQueue(player)
        remotes[Constants.Remotes.MinigameStateUpdate]:FireClient(player, {
            type = "queue",
            data = result,
        })
    elseif action == "leave" then
        MinigameService.RemovePlayer(player)
        remotes[Constants.Remotes.MinigameStateUpdate]:FireClient(player, {
            type = "queue_left",
        })
    end
end)

-------------------------------------------------------
-- LLM 백엔드 헬스체크 (서버 시작 시)
-------------------------------------------------------
task.spawn(function()
    local llmConfig = GameConfig.LLM or {}

    -- 설정에서 강제 활성화된 경우
    if llmConfig.enabled then
        LLMClient.SetEnabled(true)
        print("[MainServer] LLM 강제 활성화 (GameConfig.LLM.enabled = true)")
        return
    end

    -- 헬스체크로 자동 활성화
    if llmConfig.autoEnable then
        local health = LLMClient.HealthCheck()
        if health.online then
            print("[MainServer] LLM 백엔드 연결 확인됨 — LLM 활성화")
            LLMClient.SetEnabled(true)
        else
            print("[MainServer] LLM 백엔드 미연결 — 프리셋 텍스트 모드")
        end
    else
        print("[MainServer] LLM 비활성화 (GameConfig.LLM.autoEnable = false)")
    end
end)

-------------------------------------------------------
-- 자동저장 시작
-------------------------------------------------------
DataManager.StartAutosave()

-- 서버 종료 시 저장
game:BindToClose(function()
    DataManager.OnServerShutdown()
end)

-------------------------------------------------------
-- UGC 파이프라인 관리자 명령어 설정
-------------------------------------------------------
UGCPipeline.SetupAdminCommands()
print("[MainServer] UGC 파이프라인 관리자 명령어 활성화 (!ugc_make <프롬프트>)")

print("[MainServer] 가차 게임 서버 초기화 완료")
