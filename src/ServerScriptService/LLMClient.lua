--[[
    LLMClient.lua
    백엔드 API 서버와 통신하여 LLM 텍스트를 요청/수신
    실패 시 프리셋 폴백 텍스트 반환 (게임 중단 없음)
]]

local HttpService = game:GetService("HttpService")
local Constants = require(game.ReplicatedStorage.Modules.Constants)
local ItemDatabase = require(game.ReplicatedStorage.Modules.ItemDatabase)

local LLMClient = {}

-------------------------------------------------------
-- 설정
-------------------------------------------------------
LLMClient.Config = {
    backendUrl = "http://localhost:3001",  -- 프로덕션에서는 실제 URL로 교체
    sharedSecret = "dev-secret",            -- .env와 일치시킬 것
    timeoutSeconds = 10,  -- 10초 타임아웃 (캐시는 1초 이내, 새 요청은 5~10초)
    enabled = false,  -- true로 변경하면 LLM 활성화 (기본: 프리셋만)
}

-------------------------------------------------------
-- 백엔드에 텍스트 생성 요청
-------------------------------------------------------
function LLMClient.RequestText(templateId, rarity, category, baseName, options)
    print("[LLMClient] RequestText 호출 - enabled:", LLMClient.Config.enabled, "templateId:", templateId)

    if not LLMClient.Config.enabled then
        print("[LLMClient] LLM 비활성화 - 폴백 반환")
        return LLMClient._getFallback(templateId)
    end

    options = options or {}
    print("[LLMClient] 백엔드 요청 시작...")

    local requestBody = {
        requestId = HttpService:GenerateGUID(false),
        templateId = templateId,
        rarity = rarity,
        category = category,
        baseName = baseName,
        theme = options.theme or "default",
        locale = options.locale or "ko",
        keywords = options.keywords or {},
        tone = options.tone or "default",
    }

    local success, response = pcall(function()
        print("[LLMClient] HTTP 요청 전송:", LLMClient.Config.backendUrl .. "/api/generate")
        return HttpService:RequestAsync({
            Url = LLMClient.Config.backendUrl .. "/api/generate",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["X-Api-Secret"] = LLMClient.Config.sharedSecret,
            },
            Body = HttpService:JSONEncode(requestBody),
        })
    end)

    print("[LLMClient] HTTP 요청 완료 - success:", success)

    if not success then
        warn("[LLMClient] HTTP 요청 실패: " .. tostring(response))
        return LLMClient._getFallback(templateId)
    end

    if response.StatusCode ~= 200 then
        warn("[LLMClient] 응답 오류 (" .. tostring(response.StatusCode) .. ")")
        return LLMClient._getFallback(templateId)
    end

    local decodeSuccess, data = pcall(function()
        return HttpService:JSONDecode(response.Body)
    end)

    if not decodeSuccess or not data then
        warn("[LLMClient] JSON 파싱 실패")
        return LLMClient._getFallback(templateId)
    end

    if data.success and data.text then
        return {
            success = true,
            source = data.source or "llm",
            name = data.text.name,
            description = data.text.description,
            flavorText = data.text.flavorText,
            tagsSuggested = data.text.tagsSuggested,
        }
    else
        return LLMClient._getFallback(templateId)
    end
end

-------------------------------------------------------
-- 비동기 요청 (코루틴 안전)
-------------------------------------------------------
function LLMClient.RequestTextAsync(templateId, rarity, category, baseName, options)
    local result
    local thread = coroutine.running()

    task.spawn(function()
        result = LLMClient.RequestText(templateId, rarity, category, baseName, options)
        if thread then
            task.defer(function()
                coroutine.resume(thread)
            end)
        end
    end)

    coroutine.yield()
    return result
end

-------------------------------------------------------
-- 폴백: 프리셋 텍스트 반환 (LLM 실패/비활성 시)
-------------------------------------------------------
function LLMClient._getFallback(templateId)
    local template = ItemDatabase.GetTemplate(templateId)
    if template then
        return {
            success = true,
            source = "fallback",
            name = template.name,
            description = template.description,
            flavorText = template.flavorText,
        }
    end

    return {
        success = true,
        source = "fallback",
        name = "신비로운 아이템",
        description = "알 수 없는 힘이 깃들어 있다.",
        flavorText = "무언가 특별한 것.",
    }
end

-------------------------------------------------------
-- LLM 활성화/비활성화 (런타임 토글)
-------------------------------------------------------
function LLMClient.SetEnabled(enabled)
    LLMClient.Config.enabled = enabled
    print("[LLMClient] LLM " .. (enabled and "활성화" or "비활성화"))
end

function LLMClient.IsEnabled()
    return LLMClient.Config.enabled
end

-------------------------------------------------------
-- 백엔드 헬스체크
-------------------------------------------------------
function LLMClient.HealthCheck()
    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = LLMClient.Config.backendUrl .. "/api/health",
            Method = "GET",
        })
    end)

    if success and response and response.StatusCode == 200 then
        local decodeOk, data = pcall(function()
            return HttpService:JSONDecode(response.Body)
        end)
        return { online = true, data = decodeOk and data or nil }
    end

    return { online = false }
end

return LLMClient
