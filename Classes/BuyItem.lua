---@type RestockerAddon
local _, RS       = ...;

---@class RsBuyItem
---@field numNeeded number
---@field itemName string
---@field itemLink string
---@field itemID number

RS.RsBuyItem         = {}
RS.RsBuyItem.__index = RS.RsBuyItem

---@param id number
---@param englishName string
---@return RsItem
function RS.RsBuyItem:Create(fields)
  fields = fields or {}
  setmetatable(fields, RS.RsBuyItem)
  return fields
end
