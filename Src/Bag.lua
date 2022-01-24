---@type RestockerAddon
local TOC, RS = ...;
---@class RsBagModule
local bagModule = RsModule.DeclareModule("Bag") ---@type RsBagModule

bagModule.BACKPACK_CONTAINER = 0
bagModule.BANK_CONTAINER = -1
bagModule.PLAYER_BAGS = {}
bagModule.PLAYER_BAGS_REVERSED = {}

bagModule.BANK_BAGS = {} -- set up in RS.SetupBankConstants
bagModule.BANK_BAGS_REVERSED = {} -- set up in RS.SetupBankConstants

--if REAGENTBANK_CONTAINER then
--  tinsert(BANK_BAGS, REAGENTBANK_CONTAINER)
--  tinsert(BANK_BAGS_REVERSED, REAGENTBANK_CONTAINER)
--end

function bagModule.OnModuleInit()
  -- -1 bank container, 0 backpack, 1234 bags, 5-10 or 5-11 is TBC bank
  if RS.TBC then
    bagModule.BANK_BAGS = { bagModule.BANK_CONTAINER, 5, 6, 7, 8, 9, 10, 11 }
    bagModule.BANK_BAGS_REVERSED = { 11, 10, 9, 8, 7, 6, 5, bagModule.BANK_CONTAINER }
  else
    bagModule.BANK_BAGS = { bagModule.BANK_CONTAINER, 5, 6, 7, 8, 9, 10 }
    bagModule.BANK_BAGS_REVERSED = { 10, 9, 8, 7, 6, 5, bagModule.BANK_CONTAINER }
  end

  bagModule.PLAYER_BAGS = { 0, 1, 2, 3, 4 }
  bagModule.PLAYER_BAGS_REVERSED = { 4, 3, 2, 1, 0 }
end

function bagModule:IsSomethingLocked()
  for _, bag in ipairs(self.PLAYER_BAGS) do
    for slot = 1, GetContainerNumSlots(bag) do
      local _, _, locked = GetContainerItemInfo(bag, slot)
      if locked then
        return true
      end
    end
  end

  for _, bag in ipairs(self.BANK_BAGS_REVERSED) do
    for slot = 1, GetContainerNumSlots(bag) do
      local _, _, locked = GetContainerItemInfo(bag, slot)
      if locked then
        return true
      end
    end
  end

  return false
end

---@return table<string, number>
function bagModule:GetItemsInBags()
  local result = {}
  for bag = self.BACKPACK_CONTAINER, NUM_BAG_SLOTS do
    for slot = 1, GetContainerNumSlots(bag) do
      local _, itemCount, locked, _, _, _, itemLink, _, _, itemID = GetContainerItemInfo(bag, slot)
      local itemName = itemLink and string.match(itemLink, "%[(.*)%]")
      if itemID then
        result[itemName] = result[itemName] and result[itemName] + itemCount or itemCount
      end
    end
  end
  return result
end

---@return table<string, number>
function bagModule:GetItemsInBank()
  local result = {}
  for _, bag in ipairs(self.BANK_BAGS_REVERSED) do
    for slot = 1, GetContainerNumSlots(bag) do
      local _, itemCount, locked, _, _, _, itemLink, _, _, itemID = GetContainerItemInfo(bag, slot)
      local itemName = itemLink and string.match(itemLink, "%[(.*)%]")
      if itemID then
        result[itemName] = result[itemName] and result[itemName] + itemCount or itemCount
      end
    end
  end

  return result
end

---@param dropItem RsItem
---@param bag number BagID https://wowwiki-archive.fandom.com/wiki/BagId
---@return number, number Returns bag, slot where drop happened
function bagModule:DropCursorItemIntoBag(dropItem, bag)
  -- Search through the bag for an empty slot
  for slot = 1, GetContainerNumSlots(bag) do
    local _, itemCount, locked, _, _, _, _, _, _, itemID = GetContainerItemInfo(bag, slot)

    if not locked and not itemCount then
      PickupContainerItem(bag, slot)
      return bag, slot
    end
  end -- for all bag slots
  return nil
end

---Takes cursor item. Drops it into same bags where it was taken from then right-clicks it to move
---into the opposite bags group. I.e. bank to bags, or bags to bank.
---@param dropItem RsItem
---@param srcBags table<number, number> Bag list where the item comes from - used for splitting
---@return number, number Bag and slot where the drop happened
function bagModule:SplitSwapCursorItem(dropItem, srcBags)
  if not CursorHasItem() then
    return
  end
  C_NewItems.ClearAll()

  ---------------------------------------
  -- Try find a bag which has free space
  ---------------------------------------
  for _, bag in ipairs(srcBags) do
    local numberOfFreeSlots, _bagType = GetContainerNumFreeSlots(bag)
    if numberOfFreeSlots > 0 then
      local tmpBag, tmpSlot = bagModule:DropCursorItemIntoBag(dropItem, bag)
      UseContainerItem(tmpBag, tmpSlot) -- move to the opposite container group bank-bag, or bag-bank
      return
    end
  end
end

function bagModule:CheckSpace(bags)
  for _, bag in ipairs(bags) do
    local numberOfFreeSlots, _bagType = GetContainerNumFreeSlots(bag)
    if numberOfFreeSlots > 0 then
      return true
    end
  end
  return false
end

---@param task table<string, number>
---@param moveName string
---@param moveAmount number Negative for take from bag, positive for take from bank
function bagModule:MoveFromBank(task, moveName, moveAmount)
  -- For all bank bags and all bank bag slots
  for _, bag in ipairs(bagModule.BANK_BAGS) do
    for slot = GetContainerNumSlots(bag), 1, -1 do
      local _icon, slotCount, slotLocked, _, _, _, slotItemLink, _, _, slotItemId = GetContainerItemInfo(bag, slot)
      local itemName = slotItemLink and string.match(slotItemLink, "%[(.*)%]")

      if slotLocked then
        return true -- can't do nothing now, something is locked, try in 0.1 sec
      end

      if itemName == moveName
          and slotCount <= moveAmount
      then
        UseContainerItem(bag, slot)
        task[itemName] = task[itemName] - slotCount -- deduct
        return true -- DONE one step
      end

      if itemName == moveName
          and slotCount > moveAmount
      then
        local itemInfo = RS.GetItemInfo(slotItemId)

        SplitContainerItem(bag, slot, moveAmount)
        --rsPutSplitItemIntoBags(itemInfo, 1, BANK_BAGS, PLAYER_BAGS)
        bagModule:SplitSwapCursorItem(itemInfo, bagModule.BANK_BAGS)

        task[itemName] = task[itemName] - moveAmount -- deduct
        return true -- DONE one step
      end
    end
  end
  return false -- did not move
end

---@param task table<string, number>
---@param moveName string
---@param moveAmount number Negative for take from bag, positive for take from bank
function bagModule:MoveToBank(task, moveName, moveAmount)
  -- For all bank bags and all bank bag slots
  for _, bag in ipairs(bagModule.PLAYER_BAGS) do
    for slot = GetContainerNumSlots(bag), 1, -1 do
      local _icon, slotCount, slotLocked, _, _, _, slotItemLink, _, _, slotItemId = GetContainerItemInfo(bag, slot)
      local itemName = slotItemLink and string.match(slotItemLink, "%[(.*)%]")

      if slotLocked then
        return true -- can't do nothing now, something is locked, try in 0.1 sec
      end

      -- Found something to move and its smaller than what we need to move
      if itemName == moveName
          and slotCount <= moveAmount
      then
        UseContainerItem(bag, slot)
        task[itemName] = task[itemName] + slotCount -- deduct
        return true -- moved one
      end

      -- Found something to move, but its bigger than how many we need to move
      if itemName == moveName
          and slotCount > moveAmount
      then
        local itemInfo = RS.GetItemInfo(slotItemId)

        SplitContainerItem(bag, slot, moveAmount)
        --rsPutSplitItemIntoBags(itemInfo, 1, PLAYER_BAGS, BANK_BAGS)
        bagModule:SplitSwapCursorItem(itemInfo, bagModule.PLAYER_BAGS)

        task[itemName] = task[itemName] + moveAmount -- add
        return true -- DONE one step
      end
    end
  end
  return false -- did not move
end
