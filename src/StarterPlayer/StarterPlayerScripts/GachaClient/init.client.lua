--[[
    MainClient.lua
    클라이언트 진입점 — UI 생성 및 서버 통신 연결
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Modules.Constants)

local player = Players.LocalPlayer

-- UI 모듈 로드 (Rojo: init.client.lua이므로 하위 모듈은 script.X)
local HubUI = require(script.HubUI)
local GachaUI = require(script.GachaUI)
local InventoryUI = require(script.InventoryUI)
local CodexUI = require(script.CodexUI)
local MinigameUI = require(script.MinigameUI)

-------------------------------------------------------
-- UI 생성 (Remote 로딩과 무관하게 즉시 표시)
-------------------------------------------------------
local mainGui = HubUI.CreateMainGui()
local gachaPanel = GachaUI.Create(mainGui)
local inventoryPanel = InventoryUI.Create(mainGui)
local codexPanel = CodexUI.Create(mainGui)
local minigamePanel = MinigameUI.Create(mainGui)

-------------------------------------------------------
-- Remote 초기화 (비동기/안전)
-------------------------------------------------------
local remotes = {}
local remoteConnections = {}

local REMOTE_FUNCTIONS = {
    RequestOddsTable = true,
    RequestInventory = true,
    RequestCodex = true,
    RequestCurrency = true,
}

local function findRemote(name)
    local remote = ReplicatedStorage:FindFirstChild(name)
    if remote then
        return remote
    end

    -- 폴더에 모아두는 프로젝트(예: ReplicatedStorage/Remotes)도 지원
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if remotesFolder then
        return remotesFolder:FindFirstChild(name)
    end

    return nil
end

local function resolveRemote(name)
    if remotes[name] then
        return remotes[name]
    end

    local remote = findRemote(name)
    if remote then
        remotes[name] = remote
        return remote
    end

    return nil
end

local function safeInvoke(remoteName, ...)
    local remote = resolveRemote(remoteName)
    if not remote then
        warn("[MainClient] Remote 없음(Invoke): " .. tostring(remoteName))
        return nil
    end
    if not remote:IsA("RemoteFunction") then
        warn(string.format("[MainClient] RemoteFunction 아님(Invoke): %s (%s)", tostring(remoteName), remote.ClassName))
        return nil
    end

    local ok, result = pcall(remote.InvokeServer, remote, ...)
    if not ok then
        warn(string.format("[MainClient] InvokeServer 실패: %s (%s)", tostring(remoteName), tostring(result)))
        return nil
    end
    return result
end

local function safeFire(remoteName, ...)
    local remote = resolveRemote(remoteName)
    if not remote then
        warn("[MainClient] Remote 없음(Fire): " .. tostring(remoteName))
        return false
    end
    if not remote:IsA("RemoteEvent") then
        warn(string.format("[MainClient] RemoteEvent 아님(Fire): %s (%s)", tostring(remoteName), remote.ClassName))
        return false
    end

    local ok, err = pcall(remote.FireServer, remote, ...)
    if not ok then
        warn(string.format("[MainClient] FireServer 실패: %s (%s)", tostring(remoteName), tostring(err)))
        return false
    end
    return true
end

local function tryConnectRemoteEvent(remoteName, handler)
    if remoteConnections[remoteName] then
        return true
    end

    local remote = resolveRemote(remoteName)
    if not remote then
        return false
    end
    if not remote:IsA("RemoteEvent") then
        warn(string.format("[MainClient] RemoteEvent 아님(Connect): %s (%s)", tostring(remoteName), remote.ClassName))
        return false
    end

    remoteConnections[remoteName] = remote.OnClientEvent:Connect(handler)
    return true
end

local function tryConnectServerEvents()
    tryConnectRemoteEvent(Constants.Remotes.GachaPullResult, function(result)
        if not result then return end

        if result.success then
            GachaUI.ShowResult(result.items)
            -- 재화 업데이트
            if result.currency then
                GachaUI.UpdateCurrency(result.currency.Coins or 0, result.currency.Tickets or 0)
                HubUI.UpdateCurrency(result.currency)
            end
            -- 세트 완성 알림
            if result.claimedSets and #result.claimedSets > 0 then
                for _, set in ipairs(result.claimedSets) do
                    -- 간단한 알림 (추후 연출 강화)
                    print("[세트 완성!] " .. set.displayName)
                end
            end
        else
            warn(result.error or "가차 실패")
        end
    end)

    tryConnectRemoteEvent(Constants.Remotes.MinigameStateUpdate, function(data)
        if not data then return end

        if data.type == "queue" then
            MinigameUI.UpdateQueue(data.data)
        elseif data.type == "queue_left" then
            MinigameUI.SetJoined(false)
            MinigameUI.SetStatus("")
        elseif data.type == "session_start" then
            MinigameUI.SetJoined(true)
            local startIn = tonumber(data.startIn) or 3
            MinigameUI.SetStatus("게임 시작! " .. tostring(startIn) .. "초 후 웨이브 시작")
        elseif data.type == "wave_start" then
            local wave = tonumber(data.wave) or 0
            local enemyName = data.enemies and data.enemies.name or ""
            MinigameUI.SetStatus("Wave " .. tostring(wave) .. " 시작! " .. tostring(enemyName))
        elseif data.type == "wave_clear" then
            local wave = tonumber(data.wave) or 0
            MinigameUI.SetStatus("Wave " .. tostring(wave) .. " 클리어!")
        elseif data.type == "player_left" then
            MinigameUI.SetStatus("플레이어가 나갔습니다.")
        elseif data.type == "session_end" then
            MinigameUI.SetJoined(false)
            MinigameUI.SetStatus("미니게임 종료")
        end
    end)

    tryConnectRemoteEvent(Constants.Remotes.MinigameResult, function(result)
        if result then
            MinigameUI.ShowResult(result)
            MinigameUI.SetJoined(false)
            -- 재화 갱신
            local currency = safeInvoke(Constants.Remotes.RequestCurrency)
            if currency then
                HubUI.UpdateCurrency(currency)
            end
        end
    end)

    tryConnectRemoteEvent(Constants.Remotes.PlayerDataLoaded, function(data)
        print("[MainClient] PlayerDataLoaded 수신:", data)
        if data and data.currency then
            print("[MainClient] 재화 업데이트:", data.currency.Coins, data.currency.Tickets)
            HubUI.UpdateCurrency(data.currency)
        else
            warn("[MainClient] PlayerDataLoaded에 currency가 없음:", data)
        end
    end)
end

-- 1차: 즉시 스캔 (UI 블로킹 없음)
do
    local missing = {}
    for name, _ in pairs(Constants.Remotes) do
        local expectedClass = REMOTE_FUNCTIONS[name] and "RemoteFunction" or "RemoteEvent"
        local remote = resolveRemote(name)

        if not remote then
            table.insert(missing, name)
        elseif remote.ClassName ~= expectedClass then
            warn(string.format("[MainClient] Remote 타입 불일치: %s (expected=%s actual=%s)", name, expectedClass, remote.ClassName))
        end
    end

    if #missing > 0 then
        warn("[MainClient] Remote 일부 없음(초기): " .. table.concat(missing, ", "))
    end
end

-- 2차: 일정 시간 재시도 (서버 초기화 지연 대비)
task.spawn(function()
    local startTime = os.clock()
    local maxWait = 60

    while os.clock() - startTime < maxWait do
        local missingCount = 0
        for name, _ in pairs(Constants.Remotes) do
            if not remotes[name] then
                missingCount = missingCount + 1
                resolveRemote(name)
            end
        end

        tryConnectServerEvents()

        if missingCount == 0 then
            print("[MainClient] 모든 Remote 로드 완료")
            return
        end

        task.wait(0.5)
    end

    -- 최종 누락 로그
    local missing = {}
    for name, _ in pairs(Constants.Remotes) do
        if not remotes[name] then
            table.insert(missing, name)
        end
    end

    warn("[MainClient] Remote 로드 타임아웃(" .. tostring(maxWait) .. "s). 누락: " .. table.concat(missing, ", "))
end)

-------------------------------------------------------
-- 인벤토리 장착/해제 액션 바인딩
-------------------------------------------------------
local inventoryActionBusy = false

local function refreshInventory()
    local data = safeInvoke(Constants.Remotes.RequestInventory)
    if data then
        InventoryUI.Refresh(data.inventory, data.equipped, data.templates)
    end
end

InventoryUI.BindActions({
    onEquip = function(slotIndex)
        if inventoryActionBusy then return end
        inventoryActionBusy = true
        safeFire(Constants.Remotes.RequestEquip, slotIndex)
        task.spawn(function()
            task.wait(0.12)
            refreshInventory()
            inventoryActionBusy = false
        end)
    end,
    onUnequip = function(category)
        if inventoryActionBusy then return end
        inventoryActionBusy = true
        safeFire(Constants.Remotes.RequestUnequip, category)
        task.spawn(function()
            task.wait(0.12)
            refreshInventory()
            inventoryActionBusy = false
        end)
    end,
})

-------------------------------------------------------
-- 모든 패널 닫기 (하나만 열기 위해)
-------------------------------------------------------
local function closeAllPanels()
    GachaUI.Hide()
    InventoryUI.Hide()
    CodexUI.Hide()
    MinigameUI.Hide()
end

-------------------------------------------------------
-- 메뉴 버튼 이벤트 연결
-------------------------------------------------------
local menuBar = mainGui:FindFirstChild("MenuBar")
if menuBar then
    local gachaBtn = menuBar:FindFirstChild("GachaBtn")
    local inventoryBtn = menuBar:FindFirstChild("InventoryBtn")
    local codexBtn = menuBar:FindFirstChild("CodexBtn")
    local minigameBtn = menuBar:FindFirstChild("MinigameBtn")

    if gachaBtn then
        gachaBtn.MouseButton1Click:Connect(function()
            local wasVisible = gachaPanel.Visible
            closeAllPanels()
            if not wasVisible then
                GachaUI.Show()
                -- 재화 갱신
                local currency = safeInvoke(Constants.Remotes.RequestCurrency)
                if currency then
                    GachaUI.UpdateCurrency(currency.Coins or 0, currency.Tickets or 0)
                    HubUI.UpdateCurrency(currency)
                end
            end
        end)
    end

    if inventoryBtn then
        inventoryBtn.MouseButton1Click:Connect(function()
            local wasVisible = inventoryPanel.Visible
            closeAllPanels()
            if not wasVisible then
                InventoryUI.Show()
                local data = safeInvoke(Constants.Remotes.RequestInventory)
                if data then
                    InventoryUI.Refresh(data.inventory, data.equipped, data.templates)
                end
            end
        end)
    end

    if codexBtn then
        codexBtn.MouseButton1Click:Connect(function()
            local wasVisible = codexPanel.Visible
            closeAllPanels()
            if not wasVisible then
                CodexUI.Show()
                local data = safeInvoke(Constants.Remotes.RequestCodex)
                if data then
                    CodexUI.Refresh(data.codex, data.sets, data.progress)
                end
            end
        end)
    end

    if minigameBtn then
        minigameBtn.MouseButton1Click:Connect(function()
            local wasVisible = minigamePanel.Visible
            closeAllPanels()
            if not wasVisible then
                MinigameUI.Show()
            end
        end)
    end
end

-------------------------------------------------------
-- 가차 버튼 이벤트 + 로딩 연출
-------------------------------------------------------
local buttonArea = gachaPanel:FindFirstChild("ButtonArea")
if buttonArea then
    local singleCoinBtn = buttonArea:FindFirstChild("SingleCoinBtn")
    local multiCoinBtn = buttonArea:FindFirstChild("MultiCoinBtn")
    local ticketBtn = buttonArea:FindFirstChild("TicketBtn")
    local oddsBtn = buttonArea:FindFirstChild("OddsBtn")
    local gachaMachine = gachaPanel:FindFirstChild("MachineFrame")

    -- 로딩 상태 추적
    local isGachaInProgress = false

    local function startGachaAnimation()
        if isGachaInProgress then
            return function() end
        end
        isGachaInProgress = true

        -- 버튼 비활성화
        if singleCoinBtn then singleCoinBtn.Active = false end
        if multiCoinBtn then multiCoinBtn.Active = false end
        if ticketBtn then ticketBtn.Active = false end

        -- 가차 머신 애니메이션 (회전 효과)
        if gachaMachine then
            local label = gachaMachine:FindFirstChild("TextLabel")
            if label then
                label.Text = "뽑는 중..."
                local spin = 0
                local connection
                connection = game:GetService("RunService").Heartbeat:Connect(function()
                    spin = spin + 10
                    gachaMachine.Rotation = spin
                end)

                -- 애니메이션 정지 함수 반환
                return function()
                    connection:Disconnect()
                    gachaMachine.Rotation = 0
                    label.Text = "GACHA"
                    isGachaInProgress = false
                    if singleCoinBtn then singleCoinBtn.Active = true end
                    if multiCoinBtn then multiCoinBtn.Active = true end
                    if ticketBtn then ticketBtn.Active = true end
                end
            end
        end

        return function() end  -- 폴백
    end

    if singleCoinBtn then
        singleCoinBtn.MouseButton1Click:Connect(function()
            local stopAnimation = startGachaAnimation()
            local ok = safeFire(Constants.Remotes.RequestGachaPull, {
                pullType = "single_coin",
                requestTime = os.time()  -- 타임스탬프 추가
            })
            -- 결과는 OnClientEvent에서 처리되므로 여기서는 애니메이션만 설정
            if ok then
                task.delay(10, stopAnimation)  -- 최대 10초 후 애니메이션 정지
            else
                stopAnimation()
            end
        end)
    end

    if multiCoinBtn then
        multiCoinBtn.MouseButton1Click:Connect(function()
            local stopAnimation = startGachaAnimation()
            local ok = safeFire(Constants.Remotes.RequestGachaPull, {
                pullType = "multi_coin",
                requestTime = os.time()
            })
            if ok then
                task.delay(15, stopAnimation)  -- 10연은 최대 15초
            else
                stopAnimation()
            end
        end)
    end

    if ticketBtn then
        ticketBtn.MouseButton1Click:Connect(function()
            local stopAnimation = startGachaAnimation()
            local ok = safeFire(Constants.Remotes.RequestGachaPull, {
                pullType = "single_ticket",
                requestTime = os.time()
            })
            if ok then
                task.delay(10, stopAnimation)
            else
                stopAnimation()
            end
        end)
    end

    if oddsBtn then
        oddsBtn.MouseButton1Click:Connect(function()
            local odds = safeInvoke(Constants.Remotes.RequestOddsTable, "standard_v1")
            if odds then
                GachaUI.ShowOddsTable(odds)
            end
        end)
    end
end

-- 가차 패널 닫기 버튼
local gachaCloseBtn = gachaPanel:FindFirstChild("CloseBtn")
if gachaCloseBtn then
    gachaCloseBtn.MouseButton1Click:Connect(function()
        GachaUI.Hide()
    end)
end

-- 인벤토리 패널 닫기 버튼
local invCloseBtn = inventoryPanel:FindFirstChild("CloseBtn")
if invCloseBtn then
    invCloseBtn.MouseButton1Click:Connect(function()
        InventoryUI.Hide()
    end)
end

-- 도감 패널 닫기 버튼
local codexCloseBtn = codexPanel:FindFirstChild("CloseBtn")
if codexCloseBtn then
    codexCloseBtn.MouseButton1Click:Connect(function()
        CodexUI.Hide()
    end)
end

-- 미니게임 패널 닫기/참가 버튼
local mgCloseBtn = minigamePanel:FindFirstChild("CloseBtn")
if mgCloseBtn then
    mgCloseBtn.MouseButton1Click:Connect(function()
        MinigameUI.Hide()
    end)
end

local mgJoinBtn = minigamePanel:FindFirstChild("JoinBtn")
if mgJoinBtn then
    mgJoinBtn.MouseButton1Click:Connect(function()
        if MinigameUI.joined then
            safeFire(Constants.Remotes.JoinMinigame, "leave")
        else
            safeFire(Constants.Remotes.JoinMinigame, "join")
        end
    end)
end

-------------------------------------------------------
-- 서버 이벤트 수신
-------------------------------------------------------
tryConnectServerEvents()

-------------------------------------------------------
-- 관리자 모드 설정 (UGC 생성 버튼 표시)
-------------------------------------------------------
local RunService = game:GetService("RunService")

local function checkAdminMode()
    if Constants.IsAdmin(player, RunService) then
        GachaUI.SetAdminMode(true)
        print("[MainClient] 관리자 모드 활성화 - UGC 생성 버튼 표시")
    else
        GachaUI.SetAdminMode(false)
    end
end

-- 플레이어 캐릭터 로드 후 확인 (캐릭터가 로드된 시점에 확인)
if player.Character then
    checkAdminMode()
else
    player.CharacterAdded:Connect(function()
        checkAdminMode()
    end)
end

print("[MainClient] 가차 게임 클라이언트 초기화 완료")
