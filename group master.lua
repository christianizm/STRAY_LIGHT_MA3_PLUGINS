--Group Masters UI
--by Christian Floyd Lewis

local pluginName    = select(1, ...)
local componentName = select(2, ...)
local signalTable   = select(3, ...)
local myHandle      = select(4, ...)

local COLS         = 8
local FADER_W      = 120
local FADER_H      = 220
local VALUE_H      = 0
local COL_W        = 120
local COL_PAD      = 5
local ROW_PAD      = 10
local TITLE_H      = 30
local FRAME_PAD_L  = 5
local FRAME_PAD_T  = 10
local FRAME_PAD_R  = 33
local FRAME_PAD_B  = 42
local SCROLLBAR_W  = 20
local MAX_VIS_ROWS = 2
local BG_COLOR     = "Window.Menus"
local BG_FILL      = "Global.ToolboxColor_8"

local COL_STEP = COL_W + COL_PAD
local ROW_H    = FADER_H + VALUE_H
local ROW_STEP = ROW_H + ROW_PAD
local GRID_W   = COLS * COL_STEP - COL_PAD

local faderEntries = {}

local function WrapName(str, maxLen)
    if #str <= maxLen then return str end
    local mid = math.floor(#str / 2)
    for offset = 0, mid do
        if str:sub(mid - offset, mid - offset) == " " then
            return str:sub(1, mid - offset - 1) .. "\n" .. str:sub(mid - offset + 1)
        end
        if str:sub(mid + offset, mid + offset) == " " then
            return str:sub(1, mid + offset - 1) .. "\n" .. str:sub(mid + offset + 1)
        end
    end
    return str:sub(1, maxLen) .. "\n" .. str:sub(maxLen + 1)
end

local function Cleanup()
    faderEntries = {}
end

local function CollectGroupMasters()
    local masters   = {}
    local seen      = {}
    local MAX_PAGES = 20

    local okP, pages = pcall(function() return DataPool().Pages end)
    if not okP or not pages then
        ErrEcho("[GMFaders] Could not access DataPool().Pages")
        return masters
    end

    for pi = 1, math.min(pages:Count(), MAX_PAGES) do
        local okPg, page = pcall(function() return pages[pi] end)
        if okPg and page then
            local okC, cnt = pcall(function() return page:Count() end)
            if okC and cnt and cnt > 0 then
                for ei = 1, cnt do
                    local okE, exec = pcall(function() return page[ei] end)
                    if okE and exec then
                        local okO, obj = pcall(function() return exec:GetAssignedObj() end)
                        if okO and obj then
                            local okCl, cls = pcall(function() return obj:GetClass() end)
                            if okCl and cls and cls:lower():find("group") then
                                local okId, objId = pcall(function() return HandleToInt(obj) end)
                                local dedupKey = (okId and objId) and objId or (pi .. "_" .. ei)

                                if not seen[dedupKey] then
                                    seen[dedupKey] = true

                                    local rawName = nil
                                    local okN1, n1 = pcall(function() return obj:Get("Name") end)
                                    if okN1 and n1 and n1 ~= "" then
                                        rawName = n1
                                    end

                                    if not rawName then
                                        local okN2, n2 = pcall(function() return exec:Get("Name") end)
                                        if okN2 and n2 and n2 ~= "" then
                                            rawName = n2
                                        end
                                    end

                                    if not rawName or rawName == "" then
                                        rawName = "Ex" .. ei
                                    end

                                    local okG, group = pcall(function()
                                        return DataPool().Groups[rawName]
                                    end)

                                    masters[#masters + 1] = {
                                        group   = (okG and group) and group or obj,
                                        name    = WrapName(rawName, 10),
                                        rawName = rawName,
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return masters
end

signalTable.FaderChanged = function(caller)
    local idx = tonumber(caller.SignalValue)
    if not idx then return end

    local entry = faderEntries[idx]
    if not entry or not entry.group then return end

    local rawVal = caller.Value
    local numVal = nil

    if type(rawVal) == "number" then
        numVal = rawVal
    elseif type(rawVal) == "string" then
        numVal = tonumber(rawVal:match("([%d%.%-]+)"))
    end

    if not numVal then return end

    local val = math.floor(numVal + 0.5)

    local ok = pcall(function()
        entry.group:SetFader({ value = val, token = "FaderMaster" })
    end)

    if not ok then
        CmdIndirect(string.format('FaderMaster Group "%s" At %d', entry.rawName, val))
    end
end

signalTable.CloseUI = function(caller)
    Cleanup()
    local display = GetFocusDisplay()
    display.ScreenOverlay:ClearUIChildren()
end

signalTable.RescanUI = function(caller)
    Cleanup()
    Main()
end

local function BuildUI()
    Cleanup()

    local masters = CollectGroupMasters()
    if #masters == 0 then
        ErrEcho("[GMFaders] No Group Masters found.")
        return
    end

    --Printf("[GMFaders] Found " .. #masters .. " Group Master(s)")

    local totalRows  = math.ceil(#masters / COLS)
    local totalGridH = totalRows * ROW_STEP - ROW_PAD
    local useScroll  = totalRows > MAX_VIS_ROWS
    local visGridH   = useScroll and (MAX_VIS_ROWS * ROW_STEP - ROW_PAD) or totalGridH

    local dialogW = GRID_W + FRAME_PAD_L + FRAME_PAD_R + (useScroll and SCROLLBAR_W or 0)
    local dialogH = TITLE_H + FRAME_PAD_T + visGridH + FRAME_PAD_B + 10

    local display = GetFocusDisplay()
    local overlay = display.ScreenOverlay
    overlay:ClearUIChildren()

    local base            = overlay:Append("BaseInput")
    base.W                = dialogW
    base.H                = dialogH
    base.Columns          = 1
    base.Rows             = 2
    base[1][1].SizePolicy = "Fixed"
    base[1][1].Size       = TITLE_H
    base[1][2].SizePolicy = "Stretch"
    base.AutoClose        = "No"
    base.CloseOnEscape    = "Yes"
    --base.BackColor        = BG_FILL

    local titleBar            = base:Append("TitleBar")
    titleBar.Columns          = 2
    titleBar.Rows             = 1
    titleBar.Anchors          = "0,0"
    titleBar[2][2].SizePolicy = "Fixed"
    titleBar[2][2].Size       = 50
    titleBar.Texture          = "corner2"

    local titleBtnLeft              = titleBar:Append("TitleButton")
    titleBtnLeft.Anchors            = "0,0"
    titleBtnLeft.Icon               = "fader"
    titleBtnLeft.Texture            = "corner1"
    titleBtnLeft.Text               = "GROUP MASTERS"
    titleBtnLeft.TextalignmentH     = "Center"
    titleBtnLeft.ShowAdditionalInfo = "Yes"
    titleBtnLeft.AdditionalInfo     = "                                                                                            by Christian Floyd Lewis"
    titleBtnLeft.BackColor          = BG_COLOR

    local closeBtn           = titleBar:Append("Button")
    closeBtn.Anchors         = "1,0"
    closeBtn.Texture         = "corner2"
    closeBtn.Icon            = "fader"
    closeBtn.Text            = ""
    closeBtn.TextalignmentH  = "Right"
    closeBtn.PluginComponent = myHandle
    closeBtn.Clicked         = "CloseUI"
    closeBtn.BackColor       = BG_COLOR

    local frame            = base:Append("DialogFrame")
    frame.Anchors          = { left = 0, right = 0, top = 1, bottom = 1 }
    frame.Columns          = 1
    frame.Rows             = 1
    frame[1][1].SizePolicy = "Stretch"
    frame.BackColor        = BG_COLOR

    local originX = FRAME_PAD_L
    local originY = FRAME_PAD_T

    local colParent = nil
    local colOffX   = 0
    local colOffY   = 0

    if useScroll then
        local scrollContainer   = frame:Append("ScrollContainer")
        scrollContainer.X       = originX
        scrollContainer.Y       = originY
        scrollContainer.W       = GRID_W + SCROLLBAR_W
        scrollContainer.H       = visGridH
        scrollContainer.Anchors = "0,0"

        local scrollBox = scrollContainer:Append("ScrollBox")

        local scrollBar        = frame:Append("ScrollBarV")
        scrollBar.X            = originX + GRID_W + 2
        scrollBar.Y            = originY
        scrollBar.W            = SCROLLBAR_W
        scrollBar.H            = visGridH
        scrollBar.ScrollTarget = scrollBox

        colParent = scrollBox
    else
        colParent = frame
        colOffX   = originX
        colOffY   = originY
    end

    for i, gm in ipairs(masters) do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        local x   = colOffX + col * COL_STEP
        local y   = colOffY + row * ROW_STEP

        local fader           = colParent:Append("UiFader")
        fader.W               = FADER_W
        fader.H               = FADER_H
        fader.X               = x
        fader.Y               = y
        fader.Target          = gm.group
        fader.Text            = gm.name
        fader.SignalValue     = tostring(i)
        fader.Changed         = "FaderChanged"
        fader.PluginComponent = myHandle

        faderEntries[i] = {
            fader   = fader,
            group   = gm.group,
            rawName = gm.rawName,
        }
    end
end

function Main()
    BuildUI()
end

return Main
