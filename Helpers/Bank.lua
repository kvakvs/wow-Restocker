---@type RestockerAddon
local _, RS = ...;

---@class RsBankModule
local bankModule = RsModule.DeclareModule("Bank") ---@type RsBankModule

local bagModule = RsModule.Import("Bag") ---@type RsBagModule

bankModule.didBankStuff = false

---Called once on Addon creation. Sets up constants for bank bags
function bankModule.OnModuleInit()
end

-- unused
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

-- unused
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

---@param state BankRestockCoroState
---@param moveName string
---@param moveAmount number Negative for take from bag, positive for take from bank
local function rsToBank(state, moveName, moveAmount)
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
        state.task[itemName] = state.task[itemName] + slotCount -- deduct
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

        state.task[itemName] = state.task[itemName] + moveAmount -- add
        return true -- DONE one step
      end
    end
  end
  return false -- did not move
end

---Try move full stacks in or out of bank, if not possible, then try move 1 item at a time.
---@param state BankRestockCoroState
local function coroBagToBankExchange(state)
  for moveName, moveAmount in pairs(state.task) do
    -- Negative for take from bag, positive for take from bank
    if moveAmount < 0 then
      if rsToBank(state, moveName, math.abs(moveAmount)) then
        return -- DONE one step
      end
    end
  end
end

---@param state BankRestockCoroState
---@param moveName string
---@param moveAmount number Negative for take from bag, positive for take from bank
local function rsFromBank(state, moveName, moveAmount)
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
        state.task[itemName] = state.task[itemName] - slotCount -- deduct
        return true -- DONE one step
      end

      if itemName == moveName
          and slotCount > moveAmount
      then
        local itemInfo = RS.GetItemInfo(slotItemId)

        SplitContainerItem(bag, slot, moveAmount)
        --rsPutSplitItemIntoBags(itemInfo, 1, BANK_BAGS, PLAYER_BAGS)
        bagModule:SplitSwapCursorItem(itemInfo, bagModule.BANK_BAGS)

        state.task[itemName] = state.task[itemName] - moveAmount -- deduct
        return true -- DONE one step
      end
    end
  end
  return false -- did not move
end

---Try move full stacks out of bank, if not possible, then try move 1 item at a time.
---@param state BankRestockCoroState
local function coroBankToBagExchange(state)
  for moveName, moveAmount in pairs(state.task) do
    -- Negative for take from bag, positive for take from bank
    if moveAmount > 0 then
      if rsFromBank(state, moveName, moveAmount) then
        return
      end
    end
  end
end

---@class BankRestockCoroState
---@field itemsInBags table<string, number> How many items in bags, name is key, count is value
---@field itemsInBank table<string, number> How many items in bank, name is key, count is value
---@field currentProfile table
---@field task table<string, number> What item, and how many to move (negative = move to bank)

---Go through the bags and see what's too much in our bag and must be sent to bank
---The values will be stored in dictionary with negative quantities
---(i.e. remove from backpack)
---@param state BankRestockCoroState
---@return number, table<string, number> Count of items to move and table of item names to move
local function rsCountMoveItems(state)
  local task = {}
  local moveCount = 0

  for i, rs in pairs(state.currentProfile) do
    local haveInBackpack = state.itemsInBags[rs.itemName] or 0
    local haveInBank = state.itemsInBank[rs.itemName] or 0

    --If have more than in restocker config, move excess to bank
    if rs.amount < haveInBackpack then
      -- Negative for take from bag, positive for take from bank
      task[rs.itemName] = rs.amount - haveInBackpack
      moveCount = moveCount + math.abs(task[rs.itemName])
    else
      -- if have in bank
      if rs.amount > haveInBackpack and haveInBank > 0 then
        -- Negative for take from bag, positive for take from bank
        task[rs.itemName] = math.min(
            rs.amount - haveInBackpack, -- don't move more than we need
            haveInBank) -- but not more than have in bank
        moveCount = moveCount + math.abs(task[rs.itemName])
      end
    end
  end -- for all items in restock list

  return moveCount, task
end

---@return string "ok", "bank" - bank is full, "bag" - bag is full, "both" - both bank and bag are full
local function rsCheckBankBagSpace()
  local bankFree = bagModule:CheckSpace(bagModule.BANK_BAGS)
  local bagFree = bagModule:CheckSpace(bagModule.PLAYER_BAGS)
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

---Coroutine function to unload extra goods into bank and load goods from bank
local function coroutineBank()
  if not RS.bankIsOpen then
    RS.currentlyRestocking = false
    RS.Print("Bank is not open")
    return
  end

  ---@type BankRestockCoroState
  local state = {
    itemsInBags    = bagModule:GetItemsInBags(),
    itemsInBank    = bagModule:GetItemsInBank(),
    currentProfile = Restocker.profiles[Restocker.currentProfile],
    task           = {}
  }
  local moveCount = 0
  moveCount, state.task = rsCountMoveItems(state)

  if moveCount < 1 then
    RS.currentlyRestocking = false
    RS.Print("Finished restocking")
    return
  end

  local bagCheck = rsCheckBankBagSpace()
  if bagCheck == "both" then
    RS.currentlyRestocking = false
    RS.Print("Both bag and bank are full, need 1 free slot to begin")
    return
  elseif bagCheck == "bank" then
    RS.currentlyRestocking = false
    RS.Print("Bank is full, need 1 free slot to begin")
    return
  elseif bagCheck == "bag" then
    RS.currentlyRestocking = false
    RS.Print("Bag is full, need 1 free slot to begin")
    return
  end

  coroBagToBankExchange(state)
  coroBankToBagExchange(state)
end

---For debugging restocking coroutine do the scriptErrors once, then run xxx() like so
---/console scriptErrors 1
---/run RS_ADDON.xxx()
local function testCoroutineBank()
  RS.currentlyRestocking = true
  coroutineBank()
end

RS.xxx = testCoroutineBank
restockerCoroutine = coroutine.create(coroutineBank)


--
-- OnUpdate frame
--

local rsUpdateTimer = 0
local function rsBankUpdateFn(self, elapsed)
  rsUpdateTimer = rsUpdateTimer + elapsed

  -- Ping x 3 defines the click frequency. But never go faster than 140 ms
  local _down, _up, pingHome, pingWorld = GetNetStats();
  local maxPing = math.max(pingHome, pingWorld)
  local updateInterval = math.max(0.140, (maxPing * 3) / 1000)

  if rsUpdateTimer >= updateInterval then
    rsUpdateTimer = 0

    if RS.currentlyRestocking then
      if bagModule:IsSomethingLocked() and not CursorHasItem() then
        return
      end

      if coroutine.status(restockerCoroutine) == "running" then
        return
      end

      local resume = coroutine.resume(restockerCoroutine)

      if resume == false then
        restockerCoroutine = coroutine.create(coroutineBank)
      end
    end
  end
end

RS.onUpdateFrame = CreateFrame("Frame")
RS.onUpdateFrame:SetScript("OnUpdate", rsBankUpdateFn)
