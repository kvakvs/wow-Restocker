--
--This Module contains auto-buy table for ingredients for craftable items (example rogue poisons)
--
---@type RestockerAddon
local _, RS = ...;

--- From 2 choices return TBC if BOM.TBC is true, otherwise return classic
local function tbc_or_classic(tbc, classic)
  if RS.TBC then
    return tbc
  end
  return classic
end

---@param recipe RsRecipe
local function rs_add_craftable_recipe(recipe)
  -- Two situations can happen:
  -- 1. GetItemInfo will work and return all values required
  -- 2. Some values will not work - then we place the task into RS.buyIngredientsWait and do later
  local function postpone()
    RS.buyIngredientsWait[recipe.item.id] = recipe
  end

  local itemVal = RS.GetItemInfo(recipe.item.id) --- @type GIICacheItem
  if not itemVal then
    postpone()
    return
  end

  local reagent1    = recipe.reagent1[1]
  local reagent1Val = RS.GetItemInfo(reagent1.id) --- @type GIICacheItem
  if not reagent1Val then
    postpone()
    return
  end

  local reagent2Val --- @type GIICacheItem
  local reagent3Val --- @type GIICacheItem

  if recipe.reagent2 then
    local reagent2 = recipe.reagent2[1]
    reagent2Val    = RS.GetItemInfo(reagent2.id)
    if not reagent2Val then
      postpone()
      return
    end
  end

  if recipe.reagent3 then
    local reagent3 = recipe.reagent3[1]
    reagent3Val    = RS.GetItemInfo(reagent3.id)
    if not reagent3Val then
      postpone()
      return
    end
  end

  RS.Dbg("Added craft recipe for item " .. recipe.item.id)
  RS.buyIngredients[itemVal.itemName]   = recipe -- added with localized name key
  RS.buyIngredientsWait[recipe.item.id] = nil -- delete the waiting one
end

---@param item RsItem
---@param reagent1 table<RsItem|number> Pair of {Item, Count} First reagent to craft
---@param reagent2 table<RsItem|number>|nil Nil or pair of {Item, Count} 2nd reagent to craft
---@param reagent3 table<RsItem|number>|nil Nil or pair of {Item, Count} 3rd reagent to craft
local function rs_add_craftable(item, reagent1, reagent2, reagent3)
  local recipe = RS.RsRecipe:Create(item, reagent1, reagent2, reagent3)
  rs_add_craftable_recipe(recipe)
end

function RS.RetryWaitRecipes()
  for _, recipe in pairs(RS.buyIngredientsWait) do
    rs_add_craftable_recipe(recipe)
  end
end

local function rs_add_craftable_TBC(item, reagent1, reagent2, reagent3)
  if RS.TBC then
    rs_add_craftable(item, reagent1, reagent2, reagent3)
  end
end

local function rs_add_craftable_CLASSIC(item, reagent1, reagent2, reagent3)
  if not RS.TBC then
    rs_add_craftable(item, reagent1, reagent2, reagent3)
  end
end

function RS.SetupAutobuyIngredients()
  RS.buyIngredients     = {}
  RS.buyIngredientsWait = {}

  local maidensAnguish  = { RS.RsItem:Create(2931, "Maiden's Anguish"), 1 } -- always 1 in crafts
  local dustOfDeter     = RS.RsItem:Create(8924, "Dust of Deterioration")
  local dustOfDecay     = RS.RsItem:Create(2928, "Dust of Decay")
  local essOfAgony      = RS.RsItem:Create(8923, "Essence of Agony")
  local essOfPain       = RS.RsItem:Create(2930, "Essence of Pain")
  local deathweed       = RS.RsItem:Create(5173, "Deathweed")

  local crystalVial     = { RS.RsItem:Create(8925, "Crystal Vial"), 1 }
  local leadedVial      = { RS.RsItem:Create(3372, "Leaded Vial"), 1 }
  local emptyVial       = { RS.RsItem:Create(3371, "Empty Vial"), 1 }

  --
  -- INSTANT POISONS
  --
  rs_add_craftable_TBC(RS.RsItem:Create(21927, "Instant Poison VII"), maidensAnguish, crystalVial)

  rs_add_craftable(RS.RsItem:Create(8928, "Instant Poison VI"), { dustOfDeter, tbc_or_classic(2, 4) }, crystalVial)
  rs_add_craftable(RS.RsItem:Create(8927, "Instant Poison V"), { dustOfDeter, tbc_or_classic(2, 3) }, crystalVial)
  rs_add_craftable(RS.RsItem:Create(8926, "Instant Poison IV"), { dustOfDeter, tbc_or_classic(1, 2) }, crystalVial)
  rs_add_craftable(RS.RsItem:Create(6950, "Instant Poison III"), { dustOfDeter, tbc_or_classic(2, 1) }, leadedVial)
  rs_add_craftable(RS.RsItem:Create(6949, "Instant Poison II"), { dustOfDecay, tbc_or_classic(1, 3) }, leadedVial)
  rs_add_craftable(RS.RsItem:Create(6947, "Instant Poison"), { dustOfDecay, 1 }, emptyVial)

  --
  -- CRIPPLING POISONS
  --
  rs_add_craftable(RS.RsItem:Create(3776, "Crippling Poison II"), { essOfAgony, tbc_or_classic(1, 3) }, crystalVial)
  rs_add_craftable(RS.RsItem:Create(3775, "Crippling Poison"), { essOfPain, 1 }, emptyVial)

  --
  -- DEADLY POISONS
  --
  rs_add_craftable_TBC(RS.RsItem:Create(22054, "Deadly Poison VII"), maidensAnguish, crystalVial)
  rs_add_craftable_TBC(RS.RsItem:Create(22053, "Deadly Poison VI"), maidensAnguish, crystalVial)

  rs_add_craftable(RS.RsItem:Create(20844, "Deadly Poison V"), { deathweed, tbc_or_classic(2, 7) }, crystalVial)
  rs_add_craftable(RS.RsItem:Create(8985, "Deadly Poison IV"), { deathweed, tbc_or_classic(2, 5) }, crystalVial)
  rs_add_craftable(RS.RsItem:Create(8984, "Deadly Poison III"), { deathweed, tbc_or_classic(1, 3) }, crystalVial)
  rs_add_craftable(RS.RsItem:Create(2893, "Deadly Poison II"), { deathweed, 2 }, leadedVial)
  rs_add_craftable(RS.RsItem:Create(2892, "Deadly Poison"), { deathweed, 1 }, leadedVial)

  -- MIND-NUMBING POISONS
  local mindNumbing3 = RS.RsItem:Create(9186, "Mind-numbing Poison III")
  rs_add_craftable_TBC(mindNumbing3, { essOfAgony, 1 }, crystalVial)
  rs_add_craftable_CLASSIC(mindNumbing3, { dustOfDeter, 2 }, { essOfAgony, 2 }, crystalVial)

  local mindNumbing2 = RS.RsItem:Create(6951, "Mind-numbing Poison II")
  rs_add_craftable_TBC(mindNumbing2, { essOfAgony, 1 }, leadedVial)
  rs_add_craftable_CLASSIC(mindNumbing2, { dustOfDecay, 4 }, { essOfPain, 4 }, leadedVial)

  local mindNumbing1 = RS.RsItem:Create(5237, "Mind-numbing Poison")
  rs_add_craftable_TBC(mindNumbing1, { dustOfDecay, 1 }, emptyVial)
  rs_add_craftable_CLASSIC(mindNumbing1, { dustOfDecay, 1 }, { essOfPain, 1 }, emptyVial)

  -- WOUND POISONS
  rs_add_craftable_TBC(RS.RsItem:Create(22055, "Wound Poison V"), { essOfAgony, 2 }, crystalVial)

  rs_add_craftable(RS.RsItem:Create(10922, "Wound Poison IV"),
      { essOfAgony, tbc_or_classic(1, 2) }, { deathweed, tbc_or_classic(1, 2) }, crystalVial)

  local wound3 = RS.RsItem:Create(10921, "Wound Poison III")
  rs_add_craftable_TBC(wound3, { essOfAgony, 1 }, crystalVial)
  rs_add_craftable_CLASSIC(wound3, { essOfAgony, 1 }, { deathweed, 2 }, crystalVial)

  rs_add_craftable(RS.RsItem:Create(10920, "Wound Poison II"),
      { essOfPain, 1 }, { deathweed, tbc_or_classic(1, 2) }, leadedVial)

  rs_add_craftable_TBC(RS.RsItem:Create(10918, "Wound Poison"), { essOfPain, 1 }, leadedVial)
  rs_add_craftable_CLASSIC(RS.RsItem:Create(10918, "Wound Poison"), { essOfPain, 1 }, { deathweed, 1 }, leadedVial)

  -- ANESTHETIC POISON
  rs_add_craftable_TBC(RS.RsItem:Create(21835, "Anesthetic Poison"), maidensAnguish, { deathweed, 1 }, crystalVial)
end

--- Check if any of the items user wants to restock are on our crafting autobuy list
function RS.CraftingPurchaseOrder()
  local purchaseOrder = {}

  -- Check auto-buy reagents table
  for _, item in ipairs(Restocker.profiles[Restocker.currentProfile]) do
    if RS.buyIngredients[item.itemName] ~= nil then
      local craftedName          = item.itemName
      local craftedRestockAmount = item.amount
      local haveCrafted          = GetItemCount(item.itemID, true)
      local inBags               = GetItemCount(item.itemID, false)
      local craftedMissing       = craftedRestockAmount - haveCrafted
      local minDifference

      local inBank               = haveCrafted - inBags

      if inBank == 0 then
        minDifference = 1
      else
        minDifference = craftedRestockAmount / 2
      end

      if craftedMissing >= minDifference and craftedMissing > 0 then
        for ingredient, amount in pairs(RS.buyIngredients[craftedName]) do
          local amountToGet         = amount * craftedMissing
          purchaseOrder[ingredient] = purchaseOrder[ingredient] and purchaseOrder[ingredient] + amountToGet or amountToGet
        end
      end
    end
  end

  for reagent, val in pairs(purchaseOrder) do
    local inBags = GetItemCount(reagent, false)
    if inBags > 0 then
      purchaseOrder[reagent] = purchaseOrder[reagent] - inBags
    end
  end

  return purchaseOrder
end
