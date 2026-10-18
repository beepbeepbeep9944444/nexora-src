local M = function(NX)

NX.gameName = "typical colors 2"
NX.skins = true

NX.tune = {
}

end

local ENV = (getfenv and getfenv()) or _G
ENV.NEXORA_GAME = M
return M
