--[[
    MinigameService.lua
    웨이브 디펜스 미니게임 — 매칭/진행/보상
]]

local Players = game:GetService("Players")
local Constants = require(game.ReplicatedStorage.Modules.Constants)
local CurrencyService = require(script.Parent.CurrencyService)
local InventoryService = require(script.Parent.InventoryService)

local MinigameService = {}

-- init.server.lua에서 주입되는 RemoteEvent 참조
local remoteStateUpdate = nil
local remoteResult = nil

function MinigameService.SetRemotes(stateUpdateRemote, resultRemote)
    remoteStateUpdate = stateUpdateRemote
    remoteResult = resultRemote
end

local function broadcast(players, payload)
    if not remoteStateUpdate then return end
    for _, plr in ipairs(players) do
        if plr and plr.Parent then
            remoteStateUpdate:FireClient(plr, payload)
        end
    end
end

local function sendResult(player, payload)
    if not remoteResult then return end
    if player and player.Parent then
        remoteResult:FireClient(player, payload)
    end
end

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

local function calculateWaveDuration(session, wave)
    -- 공격력이 높을수록 조금 더 빨리 끝나는 "시뮬레이션" 웨이브
    local baseByWave = { [1] = 8, [2] = 10, [3] = 12 }
    local base = baseByWave[wave] or 10

    local totalAttack = 0
    for _, stat in pairs(session.playerStats) do
        totalAttack = totalAttack + (stat.attack or 0)
    end

    local reduce = totalAttack / 60 -- 공격력 60당 1초 단축
    return math.max(4, base - reduce)
end

local function distributeKills(session, totalEnemies)
    local players = {}
    local totalWeight = 0

    for _, plr in ipairs(session.players) do
        if plr and plr.Parent then
            local stat = session.playerStats[plr.UserId]
            if stat and stat.alive ~= false then
                local w = math.max(1, stat.attack or 1)
                totalWeight = totalWeight + w
                table.insert(players, { player = plr, weight = w })
            end
        end
    end

    if #players == 0 or totalEnemies <= 0 then return end

    for _ = 1, totalEnemies do
        local roll = math.random(1, totalWeight)
        local cumulative = 0
        for _, entry in ipairs(players) do
            cumulative = cumulative + entry.weight
            if roll <= cumulative then
                local stat = session.playerStats[entry.player.UserId]
                if stat then
                    stat.kills = (stat.kills or 0) + 1
                end
                break
            end
        end
    end
end

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

    local position = #queue + 1
    table.insert(queue, player)

    -- 최소 인원 충족 시 게임 시작
    local startedSession = nil
    if #queue >= Constants.Minigame.MinPlayers then
        startedSession = MinigameService._tryStartGame()
    end

    local startedForThisPlayer = startedSession and table.find(startedSession.players, player) ~= nil

    return {
        success = true,
        position = position,
        message = startedForThisPlayer and "게임을 시작합니다!" or ("대기열에 참가했습니다. (" .. #queue .. "명 대기 중)"),
        started = startedForThisPlayer,
        sessionId = startedForThisPlayer and startedSession.sessionId or nil,
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

-- 대기열/세션에서 플레이어 제거 (나가기/퇴장 처리)
function MinigameService.RemovePlayer(player)
    MinigameService.LeaveQueue(player)

    for sessionId, session in pairs(activeSessions) do
        for i = #session.players, 1, -1 do
            if session.players[i] == player then
                table.remove(session.players, i)
                local stat = session.playerStats[player.UserId]
                if stat then
                    stat.alive = false
                end
                broadcast(session.players, {
                    type = "player_left",
                    sessionId = sessionId,
                    userId = player.UserId,
                })
                break
            end
        end

        if #session.players == 0 then
            activeSessions[sessionId] = nil
        end
    end
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

    -- 세션 시작 알림
    broadcast(sessionPlayers, {
        type = "session_start",
        sessionId = sessionId,
        startIn = 3,
        waveCount = Constants.Minigame.WaveCount,
    })

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

    broadcast(session.players, {
        type = "wave_start",
        sessionId = sessionId,
        wave = session.currentWave,
        enemies = waveData,
        totalEnemies = totalEnemies,
        duration = calculateWaveDuration(session, session.currentWave),
    })

    -- 실제 전투 구현 전 MVP: 일정 시간 후 자동 클리어
    local duration = calculateWaveDuration(session, session.currentWave)
    task.delay(duration, function()
        local latest = activeSessions[sessionId]
        if not latest or latest.state ~= "wave_active" then return end
        distributeKills(latest, latest.enemiesRemaining)
        latest.enemiesRemaining = 0
        MinigameService._clearWave(sessionId)
    end)
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

    broadcast(session.players, {
        type = "wave_clear",
        sessionId = sessionId,
        wave = wave,
    })

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

    -- 결과 전송
    for _, player in ipairs(session.players) do
        if player and player.Parent then
            local payload = results[player.UserId]
            if payload then
                sendResult(player, payload)
            end
        end
    end

    broadcast(session.players, {
        type = "session_end",
        sessionId = sessionId,
        success = success,
    })

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
