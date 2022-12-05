--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

---@class RsBankModule
---@field bankIsOpen boolean
---@field currentlyRestocking boolean
local bankModule = RsModule.bankModule
bankModule.bankIsOpen = false

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

---@alias RsInventoryByItemName {[string]: number} Items in the bag by name
---@alias RsMoveItemTask {[string]: number} Item name is key, amount to buy is value

---@class BankRestockCoroState
---@field itemsInBags RsInventoryByItemName How many items in bags, name is key, count is value
---@field itemsInBank RsInventoryByItemName How many items in bank, name is key, count is value
---@field currentProfile RsTradeCommand[]
---@field task RsMoveItemTask What item, and how many to move (negative = move to bank)
---@field moveCount number
local coroStateClass = {}
coroStateClass.__index = coroStateClass

function bankModule:NewCoroState()
  local fields = --[[---@type BankRestockCoroState]] {}
  local settings = restockerModule.settings

  fields.itemsInBags = bagModule:GetItemsInBags()
  fields.itemsInBank = bagModule:GetItemsInBank()
  fields.currentProfile = --[[---@not nil]] settings.profiles[settings.currentProfile]
  fields.task = --[[---@type RsMoveItemTask]] {}
  fields.moveCount = 0

  setmetatable(fields, coroStateClass)
  return fields
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

---Go through the bags and see what's too much in our bag and must be sent to bank
function coroStateClass:CountItemsTooMany()
  for i, eachItem in pairs(self.currentProfile) do
    local haveInBackpack = self.itemsInBags[eachItem.itemName] or 0

    --If have more than in restocker config, move excess to bank
    if eachItem.amount < haveInBackpack
        and eachItem.stashTobank
    then
      -- Negative for take from bag, positive for take from bank
      self.task[eachItem.itemName] = eachItem.amount - haveInBackpack
      self.moveCount = self.moveCount + math.abs(self.task[eachItem.itemName])
    end
  end -- for all items in restock list
end

---Go through the bags and see what's too much in our bag and must be sent to bank
function coroStateClass:CountItemsTooFew()
  for i, eachItem in pairs(self.currentProfile) do
    local haveInBackpack = self.itemsInBags[eachItem.itemName] or 0
    local haveInBank = self.itemsInBank[eachItem.itemName] or 0

    if eachItem.amount > haveInBackpack
        and haveInBank > 0
        and eachItem.restockFromBank
    then
      -- Negative for take from bag, positive for take from bank
      self.task[eachItem.itemName] = math.min(
          eachItem.amount - haveInBackpack, -- don't move more than we need
          haveInBank) -- but not more than have in bank
      self.moveCount = self.moveCount + math.abs(self.task[eachItem.itemName])
    end
  end -- for all items in restock list
end

---Coroutine function to unload extra goods into bank and load goods from bank
function bankModule:coroutineBank()
  if not self.bankIsOpen then
    self.currentlyRestocking = false
    RS:Print("Bank is not open")
    return
  end

  local state = self:NewCoroState()
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

--- For debugging restocking coroutine do the scriptErrors once, then run xxx() like so
--- /console scriptErrors 1
--- /run RS_ADDON.testBank()
function RS.testBank()
  bankModule.currentlyRestocking = true
  bankModule:coroutineBank()
end

local restockerCoroutine = coroutine.create(function()
  bankModule:coroutineBank()
end)


--
-- OnUpdate frame
--

local rsUpdateTimer = 0
function bankModule.BankUpdateFn(self, elapsed)
  rsUpdateTimer = rsUpdateTimer + elapsed

  -- Ping x 3 defines the click frequency. But never go faster than 140 ms
  local _down, _up, pingHome, pingWorld = GetNetStats()
  local maxPing = math.max(pingHome, pingWorld)
  local updateInterval = math.max(0.140, (maxPing * 3) / 1000)

  if rsUpdateTimer >= updateInterval then
    rsUpdateTimer = 0

    if bankModule.currentlyRestocking then
      if bagModule:IsSomethingLocked() and not CursorHasItem() then
        return
      end

      if coroutine.status(restockerCoroutine) == "running" then
        return
      end

      local resume = coroutine.resume(restockerCoroutine)

      if resume == false then
        restockerCoroutine = coroutine.create(function()
          bankModule:coroutineBank()
        end)
      end
    end
  end
end

RS.onUpdateFrame = CreateFrame("Frame")
RS.onUpdateFrame:SetScript("OnUpdate", bankModule.BankUpdateFn)
