-- Read-only baseline loader: route just the two optimized product modules to 73b4254.
local base=".lycheedev/performance-optimization-20261027/"
local paths={
 ["addon/LycheeGroup/Configuration.lua"]=base.."before-Configuration.lua",
 ["addon/LycheeGroup/Appearance.lua"]=base.."before-Appearance.lua",
}
local load,dofileOriginal=loadfile,dofile
loadfile=function(path,...) return load(paths[path] or path,...) end
dofile=function(path) return dofileOriginal(paths[path] or path) end
local target=table.remove(arg,1)
return dofile(target)
