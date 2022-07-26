local TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon

---@class RsRestockerModule
local restockerModule = RsModule.DeclareModule("Restocker") ---@type RsRestockerModule

local list = {} ---@type table<number, RsRestockItem>

local bankModule = RsModule.Import("Bank") ---@type RsBankModule
local eventsModule = RsModule.Import("Events") ---@type RsEventsModule
local merchantModule = RsModule.Import("Merchant") ---@type RsMerchantModule

local RS = LibStub("AceAddon-3.0"):NewAddon(
    "Restocker", "AceConsole-3.0", "AceEvent-3.0") ---@type RestockerAddon
RS_ADDON = RS ---@type RestockerAddon

RS.defaults = {
  prefix = "|cff8d63ffRestocker|r ",
  color  = "8d63ff",
  slash  = "|cff8d63ff/rs|r "
}

RS.BAG_ICON = "Interface\\ICONS\\INV_Misc_Bag_10_Green" -- bag icon for add tooltip

--function RS.Print(...)
--  DEFAULT_CHAT_FRAME:AddMessage(RS.addonName .. "- " .. tostringall(...))
--end

RS.slashPrefix = "|cff8d63ff/restocker|r "
RS.addonName = "|cff8d63ffRestocker|r "

--- Addon is running on Classic TBC client
RS.IsTBC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
--- Addon is running on Classic "Vanilla" client: Means Classic Era and its seasons like SoM
RS.IsClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
--- Addon is running on Classic "Vanilla" client and on Era realm
RS.IsEra = RS.IsClassic and (not C_Seasons.HasActiveSeason())
--- Addon is running on Classic "Vanilla" client and on Seasons of Mastery realm
RS.IsSoM = RS.IsClassic and C_Seasons.HasActiveSeason() and (C_Seasons.GetActiveSeason() == Enum.SeasonID.SeasonOfMastery)

function RS:Show()
  if RS.loaded then
    local menu = RS.MainFrame or RS:CreateMenu();
    menu:Show()
    return RS:Update()
  end
end

function RS:Hide()
  if RS.loaded then
    local menu = RS.MainFrame or RS:CreateMenu();
    return menu:Hide()
  end
end

function RS:Toggle()
  if RS.loaded then
    local menu = RS.MainFrame or RS:CreateMenu();
    return menu:SetShown(not menu:IsShown()) or false
  end
end

RS.commands = {
  show    = RS.defaults.slash .. "show - Show the addon",
  profile = {
    add    = RS.defaults.slash .. "profile add [name] - Adds a profile with [name]",
    delete = RS.defaults.slash .. "profile delete [name] - Deletes profile with [name]",
    rename = RS.defaults.slash .. "profile rename [name] - Renames current profile to [name]",
    copy   = RS.defaults.slash .. "profile copy [name] - Copies profile [name] into current profile.",
    config = RS.defaults.slash .. "config - Opens the interface options menu."
  }
}

--[[
  SLASH COMMANDS
]]
function RS:SlashCommand(args)
  local command, rest = strsplit(" ", args, 2)
  command = command:lower()

  if command == "show" then
    RS:Show()

  elseif command == "profile" then
    if rest == "" or rest == nil then
      for _, v in pairs(RS.commands.profile) do
        RS:Print(v)
      end
      return
    end

    local subcommand, name = strsplit(" ", rest, 2)

    if subcommand == "add" then
      RS:AddProfile(name)

    elseif subcommand == "delete" then
      RS:DeleteProfile(name)

    elseif subcommand == "rename" then
      RS:RenameCurrentProfile(name)

    elseif subcommand == "copy" then
      RS:CopyProfile(name)
    end

  elseif command == "help" then

    for _, v in pairs(RS.commands) do
      if type(v) == "table" then
        for _, vv in pairs(v) do
          RS:Print(vv)
        end
      else
        RS:Print(v)
      end
    end
    return

  elseif command == "config" then
    InterfaceOptionsFrame_OpenToCategory(RS.optionsPanel)
    InterfaceOptionsFrame_OpenToCategory(RS.optionsPanel)
    return

  else
    RS:Toggle()
  end
  RS:Update()
end


--[[
  UPDATE
]]
function RS:Update()
  local currentProfile = RestockerSettings.profiles[RestockerSettings.currentProfile]
  wipe(list)

  for i, v in ipairs(currentProfile) do
    tinsert(list, v)
  end

  if RS.sortListAlphabetically then
    table.sort(list, function(a, b)
      return a.itemName < b.itemName
    end)

  elseif RS.sortListNumerically then
    table.sort(list, function(a, b)
      return a.amount > b.amount
    end)
  end

  for _, f in ipairs(RS.framepool) do
    f.isInUse = false
    f:SetParent(RS.hiddenFrame)
    f:Hide()
  end

  for _, item in ipairs(list) do
    local f = RS:GetFirstEmpty()
    f:SetParent(RS.MainFrame.scrollChild)
    f.isInUse = true
    f.editBox:SetText(tostring(item.amount or 0))
    f.reactionBox:SetText(tostring(item.reaction or 0))
    f.text:SetText(item.itemName)
    f:Show()
  end

  local height = 0
  for _, f in ipairs(RS.framepool) do
    if f.isInUse then
      height = height + 15
    end
  end
  RS.MainFrame.scrollChild:SetHeight(height)
end


--[[
  GET FIRST UNUSED SCROLLCHILD FRAME
]]
function RS:GetFirstEmpty()
  for i, frame in ipairs(RS.framepool) do
    if not frame.isInUse then
      return frame
    end
  end
  return RS:addListFrame()
end



--[[
  ADD PROFILE
]]
---@param newProfile string
function RS:AddProfile(newProfile)
  RestockerSettings.currentProfile = newProfile ---@type string
  RestockerSettings.profiles[newProfile] = {} ---@type RsRestockItem

  local menu = RS.MainFrame or RS:CreateMenu()
  menu:Show()
  RS:Update()

  UIDropDownMenu_SetText(RS.MainFrame.profileDropDownMenu, RestockerSettings.currentProfile)
end


--[[
  DELETE PROFILE
]]
function RS:DeleteProfile(profile)
  local currentProfile = RestockerSettings.currentProfile

  if currentProfile == profile then
    if #RestockerSettings.profiles > 1 then
      RestockerSettings.profiles[currentProfile] = nil
      RestockerSettings.currentProfile = RestockerSettings.profiles[1]
    else
      RestockerSettings.profiles[currentProfile] = nil
      RestockerSettings.currentProfile = "default"
      RestockerSettings.profiles.default = {}
    end

  else
    RestockerSettings.profiles[profile] = nil
  end

  UIDropDownMenu_SetText(RS.optionsPanel.deleteProfileMenu, "")

  local menu = RS.MainFrame or RS:CreateMenu()
  RS.profileSelectedForDeletion = ""
  UIDropDownMenu_SetText(RS.MainFrame.profileDropDownMenu, RestockerSettings.currentProfile)
end

--[[
  RENAME PROFILE
]]
function RS:RenameCurrentProfile(newName)
  local currentProfile = RestockerSettings.currentProfile

  RestockerSettings.profiles[newName] = RestockerSettings.profiles[currentProfile]
  RestockerSettings.profiles[currentProfile] = nil

  RestockerSettings.currentProfile = newName

  UIDropDownMenu_SetText(RS.MainFrame.profileDropDownMenu, RestockerSettings.currentProfile)
end


--[[
  CHANGE PROFILE
]]
function RS:ChangeProfile(newProfile)
  RestockerSettings.currentProfile = newProfile

  UIDropDownMenu_SetText(RS.MainFrame.profileDropDownMenu, RestockerSettings.currentProfile)
  --print(RS.defaults.prefix .. "current profile: ".. Restocker.currentProfile)
  RS:Update()

  if bankModule.bankIsOpen then
    eventsModule.OnBankOpen(true)
  end

  if merchantModule.merchantIsOpen then
    eventsModule.OnMerchantShow()
  end
end

---@class RsRestockItem
---@field amount number
---@field reaction number
---@field itemName string

--[[
  COPY PROFILE
]]
function RS:CopyProfile(profileToCopy)
  local copyProfile = CopyTable(RestockerSettings.profiles[profileToCopy])
  RestockerSettings.profiles[RestockerSettings.currentProfile] = copyProfile
  RS:Update()
end

function RS:loadSettings()
  if RestockerSettings.autoBuy == nil then
    RestockerSettings.autoBuy = true
  end
  if RestockerSettings.restockFromBank == nil then
    RestockerSettings.restockFromBank = true
  end

  if RestockerSettings.profiles == nil then
    ---@type table<string, table<string, RsRestockItem>>
    RestockerSettings.profiles = {}
  end
  if RestockerSettings.profiles.default == nil then
    ---@type table<string, RsRestockItem>
    RestockerSettings.profiles.default = {}
  end
  if RestockerSettings.currentProfile == nil then
    RestockerSettings.currentProfile = "default" ---@type string
  end

  if RestockerSettings.framePos == nil then
    RestockerSettings.framePos = {}
  end

  if RestockerSettings.autoOpenAtBank == nil then
    RestockerSettings.autoOpenAtBank = false
  end
  if RestockerSettings.autoOpenAtMerchant == nil then
    RestockerSettings.autoOpenAtMerchant = false
  end
  if RestockerSettings.loginMessage == nil then
    RestockerSettings.loginMessage = true
  end
end

function RS.Dbg(t)
  local name = "RsDbg"
  DEFAULT_CHAT_FRAME:AddMessage("|cffbb3333" .. name .. "|r: " .. t)
end

RS.ICON_FORMAT = "|T%s:0:0:0:0:64:64:4:60:4:60|t"

---Creates a string which will display a picture in a FontString
---@param texture string - path to UI texture file (for example can come from
---  GetContainerItemInfo(bag, slot) or spell info etc
function RS.FormatTexture(texture)
  return string.format(RS.ICON_FORMAT, texture)
end

---AceAddon handler
function RS:OnInitialize()
  -- do init tasks here, like loading the Saved Variables,
  -- or setting up slash commands.
  self.loaded = false
end

---AceAddon handler
function RS:OnEnable()
  -- Saved variables; Migrate from old 'Restocker' to new 'RestockerSettings'
  RestockerSettings = (Restocker or RestockerSettings) or {}
  if Restocker then
    Restocker = nil
  end

  self.currentlyRestocking = false
  self.itemsRestocked = {}
  self.restockedItems = false
  self.framepool = {}
  self.hiddenFrame = CreateFrame("Frame", nil, UIParent):Hide()
  self:loadSettings()

  -- Do more initialization here, that really enables the use of your addon.
  -- Register Events, Hook functions, Create Frames, Get information from
  -- the game that wasn't available in OnInitialize
  for profile, _ in pairs(RestockerSettings.profiles) do
    for _, item in ipairs(RestockerSettings.profiles[profile]) do
      item.itemID = tonumber(item.itemID)
    end
  end

  local f = InterfaceOptionsFrame;
  f:SetMovable(true);
  f:EnableMouse(true);
  f:SetUserPlaced(true);
  f:SetScript("OnMouseDown", f.StartMoving);
  f:SetScript("OnMouseUp", f.StopMovingOrSizing);

  SLASH_RESTOCKER1 = "/restocker";
  SLASH_RESTOCKER2 = "/rs";
  SlashCmdList.RESTOCKER = function(msg)
    RS:SlashCommand(msg)
  end

  -- Options tabs
  RS:CreateOptionsMenu(TOCNAME)

  RS:Show()
  RS:Hide()

  eventsModule:InitEvents()

  RsModule:CallInEachModule("OnModuleInit")

  if not RS.MainFrame then
    RS:CreateMenu()
  end -- setup the UI

  RS.loaded = true

  if RestockerSettings.loginMessage then
    RS:Print("Initialized")
  end
end

---AceAddon handler
function RS:OnDisable()
end
