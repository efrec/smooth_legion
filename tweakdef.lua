--SMOOTH LEGION

local UD = UnitDefs
local unitDef, weaponDef, cparams, ref
local divisors, m2e, m2b = { 2, 4, 5, 8, 12, 20, 50, 125, 250 }, 60, 30
local weapons, weapondefs, metalcost, energycost, buildtime, onlytargetcategory, badtargetcategory, areaofeffect, edgeeffectiveness, explosiongenerator, weaponvelocity = "weapons", "weapondefs", "metalcost", "energycost", "buildtime", "onlytargetcategory", "badtargetcategory", "areaofeffect", "edgeeffectiveness", "explosiongenerator", "weaponvelocity"
local units = {}

--------------------------------------------------------------------------------
-- Tests -----------------------------------------------------------------------

if not UD.legcom then
	Spring.Echo('Error: Legion not enabled.')
	return
end

local function nounit(name)
	if not unitDef then
		Spring.Echo("error: missing unitdef", name)
	end
end

local function noweapon(name)
	if not weaponDef then
		Spring.Echo("error: missing weapondef", name)
	end
end

local function norefdef(def, ...)
	if not def or not ref then
		Spring.Echo("error: missing def/ref", ...)
	end
end

local function equal(old, new)
	return
		(type(old) == "string" and tonumber(old) and tonumber(old) ~= new) or
		((old == 0 or old == "false") and new ~= false) or
		((old == 1 or old == "true") and new ~= true)
end

local function diff(old, new)
	local d = {}
	for k, v_o in pairs(old) do
		if type(k) ~= "number" then
			local v_n = new[k]
			if v_n == nil then
				d[k] = "nil"
			elseif type(v_o) == "table" and type(v_n) == "table" then
				d[k] = diff(v_o, v_n)
			elseif v_o ~= v_n and (type(v_o) == type(v_n) or equal(v_o, v_n)) then
				d[k] = v_n
			end
		end
	end
	for k, v_n in pairs(new) do
		if old[k] == nil then
			d[k] = v_n
		end
	end
	if next(d) then
		return d
	end
end

--------------------------------------------------------------------------------
-- Initialize ------------------------------------------------------------------

local function unit(name)
	unitDef = UD[name]
	nounit()
	if unitDef and not units[name] then
		units[name] = table.copy(unitDef)
	end
	return unitDef
end

local function weapon(name)
	nounit(name)
	weaponDef = unitDef[weapondefs][name]
	noweapon(name)
	return weaponDef
end

local function custom(def)
	cparams = def.customparams or {}
	def.customparams = cparams
	return cparams
end

local function copyweapon(name, def)
	local new = table.copy(def or ref)
	unitDef[weapondefs][name] = new
	return new
end

local function copyref(def, ...)
	norefdef(def, ...)
	for _, property in ipairs({ ... }) do
		def[property] = ref[property]
	end
end

local function neat(value, precision)
	precision = precision or 1
	value = value / precision
	if value <= 30 then
		return math.floor(value + 0.5) * precision
	end
	local values = {}
	for _, v in ipairs(divisors) do
		values[v] = math.floor(value / v + 0.5) * v
	end
	local neatest = values[divisors[1]]
	local fitness = neatest - value
	fitness = fitness * fitness / divisors[1]
	for i = 2, #divisors do
		local divisor = divisors[i]
		local fitness2 = (values[divisor] - value) ^ 2 / divisors[1]
		if fitness > fitness2 then
			neatest = values[divisor]
			fitness = fitness2
		end
	end
	return neatest * precision
end

local function set(tbl, key, mult, add, precision)
	local value = tonumber(tbl[key])
	tbl[key] = value and neat(value * (mult or 1) + (add or 0), precision) or nil
end

local function costs(mult, add_m, add_e, add_bp)
	add_m = add_m or 0
	add_e = add_e or add_m * ((unitDef[metalcost] or 0) > 0 and unitDef[energycost] / unitDef[metalcost] or m2e)
	add_bp = add_bp or add_m * ((unitDef[metalcost] or 0) > 0 and unitDef[buildtime] / unitDef[metalcost] or m2b)
	set(unitDef, metalcost, mult, add_m, 10)
	set(unitDef, energycost, mult, add_e, 10)
	set(unitDef, buildtime, mult, add_bp, 10)
end

local function damages(mult, add)
	for armor in pairs(weaponDef.damage) do
		set(weaponDef.damage, armor, mult, add)
	end
	return weaponDef.damage
end

--------------------------------------------------------------------------------
-- Commander -------------------------------------------------------------------

ref = unit("legcom")[weapons]
ref[1][onlytargetcategory] = "NOTSUB"
ref[1].fastautoretargeting = true
ref[4] = nil
ref = UD.armcom[weapondefs]
copyweapon("legcomlaser", ref.armcomlaser)
copyweapon("torpedo", ref.armcomsealaser)

--------------------------------------------------------------------------------
-- Basic economy ---------------------------------------------------------------

if unit("legmex") then
	unitDef.extractsmetal = 0.001
	unitDef.energyupkeep = 3
end

--------------------------------------------------------------------------------
-- Make T1.5 units smoother ----------------------------------------------------

for _, name in pairs { "legkark", "leggat" } do
	if unit(name) then
		costs(0.9)
		set(unitDef, "health", 0.9)
		set(unitDef, "speed", 1.07)
		for wname in pairs(unitDef[weapondefs]) do
			weapon(wname)
			damages(0.92)
		end
	end
end

--------------------------------------------------------------------------------
-- Weapon conversions ----------------------------------------------------------

local function scaleLaserFX(grav)
	local scale = math.sqrt(damages().default / ref.damage.default) * (grav or 1) + (0.5 - (grav or 1) * 0.5)
	scale = scale / ((weaponDef.beamtime or (1/30)) * 30)
	set(weaponDef, "corethickness", scale)
	set(weaponDef, "thickness", scale)
	set(weaponDef, "laserflaresize", scale * 0.1 + 0.9)
end

-- Heat rays
local function scaleHeatRay(name, wname)
	if unit(name) and weapon(wname) then
		if weaponDef[areaofeffect] >= 40 and not weaponDef.impactonly then
			costs(0.95)
		end
		copyref(weaponDef, "impactonly", areaofeffect,
			"corethickness", explosiongenerator, "intensity", "laserflaresize", "rgbcolor", "thickness", "size",
			"soundhitdry", "soundhitwet")
		scaleLaserFX()
	end
end
ref = UD.armllt[weapondefs].arm_lightlaser
for name, wname in pairs { leginfestor = "festorbeam", leglht = "heat_ray", legsh = "heat_ray", leghelios = "heat_ray" } do
	scaleHeatRay(name, wname)
end
ref = UD.armbeamer[weapondefs].armbeamer_weapon
for name, wname in pairs { legheavydrone = "heat_ray", leginc = "heatraylarge", legkark = "heat_ray", legbastion = "t2heatray", leganavyflagship = "leg_experimental_heatray", legnavydestro = "leg_medium_heatray", legeheatraymech = "heatray1", legehovertank = "heat_ray", legaheattank = "heat_ray" } do
	scaleHeatRay(name, wname)
end

-- Railguns
ref = UD.corhlt[weapondefs].cor_laserh1
for name, wname in pairs { legrail = "railgun", legsrail = "railgunt2", leganavyflagship = "leg_experimental_railgun", legerailtank = "t3_rail_accelerator" } do
	if unit(name) and weapon(wname) then
		custom(weaponDef)
		copyref(weaponDef, "weapontype", "beamtime", "impulsefactor", "noexplode", "name",
			"corethickness", explosiongenerator, "intensity", "laserflaresize", "rgbcolor", "thickness", "size", "cegtag",
			"soundhitdry", "soundhitwet", "soundstart",
			"cylindertargeting", "impactonly", "predictboost")
		weaponDef[weaponvelocity] = weaponDef.range + 100
		cparams.overpenetrate = nil
		damages(1.3)
		scaleLaserFX(0.6667)
	end
end
for name, wname in pairs { legrail = "aa_railgun", legadvaabot = "aa_railgun" } do
	if unit(name) and weapon(wname) then
		local range, vtol, reloadtime = weaponDef.range, weaponDef.damage.vtol, weaponDef.reloadtime
		weaponDef = copyweapon(wname, UD.armaak[weapondefs].longrangemissile)
		weaponDef.range = range
		weaponDef.damage.vtol = vtol
		weaponDef.reloadtime = reloadtime
	end
end

-- Machine guns
ref = UD.armpw[weapondefs].emg
for name, wname in pairs { legscout = "gun", leggob = "semiauto", legstr = "armmg_weapon", legmg = "armmg_weapon", legfmg = "gatling_gun", legapopupdef = "standard_minigun", leganavaldefturret = "legion_heavy_minigun", leganavycruiser = "mg_guns", legnavyscout = "mg_guns", legjav = "mg_guns", legkeres = "legkeres_gatling", legfloat = "legfloat_gatling", leggat = "armmg_weapon", legfort = "semiauto" } do
	if unit(name) and weapon(wname) then
		copyref(weaponDef, edgeeffectiveness, explosiongenerator, "gravityaffected", "intensity", "rgbcolor", "size", "soundstart", "weapontype")
		set(weaponDef, weaponvelocity, 0.6154)
		set(weaponDef, "ownerExpAccWeight", 0.5)
		damages(1.0833)
		costs(1.01)
	end
end
ref = UD.armfig[weapondefs].armvtol_missile
for name, wname in pairs { legfig = "semiauto", legafigdef = "leggun" } do
	if unit(name) and weapon(wname) then
		local dps, range = weaponDef.damage.vtol / weaponDef.reloadtime, weaponDef.range
		weaponDef = copyweapon(wname, ref)
		weaponDef.range = range
		damages(dps / ref.damage.vtol * ref.reloadtime)
		unitDef[weapons][1].maxangledif = nil
	end
end

-- Shotguns
ref = UD.armclaw[weapondefs].dclaw
for name, wname in pairs { legkark = "legion_shotgun", legcar = "shot", leganavybattleship = "legion_shotgun", legeshotgunmech = "shotgun", legstronghold = "shotgun", leganavaldefturret = "advanced_shotgun" } do
	if unit(name) and weapon(wname) then
		copyref(weaponDef, "weapontype", "burstrate", "duration", explosiongenerator, "impulsefactor", "intensity", "soundhit", "soundhitwet", "soundstart", "thickness")
		weaponDef.burst = weaponDef.projectiles
		weaponDef.projectiles = nil
		weaponDef.weaponvelocity = weaponDef.range + 20
	end
end

-- Burst plasma
ref = UD.correap[weapondefs].cor_reap
for name, wname in pairs { legcen = "gauss", legaskirmtank = "legmgplasma", legmrv = "quickshot_cannon", leganavybattleship = "burst_plasma_t2", } do
	if unit(name) and weapon(wname) then
		local burst = weaponDef.burst
		copyref(weaponDef, name, "impactonly", "impulsefactor", weaponvelocity, edgeeffectiveness)
		weaponDef.burst = nil
		weaponDef.impactonly = nil
		damages(burst)
		local t = math.clamp((weaponDef.damage.default * (1 - 1 / burst)) / ref.damage.default, 0, 1 + (burst - 1) / 10)
		weaponDef[areaofeffect] = math.mix(weaponDef[areaofeffect], ref[areaofeffect], t)
	end
end

-- Cluster plasma
local function toplasma(name, wname, cname)
	if unit(name) and weapon(wname) then
		ref = UD.armamb[weapondefs].armamb_gun -- TODO: need existence checks for ref, too.
		copyref(weaponDef, "cegtag", explosiongenerator)
		local count = custom(weaponDef).cluster_number or 5
		damages(1 + math.sqrt(count * weapon(cname or "cluster_munition").damage.default / weapon(wname).damage.default))
		cparams.cluster_def, cparams.cluster_number = nil, nil
	end
end
for name, wname in pairs { legamcluster = "cluster_artillery", legcluster = "plasma", legacluster = "plasma", leglrpc = "lrpc", legeallterrainmech = "plasma_low" } do
	toplasma(name, wname)
end
for name, wname in pairs { legcluster = "plasma_high", legacluster = "plasma_high", legeallterrainmech = "plasma_high" } do
	toplasma(name, wname)
end
toplasma("leganavyartyship", "leg_mobile_cluster_lrpc_cannon", "cluster_munition_main")
toplasma("leganavyartyship", "leg_mobile_cluster_plasma", "cluster_munition_secondary")

-- Napalm
if unit("legbar") then
	unitDef.speed = 49
	weaponDef = copyweapon("clusternapalm", UD.legehovertank[weapondefs].parabolic_rockets)
	weaponDef[areaofeffect] = 56
	weaponDef[edgeeffectiveness] = 0.25
	weaponDef[explosiongenerator] = "custom:genericshellexplosion-small-bomb"
	weaponDef.burst = 3
	weaponDef.burstrate = 0.4
	weaponDef.range = 610
	weaponDef[weaponvelocity] = 260
end

if unit("legbart") then
	copyweapon("clusternapalm", UD.armfido[weapondefs].bfido)
	costs(0.85)
end

if unit("leginf") then
	weaponDef = copyweapon("rapidnapalm", UD.cortrem[weapondefs].tremor_spread_fire)
	weaponDef.burst = 3
	weaponDef.burstrate = 0.3333
	weaponDef.reloadtime = 2
	weaponDef.mygravity = 0.18
	weaponDef.range = 1200
	weaponDef[weaponvelocity] = 460
end

if unit("legperdition") then
	copyweapon("napalmmissile", UD.cortron[weapondefs].cortron_weapon)
end

-- Medusa
if unit("legmed") then
	copyweapon("laser", UD.corak[weapondefs].gator_laser)
	unitDef[weapons][1][badtargetcategory] = "VTOL"
	unitDef[weapons][2][badtargetcategory] = "VTOL"
	unitDef[weapons][2].slaveto = nil
	weapon("legmed_missile").customparams = {
		projectile_destruction_method = "descend",
		overrange_distance = 1093,
	}
	ref = weaponDef
	weapon("laser").range = ref.range
end

-- Blindfold
if unit("legcib") then
	unitDef[weapons][1].def = "emp"
	weaponDef = copyweapon("emp", UD.armstil.weapondefs.stiletto_bomb)
	weaponDef[areaofeffect] = 120
	weaponDef.paralyzetime = 10
	weaponDef.range = unitDef.speed * 3
	weaponDef.reloadtime = 10
	damages(0.1)
end

-- Telchine
if unit("legamph") then
	copyweapon("heat_ray", UD.cormaw[weapondefs].dmaw)
	copyweapon("coax_depthcharge", UD.cormort[weapondefs].cor_mort)
	unitDef[weapons][2][onlytargetcategory] = "SURFACE"
end

--------------------------------------------------------------------------------
-- Reactive armor --------------------------------------------------------------

for _, name in pairs { "legkark", "legamph", "legshot" } do
	if unit(name) then
		custom(unitDef)
		local armoredMult = 1 / unitDef.damagemodifier
		local armorHealth = cparams.reactive_armor_health
		cparams.reactive_armor_health = nil
		cparams.reactive_armor_restore = nil
		local healthBonus = armorHealth * (0.5 + math.sqrt(armorHealth * armoredMult / unitDef.health) * (armoredMult - 1))
		unitDef.health = unitDef.health + healthBonus
	end
end

--------------------------------------------------------------------------------
-- Drones ----------------------------------------------------------------------

for name, wname in pairs { leghive = "plasma", legfhive = "plasma", legspcarrier = "leg_drone_controller", legvcarry = "targeting", leganavyantinukecarrier = "leg_drone_controller" } do
	if unit(name) and weapon(wname) then
		costs(0.75)
		ref = unitDef[weapons][1]
		ref[onlytargetcategory] = "VTOL"
		ref[badtargetcategory] = "LIGHTAIRSCOUT"
		weaponDef.range = 1600
		ref = UD.armfig
		copyref(custom(weaponDef), metalcost, energycost)
		cparams.carried_unit = "legfig"
		cparams.controlradius = 1600
	end
end

--------------------------------------------------------------------------------
-- Nuh-uh ----------------------------------------------------------------------

if unit("leglob") then
	unitDef[weapons][2] = nil
end

for name, wname in pairs { legmg = "armmg_weapon", legfmg = "gatling_gun" } do
	if unit(name) and weapon(wname) then
		unitDef.cantbetransported = true
		weaponDef.range = 625
		weaponDef.accuracy = 100
		weaponDef.sprayangle = 880
		costs(1.07)
	end
end

if unit("legfloat") then
	unitDef.movementclass = "MTANK3"
	unitDef.waterline = nil
	unitDef.floater = nil
end

if unit("legnavyfrigate") then
	unitDef[weapons][1][onlytargetcategory] = "NOTSUB"
	unitDef[weapons][2] = nil
	costs(0.85)
end

if unit("legnavydestro") then
	ref = UD.legnavyartyship
	copyref(unitDef, "buildpic", "collisionvolumeoffsets", "collisionvolumescales", "collisionvolumetype", "objectname", "script")
	copyweapon("depthcharge", UD.corroy[weapondefs].depthcharge)
	unitDef[weapons][2] = table.copy(UD.corroy[weapons][2])
	unitDef[weapondefs].drone_control_matrix = nil
	costs(1.08)
end

if unit("leganavybattleship") then
	unitDef.movementclass = "BOAT9"
	costs(0.88)
end

if unit("legap") then
	table.insert(unitDef.buildoptions, "corfink")
end

UD.legkam = table.copy(UD.armthund)

UD.legphoenix = nil

if unit("legmineb") then
	copyweapon("cor_seaadvbomb", UD.corhurc[weapondefs].coradvbomb)
	costs(0.94)
end

if unit("legrampart") then
	unitDef.radardistancejam = nil
	unitDef[weapons][2] = nil
	costs(0.9)
end

UD.legelrpcmech = nil

if unit("legeallterrainmech") then
	unitDef[weapons][5] = nil
	costs(0.9)
end

UD.legstarfall = table.copy(UD.armvulc)

--------------------------------------------------------------------------------
-- Convert to tweakunits -------------------------------------------------------

local tweaks = {}
for name, old in pairs(units) do
	tweaks[name] = diff(old, UD[name])
end
Spring.Echo(tweaks)