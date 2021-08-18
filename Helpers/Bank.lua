---@type RestockerAddon
local _, RS = ...;

RS.didBankStuff = false
RS.justSplit = false
RS.splitLoc = {}

local BACKPACK_CONTAINER = 0
local BANK_CONTAINER = -1
local PLAYER_BAGS = {}
local PLAYER_BAGS_REVERSED = {}

local BANK_BAGS -- set up in RS.SetupBankConstants
local BANK_BAGS_REVERSED -- set up in RS.SetupBankConstants

--if REAGENTBANK_CONTAINER then
--  tinsert(BANK_BAGS, REAGENTBANK_CONTAINER)
--  tinsert(BANK_BAGS_REVERSED, REAGENTBANK_CONTAINER)
--end

--local GetContainerItemInfo = _G.GetContainerItemInfo

---Called once on Addon creation. Sets up constants for bank bags
function RS.SetupBankConstants()
  -- -1 bank container, 0 backpack, 1234 bags, 5-10 or 5-11 is TBC bank
  if RS.TBC then
    BANK_BAGS = { BANK_CONTAINER, 5, 6, 7, 8, 9, 10, 11 }
    BANK_BAGS_REVERSED = { 11, 10, 9, 8, 7, 6, 5, BANK_CONTAINER }
  else
    BANK_BAGS = { BANK_CONTAINER, 5, 6, 7, 8, 9, 10 }
    BANK_BAGS_REVERSED = { 10, 9, 8, 7, 6, 5, BANK_CONTAINER }
  end

  PLAYER_BAGS = { 0, 1, 2, 3, 4 }
  PLAYER_BAGS_REVERSED = { 4, 3, 2, 1, 0 }
end

local function rsCount(T)
  -- unused?
  local i = 0
  for _, _ in pairs(T) do
    i = i + 1
  end
  return i
end

local function rsIsSomethingLocked()
  for _, bag in ipairs(PLAYER_BAGS) do
    for slot = 1, GetContainerNumSlots(bag) do
      local _, _, locked = GetContainerItemInfo(bag, slot)
      if locked then
        return true
      end
    end
  end

  for _, bag in ipairs(BANK_BAGS_REVERSED) do
    for slot = 1, GetContainerNumSlots(bag) do
      local _, _, locked = GetContainerItemInfo(bag, slot)
      if locked then
        return true
      end
    end
  end

  return false
end

local function rsIsItemInRestockList(item)
  local type
  if tonumber(item) then
    type = "itemID"
  elseif string.find(item, "Hitem:") then
    type = "itemLink"
  else
    type = "itemName"
  end

  for _, restockItem in ipairs(Restocker.profiles[Restocker.currentProfile]) do
    if restockItem[type] == item then
      return true
    end
  end
  return false
end

local function rsGetRestockItemIndex(item)
  local type
  if tonumber(item) then
    type = "itemID"
  elseif string.find(item, "Hitem:") then
    type = "itemLink"
  else
    type = "itemName"
  end

  for i, restockItem in ipairs(Restocker.profiles[Restocker.currentProfile]) do
    if restockItem[type] == item then
      return i
    end
  end
  return nil
end

local function rsGetItemsInBags()
  local result = {}
  for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
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

local function rsGetItemsInBank()
  local result = {}
  for _, bag in ipairs(BANK_BAGS_REVERSED) do
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
local function rsDropCursorItemIntoBag(dropItem, bag)
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
local function rsSplitSwapCursorItem(dropItem, srcBags)
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
      local tmpBag, tmpSlot = rsDropCursorItemIntoBag(dropItem, bag)
      UseContainerItem(tmpBag, tmpSlot) -- move to the opposite container group bank-bag, or bag-bank
      return
    end
  end
end

---Try move full stacks in or out of bank, if not possible, then try move 1 item at a time.
---@param state BankRestockCoroState
local function coroBankExchange(state)
  ----------------------------------------------------
  -- for all bags: backpack, 1,2,3,4 in reverse order
  -- Move excess bag items out to the bank
  ----------------------------------------------------
  for _, bag in ipairs(PLAYER_BAGS_REVERSED) do
    for slot = GetContainerNumSlots(bag), 1, -1 do
      local _icon, slotCount, slotLocked, _, _, _, slotItemLink, _, _, slotItemId = GetContainerItemInfo(bag, slot)
      local itemName = slotItemLink and string.match(slotItemLink, "%[(.*)%]")

      -- negative - move from bag to bank
      if state.task[itemName] and not slotLocked and state.task[itemName] < 0
      then
        local needToMove = math.abs(state.task[itemName])

        if slotCount <= needToMove then
          -- If slot does not contain more than the task, take entire slot
          UseContainerItem(bag, slot)
          state.task[itemName] = state.task[itemName] + slotCount -- add
          return

        else
          local itemInfo = RS.GetItemInfo(slotItemId)

          SplitContainerItem(bag, slot, needToMove)
          --rsPutSplitItemIntoBags(itemInfo, 1, PLAYER_BAGS, BANK_BAGS)
          rsSplitSwapCursorItem(itemInfo, PLAYER_BAGS)

          state.task[itemName] = state.task[itemName] + needToMove -- add
        end
      end -- if we move to bank
    end -- for slot
  end -- for player bags

  ----------------------------------------------------
  -- For all bank bags, move needed items back to bags
  ----------------------------------------------------
  for _, bag in ipairs(BANK_BAGS_REVERSED) do
    for slot = GetContainerNumSlots(bag), 1, -1 do
      local _icon, slotCount, slotLocked, _, _, _, slotItemLink, _, _, slotItemId = GetContainerItemInfo(bag, slot)
      local itemName = slotItemLink and string.match(slotItemLink, "%[(.*)%]")

      -- positive - take from bank
      if state.task[itemName] and not slotLocked and state.task[itemName] > 0
      then
        local needToMove = state.task[itemName]

        if slotCount <= needToMove then
          -- If slot does not contain more than the task, take entire slot
          UseContainerItem(bag, slot)
          state.task[itemName] = state.task[itemName] - slotCount -- deduct
          return

        else
          -- Move 1 item at a time
          local itemInfo = RS.GetItemInfo(slotItemId)

          -- Take 1 drop 1
          SplitContainerItem(bag, slot, needToMove)
          --rsPutSplitItemIntoBags(itemInfo, 1, BANK_BAGS, PLAYER_BAGS)
          rsSplitSwapCursorItem(itemInfo, BANK_BAGS)

          state.task[itemName] = state.task[itemName] - needToMove -- deduct
        end
      end
    end -- for slot
  end -- for bank bags
end

---@class BankRestockCoroState
---@field itemsInBags table<string, number> How many items in bags, name is key, count is value
---@field itemsInBank table<string, number> How many items in bank, name is key, count is value
---@field currentProfile table
---@field rightClickedItem boolean
---@field hasSplitItems boolean
---@field transferredToBank boolean
---@field task table<string, number> What item, and how many to move (negative = move to bank)

---Go through the bags and see what's too much in our bag and must be sent to bank
---The values will be stored in dictionary with negative quantities
---(i.e. remove from backpack)
---@param state BankRestockCoroState
local function rsCountMoveItems(state)
  local task = {}

  for i, rs in pairs(state.currentProfile) do
    local haveInBackpack = state.itemsInBags[rs.itemName] or 0
    local haveInBank = state.itemsInBank[rs.itemName] or 0

    --If have more than in restocker config, move excess to bank
    if rs.amount < haveInBackpack then
      -- Negative for take from bag, positive for take from bank
      task[rs.itemName] = rs.amount - haveInBackpack
    else
      -- if have in bank
      if rs.amount > haveInBackpack and haveInBank > 0 then
        -- Negative for take from bag, positive for take from bank
        task[rs.itemName] = math.min(
            rs.amount - haveInBackpack, -- don't move more than we need
            haveInBank) -- but not more than have in bank
      end
    end
  end -- for all items in restock list

  return task
end

---Coroutine function to unload extra goods into bank and load goods from bank
local function coroutineBankLoadUnload()
  local state = { ---@type BankRestockCoroState
                  itemsInBags       = rsGetItemsInBags(),
                  itemsInBank       = rsGetItemsInBank(),
                  currentProfile    = Restocker.profiles[Restocker.currentProfile],
                  rightClickedItem  = false,
                  hasSplitItems     = false,
                  transferredToBank = false,
                  task              = {} }

  state.task = rsCountMoveItems(state)
  coroBankExchange(state)

  if not state.rightClickedItem
      and not state.transferredToBank
      and not state.hasSplitItems
      and RS.didBankStuff
      and RS.minorChange == false then
    RS.currentlyRestocking = false
    RS.Print("Finished restocking from bank")
  end
end

RS.xxx = coroutineBankLoadUnload -- for debugging restocking coroutin
restockerCoroutine = coroutine.create(coroutineBankLoadUnload)


--
-- OnUpdate frame
--

RS.onUpdateFrame = CreateFrame("Frame")
local ONUPDATE_INTERVAL = 0.1
local rsUpdateTimer = 0

RS.onUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
  rsUpdateTimer = rsUpdateTimer + elapsed

  if rsUpdateTimer >= ONUPDATE_INTERVAL then
    rsUpdateTimer = 0

    if RS.currentlyRestocking then
      if rsIsSomethingLocked() and not CursorHasItem() then
        return
      end

      if coroutine.status(restockerCoroutine) == "running" then
        return
      end

      local resume = coroutine.resume(restockerCoroutine)

      if resume == false then
        restockerCoroutine = coroutine.create(coroutineBankLoadUnload)
      end
    end
  end
end)