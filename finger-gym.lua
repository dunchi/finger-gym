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
    }

    -- 텍스트
    M.canvas[2] = {
        type = "text",
        text = M.formatNumber(M.count),
        textFont = "Menlo",
        textSize = 24,
        textColor = {red = 0.3, green = 0.9, blue = 0.4, alpha = 1},
        textAlignment = "center",
        frame = {x = 0, y = 13, w = width, h = height}
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

-- 로그 파일에서 기록 읽기
function M.loadLogData()
    local data = {}
    local file = io.open(M.logFile, "r")
    if file then
        for line in file:lines() do
            local date, count = line:match("([^,]+),([^,]+)")
            if date and count then
                data[date] = tonumber(count) or 0
            end
        end
        file:close()
    end
    return data
end

-- 최근 N일 기록 가져오기 (오래된 날짜부터, 오늘이 마지막)
function M.getRecentDays(days)
    local logData = M.loadLogData()
    local result = {}
    local total = 0

    for i = days - 1, 0, -1 do
        local timestamp = os.time() - (i * 86400)
        local date = os.date("%Y-%m-%d", timestamp)
        local count = 0

        if i == 0 then
            -- 오늘은 현재 카운트
            count = M.count
        else
            count = logData[date] or 0
        end

        table.insert(result, {date = date, count = count, isToday = (i == 0)})
        total = total + count
    end

    return result, total
end

-- 주간 기록 팝업
M.weeklyCanvas = nil
M.weeklyTimer = nil

function M.showWeeklyStats()
    -- 기존 팝업 닫기
    M.hideWeeklyStats()

    local days, total = M.getRecentDays(7)
    local screen = hs.screen.primaryScreen()
    local frame = screen:frame()

    local width = 280
    local lineHeight = 28
    local headerHeight = 40
    local footerHeight = 36
    local height = headerHeight + (lineHeight * 7) + footerHeight + 20
    local padding = 20

    -- 키 카운트 캔버스 위에 위치
    local x = frame.x + frame.w - width - padding
    local y = frame.y + frame.h - 50 - padding - height - 10  -- 카운트 캔버스(50) 위

    M.weeklyCanvas = hs.canvas.new({x = x, y = y, w = width, h = height})

    -- 배경
    M.weeklyCanvas[1] = {
        type = "rectangle",
        fillColor = {red = 0.12, green = 0.12, blue = 0.14, alpha = 0.95},
    }

    -- 테두리
    M.weeklyCanvas[2] = {
        type = "rectangle",
        strokeColor = {red = 0.3, green = 0.3, blue = 0.35, alpha = 1},
        strokeWidth = 1,
        fillColor = {alpha = 0},
    }

    -- 헤더
    M.weeklyCanvas[3] = {
        type = "text",
        text = "최근 7일 타수",
        textFont = "Helvetica Neue Bold",
        textSize = 16,
        textColor = {red = 1, green = 1, blue = 1, alpha = 1},
        textAlignment = "center",
        frame = {x = 0, y = 12, w = width, h = 24}
    }

    -- 구분선
    M.weeklyCanvas[4] = {
        type = "rectangle",
        fillColor = {red = 0.3, green = 0.3, blue = 0.35, alpha = 1},
        frame = {x = 20, y = headerHeight, w = width - 40, h = 1}
    }

    -- 일별 기록
    local idx = 5
    for i, day in ipairs(days) do
        local yPos = headerHeight + 10 + (i - 1) * lineHeight
        local displayDate = day.date:sub(6) -- MM-DD만 표시
        local label = displayDate
        if day.isToday then
            label = displayDate .. " (오늘)"
        end

        -- 날짜
        M.weeklyCanvas[idx] = {
            type = "text",
            text = label,
            textFont = "Menlo",
            textSize = 14,
            textColor = {red = 0.7, green = 0.7, blue = 0.7, alpha = 1},
            textAlignment = "left",
            frame = {x = 24, y = yPos, w = 120, h = 24}
        }
        idx = idx + 1

        -- 카운트
        local countColor = {red = 0.3, green = 0.9, blue = 0.4, alpha = 1}
        if day.count == 0 then
            countColor = {red = 0.5, green = 0.5, blue = 0.5, alpha = 1}
        end

        M.weeklyCanvas[idx] = {
            type = "text",
            text = M.formatNumber(day.count),
            textFont = "Menlo",
            textSize = 14,
            textColor = countColor,
            textAlignment = "right",
            frame = {x = width - 24 - 100, y = yPos, w = 100, h = 24}
        }
        idx = idx + 1
    end

    -- 하단 구분선
    local footerY = headerHeight + 10 + (7 * lineHeight)
    M.weeklyCanvas[idx] = {
        type = "rectangle",
        fillColor = {red = 0.3, green = 0.3, blue = 0.35, alpha = 1},
        frame = {x = 20, y = footerY, w = width - 40, h = 1}
    }
    idx = idx + 1

    -- 합계
    M.weeklyCanvas[idx] = {
        type = "text",
        text = "주간 합계",
        textFont = "Helvetica Neue",
        textSize = 14,
        textColor = {red = 0.8, green = 0.8, blue = 0.8, alpha = 1},
        textAlignment = "left",
        frame = {x = 24, y = footerY + 8, w = 100, h = 24}
    }
    idx = idx + 1

    M.weeklyCanvas[idx] = {
        type = "text",
        text = M.formatNumber(total),
        textFont = "Menlo Bold",
        textSize = 16,
        textColor = {red = 0.4, green = 0.8, blue = 1, alpha = 1},
        textAlignment = "right",
        frame = {x = width - 24 - 100, y = footerY + 8, w = 100, h = 24}
    }

    M.weeklyCanvas:level(hs.canvas.windowLevels.overlay)
    M.weeklyCanvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
    M.weeklyCanvas:show()

    -- 5초 후 자동 닫기
    M.weeklyTimer = hs.timer.doAfter(5, function()
        M.hideWeeklyStats()
    end)
end

function M.hideWeeklyStats()
    if M.weeklyTimer then
        M.weeklyTimer:stop()
        M.weeklyTimer = nil
    end
    if M.weeklyCanvas then
        M.weeklyCanvas:delete()
        M.weeklyCanvas = nil
    end
end

return M
