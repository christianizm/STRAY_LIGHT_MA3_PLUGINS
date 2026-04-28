-- Set Fixture Channel Defaults
-- Logic by CHRISTIAN FLOYD LEWIS *STRAY LIGHT*

--titlebar 'close' button set as a rescan instead...

local pluginName    = select(1, ...)
local componentName = select(2, ...)
local signalTable   = select(3, ...)
local myHandle      = select(4, ...)

local BTN_H         = 55
local GAP_X         = 3
local GAP_Y         = 5
local TITLE_H       = 50
local INFO_H        = 60
local HEADER_H      = 35
local PAD_L         = 0
local PAD_T         = 0
local PAD_R         = 10
local PAD_B         = 5
local FRAME_PAD_L   = 5
local FRAME_PAD_T   = 10
local FRAME_PAD_R   = 22
local FRAME_PAD_B   = 1
local BTN_GAP_TOP   = 10

local COL_LABEL_W   = 300
local COL_VALUE_W   = 130
local COL_BTN_W     = 90
local GRID_W        = COL_LABEL_W + GAP_X + COL_VALUE_W + GAP_X + COL_BTN_W
local BOTTOM_W      = (GRID_W - GAP_X * 2) / 3


local MAX_GRID_H    = 600


local attrData        = {}
local toggleStates    = {}
local toggleBtnEls    = {}
local ftName          = ""
local ftNo            = ""
local modeName        = ""
local keepActive      = true
local keepActiveBtnEl = nil

local function getFixtureInfo()
    local patchIndex = SelectionFirst()
    if not patchIndex then return nil end

    local subFixture = GetSubfixture(patchIndex)
    if not subFixture then return nil end

    local fixture = subFixture:Get('Fixture')
    if not fixture then return nil end

    local fixtureType = fixture.FixtureType
    if not fixtureType then return nil end

    local modeRaw    = tostring(fixture.Mode or "")
    local modeString = modeRaw:match("^%d+%s+(.+)$") or modeRaw
    local dmxMode    = nil
    local modeCount  = fixtureType.DMXModes:Count()
    for i = 1, modeCount do
        local m = fixtureType.DMXModes[i]
        if m and tostring(m.Name) == modeString then
            dmxMode = m
            break
        end
    end
    if not dmxMode then
        dmxMode = fixtureType.DMXModes[1]
    end

    return {
        patchIndex = patchIndex,
        ftName     = fixtureType.Name,
        ftNo       = fixtureType.No,
        modeName   = dmxMode.Name,
        dmxMode    = dmxMode,
    }
end

local function buildAttrToChanMap(dmxMode)
    local map   = {}
    local count = dmxMode.DMXChannels:Count()
    for i = 1, count do
        local chan = dmxMode.DMXChannels[i]
        if chan then
            local chanName = chan.Name or ""
            local ok, logChan = pcall(function()
                return chan:Children()[1]
            end)
            if ok and logChan then
                local attrName = logChan.Attribute or ""
                if attrName ~= "" and chanName ~= "" then
                    if not map[attrName] then
                        map[attrName] = {}
                    end
                    table.insert(map[attrName], chanName)
                end
            end
        end
    end
    return map
end

local function findAllProgAttrs(mainPatchIndex, dmxMode)
    local results   = {}
    local attrCount = GetAttributeCount()
    local sources   = {}

    local function collectSources(handle, sourceName)
        local ok, sfIdx = pcall(function()
            return handle:Get("SubfixtureIndex")
        end)
        if ok and sfIdx then
            table.insert(sources, {
                patchIdx   = sfIdx,
                sourceName = sourceName,
                isMain     = false,
            })
        end
        local children = handle:Children()
        for i = 1, #children do
            local child     = children[i]
            local rawName   = child.Name or ("Child" .. i)
            local cleanName = rawName:match("^%[(.-)%]$") or rawName
            collectSources(child, cleanName)
        end
    end

    local sf = GetSubfixture(mainPatchIndex)
    if sf then
        table.insert(sources, {
            patchIdx   = mainPatchIndex,
            sourceName = sf.Name or "Main",
            isMain     = true,
        })
        local children = sf:Children()
        for i = 1, #children do
            local child     = children[i]
            local rawName   = child.Name or ("Child" .. i)
            local cleanName = rawName:match("^%[(.-)%]$") or rawName
            collectSources(child, cleanName)
        end
    end

    local attrToChan = buildAttrToChanMap(dmxMode)
    local seen       = {}

    for _, source in ipairs(sources) do
        for attrIdx = 0, attrCount - 1 do
            local uich = GetUIChannelIndex(source.patchIdx, attrIdx)
            if uich then
                local data = GetProgPhaser(uich)
                if data and data[1] then
                    local ah = GetAttributeByUIChannel(uich)
                    if ah then
                        local name = ah.Name or ""
                        local key  = source.sourceName .. "_" .. name
                        if name ~= "" and not seen[key] then
                            local chanNames = attrToChan[name]
                            if chanNames and #chanNames > 0 then
                                seen[key] = true

                                table.insert(results, {
                                    label          = source.isMain and name or (source.sourceName .. " : " .. name),
                                    chanNames      = chanNames,
                                    value          = data[1].absolute,
                                    absolute_value = data[1].absolute_value,
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    return results
end

signalTable.ToggleAttr = function(caller)
    local sv  = caller.SignalValue or ""
    local idx = tonumber(sv)
    if not idx then return end

    toggleStates[idx] = not toggleStates[idx]
    local el = toggleBtnEls[idx]
    if el then
        el.Icon = toggleStates[idx] and "CheckboxChecked" or "CheckboxUnchecked"
    end
end

signalTable.ToggleKeepActive = function(caller)
    keepActive = not keepActive
    if keepActiveBtnEl then
        keepActiveBtnEl.State = keepActive and 1 or 0
    end
end

signalTable.ApplyDefaults = function(caller)
    local selected = {}
    for i, entry in ipairs(attrData) do
        if toggleStates[i] then
            table.insert(selected, entry)
        end
    end

    if #selected == 0 then
        Confirm("Set Fixture Defaults", "No attributes selected.")
        return
    end

    local count = 0
    local lines = {}
    for _, entry in ipairs(selected) do
        local dmxVal = math.min(255, math.max(0, math.floor((entry.absolute_value / 16777216) * 255 + 0.5)))
        for _, chanName in ipairs(entry.chanNames) do
            local cmd = string.format(
                'Set FixtureType %s.DMXModes."%s".DMXChannels."%s" "DEFAULT" "%s"',
                ftNo, modeName, chanName, tostring(dmxVal)
            )

            Cmd(cmd)
        end
        count = count + 1
        table.insert(lines, string.format(
            "  %s  →  %.1f%%  (%d/255)",
            entry.label, entry.value, dmxVal))
    end

    if not keepActive then
        Cmd("ClearAll")
    end

    local display = GetFocusDisplay()
    display.ScreenOverlay:ClearUIChildren()
    attrData        = {}
    toggleStates    = {}
    toggleBtnEls    = {}
    keepActiveBtnEl = nil

    local summary = string.format(
        "Applied %d default%s to\n%s / %s\n\n%s",
        count, count == 1 and "" or "s",
        ftName, modeName,
        table.concat(lines, "\n")
    )

    CmdIndirect("Off Plugin '" .. pluginName .. "'")
    MessageBox({
        title   = "Set Fixture Defaults",
        message = summary,
        timeout = 2000,
    })
end

signalTable.RescanUI = function(caller)
    CmdIndirect("Call Plugin '" .. pluginName .. "'")
end

signalTable.CloseUI = function(caller)
    attrData        = {}
    toggleStates    = {}
    toggleBtnEls    = {}
    keepActiveBtnEl = nil
    local display = GetFocusDisplay()
    display.ScreenOverlay:ClearUIChildren()
    CmdIndirect("Off Plugin '" .. pluginName .. "'")
end

local function BuildUI()

    attrData        = {}
    toggleStates    = {}
    toggleBtnEls    = {}
    keepActiveBtnEl = nil
    ftName          = ""
    ftNo            = ""
    modeName        = ""

    local info = getFixtureInfo()
    if not info then
        Confirm("Set Fixture Defaults", "No fixture selected.")
        return
    end

    ftName   = info.ftName
    ftNo     = info.ftNo
    modeName = info.modeName

    local allAttrs = findAllProgAttrs(info.patchIndex, info.dmxMode)
    for _, entry in ipairs(allAttrs) do
        table.insert(attrData, entry)
        table.insert(toggleStates, false)
    end

    if #attrData == 0 then
        Confirm("Set Fixture Defaults",
            "No programmer values found.\nSet values in programmer first.")
        return
    end

    local ROW_COUNT    = #attrData
    local gridH        = (ROW_COUNT * BTN_H) + ((ROW_COUNT - 1) * GAP_Y)
    local useScroll    = gridH > MAX_GRID_H
    local visibleGridH = useScroll and MAX_GRID_H or gridH

    local dialogW = GRID_W + PAD_L + PAD_R + FRAME_PAD_L + FRAME_PAD_R
    local dialogH = TITLE_H + INFO_H + HEADER_H
                  + visibleGridH
                  + BTN_GAP_TOP + BTN_H
                  + PAD_T + PAD_B + FRAME_PAD_T + FRAME_PAD_B + 20

    local display = GetFocusDisplay()
    local overlay = display.ScreenOverlay
    overlay:ClearUIChildren()

    local base = overlay:Append("BaseInput")
    base.W                = dialogW
    base.H                = dialogH
    base.Columns          = 1
    base.Rows             = 2
    base[1][1].SizePolicy = "Fixed"
    base[1][1].Size       = TITLE_H
    base[1][2].SizePolicy = "Stretch"
    base.AutoClose        = "No"
    base.CloseOnEscape    = "Yes"

    local titleBar = base:Append("TitleBar")
    titleBar.Columns          = 2
    titleBar.Rows             = 1
    titleBar.Anchors          = "0,0"
    titleBar[2][2].SizePolicy = "Fixed"
    titleBar[2][2].Size       = 55
    titleBar.Texture          = "corner2"

    local titleBtnLeft = titleBar:Append("TitleButton")
    titleBtnLeft.Anchors            = "0,0"
    titleBtnLeft.Icon               = "setup_patch"
    titleBtnLeft.Texture            = "corner1"
    titleBtnLeft.Text               = "< SET CHANNEL DEFAULT >"
    titleBtnLeft.TextalignmentH     = "Center"
    titleBtnLeft.ShowAdditionalInfo = "Yes"
    titleBtnLeft.AdditionalInfo     =
        "                                by Christian Floyd Lewis"

    local titleBtnRight = titleBar:Append("TitleButton")
    titleBtnRight.Anchors         = "1,0"
    titleBtnRight.Texture         = "corner2"
    titleBtnRight.Icon            = "setup_patch"
    titleBtnRight.Text            = "Rescan"
    titleBtnRight.PluginComponent = myHandle
    titleBtnRight.Clicked         = "RescanUI"

    local frame = base:Append("DialogFrame")
    frame.Anchors          = { left=0, right=0, top=1, bottom=1 }
    frame.Columns          = 1
    frame.Rows             = 1
    frame[1][1].SizePolicy = "Stretch"

    local originX = PAD_L + FRAME_PAD_L
    local originY = PAD_T + FRAME_PAD_T

    local ftLabel = frame:Append("UIObject")
    ftLabel.X              = originX
    ftLabel.Y              = originY - 4
    ftLabel.W              = GRID_W
    ftLabel.H              = INFO_H
    ftLabel.Font           = "Medium20"
    ftLabel.TextalignmentH = "Centre"
    ftLabel.TextalignmentV = "Centre"
    ftLabel.HasHover       = "No"
    ftLabel.BackColor      = Root().ColorTheme.ColorGroups.Global.Transparent
    ftLabel.Text           = ftName .. "  |  " .. modeName

    local headerY = originY - 4 + INFO_H

    local hLabel = frame:Append("UIObject")
    hLabel.X              = originX
    hLabel.Y              = headerY
    hLabel.W              = COL_LABEL_W
    hLabel.H              = HEADER_H
    hLabel.TextalignmentH = "Centre"
    hLabel.TextalignmentV = "Top"
    hLabel.HasHover       = "No"
    hLabel.BackColor      = Root().ColorTheme.ColorGroups.Global.Transparent
    hLabel.Text           = "Attribute"

    local hValue = frame:Append("UIObject")
    hValue.X              = originX + COL_LABEL_W + GAP_X
    hValue.Y              = headerY
    hValue.W              = COL_VALUE_W
    hValue.H              = HEADER_H
    hValue.TextalignmentH = "Centre"
    hValue.TextalignmentV = "Top"
    hValue.HasHover       = "No"
    hValue.BackColor      = Root().ColorTheme.ColorGroups.Global.Transparent
    hValue.Text           = "Value %"

    local hSelect = frame:Append("UIObject")
    hSelect.X              = originX + COL_LABEL_W + GAP_X + COL_VALUE_W + GAP_X
    hSelect.Y              = headerY
    hSelect.W              = COL_BTN_W
    hSelect.H              = HEADER_H
    hSelect.TextalignmentH = "Centre"
    hSelect.TextalignmentV = "Top"
    hSelect.HasHover       = "No"
    hSelect.BackColor      = Root().ColorTheme.ColorGroups.Global.Transparent
    hSelect.Text           = ""

    local rowParent
    local scrollBox = nil

    if useScroll then
        local scrollContainer = frame:Append("ScrollContainer")
        scrollContainer.X       = originX
        scrollContainer.Y       = headerY + HEADER_H
        scrollContainer.W       = GRID_W + PAD_R + FRAME_PAD_R
        scrollContainer.H       = visibleGridH
        scrollContainer.Anchors = "0,0"

        scrollBox = scrollContainer:Append("ScrollBox")

        local scrollBar = frame:Append("ScrollBarV")
        scrollBar.X            = originX
        scrollBar.Y            = headerY + HEADER_H
        scrollBar.W            = 20
        scrollBar.H            = visibleGridH
        scrollBar.AlignmentH   = "Right"
        scrollBar.ScrollTarget = scrollBox

        rowParent = scrollBox
    else
        rowParent = frame
    end

    local rowOriginY = useScroll and 0 or (headerY + HEADER_H)
    local colOffsetX = useScroll and 0 or originX

    for i, entry in ipairs(attrData) do
        local rowY = rowOriginY + (i - 1) * (BTN_H + GAP_Y)

        local lbl = rowParent:Append("UIObject")
        lbl.X              = colOffsetX
        lbl.Y              = rowY
        lbl.W              = COL_LABEL_W
        lbl.H              = BTN_H
        lbl.Font           = "Medium20"
        lbl.TextalignmentH = "Centre"
        lbl.TextalignmentV = "Centre"
        lbl.HasHover       = "No"
        lbl.BackColor      = Root().ColorTheme.ColorGroups.Global.Transparent
        lbl.Text           = entry.label

        local val = rowParent:Append("UIObject")
        val.X              = colOffsetX + COL_LABEL_W + GAP_X
        val.Y              = rowY
        val.W              = COL_VALUE_W
        val.H              = BTN_H
        val.Font           = "Medium20"
        val.TextalignmentH = "Centre"
        val.TextalignmentV = "Centre"
        val.HasHover       = "No"
        val.BackColor      = Root().ColorTheme.ColorGroups.Global.Transparent
        val.Text           = string.format("%.1f%%  (%d)", entry.value,
                                math.min(255, math.max(0, math.floor((entry.absolute_value / 16777216) * 255 + 0.5))))

        local btn = rowParent:Append("Button")
        btn.X               = colOffsetX + COL_LABEL_W + GAP_X + COL_VALUE_W + GAP_X
        btn.Y               = rowY
        btn.W               = COL_BTN_W
        btn.H               = BTN_H
        btn.Text            = ""
        btn.Icon            = "CheckboxUnchecked"
        btn.Font            = "Medium20"
        btn.TextalignmentH  = "Centre"
        btn.TextalignmentV  = "Centre"
        btn.HasHover        = "Yes"
        btn.Textshadow      = 0
        btn.Texture         = ""
        btn.BackColor       = Root().ColorTheme.ColorGroups.Global.Transparent
        btn.SignalValue     = tostring(i)
        btn.PluginComponent = myHandle
        btn.Clicked         = "ToggleAttr"

        toggleBtnEls[i] = btn
    end

    local bottomY = headerY + HEADER_H + visibleGridH + BTN_GAP_TOP

    local confirmBtn = frame:Append("Button")
    confirmBtn.X               = originX
    confirmBtn.Y               = bottomY
    confirmBtn.W               = BOTTOM_W
    confirmBtn.H               = BTN_H
    confirmBtn.Text            = "Update"
    confirmBtn.Font            = "Medium20"
    confirmBtn.TextalignmentH  = "Centre"
    confirmBtn.TextalignmentV  = "Centre"
    confirmBtn.HasHover        = "Yes"
    confirmBtn.Texture         = "corner15"
    confirmBtn.Textshadow      = 0
    confirmBtn.PluginComponent = myHandle
    confirmBtn.Clicked         = "ApplyDefaults"

    local keepActiveBtn = frame:Append("Button")
    keepActiveBtn.X               = originX + BOTTOM_W + GAP_X
    keepActiveBtn.Y               = bottomY
    keepActiveBtn.W               = BOTTOM_W
    keepActiveBtn.H               = BTN_H
    keepActiveBtn.Text            = "Keep Active"
    keepActiveBtn.Font            = "Medium20"
    keepActiveBtn.TextalignmentH  = "Centre"
    keepActiveBtn.TextalignmentV  = "Centre"
    keepActiveBtn.HasHover        = "Yes"
    keepActiveBtn.Texture         = "corner15"
    keepActiveBtn.Textshadow      = 0
    keepActiveBtn.State           = keepActive and 1 or 0
    keepActiveBtn.PluginComponent = myHandle
    keepActiveBtn.Clicked         = "ToggleKeepActive"

    keepActiveBtnEl = keepActiveBtn

    local cancelBtn = frame:Append("Button")
    cancelBtn.X               = originX + (BOTTOM_W + GAP_X) * 2
    cancelBtn.Y               = bottomY
    cancelBtn.W               = BOTTOM_W
    cancelBtn.H               = BTN_H
    cancelBtn.Text            = "Cancel"
    cancelBtn.Font            = "Medium20"
    cancelBtn.TextalignmentH  = "Centre"
    cancelBtn.TextalignmentV  = "Centre"
    cancelBtn.HasHover        = "Yes"
    cancelBtn.Texture         = "corner15"
    cancelBtn.Textshadow      = 1
    cancelBtn.PluginComponent = myHandle
    cancelBtn.Clicked         = "CloseUI"
end

return BuildUI