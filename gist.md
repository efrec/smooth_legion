# SMOOTH LEGION

## Tweakdefs

```lua
--SMOOTH LEGION
local UD = UnitDefs
local unitDef, weaponDef, cparams, ref
local divisors, m2e, m2b = { 2, 4, 5, 8, 12, 20, 50, 125, 250 }, 60, 30
local weapons, weapondefs, metalcost, energycost, buildtime, onlytargetcategory, badtargetcategory, areaofeffect, edgeeffectiveness, explosiongenerator, weaponvelocity = "weapons", "weapondefs", "metalcost", "energycost", "buildtime", "onlytargetcategory", "badtargetcategory", "areaofeffect", "edgeeffectiveness", "explosiongenerator", "weaponvelocity"

--------------------------------------------------------------------------------
-- Initialize ------------------------------------------------------------------

local function unit(name)
	unitDef = UD[name]
	return unitDef
end

local function weapon(name)
	weaponDef = unitDef[weapondefs][name]
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
```

## Tweakunits

<!-- tweakunits_readable -->

## Tweakdefs encoded (URL-safe base64)

> bG9jYWwgYT1Vbml0RGVmcztsb2NhbCBiLGMsZCxlO2xvY2FsIGYsZyxoPXsyLDQsNSw4LDEyLDIwLDUwLDEyNSwyNTB9LDYwLDMwO2xvY2FsIGksaixrLGwsbSxuLG8scCxxLHIscz0id2VhcG9ucyIsIndlYXBvbmRlZnMiLCJtZXRhbGNvc3QiLCJlbmVyZ3ljb3N0IiwiYnVpbGR0aW1lIiwib25seXRhcmdldGNhdGVnb3J5IiwiYmFkdGFyZ2V0Y2F0ZWdvcnkiLCJhcmVhb2ZlZmZlY3QiLCJlZGdlZWZmZWN0aXZlbmVzcyIsImV4cGxvc2lvbmdlbmVyYXRvciIsIndlYXBvbnZlbG9jaXR5ImxvY2FsIGZ1bmN0aW9uIHQodSliPWFbdV1yZXR1cm4gYiBlbmQ7bG9jYWwgZnVuY3Rpb24gdih1KWM9YltqXVt1XXJldHVybiBjIGVuZDtsb2NhbCBmdW5jdGlvbiB3KHgpZD14LmN1c3RvbXBhcmFtcyBvcnt9eC5jdXN0b21wYXJhbXM9ZDtyZXR1cm4gZCBlbmQ7bG9jYWwgZnVuY3Rpb24geSh1LHgpbG9jYWwgej10YWJsZS5jb3B5KHggb3IgZSliW2pdW3VdPXo7cmV0dXJuIHogZW5kO2xvY2FsIGZ1bmN0aW9uIEEoeCwuLi4pbm9yZWZkZWYoeCwuLi4pZm9yIEIsQyBpbiBpcGFpcnMoey4uLn0pZG8geFtDXT1lW0NdZW5kIGVuZDtsb2NhbCBmdW5jdGlvbiBEKEUsRilGPUYgb3IgMTtFPUUvRjtpZiBFPD0zMCB0aGVuIHJldHVybiBtYXRoLmZsb29yKEUrMC41KSpGIGVuZDtsb2NhbCBHPXt9Zm9yIEIsSCBpbiBpcGFpcnMoZilkbyBHW0hdPW1hdGguZmxvb3IoRS9IKzAuNSkqSCBlbmQ7bG9jYWwgST1HW2ZbMV1dbG9jYWwgSj1JLUU7Sj1KKkovZlsxXWZvciBLPTIsI2YgZG8gbG9jYWwgTD1mW0tdbG9jYWwgTT0oR1tMXS1FKV4yL2ZbMV1pZiBKPk0gdGhlbiBJPUdbTF1KPU0gZW5kIGVuZDtyZXR1cm4gSSpGIGVuZDtsb2NhbCBmdW5jdGlvbiBOKE8sUCxRLFIsRilsb2NhbCBFPXRvbnVtYmVyKE9bUF0pT1tQXT1FIGFuZCBEKEUqKFEgb3IgMSkrKFIgb3IgMCksRilvciBuaWwgZW5kO2xvY2FsIGZ1bmN0aW9uIFMoUSxULFUsVilUPVQgb3IgMDtVPVUgb3IgVCooKGJba11vciAwKT4wIGFuZCBiW2xdL2Jba11vciBnKVY9ViBvciBUKigoYltrXW9yIDApPjAgYW5kIGJbbV0vYltrXW9yIGgpTihiLGssUSxULDEwKU4oYixsLFEsVSwxMClOKGIsbSxRLFYsMTApZW5kO2xvY2FsIGZ1bmN0aW9uIFcoUSxSKWZvciBYIGluIHBhaXJzKGMuZGFtYWdlKWRvIE4oYy5kYW1hZ2UsWCxRLFIpZW5kO3JldHVybiBjLmRhbWFnZSBlbmQ7ZT10KCJsZWdjb20iKVtpXWVbMV1bbl09Ik5PVFNVQiJlWzFdLmZhc3RhdXRvcmV0YXJnZXRpbmc9dHJ1ZTtlWzRdPW5pbDtlPWEuYXJtY29tW2pdeSgibGVnY29tbGFzZXIiLGUuYXJtY29tbGFzZXIpeSgidG9ycGVkbyIsZS5hcm1jb21zZWFsYXNlcilpZiB0KCJsZWdtZXgiKXRoZW4gYi5leHRyYWN0c21ldGFsPTAuMDAxO2IuZW5lcmd5dXBrZWVwPTMgZW5kO2ZvciBCLHUgaW4gcGFpcnN7ImxlZ2thcmsiLCJsZWdnYXQifWRvIGlmIHQodSl0aGVuIFMoMC45KU4oYiwiaGVhbHRoIiwwLjkpTihiLCJzcGVlZCIsMS4wNylmb3IgWSBpbiBwYWlycyhiW2pdKWRvIHYoWSlXKDAuOTIpZW5kIGVuZCBlbmQ7bG9jYWwgZnVuY3Rpb24gWihfKWxvY2FsIGEwPW1hdGguc3FydChXKCkuZGVmYXVsdC9lLmRhbWFnZS5kZWZhdWx0KSooXyBvciAxKSswLjUtKF8gb3IgMSkqMC41O2EwPWEwLygoYy5iZWFtdGltZSBvciAxLzMwKSozMClOKGMsImNvcmV0aGlja25lc3MiLGEwKU4oYywidGhpY2tuZXNzIixhMClOKGMsImxhc2VyZmxhcmVzaXplIixhMCowLjErMC45KWVuZDtsb2NhbCBmdW5jdGlvbiBhMSh1LFkpaWYgdCh1KWFuZCB2KFkpdGhlbiBpZiBjW3BdPj00MCBhbmQgbm90IGMuaW1wYWN0b25seSB0aGVuIFMoMC45NSllbmQ7QShjLCJpbXBhY3Rvbmx5IixwLCJjb3JldGhpY2tuZXNzIixyLCJpbnRlbnNpdHkiLCJsYXNlcmZsYXJlc2l6ZSIsInJnYmNvbG9yIiwidGhpY2tuZXNzIiwic2l6ZSIsInNvdW5kaGl0ZHJ5Iiwic291bmRoaXR3ZXQiKVooKWVuZCBlbmQ7ZT1hLmFybWxsdFtqXS5hcm1fbGlnaHRsYXNlcjtmb3IgdSxZIGluIHBhaXJze2xlZ2luZmVzdG9yPSJmZXN0b3JiZWFtIixsZWdsaHQ9ImhlYXRfcmF5IixsZWdzaD0iaGVhdF9yYXkiLGxlZ2hlbGlvcz0iaGVhdF9yYXkifWRvIGExKHUsWSllbmQ7ZT1hLmFybWJlYW1lcltqXS5hcm1iZWFtZXJfd2VhcG9uO2ZvciB1LFkgaW4gcGFpcnN7bGVnaGVhdnlkcm9uZT0iaGVhdF9yYXkiLGxlZ2luYz0iaGVhdHJheWxhcmdlIixsZWdrYXJrPSJoZWF0X3JheSIsbGVnYmFzdGlvbj0idDJoZWF0cmF5IixsZWdhbmF2eWZsYWdzaGlwPSJsZWdfZXhwZXJpbWVudGFsX2hlYXRyYXkiLGxlZ25hdnlkZXN0cm89ImxlZ19tZWRpdW1faGVhdHJheSIsbGVnZWhlYXRyYXltZWNoPSJoZWF0cmF5MSIsbGVnZWhvdmVydGFuaz0iaGVhdF9yYXkiLGxlZ2FoZWF0dGFuaz0iaGVhdF9yYXkifWRvIGExKHUsWSllbmQ7ZT1hLmNvcmhsdFtqXS5jb3JfbGFzZXJoMTtmb3IgdSxZIGluIHBhaXJze2xlZ3JhaWw9InJhaWxndW4iLGxlZ3NyYWlsPSJyYWlsZ3VudDIiLGxlZ2FuYXZ5ZmxhZ3NoaXA9ImxlZ19leHBlcmltZW50YWxfcmFpbGd1biIsbGVnZXJhaWx0YW5rPSJ0M19yYWlsX2FjY2VsZXJhdG9yIn1kbyBpZiB0KHUpYW5kIHYoWSl0aGVuIHcoYylBKGMsIndlYXBvbnR5cGUiLCJiZWFtdGltZSIsImltcHVsc2VmYWN0b3IiLCJub2V4cGxvZGUiLCJuYW1lIiwiY29yZXRoaWNrbmVzcyIsciwiaW50ZW5zaXR5IiwibGFzZXJmbGFyZXNpemUiLCJyZ2Jjb2xvciIsInRoaWNrbmVzcyIsInNpemUiLCJjZWd0YWciLCJzb3VuZGhpdGRyeSIsInNvdW5kaGl0d2V0Iiwic291bmRzdGFydCIsImN5bGluZGVydGFyZ2V0aW5nIiwiaW1wYWN0b25seSIsInByZWRpY3Rib29zdCIpY1tzXT1jLnJhbmdlKzEwMDtkLm92ZXJwZW5ldHJhdGU9bmlsO1coMS4zKVooMC42NjY3KWVuZCBlbmQ7Zm9yIHUsWSBpbiBwYWlyc3tsZWdyYWlsPSJhYV9yYWlsZ3VuIixsZWdhZHZhYWJvdD0iYWFfcmFpbGd1biJ9ZG8gaWYgdCh1KWFuZCB2KFkpdGhlbiBsb2NhbCBhMixhMyxhND1jLnJhbmdlLGMuZGFtYWdlLnZ0b2wsYy5yZWxvYWR0aW1lO2M9eShZLGEuYXJtYWFrW2pdLmxvbmdyYW5nZW1pc3NpbGUpYy5yYW5nZT1hMjtjLmRhbWFnZS52dG9sPWEzO2MucmVsb2FkdGltZT1hNCBlbmQgZW5kO2U9YS5hcm1wd1tqXS5lbWc7Zm9yIHUsWSBpbiBwYWlyc3tsZWdzY291dD0iZ3VuIixsZWdnb2I9InNlbWlhdXRvIixsZWdzdHI9ImFybW1nX3dlYXBvbiIsbGVnbWc9ImFybW1nX3dlYXBvbiIsbGVnZm1nPSJnYXRsaW5nX2d1biIsbGVnYXBvcHVwZGVmPSJzdGFuZGFyZF9taW5pZ3VuIixsZWdhbmF2YWxkZWZ0dXJyZXQ9ImxlZ2lvbl9oZWF2eV9taW5pZ3VuIixsZWdhbmF2eWNydWlzZXI9Im1nX2d1bnMiLGxlZ25hdnlzY291dD0ibWdfZ3VucyIsbGVnamF2PSJtZ19ndW5zIixsZWdrZXJlcz0ibGVna2VyZXNfZ2F0bGluZyIsbGVnZmxvYXQ9ImxlZ2Zsb2F0X2dhdGxpbmciLGxlZ2dhdD0iYXJtbWdfd2VhcG9uIixsZWdmb3J0PSJzZW1pYXV0byJ9ZG8gaWYgdCh1KWFuZCB2KFkpdGhlbiBBKGMscSxyLCJncmF2aXR5YWZmZWN0ZWQiLCJpbnRlbnNpdHkiLCJyZ2Jjb2xvciIsInNpemUiLCJzb3VuZHN0YXJ0Iiwid2VhcG9udHlwZSIpTihjLHMsMC42MTU0KU4oYywib3duZXJFeHBBY2NXZWlnaHQiLDAuNSlXKDEuMDgzMylTKDEuMDEpZW5kIGVuZDtlPWEuYXJtZmlnW2pdLmFybXZ0b2xfbWlzc2lsZTtmb3IgdSxZIGluIHBhaXJze2xlZ2ZpZz0ic2VtaWF1dG8iLGxlZ2FmaWdkZWY9ImxlZ2d1biJ9ZG8gaWYgdCh1KWFuZCB2KFkpdGhlbiBsb2NhbCBhNSxhMj1jLmRhbWFnZS52dG9sL2MucmVsb2FkdGltZSxjLnJhbmdlO2M9eShZLGUpYy5yYW5nZT1hMjtXKGE1L2UuZGFtYWdlLnZ0b2wqZS5yZWxvYWR0aW1lKWJbaV1bMV0ubWF4YW5nbGVkaWY9bmlsIGVuZCBlbmQ7ZT1hLmFybWNsYXdbal0uZGNsYXc7Zm9yIHUsWSBpbiBwYWlyc3tsZWdrYXJrPSJsZWdpb25fc2hvdGd1biIsbGVnY2FyPSJzaG90IixsZWdhbmF2eWJhdHRsZXNoaXA9ImxlZ2lvbl9zaG90Z3VuIixsZWdlc2hvdGd1bm1lY2g9InNob3RndW4iLGxlZ3N0cm9uZ2hvbGQ9InNob3RndW4iLGxlZ2FuYXZhbGRlZnR1cnJldD0iYWR2YW5jZWRfc2hvdGd1biJ9ZG8gaWYgdCh1KWFuZCB2KFkpdGhlbiBBKGMsIndlYXBvbnR5cGUiLCJidXJzdHJhdGUiLCJkdXJhdGlvbiIsciwiaW1wdWxzZWZhY3RvciIsImludGVuc2l0eSIsInNvdW5kaGl0Iiwic291bmRoaXR3ZXQiLCJzb3VuZHN0YXJ0IiwidGhpY2tuZXNzIiljLmJ1cnN0PWMucHJvamVjdGlsZXM7Yy5wcm9qZWN0aWxlcz1uaWw7Yy53ZWFwb252ZWxvY2l0eT1jLnJhbmdlKzIwIGVuZCBlbmQ7ZT1hLmNvcnJlYXBbal0uY29yX3JlYXA7Zm9yIHUsWSBpbiBwYWlyc3tsZWdjZW49ImdhdXNzIixsZWdhc2tpcm10YW5rPSJsZWdtZ3BsYXNtYSIsbGVnbXJ2PSJxdWlja3Nob3RfY2Fubm9uIixsZWdhbmF2eWJhdHRsZXNoaXA9ImJ1cnN0X3BsYXNtYV90MiJ9ZG8gaWYgdCh1KWFuZCB2KFkpdGhlbiBsb2NhbCBhNj1jLmJ1cnN0O0EoYyx1LCJpbXBhY3Rvbmx5IiwiaW1wdWxzZWZhY3RvciIscyxxKWMuYnVyc3Q9bmlsO2MuaW1wYWN0b25seT1uaWw7VyhhNilsb2NhbCBhNz1tYXRoLmNsYW1wKGMuZGFtYWdlLmRlZmF1bHQqKDEtMS9hNikvZS5kYW1hZ2UuZGVmYXVsdCwwLDErKGE2LTEpLzEwKWNbcF09bWF0aC5taXgoY1twXSxlW3BdLGE3KWVuZCBlbmQ7bG9jYWwgZnVuY3Rpb24gYTgodSxZLGE5KWlmIHQodSlhbmQgdihZKXRoZW4gZT1hLmFybWFtYltqXS5hcm1hbWJfZ3VuO0EoYywiY2VndGFnIixyKWxvY2FsIGFhPXcoYykuY2x1c3Rlcl9udW1iZXIgb3IgNTtXKDErbWF0aC5zcXJ0KGFhKnYoYTkgb3IiY2x1c3Rlcl9tdW5pdGlvbiIpLmRhbWFnZS5kZWZhdWx0L3YoWSkuZGFtYWdlLmRlZmF1bHQpKWQuY2x1c3Rlcl9kZWYsZC5jbHVzdGVyX251bWJlcj1uaWwsbmlsIGVuZCBlbmQ7Zm9yIHUsWSBpbiBwYWlyc3tsZWdhbWNsdXN0ZXI9ImNsdXN0ZXJfYXJ0aWxsZXJ5IixsZWdjbHVzdGVyPSJwbGFzbWEiLGxlZ2FjbHVzdGVyPSJwbGFzbWEiLGxlZ2xycGM9ImxycGMiLGxlZ2VhbGx0ZXJyYWlubWVjaD0icGxhc21hX2xvdyJ9ZG8gYTgodSxZKWVuZDtmb3IgdSxZIGluIHBhaXJze2xlZ2NsdXN0ZXI9InBsYXNtYV9oaWdoIixsZWdhY2x1c3Rlcj0icGxhc21hX2hpZ2giLGxlZ2VhbGx0ZXJyYWlubWVjaD0icGxhc21hX2hpZ2gifWRvIGE4KHUsWSllbmQ7YTgoImxlZ2FuYXZ5YXJ0eXNoaXAiLCJsZWdfbW9iaWxlX2NsdXN0ZXJfbHJwY19jYW5ub24iLCJjbHVzdGVyX211bml0aW9uX21haW4iKWE4KCJsZWdhbmF2eWFydHlzaGlwIiwibGVnX21vYmlsZV9jbHVzdGVyX3BsYXNtYSIsImNsdXN0ZXJfbXVuaXRpb25fc2Vjb25kYXJ5IilpZiB0KCJsZWdiYXIiKXRoZW4gYi5zcGVlZD00OTtjPXkoImNsdXN0ZXJuYXBhbG0iLGEubGVnZWhvdmVydGFua1tqXS5wYXJhYm9saWNfcm9ja2V0cyljW3BdPTU2O2NbcV09MC4yNTtjW3JdPSJjdXN0b206Z2VuZXJpY3NoZWxsZXhwbG9zaW9uLXNtYWxsLWJvbWIiYy5idXJzdD0zO2MuYnVyc3RyYXRlPTAuNDtjLnJhbmdlPTYxMDtjW3NdPTI2MCBlbmQ7aWYgdCgibGVnYmFydCIpdGhlbiB5KCJjbHVzdGVybmFwYWxtIixhLmFybWZpZG9bal0uYmZpZG8pUygwLjg1KWVuZDtpZiB0KCJsZWdpbmYiKXRoZW4gYz15KCJyYXBpZG5hcGFsbSIsYS5jb3J0cmVtW2pdLnRyZW1vcl9zcHJlYWRfZmlyZSljLmJ1cnN0PTM7Yy5idXJzdHJhdGU9MC4zMzMzO2MucmVsb2FkdGltZT0yO2MubXlncmF2aXR5PTAuMTg7Yy5yYW5nZT0xMjAwO2Nbc109NDYwIGVuZDtpZiB0KCJsZWdwZXJkaXRpb24iKXRoZW4geSgibmFwYWxtbWlzc2lsZSIsYS5jb3J0cm9uW2pdLmNvcnRyb25fd2VhcG9uKWVuZDtpZiB0KCJsZWdtZWQiKXRoZW4geSgibGFzZXIiLGEuY29yYWtbal0uZ2F0b3JfbGFzZXIpYltpXVsxXVtvXT0iVlRPTCJiW2ldWzJdW29dPSJWVE9MImJbaV1bMl0uc2xhdmV0bz1uaWw7digibGVnbWVkX21pc3NpbGUiKS5jdXN0b21wYXJhbXM9e3Byb2plY3RpbGVfZGVzdHJ1Y3Rpb25fbWV0aG9kPSJkZXNjZW5kIixvdmVycmFuZ2VfZGlzdGFuY2U9MTA5M31lPWM7digibGFzZXIiKS5yYW5nZT1lLnJhbmdlIGVuZDtpZiB0KCJsZWdjaWIiKXRoZW4gYltpXVsxXS5kZWY9ImVtcCJjPXkoImVtcCIsYS5hcm1zdGlsLndlYXBvbmRlZnMuc3RpbGV0dG9fYm9tYiljW3BdPTEyMDtjLnBhcmFseXpldGltZT0xMDtjLnJhbmdlPWIuc3BlZWQqMztjLnJlbG9hZHRpbWU9MTA7VygwLjEpZW5kO2lmIHQoImxlZ2FtcGgiKXRoZW4geSgiaGVhdF9yYXkiLGEuY29ybWF3W2pdLmRtYXcpeSgiY29heF9kZXB0aGNoYXJnZSIsYS5jb3Jtb3J0W2pdLmNvcl9tb3J0KWJbaV1bMl1bbl09IlNVUkZBQ0UiZW5kO2ZvciBCLHUgaW4gcGFpcnN7ImxlZ2thcmsiLCJsZWdhbXBoIiwibGVnc2hvdCJ9ZG8gaWYgdCh1KXRoZW4gdyhiKWxvY2FsIGFiPTEvYi5kYW1hZ2Vtb2RpZmllcjtsb2NhbCBhYz1kLnJlYWN0aXZlX2FybW9yX2hlYWx0aDtkLnJlYWN0aXZlX2FybW9yX2hlYWx0aD1uaWw7ZC5yZWFjdGl2ZV9hcm1vcl9yZXN0b3JlPW5pbDtsb2NhbCBhZD1hYyooMC41K21hdGguc3FydChhYyphYi9iLmhlYWx0aCkqKGFiLTEpKWIuaGVhbHRoPWIuaGVhbHRoK2FkIGVuZCBlbmQ7Zm9yIHUsWSBpbiBwYWlyc3tsZWdoaXZlPSJwbGFzbWEiLGxlZ2ZoaXZlPSJwbGFzbWEiLGxlZ3NwY2Fycmllcj0ibGVnX2Ryb25lX2NvbnRyb2xsZXIiLGxlZ3ZjYXJyeT0idGFyZ2V0aW5nIixsZWdhbmF2eWFudGludWtlY2Fycmllcj0ibGVnX2Ryb25lX2NvbnRyb2xsZXIifWRvIGlmIHQodSlhbmQgdihZKXRoZW4gUygwLjc1KWU9YltpXVsxXWVbbl09IlZUT0wiZVtvXT0iTElHSFRBSVJTQ09VVCJjLnJhbmdlPTE2MDA7ZT1hLmFybWZpZztBKHcoYyksayxsKWQuY2FycmllZF91bml0PSJsZWdmaWciZC5jb250cm9scmFkaXVzPTE2MDAgZW5kIGVuZDtpZiB0KCJsZWdsb2IiKXRoZW4gYltpXVsyXT1uaWwgZW5kO2ZvciB1LFkgaW4gcGFpcnN7bGVnbWc9ImFybW1nX3dlYXBvbiIsbGVnZm1nPSJnYXRsaW5nX2d1biJ9ZG8gaWYgdCh1KWFuZCB2KFkpdGhlbiBiLmNhbnRiZXRyYW5zcG9ydGVkPXRydWU7Yy5yYW5nZT02MjU7Yy5hY2N1cmFjeT0xMDA7Yy5zcHJheWFuZ2xlPTg4MDtTKDEuMDcpZW5kIGVuZDtpZiB0KCJsZWdmbG9hdCIpdGhlbiBiLm1vdmVtZW50Y2xhc3M9Ik1UQU5LMyJiLndhdGVybGluZT1uaWw7Yi5mbG9hdGVyPW5pbCBlbmQ7aWYgdCgibGVnbmF2eWZyaWdhdGUiKXRoZW4gYltpXVsxXVtuXT0iTk9UU1VCImJbaV1bMl09bmlsO1MoMC44NSllbmQ7aWYgdCgibGVnbmF2eWRlc3RybyIpdGhlbiBlPWEubGVnbmF2eWFydHlzaGlwO0EoYiwiYnVpbGRwaWMiLCJjb2xsaXNpb252b2x1bWVvZmZzZXRzIiwiY29sbGlzaW9udm9sdW1lc2NhbGVzIiwiY29sbGlzaW9udm9sdW1ldHlwZSIsIm9iamVjdG5hbWUiLCJzY3JpcHQiKXkoImRlcHRoY2hhcmdlIixhLmNvcnJveVtqXS5kZXB0aGNoYXJnZSliW2ldWzJdPXRhYmxlLmNvcHkoYS5jb3Jyb3lbaV1bMl0pYltqXS5kcm9uZV9jb250cm9sX21hdHJpeD1uaWw7UygxLjA4KWVuZDtpZiB0KCJsZWdhbmF2eWJhdHRsZXNoaXAiKXRoZW4gYi5tb3ZlbWVudGNsYXNzPSJCT0FUOSJTKDAuODgpZW5kO2lmIHQoImxlZ2FwIil0aGVuIHRhYmxlLmluc2VydChiLmJ1aWxkb3B0aW9ucywiY29yZmluayIpZW5kO2EubGVna2FtPXRhYmxlLmNvcHkoYS5hcm10aHVuZClhLmxlZ3Bob2VuaXg9bmlsO2lmIHQoImxlZ21pbmViIil0aGVuIHkoImNvcl9zZWFhZHZib21iIixhLmNvcmh1cmNbal0uY29yYWR2Ym9tYilTKDAuOTQpZW5kO2lmIHQoImxlZ3JhbXBhcnQiKXRoZW4gYi5yYWRhcmRpc3RhbmNlamFtPW5pbDtiW2ldWzJdPW5pbDtTKDAuOSllbmQ7YS5sZWdlbHJwY21lY2g9bmlsO2lmIHQoImxlZ2VhbGx0ZXJyYWlubWVjaCIpdGhlbiBiW2ldWzVdPW5pbDtTKDAuOSllbmQ7YS5sZWdzdGFyZmFsbD10YWJsZS5jb3B5KGEuYXJtdnVsYyk

