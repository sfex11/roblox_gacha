--[[
    GachaAnimation.lua
    가차 연출 시스템 — 희귀도별 이펙트, 캡슐 애니메이션
    클라이언트에서 결과 수신 후 연출을 재생하고, 완료 후 결과 카드를 표시
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Constants = require(game.ReplicatedStorage.Modules.Constants)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GachaAnimation = {}

-- 희귀도별 연출 설정
local RarityEffects = {
    [Constants.Rarity.Common] = {
        glowColor = Color3.fromRGB(180, 180, 180),
        shakeIntensity = 0,
        particleCount = 3,
        bgFlash = false,
        soundPitch = 1.0,
        duration = 1.5,
    },
    [Constants.Rarity.Rare] = {
        glowColor = Color3.fromRGB(70, 130, 255),
        shakeIntensity = 2,
        particleCount = 6,
        bgFlash = false,
        soundPitch = 1.1,
        duration = 2.0,
    },
    [Constants.Rarity.Epic] = {
        glowColor = Color3.fromRGB(170, 70, 255),
        shakeIntensity = 4,
        particleCount = 10,
        bgFlash = true,
        soundPitch = 1.2,
        duration = 2.5,
    },
    [Constants.Rarity.Legendary] = {
        glowColor = Color3.fromRGB(255, 200, 50),
        shakeIntensity = 6,
        particleCount = 15,
        bgFlash = true,
        soundPitch = 1.3,
        duration = 3.0,
    },
    [Constants.Rarity.Mythic] = {
        glowColor = Color3.fromRGB(255, 80, 120),
        shakeIntensity = 8,
        particleCount = 25,
        bgFlash = true,
        soundPitch = 1.5,
        duration = 3.5,
    },
}

-------------------------------------------------------
-- 단일 뽑기 연출 재생
-------------------------------------------------------
function GachaAnimation.PlaySingle(item, callback)
    local effect = RarityEffects[item.rarity] or RarityEffects[Constants.Rarity.Common]

    -- 연출 ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "GachaAnimation"
    screenGui.DisplayOrder = 20
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = playerGui

    -- 어두운 배경
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.new(0, 0, 0)
    bg.BackgroundTransparency = 0.4
    bg.Parent = screenGui

    -- 캡슐 (원형)
    local capsule = Instance.new("Frame")
    capsule.Name = "Capsule"
    capsule.Size = UDim2.new(0, 120, 0, 120)
    capsule.Position = UDim2.new(0.5, -60, 0.5, -60)
    capsule.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    capsule.Parent = screenGui

    local capsuleCorner = Instance.new("UICorner")
    capsuleCorner.CornerRadius = UDim.new(0.5, 0) -- 원형
    capsuleCorner.Parent = capsule

    local capsuleStroke = Instance.new("UIStroke")
    capsuleStroke.Color = Color3.fromRGB(120, 120, 140)
    capsuleStroke.Thickness = 3
    capsuleStroke.Parent = capsule

    local capsuleText = Instance.new("TextLabel")
    capsuleText.Size = UDim2.new(1, 0, 1, 0)
    capsuleText.BackgroundTransparency = 1
    capsuleText.Text = "?"
    capsuleText.TextColor3 = Color3.new(1, 1, 1)
    capsuleText.TextSize = 40
    capsuleText.Font = Enum.Font.GothamBold
    capsuleText.Parent = capsule

    -- 스킵 버튼
    local skipBtn = Instance.new("TextButton")
    skipBtn.Size = UDim2.new(0, 120, 0, 35)
    skipBtn.Position = UDim2.new(1, -130, 1, -50)
    skipBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    skipBtn.BackgroundTransparency = 0.3
    skipBtn.Text = "스킵 >"
    skipBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    skipBtn.TextSize = 14
    skipBtn.Font = Enum.Font.Gotham
    skipBtn.Parent = screenGui

    local skipCorner = Instance.new("UICorner")
    skipCorner.CornerRadius = UDim.new(0, 6)
    skipCorner.Parent = skipBtn

    local skipped = false
    skipBtn.MouseButton1Click:Connect(function()
        skipped = true
    end)

    -- 연출 코루틴
    task.spawn(function()
        -- Phase 1: 캡슐 등장 (바운스)
        capsule.Size = UDim2.new(0, 0, 0, 0)
        capsule.Position = UDim2.new(0.5, 0, 0.5, 0)

        local appearTween = TweenService:Create(capsule, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 120, 0, 120),
            Position = UDim2.new(0.5, -60, 0.5, -60),
        })
        appearTween:Play()
        appearTween.Completed:Wait()

        if skipped then
            screenGui:Destroy()
            if callback then callback() end
            return
        end

        -- Phase 2: 흔들림 (빌드업)
        if effect.shakeIntensity > 0 then
            local shakeTime = effect.duration * 0.3
            local startTime = tick()
            while tick() - startTime < shakeTime and not skipped do
                local intensity = effect.shakeIntensity * ((tick() - startTime) / shakeTime)
                local offsetX = math.random(-1, 1) * intensity
                local offsetY = math.random(-1, 1) * intensity
                capsule.Position = UDim2.new(0.5, -60 + offsetX, 0.5, -60 + offsetY)
                task.wait(0.03)
            end
            capsule.Position = UDim2.new(0.5, -60, 0.5, -60)
        end

        if skipped then
            screenGui:Destroy()
            if callback then callback() end
            return
        end

        -- Phase 3: 빛 누출 (희귀도 색상)
        capsuleStroke.Color = effect.glowColor
        capsuleStroke.Thickness = 3

        local glowTween = TweenService:Create(capsuleStroke, TweenInfo.new(0.5), {
            Thickness = 8,
        })
        glowTween:Play()

        capsule.BackgroundColor3 = effect.glowColor
        local colorTween = TweenService:Create(capsule, TweenInfo.new(0.5), {
            BackgroundTransparency = 0.3,
        })
        colorTween:Play()
        colorTween.Completed:Wait()

        if skipped then
            screenGui:Destroy()
            if callback then callback() end
            return
        end

        -- Phase 4: 배경 플래시 (Epic 이상)
        if effect.bgFlash then
            local flash = Instance.new("Frame")
            flash.Size = UDim2.new(1, 0, 1, 0)
            flash.BackgroundColor3 = effect.glowColor
            flash.BackgroundTransparency = 0.3
            flash.ZIndex = 5
            flash.Parent = screenGui

            local flashTween = TweenService:Create(flash, TweenInfo.new(0.4), {
                BackgroundTransparency = 1,
            })
            flashTween:Play()
            flashTween.Completed:Connect(function()
                flash:Destroy()
            end)
        end

        -- Phase 5: 캡슐 파열 → 확대 후 사라짐
        local burstTween = TweenService:Create(capsule, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 200, 0, 200),
            Position = UDim2.new(0.5, -100, 0.5, -100),
            BackgroundTransparency = 1,
        })
        burstTween:Play()

        local strokeFade = TweenService:Create(capsuleStroke, TweenInfo.new(0.3), {
            Thickness = 0,
        })
        strokeFade:Play()

        -- 파티클 효과 (간단한 프레임 기반)
        GachaAnimation._spawnParticles(screenGui, effect.glowColor, effect.particleCount)

        burstTween.Completed:Wait()
        task.wait(0.3)

        -- 결과 카드 표시
        local rarityInfo = Constants.RarityInfo[item.rarity]

        local resultCard = Instance.new("Frame")
        resultCard.Name = "ResultCard"
        resultCard.Size = UDim2.new(0, 0, 0, 0)
        resultCard.Position = UDim2.new(0.5, 0, 0.5, 0)
        resultCard.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
        resultCard.Parent = screenGui

        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 12)
        cardCorner.Parent = resultCard

        local cardStroke = Instance.new("UIStroke")
        cardStroke.Color = effect.glowColor
        cardStroke.Thickness = 3
        cardStroke.Parent = resultCard

        -- 카드 등장 애니메이션
        local cardAppear = TweenService:Create(resultCard, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 260, 0, 340),
            Position = UDim2.new(0.5, -130, 0.5, -170),
        })
        cardAppear:Play()
        cardAppear.Completed:Wait()

        -- 희귀도 라벨
        local rarityLabel = Instance.new("TextLabel")
        rarityLabel.Size = UDim2.new(1, 0, 0, 30)
        rarityLabel.Position = UDim2.new(0, 0, 0, 10)
        rarityLabel.BackgroundTransparency = 1
        rarityLabel.Text = rarityInfo and rarityInfo.displayName or ""
        rarityLabel.TextColor3 = effect.glowColor
        rarityLabel.TextSize = 18
        rarityLabel.Font = Enum.Font.GothamBold
        rarityLabel.Parent = resultCard

        -- 아이콘 영역
        local iconFrame = Instance.new("Frame")
        iconFrame.Size = UDim2.new(0, 120, 0, 120)
        iconFrame.Position = UDim2.new(0.5, -60, 0, 50)
        iconFrame.BackgroundColor3 = effect.glowColor
        iconFrame.BackgroundTransparency = 0.6
        iconFrame.Parent = resultCard

        local iconCorner = Instance.new("UICorner")
        iconCorner.CornerRadius = UDim.new(0, 12)
        iconCorner.Parent = iconFrame

        -- 아이템 이름
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -20, 0, 30)
        nameLabel.Position = UDim2.new(0, 10, 0, 185)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = item.name or "???"
        nameLabel.TextColor3 = Color3.new(1, 1, 1)
        nameLabel.TextSize = 20
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.Parent = resultCard

        -- 설명
        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, -20, 0, 40)
        descLabel.Position = UDim2.new(0, 10, 0, 220)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = item.description or ""
        descLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        descLabel.TextSize = 13
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextWrapped = true
        descLabel.Parent = resultCard

        -- NEW / 중복 표시
        local statusLabel = Instance.new("TextLabel")
        statusLabel.Size = UDim2.new(1, 0, 0, 30)
        statusLabel.Position = UDim2.new(0, 0, 0, 270)
        statusLabel.BackgroundTransparency = 1
        statusLabel.TextSize = 18
        statusLabel.Font = Enum.Font.GothamBold
        statusLabel.Parent = resultCard

        if item.isNew then
            statusLabel.Text = "NEW!"
            statusLabel.TextColor3 = Color3.fromRGB(50, 255, 50)
        elseif item.isDuplicate then
            statusLabel.Text = "+" .. tostring(item.duplicateCoins) .. " Coin"
            statusLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
        end

        -- 탭하여 닫기
        local touchBtn = Instance.new("TextButton")
        touchBtn.Size = UDim2.new(1, 0, 0, 25)
        touchBtn.Position = UDim2.new(0, 0, 1, -30)
        touchBtn.BackgroundTransparency = 1
        touchBtn.Text = "탭하여 계속"
        touchBtn.TextColor3 = Color3.fromRGB(120, 120, 120)
        touchBtn.TextSize = 12
        touchBtn.Font = Enum.Font.Gotham
        touchBtn.Parent = resultCard

        touchBtn.MouseButton1Click:Connect(function()
            screenGui:Destroy()
            if callback then callback() end
        end)

        -- 배경 클릭으로도 닫기
        bg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                screenGui:Destroy()
                if callback then callback() end
            end
        end)
    end)
end

-------------------------------------------------------
-- 10연 뽑기 연출 (순차 표시 + 스킵)
-------------------------------------------------------
function GachaAnimation.PlayMulti(items, callback)
    -- 10연은 간략 연출: 바로 결과 카드 그리드 표시
    -- (추후 순차 캡슐 오픈 연출로 확장 가능)
    if callback then callback() end
end

-------------------------------------------------------
-- 파티클 효과 (프레임 기반)
-------------------------------------------------------
function GachaAnimation._spawnParticles(parent, color, count)
    for i = 1, count do
        local particle = Instance.new("Frame")
        particle.Size = UDim2.new(0, math.random(4, 10), 0, math.random(4, 10))
        particle.Position = UDim2.new(0.5, math.random(-20, 20), 0.5, math.random(-20, 20))
        particle.BackgroundColor3 = color
        particle.ZIndex = 8
        particle.Parent = parent

        local pCorner = Instance.new("UICorner")
        pCorner.CornerRadius = UDim.new(0.5, 0)
        pCorner.Parent = particle

        local targetX = math.random(-200, 200)
        local targetY = math.random(-200, 200)

        local tween = TweenService:Create(particle, TweenInfo.new(0.6 + math.random() * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, targetX, 0.5, targetY),
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 2, 0, 2),
        })
        tween:Play()
        tween.Completed:Connect(function()
            particle:Destroy()
        end)
    end
end

return GachaAnimation
