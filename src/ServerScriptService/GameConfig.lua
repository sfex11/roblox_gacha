--[[
    GameConfig.lua
    서버 전용 설정 모듈 (배포 환경에 맞게 값만 조정)
]]

local GameConfig = {}

-- 데이터 저장/로드 설정
GameConfig.Data = {
    -- true면 DataStore를 무시하고 매번 새 데이터로 시작 (개발/테스트용)
    forceFreshData = true,

    -- DataStore 활성화 여부
    enableDataStore = false,

    -- DataStore 이름 (버전 업 시 "v2" 등으로 변경)
    dataStoreName = "PlayerData_v1",
}

-- LLM 설정
GameConfig.LLM = {
    -- LLM 활성화 여부 (true면 백엔드 API 호출)
    enabled = true,

    -- 헬스체크 후 자동 활성화 (false면 헬스체크 결과 무시하고 강제 활성화)
    autoEnable = false,
}

return GameConfig

