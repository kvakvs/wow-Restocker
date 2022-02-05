local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

-- TODO: Remove this; move fields to RestockerAddon
---@class RestockerConf
---@field profiles table<string, table<string, number>>
---@field currentProfile string
---@field autoBuy boolean
---@field restockFromBank boolean
---@field autoOpenAtBank boolean
---@field autoOpenAtMerchant boolean
---@field loginMessage boolean
---@field framePos table<number>

RS.RestockerConf         = {}
RS.RestockerConf.__index = RS.RestockerConf

-- -@return RsItem
--function RS.RestockerConf.Create(fields)
--  fields = fields or {}
--  setmetatable(fields, RS.RestockerConf)
--  return fields
--end
