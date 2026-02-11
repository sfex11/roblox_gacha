/**
 * Modeling API — 3D 모델링 가이드 생성 엔드포인트
 *
 * GLM-4.7으로 Blender가 해석할 수 있는 구조화된 모델링 스펙 생성
 */

const express = require("express");
const router = express.Router();
const path = require("path");
const { generateModelingGuide } = require("../services/blenderService");

// ─── 모델링 가이드 생성 ─────────────────────────────────────
router.post("/guide", async (req, res) => {
    console.log("[modeling.js] /api/modeling/guide 요청:", req.body);

    const {
        templateId,
        rarity,
        category,
        prompt,
        theme = "default",
        attachmentPoint,
    } = req.body;

    // 필수 파라미터 검증
    if (!prompt && !templateId) {
        return res.status(400).json({
            success: false,
            error: "missing_params",
            required: ["prompt 또는 templateId"],
        });
    }

    try {
        const result = await generateModelingGuide({
            templateId,
            rarity,
            category,
            prompt,
            theme,
            attachmentPoint,
        });

        console.log("[modeling.js] 가이드 생성 성공:", result.name);
        res.json({
            success: true,
            data: result,
        });
    } catch (error) {
        console.error("[modeling.js] 가이드 생성 실패:", error.message);
        res.status(500).json({
            success: false,
            error: error.message,
        });
    }
});

// ─── 스펙에서 Blender 명령어 생성 ────────────────────────────
router.post("/commands", async (req, res) => {
    console.log("[modeling.js] /api/modeling/commands 요청:", req.body);

    const { spec } = req.body;

    if (!spec) {
        return res.status(400).json({
            success: false,
            error: "missing_spec",
        });
    }

    // Blender Python 스크립트 생성
    const blenderService = require("../services/blenderService");
    const commands = blenderService.generateBlenderCommands(spec);

    res.json({
        success: true,
        commands: commands,
    });
});

// ─── FBX 모델 생성 (Blender 실행) + Studio Lua 스크립트 ─────────
router.post("/generate", async (req, res) => {
    console.log("[modeling.js] /api/modeling/generate 요청:", req.body);

    const {
        prompt,
        rarity,
        category,
        theme,
        attachmentPoint,
    } = req.body;

    if (!prompt) {
        return res.status(400).json({
            success: false,
            error: "missing_prompt",
        });
    }

    try {
        const blenderService = require("../services/blenderService");

        // 1. 모델링 가이드 생성
        const spec = await blenderService.generateModelingGuide({
            prompt,
            rarity,
            category,
            theme,
            attachmentPoint,
        });

        console.log("[modeling.js] 스펙 생성 완료, Blender 실행...");

        // 2. Blender 실행으로 FBX 생성
        const fbxPath = await blenderService.generateModel(spec);

        // 3. 결과 반환
        const filename = path.basename(fbxPath);
        const downloadUrl = blenderService.getFbxUrl(filename);

        // 4. Studio에서 사용할 Lua 스크립트 생성
        const studioLuaScript = generateStudioLuaScript(spec, filename);

        res.json({
            success: true,
            spec: spec,
            fbxPath: fbxPath,
            filename: filename,
            downloadUrl: downloadUrl,
            studioLuaScript: studioLuaScript,
            importInstructions: getImportInstructions(filename),
        });

    } catch (error) {
        console.error("[modeling.js] 모델 생성 실패:", error.message);
        res.status(500).json({
            success: false,
            error: error.message,
        });
    }
});

// ─── Studio Import Lua 스크립트 생성 ─────────────────────────────
function generateStudioLuaScript(spec, filename) {
    // 색상값 변환 (HEX to Color3)
    const hexToColor3 = (hex) => {
        const r = parseInt(hex.slice(1, 3), 16) / 255;
        const g = parseInt(hex.slice(3, 5), 16) / 255;
        const b = parseInt(hex.slice(5, 7), 16) / 255;
        return `Color3.new(${r.toFixed(3)}, ${g.toFixed(3)}, ${b.toFixed(3)})`;
    };

    const primaryColor = hexToColor3(spec.style?.primaryColor || "#4a90d9");
    const secondaryColor = hexToColor3(spec.style?.secondaryColor || "#ffffff");

    return `--[[
    🎨 UGC 아이템 자동 설정 스크립트
    생성된 FBX를 Import 후 실행하세요

    사용법:
    1. Avatar → Import 3D로 FBX Import
    2. Import된 모델 선택
    3. 이 스크립트 실행 (Command Bar 또는 스크립트 에디터)
]]

local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- ─── 아이템 데이터 ────────────────────────────────────────────────────
local itemData = {
    name = "${spec.name}",
    description = "${spec.description}",
    productId = "${filename}",
    attachmentPoint = "${(spec.attachmentPoint || "HatAttachment")}",
    rarity = "${spec.rarity || "Common"}",
    category = "${spec.category || "Hat"}",
    colors = {
        primary = ${primaryColor},
        secondary = ${secondaryColor},
    }
}

print("═══════════════════════════════════════════════════════")
print("🎨 UGC 아이템 자동 설정")
print("═══════════════════════════════════════════════════════")
print("이름:", itemData.name)
print("설명:", itemData.description)
print("카테고리:", itemData.category)
print("희귀도:", itemData.rarity)
print("Attachment:", itemData.attachmentPoint)
print("═══════════════════════════════════════════════════════")

-- ─── 선택된 모델 확인 ───────────────────────────────────────────────
local selection = game.Selection:Get()
if #selection == 0 then
    warn("⚠️ Import된 모델을 선택한 후 이 스크립트를 실행하세요")
    return nil
end

local model = selection[1]
print("✅ 선택된 모델:", model.Name)

-- ─── 모델 이름 변경 ─────────────────────────────────────────────────
local oldName = model.Name
model.Name = itemData.name
print("✅ 이름 변경:", oldName, "→", model.Name)

-- ─── 메타데이터 설정 (Attributes) ────────────────────────────────────
-- Roblox Studio에서 사용할 메타데이터
model:SetAttribute("UGC_ItemName", itemData.name)
model:SetAttribute("UGC_Description", itemData.description)
model:SetAttribute("UGC_Rarity", itemData.rarity)
model:SetAttribute("UGC_Category", itemData.category)
model:SetAttribute("UGC_AttachmentPoint", itemData.attachmentPoint)
model:SetAttribute("UGC_ProductId", itemData.productId)

print("✅ 메타데이터 설정 완료")

-- ─── MeshPart 색상 적용 (선택 사항) ─────────────────────────────────
local function applyColorsToMesh(object, colors)
    if object:IsA("MeshPart") or object:IsA("Part") then
        if object.Color == Color3.new(1, 1, 1) then -- 흰색인 경우만
            object.Color = colors.primary
            print("  └─ 색상 적용:", object.Name, object.Color)
        end
    end
    for _, child in ipairs(object:GetChildren()) do
        applyColorsToMesh(child, colors)
    end
end

print("✅ MeshPart 색상 적용 중...")
applyColorsToMesh(model, itemData.colors)

-- ─── Accessory 제작 가이드 출력 ────────────────────────────────────────
print(" ")
print("═══════════════════════════════════════════════════════")
print("📋 다음 단계:")
print("═══════════════════════════════════════════════════════")
print("1. Plugin 탭 → Accessory Fitting Tool 실행")
print("2. Attachment Point 선택:", itemData.attachmentPoint)
print("3. 'Create' 클릭하여 Accessory 생성")
print("4. 생성된 Accessory의 속성을 확인하세요")
print("═══════════════════════════════════════════════════════")

-- 변경 사항 기록
ChangeHistoryService:SetWaypoint("UGC Auto-Setup: " .. itemData.name)

return itemData
`;
}

// ─── Import 가이드 생성 ─────────────────────────────────────────
function getImportInstructions(filename) {
    return {
        step1: "1. Roblox Studio 열기",
        step2: "2. Avatar 탭 → Import 3D 클릭",
        step3: `3. 파일 선택: ${filename}`,
        step4: "4. Import 후 Accessory Fitting Tool 실행",
        step5: "5. 위 Lua 스크립트로 메타데이터 설정",
        fbxPath: `/Users/chulhyunhwang/Documents/zenflow/roblox_gacha/backend/exports/ugc/${filename}`,
    };
}

// ─── UGC 아이템 목록 조회 (생성된 FBX 파일들) ─────────────────────
router.get("/ugc-files", (req, res) => {
    const fs = require("fs");
    const exportsDir = path.join(__dirname, "../../exports/ugc");

    try {
        if (!fs.existsSync(exportsDir)) {
            return res.json({
                success: true,
                files: [],
                count: 0,
            });
        }

        const files = fs.readdirSync(exportsDir)
            .filter(f => f.endsWith(".fbx"))
            .map(f => ({
                filename: f,
                path: path.join(exportsDir, f),
                url: `/exports/ugc/${f}`,
            }));

        res.json({
            success: true,
            files: files,
            count: files.length,
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message,
        });
    }
});

// ─── Studio에 UGC 아이템 등록 (MCP 통해) ───────────────────────────
router.post("/register-to-gacha", async (req, res) => {
    console.log("[modeling.js] /api/modeling/register-to-gacha 요청:", req.body);

    const { spec } = req.body;

    if (!spec) {
        return res.status(400).json({
            success: false,
            error: "missing_spec",
        });
    }

    try {
        // Studio MCP 클라이언트
        const { getClient } = require("../services/StudioTcpClient");
        const client = getClient({ debug: true });

        // 연결 확인
        const status = await client.getStatus();
        if (!status.connected) {
            return res.status(503).json({
                success: false,
                error: "Studio not connected",
                hint: "Roblox Studio와 MCP Plugin이 실행 중인지 확인하세요",
            });
        }

        // UGCDatabase에 아이템 등록하는 Lua 코드 실행
        const luaCode = `
local UGCDatabase = require(game.ReplicatedStorage.Modules.UGCDatabase)
local GachaConfig = require(game.ReplicatedStorage.Modules.GachaConfig)

local templateId = UGCDatabase.RegisterItem({
    name = "${spec.name.replace(/"/g, '\\"')}",
    description = "${(spec.description || "").replace(/"/g, '\\"')}",
    flavorText = "${(spec.flavorText || "AI가 생성한 아이템").replace(/"/g, '\\"')}",
    rarity = "${spec.rarity || "Rare"}",
    ugcType = "${spec.category || "Hat"}",
    stats = {},
    weight = ${spec.weight || 100},
})

if templateId then
    GachaConfig.RefreshPool("standard_v1")
    print("[SUCCESS] UGC 등록 완료:", templateId)
else
    warn("[ERROR] UGC 등록 실패")
end
`;

        const result = await client.runCode(luaCode);

        res.json({
            success: true,
            result: result,
            spec: spec,
        });

    } catch (error) {
        console.error("[modeling.js] UGC 등록 실패:", error.message);
        res.status(500).json({
            success: false,
            error: error.message,
        });
    }
});

module.exports = router;
