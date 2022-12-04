--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

local restockerModule = RsModule.restockerModule ---@type RsRestockerModule

---@class RsMerchantModule
---@field merchantIsOpen boolean
---@field lastTimeRestocked number GetTime() of last restock
local merchantModule = RsModule.merchantModule

merchantModule.merchantIsOpen = false
merchantModule.lastTimeRestocked = GetTime()

local buyIngredientsModule = RsModule.buyIngredientsModule ---@type RsBuyIngredientsModule
local buyItemModule = RsModule.buyCommandModule ---@type RsBuyCommandModule

---@param theTable table|nil
local function countTableItems(theTable)
  if not theTable then
    return 0
  end

  local count = 0
  for _, _ in pairs(--[[---@not nil]] theTable) do
    count = count + 1
  end
  return count
end

---@param purchaseOrders RsPurchaseOrders
---@param eachRestockRecord RsBuyCommand
---@param vendorReaction number
function merchantModule:BuildPurchaseOrder(purchaseOrders, eachRestockRecord, vendorReaction)
  local haveInBag = GetItemCount(eachRestockRecord.itemName, false)
  local amount = eachRestockRecord.amount or 0
  local requiredReaction = eachRestockRecord.reaction or 0

  if requiredReaction > vendorReaction then
    -- (spammy) RS:Print(string.format("Not buying: %s (too low reputation)", item.itemName))
  elseif amount > 0 then
    local toBuy = amount - haveInBag

    if toBuy > 0 then
      if not purchaseOrders[eachRestockRecord.itemName] then
        -- add new
        purchaseOrders[eachRestockRecord.itemName] = buyItemModule:Create(
              --[[---@type RsBuyCommand]] {
              numNeeded = toBuy,
              itemName  = eachRestockRecord.itemName,
              itemID    = eachRestockRecord.itemID,
              itemLink  = eachRestockRecord.itemLink,
            })
      else
        -- update amount, add more
        local purchase = purchaseOrders[eachRestockRecord.itemName]
        purchase.numNeeded = purchase.numNeeded + toBuy
      end
    end -- if tobuy > 0
  end -- if amount
end

---@param purchaseOrders RsPurchaseOrders
---@param ingredientName string Name of ingredient to add to purchaseOrders
---@param toBuy number Requested amount
function merchantModule:UpdatePurchaseOrdersWithCraftingReagents(purchaseOrders, ingredientName, toBuy)
  if not purchaseOrders[ingredientName] then
    purchaseOrders[ingredientName] = buyItemModule:Create(
          --[[---@type RsBuyCommand]] {
          numNeeded = toBuy,
          itemName  = ingredientName,
        })
  else
    local purchase = purchaseOrders[ingredientName]
    purchase.numNeeded = purchase.numNeeded + toBuy
  end
end

---@param i number Merchant item index
---@param purchaseOrders RsPurchaseOrders
---@param numPurchases number Counter for purchases done
function merchantModule:PurchaseMerchantItem(i, purchaseOrders, numPurchases)
  local itemName, _, _, _, merchantAvailable, _, _ = GetMerchantItemInfo(i)
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
  end -- if purchaseOrders[itemName]

  return numPurchases
end

---@alias RsPurchaseOrders {[string]: RsBuyCommand}

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

  ---@type RsPurchaseOrders
  local purchaseOrders = {}

  local restockList = settings.profiles[settings.currentProfile]
  local vendorReaction = UnitReaction("target", "player") or 0

  -- Build the Purchase Orders table used for buying items
  for _, eachRestockRecord in ipairs(--[[---@not nil]] restockList) do
    self:BuildPurchaseOrder(purchaseOrders, eachRestockRecord, vendorReaction)
  end

  -- Insert craft reagents for missing items into purchase orders, or add
  for ingredientName, toBuy in pairs(craftingPurchaseOrder) do
    self:UpdatePurchaseOrdersWithCraftingReagents(purchaseOrders, ingredientName, toBuy)
  end

  -- Loop through vendor items
  for i = 0, GetMerchantNumItems() do
    if not RS.buying then
      return
    end

    numPurchases = self:PurchaseMerchantItem(i, purchaseOrders, numPurchases)
  end -- for loop GetMerchantNumItems()


  if numPurchases > 0 then
    RS:Print("Finished restocking (" .. numPurchases .. " purchase orders done)")
  end
end