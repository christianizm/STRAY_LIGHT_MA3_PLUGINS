-- Pan Tilt Encoder DMX Inverter
-- Logic by CHRISTIAN FLOYD LEWIS *STRAY LIGHT*

local pluginName    = select(1, ...)
local componentName = select(2, ...)
local signalTable   = select(3, ...)
local myHandle      = select(4, ...)

local BTN_H       = 70
local GAP_X       = 3
local GAP_Y       = 10
local TITLE_H     = 45
local INFO_H      = 45
local PAD_L       = 0
local PAD_T       = 0
local PAD_R       = 10
local PAD_B       = 5
local FRAME_PAD_L = 5
local FRAME_PAD_T = 27
local FRAME_PAD_R = 22
local FRAME_PAD_B = 13
local BG_COLOR_1    = "Global.ToolboxColor_12"
local BG_COLOR_2    = "Global.DimmerBtn_1"

local BTN_COUNT = 3
local GRID_W    = (BTN_COUNT * 170) + ((BTN_COUNT - 1) * GAP_X)

local ROWS = {
  {
    rowType = "ENC",
    buttons = {
      { text = "Encoder\nReverse Pan",  action = "Pan"  },
      { text = "Encoder\nReverse Tilt", action = "Tilt" },
      { text = "Encoder\nInfo",          action = "Info" },
    },
  },
  {
    rowType = "DMX",
    buttons = {
      { text = "DMX\nReverse Pan",  action = "Pan"  },
      { text = "DMX\nReverse Tilt", action = "Tilt" },
      { text = "DMX\nInfo",          action = "Info" },
    },
  },
}

local rowState = {
  ENC = { Pan = false, Tilt = false },
  DMX = { Pan = false, Tilt = false },
}

local btnElements = {}

local infoLabelEl = nil

local function refreshRowButtons(rowType)
  local state = rowState[rowType]
  for _, action in ipairs({ "Pan", "Tilt" }) do
    local el = btnElements[rowType .. "_" .. action]
    if el then
      el.State = state[action] and 1 or 0
    end
  end
end

local function resetAllStates()
  for _, rowType in ipairs({ "ENC", "DMX" }) do
    rowState[rowType] = { Pan = false, Tilt = false }
    refreshRowButtons(rowType)
  end
end

local function refreshInfoLabel()
  if not infoLabelEl then return end
  local selCount = SelectionCount()
  if selCount == 0 then
    infoLabelEl.Text = "⚠  NO FIXTURES SELECTED"
  else
    infoLabelEl.Text = string.format(
      "Selection:   %d Fixture%s", selCount, selCount == 1 and "" or "s")
  end
end

local function getSelection()
  local fixtures = {}
  local index    = SelectionFirst()
  if not index then return nil end
  while index do
    local handle = GetSubfixture(index)
    if handle then
      table.insert(fixtures, {
        handle = handle,
        addr   = handle:ToAddr(),
        name   = handle.NAME or "Unknown",
      })
    end
    index = SelectionNext(index)
  end
  if #fixtures == 0 then return nil end
  return fixtures
end

local function applyEncoder(doPan, doTilt, fixtures)
  local count = 0
  for _, item in ipairs(fixtures) do
    local h = item.handle
    if h then
      if doPan  then h.EncInvertPan  = not h.EncInvertPan  end
      if doTilt then h.EncInvertTilt = not h.EncInvertTilt end
      count = count + 1
    end
  end
  return count
end

local function applyDMX(doPan, doTilt, fixtures)
  local count = 0
  for _, item in ipairs(fixtures) do
    local h = item.handle
    if h then
      if doPan  then h.DMXINVERTPAN  = not h.DMXINVERTPAN  end
      if doTilt then h.DMXINVERTTILT = not h.DMXINVERTTILT end
      count = count + 1
    end
  end
  return count
end

local function showEncoderInfo()
  local fixtures = getSelection()
  if not fixtures then Confirm("Error", "No fixtures selected.") return end
  local limit = math.min(#fixtures, 30)
  local lines = { "Encoder Invert Status:\n" }
  for i = 1, limit do
    local f    = fixtures[i]
    local pVal = f.handle.EncInvertPan
    local tVal = f.handle.EncInvertTilt
    lines[#lines + 1] = string.format(
      "%s (%s):  Pan=%s  Tilt=%s",
      f.name, f.addr,
      (pVal == true) and "ON" or "OFF",
      (tVal == true) and "ON" or "OFF"
    )
  end
  if #fixtures > 30 then
    lines[#lines + 1] = string.format("...and %d more.", #fixtures - 30)
  end
  MessageBox({
    title    = "Encoder Inverter — Encoder Status",
    message  = table.concat(lines, "\n"),
    commands = { { value = 1, name = "OK" } },
  })
end

local function showDMXInfo()
  local fixtures = getSelection()
  if not fixtures then Confirm("Error", "No fixtures selected.") return end
  local limit = math.min(#fixtures, 30)
  local lines = { "DMX Invert Status:\n" }
  for i = 1, limit do
    local f    = fixtures[i]
    local pVal = f.handle.DMXINVERTPAN
    local tVal = f.handle.DMXINVERTTILT
    lines[#lines + 1] = string.format(
      "%s (%s):  Pan=%s  Tilt=%s",
      f.name, f.addr,
      (pVal == true) and "ON" or "OFF",
      (tVal == true) and "ON" or "OFF"
    )
  end
  if #fixtures > 30 then
    lines[#lines + 1] = string.format("...and %d more.", #fixtures - 30)
  end
  MessageBox({
    title    = "Encoder Inverter — DMX Status",
    message  = table.concat(lines, "\n"),
    commands = { { value = 1, name = "OK" } },
  })
end

signalTable.ButtonPressed = function(caller)
  local sv              = caller.SignalValue or ""
  local rowType, action = sv:match("^([^_]+)_(.+)$")
  if not rowType or not action then return end

  if action == "Info" then
    if rowType == "ENC" then showEncoderInfo()
    else                     showDMXInfo()
    end
    return
  end

  if action == "Pan" or action == "Tilt" then
    rowState[rowType][action] = not rowState[rowType][action]
    refreshRowButtons(rowType)
  end
end

signalTable.ApplyAction = function(caller)

  refreshInfoLabel()

  local encPan  = rowState.ENC.Pan
  local encTilt = rowState.ENC.Tilt
  local dmxPan  = rowState.DMX.Pan
  local dmxTilt = rowState.DMX.Tilt

  if not encPan and not encTilt and not dmxPan and not dmxTilt then
    Confirm("Encoder Inverter", "No actions selected.")
    return
  end

  local fixtures = getSelection()
  if not fixtures then
    refreshInfoLabel()
    return
  end

  local parts = {}

  if encPan or encTilt then
    local c    = applyEncoder(encPan, encTilt, fixtures)
    local axes = (encPan and encTilt) and "Pan + Tilt" or (encPan and "Pan" or "Tilt")
    parts[#parts + 1] = string.format(
      "Encoder %s → %d fixture%s", axes, c, c == 1 and "" or "s")
  end

  if dmxPan or dmxTilt then
    local c    = applyDMX(dmxPan, dmxTilt, fixtures)
    local axes = (dmxPan and dmxTilt) and "Pan + Tilt" or (dmxPan and "Pan" or "Tilt")
    parts[#parts + 1] = string.format(
      "DMX %s → %d fixture%s", axes, c, c == 1 and "" or "s")
  end

  local display = GetFocusDisplay()
  display.ScreenOverlay:ClearUIChildren()
  btnElements  = {}
  infoLabelEl  = nil
  resetAllStates()
  Confirm("Encoder Inverter", table.concat(parts, "\n"))
end

signalTable.CloseUI = function(caller)
  btnElements = {}
  infoLabelEl = nil
  rowState = {
    ENC = { Pan = false, Tilt = false },
    DMX = { Pan = false, Tilt = false },
  }
  CmdIndirect("Off Plugin 'P/T Inverter'")
  local display = GetFocusDisplay()
  display.ScreenOverlay:ClearUIChildren()
end

local function BuildUI()

  btnElements = {}
  infoLabelEl = nil
  rowState = {
    ENC = { Pan = false, Tilt = false },
    DMX = { Pan = false, Tilt = false },
  }

  local display = GetFocusDisplay()
  local overlay = display.ScreenOverlay
  overlay:ClearUIChildren()

  local ROW_COUNT = #ROWS
  local gridH     = (ROW_COUNT * BTN_H) + ((ROW_COUNT - 1) * GAP_Y)
  local BOTTOM_W  = (GRID_W - GAP_X) / 2

  local dialogW = GRID_W + PAD_L + PAD_R + FRAME_PAD_L + FRAME_PAD_R
  local dialogH = TITLE_H + INFO_H
              + gridH
              + GAP_Y + BTN_H
              + PAD_T + PAD_B + FRAME_PAD_T + FRAME_PAD_B + 20

  local base = overlay:Append("BaseInput")
  base.W             = dialogW
  base.H             = dialogH
  base.Columns       = 1
  base.Rows          = 2
  base[1][1].SizePolicy = "Fixed"
  base[1][1].Size       = TITLE_H
  base[1][2].SizePolicy = "Stretch"
  base.AutoClose     = "No"
  base.CloseOnEscape = "Yes"

  local titleBar = base:Append("TitleBar")
  titleBar.Columns  = 2
  titleBar.Rows     = 1
  titleBar.Anchors  = "0,0"
  titleBar[2][2].SizePolicy = "Fixed"
  titleBar[2][2].Size       = 50
  titleBar.Texture  = "corner2"

  local titleBtnLeft = titleBar:Append("TitleButton")
  titleBtnLeft.Anchors            = "0,0"
  titleBtnLeft.Texture            = "corner1"
  titleBtnLeft.Icon               = "encoder_sym_24px"
  titleBtnLeft.Text               = "P/T INVERTER"
  titleBtnLeft.TextalignmentH     = "Center"
  titleBtnLeft.ShowAdditionalInfo = "Yes"
  titleBtnLeft.AdditionalInfo     =
    "                                by Christian Floyd Lewis"

  local titleBtnRight = titleBar:Append("TitleButton")
  titleBtnRight.Anchors = "1,0"
  titleBtnRight.Texture = "corner2"
  titleBtnRight.Icon    = "encoder_sym_24px"

  local frame = base:Append("DialogFrame")
  frame.Anchors          = { left=0, right=0, top=1, bottom=1 }
  frame.Columns          = 1
  frame.Rows             = 1
  frame[1][1].SizePolicy = "Stretch"

  local originX = PAD_L + FRAME_PAD_L
  local originY = PAD_T + FRAME_PAD_T

  local selCount = SelectionCount()
  infoLabelEl = frame:Append("UIObject")
  infoLabelEl.X              = originX
  infoLabelEl.Y              = originY - 4
  infoLabelEl.W              = GRID_W
  infoLabelEl.H              = INFO_H
  infoLabelEl.Font           = selCount == 0 and "Medium16" or "Medium20"
  infoLabelEl.TextalignmentH = "Centre"
  infoLabelEl.TextalignmentV = "Top"
  infoLabelEl.HasHover       = "No"
  infoLabelEl.BackColor      = Root().ColorTheme.ColorGroups.Global.Transparent
  refreshInfoLabel()

  local btnW       = (GRID_W - (BTN_COUNT - 1) * GAP_X) / BTN_COUNT
  local rowOriginY = originY + INFO_H

  for r, row in ipairs(ROWS) do
    local rowY = rowOriginY + (r - 1) * (BTN_H + GAP_Y)
    for c, btnDef in ipairs(row.buttons) do
      local btn = frame:Append("Button")
      btn.W               = btnW
      btn.H               = BTN_H
      btn.X               = originX + (c - 1) * (btnW + GAP_X)
      btn.Y               = rowY
      btn.Text            = btnDef.text
      btn.Font            = "Medium20"
      btn.TextalignmentH  = "Centre"
      btn.TextalignmentV  = "Centre"
      btn.HasHover        = "Yes"
      btn.Textshadow      = 0
      btn.SignalValue     = row.rowType .. "_" .. btnDef.action
      btn.PluginComponent = myHandle
      btn.Clicked         = "ButtonPressed"
      btn.Texture         = "corner15"

      if btnDef.action == "Pan" or btnDef.action == "Tilt" then
        btnElements[row.rowType .. "_" .. btnDef.action] = btn
      end
    end
  end

  local bottomY = rowOriginY + ROW_COUNT * (BTN_H + GAP_Y)

  local applyBtn = frame:Append("Button")
  applyBtn.X               = originX
  applyBtn.Y               = bottomY
  applyBtn.W               = BOTTOM_W
  applyBtn.H               = BTN_H
  applyBtn.Text            = "Apply"
  applyBtn.Font            = "Medium20"
  applyBtn.TextalignmentH  = "Centre"
  applyBtn.TextalignmentV  = "Centre"
  applyBtn.HasHover        = "Yes"
  applyBtn.Texture         = "corner15"
  applyBtn.Textshadow      = 0
  applyBtn.PluginComponent = myHandle
  applyBtn.Clicked         = "ApplyAction"

  local cancelBtn = frame:Append("Button")
  cancelBtn.X               = originX + BOTTOM_W + GAP_X
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