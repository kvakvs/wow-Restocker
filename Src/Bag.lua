--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

---@class RsBagModule
---@field PLAYER_BAGS RsBagDef[] Indexes of player bags
---@field PLAYER_BAGS_REVERSED RsBagDef[]
---@field BANK_BAGS RsBagDef[]
---@field BANK_BAGS_REVERSED RsBagDef[]

local bagModule = RsModule.bagModule ---@type RsBagModule
local itemModule = RsModule.itemModule ---@type RsItemModule
local kvEnvModule = KvModuleManager.envModule

bagModule.PLAYER_BAGS = {}
bagModule.PLAYER_BAGS_REVERSED = {}

---@alias RsBagId number

---@alias RsContainerLocation "bank" | "guildbank" | "bag" | "backpack"

---@class RsBagDef
---@field location RsContainerLocation
---@field bagId RsBagId The bag id
---@field containerSlotId number The container slot id for PutItemInBag calls
local bagDefClass = {}
bagDefClass.__index = bagDefClass

bagModule.BANK_BAGS = --[[---@type RsBagDef[] ]] {} -- set up in RS.SetupBankConstants
bagModule.BANK_BAGS_REVERSED = --[[---@type RsBagDef[] ]] {} -- set up in RS.SetupBankConstants

local inventoryClass = {}
inventoryClass.__index = inventoryClass

local slotClass = {}
slotClass.__index = slotClass

---@return RsInventory
function bagModule:NewInventory()
  local inv = --[[---@type RsInventory]] {
    summary = {},
    slots = {},
  }
  setmetatable(inv, inventoryClass)
  return inv
end

---Sorts bag slots for each item, with smallest stacks first
---@param self RsInventory
function inventoryClass.SortSlots(self)
  local sortFn = function(a, b)
    return a.count < b.count
  end
  for _key, eachItemSlots in pairs(self.slots) do
    table.sort(eachItemSlots, sortFn)
  end
end

---@return RsSlot
---@param bag number
---@param slot number
---@param itemCount number
function bagModule:NewSlot(bag, slot, itemCount)
  local slotObj = --[[---@type RsSlot]] {
    bag = bag,
    slot = slot,
    count = itemCount,
  }
  setmetatable(slotObj, slotClass)
  return slotObj
end

local function bagSlotFromBag(bag)
  RS:Debug("bagSlotFromBag bag=" .. bag)
  local bagSlot, _icon, _ = GetInventorySlotInfo("BAG" .. (bag - 1) .. "SLOT")
  return bagSlot
end

---@return RsBagDef
function bagModule:NewBagDef(location, bagId, containerSlotId)
  local result = --[[---@type RsBagDef]] {}
  result.location = location
  result.bagId = bagId
  result.containerSlotId = containerSlotId
  setmetatable(result, bagDefClass)
  return result
end

local function createBackpack()
  return bagModule:NewBagDef("backpack", BACKPACK_CONTAINER, nil)
end

local function createBag(bag)
  return bagModule:NewBagDef("bag", bag, bagSlotFromBag(bag))
end

---@return RsBagDef
local function createBankMainBag()
  return bagModule:NewBagDef("bank", BANK_CONTAINER, BankButtonIDToInvSlotID(0, true))
end

local function createBankBag(bag)
  -- bank bags go from 5 to 11
  return bagModule:NewBagDef("bag", bag + NUM_BAG_SLOTS, BankButtonIDToInvSlotID(bag, true))
end

function bagModule.OnModuleInit()
  bagModule.BANK_BAGS = { createBankMainBag(), createBankBag(1), createBankBag(2), createBankBag(3),
                          createBankBag(4), createBankBag(5), createBankBag(6), createBankBag(7) }
  bagModule.BANK_BAGS_REVERSED = { createBankBag(7), createBankBag(6), createBankBag(5),
                                   createBankBag(4), createBankBag(3), createBankBag(2), createBankBag(1),
                                   createBankMainBag() }

  bagModule.PLAYER_BAGS = { createBackpack(),
                            createBag(1), createBag(2), createBag(3), createBag(4) }
  bagModule.PLAYER_BAGS_REVERSED = { createBag(4), createBag(3), createBag(2), createBag(1),
                                     createBackpack() }
end

function bagDefClass:HasSpace()
  local numberOfFreeSlots, _bagType = C_Container.GetContainerNumFreeSlots(self.bagId)
  return numberOfFreeSlots > 0
end

function bagDefClass:PutCursorItem()
  if self.location == "backpack" then
    RS:Debug("PutCursorItem(backpack) bag=" .. self.bagId .. " invslot=" .. tostring(self.containerSlotId))
    PutItemInBackpack()
  end
  if self.location == "bank" then
    RS:Debug("PutCursorItem(bank) bag=" .. self.bagId .. " invslot=" .. tostring(self.containerSlotId))

    -- Find a free slot in the bank
    for slot = 1, C_Container.GetContainerNumSlots(self.bagId) do
      local link = C_Container.GetContainerItemLink(self.bagId, slot)
      if not link then
        -- available!
        if not C_Container.PickupContainerItem(self.bagId, slot) then
          ClearCursor()
        end
        return
      end
    end
  else
    -- Drop in the bag provided that HasSpace() is true (checked by the caller)
    RS:Debug("PutCursorItem(bag) bag=" .. self.bagId .. " invslot=" .. tostring(self.containerSlotId))
    PutItemInBag(self.containerSlotId)
  end
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
    for slot = 1, C_Container.GetContainerNumSlots(bag.bagId) do
      local itemInfo = C_Container.GetContainerItemInfo(bag.bagId, slot)

      if itemInfo and itemInfo.isLocked then
        return true
      end
    end
  end

  for _, bag in ipairs(self.BANK_BAGS_REVERSED) do
    for slot = 1, C_Container.GetContainerNumSlots(bag.bagId) do
      local itemInfo = C_Container.GetContainerItemInfo(bag.bagId, slot)

      if itemInfo and itemInfo.isLocked then
        return true
      end
    end
  end

  return false
end

---@param predicate fun(s: string): boolean|nil
---@return RsInventory
function bagModule:GetItemsInBags(predicate)
  local result = self:NewInventory()

  for _, bag in ipairs(self.PLAYER_BAGS) do
    for slot = 1, C_Container.GetContainerNumSlots(bag.bagId) do
      -- local _, itemCount, locked, _, _, _, itemLink, _, _, itemID
      local itemInfo = C_Container.GetContainerItemInfo(bag.bagId, slot)

      if itemInfo and itemInfo.itemID and itemInfo.hyperlink then
        local itemName = --[[---@type string]] (string.match(itemInfo.hyperlink, "%[(.*)%]"))

        -- Allow filtering by predicate
        if predicate == nil or predicate(itemName) == true then
          result.summary[itemName] = (result.summary[itemName] and result.summary[itemName] + itemInfo.stackCount)
              or itemInfo.stackCount

          result.slots[itemName] = result.slots[itemName] or {}
          table.insert(result.slots[itemName], self:NewSlot(bag.bagId, slot, itemInfo.stackCount))
        end
      end
    end
  end

  result:SortSlots()
  return result
end

---@param handler fun(bag: number, slot: number, itemName: string, itemID: number, itemCount: number)
function bagModule:ForEachBagItem(handler)
  local result = --[[---@type RsInventoryCountByItemName]] {}
  for _, bag in ipairs(self.PLAYER_BAGS) do
    for slot = 1, C_Container.GetContainerNumSlots(bag.bagId) do
      --local _, itemCount, locked, _, _, _, itemLink, _, _, itemID =
      local itemInfo = C_Container.GetContainerItemInfo(bag.bagId, slot)

      if itemInfo and itemInfo.itemID and itemInfo.hyperlink then
        local itemName = --[[---@type string]] (string.match(itemInfo.hyperlink, "%[(.*)%]"))
        handler(bag.bagId, slot, itemName, itemInfo.itemID, itemInfo.stackCount)
      end
    end
  end
  return result
end

---@param predicate fun(s: string): boolean|nil
---@return RsInventory
function bagModule:GetItemsInBank(predicate)
  local result = self:NewInventory()

  for _, bag in ipairs(self.BANK_BAGS_REVERSED) do
    for slot = 1, C_Container.GetContainerNumSlots(bag.bagId) do
      --local _, itemCount, locked, _, _, _, itemLink, _, _, itemID =
      local itemInfo = C_Container.GetContainerItemInfo(bag.bagId, slot)
      if itemInfo and itemInfo.itemID then
        local itemName = --[[---@type string]] string.match(itemInfo.hyperlink, "%[(.*)%]")

        -- Allow filtering by predicate
        if predicate == nil or predicate(itemName) == true then
          result.summary[itemName] = (result.summary[itemName] and result.summary[itemName] + itemInfo.stackCount)
              or itemInfo.stackCount

          result.slots[itemName] = result.slots[itemName] or {}
          table.insert(result.slots[itemName], self:NewSlot(bag.bagId, slot, itemInfo.stackCount))
        end
      end
    end
  end

  result:SortSlots()
  return result
end

-----@param dropItem RsItem
-----@param bag number BagID https://wowwiki-archive.fandom.com/wiki/BagId
-----@return RsInventorySlotNumber|nil Returns bag, slot where drop happened
--function bagModule:DropCursorItemIntoBag(dropItem, bag)
--  if not CursorHasItem() then
--    RS:Debug("DropCursorItemIntoBag: Cursor doesn't have item!")
--    return nil
--  end
--
--  -- Search through the bag for an empty slot
--  for slot = 1, C_Container.GetContainerNumSlots(bag) do
--    local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
--
--    if not itemInfo then
--      -- must be empty where we drop!
--      C_Container.UseContainerItem(bag, slot, nil, nil)
--      RS:Debug("DropCursorItemIntoBag: to bag " .. bag .. " slot " .. slot)
--      return --[[---@type RsInventorySlotNumber]] { bag = bag, slot = slot }
--    end
--  end -- for all bag slots
--  return nil
--end

--function bagModule:BagSlotFromBag(bag)
--  if tContains(self.PLAYER_BAGS, bag) then
--    local bagSlot, _icon, _ = GetInventorySlotInfo("BAG" .. (bag - 1) .. "SLOT")
--    return bagSlot
--  else
--    if bag == self.BANK_CONTAINER then
--      -- Handle the bank main bag (-1) special value
--      local bagSlot, _icon, _ = GetInventorySlotInfo("BAG1")
--      return bagSlot
--    else
--      -- Handle the bank other bags 5..11 become BAG2...
--      local bagSlot, _icon, _ = GetInventorySlotInfo("BAG" .. (bag - 3))
--      return bagSlot
--    end
--  end
--end

---Takes cursor item. Drops it into one of the bank bags.
---@return boolean Success
function bagModule:PutItemInBank()
  if not CursorHasItem() then
    return false
  end
  --C_NewItems.ClearAll() -- don't show item is new?

  for _, bag in ipairs(self.BANK_BAGS) do
    if bag:HasSpace() then
      bag:PutCursorItem()
      return true
    end
  end

  return false
end

---Takes cursor item. Drops it into one of the bank bags.
---@return boolean Success
function bagModule:PutItemInPlayerBag()
  if not CursorHasItem() then
    return false
  end
  --C_NewItems.ClearAll() -- don't show item is new?

  for _, bag in ipairs(self.PLAYER_BAGS) do
    if bag:HasSpace() then
      bag:PutCursorItem()
      return true
    end
  end

  return false
end

---@param bags RsBagDef[]
function bagModule:CheckSpace(bags)
  for _, bag in ipairs(bags) do
    local numberOfFreeSlots, _bagType = C_Container.GetContainerNumFreeSlots(bag.bagId)
    if numberOfFreeSlots > 0 then
      return true
    end
  end
  return false
end

---From bags list, retrieve items which are not locked and match predicate
---@param bags RsBagDef[] List of bags from bagModule.* constants
---@param predicate function
---@return RsContainerItemInfo[]
function bagModule:ScanBagsFor(bags, predicate)
  local itemCandidates = --[[---@type RsContainerItemInfo[] ]] {}

  for _, bag in ipairs(bags) do
    for slot = 1, C_Container.GetContainerNumSlots(bag.bagId), 1 do
      local containerItemInfo = itemModule:GetContainerItemInfo(bag.bagId, slot)
      if containerItemInfo then
        if (--[[---@not nil]] containerItemInfo).locked then
          return {} -- can't do nothing now, something is locked, try in 0.1 sec
        end

        if predicate(containerItemInfo) then
          table.insert(itemCandidates, --[[---@not nil]] containerItemInfo)
        end
      end -- if item in that slot
    end -- for all slots
  end -- for all bags

  return itemCandidates
end

-- TODO: Drop old algorithm below, use RsInventory.slots to pick smallest stack of specific item
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
---@param moveAmount number
function bagModule:MoveFromBankToPlayer_1(task, candidates, moveAmount)
  for _index, moveCandidate in ipairs(candidates) do

    -- Move if entire stack found which fits
    if moveCandidate.count <= moveAmount then
      RS:Debug("Use " .. moveCandidate.name .. " from bank, bag=" .. moveCandidate.bag .. ", slot=" .. moveCandidate.slot)
      C_Container.UseContainerItem(moveCandidate.bag, moveCandidate.slot, nil, nil)
      task[moveCandidate.name] = task[moveCandidate.name] - moveCandidate.count -- deduct
      return true -- DONE one step
    end

    if moveCandidate.count > moveAmount then
      local itemInfo = RS.GetItemInfo(moveCandidate.itemId)
      RS:Debug("Split " .. moveCandidate.name .. " from bank, bag=" .. moveCandidate.bag .. ", slot=" .. moveCandidate.slot)

      -- Split and take
      C_Container.SplitContainerItem(moveCandidate.bag, moveCandidate.slot, moveAmount)
      --coroutine.yield()

      bagModule:PutItemInPlayerBag()

      task[moveCandidate.name] = task[moveCandidate.name] - moveAmount -- deduct
      return true -- DONE one step
    end
  end

  return false
end

---@param task table<string, number>
---@param moveName string
---@param moveAmount number Negative for take from bag, positive for take from bank
function bagModule:MoveFromBankToPlayer(task, moveName, moveAmount)
  local bankBagsReverse = self:GetBankBags(true)

  -------------------------------------------
  -- Try move from all bank bags in reverse
  -------------------------------------------
  for _index0, bag in ipairs(bankBagsReverse) do
    -- TODO: Drop old algorithm below, use RsInventory.slots
    -- Build list of move candidates. Sort them to contain smallest stacks first.
    local moveCandidates = self:ScanBagsFor({ bag }, rsContainerItemInfoMatchName(moveName))
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

---@param candidates RsContainerItemInfo[] Sorted by stack size move candidates in different bag slots
function bagModule:MoveFromPlayerToBank_1(task, candidates, moveAmount)
  for _index, containerItemInfo in ipairs(candidates) do
    -- Found something to move and its smaller than what we need to move
    if containerItemInfo.count <= moveAmount then
      C_Container.UseContainerItem(containerItemInfo.bag, containerItemInfo.slot, nil, nil)
      task[containerItemInfo.name] = task[containerItemInfo.name] + containerItemInfo.count -- deduct
      return true -- moved one
    end

    -- Found something to move, but its bigger than how many we need to move
    if containerItemInfo.count > moveAmount then
      local itemInfo = RS.GetItemInfo(containerItemInfo.itemId)

      C_Container.SplitContainerItem(containerItemInfo.bag, containerItemInfo.slot, moveAmount)
      --coroutine.yield()

      bagModule:PutItemInBank()

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
  local playerBags = self:GetPlayerBags(false)

  -------------------------------------------
  -- Try move from all player bags
  -- Build list of candidates, slots where this item is located
  -- Sort the candidates by stack size to move smallest first
  -------------------------------------------
  for _index0, bag in ipairs(playerBags) do
    -- TODO: Drop old algorithm below, use RsInventory.slots
    -- Build list of move candidates. Sort them to contain smallest stacks first.
    local moveCandidates = self:ScanBagsFor(
        { bag }, rsContainerItemInfoMatchName(moveName))

    -- Possibly nil, and try again?
    if moveCandidates == nil then
      RS:Debug("No move candidates found for playerToBank?")
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
