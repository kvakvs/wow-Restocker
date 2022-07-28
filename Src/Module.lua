---@class RsModuleModule
RsModule = {}

local moduleIndex = {}
RsModule._moduleIndex = moduleIndex

---New empty module with private section
local function rsNewModule()
  return {
    private = {}
  }
end

---@param name string
function RsModule.New(name)
  if (not moduleIndex[name]) then
    moduleIndex[name] = rsNewModule()
    return moduleIndex[name]
  end

  return moduleIndex[name] -- found
end

RsModule.Import = RsModule.New

---For each known module call function by fnName and optional context will be
---passed as 1st argument, can be ignored (defaults to nil)
---module:EarlyModuleInit (called early on startup)
---module:LateModuleInit (called late on startup, after entered world)
function RsModule:CallInEachModule(fnName, context)
  for _name, module in pairs(moduleIndex) do
    local fn = module[fnName]
    if fn then
      fn(context)
    end
  end
end
