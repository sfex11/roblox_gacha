# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

Roblox 기반 LLM 연동 가챠형 컬렉션 게임 기획 프로젝트입니다. 현재 기획 문서 단계로, 실제 개발이 시작되면 Luau(Roblox Lua)로 코드가 작성될 예정입니다.

## 핵심 기획 원칙

### 게임 콘셉트
- **장르**: 소셜 허브 + 협동 미니게임(Raid/TD/보스) + 컬렉션/도감 + 가차
- **USP**: LLM이 아이템의 이름/설명/플레이버 텍스트를 매번 다르게 생성하여 수집의 재미와 공유성을 강화
- **타겟**: 한국 사용자 (ko UI/카피 중심)

### 중요 설계 원칙
1. **결과는 서버가 결정**: 희귀도/아이템/스탯은 Roblox 서버가 100% 통제 (공정성/정책 대응)
2. **LLM은 표현만 생성**: 이름/설명/로어 텍스트만 생성 (비용/안전/품질 관리)
3. **플레이어 입력은 프리셋 중심**: 제한형 자유 입력만 허용 (텍스트 안전/필터링 리스크 최소화)

## 과금 정책 (한국 타겟)

Roblox "Paid Random Items" 정책 준수가 필수적입니다:

### 필수 요구사항
- **확률(odds) 공개**: 구매 전/게임 내 상시 제공
- **구매자 자격 제한**: PolicyService로 구매 가능 사용자만 거래 허용
- **가치 거래 유도 금지**: 아이템을 현금/Robux 가치로 거래/이전하지 않도록 설계
- **보상형 광고 제약**: 랜덤 아이템 보상 금지

### 추천 과금 구조
- 가차는 무료 티켓/소프트 재화 중심
- Robux 과금은 배틀패스/구독/VIP/편의성/직접구매 위주
- 한국 사용자 신뢰: 확률표 상시 노출 + 천장/교환 + 중복 보상(진행도화)

## 기술 아키텍처 (개발 시)

```
[Client] --(RemoteEvent)--> [Roblox Server] --(HttpService)--> [Backend API] --(Provider SDK)--> [LLM]
```

### 보안 원칙
- 클라이언트에서 직접 LLM 호출 금지 (키 유출/변조 방지)
- Roblox 서버가 결과 지급 담당 (신뢰 경계)
- 백엔드: API 키 보관, 요청 인증, 프롬프트 정규화/필터링, 캐시/레이트리밋/로깅

### 장애 대응
- LLM 장애/타임아웃 시: 프리셋 텍스트로 즉시 대체 (사용자에게 기술 문구 노출 금지)
- 백엔드 장애 시: 가차 자체는 정상 진행, 텍스트만 기본값 처리

## 개발 로드맵

### Phase 0: MVP (LLM 없이도 재미 성립)
- 가차 확률/풀/연출
- 인벤토리/장착/도감/세트 보상
- 협동 미니게임 1종

### Phase 1: 백엔드/LLM 연동 (표현만)
- Backend API (인증/레이트리밋/캐시/로그)
- LLM 텍스트 생성 + Roblox 필터 적용
- 폴백/타임아웃/장애 대응

### Phase 2: 프롬프트 튜닝 & 시즌 운영
- 테마별 톤 가이드 (귀여움/영웅담/코믹/다크)
- 한국어/영어 로캘 대응
- 세트/픽업/천장/교환 시스템 고도화

## 기획 문서

- `가차게임계획.md`: 전체 기획서 (시장/포지셔닝/과금정책/콘텐츠/LLM 연동/개발 로드맵)
- `로블록스_가차_시장조사.md`: 경쟁작 벤치마크 및 시장 분석

## Roblox 관련 참고

### 확률형 아이템 정책 (출시 전 재검증 필수)
- Roblox Community Standards – Paid Random Items: https://en.help.roblox.com/hc/en-us/articles/20331341057940-Roblox-Community-Standards
- Roblox Advertising Standards: https://en.help.roblox.com/hc/en-us/articles/20331327993748-Roblox-Advertising-Standards
- Roblox Terms of Use (Republic of Korea): https://en.help.roblox.com/hc/en-us/articles/16888601846932-Terms-of-Use-Republic-of-Korea
