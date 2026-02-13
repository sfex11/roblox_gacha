--[[
    UGCProceduralBuilder.lua
    런타임에서 "그럴듯한" UGC 액세서리를 절차적으로 생성합니다.

    목표:
    - 외부 Mesh/Asset 없이도(=FBX Import 없이도) 보기 좋은 액세서리 생성
    - LLM(모델링 스펙)의 shape/style/motifs/vfx 힌트를 사용
    - templateId 기반 seed로 동일 아이템은 동일한 형태 유지
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Modules.Constants)

local UGCProceduralBuilder = {}

local function clampNumber(value, minValue, maxValue, fallback)
    if type(value) ~= "number" then
        return fallback
    end
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function hashToSeed(str)
    if type(str) ~= "string" then
        return 1
    end
    local hash = 0
    for i = 1, #str do
        hash = (hash * 31 + string.byte(str, i)) % 2147483647
    end
    if hash <= 0 then
        hash = 1
    end
    return hash
end

local function hexToColor3(hex, fallback)
    fallback = fallback or Color3.fromRGB(200, 200, 200)
    if type(hex) ~= "string" then
        return fallback
    end

    local cleaned = hex:gsub("#", "")
    if #cleaned ~= 6 then
        return fallback
    end

    local r = tonumber(cleaned:sub(1, 2), 16)
    local g = tonumber(cleaned:sub(3, 4), 16)
    local b = tonumber(cleaned:sub(5, 6), 16)
    if not r or not g or not b then
        return fallback
    end

    return Color3.fromRGB(r, g, b)
end

local function adjustColor(color, amount)
    local r = math.clamp(color.R + amount, 0, 1)
    local g = math.clamp(color.G + amount, 0, 1)
    local b = math.clamp(color.B + amount, 0, 1)
    return Color3.new(r, g, b)
end

local STYLE_MATERIAL_MAP = {
    matte = Enum.Material.SmoothPlastic,
    glossy = Enum.Material.SmoothPlastic,
    metallic = Enum.Material.Metal,
    emissive = Enum.Material.Neon,
    glass = Enum.Material.Glass,
}

local function getMaterial(styleMaterial)
    if type(styleMaterial) ~= "string" then
        return Enum.Material.SmoothPlastic
    end
    return STYLE_MATERIAL_MAP[string.lower(styleMaterial)] or Enum.Material.SmoothPlastic
end

local function normalizeMotifs(spec)
    local motifs = {}

    if spec and type(spec.motifs) == "table" then
        for _, m in ipairs(spec.motifs) do
            if type(m) == "string" then
                table.insert(motifs, string.lower(m))
            end
        end
    end

    local prompt = ""
    if spec and type(spec.prompt) == "string" then
        prompt = spec.prompt
    elseif spec and type(spec.name) == "string" then
        prompt = spec.name
    end
    local p = string.lower(prompt)

    local function addIfMatch(keyword, motif)
        if string.find(p, keyword, 1, true) then
            table.insert(motifs, motif)
        end
    end

    -- 한/영 키워드 기반 힌트
    addIfMatch("고양이", "cat_ears")
    addIfMatch("cat", "cat_ears")
    addIfMatch("왕관", "crown")
    addIfMatch("crown", "crown")
    addIfMatch("헬멧", "helmet")
    addIfMatch("helmet", "helmet")
    addIfMatch("날개", "wings")
    addIfMatch("wing", "wings")
    addIfMatch("사이버", "cyber")
    addIfMatch("cyber", "cyber")
    addIfMatch("우주", "space")
    addIfMatch("space", "space")
    addIfMatch("불", "embers")
    addIfMatch("fire", "embers")
    addIfMatch("번개", "lightning")
    addIfMatch("lightning", "lightning")

    -- 중복 제거
    local uniq = {}
    local out = {}
    for _, m in ipairs(motifs) do
        if not uniq[m] then
            uniq[m] = true
            table.insert(out, m)
        end
    end

    return out
end

local function rarityToDetailCount(rarity)
    if rarity == Constants.Rarity.Common then return 1 end
    if rarity == Constants.Rarity.Rare then return 3 end
    if rarity == Constants.Rarity.Epic then return 5 end
    if rarity == Constants.Rarity.Legendary then return 7 end
    if rarity == Constants.Rarity.Mythic then return 9 end
    return 3
end

local function setCommonPartProps(part)
    part.Anchored = false
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Massless = true
    part.CastShadow = false
end

local function createWeld(handle, part)
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = handle
    weld.Part1 = part
    weld.Parent = part
    return weld
end

local function makePart(params)
    local className = params.className or "Part"
    local part = Instance.new(className)
    part.Name = params.name or className
    part.Size = params.size or Vector3.new(1, 1, 1)
    part.Color = params.color or Color3.fromRGB(220, 220, 220)
    part.Material = params.material or Enum.Material.SmoothPlastic
    part.Transparency = params.transparency or 0
    part.Reflectance = params.reflectance or 0
    setCommonPartProps(part)

    if params.meshType then
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = params.meshType
        mesh.Scale = params.meshScale or Vector3.new(1, 1, 1)
        mesh.Parent = part
    end

    return part
end

local function placeWelded(accessory, handle, part, offset, rotation)
    offset = offset or Vector3.new()
    rotation = rotation or Vector3.new()
    part.CFrame = handle.CFrame * CFrame.new(offset)
        * CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
    part.Parent = accessory
    createWeld(handle, part)
    return part
end

local function applyVfx(handle, rarity, accentColor, motifs)
    if rarity == Constants.Rarity.Common or rarity == Constants.Rarity.Rare then
        return
    end

    local light = Instance.new("PointLight")
    light.Color = accentColor
    light.Range = 10
    light.Brightness = rarity == Constants.Rarity.Epic and 1.2
        or rarity == Constants.Rarity.Legendary and 1.8
        or 2.4
    light.Parent = handle

    local spark = Instance.new("Sparkles")
    spark.SparkleColor = accentColor
    spark.Parent = handle

    if table.find(motifs, "embers") then
        local fire = Instance.new("Fire")
        fire.Color = accentColor
        fire.SecondaryColor = adjustColor(accentColor, -0.25)
        fire.Heat = 6
        fire.Size = rarity == Constants.Rarity.Mythic and 3 or 2
        fire.Parent = handle
    end
end

local function buildHat(accessory, handle, palette, dims, motifs, detailCount, rng, baseGeometry)
    local primary = palette.primary
    local secondary = palette.secondary
    local accent = palette.accent
    local material = palette.material

    -- base cap
    local capHeight = clampNumber(dims.height, 0.4, 1.8, 1.0)
    local capWidth = clampNumber(dims.width, 0.7, 2.4, 1.4)
    local capDepth = clampNumber(dims.depth, 0.7, 2.4, 1.4)

    baseGeometry = type(baseGeometry) == "string" and string.lower(baseGeometry) or "cylinder"

    local capParams = {
        name = "Cap",
        color = primary,
        material = material,
        reflectance = material == Enum.Material.Metal and 0.15 or 0,
    }

    local capEffectiveHeight = capHeight
    if baseGeometry == "sphere" then
        capParams.size = Vector3.new(1, 1, 1)
        capParams.meshType = Enum.MeshType.Sphere
        capParams.meshScale = Vector3.new(capWidth, capHeight, capDepth)
    elseif baseGeometry == "cube" or baseGeometry == "custom" then
        capParams.size = Vector3.new(capWidth, capHeight, capDepth)
        capEffectiveHeight = capParams.size.Y
    elseif baseGeometry == "plane" then
        capParams.size = Vector3.new(capWidth, math.max(0.12, capHeight * 0.22), capDepth)
        capEffectiveHeight = capParams.size.Y
    else
        capParams.size = Vector3.new(1, 1, 1)
        capParams.meshType = Enum.MeshType.Cylinder
        capParams.meshScale = Vector3.new(capWidth, capHeight, capDepth)
    end

    local cap = makePart(capParams)

    local capOffsetY = (capEffectiveHeight / 2) - 0.1
    placeWelded(accessory, handle, cap, Vector3.new(0, capOffsetY, 0), Vector3.new(0, 0, 0))

    -- brim
    if detailCount >= 2 then
        local brim = makePart({
            name = "Brim",
            size = Vector3.new(1, 1, 1),
            color = secondary,
            material = material,
            meshType = Enum.MeshType.Cylinder,
            meshScale = Vector3.new(capWidth * 1.35, math.max(0.12, capHeight * 0.18), capDepth * 1.35),
            reflectance = 0,
        })

        local brimOffsetY = -0.08
        placeWelded(accessory, handle, brim, Vector3.new(0, brimOffsetY, 0), Vector3.new(0, 0, 0))
    end

    -- jewel / topper
    if detailCount >= 3 then
        local jewel = makePart({
            name = "Jewel",
            size = Vector3.new(0.2, 0.2, 0.2),
            color = accent,
            material = Enum.Material.Neon,
            meshType = Enum.MeshType.Sphere,
            meshScale = Vector3.new(0.35, 0.35, 0.35),
        })
        placeWelded(accessory, handle, jewel, Vector3.new(0, capOffsetY + capHeight / 2 + 0.18, 0), Vector3.new(0, 0, 0))
    end

    -- motifs: ears / crown spikes / antenna
    local hasCatEars = table.find(motifs, "cat_ears") ~= nil
    local hasCrown = table.find(motifs, "crown") ~= nil
    local hasHelmet = table.find(motifs, "helmet") ~= nil
    local hasSpace = table.find(motifs, "space") ~= nil

    if hasHelmet and detailCount >= 2 then
        local visor = makePart({
            name = "Visor",
            size = Vector3.new(0.9, 0.25, 0.35),
            color = adjustColor(secondary, -0.08),
            material = Enum.Material.Glass,
            transparency = 0.25,
            reflectance = 0.05,
        })
        placeWelded(accessory, handle, visor, Vector3.new(0, capOffsetY + 0.05, -capDepth * 0.35), Vector3.new(0, 0, 0))
    end

    if hasCatEars and detailCount >= 3 then
        for _, sx in ipairs({ -1, 1 }) do
            local ear = Instance.new("WedgePart")
            ear.Name = sx == -1 and "EarL" or "EarR"
            ear.Size = Vector3.new(0.28, 0.38, 0.28)
            ear.Color = secondary
            ear.Material = material
            setCommonPartProps(ear)
            placeWelded(accessory, handle, ear, Vector3.new(0.28 * sx, capOffsetY + capHeight / 2 + 0.16, 0), Vector3.new(0, 0, sx == -1 and 12 or -12))

            if detailCount >= 5 then
                local inner = Instance.new("WedgePart")
                inner.Name = ear.Name .. "_Inner"
                inner.Size = Vector3.new(0.18, 0.26, 0.18)
                inner.Color = accent
                inner.Material = Enum.Material.Neon
                setCommonPartProps(inner)
                placeWelded(accessory, handle, inner, Vector3.new(0.28 * sx, capOffsetY + capHeight / 2 + 0.14, 0.04), Vector3.new(0, 0, sx == -1 and 12 or -12))
            end
        end
    elseif hasCrown and detailCount >= 4 then
        local ring = makePart({
            name = "CrownRing",
            size = Vector3.new(1, 0.2, 1),
            color = secondary,
            material = Enum.Material.Metal,
            reflectance = 0.1,
        })
        placeWelded(accessory, handle, ring, Vector3.new(0, capOffsetY + capHeight * 0.1, 0), Vector3.new(0, 0, 0))

        local spikeCount = math.clamp(math.floor(3 + detailCount / 2), 4, 8)
        for i = 1, spikeCount do
            local angle = (i / spikeCount) * math.pi * 2
            local radius = math.max(0.45, capWidth * 0.45)
            local x = math.cos(angle) * radius
            local z = math.sin(angle) * radius

            local spike = Instance.new("WedgePart")
            spike.Name = "Spike_" .. tostring(i)
            spike.Size = Vector3.new(0.18, 0.35, 0.18)
            spike.Color = accent
            spike.Material = Enum.Material.Neon
            setCommonPartProps(spike)
            placeWelded(accessory, handle, spike, Vector3.new(x, capOffsetY + capHeight / 2 + 0.1, z), Vector3.new(0, math.deg(angle), 0))
        end
    else
        -- generic spikes for higher rarities
        if detailCount >= 6 then
            local spikes = 2 + rng:NextInteger(1, 3)
            for i = 1, spikes do
                local sx = rng:NextNumber(-0.5, 0.5)
                local sz = rng:NextNumber(-0.4, 0.4)
                local spike = Instance.new("WedgePart")
                spike.Name = "SpikeG_" .. tostring(i)
                spike.Size = Vector3.new(0.16, 0.3, 0.16)
                spike.Color = accent
                spike.Material = Enum.Material.Neon
                setCommonPartProps(spike)
                placeWelded(accessory, handle, spike, Vector3.new(sx, capOffsetY + capHeight / 2 + 0.12, sz), Vector3.new(0, rng:NextNumber(0, 360), 0))
            end
        end
    end

    if hasSpace and detailCount >= 4 then
        local antenna = makePart({
            name = "Antenna",
            size = Vector3.new(0.12, 0.6, 0.12),
            color = secondary,
            material = Enum.Material.Metal,
            reflectance = 0.12,
        })
        placeWelded(accessory, handle, antenna, Vector3.new(0, capOffsetY + capHeight / 2 + 0.3, 0.05), Vector3.new(0, 0, 0))

        local tip = makePart({
            name = "AntennaTip",
            size = Vector3.new(0.2, 0.2, 0.2),
            color = accent,
            material = Enum.Material.Neon,
            meshType = Enum.MeshType.Sphere,
            meshScale = Vector3.new(0.22, 0.22, 0.22),
        })
        placeWelded(accessory, handle, tip, Vector3.new(0, capOffsetY + capHeight / 2 + 0.65, 0.05), Vector3.new(0, 0, 0))
    end
end

local function buildBack(accessory, handle, palette, dims, motifs, detailCount, rng)
    local primary = palette.primary
    local secondary = palette.secondary
    local accent = palette.accent
    local material = palette.material

    local w = clampNumber(dims.width, 0.8, 2.8, 1.4)
    local h = clampNumber(dims.height, 0.8, 2.8, 1.6)
    local d = clampNumber(dims.depth, 0.4, 2.2, 0.8)

    local offsetZ = (d / 2) + 0.35

    local pack = makePart({
        name = "BackCore",
        size = Vector3.new(w, h, d),
        color = primary,
        material = material,
        reflectance = material == Enum.Material.Metal and 0.12 or 0,
    })
    placeWelded(accessory, handle, pack, Vector3.new(0, 0.15, offsetZ), Vector3.new(0, 0, 0))

    local hasWings = table.find(motifs, "wings") ~= nil
    local hasCyber = table.find(motifs, "cyber") ~= nil

    if hasWings and detailCount >= 3 then
        for _, sx in ipairs({ -1, 1 }) do
            local wing = Instance.new("WedgePart")
            wing.Name = sx == -1 and "WingL" or "WingR"
            wing.Size = Vector3.new(0.25, h * 0.95, w * 1.2)
            wing.Color = secondary
            wing.Material = material
            setCommonPartProps(wing)
            placeWelded(accessory, handle, wing, Vector3.new((w * 0.55) * sx, 0.2, offsetZ + 0.1), Vector3.new(0, 0, sx == -1 and 18 or -18))

            if detailCount >= 6 then
                local edge = makePart({
                    name = wing.Name .. "_Edge",
                    size = Vector3.new(0.12, h * 0.9, w * 1.1),
                    color = accent,
                    material = Enum.Material.Neon,
                })
                placeWelded(accessory, handle, edge, Vector3.new((w * 0.68) * sx, 0.2, offsetZ + 0.12), Vector3.new(0, 0, sx == -1 and 18 or -18))
            end
        end
    end

    if hasCyber and detailCount >= 4 then
        local stripeCount = 2 + rng:NextInteger(0, 2)
        for i = 1, stripeCount do
            local stripe = makePart({
                name = "CyberStripe_" .. tostring(i),
                size = Vector3.new(w * 0.85, 0.08, 0.08),
                color = accent,
                material = Enum.Material.Neon,
            })
            local y = -h * 0.2 + (i - 1) * 0.25
            placeWelded(accessory, handle, stripe, Vector3.new(0, y, offsetZ + d * 0.52), Vector3.new(0, 0, 0))
        end
    end
end

local function buildFace(accessory, handle, palette, dims, _motifs, detailCount, _rng)
    local primary = palette.primary
    local secondary = palette.secondary
    local accent = palette.accent

    local w = clampNumber(dims.width, 0.6, 2.2, 1.4)
    local h = clampNumber(dims.height, 0.2, 1.4, 0.35)
    local d = clampNumber(dims.depth, 0.2, 1.4, 0.25)

    local offsetZ = -(d / 2) - 0.55

    -- simple "glasses"
    local left = makePart({
        name = "LensL",
        size = Vector3.new(0.45, 0.32, d),
        color = primary,
        material = Enum.Material.Glass,
        transparency = 0.25,
        reflectance = 0.05,
    })
    placeWelded(accessory, handle, left, Vector3.new(-w * 0.22, 0.1, offsetZ), Vector3.new(0, 0, 0))

    local right = makePart({
        name = "LensR",
        size = Vector3.new(0.45, 0.32, d),
        color = primary,
        material = Enum.Material.Glass,
        transparency = 0.25,
        reflectance = 0.05,
    })
    placeWelded(accessory, handle, right, Vector3.new(w * 0.22, 0.1, offsetZ), Vector3.new(0, 0, 0))

    local bridge = makePart({
        name = "Bridge",
        size = Vector3.new(0.18, 0.08, d * 0.9),
        color = secondary,
        material = Enum.Material.Metal,
        reflectance = 0.08,
    })
    placeWelded(accessory, handle, bridge, Vector3.new(0, 0.1, offsetZ), Vector3.new(0, 0, 0))

    if detailCount >= 5 then
        local badge = makePart({
            name = "Badge",
            size = Vector3.new(0.16, 0.16, 0.16),
            color = accent,
            material = Enum.Material.Neon,
            meshType = Enum.MeshType.Sphere,
            meshScale = Vector3.new(0.2, 0.2, 0.2),
        })
        placeWelded(accessory, handle, badge, Vector3.new(w * 0.52, 0.08, offsetZ + 0.02), Vector3.new(0, 0, 0))
    end
end

local function buildWaist(accessory, handle, palette, dims, _motifs, detailCount, rng)
    local primary = palette.primary
    local secondary = palette.secondary
    local accent = palette.accent
    local material = palette.material

    local beltW = clampNumber(dims.width, 1.2, 3.0, 2.0)
    local beltH = clampNumber(dims.height, 0.12, 0.5, 0.2)
    local beltD = clampNumber(dims.depth, 0.2, 1.4, 0.7)

    local offsetY = -(beltH / 2) - 0.55

    -- ring-ish: 4 segments
    local segmentSize = Vector3.new(beltW * 0.55, beltH, 0.18)
    for i, seg in ipairs({
        { name = "BeltF", offset = Vector3.new(0, offsetY, -(beltD / 2) - 0.1) },
        { name = "BeltB", offset = Vector3.new(0, offsetY, (beltD / 2) + 0.1) },
        { name = "BeltL", offset = Vector3.new(-(beltW / 2) - 0.1, offsetY, 0), rot = Vector3.new(0, 90, 0) },
        { name = "BeltR", offset = Vector3.new((beltW / 2) + 0.1, offsetY, 0), rot = Vector3.new(0, 90, 0) },
    }) do
        local part = makePart({
            name = seg.name,
            size = segmentSize,
            color = primary,
            material = material,
        })
        placeWelded(accessory, handle, part, seg.offset, seg.rot or Vector3.new())
    end

    if detailCount >= 3 then
        local buckle = makePart({
            name = "Buckle",
            size = Vector3.new(0.35, beltH * 1.15, 0.2),
            color = secondary,
            material = Enum.Material.Metal,
            reflectance = 0.12,
        })
        placeWelded(accessory, handle, buckle, Vector3.new(0, offsetY, -(beltD / 2) - 0.22), Vector3.new(0, 0, 0))
    end

    if detailCount >= 5 then
        local pouchCount = 1 + rng:NextInteger(0, 2)
        for i = 1, pouchCount do
            local pouch = makePart({
                name = "Pouch_" .. tostring(i),
                size = Vector3.new(0.28, 0.22, 0.18),
                color = accent,
                material = Enum.Material.SmoothPlastic,
            })
            placeWelded(accessory, handle, pouch, Vector3.new(rng:NextNumber(-0.5, 0.5), offsetY - 0.05, -(beltD / 2) - 0.32), Vector3.new(0, 0, 0))
        end
    end
end

local function buildShoulder(accessory, handle, palette, dims, _motifs, detailCount, rng)
    local primary = palette.primary
    local secondary = palette.secondary
    local accent = palette.accent
    local material = palette.material

    local w = clampNumber(dims.width, 0.5, 1.8, 1.0)
    local h = clampNumber(dims.height, 0.5, 1.8, 1.0)
    local d = clampNumber(dims.depth, 0.5, 1.8, 1.0)

    local offsetX = -0.75

    local pad = makePart({
        name = "Pad",
        size = Vector3.new(1, 1, 1),
        color = primary,
        material = material,
        meshType = Enum.MeshType.Sphere,
        meshScale = Vector3.new(w, h, d),
        reflectance = material == Enum.Material.Metal and 0.1 or 0,
    })
    placeWelded(accessory, handle, pad, Vector3.new(offsetX, 0.15, 0), Vector3.new(0, 0, 0))

    if detailCount >= 4 then
        local plate = makePart({
            name = "Plate",
            size = Vector3.new(w * 0.9, 0.12, d * 0.9),
            color = secondary,
            material = material,
        })
        placeWelded(accessory, handle, plate, Vector3.new(offsetX, -0.1, 0), Vector3.new(0, rng:NextNumber(0, 360), 0))
    end

    if detailCount >= 6 then
        local gem = makePart({
            name = "Gem",
            size = Vector3.new(0.2, 0.2, 0.2),
            color = accent,
            material = Enum.Material.Neon,
            meshType = Enum.MeshType.Sphere,
            meshScale = Vector3.new(0.22, 0.22, 0.22),
        })
        placeWelded(accessory, handle, gem, Vector3.new(offsetX + w * 0.35, 0.05, 0), Vector3.new(0, 0, 0))
    end
end

local function buildFront(accessory, handle, palette, dims, motifs, detailCount, rng)
    local primary = palette.primary
    local secondary = palette.secondary
    local accent = palette.accent
    local material = palette.material

    local w = clampNumber(dims.width, 0.6, 2.6, 1.2)
    local h = clampNumber(dims.height, 0.6, 2.6, 1.2)
    local d = clampNumber(dims.depth, 0.12, 1.2, 0.2)

    local offsetZ = -(d / 2) - 0.55

    local plate = makePart({
        name = "FrontPlate",
        size = Vector3.new(w, h, d),
        color = primary,
        material = material,
    })
    placeWelded(accessory, handle, plate, Vector3.new(0, 0.1, offsetZ), Vector3.new(0, 0, 0))

    if detailCount >= 3 then
        local emblem = makePart({
            name = "Emblem",
            size = Vector3.new(0.35, 0.35, 0.12),
            color = secondary,
            material = Enum.Material.Metal,
            reflectance = 0.12,
        })
        placeWelded(accessory, handle, emblem, Vector3.new(0, 0.15, offsetZ - 0.08), Vector3.new(0, 0, 0))
    end

    if detailCount >= 5 or table.find(motifs, "lightning") then
        local bolt = Instance.new("WedgePart")
        bolt.Name = "Bolt"
        bolt.Size = Vector3.new(0.18, 0.5, 0.18)
        bolt.Color = accent
        bolt.Material = Enum.Material.Neon
        setCommonPartProps(bolt)
        placeWelded(accessory, handle, bolt, Vector3.new(rng:NextNumber(-0.2, 0.2), 0.15, offsetZ - 0.12), Vector3.new(0, rng:NextNumber(-20, 20), 0))
    end
end

local function buildHair(accessory, handle, palette, dims, motifs, detailCount, rng)
    local primary = palette.primary
    local secondary = palette.secondary
    local accent = palette.accent
    local material = palette.material

    local strandCount = math.clamp(4 + detailCount, 6, 14)
    local w = clampNumber(dims.width, 0.8, 2.6, 1.6)
    local h = clampNumber(dims.height, 0.8, 2.6, 1.4)
    local d = clampNumber(dims.depth, 0.4, 2.0, 1.0)

    local baseOffsetY = (h / 2) - 0.15

    for i = 1, strandCount do
        local t = (i - 1) / math.max(1, strandCount - 1)
        local color = primary:Lerp(secondary, t * 0.6)
        if table.find(motifs, "cyber") and (i % 3 == 0) then
            color = accent
        end

        local strand = makePart({
            name = "Strand_" .. tostring(i),
            size = Vector3.new(0.12, 0.45 + rng:NextNumber(0.0, 0.35), 0.12),
            color = color,
            material = material,
        })

        local x = rng:NextNumber(-w * 0.35, w * 0.35)
        local z = rng:NextNumber(-d * 0.25, d * 0.25)
        local y = baseOffsetY + rng:NextNumber(-0.15, 0.15)
        local rot = Vector3.new(rng:NextNumber(-20, 20), rng:NextNumber(0, 360), rng:NextNumber(-20, 20))
        placeWelded(accessory, handle, strand, Vector3.new(x, y, z), rot)
    end

    if detailCount >= 6 then
        local pin = makePart({
            name = "HairPin",
            size = Vector3.new(0.5, 0.08, 0.12),
            color = accent,
            material = Enum.Material.Neon,
        })
        placeWelded(accessory, handle, pin, Vector3.new(0, baseOffsetY - 0.2, -d * 0.3), Vector3.new(0, 0, 0))
    end
end

local function resolveDims(spec)
    local shape = spec and spec.shape
    local dimensions = shape and shape.dimensions
    local width = clampNumber(dimensions and dimensions.width, 0.2, 4, 1.2)
    local height = clampNumber(dimensions and dimensions.height, 0.2, 4, 1.2)
    local depth = clampNumber(dimensions and dimensions.depth, 0.2, 4, 1.2)
    return { width = width, height = height, depth = depth }
end

local function resolveBaseGeometry(spec)
    local shape = spec and spec.shape
    local geo = shape and shape.baseGeometry
    if type(geo) ~= "string" or geo == "" then
        return "cylinder"
    end
    return string.lower(geo)
end

local function resolvePalette(rarityColor, spec, rng)
    local style = spec and spec.style or {}

    local primary = hexToColor3(style.primaryColor, rarityColor)
    local secondary = hexToColor3(style.secondaryColor, adjustColor(primary, 0.18))
    local accent = hexToColor3(style.accentColor, adjustColor(primary, -0.12))

    -- 대비가 너무 약하면 accent를 더 튀게 조정
    if math.abs(primary.R - accent.R) + math.abs(primary.G - accent.G) + math.abs(primary.B - accent.B) < 0.35 then
        accent = Color3.fromHSV(rng:NextNumber(), 0.85, 1.0)
    end

    return {
        primary = primary,
        secondary = secondary,
        accent = accent,
        material = getMaterial(style.material),
    }
end

local ACCESSORY_TYPE_MAP = {
    [Constants.UGCType.Hat] = Enum.AccessoryType.Hat,
    [Constants.UGCType.Hair] = Enum.AccessoryType.Hair,
    [Constants.UGCType.Face] = Enum.AccessoryType.Face,
    [Constants.UGCType.Back] = Enum.AccessoryType.Back,
    [Constants.UGCType.Front] = Enum.AccessoryType.Front,
    [Constants.UGCType.Shoulder] = Enum.AccessoryType.Shoulder,
    [Constants.UGCType.Waist] = Enum.AccessoryType.Waist,
}

--[[
    절차적 액세서리 생성
    @param templateId string
    @param ugcItem table  -- UGCDatabase item
    @param attachmentName string
    @param rarityColor Color3
    @return Accessory
]]
function UGCProceduralBuilder.BuildAccessory(templateId, ugcItem, attachmentName, rarityColor)
    local visualSpec = ugcItem and ugcItem.visualSpec or nil
    local ugcType = ugcItem and ugcItem.ugcType or Constants.UGCType.Hat
    local rarity = ugcItem and ugcItem.rarity or Constants.Rarity.Rare

    local seed = (visualSpec and type(visualSpec.seed) == "number") and math.floor(visualSpec.seed) or hashToSeed(templateId)
    local rng = Random.new(seed)

    local dims = resolveDims(visualSpec)
    local baseGeometry = resolveBaseGeometry(visualSpec)
    local palette = resolvePalette(rarityColor, visualSpec, rng)
    local motifs = normalizeMotifs(visualSpec)
    local detailCount = rarityToDetailCount(rarity)

    local accessory = Instance.new("Accessory")
    accessory.Name = ugcItem and ugcItem.name or templateId
    accessory.AccessoryType = ACCESSORY_TYPE_MAP[ugcType] or Enum.AccessoryType.Hat

    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.2, 0.2, 0.2)
    handle.Transparency = 1
    handle.Color = palette.primary
    handle.Material = Enum.Material.SmoothPlastic
    setCommonPartProps(handle)
    handle.Parent = accessory

    local attachment = Instance.new("Attachment")
    attachment.Name = attachmentName
    attachment.Parent = handle

    if ugcType == Constants.UGCType.Hat then
        buildHat(accessory, handle, palette, dims, motifs, detailCount, rng, baseGeometry)
    elseif ugcType == Constants.UGCType.Back then
        buildBack(accessory, handle, palette, dims, motifs, detailCount, rng)
    elseif ugcType == Constants.UGCType.Face then
        buildFace(accessory, handle, palette, dims, motifs, detailCount, rng)
    elseif ugcType == Constants.UGCType.Waist then
        buildWaist(accessory, handle, palette, dims, motifs, detailCount, rng)
    elseif ugcType == Constants.UGCType.Shoulder then
        buildShoulder(accessory, handle, palette, dims, motifs, detailCount, rng)
    elseif ugcType == Constants.UGCType.Front then
        buildFront(accessory, handle, palette, dims, motifs, detailCount, rng)
    elseif ugcType == Constants.UGCType.Hair then
        buildHair(accessory, handle, palette, dims, motifs, detailCount, rng)
    else
        buildHat(accessory, handle, palette, dims, motifs, detailCount, rng, baseGeometry)
    end

    applyVfx(handle, rarity, palette.accent, motifs)

    accessory:SetAttribute("UGC_TemplateId", templateId)
    accessory:SetAttribute("UGC_Type", ugcType)
    accessory:SetAttribute("UGC_Rarity", rarity)
    accessory:SetAttribute("UGC_Seed", seed)

    return accessory
end

return UGCProceduralBuilder
