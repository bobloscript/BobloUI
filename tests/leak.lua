-- Run in an executor/Studio after replacing the URL with a hosted dist/BobloUI.lua.
local CollectionService = game:GetService("CollectionService")
local BobloUI = loadstring(game:HttpGet("https://YOUR_CDN/BobloUI.lua"))()
local ID = "bobloui-leak-test"

local function count()
	local n = 0
	for _, gui in CollectionService:GetTagged("BobloUI") do
		if gui:GetAttribute("BobloWindowId") == ID and gui.Parent then
			n += 1
		end
	end
	return n
end

local UI = BobloUI:CreateWindow({ Id = ID, Title = "Leak Test" })
local Tab = UI:AddTab({ Id = "main", Title = "Main" })
for i = 1, 200 do
	Tab:AddToggle({ Id = "T" .. i, Title = "Toggle " .. i, Default = i % 2 == 0 })
end
assert(count() == 3, "expected Root/Overlay/Toast ScreenGui layers")
UI:Unload()
task.wait()
assert(count() == 0, "ScreenGui leak after Unload")
assert(BobloUI:GetWindow(ID) == nil, "window registry leak after Unload")
print("BobloUI leak smoke: PASS")
