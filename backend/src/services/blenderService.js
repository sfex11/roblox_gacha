/**
 * Blender Service — 3D 모델링 자동화 서비스
 *
 * 기능:
 * 1. GLM-4.7으로 모델링 가이드 생성
 * 2. Blender Python 스크립트 생성
 * 3. Blender 실행 및 FBX 내보내기 (향후 MCP 연동 시)
 */

const fs = require("fs").promises;
const path = require("path");
const { getGlmClient } = require("../llm");
const config = require("../config");

// ─── 설정 ───────────────────────────────────────────────────
const SCRIPTS_DIR = path.join(__dirname, "../../blender-scripts");
const EXPORTS_DIR = path.join(__dirname, "../../exports/ugc");

// 카테고리별 어태치먼트 매핑
const CATEGORY_ATTACHMENTS = {
    Hat: "HatAttachment",
    Hair: "HairAttachment",
    Front: "BodyFrontAttachment",
    Back: "BodyBackAttachment",
    Shoulder: "LeftShoulderAttachment",
    Waist: "WaistCenterAttachment",
    Face: "FaceFrontAttachment",
    Shirt: "Body",
    Pants: "Body",
    Shoes: "Body",
};

// ─── GLM-4.7 프롬프트 템플릿 ──────────────────────────────────
const MODELING_SYSTEM_PROMPT = `당신은 Roblox UGC 크리에이터를 위한 3D 모델링 가이드 전문가입니다.
Blender에서 직접 모델링할 수 있도록 구체적이고 기술적인 지시사항을 작성하세요.

**중요:**
- 폴리곤 수를 4000개 이하로 유지
- Roblox R15 아바타에 맞춰 크기 조절
- 명확한 단계별 지시사항 제공
- 한국어로 작성
- "보기 좋은 실루엣"을 우선: 단순한 박스/구 형태만 내지 말고, 레이어(겹침), 포인트(엑센트), 디테일(장식)을 포함
- style 색상 3개(Primary/Secondary/Accent)는 조화/대비가 느껴지게 선택
- Roblox 런타임에서 절차적으로 재구성할 수 있도록 motifs/vfx 힌트도 함께 제안`;

// ─── 모델링 가이드 생성 ───────────────────────────────────────
/**
 * GLM-4.7로 모델링 가이드 생성
 * @param {object} params
 * @param {string} params.prompt - 사용자 프롬프트 (예: "귀여운 고양이 귀")
 * @param {string} params.rarity - 희귀도 (Common/Rare/Epic/Legendary)
 * @param {string} params.category - 카테고리 (Hat/Hair/Back/Shoulder 등)
 * @param {string} params.theme - 테마 (default/cute/dark/cyber 등)
 * @param {string} params.attachmentPoint - 어태치먼트 포인트
 */
async function generateModelingGuide(params) {
    const {
        prompt,
        rarity = "Rare",
        category = "Hat",
        theme = "default",
        attachmentPoint,
        templateId,
    } = params;

    console.log("[blenderService] 모델링 가이드 생성 시작:", prompt);

    // 카테고리에서 어태치먼트 결정
    const finalAttachment = attachmentPoint || CATEGORY_ATTACHMENTS[category] || "HatAttachment";

    // GLM-4.7에 요청할 프롬프트 구성
    const userPrompt = `
다음 조건으로 Roblox UGC 아이템을 위한 3D 모델링 가이드를 작성하세요:

**요청:**
${prompt}

**사양:**
- 희귀도: ${rarity}
- 카테고리: ${category}
- 어태치먼트: ${finalAttachment}
- 테마: ${theme}

**출력 형식 (JSON만 출력):**
\`\`\`json
{
  "name": "아이템 이름",
  "category": "${category}",
  "attachmentPoint": "${finalAttachment}",
  "description": "시각적 설명 (2-3문장)",
  "rarity": "${rarity}",
  "motifs": ["cat_ears|crown|wings|helmet|antenna|runes|spikes|gems|ribbons|halo|visor|jetpack|cape"],
  "shape": {
    "baseGeometry": "cube|sphere|cylinder|cone|torus|plane|custom",
    "dimensions": {"width": 1.0, "height": 1.0, "depth": 1.0},
    "modifiers": ["subdivision", "bevel", "mirror", "solidify"]
  },
  "style": {
    "primaryColor": "#HEX",
    "secondaryColor": "#HEX",
    "accentColor": "#HEX",
    "material": "matte|glossy|metallic|emissive|glass",
    "textureType": "solid|gradient|pattern|none"
  },
  "vfx": {
    "glow": true,
    "glowColor": "#HEX",
    "sparkles": true,
    "intensity": 0.0
  },
  "seed": 12345,
  "blenderInstructions": [
    "1단계: 구체적인 Blender 조작 지시",
    "2단계: 구체적인 Blender 조작 지시",
    "3단계: 구체적인 Blender 조작 지시"
  ],
  "constraints": {
    "maxTriangles": ${rarity === "Legendary" ? 4000 : rarity === "Epic" ? 3000 : 2000},
    "maxSize": 4,
    "riggingRequired": ${category === "Shoulder" || category === "Back"}
  }
}
\`\`\`

**참고:**
- ${rarity === "Legendary" ? "전설급 아이템: 복잡한 디테일, 특수 효과 포함" :
  rarity === "Epic" ? "에픽 아이템: 독특한 형태, 강렬한 색상" :
  rarity === "Rare" ? "레어 아이템: 개성적인 디자인, 꽤 복잡함" :
  "커먼 아이템: 간단한 형태, 깔끔함"}
- 폴리곤 제한 준수
- Blender 4.x 버전 호환
`;

    try {
        const client = getGlmClient();

        console.log("[blenderService] GLM API 호출...");

        // 타임아웃 래퍼 (5분)
        const timeoutPromise = new Promise((_, reject) =>
            setTimeout(() => reject(new Error("GLM API timeout")), 300000)
        );

        const apiCall = client.chat.completions.create({
            model: config.llm.glmModel,
            messages: [
                { role: "system", content: MODELING_SYSTEM_PROMPT },
                { role: "user", content: userPrompt },
            ],
            max_completion_tokens: 2000,
            temperature: 0.7,
        });

        const response = await Promise.race([apiCall, timeoutPromise]);

        const message = response.choices[0]?.message || {};
        const text = message.reasoning_content || message.content || "";
        console.log("[blenderService] GLM 응답 길이:", text.length);

        // JSON 추출
        const jsonMatch = text.match(/\{[\s\S]*\}/);
        if (!jsonMatch) {
            throw new Error("JSON 파싱 실패");
        }

        const spec = JSON.parse(jsonMatch[0]);

        // 검증
        if (!spec.name || !spec.shape || !spec.blenderInstructions) {
            throw new Error("필수 필드 누락");
        }

        console.log("[blenderService] 가이드 생성 성공:", spec.name);
        return spec;

    } catch (error) {
        console.error("[blenderService] GLM 호출 실패:", error.message);

        // 폴백: 기본 스펙 반환
        return {
            name: prompt?.split(" ").slice(0, 3).join(" ") || "기본 아이템",
            category: category,
            attachmentPoint: finalAttachment,
            description: prompt || "기본 UGC 아이템",
            rarity: rarity,
            motifs: ["gems"],
            shape: {
                baseGeometry: "cube",
                dimensions: { width: 1, height: 1, depth: 1 },
                modifiers: ["subdivision"],
            },
            style: {
                primaryColor: "#4a90d9",
                secondaryColor: "#ffffff",
                accentColor: "#ffd700",
                material: "glossy",
                textureType: "solid",
            },
            vfx: {
                glow: rarity === "Epic" || rarity === "Legendary" || rarity === "Mythic",
                glowColor: "#ffd700",
                sparkles: rarity === "Legendary" || rarity === "Mythic",
                intensity: rarity === "Mythic" ? 0.9 : rarity === "Legendary" ? 0.6 : 0.3,
            },
            seed: Math.floor(Math.random() * 1000000),
            blenderInstructions: [
                "1. 1x1x1 큐브 생성",
                "2. Subdivision Surface 모디파이어 추가 (레벨 2)",
                "3. 색상 설정",
                "4. FBX로 내보내기",
            ],
            constraints: {
                maxTriangles: 2000,
                maxSize: 4,
                riggingRequired: false,
            },
        };
    }
}

// ─── Blender Python 스크립트 생성 ──────────────────────────────
/**
 * 모델링 스펙에서 Blender 실행 가능한 Python 스크립트 생성
 */
function generateBlenderScript(spec, outputPath) {
    const shape = spec.shape;
    const style = spec.style;

    return `
import bpy
import math

# 출력 경로 설정 (스크립트 시작 부분에 정의)
outputPath = r"${outputPath}"

# ─── 초기화 ────────────────────────────────────────────────
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

# ─── 기본 형태 생성 ────────────────────────────────────────
${getGeometryCode(shape)}

# ─── 모디파이어 적용 ────────────────────────────────────────
${getModifierCode(shape.modifiers || [])}

# ─── 재질 생성 ────────────────────────────────────────────────
${getMaterialCode(style)}

# ─── Roblox용 내보내기 설정 ───────────────────────────────────
# FBX 내보내기
bpy.ops.export_scene.fbx(
    filepath=outputPath,
    object_types={'MESH'},
    use_selection=False,
    global_scale=1.0,
    apply_unit_scale=True,
    axis_forward='-Z',
    axis_up='Y',
    mesh_smooth_type='FACE'
)

print(f"[SUCCESS] Exported to: {outputPath}")
`;
}

// ─── 기하학 코드 생성 헬퍼 ────────────────────────────────────
function getGeometryCode(shape) {
    const dims = shape.dimensions || { width: 1, height: 1, depth: 1 };
    const geo = shape.baseGeometry || "cube";

    switch (geo) {
        case "cube":
            return `
bpy.ops.mesh.primitive_cube_add(size=1)
obj = bpy.context.active_object
obj.scale = (${dims.width}, ${dims.height}, ${dims.depth})
`;

        case "sphere":
            return `
bpy.ops.mesh.primitive_uv_sphere_add(radius=${dims.width / 2})
obj = bpy.context.active_object
`;

        case "cylinder":
            return `
bpy.ops.mesh.primitive_cylinder_add(radius=${dims.width / 2}, depth=${dims.height})
obj = bpy.context.active_object
`;

        case "cone":
            return `
bpy.ops.mesh.primitive_cone_add(radius1=${dims.width / 2}, depth=${dims.height})
obj = bpy.context.active_object
`;

        case "torus":
            return `
bpy.ops.mesh.primitive_torus_add(major_radius=${dims.width / 2}, minor_radius=${dims.width / 10})
obj = bpy.context.active_object
`;

        case "plane":
            return `
bpy.ops.mesh.primitive_plane_add(size=${dims.width})
obj = bpy.context.active_object
`;

        default:
            return `
# 커스텀 형태 - 큐브로 시작
bpy.ops.mesh.primitive_cube_add(size=1)
obj = bpy.context.active_object
obj.scale = (${dims.width}, ${dims.height}, ${dims.depth})
`;
    }
}

// ─── 모디파이어 코드 생성 ─────────────────────────────────────
function getModifierCode(modifiers) {
    let code = "";

    if (modifiers.includes("subdivision")) {
        code += `
# Subdivision Surface
obj.modifiers.new(name="Subsurf", type='SUBSURF')
obj.modifiers["Subsurf"].levels = 2
obj.modifiers["Subsurf"].render_levels = 2
`;
    }

    if (modifiers.includes("bevel")) {
        code += `
# Bevel
obj.modifiers.new(name="Bevel", type='BEVEL')
obj.modifiers["Bevel"].width = 0.05
obj.modifiers["Bevel"].segments = 4
`;
    }

    if (modifiers.includes("mirror")) {
        code += `
# Mirror
obj.modifiers.new(name="Mirror", type='MIRROR')
obj.modifiers["Mirror"].use_clip = True
`;
    }

    if (modifiers.includes("solidify")) {
        code += `
# Solidify
obj.modifiers.new(name="Solidify", type='SOLIDIFY')
obj.modifiers["Solidify"].thickness = 0.02
`;
    }

    return code || "# 모디파이어 없음";
}

// ─── 재질 코드 생성 ───────────────────────────────────────────
function getMaterialCode(style) {
    const primary = style.primaryColor || "#4a90d9";
    const secondary = style.secondaryColor || "#ffffff";
    const material = style.material || "glossy";

    return `
# 재질 생성
mat = bpy.data.materials.new(name="UGC_Material")
mat.use_nodes = True
nodes = mat.node_tree.nodes
bsdf = nodes.get("Principled BSDF")

# 기본 색상 (RGB 변환)
${hexToRgbCode(primary, "base_color")}

if "${material}" == "emissive":
    # 발광 재질
    nodes.new("ShaderNodeEmission")
    emission = nodes.get("Emission")
    emission.inputs["Color"].default_value = (*base_color, 1.0)
    emission.inputs["Strength"].default_value = 5.0
    mat.node_tree.links.new(
        emission.outputs["Emission"],
        bsdf.inputs["Emission"]
    )
elif "${material}" == "metallic":
    # 금속 재질
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.2
elif "${material}" == "glass":
    # 유리 재질
    bsdf.inputs["Transmission"].default_value = 0.9
    bsdf.inputs["Roughness"].default_value = 0.1
else:
    # 기본 (glossy/matte)
    bsdf.inputs["Roughness"].default_value = 0.3 if "${material}" == "glossy" else 0.8

# 재질 적용
if obj.data.materials:
    obj.data.materials[0] = mat
else:
    obj.data.materials.append(mat)
`;
}

// ─── HEX를 RGB로 변환 ───────────────────────────────────────────
function hexToRgbCode(hex, varName) {
    const r = parseInt(hex.slice(1, 3), 16) / 255;
    const g = parseInt(hex.slice(3, 5), 16) / 255;
    const b = parseInt(hex.slice(5, 7), 16) / 255;
    return `${varName} = (${r.toFixed(3)}, ${g.toFixed(3)}, ${b.toFixed(3)})`;
}

// ─── Blender 명령어 생성 (단순화 버전) ─────────────────────────
function generateBlenderCommands(spec) {
    return spec.blenderInstructions || [];
}

// ─── 스크립트 저장 및 실행 (향후 MCP 연동 시) ──────────────────────
/**
 * Blender 스크립트를 파일로 저장
 */
async function saveBlenderScript(spec, filename) {
    const scriptName = filename || `generate_${Date.now()}.py`;
    const scriptPath = path.join(SCRIPTS_DIR, scriptName);
    const outputPath = path.join(EXPORTS_DIR, `${spec.name.replace(/\s+/g, "_")}.fbx`);

    const script = generateBlenderScript(spec, outputPath);

    await fs.writeFile(scriptPath, script, "utf8");
    console.log("[blenderService] 스크립트 저장:", scriptPath);

    return { scriptPath, outputPath };
}

// ─── 디렉토리 초기화 ───────────────────────────────────────────
async function ensureDirectories() {
    try {
        await fs.mkdir(SCRIPTS_DIR, { recursive: true });
        await fs.mkdir(EXPORTS_DIR, { recursive: true });
        console.log("[blenderService] 디렉토리 확인 완료");
    } catch (error) {
        console.error("[blenderService] 디렉토리 생성 실패:", error);
    }
}

// ─── Blender 실행 (백그라운드) ─────────────────────────────────
const { spawn } = require("child_process");

/**
 * Blender 백그라운드 실행으로 FBX 생성
 * @param {object} spec - 모델링 스펙
 * @returns {Promise<string>} - 출력된 FBX 파일 경로
 */
async function generateModel(spec) {
    console.log("[blenderService] Blender 모델 생성 시작:", spec.name);

    // 1. 스크립트 생성
    const { scriptPath, outputPath } = await saveBlenderScript(spec);

    // 2. Blender 실행 경로 확인
    const blenderPaths = [
        "/Applications/Blender.app/Contents/MacOS/Blender",
        "/usr/local/bin/blender",
        "C:\\Program Files\\Blender Foundation\\Blender 4.2\\blender.exe",
    ];

    let blenderPath = blenderPaths.find((p) => require("fs").existsSync(p));
    if (!blenderPath) {
        blenderPaths[0]; // macOS 기본값 사용
    }

    console.log("[blenderService] Blender 경로:", blenderPath);

    // 3. Blender 백그라운드 실행
    return new Promise((resolve, reject) => {
        const blender = spawn(blenderPath, [
            "-b",              // 백그라운드 모드 (no GUI)
            "-noaudio",        // 오디오 비활성화
            "-P", scriptPath,  // Python 스크립트 실행
        ]);

        let stdout = "";
        let stderr = "";

        blender.stdout.on("data", (data) => {
            const text = data.toString();
            stdout += text;
            console.log("[Blender]", text.trim());
        });

        blender.stderr.on("data", (data) => {
            const text = data.toString();
            stderr += text;
            console.error("[Blender Error]", text.trim());
        });

        blender.on("close", (code) => {
            console.log("[blenderService] Blender 종료, 코드:", code);

            if (code === 0) {
                // 출력 파일 확인 (fs.promises 사용)
                fs.access(outputPath)
                    .then(() => {
                        console.log("[blenderService] FBX 생성 성공:", outputPath);
                        resolve(outputPath);
                    })
                    .catch(() => {
                        reject(new Error("FBX 파일이 생성되지 않음"));
                    });
            } else {
                reject(
                    new Error(
                        `Blender 실행 실패 (코드: ${code}): ${stderr}`
                    )
                );
            }
        });

        // 타임아웃 (30초)
        setTimeout(() => {
            blender.kill();
            reject(new Error("Blender 타임아웃 (30초)"));
        }, 30000);
    });
}

// ─── FBX 파일 URL 변환 ───────────────────────────────────────────
/**
 * FBX 파일을 정적 파일로 제공하기 위한 URL 생성
 */
function getFbxUrl(filename) {
    return `http://localhost:${config.port}/exports/ugc/${filename}`;
}

// ─── Studio Lua 스크립트 생성 ────────────────────────────────────
/**
 * 모델링 스펙에서 Roblox Studio 실행 가능한 Lua 스크립트 생성
 * @param {object} spec - 아이템 스펙 (name, description, rarity, category 등)
 * @param {string} filename - FBX 파일명 (참고용)
 * @returns {string} - Studio Command Bar에서 실행 가능한 Lua 코드
 */
function generateStudioLuaScript(spec, filename) {
    const attachmentPoint = spec.attachmentPoint || CATEGORY_ATTACHMENTS[spec.category] || "HatAttachment";

    // Lua 스크립트 생성
    const luaScript = `
-- UGC 아이템 자동 설정 스크립트
-- FBX: ${filename || "N/A"}
local ServerScriptService = game:GetService("ServerScriptService")

local function findModuleScript(name)
    for _, inst in ipairs(ServerScriptService:GetDescendants()) do
        if inst:IsA("ModuleScript") and inst.Name == name then
            return inst
        end
    end
    return nil
end

local UGCToolsModule = findModuleScript("UGCTools")
assert(UGCToolsModule, "UGCTools not found under ServerScriptService")

local UGCTools = require(UGCToolsModule)

local spec = {
    name = "${spec.name || "Unknown Item"}",
    description = "${(spec.description || "").replace(/"/g, '\\"')}",
    rarity = "${spec.rarity || "Common"}",
    category = "${spec.category || "Hat"}",
    attachmentPoint = "${attachmentPoint}",
}

-- 선택된 모델에 스펙 적용
local result = UGCTools.SetupSelected(spec)

print("✅ UGC 아이템 설정 완료!")
print("이름:", result.name)
print("희귀도:", result.rarity)
print("카테고리:", result.category)
`.trim();

    return luaScript;
}

// 시작 시 디렉토리 확인
ensureDirectories();

module.exports = {
    generateModelingGuide,
    generateBlenderScript,
    generateBlenderCommands,
    saveBlenderScript,
    generateModel,
    getFbxUrl,
    generateStudioLuaScript,
    SCRIPTS_DIR,
    EXPORTS_DIR,
};
