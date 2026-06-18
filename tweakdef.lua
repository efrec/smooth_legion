--SMOOTH LEGION

local UD = UnitDefs
local unitDef, weaponDef, cparams, ref
local units = {}
local divisors = { 2, 4, 5, 8, 12, 20, 50, 125, 250 }
local m2e, m2b = 20, 30

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

local function deep(tbl)
	local new = {}
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			new[k] = deep(v)
		else
			new[k] = v
		end
	end
	return new
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
		units[name] = deep(unitDef)
	end
	return unitDef
end

local function weapon(name)
	nounit(name)
	weaponDef = unitDef.weapondefs[name]
	noweapon(name)
	return weaponDef
end

local function custom(def)
	cparams = def.customparams or {}
	def.customparams = cparams
	return cparams
end

local function copy(def, ...)
	for _, property in ipairs({ ... }) do
		def[property] = ref[property]
	end
end

local function neat(value, precision)
	if precision then
		value = value / precision
	else
		precision = 1
	end
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
		local fitness2 = values[divisor] - value
		fitness2 = fitness2 * fitness2 / divisors[i]
		if fitness > fitness2 then
			neatest = values[divisor]
			fitness = fitness2
		end
	end
	return neatest * precision
end

local function set(tbl, key, mult, add, precision)
	local value = tonumber(tbl[key])
	if type(value) == "number" then
		tbl[key] = neat(value * (mult or 1) + (add or 0), precision)
	end
end

local function costs(mult, add_m, add_e, add_bp)
	local u = unitDef
	if not add_m then add_m = 0 end
	if not add_e then
		add_e = add_m * (u.metalcost and u.metalcost > 0 and u.energycost / u.metalcost or m2e)
	end
	if not add_bp then
		add_bp = add_m * (u.metalcost and u.metalcost > 0 and u.buildtime / u.metalcost or m2b)
	end
	local metal = neat(u.metalcost * mult + add_m, 10)
	local ratio = metal / u.metalcost
	u.metalcost = metal
	set(u, "energycost", mult, add_e, 10)
	set(u, "buildtime", mult, add_bp, 10)
	for _, fd in pairs(u.featuredefs or {}) do
		fd.metal = math.floor(ratio * fd.metal + 0.5)
	end
end

local function damages(mult, add)
	for armor in pairs(weaponDef.damage) do
		set(weaponDef.damage, armor, mult, add)
	end
	return weaponDef.damage
end

--------------------------------------------------------------------------------
-- Commander -------------------------------------------------------------------

ref = unit("legcom").weapons
ref[1].onlytargetcategory = "NOTSUB"
ref[1].fastautoretargeting = true
ref[4] = nil
ref = UD.armcom.weapondefs
unitDef.weapondefs.legcomlaser = table.copy(ref.armcomlaser)
unitDef.weapondefs.torpedo = table.copy(ref.armcomsealaser)

--------------------------------------------------------------------------------
-- Basic economy ---------------------------------------------------------------

if unit("legmex") then
	unitDef.extractsmetal = 0.001
	unitDef.energyupkeep = 3
end

--------------------------------------------------------------------------------
-- Make T1.5 units smoother ----------------------------------------------------

for _, name in ipairs { "legkark", "leggat" } do
	if unit(name) then
		costs(0.9)
		set(unitDef, "health", 0.9)
		set(unitDef, "speed", 1.07)
		for wname in pairs(unitDef.weapondefs) do
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
		if weaponDef.areaofeffect >= 40 and weaponDef.impactonly ~= 1 then
			costs(0.95)
		end
		copy(weaponDef, "impactonly", "areaofeffect",
			"corethickness", "explosiongenerator", "intensity", "laserflaresize", "rgbcolor", "thickness", "size",
			"soundhitdry", "soundhitwet")
		scaleLaserFX()
	end
end
ref = UD.armllt.weapondefs.arm_lightlaser
for name, wname in pairs { leginfestor = "festorbeam", leglht = "heat_ray", legsh = "heat_ray", leghelios = "heat_ray" } do
	scaleHeatRay(name, wname)
end
ref = UD.armbeamer.weapondefs.armbeamer_weapon
for name, wname in pairs { legheavydrone = "heat_ray", leginc = "heatraylarge", legkark = "heat_ray", legbastion = "t2heatray", leganavyflagship = "leg_experimental_heatray", legnavydestro = "leg_medium_heatray", legeheatraymech = "heatray1", legehovertank = "heat_ray", legaheattank = "heat_ray" } do
	scaleHeatRay(name, wname)
end

-- Railguns
ref = UD.corhlt.weapondefs.cor_laserh1
for name, wname in pairs { legrail = "railgun", legsrail = "railgunt2", leganavyflagship = "leg_experimental_railgun", legerailtank = "t3_rail_accelerator" } do
	if unit(name) and weapon(wname) then
		custom(weaponDef)
		weaponDef.name = "Heavy Laser"
		copy(weaponDef, "weapontype", "beamtime", "impulsefactor", "noexplode",
			"corethickness", "explosiongenerator", "intensity", "laserflaresize", "rgbcolor", "thickness", "size",
			"soundhitdry", "soundhitwet", "soundstart",
			"cylindertargeting", "impactonly", "predictboost")
		weaponDef.weaponvelocity = weaponDef.range + 100
		cparams.overpenetrate = nil
		damages(1.3)
		scaleLaserFX(0.6667)
	end
end
ref = UD.armaak.weapondefs.longrangemissile
for name, wname in pairs { legrail = "aa_railgun", legadvaabot = "aa_railgun" } do
	if unit(name) and weapon(wname) then
		weaponDef.name = "Long-Range Anti-Air Missile Launcher"
		local range = weaponDef.range
		local vtol = weaponDef.damage.vtol
		local reloadtime = weaponDef.reloadtime
		local new = table.copy(ref)
		new.range = range
		new.vtol = vtol
		new.reloadtime = reloadtime
		unitDef.weapondefs[wname] = new
	end
end

-- Burst plasma
ref = UD.correap.weapondefs.cor_reap
for name, wname in pairs { legcen = "gauss", legaskirmtank = "legmgplasma", legmrv = "quickshot_cannon", leganavybattleship = "burst_plasma_t2", } do
	if unit(name) and weapon(wname) then
		weaponDef.name = "Medium Plasma Cannon"
		weaponDef.impactonly = false
		local burst = weaponDef.burst
		copy(weaponDef, "impactonly", "impulsefactor", "weaponvelocity", "edgeeffectiveness")
		local base = weaponDef.damage.default
		damages(burst)
		weaponDef.burst = nil
		local t = math.clamp((weaponDef.damage.default - base) / (ref.damage.default - base), 0, 1 + burst / 3)
		weaponDef.areaofeffect = math.mix(weaponDef.areaofeffect, ref.areaofeffect, t)
	end
end

-- Cluster plasma
ref = UD.armamb.weapondefs.armamb_gun
local function toplasma(name, wname, cname)
	if unit(name) and weapon(wname) then
		custom(weaponDef)
		copy(weaponDef, "cegtag", "explosiongenerator")
		local count = cparams.cluster_number or 5
		local damage = unitDef.weapondefs[cname or "cluster_munition"].damage.default
		damages(1 + math.sqrt(count * damage / weaponDef.damage.default))
		cparams.cluster_def, cparams.cluster_number = nil, nil
	end
end
for name, wname in pairs { legamcluster = "cluster_artillery", legcluster = "plasma", legacluster = "plasma", leglrpc = "lrpc", legeallterrainmech = "plasma_low", leganavyartyship = "leg_cluster_artillery_cannon" } do
	toplasma(name, wname)
end
for name, wname in pairs { legcluster = "plasma_high", legacluster = "plasma_high", legeallterrainmech = "plasma_high", leganavyartyship = "leg_cluster_artillery_cannon_2" } do
	toplasma(name, wname)
end
toplasma("leganavyartyship", "leg_mobile_cluster_lrpc_cannon", "cluster_munition_main")
toplasma("leganavyartyship", "leg_mobile_cluster_plasma", "cluster_munition_secondary")

-- Napalm
if unit("legbar") then
	unitDef.speed = 49
	unitDef.weapondefs.clusternapalm = table.copy(UD.legehovertank.weapondefs.parabolic_rockets)
	weapon("clusternapalm")
	weaponDef.areaofeffect = 56
	weaponDef.edgeeffectiveness = 0.25
	weaponDef.explosiongenerator = "custom:genericshellexplosion-small-bomb"
	weaponDef.burst = 3
	weaponDef.burstrate = 0.4
	weaponDef.range = 610
	weaponDef.weaponvelocity = 260
end

if unit("legbart") then
	unitDef.weapondefs.clusternapalm = table.copy(UD.armfido.weapondefs.bfido)
	costs(0.85)
end

if unit("leginf") then
	unitDef.weapondefs.rapidnapalm = table.copy(UD.cortrem.weapondefs.tremor_spread_fire)
	weapon("rapidnapalm")
	weaponDef.burst = 3
	weaponDef.burstrate = 0.3333
	weaponDef.reloadtime = 2
	weaponDef.mygravity = 0.18
	weaponDef.range = 1200
	weaponDef.weaponvelocity = 460
end

if unit("legperdition") then
	unitDef.weapondefs.napalmmissile = table.copy(UD.cortron.weapondefs.cortron_weapon)
end

-- Medusa
if unit("legmed") then
	unitDef.weapondefs.laser = table.copy(UD.corak.weapondefs.gator_laser)
	unitDef.weapons[1].badtargetcategory = "VTOL"
	unitDef.weapons[2].badtargetcategory = "VTOL"
	unitDef.weapons[2].slaveto = nil
	weapon("legmed_missile").customparams = {
		cruise_max_height = 40,
		cruise_min_height = 15,
		lockon_dist = 100,
		speceffect = "cruise",
		projectile_destruction_method = "descend",
		overrange_distance = 1093,
	}
	ref = weaponDef
	weapon("laser").range = ref.range
end

-- Blindfold
if unit("legcib") and weapon("juno_pulse_mini") then
	unitDef.weapondefs.emp_pulse = table.copy(weaponDef)
	unitDef.weapons[1].def = "emp_pulse"
	unitDef.weapondefs.juno_pulse_mini = nil
	weapon("emp_pulse")
	weaponDef.customparams = nil
	weaponDef.paralyzer = true
	weaponDef.paralyzetime = 5
	weaponDef.areaofeffect = 420
	weaponDef.edgeeffectiveness = 0
	weaponDef.damage.default = 300
	weaponDef.damage.vtol = 10
end

-- Telchine
if unit("legamph") then
	unitDef.weapondefs.heat_ray = table.copy(UD.cormaw.weapondefs.dmaw)
	unitDef.weapondefs.coax_depthcharge = table.copy(UD.cormort.weapondefs.cor_mort)
	unitDef.weapons[2].onlytargetcategory = "SURFACE"
end

--------------------------------------------------------------------------------
-- Reactive armor --------------------------------------------------------------

for _, name in ipairs { "legkark", "legamph", "legshot" } do
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

ref = UD.armfig
for name, wname in pairs { leghive = "plasma", legfhive = "plasma", legspcarrier = "leg_drone_controller", legvcarry = "targeting", leganavyantinukecarrier = "leg_drone_controller" } do
	if unit(name) and weapon(wname) then
		costs(0.75)
		unitDef.weapons[1].onlytargetcategory = "VTOL"
		unitDef.weapons[1].badtargetcategory = "LIGHTAIRSCOUT"
		weaponDef.range = 1600
		custom(weaponDef)
		cparams.carried_unit = "legfig"
		cparams.controlradius = 1600
		cparams.metalcost = ref.metalcost
		cparams.energycost = ref.energycost
	end
end

--------------------------------------------------------------------------------
-- Nuh-uh ----------------------------------------------------------------------

if unit("leglob") then
	unitDef.weapons[2] = nil
end

if unit("legmg") and weapon("armmg_weapon") then
	unitDef.cantbetransported = true
	costs(1.07)
	weaponDef.range = 620
	weaponDef.ownerExpAccWeight = 2
	weaponDef.accuracy = 100
	weaponDef.sprayangle = 880
end

if unit("legfloat") then
	unitDef.movementclass = "MTANK3"
	unitDef.waterline = nil
	unitDef.floater = nil
end

if unit("legnavyfrigate") then
	unitDef.weapons[1].onlytargetcategory = "NOTSUB"
	unitDef.weapons[2] = nil
	costs(0.85)
end

if unit("legnavydestro") then
	ref = UD.legnavyartyship
	copy(unitDef, "buildpic", "collisionvolumeoffsets", "collisionvolumescales", "collisionvolumetype", "objectname", "script")
	unitDef.weapons[2] = table.copy(UD.corroy.weapons[2])
	unitDef.weapondefs.depthcharge = table.copy(UD.corroy.weapondefs.depthcharge)
	unitDef.weapondefs.drone_control_matrix = nil
	costs(1.08)
end

if unit("leganavybattleship") then
	unitDef.movementclass = "BOAT9"
	costs(0.88)
end

if unit("legap") then
	table.insert(unitDef.buildoptions, "corfink")
end

if unit("legfig") then
	ref = UD.armfig
	copy(unitDef, "buildtime", "energycost", "metalcost", "speed", "turnradius")
	unitDef.weapondefs.semiauto = table.copy(ref.weapondefs.armvtol_missile)
	unitDef.weapons[1].maxangledif = nil
end

UD.legkam = table.copy(UD.armthund)

UD.legphoenix = nil

if unit("legmineb") then
	unitDef.weapondefs.cor_seaadvbomb = table.copy(UD.corhurc.weapondefs.coradvbomb)
	costs(0.94)
end

if unit("legrampart") then
	unitDef.radardistancejam = nil
	unitDef.weapons[2] = nil
	costs(0.9)
end

UD.legelrpcmech = nil

if unit("legeallterrainmech") then
	unitDef.weapons[5] = nil
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