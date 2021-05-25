---@type RestockerAddon
local _, RS                 = ...;

---@class RsRecipe
---@field item RsItem
---@field reagent1 RsItem
---@field reagent2 RsItem
---@field reagent3 RsItem

RS.RsRecipe         = {}
RS.RsRecipe.__index = RS.RsRecipe

---@return RsRecipe
function RS.RsRecipe:Create(item, reagent1, reagent2, reagent3)
  local fields = { item     = item,
                   reagent1 = reagent1,
                   reagent2 = reagent2,
                   reagent3 = reagent3 }

  setmetatable(fields, RS.RsRecipe)

  return fields
end
