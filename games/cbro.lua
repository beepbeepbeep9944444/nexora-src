local M = function(NX)

NX.gameName = "counter blox"
NX.skins = false

NX.tune = {
}

end

local ENV = (getfenv and getfenv()) or _G
ENV.NEXORA_GAME = M
return M
