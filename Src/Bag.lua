--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

---@class RsBagModule
---@field priorityMoveBank RsInventorySlotNumber|nil If not nil, this will be priority clicked before any new stack is split
---@field priorityMovePlayer RsInventorySlotNumber|nil If not nil, this will be priority clicked before any new stack is split
---@field BACKPACK_CONTAINER number Index of backpack container
---@field BANK_CONTAINER number Index of main bank container
---@field PLAYER_BAGS RsBagId[] Indexes of player bags
---@field PLAYER_BAGS_REVERSED RsBagId[]
---@field BANK_BAGS RsBagId[]
---@field BANK_BAGS_REVERSED RsBagId[]

local bagModule = RsModule.bagModule ---@type RsBagModule
local itemModule = RsModule.itemModule ---@type RsItemModule

bagModule.BACKPACK_CONTAINER = 0
bagModule.BANK_CONTAINER = -1
bagModule.PLAYER_BAGS = {}
bagModule.PLAYER_BAGS_REVERSED = {}

---@alias RsBagId number

bagModule.BANK_BAGS = --[[---@type RsBagId[] ]] {} -- set up in RS.SetupBankConstants
bagModule.BANK_BAGS_REVERSED = --[[---@type RsBagId[] ]] {} -- set up in RS.SetupBankConstants

function bagModule:ResetBankRestocker()
  bagModule.priorityMoveBankBag = nil
  bagModule.priorityMoveBankSlot = nil
  bagModule.priorityMovePlayerBag = nil
  bagModule.priorityMovePlayerSlot = nil
end

function bagModule.OnModuleInit()
  -- -1 bank container, 0 backpack, 1234 bags, 5-10 or 5-11 is TBC bank
  if RS.HaveTBC then
    bagModule.BANK_BAGS = { bagModule.BANK_CONTAINER, 5, 6, 7, 8, 9, 10, 11 }
    bagModule.BANK_BAGS_REVERSED = { 11, 10, 9, 8, 7, 6, 5, bagModule.BANK_CONTAINER }
  else
    bagModule.BANK_BAGS = { bagModule.BANK_CONTAINER, 5, 6, 7, 8, 9, 10 }
    bagModule.BANK_BAGS_REVERSED = { 10, 9, 8, 7, 6, 5, bagModule.BANK_CONTAINER }
  end

  bagModule.PLAYER_BAGS = { 0, 1, 2, 3, 4 }
  bagModule.PLAYER_BAGS_REVERSED = { 4, 3, 2, 1, 0 }
end

function bagModule:GetBankBags(reversed)
  if reversed then
    return self.BANK_BAGS_REVERSED
  end
  return self.BANK_BAGS
end

function bagModule:GetPlayerBags(reversed)
  if reversed then
    return self.PLAYER_BAGS_REVERSED
  end
  return self.PLAYER_BAGS
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

---@return RsInventoryByItemName
function bagModule:GetItemsInBags()
  local result = --[[---@type RsInventoryByItemName]] {}
  for bag = self.BACKPACK_CONTAINER, NUM_BAG_SLOTS do
    for slot = 1, GetContainerNumSlots(bag) do
      local _, itemCount, locked, _, _, _, itemLink, _, _, itemID = GetContainerItemInfo(bag, slot)
      if itemID and itemLink then
        local itemName = --[[---@type string]] (string.match(itemLink, "%[(.*)%]"))
        result[itemName] = result[itemName] and result[itemName] + itemCount or itemCount
      end
    end
  end
  return result
end

---@param handler fun(bag: number, slot: number, itemName: string, itemID: number, itemCount: number)
function bagModule:ForEachBagItem(handler)
  local result = --[[---@type RsInventoryByItemName]] {}
  for bag = self.BACKPACK_CONTAINER, NUM_BAG_SLOTS do
    for slot = 1, GetContainerNumSlots(bag) do
      local _, itemCount, locked, _, _, _, itemLink, _, _, itemID = GetContainerItemInfo(bag, slot)
      if itemID and itemLink then
        local itemName = --[[---@type string]] (string.match(itemLink, "%[(.*)%]"))
        handler(bag, slot, itemName, itemID, itemCount)
      end
    end
  end
  return result
end

---@return RsInventoryByItemName
function bagModule:GetItemsInBank()
  local result = --[[---@type RsInventoryByItemName]] {}
  for _, bag in ipairs(self.BANK_BAGS_REVERSED) do
    for slot = 1, GetContainerNumSlots(bag) do
      local _, itemCount, locked, _, _, _, itemLink, _, _, itemID = GetContainerItemInfo(bag, slot)
      if itemID then
        local itemName = --[[---@type string]] string.match(itemLink, "%[(.*)%]")
        result[itemName] = result[itemName] and result[itemName] + itemCount or itemCount
      end
    end
  end

  return result
end

---@param dropItem RsItem
---@param bag number BagID https://wowwiki-archive.fandom.com/wiki/BagId
---@return RsInventorySlotNumber|nil Returns bag, slot where drop happened
function bagModule:DropCursorItemIntoBag(dropItem, bag)
  -- Search through the bag for an empty slot
  for slot = 1, GetContainerNumSlots(bag) do
    local _, itemCount, locked, _, _, _, _, _, _, itemID = GetContainerItemInfo(bag, slot)

    if not locked and not itemCount then
      PickupContainerItem(bag, slot)
      return { bag = bag, slot = slot }
    end
  end -- for all bag slots
  return nil
end

---Takes cursor item. Drops it into same bags where it was taken from then right-clicks it to move
---into the opposite bags group. I.e. bank to bags, or bags to bank.
---@param dropItem RsItem
---@param srcBags number[] Bag list where the item comes from - used for splitting
---@return RsInventorySlotNumber|nil Bag and slot where the drop happened
function bagModule:SplitSwapCursorItem(dropItem, srcBags)
  if not CursorHasItem() then
    return nil
  end
  C_NewItems.ClearAll()

  ---------------------------------------
  -- Try find a bag which has free space
  ---------------------------------------
  for _, bag in ipairs(srcBags) do
    local numberOfFreeSlots, _bagType = GetContainerNumFreeSlots(bag)
    if numberOfFreeSlots > 0 then
      local tmp = bagModule:DropCursorItemIntoBag(dropItem, bag)
      if tmp then
        -- move to the opposite container group bank-bag, or bag-bank
        UseContainerItem((--[[---@not nil]] tmp).bag, (--[[---@not nil]] tmp).slot)
      end
      return tmp
    end
  end

  return nil
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

---Called to check if priority move is requested (i.e. a stack was split for move earlier)
---The item must not be locked
---@return boolean Move successful, bag and slot can be reset
function bagModule:PriorityMove(bag, slot)
  if bag == nil or slot == nil then
    return false
  end

  local containerItemInfo = itemModule:GetContainerItemInfo(bag, slot)

  if containerItemInfo.locked then
    return false
  end

  UseContainerItem(bag, slot)
  return true
end

---From bags list, retrieve items which are not locked and match predicate
---@param bags number[] List of bags from bagModule.* constants
---@param predicate function
---@return RsContainerItemInfo[]|nil
function bagModule:ScanBagsFor(bags, predicate)
  local itemCandidates = --[[---@type RsContainerItemInfo[] ]] {}

  for _, bag in ipairs(bags) do
    for slot = 1, GetContainerNumSlots(bag), 1 do
      local containerItemInfo = itemModule:GetContainerItemInfo(bag, slot)

      if containerItemInfo.locked then
        return nil -- can't do nothing now, something is locked, try in 0.1 sec
      end

      if predicate(containerItemInfo) then
        table.insert(itemCandidates, containerItemInfo)
      end
    end
  end

  return itemCandidates
end

---Filter function for ScanBagsFor, which matches the name
local function rsContainerItemInfoMatchName(name)
  return function(itemInfo)
    return itemInfo.name == name
  end
end

---Filter function for ScanBagsFor, which matches the name, but also must be
---smaller than stacksize and also smaller than the moveAmount
local function rsContainerItemInfoMatchNameAndSmall(name, moveAmount)
  return function(itemInfo)
    return itemInfo.name == name and itemInfo.count < moveAmount
  end
end

---Filter function for ScanBagsFor, which matches the name, but also must be
---1 item precisely
local function rsContainerItemInfoMatchNameAndIs1Item(name, moveAmount)
  return function(itemInfo)
    return itemInfo.name == name and itemInfo.count == 1
  end
end

---@param candidates RsContainerItemInfo[]
function bagModule:MoveFromBankToPlayer_1(task, candidates, moveAmount)
  for _index, containerItemInfo in ipairs(candidates) do
    if containerItemInfo.count <= moveAmount then
      UseContainerItem(containerItemInfo.bag, containerItemInfo.slot)
      task[containerItemInfo.name] = task[containerItemInfo.name] - containerItemInfo.count -- deduct
      return true -- DONE one step
    end

    if containerItemInfo.count > moveAmount then
      local itemInfo = RS.GetItemInfo(containerItemInfo.itemId)

      SplitContainerItem(containerItemInfo.bag, containerItemInfo.slot, moveAmount)
      --rsPutSplitItemIntoBags(itemInfo, 1, BANK_BAGS, PLAYER_BAGS)
      -- Now these slots will be priority clicked and cleared before next stack is produced
      self.priorityMoveBank = bagModule:SplitSwapCursorItem(
          itemModule:FromCachedItem(--[[---@not nil]] itemInfo),
          bagModule.BANK_BAGS)

      task[containerItemInfo.name] = task[containerItemInfo.name] - moveAmount -- deduct
      return true -- DONE one step
    end
  end

  return false
end

---@param task table<string, number>
---@param moveName string
---@param moveAmount number Negative for take from bag, positive for take from bank
function bagModule:MoveFromBankToPlayer(task, moveName, moveAmount)
  if self:PriorityMove(self.priorityMoveBankBag, self.priorityMoveBankSlot) then
    self.priorityMoveBankBag, self.priorityMoveBankSlot = nil, nil
  end

  local bankBagsReverse = self:GetBankBags(true)

  -------------------------------------------
  -- Try move from all bank bags in reverse
  -------------------------------------------
  for _index0, bag in ipairs(bankBagsReverse) do
    -- Build list of move candidates. Sort them to contain smallest stacks first.
    local moveCandidates = self:ScanBagsFor(
        { bag }, rsContainerItemInfoMatchName(moveName))
    -- Possibly nil, and try again?
    if moveCandidates == nil then
      return false
    end

    table.sort(moveCandidates, itemModule.CompareByStacksizeAscending)

    if self:MoveFromBankToPlayer_1(task, moveCandidates, moveAmount) then
      return true
    end
  end -- for bank bags in reverse order

  return false -- did not move
end

---@param candidates RsContainerItemInfo[]
function bagModule:MoveFromPlayerToBank_1(task, candidates, moveAmount)
  for _index, containerItemInfo in ipairs(candidates) do
    -- Found something to move and its smaller than what we need to move
    if containerItemInfo.count <= moveAmount then
      UseContainerItem(containerItemInfo.bag, containerItemInfo.slot)
      task[containerItemInfo.name] = task[containerItemInfo.name] + containerItemInfo.count -- deduct
      return true -- moved one
    end

    -- Found something to move, but its bigger than how many we need to move
    if containerItemInfo.count > moveAmount then
      local itemInfo = RS.GetItemInfo(containerItemInfo.itemId)

      SplitContainerItem(containerItemInfo.bag, containerItemInfo.slot, moveAmount)
      --rsPutSplitItemIntoBags(itemInfo, 1, PLAYER_BAGS, BANK_BAGS)
      self.priorityMovePlayer = bagModule:SplitSwapCursorItem(
          itemModule:FromCachedItem(--[[---@not nil]] itemInfo),
          bagModule.PLAYER_BAGS)

      task[containerItemInfo.name] = task[containerItemInfo.name] + moveAmount -- add
      return true -- DONE one step
    end
  end

  return false
end

---@param task table<string, number> How many items should arrive or depart to player bags
---@param moveName string
---@param moveAmount number Negative for take from bag, positive for take from bank
function bagModule:MoveFromPlayerToBank(task, moveName, moveAmount)
  if self:PriorityMove(self.priorityMovePlayerBag, self.priorityMovePlayerSlot) then
    self.priorityMovePlayerBag, self.priorityMovePlayerSlot = nil, nil
  end

  local playerBags = self:GetPlayerBags(false)

  -------------------------------------------
  -- Try move from all player bags
  -------------------------------------------
  for _index0, bag in ipairs(playerBags) do
    -- Build list of move candidates. Sort them to contain smallest stacks first.
    local moveCandidates = self:ScanBagsFor(
        { bag }, rsContainerItemInfoMatchName(moveName))
    -- Possibly nil, and try again?
    if moveCandidates == nil then
      return false
    end

    table.sort(moveCandidates, itemModule.CompareByStacksizeAscending)

    if self:MoveFromPlayerToBank_1(task, moveCandidates, moveAmount) then
      return true
    end
  end -- for all player bags starting from main bag

  return false -- did not move
end

---@return string "ok", "bank" - bank is full, "bag" - bag is full, "both" - both bank and bag are full
function bagModule:CheckBankBagSpace()
  local bankFree = self:CheckSpace(bagModule.BANK_BAGS)
  local bagFree = self:CheckSpace(bagModule.PLAYER_BAGS)

  if bagFree then
    if bankFree then
      return "ok"
    else
      return "bank"
    end
  else
    if bankFree then
      return "bag"
    else
      return "both"
    end
  end
end
