--[[
    MinigameService.lua
    웨이브 디펜스 미니게임 — 매칭/진행/보상
]]

local Players = game:GetService("Players")
local Constants = require(game.ReplicatedStorage.Modules.Constants)
local CurrencyService = require(script.Parent.CurrencyService)
local InventoryService = require(script.Parent.InventoryService)

local MinigameService = {}

-- 대기열
local queue = {}        -- { player, ... }
local activeSessions = {} -- { [sessionId] = sessionData }
local nextSessionId = 1

-- 보상 테이블
local WaveRewards = {
    [1] = { coinsMin = 30, coinsMax = 50, ticketChance = 0,   ticketAmount = 0 },
    [2] = { coinsMin = 50, coinsMax = 80, ticketChance = 0.3, ticketAmount = 1 },
    [3] = { coinsMin = 100, coinsMax = 150, ticketChance = 1,  ticketAmount = 1 },
}
local ALL_CLEAR_BONUS_COINS = 50

-- 몬스터 정의
local WaveEnemies = {
    [1] = {
        count = 8,
        health = 50,
        damage = 5,
        speed = 10,
        name = "슬라임",
    },
    [2] = {
        count = 6,
        health = 120,
        damage = 12,
        speed = 12,
        name = "고블린",
        miniBoss = { health = 300, damage = 25, name = "고블린 대장" },
    },
    [3] = {
        count = 4,
        health = 200,
        damage = 18,
        speed = 8,
        name = "해골 전사",
        boss = { health = 800, damage = 40, name = "해골 왕" },
    },
}

-- 대기열에 플레이어 추가
function MinigameService.JoinQueue(player)
    -- 이미 대기 중인지 확인
    for _, p in ipairs(queue) do
        if p == player then
            return { success = false, error = "이미 대기 중입니다." }
        end
    end

    -- 활성 세션에 있는지 확인
    for _, session in pairs(activeSessions) do
        for _, p in ipairs(session.players) do
            if p == player then
                return { success = false, error = "이미 게임 중입니다." }
            end
        end
    end

    table.insert(queue, player)

    -- 최소 인원 충족 시 게임 시작
    if #queue >= Constants.Minigame.MinPlayers then
        MinigameService._tryStartGame()
    end

    return {
        success = true,
        position = #queue,
        message = "대기열에 참가했습니다. (" .. #queue .. "명 대기 중)",
    }
end

-- 대기열에서 나가기
function MinigameService.LeaveQueue(player)
    for i, p in ipairs(queue) do
        if p == player then
            table.remove(queue, i)
            return true
        end
    end
    return false
end

-- 게임 시작 시도
function MinigameService._tryStartGame()
    if #queue < Constants.Minigame.MinPlayers then return end

    local sessionPlayers = {}
    local count = math.min(#queue, Constants.Minigame.MaxPlayers)

    for i = 1, count do
        table.insert(sessionPlayers, table.remove(queue, 1))
    end

    local sessionId = "session_" .. nextSessionId
    nextSessionId = nextSessionId + 1

    local session = {
        sessionId = sessionId,
        players = sessionPlayers,
        currentWave = 0,
        state = "starting",    -- starting / wave_active / wave_clear / completed / failed
        waveResults = {},
        startTime = os.time(),
        enemiesRemaining = 0,
        playerStats = {},      -- [userId] = { kills, damage, alive }
    }

    -- 플레이어별 전투 스탯 로드
    for _, player in ipairs(sessionPlayers) do
        local combatStats = InventoryService.GetCombatStats(player.UserId)
        session.playerStats[player.UserId] = {
            kills = 0,
            damageDealt = 0,
            alive = true,
            attack = combatStats.attack,
            coinBoost = combatStats.coinBoost,
        }
    end

    activeSessions[sessionId] = session

    -- 3초 후 첫 웨이브 시작
    task.delay(3, function()
        MinigameService._startWave(sessionId)
    end)

    return session
end

-- 웨이브 시작
function MinigameService._startWave(sessionId)
    local session = activeSessions[sessionId]
    if not session then return end

    session.currentWave = session.currentWave + 1
    session.state = "wave_active"

    local waveData = WaveEnemies[session.currentWave]
    if not waveData then
        MinigameService._completeSession(sessionId, true)
        return
    end

    local totalEnemies = waveData.count
    if waveData.miniBoss then totalEnemies = totalEnemies + 1 end
    if waveData.boss then totalEnemies = totalEnemies + 1 end

    session.enemiesRemaining = totalEnemies

    -- 클라이언트에 웨이브 시작 알림 (실제 구현에서는 RemoteEvent)
    -- 여기서는 시뮬레이션으로 일정 시간 후 웨이브 완료 처리
    return {
        wave = session.currentWave,
        enemies = waveData,
        totalEnemies = totalEnemies,
    }
end

-- 적 처치 (클라이언트에서 서버로 호출)
function MinigameService.OnEnemyKilled(sessionId, player)
    local session = activeSessions[sessionId]
    if not session or session.state ~= "wave_active" then return end

    local stats = session.playerStats[player.UserId]
    if stats then
        stats.kills = stats.kills + 1
    end

    session.enemiesRemaining = session.enemiesRemaining - 1

    if session.enemiesRemaining <= 0 then
        MinigameService._clearWave(sessionId)
    end
end

-- 웨이브 클리어
function MinigameService._clearWave(sessionId)
    local session = activeSessions[sessionId]
    if not session then return end

    session.state = "wave_clear"

    local wave = session.currentWave
    local reward = WaveRewards[wave]
    if not reward then return end

    -- 웨이브별 보상 기록
    session.waveResults[wave] = {
        cleared = true,
    }

    -- 다음 웨이브 또는 완료
    if session.currentWave >= Constants.Minigame.WaveCount then
        MinigameService._completeSession(sessionId, true)
    else
        -- 5초 후 다음 웨이브
        task.delay(5, function()
            MinigameService._startWave(sessionId)
        end)
    end
end

-- 세션 완료 (성공/실패) — 보상 지급
function MinigameService._completeSession(sessionId, success)
    local session = activeSessions[sessionId]
    if not session then return end

    session.state = success and "completed" or "failed"

    local results = {}

    for _, player in ipairs(session.players) do
        if player.Parent then -- 아직 서버에 있는지 확인
            local userId = player.UserId
            local playerStat = session.playerStats[userId]
            local totalCoins = 0
            local totalTickets = 0

            if success then
                -- 웨이브별 보상 합산
                for w = 1, session.currentWave do
                    local reward = WaveRewards[w]
                    if reward then
                        local coins = math.random(reward.coinsMin, reward.coinsMax)

                        -- 펫 코인 부스트 적용
                        if playerStat and playerStat.coinBoost > 0 then
                            coins = math.floor(coins * (1 + playerStat.coinBoost / 100))
                        end

                        totalCoins = totalCoins + coins

                        if reward.ticketChance > 0 and math.random() <= reward.ticketChance then
                            totalTickets = totalTickets + reward.ticketAmount
                        end
                    end
                end

                -- 올클리어 보너스
                if session.currentWave >= Constants.Minigame.WaveCount then
                    totalCoins = totalCoins + ALL_CLEAR_BONUS_COINS
                end
            end

            -- 재화 지급
            if totalCoins > 0 then
                CurrencyService.AddCurrency(userId, Constants.Currency.Coins, totalCoins)
            end
            if totalTickets > 0 then
                CurrencyService.AddCurrency(userId, Constants.Currency.Tickets, totalTickets)
            end

            results[userId] = {
                coins = totalCoins,
                tickets = totalTickets,
                kills = playerStat and playerStat.kills or 0,
                wavesCleared = session.currentWave,
                allClear = session.currentWave >= Constants.Minigame.WaveCount,
            }
        end
    end

    -- 세션 정리 (30초 후)
    task.delay(30, function()
        activeSessions[sessionId] = nil
    end)

    return results
end

-- 세션 정보 조회
function MinigameService.GetSession(sessionId)
    return activeSessions[sessionId]
end

-- 대기열 상태 조회
function MinigameService.GetQueueStatus()
    return {
        count = #queue,
        maxPlayers = Constants.Minigame.MaxPlayers,
    }
end

return MinigameService
