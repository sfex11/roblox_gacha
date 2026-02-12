--[[
    GameConfig.lua
    서버 전용 설정 모듈 (배포 환경에 맞게 값만 조정)
]]

local GameConfig = {}

-------------------------------------------------------
-- 관리자 설정 (서버/클라이언트 공통)
-------------------------------------------------------
GameConfig.Admin = {
    -- 관리자 UserId 목록 (실제 운영 시 교체 필요)
    UserIds = {
        12345678, -- 예시: 실제 관리자 UserId로 교체 필요
        -- 추가 관리자 UserId
    },

    -- Studio에서 자동 관리자 권한 부여 여부
    studioAutoAdmin = true,
}

-------------------------------------------------------
-- 데이터 저장/로드 설정
-------------------------------------------------------
GameConfig.Data = {
    -- true면 DataStore를 무시하고 매번 새 데이터로 시작 (개발/테스트용)
    forceFreshData = true,

    -- DataStore 활성화 여부
    enableDataStore = false,

    -- DataStore 이름 (버전 업 시 "v2" 등으로 변경)
    dataStoreName = "PlayerData_v1",
}

-------------------------------------------------------
-- LLM 설정
-------------------------------------------------------
GameConfig.LLM = {
    -- LLM 활성화 여부 (true면 백엔드 API 호출)
    enabled = true,

    -- 헬스체크 후 자동 활성화 (false면 헬스체크 결과 무시하고 강제 활성화)
    autoEnable = false,
}

-------------------------------------------------------
-- 디버그/로깅 설정
-------------------------------------------------------
GameConfig.Debug = {
    -- 로그 레벨: "none" | "error" | "warn" | "info" | "debug"
    logLevel = "debug",

    -- 가차 상세 로그
    gachaVerbose = false,
}

-------------------------------------------------------
-- 유틸리티 함수
-------------------------------------------------------

-- 관리자 권한 확인 (RunService 필요)
function GameConfig.IsAdmin(player, runService)
    if not player then return false end

    -- Studio에서 자동 관리자 권한
    if GameConfig.Admin.studioAutoAdmin and runService and runService:IsStudio() then
        return true
    end

    -- UserId 확인
    return table.find(GameConfig.Admin.UserIds, player.UserId) ~= nil
end

return GameConfig

