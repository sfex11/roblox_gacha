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
-- Remote 참조 대기
-------------------------------------------------------
local function waitForRemote(name, className)
    className = className or "RemoteEvent"
    local remote = ReplicatedStorage:WaitForChild(name, 15)
    if not remote then
        warn("[MainClient] Remote 대기 타임아웃:", name)
    end
    return remote
end

local remotes = {}
for name, _ in pairs(Constants.Remotes) do
    if name == "RequestOddsTable" or name == "RequestInventory"
        or name == "RequestCodex" or name == "RequestCurrency" then
        remotes[name] = waitForRemote(name, "RemoteFunction")
    else
        remotes[name] = waitForRemote(name)
    end
end

-------------------------------------------------------
-- UI 생성
-------------------------------------------------------
local mainGui = HubUI.CreateMainGui()
local gachaPanel = GachaUI.Create(mainGui)
local inventoryPanel = InventoryUI.Create(mainGui)
local codexPanel = CodexUI.Create(mainGui)
local minigamePanel = MinigameUI.Create(mainGui)

-------------------------------------------------------
-- 인벤토리 장착/해제 액션 바인딩
-------------------------------------------------------
local inventoryActionBusy = false

local function refreshInventory()
    local data = remotes[Constants.Remotes.RequestInventory]:InvokeServer()
    if data then
        InventoryUI.Refresh(data.inventory, data.equipped, data.templates)
    end
end

InventoryUI.BindActions({
    onEquip = function(slotIndex)
        if inventoryActionBusy then return end
        inventoryActionBusy = true
        remotes[Constants.Remotes.RequestEquip]:FireServer(slotIndex)
        task.spawn(function()
            task.wait(0.12)
            refreshInventory()
            inventoryActionBusy = false
        end)
    end,
    onUnequip = function(category)
        if inventoryActionBusy then return end
        inventoryActionBusy = true
        remotes[Constants.Remotes.RequestUnequip]:FireServer(category)
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
                local currency = remotes[Constants.Remotes.RequestCurrency]:InvokeServer()
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
                local data = remotes[Constants.Remotes.RequestInventory]:InvokeServer()
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
                local data = remotes[Constants.Remotes.RequestCodex]:InvokeServer()
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
        if isGachaInProgress then return end
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

        -- 폴백: 애니메이션 없이 상태만 복원
        isGachaInProgress = false
        if singleCoinBtn then singleCoinBtn.Active = true end
        if multiCoinBtn then multiCoinBtn.Active = true end
        if ticketBtn then ticketBtn.Active = true end
        return function() end
    end

    if singleCoinBtn then
        singleCoinBtn.MouseButton1Click:Connect(function()
            local stopAnimation = startGachaAnimation()
            remotes[Constants.Remotes.RequestGachaPull]:FireServer({
                pullType = "single_coin",
                requestTime = os.time()  -- 타임스탬프 추가
            })
            -- 결과는 OnClientEvent에서 처리되므로 여기서는 애니메이션만 설정
            task.delay(10, stopAnimation)  -- 최대 10초 후 애니메이션 정지
        end)
    end

    if multiCoinBtn then
        multiCoinBtn.MouseButton1Click:Connect(function()
            local stopAnimation = startGachaAnimation()
            remotes[Constants.Remotes.RequestGachaPull]:FireServer({
                pullType = "multi_coin",
                requestTime = os.time()
            })
            task.delay(15, stopAnimation)  -- 10연은 최대 15초
        end)
    end

    if ticketBtn then
        ticketBtn.MouseButton1Click:Connect(function()
            local stopAnimation = startGachaAnimation()
            remotes[Constants.Remotes.RequestGachaPull]:FireServer({
                pullType = "single_ticket",
                requestTime = os.time()
            })
            task.delay(10, stopAnimation)
        end)
    end

    if oddsBtn then
        oddsBtn.MouseButton1Click:Connect(function()
            local odds = remotes[Constants.Remotes.RequestOddsTable]:InvokeServer("standard_v1")
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
            remotes[Constants.Remotes.JoinMinigame]:FireServer("leave")
        else
            remotes[Constants.Remotes.JoinMinigame]:FireServer("join")
        end
    end)
end

-------------------------------------------------------
-- 서버 이벤트 수신
-------------------------------------------------------

-- 가차 결과
remotes[Constants.Remotes.GachaPullResult].OnClientEvent:Connect(function(result)
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

-- 미니게임 상태
remotes[Constants.Remotes.MinigameStateUpdate].OnClientEvent:Connect(function(data)
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

-- 미니게임 결과
remotes[Constants.Remotes.MinigameResult].OnClientEvent:Connect(function(result)
    if result then
        MinigameUI.ShowResult(result)
        MinigameUI.SetJoined(false)
        -- 재화 갱신
        local currency = remotes[Constants.Remotes.RequestCurrency]:InvokeServer()
        if currency then
            HubUI.UpdateCurrency(currency)
        end
    end
end)

-- 플레이어 데이터 로드 완료
remotes[Constants.Remotes.PlayerDataLoaded].OnClientEvent:Connect(function(data)
    if data and data.currency then
        HubUI.UpdateCurrency(data.currency)
    end
end)

print("[MainClient] 가차 게임 클라이언트 초기화 완료")
