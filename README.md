# finger-gym

macOS 키보드 타수 카운터 - 하루종일 키보드 치는 보람을 숫자로 확인하세요.

![macOS](https://img.shields.io/badge/macOS-000000?style=flat&logo=apple&logoColor=white)
![Hammerspoon](https://img.shields.io/badge/Hammerspoon-FFB100?style=flat)
![License](https://img.shields.io/badge/license-MIT-green)

## 소개

메인 모니터 우측 하단에 오늘 키보드를 누른 횟수를 실시간으로 표시합니다.

- 실시간 키 입력 카운트
- 하루 단위 자동 리셋 (자정)
- 일별 기록 저장
- 최근 7일 기록 팝업
- 가볍고 시스템 리소스 거의 사용 안함

## 미리보기

```
┌─────────────┐
│   12,345    │  ← 우측 하단에 표시
└─────────────┘

Ctrl+Alt+Cmd+H 로 주간 기록 확인:

┌─────────────────────────┐
│    최근 7일 타수        │
├─────────────────────────┤
│  12-03 (오늘)    1,234  │
│  12-02           8,765  │
│  12-01          12,345  │
│  ...                    │
├─────────────────────────┤
│  주간 합계      45,678  │
└─────────────────────────┘
```

## 설치

### 1. Hammerspoon 설치

```bash
brew install --cask hammerspoon
```

### 2. 프로젝트 클론

```bash
git clone https://github.com/dunchi/finger-gym.git ~/finger-gym
```

### 3. Hammerspoon 설정

`~/.hammerspoon/init.lua` 파일을 생성하거나 편집:

```lua
-- finger-gym 경로 설정 (클론한 위치에 맞게 수정)
package.path = package.path .. ";/Users/YOUR_USERNAME/finger-gym/?.lua"

local fingerGym = require("finger-gym")
fingerGym.start()

-- 단축키: Ctrl+Alt+Cmd+H 로 주간 기록 보기
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "H", function()
    fingerGym.showWeeklyStats()
end)
```

### 4. 접근성 권한 부여 (필수)

1. **시스템 설정** > **개인정보 보호 및 보안** > **접근성**
2. **Hammerspoon** 토글 ON
3. Hammerspoon 재시작

## 사용법

### 단축키

| 키 | 기능 |
|----|------|
| `Ctrl+Alt+Cmd+H` | 최근 7일 기록 보기 |

> 단축키는 `~/.hammerspoon/init.lua`에서 원하는 키로 변경할 수 있습니다.

### 단축키 커스터마이징

`init.lua`에서 단축키를 자유롭게 수정하세요:

```lua
-- 예시: 다른 단축키로 변경
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "S", function()  -- H 대신 S
    fingerGym.showWeeklyStats()
end)

-- 예시: 재시작 단축키 추가
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "R", function()
    fingerGym.restart()
    hs.alert.show("finger-gym 재시작")
end)

-- 예시: 숨기기/보이기 토글 추가
local isVisible = true
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "T", function()
    if isVisible then
        fingerGym.canvas:hide()
        isVisible = false
    else
        fingerGym.canvas:show()
        isVisible = true
    end
end)
```

### 데이터 파일

| 파일 | 설명 |
|------|------|
| `today_count.txt` | 오늘 카운트 (재시작 시 복원용) |
| `keystroke_log.txt` | 일별 기록 (날짜,카운트) |

```
# keystroke_log.txt 예시
2025-12-01,15234
2025-12-02,12876
2025-12-03,18432
```

## 커스터마이징

`finger-gym.lua` 파일에서 수정 가능:

```lua
-- 표시 위치/크기
local width = 150
local height = 50
local padding = 20  -- 화면 가장자리로부터 거리

-- 색상
fillColor = {red = 0.1, green = 0.1, blue = 0.1, alpha = 0.7}  -- 배경
textColor = {red = 0.3, green = 0.9, blue = 0.4, alpha = 1}    -- 텍스트
```

## 요구사항

- macOS
- [Hammerspoon](https://www.hammerspoon.org/)

## 라이선스

MIT License
