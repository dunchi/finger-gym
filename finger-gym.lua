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
M.weekOffset = 0

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

-- 특정 주간 기록 가져오기 (offset: 0=이번주, 1=저번주, ...)
-- 월요일~일요일 기준
function M.getWeekData(offset)
    local logData = M.loadLogData()
    local result = {}
    local total = 0
    local hasData = false

    -- 오늘 날짜와 요일 구하기
    local now = os.time()
    local todayDate = os.date("%Y-%m-%d", now)
    local wday = tonumber(os.date("%w", now)) -- 0=일, 1=월, ..., 6=토

    -- 이번 주 월요일까지의 일수 계산 (월요일=0, 화요일=1, ..., 일요일=6)
    local daysFromMonday
    if wday == 0 then
        daysFromMonday = 6 -- 일요일이면 6일 전이 월요일
    else
        daysFromMonday = wday - 1
    end

    -- offset 주 전의 월요일 timestamp
    local mondayTimestamp = now - ((daysFromMonday + (offset * 7)) * 86400)

    -- 월~일 7일 표시
    for i = 0, 6 do
        local timestamp = mondayTimestamp + (i * 86400)
        local date = os.date("%Y-%m-%d", timestamp)
        local count = 0
        local isToday = (date == todayDate)

        if isToday then
            count = M.count
            hasData = true
        else
            count = logData[date] or 0
            if count > 0 then
                hasData = true
            end
        end

        table.insert(result, {date = date, count = count, isToday = isToday})
        total = total + count
    end

    return result, total, hasData
end

-- 주간 기록 팝업
M.weeklyCanvas = nil
M.weeklyTimer = nil

function M.showWeeklyStats()
    -- 팝업이 이미 열려있으면 이전 주로 이동
    if M.weeklyCanvas then
        local nextOffset = M.weekOffset + 1
        local _, _, hasData = M.getWeekData(nextOffset)
        if hasData then
            M.weekOffset = nextOffset
            M.renderWeeklyCanvas()
        end
        -- 데이터 없으면 무시 (현재 주 유지)
        return
    end

    -- 새로 열기
    M.weekOffset = 0
    M.renderWeeklyCanvas()
end

function M.renderWeeklyCanvas()
    -- 기존 캔버스 삭제
    if M.weeklyCanvas then
        M.weeklyCanvas:delete()
        M.weeklyCanvas = nil
    end
    if M.weeklyTimer then
        M.weeklyTimer:stop()
        M.weeklyTimer = nil
    end

    local days, total, _ = M.getWeekData(M.weekOffset)
    local screen = hs.screen.primaryScreen()
    local frame = screen:frame()

    local width = 280
    local lineHeight = 28
    local topPadding = 16
    local footerHeight = 36
    local height = topPadding + (lineHeight * 7) + footerHeight + 10
    local padding = 20

    -- 키 카운트 캔버스 위에 위치
    local x = frame.x + frame.w - width - padding
    local y = frame.y + frame.h - 50 - padding - height - 10

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

    -- 요일 변환 테이블
    local weekdays = {"일", "월", "화", "수", "목", "금", "토"}

    -- 일별 기록
    local idx = 3
    for i, day in ipairs(days) do
        local yPos = topPadding + (i - 1) * lineHeight
        local displayDate = day.date:sub(6) -- MM-DD만 표시
        -- 요일 계산
        local y, m, d = day.date:match("(%d+)-(%d+)-(%d+)")
        local timestamp = os.time({year = tonumber(y), month = tonumber(m), day = tonumber(d)})
        local wday = tonumber(os.date("%w", timestamp)) + 1 -- Lua 테이블은 1부터
        local label = displayDate .. " (" .. weekdays[wday] .. ")"

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
    local footerY = topPadding + (7 * lineHeight)
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
    M.weekOffset = 0
end

return M
