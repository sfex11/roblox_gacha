--[[
    GachaServer.server.lua
    서버 진입점 — RemoteEvent 생성 및 서비스 연결
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Modules.Constants)

-------------------------------------------------------
-- RemoteEvent / RemoteFunction 생성 (서버 로직 로드보다 먼저)
-------------------------------------------------------
local remotes = {}

local REMOTE_FUNCTIONS = {
    RequestOddsTable = true,
    RequestInventory = true,
    RequestCodex = true,
    RequestCurrency = true,
}

local function getOrCreateRemote(name)
    local expectedClass = REMOTE_FUNCTIONS[name] and "RemoteFunction" or "RemoteEvent"

    local existing = ReplicatedStorage:FindFirstChild(name)
    if existing then
        if existing.ClassName == expectedClass then
            remotes[name] = existing
            return existing
        end

        warn(string.format("[MainServer] Remote 타입 불일치(재생성): %s expected=%s actual=%s", name, expectedClass, existing.ClassName))
        existing:Destroy()
    end

    local remote = Instance.new(expectedClass)
    remote.Name = name
    remote.Parent = ReplicatedStorage
    remotes[name] = remote
    return remote
end

for name, _ in pairs(Constants.Remotes) do
    getOrCreateRemote(name)
end

print("[MainServer] Remotes 준비 완료")

-- 서비스 로드 (Rojo: ServerScriptService 하위 모듈)
local function safeRequireLocal(name)
    local module = script:FindFirstChild(name) or script.Parent:FindFirstChild(name)
    if not module then
        error(string.format("[MainServer] 로컬 모듈을 찾을 수 없음: %s", tostring(name)))
    end

    local ok, result = pcall(require, module)
    if not ok then
        warn(string.format("[MainServer] 모듈 로드 실패: %s", tostring(name)))
        error(tostring(result))
    end

    return result
end

local DataManager = safeRequireLocal("DataManager")
local GachaService = safeRequireLocal("GachaService")
local CurrencyService = safeRequireLocal("CurrencyService")
local InventoryService = safeRequireLocal("InventoryService")
local CodexService = safeRequireLocal("CodexService")
local MinigameService = safeRequireLocal("MinigameService")
local LLMClient = safeRequireLocal("LLMClient")
local GameConfig = safeRequireLocal("GameConfig")
local UGCPipeline = safeRequireLocal("UGCPipeline")
local UGCEquipService = safeRequireLocal("UGCEquipService")
local UGCDatabase = require(ReplicatedStorage.Modules.UGCDatabase)
local ItemDatabase = require(ReplicatedStorage.Modules.ItemDatabase)

local RunService = game:GetService("RunService")

-- 미니게임 서비스에 Remote 주입
MinigameService.SetRemotes(
    remotes[Constants.Remotes.MinigameStateUpdate],
    remotes[Constants.Remotes.MinigameResult]
)

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
-- 플레이어 입장/퇴장
-------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
    local data = DataManager.LoadData(player)
    print("[MainServer] 플레이어 입장:", player.UserId, "시작 재화:", data.currency.Coins, data.currency.Tickets)

    -- 클라이언트에 로딩 완료 알림 (data에서 직접 가져오기)
    remotes[Constants.Remotes.PlayerDataLoaded]:FireClient(player, {
        currency = {
            Coins = data.currency.Coins or 10000,
            Tickets = data.currency.Tickets or 100,
        },
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

-------------------------------------------------------
-- UGC 생성 RemoteFunction (관리자 전용)
-------------------------------------------------------
local ugcCreateFunc = Instance.new("RemoteFunction")
ugcCreateFunc.Name = "UGCCreateItem"
ugcCreateFunc.Parent = ReplicatedStorage

ugcCreateFunc.OnServerInvoke = function(player, prompt, category, rarity)
    -- 관리자 권한 확인 (GameConfig 사용)
    if not GameConfig.IsAdmin(player, RunService) then
        warn(string.format("[MainServer] 비권한 UGC 생성 시도: userId=%d name=%s", player.UserId, player.Name))
        return { success = false, error = "권한이 없습니다." }
    end

    -- 입력 검증
    if type(prompt) ~= "string" or prompt == "" then
        return { success = false, error = "프롬프트를 입력해주세요." }
    end

    if type(category) ~= "string" or category == "" then
        category = "Hat"
    end

    if type(rarity) ~= "string" or rarity == "" then
        rarity = "Rare"
    end

    print(string.format("[MainServer] UGC 생성 요청: userId=%d prompt='%s' category=%s rarity=%s",
        player.UserId, prompt, category, rarity))

    -- UGC 절차적 생성
    local result = UGCPipeline.GenerateProceduralUGC(prompt, {
        rarity = rarity,
        category = category,
        theme = "default",
    })

    if not result or not result.templateId then
        return { success = false, error = "UGC 생성 실패 (백엔드 연결 확인 필요)" }
    end

    local templateId = result.templateId

    -- 즉시 지급 + 장착
    local okAdd, addOrErr = InventoryService.AddItem(player.UserId, templateId)
    if okAdd then
        InventoryService.Equip(player.UserId, addOrErr.slotIndex)
    else
        warn(string.format("[MainServer] 인벤토리 지급 실패(무시하고 장착 시도): %s", tostring(addOrErr)))
    end

    local okEquip = UGCEquipService.Equip(player, templateId)

    print(string.format("[MainServer] UGC 생성/장착 %s: %s (%s/%s)",
        okEquip and "성공" or "실패",
        templateId,
        rarity,
        category))

    return {
        success = true,
        templateId = templateId,
        spec = result.spec,
    }
end

print("[MainServer] 가차 게임 서버 초기화 완료")
