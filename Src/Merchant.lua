--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

local restockerModule = RsModule.restockerModule ---@type RsRestockerModule

---@class RsMerchantModule
---@field merchantIsOpen boolean
---@field lastTimeRestocked number GetTime() of last restock
local merchantModule = RsModule.merchantModule ---@type RsMerchantModule
merchantModule.merchantIsOpen = false
merchantModule.lastTimeRestocked = GetTime()

local buyIngredientsModule = RsModule.buyIngredientsModule ---@type RsBuyIngredientsModule
local buyItemModule = RsModule.buyItemModule ---@type RsBuyItemModule

--local bagModule = RsModule.bagModule ---@type RsBagModule

---@param T table
local function countTableItems(T)
  local i = 0
  for _, _ in pairs(T) do
    i = i + 1
  end
  return i
end

function merchantModule:Restock()
  local settings = restockerModule.settings

  if countTableItems(settings.profiles[settings.currentProfile]) == 0 then
    return
  end -- If profile is emtpy then return

  if GetTime() - self.lastTimeRestocked < 1 then
    return
  end -- If vendor reopened within 1 second then return (only activate addon once per second)

  self.lastTimeRestocked = GetTime()
  local numPurchases = 0

  if settings.autoOpenAtMerchant then
    RS:Show()
  end

  local craftingPurchaseOrder = buyIngredientsModule:CraftingPurchaseOrder() or {}

  ---@type table<string, RsBuyItem>
  local purchaseOrders = {}

  local restockList = settings.profiles[settings.currentProfile]
  local vendorReaction = UnitReaction("target", "player") or 0

  -- Build the Purchase Orders table used for buying items
  for _, item in ipairs(restockList) do
    local haveInBag = GetItemCount(item.itemName, false)
    local amount = item.amount or 0
    local requiredReaction = item.reaction or 0

    if requiredReaction > vendorReaction then
      -- (spammy) RS:Print(string.format("Not buying: %s (too low reputation)", item.itemName))
    elseif amount > 0 then
      local toBuy = amount - haveInBag

      if toBuy > 0 then
        if not purchaseOrders[item.itemName] then
          -- add new
          purchaseOrders[item.itemName] = buyItemModule:Create(
                --[[---@type RsBuyItem]] {
                numNeeded = toBuy,
                itemName  = item.itemName,
                itemID    = item.itemID,
                itemLink  = item.itemLink,
              })
        else
          -- update amount, add more
          local purchase = purchaseOrders[item.itemName]
          purchase.numNeeded = purchase.numNeeded + toBuy
        end
      end -- if tobuy > 0
    end -- if amount
  end

  -- Insert craft reagents for missing items into purchase orders, or add
  for ingredientName, toBuy in pairs(craftingPurchaseOrder) do
    if not purchaseOrders[ingredientName] then
      purchaseOrders[ingredientName] = buyItemModule:Create(
            --[[---@type RsBuyItem]] {
            numNeeded = toBuy,
            itemName  = ingredientName,
          })
    else
      local purchase = purchaseOrders[ingredientName]
      purchase.numNeeded = purchase.numNeeded + toBuy
    end
  end

  -- Loop through vendor items
  for i = 0, GetMerchantNumItems() do
    if not RS.buying then
      return
    end

    local itemName, _, _, _, merchantAvailable = GetMerchantItemInfo(i)
    local itemLink = GetMerchantItemLink(i)

    -- is item from merchant in our purchase order?
    local buyItem = purchaseOrders[itemName]

    if buyItem then
      local itemInfo = RS.GetItemInfo(itemLink)

      if buyItem.numNeeded > merchantAvailable and merchantAvailable > 0 then
        BuyMerchantItem(i, merchantAvailable)
        numPurchases = numPurchases + 1
      else
        for n = buyItem.numNeeded, 1, -(--[[---@not nil]] itemInfo).itemStackCount do
          if n > (--[[---@not nil]] itemInfo).itemStackCount then
            BuyMerchantItem(i, (--[[---@not nil]] itemInfo).itemStackCount)
            numPurchases = numPurchases + 1
          else
            BuyMerchantItem(i, n)
            numPurchases = numPurchases + 1
          end
        end -- forloop
      end
    end -- if buyTable[itemName] ~= nil
  end -- for loop GetMerchantNumItems()


  if numPurchases > 0 then
    RS:Print("Finished restocking (" .. numPurchases .. " purchase orders done)")
  end
end