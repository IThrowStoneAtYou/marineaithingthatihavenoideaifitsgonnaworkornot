--16157972 <- Trash removed.

local hair = {32278814,13477818,80922374,376548738,16630147,15913837,5064651922,83013207,12270248,26658141,
	188003563,13655562,4735347390,4735346175}
local facial = {5355727732,5355564336,4510537113,5164598367,4528880486,4545294588,11884330,20642008,74970669,
	4507911797,5231192146,158066137,5030224026,5031008665,4102114619,4995497755,987022351,5414672551,4875925250,
	4238241252,4904398878,5231324178,4940496302,5167393248,4933549649,4786863817,5063784744,4708784614,74221074,
	5166827175,4524490255,4875895114,5197016342}

local marine = script.Parent.Parent.Parent

function applyAsset(id)
	local item = game:GetService("InsertService"):LoadAsset(id)
	local items = item:GetChildren()
	local accessory = items[1]
	local handle = accessory.Handle
	
	accessory.Parent = marine
	item:Destroy()
	
	task.wait()
	
	handle.Parent = marine
	handle.Name = id
	
	accessory:Destroy()
	
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = marine.Head
	weld.Part1 = handle
	weld.Parent = handle
end

if script.Parent.Parent.Parent.Settings.RandomAppearance.Value then

	applyAsset(facial[math.random(#facial)])

	if math.random(4) == 1 then
		marine.ACH:Destroy()
		applyAsset(hair[math.random(#hair)])
	end

	local skinOptions = {"Wheat","Cashmere","Beige","Khaki","Buttermilk","Pastel yellow"}
	local randomSkin = BrickColor.new(skinOptions[math.random(#skinOptions)])
	local bc = marine["Body Colors"]
	bc.HeadColor = randomSkin
	bc.LeftArmColor = randomSkin
	bc.RightArmColor = randomSkin
	bc.LeftLegColor = randomSkin
	bc.RightLegColor = randomSkin
	bc.TorsoColor = randomSkin
end

