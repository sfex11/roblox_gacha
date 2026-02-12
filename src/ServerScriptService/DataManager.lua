--[[
    DataManager.lua
    DataStore 래핑 — 플레이어 데이터 저장/로드/자동저장
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Constants = require(game.ReplicatedStorage.Modules.Constants)
local GameConfig = require(script.Parent.GameConfig)

local DataManager = {}

local DATASTORE_NAME = (GameConfig.Data and GameConfig.Data.dataStoreName) or "PlayerData_v1"
local AUTOSAVE_INTERVAL = 120 -- 2분마다 자동저장

local dataStore = nil -- 지연 초기화
local playerDataCache = {} -- [userId] = data

-- DataStore 지연 초기화 helper
local function getDataStore()
    if dataStore then
        return dataStore
    end

    local cfg = GameConfig.Data or {}
    if cfg.forceFreshData or cfg.enableDataStore == false then
        return nil
    end

    local success, ds = pcall(function()
        return DataStoreService:GetDataStore(DATASTORE_NAME)
    end)

    if success then
        dataStore = ds
        return dataStore
    else
        warn("[DataManager] DataStore 초기화 실패:", tostring(ds))
        return nil
    end
end

-- 기본 플레이어 데이터 템플릿
local function getDefaultData()
    return {
        inventory = {},          -- { {templateId, obtainedAt, slotIndex} ... }
        equipped = {             -- 카테고리당 1개
            Weapon = nil,        -- inventory slot index
            Pet = nil,
            Costume = nil,
        },
        codex = {},              -- { [templateId] = true }
        completedSets = {},      -- { [setId] = true }
        currency = {
            Coins = 10000,       -- 시작 코인 (테스트용)
            Tickets = 100,       -- 시작 티켓 (테스트용)
        },
        stats = {
            totalPulls = 0,
            lastDailyReset = 0,  -- os.time() 기준
        },
    }
end

local function deepMergeDefaults(default, data)
    if type(default) ~= "table" then
        return data
    end
    if type(data) ~= "table" then
        data = {}
    end

    for key, defaultValue in pairs(default) do
        local dataValue = data[key]
        if dataValue == nil then
            if type(defaultValue) == "table" then
                local copy = {}
                deepMergeDefaults(defaultValue, copy)
                data[key] = copy
            else
                data[key] = defaultValue
            end
        elseif type(defaultValue) == "table" then
            data[key] = deepMergeDefaults(defaultValue, dataValue)
        end
    end

    return data
end

-- 데이터 로드
function DataManager.LoadData(player)
    local userId = player.UserId
    local key = "player_" .. tostring(userId)

    local cfg = GameConfig.Data or {}

    local data
    if cfg.forceFreshData then
        data = getDefaultData()
        print("[DataManager] ForceFreshData 활성 — 새 데이터 생성:", userId)
    else
        local ds = getDataStore()
        if ds then
            local success, loaded = pcall(function()
                return ds:GetAsync(key)
            end)

            if success and type(loaded) == "table" then
                data = deepMergeDefaults(getDefaultData(), loaded)
                print("[DataManager] 데이터 로드 성공:", userId)
            else
                if not success then
                    warn("[DataManager] Load failed for " .. tostring(userId) .. ": " .. tostring(loaded))
                end
                data = getDefaultData()
                print("[DataManager] 데이터 없음/실패 — 새 데이터 생성:", userId)
            end
        else
            data = getDefaultData()
            print("[DataManager] DataStore 비활성 — 새 데이터 생성:", userId)
        end
    end

    playerDataCache[userId] = data

    -- 일일 티켓 리셋 확인
    DataManager._checkDailyReset(userId)

    return data
end

-- 데이터 저장
function DataManager.SaveData(player)
    local userId = player.UserId
    local data = playerDataCache[userId]
    if not data then return false end

    local cfg = GameConfig.Data or {}
    if cfg.forceFreshData or cfg.enableDataStore == false then
        return true
    end

    local ds = getDataStore()
    if not ds then
        return true -- DataStore 없으면 저장 성공으로 처리
    end

    local key = "player_" .. tostring(userId)
    local success, err = pcall(function()
        ds:SetAsync(key, data)
    end)

    if not success then
        warn("[DataManager] Save failed for " .. tostring(userId) .. ": " .. tostring(err))
    end
    return success
end

-- 캐시된 데이터 가져오기
function DataManager.GetData(userId)
    return playerDataCache[userId]
end

-- 일일 리셋 체크 (티켓 지급)
function DataManager._checkDailyReset(userId)
    local data = playerDataCache[userId]
    if not data then return end

    local now = os.time()
    local lastReset = data.stats.lastDailyReset or 0

    -- UTC 기준 자정을 넘었으면 리셋
    local lastDay = math.floor(lastReset / 86400)
    local today = math.floor(now / 86400)

    if today > lastDay then
        data.currency.Tickets = data.currency.Tickets + Constants.DailyTickets
        data.stats.lastDailyReset = now
    end
end

-- 플레이어 떠날 때 저장
function DataManager.OnPlayerRemoving(player)
    DataManager.SaveData(player)
    playerDataCache[player.UserId] = nil
end

-- 자동저장 루프
function DataManager.StartAutosave()
    task.spawn(function()
        while true do
            task.wait(AUTOSAVE_INTERVAL)
            for _, player in ipairs(Players:GetPlayers()) do
                DataManager.SaveData(player)
            end
        end
    end)
end

-- 서버 종료 시 전체 저장
function DataManager.OnServerShutdown()
    for _, player in ipairs(Players:GetPlayers()) do
        DataManager.SaveData(player)
    end
end

return DataManager
