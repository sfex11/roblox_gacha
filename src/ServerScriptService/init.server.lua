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
local Constants = require(ReplicatedStorage.Modules.Constants)

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

-------------------------------------------------------
-- 플레이어 입장/퇴장
-------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
    local data = DataManager.LoadData(player)
    -- 클라이언트에 로딩 완료 알림
    remotes[Constants.Remotes.PlayerDataLoaded]:FireClient(player, {
        currency = CurrencyService.GetAllCurrency(player.UserId),
    })
end)

Players.PlayerRemoving:Connect(function(player)
    MinigameService.LeaveQueue(player)
    DataManager.OnPlayerRemoving(player)
end)

-------------------------------------------------------
-- 가차 요청 처리
-------------------------------------------------------
remotes[Constants.Remotes.RequestGachaPull].OnServerEvent:Connect(function(player, params)
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
    return GachaService.GetOddsTable(poolId)
end

-------------------------------------------------------
-- 인벤토리 요청 처리
-------------------------------------------------------
remotes[Constants.Remotes.RequestInventory].OnServerInvoke = function(player)
    return {
        inventory = InventoryService.GetInventory(player.UserId),
        equipped = InventoryService.GetEquipped(player.UserId),
    }
end

remotes[Constants.Remotes.RequestEquip].OnServerEvent:Connect(function(player, slotIndex)
    if type(slotIndex) ~= "number" then return end
    InventoryService.Equip(player.UserId, slotIndex)
end)

remotes[Constants.Remotes.RequestUnequip].OnServerEvent:Connect(function(player, category)
    if type(category) ~= "string" then return end
    InventoryService.Unequip(player.UserId, category)
end)

-------------------------------------------------------
-- 도감 요청 처리
-------------------------------------------------------
remotes[Constants.Remotes.RequestCodex].OnServerInvoke = function(player)
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
    return CurrencyService.GetAllCurrency(player.UserId)
end

-------------------------------------------------------
-- 미니게임 요청 처리
-------------------------------------------------------
remotes[Constants.Remotes.JoinMinigame].OnServerEvent:Connect(function(player, action)
    if action == "join" then
        local result = MinigameService.JoinQueue(player)
        remotes[Constants.Remotes.MinigameStateUpdate]:FireClient(player, {
            type = "queue",
            data = result,
        })
    elseif action == "leave" then
        MinigameService.LeaveQueue(player)
        remotes[Constants.Remotes.MinigameStateUpdate]:FireClient(player, {
            type = "queue_left",
        })
    end
end)

-------------------------------------------------------
-- LLM 백엔드 헬스체크 (서버 시작 시)
-------------------------------------------------------
task.spawn(function()
    local health = LLMClient.HealthCheck()
    if health.online then
        print("[MainServer] LLM 백엔드 연결 확인됨 — LLM 활성화")
        LLMClient.SetEnabled(true)
    else
        print("[MainServer] LLM 백엔드 미연결 — 프리셋 텍스트 모드")
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

print("[MainServer] 가차 게임 서버 초기화 완료")
