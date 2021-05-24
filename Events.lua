---@type RestockerAddon
local TOC, RS             = ...;
RS.loaded               = false
RS.itemWaitTable        = {}
RS.bankIsOpen           = false
RS.merchantIsOpen       = false

local lastTimeRestocked = GetTime()

local function count(T)
  local i = 0
  for _, _ in pairs(T) do
    i = i + 1
  end
  return i
end

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

function EventFrame:ADDON_LOADED(name)
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

  SLASH_RESTOCKER1       = "/restocker";
  SLASH_RESTOCKER2       = "/rs";
  SlashCmdList.RESTOCKER = function(msg)
    RS:SlashCommand(msg)
  end

  RS:CreateOptionsMenu()
  RS:Show()
  RS:Hide()
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
  RS.merchantIsOpen = true
  if count(Restocker.profiles[Restocker.currentProfile]) == 0 then
    return
  end -- If profile is emtpy then return
  if GetTime() - lastTimeRestocked < 1 then
    return
  end -- If vendor repoened within 1 second then return (only activate addon once per second)

  lastTimeRestocked     = GetTime()
  local boughtSomething = false
  if Restocker.autoOpenAtMerchant then
    RS:Show()
  end

  local _, class             = UnitClass("PLAYER")
  local poisonReagentsNeeded = class == "ROGUE" and RS:getPoisonReagents() or {}
  local buyTable             = {}

  local restockList          = Restocker.profiles[Restocker.currentProfile]

  -- BUILD THE TABLE USED FOR BUYING ITEMS
  for _, item in ipairs(restockList) do
    local numInBags = GetItemCount(item.itemName, false)
    local numNeeded = item.amount - numInBags
    if numNeeded > 0 then
      if not buyTable[item.itemName] then
        buyTable[item.itemName]              = {}
        buyTable[item.itemName]["numNeeded"] = numNeeded
        buyTable[item.itemName]["itemName"]  = item.itemName
        buyTable[item.itemName]["itemID"]    = item.itemID
        buyTable[item.itemName]["itemLink"]  = item.itemLink
      else
        buyTable[item.itemName]["numNeeded"] = buyTable[item.itemName]["numNeeded"] + numNeeded
      end
    end
  end

  -- INSERT POISON REAGENTS INTO BUYTABLE
  for reagent, amount in pairs(poisonReagentsNeeded) do
    if not buyTable[reagent] then
      buyTable[reagent]              = {}
      buyTable[reagent]["numNeeded"] = amount
      buyTable[reagent]["itemName"]  = reagent
    else
      buyTable[reagent]["numNeeded"] = buyTable[reagent]["numNeeded"] + amount
    end
  end


  -- LOOP THROUGH VENDOR ITEMS
  for i = 0, GetMerchantNumItems() do
    if not RS.buying then
      return
    end
    local itemName, _, _, _, numAvailable = GetMerchantItemInfo(i)
    local itemLink                        = GetMerchantItemLink(i)

    if buyTable[itemName] then
      local item                                = buyTable[itemName]
      local _, _, _, _, _, _, _, itemStackCount = GetItemInfo(itemLink)

      if item.numNeeded > numAvailable and numAvailable > 0 then
        BuyMerchantItem(i, numAvailable)
        boughtSomething = true
      else
        for n = item.numNeeded, 1, -itemStackCount do
          if n > itemStackCount then
            BuyMerchantItem(i, itemStackCount)
            boughtSomething = true
          else
            BuyMerchantItem(i, n)
            boughtSomething = true
          end
        end -- forloop
      end
    end -- if buyTable[itemName] ~= nil
  end -- for loop GetMerchantNumItems()


  if boughtSomething then
    RS:Print("finished restocking from vendor.")
  end

end

function EventFrame:MERCHANT_CLOSED()
  RS.merchantIsOpen = false
  RS:Hide()
end

function EventFrame:BANKFRAME_OPENED(isMinor)
  if IsShiftKeyDown() then
    return
  end
  if not Restocker.restockFromBank then
    return
  end
  if Restocker.profiles[Restocker.currentProfile] == nil then
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
  RS.didBankStuff        = false
  RS.bankIsOpen          = true
  RS.currentlyRestocking = true
  RS.onUpdateFrame:Show()
end

function RS:BANKFRAME_OPENED(bool)
  EventFrame:BANKFRAME_OPENED(not not bool)
end

function RS:MERCHANT_SHOW()
  EventFrame:MERCHANT_SHOW()
end

function EventFrame:BANKFRAME_CLOSED()
  RS.bankIsOpen          = false
  RS.currentlyRestocking = false
  RS:Hide()
end

function EventFrame:GET_ITEM_INFO_RECEIVED(itemID, success)
  if success == nil then
    return
  end
  if RS.itemWaitTable[itemID] then
    RS.itemWaitTable[itemID] = nil
    RS:addItem(itemID)
  end
end

function EventFrame:PLAYER_LOGOUT()
  if Restocker.framePos == nil then
    Restocker.framePos = {}
  end

  RS:Show()
  RS:Hide()

  local point, relativeTo, relativePoint, xOfs, yOfs = RS.addon:GetPoint(RS.addon:GetNumPoints())

  Restocker.framePos.point                           = point
  Restocker.framePos.relativePoint                   = relativePoint
  Restocker.framePos.xOfs                            = xOfs
  Restocker.framePos.yOfs                            = yOfs
end

function EventFrame:UI_ERROR_MESSAGE(id, message)
  if id == 2 or id == 3 then
    -- catch inventory / bank full error messages
    RS.currentlyRestocking = false
    RS.buying              = false
  end
end
