---@type RestockerAddon
local _, RS              = ...;

RS.didBankStuff          = false
RS.justSplit             = false
RS.splitLoc              = {}

local BANK_BAGS          = { -1, 5, 6, 7, 8, 9, 10 }
local BANK_BAGS_REVERSED = { 10, 9, 8, 7, 6, 5, -1 }
if REAGENTBANK_CONTAINER then
  tinsert(BANK_BAGS, REAGENTBANK_CONTAINER)
  tinsert(BANK_BAGS_REVERSED, REAGENTBANK_CONTAINER)
end

local GetContainerItemInfo = _G.GetContainerItemInfo

local function count(T)
  local i = 0
  for _, _ in pairs(T) do
    i = i + 1
  end
  return i
end

local function somethingLocked()
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

local function IsItemInRestockList(item)
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

local function GetRestockItemIndex(item)
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

local function GetItemsInBags()
  local T = {}
  for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
    for slot = 1, GetContainerNumSlots(bag) do
      local _, itemCount, locked, _, _, _, itemLink, _, _, itemID = GetContainerItemInfo(bag, slot)
      local itemName                                              = itemLink and string.match(itemLink, "%[(.*)%]")
      if itemID then
        T[itemName] = T[itemName] and T[itemName] + itemCount or itemCount
      end
    end
  end
  return T
end

local function PutSplitItemIntoBags(item, amountOnMouse)
  if not CursorHasItem() then
    return
  end
  C_NewItems.ClearAll()

  for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
    for slot = 1, GetContainerNumSlots(bag) do
      local _, itemCount, locked, _, _, _, _, _, _, itemID = GetContainerItemInfo(bag, slot)
      if itemID and not locked then
        local itemName, _, _, _, _, _, _, itemStackCount = GetItemInfo(itemID)
        if itemName == item.itemName and itemCount + amountOnMouse <= itemStackCount then
          PickupContainerItem(bag, slot)
        end
      end
    end
  end

  for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
    local numberOfFreeSlots, bagType = GetContainerNumFreeSlots(bag)
    if numberOfFreeSlots > 0 then
      local currentBag = bag + 19
      if currentBag == 19 then
        PutItemInBackpack()
        return
      else
        PutItemInBag(currentBag)
        return
      end
    end
  end
end

local function bankTransfer()
  local itemsInBags       = GetItemsInBags()

  local currentProfile    = Restocker.profiles[Restocker.currentProfile]
  local rightClickedItem  = false
  local hasSplitItems     = false
  local transferredToBank = false

  --
  --  INVENTORY
  --
  for bag = NUM_BAG_SLOTS, BACKPACK_CONTAINER, -1 do
    for slot = GetContainerNumSlots(bag), 1, -1 do
      local _, itemCount, locked, _, _, _, itemLink, _, _, itemID = GetContainerItemInfo(bag, slot)
      local itemName                                              = itemLink and string.match(itemLink, "%[(.*)%]")
      if itemID then
        local inRestockList = IsItemInRestockList(itemName)

        if not locked and inRestockList then
          local item       = currentProfile[GetRestockItemIndex(itemName)]
          local numInBags  = itemsInBags[item.itemName] or 0
          local restockNum = item.amount
          local difference = restockNum - numInBags

          if difference < 0 then
            UseContainerItem(bag, slot)
            itemsInBags[item.itemName] = itemsInBags[item.itemName] and itemsInBags[item.itemName] - itemCount
            rightClickedItem           = true
            transferredToBank          = true
            RS.didBankStuff            = true
            --coroutine.yield()
          end
        end
      end -- if item we should get and its not locked
    end -- for slot
  end -- for bag


  --
  --  BANK
  --
  -- full stacks
  if not transferredToBank then
    for _, bag in ipairs(BANK_BAGS_REVERSED) do
      for slot = GetContainerNumSlots(bag), 1, -1 do
        local _, itemCount, locked, _, _, _, itemLink, _, _, itemID = GetContainerItemInfo(bag, slot)
        local itemName                                              = itemLink and string.match(itemLink, "%[(.*)%]")
        if itemID and not locked then
          local inRestockList = IsItemInRestockList(itemName)

          if not locked and inRestockList then
            local item       = currentProfile[GetRestockItemIndex(itemName)]
            local numInBags  = itemsInBags[item.itemName] or 0
            local restockNum = item.amount
            local difference = restockNum - numInBags

            if difference > 0 and itemCount <= difference then
              UseContainerItem(bag, slot)
              itemsInBags[item.itemName] = itemsInBags[item.itemName] and itemsInBags[item.itemName] + itemCount or itemCount
              rightClickedItem           = true
              RS.didBankStuff            = true
              --coroutine.yield()
            end
          end
        end -- if item we should get and its not locked
      end -- for slot
    end -- for bag
  end


  -- split stacks
  if not rightClickedItem then
    for _, bag in ipairs(BANK_BAGS_REVERSED) do
      for slot = GetContainerNumSlots(bag), 1, -1 do
        local _, itemCount, locked, _, _, _, itemLink, _, _, itemID = GetContainerItemInfo(bag, slot)
        local itemName                                              = itemLink and string.match(itemLink, "%[(.*)%]")

        if itemID and not locked then
          local inRestockList = IsItemInRestockList(itemName)
          local itemStackSize = select(8, GetItemInfo(itemName))

          if inRestockList then
            local item       = currentProfile[GetRestockItemIndex(itemName)]
            local numInBags  = itemsInBags[item.itemName] or 0
            local restockNum = item.amount
            local difference = restockNum - numInBags

            if difference > 0 and itemCount > difference then
              if mod(difference + numInBags, itemStackSize) == 0 then
                -- if the amount we need creates a full stack in the inventory we simply have to
                -- pick up the item and place it on the incomplete stack in our inventory
                -- if we split stacks here we get an error saying "couldn't split those items."
                PickupContainerItem(bag, slot)
              else
                -- if the amount of items we need doesn't create a full stack then we split
                -- the stack in the bank and merge it with the one in our inventory.
                SplitContainerItem(bag, slot, difference)
              end

              PutSplitItemIntoBags(item, difference)

              RS.didBankStuff            = true
              itemsInBags[item.itemName] = itemsInBags[item.itemName] and itemsInBags[item.itemName] + difference or difference
              hasSplitItems              = true
              --coroutine.yield()
            end
          end
        end -- if item we should get and its not locked
      end -- for slot
    end -- for bag
  end -- not right clicked an item



  if rightClickedItem == false
      and transferredToBank == false
      and hasSplitItems == false
      and RS.didBankStuff
      and RS.minorChange == false then
    RS.currentlyRestocking = false
    RS:Print("Finished restocking from bank.")
  end
end

restockerCoroutine      = coroutine.create(bankTransfer)


--
-- OnUpdate frame
--

RS.onUpdateFrame        = CreateFrame("Frame")
local ONUPDATE_INTERVAL = 0.1
local timer             = 0

RS.onUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
  timer = timer + elapsed
  if timer >= ONUPDATE_INTERVAL then
    timer = 0
    if RS.currentlyRestocking then
      if somethingLocked() and not CursorHasItem() then
        return
      end
      if coroutine.status(restockerCoroutine) == "running" then
        return
      end

      local resume = coroutine.resume(restockerCoroutine)
      if resume == false then
        restockerCoroutine = coroutine.create(bankTransfer)
      end
    end
  end
end)