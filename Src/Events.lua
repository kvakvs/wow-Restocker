local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

---@class RsEventsModule
local eventsModule = RsModule.DeclareModule("Events") ---@type RsEventsModule

local bagModule = RsModule.Import("Bag") ---@type RsBagModule
local bankModule = RsModule.Import("Bank") ---@type RsBankModule
local buyiModule = RsModule.Import("BuyIngredients") ---@type RsBuyIngredientsModule
local merchantModule = RsModule.Import("Merchant") ---@type RsMerchantModule

RS.loaded = false
RS.addItemWait = {}

--local EventFrame = CreateFrame("Frame");
--RS.EventFrame = EventFrame

--EventFrame:SetScript("OnEvent", function(self, event, ...)
--  return self[event] and self[event](self, ...)
--end)

function eventsModule.OnEnteringWorld(login, reloadui)
end

function eventsModule.OnMerchantShow()
  -- prevents double init but sometimes does not init when entering world too soon?
  buyiModule:SetupAutobuyIngredients()

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

function eventsModule.OnMerchantClose()
  merchantModule.merchantIsOpen = false
  RS:Hide()
end

function eventsModule.OnBankOpen(isMinor)
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

  bagModule:ResetBankRestocker()
end

function eventsModule.OnBankClose()
  bankModule.bankIsOpen = false
  bankModule.currentlyRestocking = false
  RS:Hide()

  bagModule:ResetBankRestocker()
end

function eventsModule.OnItemInfoReceived(itemID, success)
  if success == nil then
    return
  end

  -- If this was an autobuy item setup item request
  if #buyiModule.buyIngredientsWait > 0 then
    buyiModule:RetryWaitRecipes()
  end

  -- If this was an item add request for an unknown item
  if RS.addItemWait[itemID] then
    RS.addItemWait[itemID] = nil
    RS:addItem(itemID)
  end
end

function eventsModule.OnLogout()
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

function eventsModule.OnUiErrorMessage(id, message)
  if id == 2 or id == 3 then
    -- catch inventory / bank full error messages
    bankModule.currentlyRestocking = false
    RS.buying = false
  end
end

function eventsModule:InitEvents()
  --RS:RegisterEvent("ADDON_LOADED", self.OnAddonLoaded);
  RS:RegisterEvent("MERCHANT_SHOW", self.OnMerchantShow);
  RS:RegisterEvent("MERCHANT_CLOSED", self.OnMerchantClose);
  RS:RegisterEvent("BANKFRAME_OPENED", self.OnBankOpen);
  RS:RegisterEvent("BANKFRAME_CLOSED", self.OnBankClose);
  RS:RegisterEvent("GET_ITEM_INFO_RECEIVED", self.OnItemInfoReceived);
  RS:RegisterEvent("PLAYER_LOGOUT", self.OnLogout);
  RS:RegisterEvent("PLAYER_ENTERING_WORLD", self.OnEnteringWorld);
  RS:RegisterEvent("UI_ERROR_MESSAGE", self.OnUiErrorMessage);
end
