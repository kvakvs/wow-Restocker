--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
--local RS = RS_ADDON ---@type RestockerAddon

---@class RsBuyItemModule
local buyItemModule = RsModule.buyItemModule ---@type RsBuyItemModule

---@shape RsBuyItem
---@field amount number
---@field numNeeded number
---@field itemName string
---@field itemLink string
---@field itemID number
---@field reaction number UnitReaction required to buy from vendor (4 neutral, 5 friendly, ... 8 exalted)

local buyItemClass = {}
buyItemClass.__index = buyItemClass

---@param fields RsBuyItem
---@return RsBuyItem
function buyItemModule:Create(fields)
  fields = fields or {}
  setmetatable(fields, buyItemClass)
  return fields
end
