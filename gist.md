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
	for _, property in ipairs({ ... }) do
		def[property] = ref[property]
	end
end

local function neat(value, precision)
	value = precision and value / precision or 1
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
		weaponDef.name = "Heavy Laser"
		copyref(weaponDef, "weapontype", "beamtime", "impulsefactor", "noexplode",
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
ref = UD.armpw
for name, wname in pairs { legscout = "gun", leggob = "semiauto", legstr = "armmg_weapon", legmg = "armmg_weapon", legfmg = "gatling_gun", legapopupdef = "standard_minigun", leganavaldefturret = "legion_heavy_minigun", leganavycruiser = "mg_guns", legnavyscout = "mg_guns", legjav = "mg_guns", legkeres = "legkeres_gatling", legfloat = "legfloat_gatling", leggat = "armmg_weapon", legfort = "semiauto" } do
	if unit(name) and weapon(wname) then
		copyref(weaponDef, edgeeffectiveness, explosiongenerator, "gravityaffected", "intensity", "rgbcolor", "size", "soundstart", "weapontype")
		set(weaponDef, weaponvelocity, 0.6154)
		set(weaponDef, "ownerExpAccWeight", 0.5)
		damages(1.0833)
		costs(1.01)
	end
end

-- Burst plasma
ref = UD.correap[weapondefs].cor_reap
for name, wname in pairs { legcen = "gauss", legaskirmtank = "legmgplasma", legmrv = "quickshot_cannon", leganavybattleship = "burst_plasma_t2", } do
	if unit(name) and weapon(wname) then
		weaponDef.name = "Medium Plasma Cannon"
		weaponDef.impactonly = false
		local burst, base = weaponDef.burst, weaponDef.damage.default
		weaponDef.burst = nil
		copyref(weaponDef, "impactonly", "impulsefactor", weaponvelocity, edgeeffectiveness)
		damages(burst)
		local t = math.clamp((weaponDef.damage.default - base) / (ref.damage.default - base), 0, 1 + burst / 3)
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
	weaponDef = copyweapon("emp", UD.armstil.weapondefs)
	weaponDef[areaofeffect] = 120
	weaponDef.paralyzetime = 10
	weaponDef.range = unitDef.speed * 3
	weaponDef.reloadtime = 10
	damages(1 / 15)
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

if unit("legfig") then
	ref = UD.armfig
	copyref(unitDef, buildtime, energycost, metalcost, "speed", "turnradius")
	copyweapon("semiauto", ref[weapondefs].armvtol_missile)
	unitDef[weapons][1].maxangledif = nil
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

> bG9jYWwgYT1Vbml0RGVmcztsb2NhbCBiLGMsZCxlO2xvY2FsIGYsZyxoPXsyLDQsNSw4LDEyLDIwLDUwLDEyNSwyNTB9LDYwLDMwO2xvY2FsIGksaixrLGwsbSxuLG8scCxxLHIscz0id2VhcG9ucyIsIndlYXBvbmRlZnMiLCJtZXRhbGNvc3QiLCJlbmVyZ3ljb3N0IiwiYnVpbGR0aW1lIiwib25seXRhcmdldGNhdGVnb3J5IiwiYmFkdGFyZ2V0Y2F0ZWdvcnkiLCJhcmVhb2ZlZmZlY3QiLCJlZGdlZWZmZWN0aXZlbmVzcyIsImV4cGxvc2lvbmdlbmVyYXRvciIsIndlYXBvbnZlbG9jaXR5ImxvY2FsIGZ1bmN0aW9uIHQodSliPWFbdV1yZXR1cm4gYiBlbmQ7bG9jYWwgZnVuY3Rpb24gdih1KWM9YltqXVt1XXJldHVybiBjIGVuZDtsb2NhbCBmdW5jdGlvbiB3KHgpZD14LmN1c3RvbXBhcmFtcyBvcnt9eC5jdXN0b21wYXJhbXM9ZDtyZXR1cm4gZCBlbmQ7bG9jYWwgZnVuY3Rpb24geSh1LHgpbG9jYWwgej10YWJsZS5jb3B5KHggb3IgZSliW2pdW3VdPXo7cmV0dXJuIHogZW5kO2xvY2FsIGZ1bmN0aW9uIEEoeCwuLi4pZm9yIEIsQyBpbiBpcGFpcnMoey4uLn0pZG8geFtDXT1lW0NdZW5kIGVuZDtsb2NhbCBmdW5jdGlvbiBEKEUsRilFPUYgYW5kIEUvRiBvciAxO2lmIEU8PTMwIHRoZW4gcmV0dXJuIG1hdGguZmxvb3IoRSswLjUpKkYgZW5kO2xvY2FsIEc9e31mb3IgQixIIGluIGlwYWlycyhmKWRvIEdbSF09bWF0aC5mbG9vcihFL0grMC41KSpIIGVuZDtsb2NhbCBJPUdbZlsxXV1sb2NhbCBKPUktRTtKPUoqSi9mWzFdZm9yIEs9MiwjZiBkbyBsb2NhbCBMPWZbS11sb2NhbCBNPShHW0xdLUUpXjIvZlsxXWlmIEo-TSB0aGVuIEk9R1tMXUo9TSBlbmQgZW5kO3JldHVybiBJKkYgZW5kO2xvY2FsIGZ1bmN0aW9uIE4oTyxQLFEsUixGKWxvY2FsIEU9dG9udW1iZXIoT1tQXSlPW1BdPUUgYW5kIEQoRSooUSBvciAxKSsoUiBvciAwKSxGKW9yIG5pbCBlbmQ7bG9jYWwgZnVuY3Rpb24gUyhRLFQsVSxWKVQ9VCBvciAwO1U9VSBvciBUKigoYltrXW9yIDApPjAgYW5kIGJbbF0vYltrXW9yIGcpVj1WIG9yIFQqKChiW2tdb3IgMCk-MCBhbmQgYlttXS9iW2tdb3IgaClOKGIsayxRLFQsMTApTihiLGwsUSxVLDEwKU4oYixtLFEsViwxMCllbmQ7bG9jYWwgZnVuY3Rpb24gVyhRLFIpZm9yIFggaW4gcGFpcnMoYy5kYW1hZ2UpZG8gTihjLmRhbWFnZSxYLFEsUillbmQ7cmV0dXJuIGMuZGFtYWdlIGVuZDtlPXQoImxlZ2NvbSIpW2ldZVsxXVtuXT0iTk9UU1VCImVbMV0uZmFzdGF1dG9yZXRhcmdldGluZz10cnVlO2VbNF09bmlsO2U9YS5hcm1jb21bal15KCJsZWdjb21sYXNlciIsZS5hcm1jb21sYXNlcil5KCJ0b3JwZWRvIixlLmFybWNvbXNlYWxhc2VyKWlmIHQoImxlZ21leCIpdGhlbiBiLmV4dHJhY3RzbWV0YWw9MC4wMDE7Yi5lbmVyZ3l1cGtlZXA9MyBlbmQ7Zm9yIEIsdSBpbiBwYWlyc3sibGVna2FyayIsImxlZ2dhdCJ9ZG8gaWYgdCh1KXRoZW4gUygwLjkpTihiLCJoZWFsdGgiLDAuOSlOKGIsInNwZWVkIiwxLjA3KWZvciBZIGluIHBhaXJzKGJbal0pZG8gdihZKVcoMC45MillbmQgZW5kIGVuZDtsb2NhbCBmdW5jdGlvbiBaKF8pbG9jYWwgYTA9bWF0aC5zcXJ0KFcoKS5kZWZhdWx0L2UuZGFtYWdlLmRlZmF1bHQpKihfIG9yIDEpKzAuNS0oXyBvciAxKSowLjU7YTA9YTAvKChjLmJlYW10aW1lIG9yIDEvMzApKjMwKU4oYywiY29yZXRoaWNrbmVzcyIsYTApTihjLCJ0aGlja25lc3MiLGEwKU4oYywibGFzZXJmbGFyZXNpemUiLGEwKjAuMSswLjkpZW5kO2xvY2FsIGZ1bmN0aW9uIGExKHUsWSlpZiB0KHUpYW5kIHYoWSl0aGVuIGlmIGNbcF0-PTQwIGFuZCBub3QgYy5pbXBhY3Rvbmx5IHRoZW4gUygwLjk1KWVuZDtBKGMsImltcGFjdG9ubHkiLHAsImNvcmV0aGlja25lc3MiLHIsImludGVuc2l0eSIsImxhc2VyZmxhcmVzaXplIiwicmdiY29sb3IiLCJ0aGlja25lc3MiLCJzaXplIiwic291bmRoaXRkcnkiLCJzb3VuZGhpdHdldCIpWigpZW5kIGVuZDtlPWEuYXJtbGx0W2pdLmFybV9saWdodGxhc2VyO2ZvciB1LFkgaW4gcGFpcnN7bGVnaW5mZXN0b3I9ImZlc3RvcmJlYW0iLGxlZ2xodD0iaGVhdF9yYXkiLGxlZ3NoPSJoZWF0X3JheSIsbGVnaGVsaW9zPSJoZWF0X3JheSJ9ZG8gYTEodSxZKWVuZDtlPWEuYXJtYmVhbWVyW2pdLmFybWJlYW1lcl93ZWFwb247Zm9yIHUsWSBpbiBwYWlyc3tsZWdoZWF2eWRyb25lPSJoZWF0X3JheSIsbGVnaW5jPSJoZWF0cmF5bGFyZ2UiLGxlZ2thcms9ImhlYXRfcmF5IixsZWdiYXN0aW9uPSJ0MmhlYXRyYXkiLGxlZ2FuYXZ5ZmxhZ3NoaXA9ImxlZ19leHBlcmltZW50YWxfaGVhdHJheSIsbGVnbmF2eWRlc3Rybz0ibGVnX21lZGl1bV9oZWF0cmF5IixsZWdlaGVhdHJheW1lY2g9ImhlYXRyYXkxIixsZWdlaG92ZXJ0YW5rPSJoZWF0X3JheSIsbGVnYWhlYXR0YW5rPSJoZWF0X3JheSJ9ZG8gYTEodSxZKWVuZDtlPWEuY29yaGx0W2pdLmNvcl9sYXNlcmgxO2ZvciB1LFkgaW4gcGFpcnN7bGVncmFpbD0icmFpbGd1biIsbGVnc3JhaWw9InJhaWxndW50MiIsbGVnYW5hdnlmbGFnc2hpcD0ibGVnX2V4cGVyaW1lbnRhbF9yYWlsZ3VuIixsZWdlcmFpbHRhbms9InQzX3JhaWxfYWNjZWxlcmF0b3IifWRvIGlmIHQodSlhbmQgdihZKXRoZW4gdyhjKWMubmFtZT0iSGVhdnkgTGFzZXIiQShjLCJ3ZWFwb250eXBlIiwiYmVhbXRpbWUiLCJpbXB1bHNlZmFjdG9yIiwibm9leHBsb2RlIiwiY29yZXRoaWNrbmVzcyIsciwiaW50ZW5zaXR5IiwibGFzZXJmbGFyZXNpemUiLCJyZ2Jjb2xvciIsInRoaWNrbmVzcyIsInNpemUiLCJjZWd0YWciLCJzb3VuZGhpdGRyeSIsInNvdW5kaGl0d2V0Iiwic291bmRzdGFydCIsImN5bGluZGVydGFyZ2V0aW5nIiwiaW1wYWN0b25seSIsInByZWRpY3Rib29zdCIpY1tzXT1jLnJhbmdlKzEwMDtkLm92ZXJwZW5ldHJhdGU9bmlsO1coMS4zKVooMC42NjY3KWVuZCBlbmQ7Zm9yIHUsWSBpbiBwYWlyc3tsZWdyYWlsPSJhYV9yYWlsZ3VuIixsZWdhZHZhYWJvdD0iYWFfcmFpbGd1biJ9ZG8gaWYgdCh1KWFuZCB2KFkpdGhlbiBsb2NhbCBhMixhMyxhND1jLnJhbmdlLGMuZGFtYWdlLnZ0b2wsYy5yZWxvYWR0aW1lO2M9eShZLGEuYXJtYWFrW2pdLmxvbmdyYW5nZW1pc3NpbGUpYy5yYW5nZT1hMjtjLmRhbWFnZS52dG9sPWEzO2MucmVsb2FkdGltZT1hNCBlbmQgZW5kO2U9YS5hcm1wdztmb3IgdSxZIGluIHBhaXJze2xlZ3Njb3V0PSJndW4iLGxlZ2dvYj0ic2VtaWF1dG8iLGxlZ3N0cj0iYXJtbWdfd2VhcG9uIixsZWdtZz0iYXJtbWdfd2VhcG9uIixsZWdmbWc9ImdhdGxpbmdfZ3VuIixsZWdhcG9wdXBkZWY9InN0YW5kYXJkX21pbmlndW4iLGxlZ2FuYXZhbGRlZnR1cnJldD0ibGVnaW9uX2hlYXZ5X21pbmlndW4iLGxlZ2FuYXZ5Y3J1aXNlcj0ibWdfZ3VucyIsbGVnbmF2eXNjb3V0PSJtZ19ndW5zIixsZWdqYXY9Im1nX2d1bnMiLGxlZ2tlcmVzPSJsZWdrZXJlc19nYXRsaW5nIixsZWdmbG9hdD0ibGVnZmxvYXRfZ2F0bGluZyIsbGVnZ2F0PSJhcm1tZ193ZWFwb24iLGxlZ2ZvcnQ9InNlbWlhdXRvIn1kbyBpZiB0KHUpYW5kIHYoWSl0aGVuIEEoYyxxLHIsImdyYXZpdHlhZmZlY3RlZCIsImludGVuc2l0eSIsInJnYmNvbG9yIiwic2l6ZSIsInNvdW5kc3RhcnQiLCJ3ZWFwb250eXBlIilOKGMscywwLjYxNTQpTihjLCJvd25lckV4cEFjY1dlaWdodCIsMC41KVcoMS4wODMzKVMoMS4wMSllbmQgZW5kO2U9YS5jb3JyZWFwW2pdLmNvcl9yZWFwO2ZvciB1LFkgaW4gcGFpcnN7bGVnY2VuPSJnYXVzcyIsbGVnYXNraXJtdGFuaz0ibGVnbWdwbGFzbWEiLGxlZ21ydj0icXVpY2tzaG90X2Nhbm5vbiIsbGVnYW5hdnliYXR0bGVzaGlwPSJidXJzdF9wbGFzbWFfdDIifWRvIGlmIHQodSlhbmQgdihZKXRoZW4gYy5uYW1lPSJNZWRpdW0gUGxhc21hIENhbm5vbiJjLmltcGFjdG9ubHk9ZmFsc2U7bG9jYWwgYTUsYTY9Yy5idXJzdCxjLmRhbWFnZS5kZWZhdWx0O2MuYnVyc3Q9bmlsO0EoYywiaW1wYWN0b25seSIsImltcHVsc2VmYWN0b3IiLHMscSlXKGE1KWxvY2FsIGE3PW1hdGguY2xhbXAoKGMuZGFtYWdlLmRlZmF1bHQtYTYpLyhlLmRhbWFnZS5kZWZhdWx0LWE2KSwwLDErYTUvMyljW3BdPW1hdGgubWl4KGNbcF0sZVtwXSxhNyllbmQgZW5kO2xvY2FsIGZ1bmN0aW9uIGE4KHUsWSxhOSlpZiB0KHUpYW5kIHYoWSl0aGVuIGU9YS5hcm1hbWJbal0uYXJtYW1iX2d1bjtBKGMsImNlZ3RhZyIscilsb2NhbCBhYT13KGMpLmNsdXN0ZXJfbnVtYmVyIG9yIDU7VygxK21hdGguc3FydChhYSp2KGE5IG9yImNsdXN0ZXJfbXVuaXRpb24iKS5kYW1hZ2UuZGVmYXVsdC92KFkpLmRhbWFnZS5kZWZhdWx0KSlkLmNsdXN0ZXJfZGVmLGQuY2x1c3Rlcl9udW1iZXI9bmlsLG5pbCBlbmQgZW5kO2ZvciB1LFkgaW4gcGFpcnN7bGVnYW1jbHVzdGVyPSJjbHVzdGVyX2FydGlsbGVyeSIsbGVnY2x1c3Rlcj0icGxhc21hIixsZWdhY2x1c3Rlcj0icGxhc21hIixsZWdscnBjPSJscnBjIixsZWdlYWxsdGVycmFpbm1lY2g9InBsYXNtYV9sb3cifWRvIGE4KHUsWSllbmQ7Zm9yIHUsWSBpbiBwYWlyc3tsZWdjbHVzdGVyPSJwbGFzbWFfaGlnaCIsbGVnYWNsdXN0ZXI9InBsYXNtYV9oaWdoIixsZWdlYWxsdGVycmFpbm1lY2g9InBsYXNtYV9oaWdoIn1kbyBhOCh1LFkpZW5kO2E4KCJsZWdhbmF2eWFydHlzaGlwIiwibGVnX21vYmlsZV9jbHVzdGVyX2xycGNfY2Fubm9uIiwiY2x1c3Rlcl9tdW5pdGlvbl9tYWluIilhOCgibGVnYW5hdnlhcnR5c2hpcCIsImxlZ19tb2JpbGVfY2x1c3Rlcl9wbGFzbWEiLCJjbHVzdGVyX211bml0aW9uX3NlY29uZGFyeSIpaWYgdCgibGVnYmFyIil0aGVuIGIuc3BlZWQ9NDk7Yz15KCJjbHVzdGVybmFwYWxtIixhLmxlZ2Vob3ZlcnRhbmtbal0ucGFyYWJvbGljX3JvY2tldHMpY1twXT01NjtjW3FdPTAuMjU7Y1tyXT0iY3VzdG9tOmdlbmVyaWNzaGVsbGV4cGxvc2lvbi1zbWFsbC1ib21iImMuYnVyc3Q9MztjLmJ1cnN0cmF0ZT0wLjQ7Yy5yYW5nZT02MTA7Y1tzXT0yNjAgZW5kO2lmIHQoImxlZ2JhcnQiKXRoZW4geSgiY2x1c3Rlcm5hcGFsbSIsYS5hcm1maWRvW2pdLmJmaWRvKVMoMC44NSllbmQ7aWYgdCgibGVnaW5mIil0aGVuIGM9eSgicmFwaWRuYXBhbG0iLGEuY29ydHJlbVtqXS50cmVtb3Jfc3ByZWFkX2ZpcmUpYy5idXJzdD0zO2MuYnVyc3RyYXRlPTAuMzMzMztjLnJlbG9hZHRpbWU9MjtjLm15Z3Jhdml0eT0wLjE4O2MucmFuZ2U9MTIwMDtjW3NdPTQ2MCBlbmQ7aWYgdCgibGVncGVyZGl0aW9uIil0aGVuIHkoIm5hcGFsbW1pc3NpbGUiLGEuY29ydHJvbltqXS5jb3J0cm9uX3dlYXBvbillbmQ7aWYgdCgibGVnbWVkIil0aGVuIHkoImxhc2VyIixhLmNvcmFrW2pdLmdhdG9yX2xhc2VyKWJbaV1bMV1bb109IlZUT0wiYltpXVsyXVtvXT0iVlRPTCJiW2ldWzJdLnNsYXZldG89bmlsO3YoImxlZ21lZF9taXNzaWxlIikuY3VzdG9tcGFyYW1zPXtwcm9qZWN0aWxlX2Rlc3RydWN0aW9uX21ldGhvZD0iZGVzY2VuZCIsb3ZlcnJhbmdlX2Rpc3RhbmNlPTEwOTN9ZT1jO3YoImxhc2VyIikucmFuZ2U9ZS5yYW5nZSBlbmQ7aWYgdCgibGVnY2liIil0aGVuIGJbaV1bMV0uZGVmPSJlbXAiYz15KCJlbXAiLGEuYXJtc3RpbC53ZWFwb25kZWZzKWNbcF09MTIwO2MucGFyYWx5emV0aW1lPTEwO2MucmFuZ2U9Yi5zcGVlZCozO2MucmVsb2FkdGltZT0xMDtXKDEvMTUpZW5kO2lmIHQoImxlZ2FtcGgiKXRoZW4geSgiaGVhdF9yYXkiLGEuY29ybWF3W2pdLmRtYXcpeSgiY29heF9kZXB0aGNoYXJnZSIsYS5jb3Jtb3J0W2pdLmNvcl9tb3J0KWJbaV1bMl1bbl09IlNVUkZBQ0UiZW5kO2ZvciBCLHUgaW4gcGFpcnN7ImxlZ2thcmsiLCJsZWdhbXBoIiwibGVnc2hvdCJ9ZG8gaWYgdCh1KXRoZW4gdyhiKWxvY2FsIGFiPTEvYi5kYW1hZ2Vtb2RpZmllcjtsb2NhbCBhYz1kLnJlYWN0aXZlX2FybW9yX2hlYWx0aDtkLnJlYWN0aXZlX2FybW9yX2hlYWx0aD1uaWw7ZC5yZWFjdGl2ZV9hcm1vcl9yZXN0b3JlPW5pbDtsb2NhbCBhZD1hYyooMC41K21hdGguc3FydChhYyphYi9iLmhlYWx0aCkqKGFiLTEpKWIuaGVhbHRoPWIuaGVhbHRoK2FkIGVuZCBlbmQ7Zm9yIHUsWSBpbiBwYWlyc3tsZWdoaXZlPSJwbGFzbWEiLGxlZ2ZoaXZlPSJwbGFzbWEiLGxlZ3NwY2Fycmllcj0ibGVnX2Ryb25lX2NvbnRyb2xsZXIiLGxlZ3ZjYXJyeT0idGFyZ2V0aW5nIixsZWdhbmF2eWFudGludWtlY2Fycmllcj0ibGVnX2Ryb25lX2NvbnRyb2xsZXIifWRvIGlmIHQodSlhbmQgdihZKXRoZW4gUygwLjc1KWU9YltpXVsxXWVbbl09IlZUT0wiZVtvXT0iTElHSFRBSVJTQ09VVCJjLnJhbmdlPTE2MDA7ZT1hLmFybWZpZztBKHcoYyksayxsKWQuY2FycmllZF91bml0PSJsZWdmaWciZC5jb250cm9scmFkaXVzPTE2MDAgZW5kIGVuZDtpZiB0KCJsZWdsb2IiKXRoZW4gYltpXVsyXT1uaWwgZW5kO2ZvciB1LFkgaW4gcGFpcnN7bGVnbWc9ImFybW1nX3dlYXBvbiIsbGVnZm1nPSJnYXRsaW5nX2d1biJ9ZG8gaWYgdCh1KWFuZCB2KFkpdGhlbiBiLmNhbnRiZXRyYW5zcG9ydGVkPXRydWU7Yy5yYW5nZT02MjU7Yy5hY2N1cmFjeT0xMDA7Yy5zcHJheWFuZ2xlPTg4MDtTKDEuMDcpZW5kIGVuZDtpZiB0KCJsZWdmbG9hdCIpdGhlbiBiLm1vdmVtZW50Y2xhc3M9Ik1UQU5LMyJiLndhdGVybGluZT1uaWw7Yi5mbG9hdGVyPW5pbCBlbmQ7aWYgdCgibGVnbmF2eWZyaWdhdGUiKXRoZW4gYltpXVsxXVtuXT0iTk9UU1VCImJbaV1bMl09bmlsO1MoMC44NSllbmQ7aWYgdCgibGVnbmF2eWRlc3RybyIpdGhlbiBlPWEubGVnbmF2eWFydHlzaGlwO0EoYiwiYnVpbGRwaWMiLCJjb2xsaXNpb252b2x1bWVvZmZzZXRzIiwiY29sbGlzaW9udm9sdW1lc2NhbGVzIiwiY29sbGlzaW9udm9sdW1ldHlwZSIsIm9iamVjdG5hbWUiLCJzY3JpcHQiKXkoImRlcHRoY2hhcmdlIixhLmNvcnJveVtqXS5kZXB0aGNoYXJnZSliW2ldWzJdPXRhYmxlLmNvcHkoYS5jb3Jyb3lbaV1bMl0pYltqXS5kcm9uZV9jb250cm9sX21hdHJpeD1uaWw7UygxLjA4KWVuZDtpZiB0KCJsZWdhbmF2eWJhdHRsZXNoaXAiKXRoZW4gYi5tb3ZlbWVudGNsYXNzPSJCT0FUOSJTKDAuODgpZW5kO2lmIHQoImxlZ2FwIil0aGVuIHRhYmxlLmluc2VydChiLmJ1aWxkb3B0aW9ucywiY29yZmluayIpZW5kO2lmIHQoImxlZ2ZpZyIpdGhlbiBlPWEuYXJtZmlnO0EoYixtLGwsaywic3BlZWQiLCJ0dXJucmFkaXVzIil5KCJzZW1pYXV0byIsZVtqXS5hcm12dG9sX21pc3NpbGUpYltpXVsxXS5tYXhhbmdsZWRpZj1uaWwgZW5kO2EubGVna2FtPXRhYmxlLmNvcHkoYS5hcm10aHVuZClhLmxlZ3Bob2VuaXg9bmlsO2lmIHQoImxlZ21pbmViIil0aGVuIHkoImNvcl9zZWFhZHZib21iIixhLmNvcmh1cmNbal0uY29yYWR2Ym9tYilTKDAuOTQpZW5kO2lmIHQoImxlZ3JhbXBhcnQiKXRoZW4gYi5yYWRhcmRpc3RhbmNlamFtPW5pbDtiW2ldWzJdPW5pbDtTKDAuOSllbmQ7YS5sZWdlbHJwY21lY2g9bmlsO2lmIHQoImxlZ2VhbGx0ZXJyYWlubWVjaCIpdGhlbiBiW2ldWzVdPW5pbDtTKDAuOSllbmQ7YS5sZWdzdGFyZmFsbD10YWJsZS5jb3B5KGEuYXJtdnVsYyk

