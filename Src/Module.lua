---@shape RsModuleModule
---@field mainFrameModule RsMainFrameModule
---@field bagModule RsBagModule
---@field bankModule RsBankModule
---@field buyIngredientsModule RsBuyIngredientsModule
---@field eventsModule RsEventsModule
---@field itemModule RsItemModule
---@field merchantModule RsMerchantModule
---@field restockerModule RsRestockerModule
---@field buyItemModule RsBuyItemModule
---@field recipeModule RsRecipeModule
local rsModule = {
  mainFrameModule = {},
  bagModule = {},
  bankModule = {},
  buyIngredientsModule = {},
  eventsModule = {},
  itemModule = {},
  merchantModule = {},
  restockerModule = {},
  buyItemModule = {},
  recipeModule = {},
}
RsModule = rsModule

---For each known module call function by fnName and optional context will be
---passed as 1st argument, can be ignored (defaults to nil)
---module:EarlyModuleInit (called early on startup)
---module:LateModuleInit (called late on startup, after entered world)
function RsModule:CallInEachModule(fnName, context)
  for _name, module in pairs(--[[---@type table]] rsModule) do
    -- Only interested in table fields, skip functions
    if module and type(module) == "table" and module[fnName] then
      module[fnName](context)
    end
  end
end
