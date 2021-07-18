---@type RestockerAddon
local _, RS = ...;

RS.didBankStuff = false
RS.justSplit = false
RS.splitLoc = {}

local BANK_BAGS -- set up in RS.SetupBankConstants
local BANK_BAGS_REVERSED -- set up in RS.SetupBankConstants

if REAGENTBANK_CONTAINER then
  tinsert(BANK_BAGS, REAGENTBANK_CONTAINER)
  tinsert(BANK_BAGS_REVERSED, REAGENTBANK_CONTAINER)
end

local GetContainerItemInfo = _G.GetContainerItemInfo

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
  for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
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

---@param item RsItem
---@param amountOnMouse number
local function rsPutSplitItemIntoBags(item, amountOnMouse)
  if not CursorHasItem() then
    return
  end
  C_NewItems.ClearAll()

  -- for all bags: backpack, 1,2,3,4
  -- Try find an incomplete stack that will fit the items we're moving
  for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
    for slot = 1, GetContainerNumSlots(bag) do
      local _, itemCount, locked, _, _, _, _, _, _, itemID = GetContainerItemInfo(bag, slot)
      if itemID and not locked then
        --local itemName, _, _, _, _, _, _, itemStackCount = GetItemInfo(itemID)
        local itemInfo = RS.GetItemInfo(itemID)
        if itemInfo ~= nil
            and itemInfo.itemName == item.itemName
            and itemCount + amountOnMouse <= itemInfo.itemStackCount then
          PickupContainerItem(bag, slot)
        end
      end
    end
  end

  -- for all bags: backpack, 1,2,3,4
  -- Try find a free bag slot
  for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
    local numberOfFreeSlots, bagType = GetContainerNumFreeSlots(bag)
    if numberOfFreeSlots > 0 then
      local currentBag = bag + 19

      if bag == BACKPACK_CONTAINER then
        PutItemInBackpack()
        return
      else
        PutItemInBag(currentBag)
        return
      end
    end
  end
end

--- If have more items than restock count, unload to bank
---@param state BankRestockCoroState
local function coroSendToBank(state)
  -- for all bags: backpack, 1,2,3,4 in reverse order
  for bag = NUM_BAG_SLOTS, BACKPACK_CONTAINER, -1 do
    for slot = GetContainerNumSlots(bag), 1, -1 do
      local _, itemCount, locked, _, _, _, itemLink, _, _, itemId = GetContainerItemInfo(bag, slot)

      local itemName = itemLink and string.match(itemLink, "%[(.*)%]")
      if itemId then
        local inRestockList = rsIsItemInRestockList(itemName)

        if not locked and inRestockList then
          local item = state.currentProfile[rsGetRestockItemIndex(itemName)]
          local numInBags = state.itemsInBags[item.itemName] or 0
          local restockNum = item.amount
          local difference = restockNum - numInBags

          if difference < 0 then
            UseContainerItem(bag, slot)
            state.itemsInBags[item.itemName] = state.itemsInBags[item.itemName]
                and state.itemsInBags[item.itemName] - itemCount
            state.rightClickedItem = true
            state.transferredToBank = true

            RS.didBankStuff = true
            --coroutine.yield()
          end
        end
      end -- if item we should get and its not locked
    end -- for slot
  end -- for bag
end

---If have too few restock items, and the bank has them, take from bank
---@param state BankRestockCoroState
local function coroTakeFromBank(state)
  if state.transferredToBank then
    return
  end

  -- full stacks
  for _, bag in ipairs(BANK_BAGS_REVERSED) do
    for slot = GetContainerNumSlots(bag), 1, -1 do
      local _, itemCount, locked, _, _, _, itemLink, _, _, itemId = GetContainerItemInfo(bag, slot)
      local itemName = itemLink and string.match(itemLink, "%[(.*)%]")

      if itemId and not locked then
        local inRestockList = rsIsItemInRestockList(itemName)

        if not locked and inRestockList then

          local item = state.currentProfile[rsGetRestockItemIndex(itemName)]
          local numInBags = state.itemsInBags[item.itemName] or 0
          local restockNum = item.amount
          local difference = restockNum - numInBags

          if difference > 0 and itemCount <= difference then
            UseContainerItem(bag, slot)

            state.itemsInBags[item.itemName] = (state.itemsInBags[item.itemName]
                and state.itemsInBags[item.itemName] + itemCount or itemCount)
            state.rightClickedItem = true

            RS.didBankStuff = true
            --coroutine.yield()
          end
        end
      end -- if item we should get and its not locked
    end -- for slot
  end -- for bag
end

---@param state BankRestockCoroState
local function coroSplitStacks(state)
  if state.rightClickedItem then
    return
  end

  -- split stacks
  for _, bag in ipairs(BANK_BAGS_REVERSED) do
    for slot = GetContainerNumSlots(bag), 1, -1 do
      local _, itemCount, locked, _, _, _, itemLink, _, _, itemId = GetContainerItemInfo(bag, slot)
      local itemName = itemLink and string.match(itemLink, "%[(.*)%]")

      if itemId and not locked then
        local inRestockList = rsIsItemInRestockList(itemName)
        local itemInfo = RS.GetItemInfo(itemName)

        if inRestockList then
          local item = state.currentProfile[rsGetRestockItemIndex(itemName)]
          local numInBags = state.itemsInBags[item.itemName] or 0
          local difference = item.amount - numInBags

          -- This will split one stack or move full stack to bags
          if difference > 0 and itemCount > difference then
            local toSplit = mod(difference + numInBags, itemInfo.itemStackCount)

            if toSplit == 0 then
              -- if the amount we need creates a full stack in the inventory we simply have to
              -- pick up the item and place it on the incomplete stack in our inventory
              -- if we split stacks here we get an error saying "couldn't split those items."
              PickupContainerItem(bag, slot)
            else
              -- if the amount of items we need doesn't create a full stack then we split
              -- the stack in the bank and merge it with the one in our inventory.
              SplitContainerItem(bag, slot, toSplit)
            end

            rsPutSplitItemIntoBags(item, toSplit)

            RS.didBankStuff = true
            state.itemsInBags[item.itemName] = (state.itemsInBags[item.itemName]
                and state.itemsInBags[item.itemName] + toSplit or toSplit)

            state.hasSplitItems = true
            --coroutine.yield()
          end
        end
      end -- if item we should get and its not locked
    end -- for slot
  end -- for bag
end

---@class BankRestockCoroState
---@field itemsInBags table<string, number> How many items in bags, name is key, count is value
---@field itemsInBank table<string, number> How many items in bank, name is key, count is value
---@field currentProfile table
---@field rightClickedItem boolean
---@field hasSplitItems boolean
---@field transferredToBank boolean

---Go through the bags and see what's too much in our bag and must be sent to bank
---The values will be stored in dictionary with negative quantities
---(i.e. remove from backpack)
---@param state BankRestockCoroState
---@return table<string, number> What item, and how many (negative = move to bank)
local function rsCountItemsToMove(state)
  local task = {}

  for i, rs in pairs(state.currentProfile) do
    local haveInBackpack = state.itemsInBags[rs.itemName] or 0
    local haveInBank = state.itemsInBank[rs.itemName] or 0

    --If have more than in restocker config, move excess to bank
    if rs.amount < haveInBackpack then
      -- Negative for take from bag, positive for take from bank
      task[rs.itemName] = rs.amount - haveInBackpack
      RS.Dbg(string.format("To bank %s=%d", rs.itemName, task[rs.itemName]))
    else
      -- if need more than have in backpack BUT have in bank
      if rs.amount > haveInBackpack and haveInBank > 0 then
        -- Negative for take from bag, positive for take from bank
        task[rs.itemName] = math.min(
            rs.amount - haveInBackpack, -- don't move more than we need
            haveInBank) -- but not more than have in bank
        RS.Dbg(string.format("From bank %s=%d", rs.itemName, task[rs.itemName]))
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
  }

  local task = rsCountItemsToMove(state)
  --coroSendToBank(state)
  --coroTakeFromBank(state)
  --coroSplitStacks(state)

  if not state.rightClickedItem
      and not state.transferredToBank
      and not state.hasSplitItems
      and RS.didBankStuff
      and RS.minorChange == false then
    RS.currentlyRestocking = false
    RS.Print("Finished restocking from bank")
  end
end

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