---@type RestockerAddon
local TOC, RS = ...;
---@class RsEventsModule
local eventsModule = RsModule.DeclareModule("Events") ---@type RsEventsModule

local bankModule = RsModule.Import("Bank") ---@type RsBankModule
local buyiModule = RsModule.Import("BuyIngredients") ---@type RsBuyIngredientsModule
local merchantModule = RsModule.Import("Merchant") ---@type RsMerchantModule

RS.loaded = false
RS.addItemWait = {}

local EventFrame = CreateFrame("Frame");
RS.EventFrame = EventFrame

EventFrame:RegisterEvent("ADDON_LOADED");
EventFrame:RegisterEvent("MERCHANT_SHOW");
EventFrame:RegisterEvent("MERCHANT_CLOSED");
EventFrame:RegisterEvent("BANKFRAME_OPENED");
EventFrame:RegisterEvent("BANKFRAME_CLOSED");
EventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED");
EventFrame:RegisterEvent("PLAYER_LOGOUT");
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
EventFrame:RegisterEvent("UI_ERROR_MESSAGE");

EventFrame:SetScript("OnEvent", function(self, event, ...)
  return self[event] and self[event](self, ...)
end)

function EventFrame:ADDON_LOADED(addonName)
  if addonName ~= "RestockerClassic" and addonName ~= "RestockerTBC" then
    return
  end

  -- NEW RESTOCKER
  RS:loadSettings()

  for profile, _ in pairs(Restocker.profiles) do
    for _, item in ipairs(Restocker.profiles[profile]) do
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

  -- Craftable recipes (rogue poisons, etc)
  RS.SetupAutobuyIngredients()

  -- Options tabs
  RS:CreateOptionsMenu(addonName)

  RS:Show()
  RS:Hide()

  RsModule:CallInEachModule("OnModuleInit")
  RS.loaded = true
end

function EventFrame:PLAYER_ENTERING_WORLD(login, reloadui)
  if not RS.loaded then
    return
  end
  if (login or reloadui) and Restocker.loginMessage then
    RS.Print("Loaded")
  end
end

function EventFrame:MERCHANT_SHOW()
  RS.buying = true

  if not Restocker.autoBuy then
    return
  end -- If not autobuying then return

  if IsShiftKeyDown() then
    return
  end -- If shiftkey is down return

  merchantModule.merchantIsOpen = true
  merchantModule:Restock()
end

function EventFrame:MERCHANT_CLOSED()
  merchantModule.merchantIsOpen = false
  RS:Hide()
end

function EventFrame:BANKFRAME_OPENED(isMinor)
  if IsShiftKeyDown()
      or not Restocker.restockFromBank
      or Restocker.profiles[Restocker.currentProfile] == nil then
    return
  end

  if Restocker.autoOpenAtBank then
    RS:Show()
  end

  if isMinor then
    RS.minorChange = true
  else
    RS.minorChange = false
  end
  bankModule.didBankStuff = false
  bankModule.bankIsOpen = true
  bankModule.currentlyRestocking = true
  RS.onUpdateFrame:Show()
end

function RS:BANKFRAME_OPENED(bool)
  EventFrame:BANKFRAME_OPENED(not not bool)
end

function RS:MERCHANT_SHOW()
  EventFrame:MERCHANT_SHOW()
end

function EventFrame:BANKFRAME_CLOSED()
  bankModule.bankIsOpen = false
  bankModule.currentlyRestocking = false
  RS:Hide()
end

function EventFrame:GET_ITEM_INFO_RECEIVED(itemID, success)
  if success == nil then
    return
  end

  -- If this was an autobuy item setup item request
  if #buyiModule.buyIngredientsWait > 0 then
    RS.RetryWaitRecipes()
  end

  -- If this was an item add request for an unknown item
  if RS.addItemWait[itemID] then
    RS.addItemWait[itemID] = nil
    RS:addItem(itemID)
  end
end

function EventFrame:PLAYER_LOGOUT()
  if Restocker.framePos == nil then
    Restocker.framePos = {}
  end

  RS:Show()
  RS:Hide()

  local point, relativeTo, relativePoint, xOfs, yOfs = RS.MainFrame:GetPoint(RS.MainFrame:GetNumPoints())

  Restocker.framePos.point = point
  Restocker.framePos.relativePoint = relativePoint
  Restocker.framePos.xOfs = xOfs
  Restocker.framePos.yOfs = yOfs
end

function EventFrame:UI_ERROR_MESSAGE(id, message)
  if id == 2 or id == 3 then
    -- catch inventory / bank full error messages
    bankModule.currentlyRestocking = false
    RS.buying = false
  end
end
