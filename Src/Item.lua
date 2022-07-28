--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
--local RS = RS_ADDON ---@type RestockerAddon

---@class RsItemModule
local itemModule = RsModule.New("Item") ---@type RsItemModule

---@class RsContainerItemInfo
---@field bag number Bag number where the item is found
---@field slot number Slot number in the bag
---@field icon string
---@field count number
---@field itemId number
---@field locked boolean
---@field link string
---@field name string Extracted from item link, localized name

---@return RsContainerItemInfo
function itemModule:GetContainerItemInfo(bag, slot)
  local icon, slotCount, slotLocked, _, _, _, slotItemLink, _, _, slotItemId = GetContainerItemInfo(bag, slot)
  local itemName = slotItemLink and string.match(slotItemLink, "%[(.*)%]")

  return {
    bag    = bag,
    slot   = slot,
    icon   = icon,
    count  = slotCount,
    locked = slotLocked,
    link   = slotItemLink,
    itemId = slotItemId,
    name   = itemName,
  }
end

---Compare whether a is less than b
---For use in table.sort(table, itemModule.CompareByStacksizeAscending) to sort by stack size
function itemModule.CompareByStacksizeAscending(a, b)
  return a.count < b.count
end
