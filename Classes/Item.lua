---@type RestockerAddon
local _, RS       = ...;

---@class RsItem
---@field id number

RS.RsItem         = {}
RS.RsItem.__index = RS.RsItem

---@param id number
---@param englishName string
---@return RsItem
function RS.RsItem:Create(id, englishName)
  local fields = { id          = id,
                   englishName = englishName }

  setmetatable(fields, RS.RsItem)

  return fields
end
