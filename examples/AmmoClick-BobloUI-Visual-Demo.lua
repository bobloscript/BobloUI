--[[
	AmmoClick / BobloUI visual demo

	This is intentionally a UI-only mockup. It does not read game state,
	call remotes, move the player, buy items, or run any gameplay automation.
	Buttons and watchers below only update BobloUI controls and notifications.
]]

local SOURCE = "https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.lua"
local cacheBust = tostring(os.time()) .. "-" .. tostring(math.floor(os.clock() * 100000))
local BobloUI = loadstring(game:HttpGet(SOURCE .. "?cb=" .. cacheBust))()

-- Downloads the two GitHub-hosted PNG atlases when the executor supports
-- filesystem + getcustomasset/getsynasset. Otherwise BobloUI uses its
-- asset-free fallback icons automatically.
BobloUI.Icon.Prepare()

local UI = BobloUI:CreateWindow({
	Id = "ammoclick-visual-demo",
	Title = "AmmoClick",
	Subtitle = "automation preview · no gameplay logic",
	Icon = "crosshair",
	Theme = "Dark",
	Accent = Color3.fromHex("7657F6"),
	Density = "Comfortable",
	Scale = 1,
	Size = UDim2.fromOffset(920, 650),
	MinSize = Vector2.new(620, 460),
	Locale = "en",
	ConfigFolder = "AmmoClickVisualDemo",
	AutoLoad = false,
	Settings = true,
	RememberGeometry = true,
	KeyboardNavigation = true,
	SoundEnabled = false,
	CornerRadius = 14,
	FooterText = "AmmoClick · visual preview · no gameplay logic",
	Opacity = 0.98,
	ShowText = "Show AmmoClick",
	ToggleUIKeybind = Enum.KeyCode.RightShift,
	NotificationPosition = "TopRight",
})

local iconStatus = BobloUI.Icon.GetStatus()
UI:AddTopbarTag({
	Id = "icon-provider",
	Text = if iconStatus.Ready then "LUCIDE" else "FALLBACK",
	Token = if iconStatus.Ready then "AccentSoft" else "SurfaceSecondary",
})
local activeTag = UI:AddTopbarTag({
	Id = "active-count",
	Text = "0 ACTIVE",
	Token = "SurfaceSecondary",
})
UI:AddTopbarButton({
	Id = "open-settings",
	Icon = "settings-2",
	Callback = function()
		UI:OpenSettings()
	end,
})

local Farming = UI:AddTab({
	Id = "farming",
	Title = "Farming",
	Description = "Ammo, walls, rewards and progression",
	Icon = "pickaxe",
	Group = "AMMOCLICK",
	Badge = "14",
})

local Engine = Farming:AddSection({
	Id = "engine",
	Title = "Engine",
	Description = "Main automation switches",
	Icon = "cpu",
	Span = 1,
	Column = 1,
	Layout = "Stack",
	Collapsible = true,
})

Engine:AddToggle({
	Id = "AutoAmmo",
	Title = "Auto Ammo",
	Description = "Adds valid ammo clicks at the selected rate and target.",
	Icon = "crosshair",
	Default = true,
	Badge = "CORE",
})

Engine:AddDropdown({
	Id = "AmmoTarget",
	Title = "Ammo Target",
	Description = "Decides where simulated ammo clicks would be sent.",
	Icon = "target",
	Options = {
		{
			Value = "BestUnlocked",
			Title = "Best unlocked",
			Description = "Highest available reward target",
			Icon = "trophy",
		},
		{
			Value = "CurrentStage",
			Title = "Current stage",
			Description = "Stay on the selected stage",
			Icon = "map-pin",
		},
		{
			Value = "NearestWall",
			Title = "Nearest wall",
			Description = "Prefer the closest valid wall",
			Icon = "brick-wall",
		},
	},
	Default = "BestUnlocked",
	VisibleWhen = { AutoAmmo = true },
})

Engine:AddToggle({
	Id = "AutoWalls",
	Title = "Auto Walls",
	Description = "Keeps the route focused on the active wall until it breaks.",
	Icon = "brick-wall",
	Default = true,
})

Engine:AddDropdown({
	Id = "WallPosition",
	Title = "Wall Position",
	Description = "Preferred position while wall automation is active.",
	Icon = "scan-line",
	Options = { "Safe", "Center", "Front" },
	Default = "Safe",
	Style = "Segmented",
	VisibleWhen = { AutoWalls = true },
})

Engine:AddToggle({
	Id = "AutoClaim",
	Title = "Auto Claim",
	Description = "Claims the deepest completed stage when its cooldown is ready.",
	Icon = "package-check",
	Default = true,
})

Engine:AddToggle({
	Id = "AutoRebirth",
	Title = "Auto Rebirth",
	Description = "Waits for the level bar to fill before starting a rebirth.",
	Icon = "rotate-cw",
	Default = false,
	Badge = "SAFE",
})

local Tuning = Farming:AddSection({
	Id = "tuning",
	Title = "Tuning",
	Description = "Safety limits and timing",
	Icon = "sliders-horizontal",
	Span = 1,
	Column = 1,
	Layout = "Stack",
	Collapsible = true,
})

Tuning:AddSlider({
	Id = "DepthSafety",
	Title = "Depth Safety Changer",
	Description = "Pauses wall routing below this percentage of the best depth.",
	Icon = "shield-check",
	Min = 0,
	Max = 100,
	Step = 5,
	Default = 50,
	Suffix = "%",
	ValueInput = true,
	FloatingValue = true,
	IconFrom = "shield-alert",
	IconTo = "shield-check",
})

Tuning:AddSlider({
	Id = "HitGap",
	Title = "Hit Gap Changer",
	Description = "Delay between planned ammo actions; lower values are more aggressive.",
	Icon = "timer",
	Min = 50,
	Max = 1000,
	Step = 25,
	Default = 300,
	Suffix = " ms",
	ValueInput = true,
	FloatingValue = true,
	IconFrom = "rabbit",
	IconTo = "turtle",
})

Tuning:AddDropdown({
	Id = "RebirthPolicy",
	Title = "Rebirth Policy",
	Description = "Additional condition checked before the automatic rebirth.",
	Icon = "refresh-cw",
	Options = {
		{ Value = "LevelFull", Title = "Level bar full", Icon = "circle-gauge" },
		{ Value = "TargetWins", Title = "Target wins reached", Icon = "trophy" },
		{ Value = "Both", Title = "Require both", Icon = "badge-check" },
	},
	Default = "LevelFull",
	VisibleWhen = { AutoRebirth = true },
})

Tuning:AddDropdown({
	Id = "AutomationProfile",
	Title = "Automation Profile",
	Description = "A visual preset for the two tuning values.",
	Icon = "gauge",
	Options = { "Safe", "Balanced", "Fast" },
	Default = "Balanced",
	Style = "Segmented",
	Callback = function(profile)
		local presets = {
			Safe = { Depth = 70, Gap = 500 },
			Balanced = { Depth = 50, Gap = 300 },
			Fast = { Depth = 25, Gap = 125 },
		}
		local selected = presets[profile]
		if selected then
			UI.State:Batch(function()
				UI.State:Set("DepthSafety", selected.Depth)
				UI.State:Set("HitGap", selected.Gap)
			end)
		end
	end,
})

local Spending = Farming:AddSection({
	Id = "spending",
	Title = "Spending",
	Description = "Purchase priorities and budgets",
	Icon = "shopping-basket",
	Span = 1,
	Column = 2,
	Layout = "Stack",
	Collapsible = true,
})

Spending:AddToggle({
	Id = "AutoBuyGuns",
	Title = "Auto Buy Guns",
	Description = "Selects the best affordable gun after free unlocks are checked.",
	Icon = "crosshair",
	Default = true,
})

Spending:AddDropdown({
	Id = "GunPurchaseMode",
	Title = "Gun Purchase Mode",
	Description = "How the next weapon would be selected.",
	Icon = "shopping-cart",
	Options = {
		{ Value = "BestAffordable", Title = "Best affordable", Icon = "badge-dollar-sign" },
		{ Value = "NextUnlock", Title = "Next unlock", Icon = "lock-keyhole-open" },
		{ Value = "Cheapest", Title = "Cheapest upgrade", Icon = "coins" },
	},
	Default = "BestAffordable",
	VisibleWhen = { AutoBuyGuns = true },
})

Spending:AddToggle({
	Id = "AutoBuyBoosts",
	Title = "Auto Buy Boosts",
	Description = "Buys damage boosts without crossing the configured balance budget.",
	Icon = "zap",
	Default = false,
})

Spending:AddSlider({
	Id = "BoostBudget",
	Title = "Boost Budget",
	Description = "Maximum share of the current balance reserved for boosts.",
	Icon = "badge-percent",
	Min = 5,
	Max = 75,
	Step = 5,
	Default = 20,
	Suffix = "%",
	ValueInput = true,
	VisibleWhen = { AutoBuyBoosts = true },
})

Spending:AddToggle({
	Id = "AutoBuyEggs",
	Title = "Auto Buy Eggs",
	Description = "Uses coin-priced eggs only; premium offers remain excluded.",
	Icon = "egg",
	Default = false,
})

Spending:AddDropdown({
	Id = "EggPurchaseMode",
	Title = "Egg Purchase Mode",
	Description = "Controls which coin egg would be selected.",
	Icon = "package-open",
	Options = {
		{ Value = "BestAffordable", Title = "Best affordable", Icon = "gem" },
		{ Value = "CurrentWorld", Title = "Current world", Icon = "globe" },
		{ Value = "Selected", Title = "Selected egg", Icon = "mouse-pointer-click" },
	},
	Default = "BestAffordable",
	VisibleWhen = { AutoBuyEggs = true },
})

local Rewards = Farming:AddSection({
	Id = "rewards",
	Title = "Rewards",
	Description = "Claim schedule and preview actions",
	Icon = "gift",
	Span = 1,
	Column = 2,
	Layout = "Stack",
	Collapsible = true,
})

Rewards:AddToggle({
	Id = "AutoClaimFreeRewards",
	Title = "Auto Claim Free Rewards",
	Description = "Checks daily rewards, playtime gifts and banked free spins.",
	Icon = "gift",
	Default = true,
})

Rewards:AddDropdown({
	Id = "RewardSchedule",
	Title = "Reward Schedule",
	Description = "When available reward checks would run.",
	Icon = "clock-3",
	Options = { "As soon as ready", "Every 30 seconds", "After each stage" },
	Default = "As soon as ready",
	VisibleWhen = { AutoClaimFreeRewards = true },
})

local RewardStatus = Rewards:AddStatus({
	Id = "RewardPreviewStatus",
	Title = "Reward Scanner",
	Description = "Local UI state only",
	Icon = "radar",
	Value = "Ready",
	Status = "Success",
	Pulse = true,
	IgnoreConfig = true,
})

Rewards:AddButton({
	Id = "ClaimRewardsNow",
	Title = "Claim Rewards Now",
	Description = "Runs a notification preview without calling the game.",
	Icon = "hand-coins",
	Text = "Run preview",
	Variant = "Primary",
	EnabledWhen = function(State)
		return State:Get("AutoClaim") or State:Get("AutoClaimFreeRewards")
	end,
	Callback = function()
		RewardStatus:SetValue("Preview complete"):SetStatus("Success")
		UI.Notify:Push({
			Title = "Rewards preview",
			Content = "The button works. No game reward was claimed.",
			Variant = "Success",
			Icon = "gift",
			Duration = 3,
		})
	end,
})

local Collection = Farming:AddSection({
	Id = "collection",
	Title = "Titles & Pets",
	Description = "Collection rules and protection filters",
	Icon = "paw-print",
	Span = 1,
	Column = 2,
	Layout = "Stack",
	Collapsible = true,
})

Collection:AddToggle({
	Id = "AutoTitleRolls",
	Title = "Auto Title Rolls",
	Description = "Rolls free titles and evaluates their multiplier before equipping.",
	Icon = "dices",
	Default = false,
})

Collection:AddDropdown({
	Id = "TitlePolicy",
	Title = "Title Policy",
	Description = "Determines which rolled title would replace the current one.",
	Icon = "medal",
	Options = {
		{ Value = "AnyUpgrade", Title = "Any multiplier upgrade", Icon = "chart-no-axes-column-increasing" },
		{ Value = "RareOnly", Title = "Rare or better", Icon = "sparkles" },
		{ Value = "KeepCurrent", Title = "Roll without equipping", Icon = "shield" },
	},
	Default = "AnyUpgrade",
	VisibleWhen = { AutoTitleRolls = true },
})

Collection:AddToggle({
	Id = "AutoEquipPets",
	Title = "Auto Equip Pets",
	Description = "Builds the strongest available three-pet team by multiplier.",
	Icon = "paw-print",
	Default = true,
})

Collection:AddDropdown({
	Id = "PetEquipPriority",
	Title = "Pet Equip Priority",
	Description = "Stat used to sort the preview pet team.",
	Icon = "crown",
	Options = { "Power", "Luck", "Balanced" },
	Default = "Power",
	Style = "Segmented",
	VisibleWhen = { AutoEquipPets = true },
})

Collection:AddToggle({
	Id = "AutoDeleteWeakPets",
	Title = "Auto Delete Weak Pets",
	Description = "Marks pets below the keep threshold; equipped and protected pets stay safe.",
	Icon = "trash-2",
	Default = false,
	Badge = "CAREFUL",
})

Collection:AddSlider({
	Id = "PetKeepThreshold",
	Title = "Keep Threshold",
	Description = "Pets below this percentage of the strongest pet would be removed.",
	Icon = "chart-no-axes-column-increasing",
	Min = 1,
	Max = 100,
	Step = 1,
	Default = 35,
	Suffix = "%",
	ValueInput = true,
	VisibleWhen = { AutoDeleteWeakPets = true },
})

Collection:AddDropdown({
	Id = "ProtectedPetRarities",
	Title = "Protected Rarities",
	Description = "Selected rarities remain protected regardless of strength.",
	Icon = "shield-check",
	Options = { "Legendary", "Mythic", "Secret", "Event" },
	Default = { "Mythic", "Secret", "Event" },
	Multi = true,
	AllowNone = true,
	VisibleWhen = { AutoDeleteWeakPets = true },
})

local Monitor = Farming:AddSection({
	Id = "monitor",
	Title = "Preview Monitor",
	Description = "Shows only the current BobloUI state",
	Icon = "chart-no-axes-column-increasing",
	Span = 2,
	Layout = "Auto",
	Collapsible = true,
})

local AutomationStatus = Monitor:AddStatus({
	Id = "AutomationPreviewStatus",
	Title = "Automation State",
	Icon = "activity",
	Value = "0 enabled",
	Status = "Neutral",
	IgnoreConfig = true,
})

local featureIds = {
	"AutoAmmo",
	"AutoWalls",
	"AutoClaim",
	"AutoRebirth",
	"AutoBuyGuns",
	"AutoBuyBoosts",
	"AutoBuyEggs",
	"AutoClaimFreeRewards",
	"AutoTitleRolls",
	"AutoEquipPets",
	"AutoDeleteWeakPets",
}

local AutomationProgress = Monitor:AddProgress({
	Id = "AutomationPreviewProgress",
	Title = "Enabled Features",
	Description = "Updates when a feature switch changes.",
	Icon = "circle-gauge",
	Min = 0,
	Max = #featureIds,
	Default = 0,
	ShowValue = true,
	IgnoreConfig = true,
	Format = function(value)
		return string.format("%d / %d", value, #featureIds)
	end,
})

Monitor:AddParagraph({
	Title = "Visual-only build",
	Content = "All switches, dependencies, sliders, presets and notifications are local UI demonstrations. This script contains no gameplay implementation.",
	Icon = "shield-check",
	Variant = "Info",
})

local function refreshMonitor(snapshot)
	local enabled = 0
	for _, id in featureIds do
		if snapshot[id] == true then
			enabled += 1
		end
	end

	AutomationProgress:SetValue(enabled, true)
	AutomationStatus:SetValue(string.format("%d enabled", enabled), true)
	AutomationStatus:SetStatus(if enabled > 0 then "Success" else "Neutral")
	activeTag:SetText(string.format("%d ACTIVE", enabled))
end

local stopWatching = UI.State:WatchMany(featureIds, refreshMonitor)
UI:OnUnload(stopWatching)
refreshMonitor(UI.State:Snapshot())

UI.Notify:Push({
	Title = "AmmoClick preview ready",
	Content = if iconStatus.Ready
		then "GitHub Lucide atlas loaded through the executor cache."
		else "Lucide atlas is unavailable here; asset-free fallback icons are active.",
	Variant = if iconStatus.Ready then "Success" else "Warning",
	Icon = if iconStatus.Ready then "sparkles" else "shield-alert",
	Duration = 4,
})

return UI
