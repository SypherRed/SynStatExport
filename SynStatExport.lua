local addonName = ...

SynStatExportDB = SynStatExportDB or {
  lastExport = nil,
  history = {},
}

local EXPORT_HEADER = "!PESTATS!"
local MAX_HISTORY = 10
local ADDON_TITLE = "Synergy Loadout Master"
local CHAT_PREFIX = "|cff66d9efSLM Stat Export:|r "
local popupFrame = nil
local popupEditBox = nil

local function ensureDb()
  SynStatExportDB = SynStatExportDB or {}
  SynStatExportDB.lastExport = SynStatExportDB.lastExport or nil
  SynStatExportDB.history = SynStatExportDB.history or {}
end

local function chat(message)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(CHAT_PREFIX .. tostring(message))
  end
end

local function ensurePopup()
  if popupFrame then
    return popupFrame, popupEditBox
  end

  local frame = CreateFrame("Frame", "SynStatExportPopup", UIParent)
  frame:SetWidth(720)
  frame:SetHeight(220)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
  end)
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
  })
  frame:SetBackdropColor(0, 0, 0, 1)
  frame:Hide()

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -16)
  title:SetText(ADDON_TITLE .. " - Stat Export")

  local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", 20, -42)
  subtitle:SetPoint("TOPRIGHT", -20, -42)
  subtitle:SetJustifyH("LEFT")
  subtitle:SetText("The export string is selected automatically. Click inside the field and press Ctrl+C if needed.")

  local scrollFrame = CreateFrame("ScrollFrame", "SynStatExportPopupScroll", frame, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 20, -66)
  scrollFrame:SetPoint("BOTTOMRIGHT", -44, 52)

  local editBox = CreateFrame("EditBox", "SynStatExportPopupEditBox", scrollFrame)
  editBox:SetMultiLine(true)
  editBox:SetFontObject(ChatFontNormal)
  editBox:SetWidth(620)
  editBox:SetAutoFocus(false)
  editBox:EnableMouse(true)
  editBox:SetScript("OnEscapePressed", function()
    frame:Hide()
  end)
  editBox:SetScript("OnTextChanged", function(self)
    scrollFrame:UpdateScrollChildRect()
  end)
  editBox:SetScript("OnEditFocusGained", function(self)
    self:HighlightText()
  end)
  scrollFrame:SetScrollChild(editBox)

  local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  closeButton:SetPoint("TOPRIGHT", -6, -6)

  local selectButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  selectButton:SetWidth(110)
  selectButton:SetHeight(24)
  selectButton:SetPoint("BOTTOMRIGHT", -20, 18)
  selectButton:SetText("Select Text")
  selectButton:SetScript("OnClick", function()
    editBox:SetFocus()
    editBox:HighlightText()
  end)

  local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("BOTTOMLEFT", 20, 24)
  hint:SetText("Use /slmstats to export or /slmshow to reopen the latest string.")

  popupFrame = frame
  popupEditBox = editBox
  return popupFrame, popupEditBox
end

local function showSharePopup(shareString)
  local frame, editBox = ensurePopup()
  frame:Show()
  editBox:SetText(tostring(shareString or ""))
  editBox:SetFocus()
  editBox:HighlightText()
end

local function clampNumber(value, fallback)
  local numberValue = tonumber(value)
  if numberValue == nil then
    return fallback or 0
  end
  return numberValue
end

local function round(value, precision)
  local numberValue = clampNumber(value, 0)
  local factor = 10 ^ (precision or 0)
  return math.floor(numberValue * factor + 0.5) / factor
end

local function escapeJsonString(value)
  local input = tostring(value or "")
  input = input:gsub("\\", "\\\\")
  input = input:gsub("\"", "\\\"")
  input = input:gsub("\n", "\\n")
  input = input:gsub("\r", "\\r")
  input = input:gsub("\t", "\\t")
  return input
end

local function encodeJsonValue(value)
  local valueType = type(value)

  if valueType == "nil" then
    return "null"
  end
  if valueType == "boolean" then
    return value and "true" or "false"
  end
  if valueType == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      return "0"
    end
    return tostring(value)
  end
  if valueType == "string" then
    return "\"" .. escapeJsonString(value) .. "\""
  end
  if valueType ~= "table" then
    return "null"
  end

  local parts = {}
  for key, nestedValue in pairs(value) do
    parts[#parts + 1] = {
      key = tostring(key),
      value = encodeJsonValue(nestedValue),
    }
  end
  table.sort(parts, function(left, right)
    return left.key < right.key
  end)

  local encoded = {}
  for index = 1, #parts do
    encoded[#encoded + 1] = "\"" .. escapeJsonString(parts[index].key) .. "\":" .. parts[index].value
  end

  return "{" .. table.concat(encoded, ",") .. "}"
end

local function getUnitStatValue(unit, index)
  local base = select(1, UnitStat(unit, index))
  return clampNumber(base, 0)
end

local function getAttackPower()
  local base, positiveBuff, negativeBuff = UnitAttackPower("player")
  return clampNumber(base, 0) + clampNumber(positiveBuff, 0) + clampNumber(negativeBuff, 0)
end

local function getSpellPower()
  if type(GetSpellBonusHealing) == "function" then
    local healing = clampNumber(GetSpellBonusHealing(), 0)
    if healing > 0 then
      return healing
    end
  end

  if type(GetSpellBonusDamage) == "function" then
    local highest = 0
    for school = 1, 7 do
      highest = math.max(highest, clampNumber(GetSpellBonusDamage(school), 0))
    end
    return highest
  end

  return 0
end

local function getArmor()
  local _, effectiveArmor = UnitArmor("player")
  return clampNumber(effectiveArmor, 0)
end

local function getCritChance()
  if type(GetCritChance) == "function" then
    return round(GetCritChance(), 2)
  end
  return 0
end

local function getHaste()
  if type(GetHaste) == "function" then
    return round(GetHaste(), 2)
  end
  return 0
end

local function getHitChance()
  if type(GetHitModifier) == "function" then
    return round(GetHitModifier(), 2)
  end
  return 0
end

local function getResilience()
  if type(GetCombatRatingBonus) == "function" and type(CR_CRIT_TAKEN_MELEE) == "number" then
    return round(GetCombatRatingBonus(CR_CRIT_TAKEN_MELEE), 2)
  end
  return 0
end

local function collectStats()
  return {
    level = clampNumber(UnitLevel("player"), 1),
    sp = round(getSpellPower(), 2),
    ap = round(getAttackPower(), 2),
    armor = round(getArmor(), 2),
    stamina = clampNumber(getUnitStatValue("player", 3), 0),
    str = clampNumber(getUnitStatValue("player", 1), 0),
    agi = clampNumber(getUnitStatValue("player", 2), 0),
    sta = clampNumber(getUnitStatValue("player", 3), 0),
    int = clampNumber(getUnitStatValue("player", 4), 0),
    spi = clampNumber(getUnitStatValue("player", 5), 0),
    crit = getCritChance(),
    haste = getHaste(),
    hit = getHitChance(),
    resil = getResilience(),
  }
end

local function saveExport(stats)
  ensureDb()

  local payload = {
    version = 1,
    exportedAt = date("%Y-%m-%d %H:%M:%S"),
    character = UnitName("player") or "",
    realm = GetRealmName and GetRealmName() or "",
    class = select(2, UnitClass("player")) or "",
    stats = stats,
  }

  payload.share = EXPORT_HEADER .. encodeJsonValue(payload)
  SynStatExportDB.lastExport = payload

  table.insert(SynStatExportDB.history, 1, payload)
  while #SynStatExportDB.history > MAX_HISTORY do
    table.remove(SynStatExportDB.history)
  end

  return payload
end

local function exportStats()
  local payload = saveExport(collectStats())
  chat("Stats exported.")
  chat("Share string saved to SavedVariables under SynStatExportDB.lastExport.share")
  chat(string.format("Level %d | SP %s | AP %s | Crit %s | Haste %s", payload.stats.level, payload.stats.sp, payload.stats.ap, payload.stats.crit, payload.stats.haste))
  showSharePopup(payload.share)
end

local function showLastExport()
  ensureDb()
  if not SynStatExportDB.lastExport then
    chat("No export available yet. Use /slmstats first.")
    return
  end

  local exportData = SynStatExportDB.lastExport
  chat("Last export: " .. tostring(exportData.exportedAt or "unknown"))
  chat("Character: " .. tostring(exportData.character or "") .. " - " .. tostring(exportData.realm or ""))
  showSharePopup(exportData.share)
end

local function printHelp()
  chat("Commands:")
  chat("/slmstats - Collect current character stats and open the export popup")
  chat("/slmshow - Reopen the latest export popup")
  chat("/slmstats help - Show this help")
end

SLASH_SLMSTATEXPORT1 = "/slmstats"
SlashCmdList["SLMSTATEXPORT"] = function(message)
  local command = string.lower((message or ""):match("^%s*(.-)%s*$") or "")

  if command == "" or command == "export" then
    exportStats()
    return
  end

  if command == "help" then
    printHelp()
    return
  end

  chat("Unknown command: " .. tostring(command))
  printHelp()
end

SLASH_SLMSHOW1 = "/slmshow"
SlashCmdList["SLMSHOW"] = function()
  ensureDb()
  if not SynStatExportDB.lastExport or not SynStatExportDB.lastExport.share then
    chat("No export available yet. Use /slmstats first.")
    return
  end
  showLastExport()
end
