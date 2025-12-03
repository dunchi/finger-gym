-- finger-gym: 키보드 타수 카운터
-- 위치: /Users/hanju/02hobby/finger-gym/finger-gym.lua

local M = {}

-- 설정
M.projectPath = "/Users/hanju/02hobby/finger-gym"
M.logFile = M.projectPath .. "/keystroke_log.txt"
M.todayFile = M.projectPath .. "/today_count.txt"

-- 상태
M.count = 0
M.today = os.date("%Y-%m-%d")
M.canvas = nil
M.keyTap = nil
M.midnightTimer = nil

-- 오늘 카운트 파일에서 로드
function M.loadTodayCount()
    local file = io.open(M.todayFile, "r")
    if file then
        local savedDate = file:read("*line")
        local savedCount = file:read("*line")
        file:close()

        if savedDate == M.today and savedCount then
            M.count = tonumber(savedCount) or 0
        else
            -- 날짜가 다르면 어제 기록 저장 후 리셋
            if savedDate and savedCount then
                M.saveToLog(savedDate, tonumber(savedCount) or 0)
            end
            M.count = 0
        end
    end
end

-- 오늘 카운트 파일에 저장
function M.saveTodayCount()
    local file = io.open(M.todayFile, "w")
    if file then
        file:write(M.today .. "\n")
        file:write(tostring(M.count) .. "\n")
        file:close()
    end
end

-- 일별 로그 파일에 저장
function M.saveToLog(date, count)
    local file = io.open(M.logFile, "a")
    if file then
        file:write(date .. "," .. tostring(count) .. "\n")
        file:close()
    end
end

-- 숫자 포맷팅 (천 단위 콤마)
function M.formatNumber(n)
    local formatted = tostring(n)
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

-- 캔버스 업데이트
function M.updateDisplay()
    if M.canvas then
        M.canvas[2].text = M.formatNumber(M.count)
    end
end

-- 캔버스 생성 (우측 하단)
function M.createCanvas()
    local screen = hs.screen.primaryScreen()
    local frame = screen:frame()

    local width = 150
    local height = 50
    local padding = 20

    local x = frame.x + frame.w - width - padding
    local y = frame.y + frame.h - height - padding

    M.canvas = hs.canvas.new({x = x, y = y, w = width, h = height})

    -- 배경
    M.canvas[1] = {
        type = "rectangle",
        fillColor = {red = 0.1, green = 0.1, blue = 0.1, alpha = 0.7},
        roundedRectRadii = {xRadius = 8, yRadius = 8},
    }

    -- 텍스트
    M.canvas[2] = {
        type = "text",
        text = M.formatNumber(M.count),
        textFont = "Menlo",
        textSize = 24,
        textColor = {red = 0.3, green = 0.9, blue = 0.4, alpha = 1},
        textAlignment = "center",
        frame = {x = 0, y = 8, w = width, h = height - 8}
    }

    M.canvas:level(hs.canvas.windowLevels.overlay)
    M.canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
    M.canvas:show()
end

-- 자정 체크 및 리셋
function M.checkMidnight()
    local newToday = os.date("%Y-%m-%d")
    if newToday ~= M.today then
        -- 어제 기록 저장
        M.saveToLog(M.today, M.count)
        -- 리셋
        M.today = newToday
        M.count = 0
        M.saveTodayCount()
        M.updateDisplay()
        hs.notify.new({title = "finger-gym", informativeText = "새로운 하루! 카운터가 리셋되었습니다."}):send()
    end
end

-- 키보드 이벤트 핸들러
function M.onKeyEvent(event)
    M.count = M.count + 1
    M.updateDisplay()

    -- 100번마다 저장 (성능 최적화)
    if M.count % 100 == 0 then
        M.saveTodayCount()
    end

    return false -- 이벤트 전달 계속
end

-- 시작
function M.start()
    M.loadTodayCount()
    M.createCanvas()

    -- 키보드 이벤트 탭
    M.keyTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, M.onKeyEvent)
    M.keyTap:start()

    -- 자정 체크 타이머 (1분마다)
    M.midnightTimer = hs.timer.doEvery(60, M.checkMidnight)

    -- 주기적 저장 타이머 (30초마다)
    M.saveTimer = hs.timer.doEvery(30, function()
        M.saveTodayCount()
    end)

    hs.notify.new({title = "finger-gym", informativeText = "키보드 카운터 시작! 오늘: " .. M.formatNumber(M.count)}):send()
end

-- 정지
function M.stop()
    if M.keyTap then
        M.keyTap:stop()
        M.keyTap = nil
    end
    if M.midnightTimer then
        M.midnightTimer:stop()
        M.midnightTimer = nil
    end
    if M.saveTimer then
        M.saveTimer:stop()
        M.saveTimer = nil
    end
    if M.canvas then
        M.canvas:delete()
        M.canvas = nil
    end
    M.saveTodayCount()
end

-- 재시작
function M.restart()
    M.stop()
    M.start()
end

return M
