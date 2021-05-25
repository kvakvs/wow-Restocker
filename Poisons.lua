---@type RestockerAddon
local _, RS = ...;

--- From 2 choices return TBC if BOM.TBC is true, otherwise return classic
local function tbc_or_classic(tbc, classic)
  if RS.TBC then
    return tbc
  end
  return classic
end

function RS.SetupPoisons()
  RS.poisons    = {}

  local Maiden  = "Maiden's Anguish"
  local DODeter = "Dust of Deterioration"
  local DODecay = "Dust of Decay"
  local EOAgony = "Essence of Agony"
  local EOPain  = "Essence of Pain"
  local DWeed   = "Deathweed"

  -- INSTANT POISONS
  if RS.TBC then
    RS.poisons["Instant Poison VII"] = { [Maiden] = 1, ["Crystal Vial"] = 1 }
  end

  RS.poisons["Instant Poison VI"]   = { [DODeter] = tbc_or_classic(2, 4), ["Crystal Vial"] = 1 }
  RS.poisons["Instant Poison V"]    = { [DODeter] = tbc_or_classic(2, 3), ["Crystal Vial"] = 1 }
  RS.poisons["Instant Poison IV"]   = { [DODeter] = tbc_or_classic(1, 2), ["Crystal Vial"] = 1 }
  RS.poisons["Instant Poison III"]  = { [DODeter] = tbc_or_classic(2, 1), ["Leaded Vial"] = 1 }
  RS.poisons["Instant Poison II"]   = { [DODecay] = tbc_or_classic(1, 3), ["Leaded Vial"] = 1 }
  RS.poisons["Instant Poison"]      = { [DODecay] = 1, ["Empty Vial"] = 1 }

  -- CRIPPLING POISONS
  RS.poisons["Crippling Poison II"] = { [EOAgony] = tbc_or_classic(1, 3), ["Crystal Vial"] = 1 }
  RS.poisons["Crippling Poison"]    = { [EOPain] = 1, ["Empty Vial"] = 1 }

  -- DEADLY POISONS
  if RS.TBC then
    RS.poisons["Deadly Poison VII"] = { [Maiden] = 1, ["Crystal Vial"] = 1 }
    RS.poisons["Deadly Poison VI"]  = { [Maiden] = 1, ["Crystal Vial"] = 1 }
  end
  RS.poisons["Deadly Poison V"]         = { [DWeed] = tbc_or_classic(2, 7), ["Crystal Vial"] = 1 }
  RS.poisons["Deadly Poison IV"]        = { [DWeed] = tbc_or_classic(2, 5), ["Crystal Vial"] = 1 }
  RS.poisons["Deadly Poison III"]       = { [DWeed] = tbc_or_classic(1, 3), ["Crystal Vial"] = 1 }
  RS.poisons["Deadly Poison II"]        = { [DWeed] = 2, ["Leaded Vial"] = 1 }
  RS.poisons["Deadly Poison"]           = { [DWeed] = 1, ["Leaded Vial"] = 1 }

  -- MIND-NUMBING POISONS
  RS.poisons["Mind-numbing Poison III"] = tbc_or_classic(
      { [EOAgony] = 1, ["Crystal Vial"] = 1 },
      { [DODeter] = 2, [EOAgony] = 2, ["Crystal Vial"] = 1 })
  RS.poisons["Mind-numbing Poison II"]  = tbc_or_classic(
      { [EOAgony] = 1, ["Leaded Vial"] = 1 },
      { [DODecay] = 4, [EOPain] = 4, ["Leaded Vial"] = 1 }
  )
  RS.poisons["Mind-numbing Poison"]     = tbc_or_classic(
      { [DODecay] = 1, ["Empty Vial"] = 1 },
      { [DODecay] = 1, [EOPain] = 1, ["Empty Vial"] = 1 }
  )

  -- WOUND POISONS
  if RS.TBC then
    RS.poisons["Wound Poison V"] = { [EOAgony] = 2, ["Crystal Vial"] = 1 }
  end
  RS.poisons["Wound Poison IV"]  = {
    [EOAgony]        = tbc_or_classic(1, 2),
    [DWeed]          = tbc_or_classic(1, 2),
    ["Crystal Vial"] = 1
  }
  RS.poisons["Wound Poison III"] = tbc_or_classic(
      { [EOAgony] = 1, ["Crystal Vial"] = 1 },
      { [EOAgony] = 1, [DWeed] = 2, ["Crystal Vial"] = 1 }
  )
  RS.poisons["Wound Poison II"]  = { [EOPain] = 1, [DWeed] = tbc_or_classic(1, 2), ["Leaded Vial"] = 1 }
  RS.poisons["Wound Poison"]     = tbc_or_classic(
      { [EOPain] = 1, ["Leaded Vial"] = 1 },
      { [EOPain] = 1, [DWeed] = 1, ["Leaded Vial"] = 1 })

  -- ANESTHETIC POISON
  if RS.TBC then
    RS.poisons["Anesthetic Poison"] = { ["Maiden's Anguish"] = 1, [DWeed] = 1, ["Crystal Vial"] = 1 }
  end
end

function RS:getPoisonReagents()
  if select(2, UnitClass("PLAYER")) ~= "ROGUE" then
    return {}
  end

  local T = {}
  for _, item in ipairs(Restocker.profiles[Restocker.currentProfile]) do
    if string.find(item.itemName, "Poison") then
      local poisonName          = item.itemName
      local poisonRestockAmount = item.amount
      local inPossesion         = GetItemCount(item.itemID, true)
      local inBags              = GetItemCount(item.itemID, false)
      local poisonsMissing      = poisonRestockAmount - inPossesion
      local minDifference

      local inBank              = inPossesion - inBags
      if inBank == 0 then
        minDifference = 1
      else
        minDifference = poisonRestockAmount / 2
      end

      if poisonsMissing >= minDifference and poisonsMissing > 0 then
        for reagent, amount in pairs(RS.poisons[poisonName]) do
          local amountToGet = amount * poisonsMissing
          T[reagent]        = T[reagent] and T[reagent] + amountToGet or amountToGet
        end
      end
    end
  end

  for reagent, val in pairs(T) do
    local inBags = GetItemCount(reagent, false)
    if inBags > 0 then
      T[reagent] = T[reagent] - inBags
    end
  end

  return T
end
