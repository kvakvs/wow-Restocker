--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
--local RS = RS_ADDON ---@type RestockerAddon

---@class RsBuyCommandModule
local buyCommandModule = RsModule.buyCommandModule

---@shape RsBuyCommand
---@field amount number
---@field numNeeded number
---@field itemName string
---@field itemLink string
---@field itemID number
---@field reaction number UnitReaction required to buy from vendor (4 neutral, 5 friendly, ... 8 exalted)

local buyItemClass = {}
buyItemClass.__index = buyItemClass

---@param fields RsBuyCommand
---@return RsBuyCommand
function buyCommandModule:Create(fields)
  fields = fields or {}
  setmetatable(fields, buyItemClass)
  return fields
end
