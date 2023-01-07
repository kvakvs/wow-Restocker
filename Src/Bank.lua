--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

---@class RsBankModule
---@field bankIsOpen boolean
---@field currentlyRestocking boolean
---@field updateTimer number
---@field state BankRestockCoroState
local bankModule = RsModule.bankModule
bankModule.bankIsOpen = false
bankModule.updateTimer = 0

local restockerModule = RsModule.restockerModule ---@type RsRestockerModule
local bagModule = RsModule.bagModule ---@type RsBagModule

bankModule.didBankStuff = false

-- -@shape RsInventorySlot
-- -@field bag number
-- -@field slot number
-- -@field itemName string
-- -@field itemID WowItemId
-- -@field count number
-- -@field maxStack number

---@class RsInventorySlotNumber
---@field bag number
---@field slot number

---@class RsSlot
---@field bag number
---@field slot number
---@field count number

---@alias RsInventoryCountByItemName {[string]: number} Items in the bag by name
---@alias RsInventorySlotByItemName {[string]: RsSlot[]} Items in the bag by name
---@alias RsMoveItemTask {[string]: number} Item name is key, amount to buy is value

---Collection of items in the inventory or bank with their precise slot locations and counts, and summaries
---@class RsInventory
---@field summary RsInventoryCountByItemName
---@field slots RsInventorySlotByItemName

---@class BankRestockCoroState
---@field bagInventory RsInventory How many items in bags, summary and per slot
---@field bankInventory RsInventory How many items in bank, summary and per slot
---@field currentProfile RsTradeCommand[]
---@field task RsMoveItemTask What item, and how many to move (negative = move to bank)
---@field moveCount number
local coroStateClass = {}
coroStateClass.__index = coroStateClass

function bankModule:NewCoroState()
  local state = --[[---@type BankRestockCoroState]] {}
  local settings = restockerModule.settings
  local currentProfile = --[[---@not nil]] settings.profiles[settings.currentProfile]

  state.currentProfile = currentProfile
  state.task = --[[---@type RsMoveItemTask]] {}
  state.moveCount = 0

  setmetatable(state, coroStateClass)
  return state
end

---Called once on Addon creation. Sets up constants for bank bags
function bankModule.OnModuleInit()
end

---Try move full stacks in or out of bank, if not possible, then try move 1 item at a time.
function coroStateClass:StashToBank()
  for moveName, moveAmount in pairs(self.task) do
    -- Negative for take from bag, positive for take from bank
    if moveAmount < 0 then
      if bagModule:MoveFromPlayerToBank(self.task, moveName, math.abs(moveAmount)) then
        return -- DONE one step
      end
    end
  end
end

---Try move full stacks out of bank, if not possible, then try move 1 item at a time.
function coroStateClass:RestockFromBank()
  for moveName, moveAmount in pairs(self.task) do
    -- Negative for take from bag, positive for take from bank
    if moveAmount > 0 then
      if bagModule:MoveFromBankToPlayer(self.task, moveName, moveAmount) then
        return
      end
    end
  end
end

function coroStateClass:UpdateInventory()
  local settings = restockerModule.settings
  local currentProfile = --[[---@not nil]] settings.profiles[settings.currentProfile]

  -- Function to check that the bag or bank item is interesting for our restocking needs
  local itemExistsFn = ---@param itemname string
  function(itemname)
    for _i, eachItem in pairs(currentProfile) do
      if eachItem.itemName == itemname then
        return true
      end
    end
    return false
  end

  self.bagInventory = bagModule:GetItemsInBags(itemExistsFn)
  self.bankInventory = bagModule:GetItemsInBank(itemExistsFn)
end

---Go through the bags and see what's too much in our bag and must be sent to bank
function coroStateClass:CountItemsTooMany()
  -- TODO: Calculate optimal stack size and block those stacks from moving
  for i, eachItem in pairs(self.currentProfile) do
    local haveInBackpack = self.bagInventory.summary[eachItem.itemName] or 0

    --If have more than in restocker config, move excess to bank
    if eachItem.amount < haveInBackpack
        and eachItem.stashTobank
    then
      RS:Debug(string.format("Too many %s in bag (%d)", eachItem.itemName, haveInBackpack))
      -- Negative for take from bag, positive for take from bank
      self.task[eachItem.itemName] = eachItem.amount - haveInBackpack
      self.moveCount = self.moveCount + math.abs(self.task[eachItem.itemName])
    end
  end -- for all items in restock list
end

---Go through the bags and see what's too few in our bag and must be restocked from bank
function coroStateClass:CountItemsTooFew()
  -- TODO: Calculate optimal stack size and block those stacks from moving
  for i, eachItem in pairs(self.currentProfile) do
    local haveInBackpack = self.bagInventory.summary[eachItem.itemName] or 0
    local haveInBank = self.bankInventory.summary[eachItem.itemName] or 0

    if eachItem.amount > haveInBackpack
        and haveInBank > 0
        and eachItem.restockFromBank
    then
      RS:Debug(string.format("Too few %s in bag (%d)", eachItem.itemName, haveInBackpack))
      -- Negative for take from bag, positive for take from bank
      self.task[eachItem.itemName] = math.min(
          eachItem.amount - haveInBackpack, -- don't move more than we need
          haveInBank) -- but not more than have in bank
      self.moveCount = self.moveCount + math.abs(self.task[eachItem.itemName])
    end
  end -- for all items in restock list
end

---Coroutine function to unload extra goods into bank and load goods from bank
---@param state BankRestockCoroState
function bankModule:coroutineRestockLogic(state)
  if not self.bankIsOpen then
    self.currentlyRestocking = false
    RS:Print("Bank is not open")
    return
  end

  RS:Debug("theCoroutine/restock logic called")

  state:UpdateInventory()
  state:CountItemsTooMany() -- to store extras to bank
  state:CountItemsTooFew() -- to restock from bank

  if state.moveCount < 1 then
    self.currentlyRestocking = false
    RS:Print("Finished restocking. Hold Shift to skip next time.")
    return
  end

  local bagCheck = bagModule:CheckBankBagSpace()
  if bagCheck == "both" then
    self.currentlyRestocking = false
    RS:Print("Both bag and bank are full, need 1 free slot to begin")
    return
  elseif bagCheck == "bank" then
    self.currentlyRestocking = false
    RS:Print("Bank is full, need 1 free slot to begin")
    return
  elseif bagCheck == "bag" then
    self.currentlyRestocking = false
    RS:Print("Bag is full, need 1 free slot to begin")
    return
  end

  state:StashToBank()
  state:RestockFromBank()
end

local theCoroutineFn = function()
  bankModule.state = bankModule:NewCoroState()
  bankModule:coroutineRestockLogic(bankModule.state)
end
local theCoroutineObject = coroutine.create(theCoroutineFn)

--- For debugging restocking coroutine do the scriptErrors once, then run xxx() like so
--- /console scriptErrors 1
--- /run RS_ADDON.testBank()
function RS.testBank()
  bankModule.currentlyRestocking = true
  theCoroutineFn()
end

--
-- OnUpdate frame
--

function bankModule.BankUpdateFn(self, elapsed)
  bankModule.updateTimer = bankModule.updateTimer + elapsed

  -- Ping x 3 defines the click frequency. But never go faster than 140 ms
  local _down, _up, pingHome, pingWorld = GetNetStats()
  local maxPing = math.max(pingHome, pingWorld)
  local updateInterval = math.max(0.140, (maxPing * 3) / 1000)

  if bankModule.updateTimer >= updateInterval then
    bankModule.updateTimer = 0

    if bankModule.currentlyRestocking then
      if bagModule:IsSomethingLocked() and not CursorHasItem() then
        return
      end

      if coroutine.status(theCoroutineObject) == "running" then
        return
      end

      local resume = coroutine.resume(theCoroutineObject)

      if resume == false then
        theCoroutineObject = coroutine.create(theCoroutineFn)
      end
    end
  end
end

RS.onUpdateFrame = CreateFrame("Frame")
RS.onUpdateFrame:SetScript("OnUpdate", bankModule.BankUpdateFn)
