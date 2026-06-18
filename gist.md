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

local function copy(value)
	if type(value) == "table" then
		return table.copy(value)
	else
		return value
	end
end

local function copyweapon(name, def)
	local new = copy(def or ref)
	unitDef[weapondefs][name] = new
	return new
end

local function copyref(def, ...)
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
	local scale = (damages().default / ref.damage.default) ^ 0.4 * (grav or 1) + (0.5 - (grav or 1) * 0.5)
	scale = scale / ((weaponDef.beamtime or (1/30)) * 30) ^ 0.4
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
		local dps, range = weaponDef.damage.vtol * (weaponDef.burst or 1) / weaponDef.reloadtime, weaponDef.range
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
		copyref(weaponDef, "weapontype", "name", "accuracy", "sprayangle", "burstrate", "duration", explosiongenerator, "impulsefactor", "intensity", "soundhit", "soundhitwet", "soundstart", "thickness", "customparams")
		weaponDef.burst = weaponDef.projectiles * (weaponDef.burst or 1)
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
	unitDef[weapons][2] = copy(UD.corroy[weapons][2])
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

UD.legkam = copy(UD.armthund)

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

UD.legstarfall = copy(UD.armvulc)
```

## Tweakunits

<!-- tweakunits_readable -->

## Tweakdefs encoded (URL-safe base64)

> bG9jYWwgYT1Vbml0RGVmcztsb2NhbCBiLGMsZCxlO2xvY2FsIGYsZyxoPXsyLDQsNSw4LDEyLDIwLDUwLDEyNSwyNTB9LDYwLDMwO2xvY2FsIGksaixrLGwsbSxuLG8scCxxLHIscz0id2VhcG9ucyIsIndlYXBvbmRlZnMiLCJtZXRhbGNvc3QiLCJlbmVyZ3ljb3N0IiwiYnVpbGR0aW1lIiwib25seXRhcmdldGNhdGVnb3J5IiwiYmFkdGFyZ2V0Y2F0ZWdvcnkiLCJhcmVhb2ZlZmZlY3QiLCJlZGdlZWZmZWN0aXZlbmVzcyIsImV4cGxvc2lvbmdlbmVyYXRvciIsIndlYXBvbnZlbG9jaXR5ImxvY2FsIGZ1bmN0aW9uIHQodSliPWFbdV1yZXR1cm4gYiBlbmQ7bG9jYWwgZnVuY3Rpb24gdih1KWM9YltqXVt1XXJldHVybiBjIGVuZDtsb2NhbCBmdW5jdGlvbiB3KHgpZD14LmN1c3RvbXBhcmFtcyBvcnt9eC5jdXN0b21wYXJhbXM9ZDtyZXR1cm4gZCBlbmQ7bG9jYWwgZnVuY3Rpb24geSh6KWlmIHR5cGUoeik9PSJ0YWJsZSJ0aGVuIHJldHVybiB0YWJsZS5jb3B5KHopZWxzZSByZXR1cm4geiBlbmQgZW5kO2xvY2FsIGZ1bmN0aW9uIEEodSx4KWxvY2FsIEI9eSh4IG9yIGUpYltqXVt1XT1CO3JldHVybiBCIGVuZDtsb2NhbCBmdW5jdGlvbiBDKHgsLi4uKWZvciBELEUgaW4gaXBhaXJzKHsuLi59KWRvIHhbRV09ZVtFXWVuZCBlbmQ7bG9jYWwgZnVuY3Rpb24gRih6LEcpRz1HIG9yIDE7ej16L0c7aWYgejw9MzAgdGhlbiByZXR1cm4gbWF0aC5mbG9vcih6KzAuNSkqRyBlbmQ7bG9jYWwgSD17fWZvciBELEkgaW4gaXBhaXJzKGYpZG8gSFtJXT1tYXRoLmZsb29yKHovSSswLjUpKkkgZW5kO2xvY2FsIEo9SFtmWzFdXWxvY2FsIEs9Si16O0s9SypLL2ZbMV1mb3IgTD0yLCNmIGRvIGxvY2FsIE09ZltMXWxvY2FsIE49KEhbTV0teileMi9mWzFdaWYgSz5OIHRoZW4gSj1IW01dSz1OIGVuZCBlbmQ7cmV0dXJuIEoqRyBlbmQ7bG9jYWwgZnVuY3Rpb24gTyhQLFEsUixTLEcpbG9jYWwgej10b251bWJlcihQW1FdKVBbUV09eiBhbmQgRih6KihSIG9yIDEpKyhTIG9yIDApLEcpb3IgbmlsIGVuZDtsb2NhbCBmdW5jdGlvbiBUKFIsVSxWLFcpVT1VIG9yIDA7Vj1WIG9yIFUqKChiW2tdb3IgMCk-MCBhbmQgYltsXS9iW2tdb3IgZylXPVcgb3IgVSooKGJba11vciAwKT4wIGFuZCBiW21dL2Jba11vciBoKU8oYixrLFIsVSwxMClPKGIsbCxSLFYsMTApTyhiLG0sUixXLDEwKWVuZDtsb2NhbCBmdW5jdGlvbiBYKFIsUylmb3IgWSBpbiBwYWlycyhjLmRhbWFnZSlkbyBPKGMuZGFtYWdlLFksUixTKWVuZDtyZXR1cm4gYy5kYW1hZ2UgZW5kO2U9dCgibGVnY29tIilbaV1lWzFdW25dPSJOT1RTVUIiZVsxXS5mYXN0YXV0b3JldGFyZ2V0aW5nPXRydWU7ZVs0XT1uaWw7ZT1hLmFybWNvbVtqXUEoImxlZ2NvbWxhc2VyIixlLmFybWNvbWxhc2VyKUEoInRvcnBlZG8iLGUuYXJtY29tc2VhbGFzZXIpaWYgdCgibGVnbWV4Iil0aGVuIGIuZXh0cmFjdHNtZXRhbD0wLjAwMTtiLmVuZXJneXVwa2VlcD0zIGVuZDtmb3IgRCx1IGluIHBhaXJzeyJsZWdrYXJrIiwibGVnZ2F0In1kbyBpZiB0KHUpdGhlbiBUKDAuOSlPKGIsImhlYWx0aCIsMC45KU8oYiwic3BlZWQiLDEuMDcpZm9yIFogaW4gcGFpcnMoYltqXSlkbyB2KFopWCgwLjkyKWVuZCBlbmQgZW5kO2xvY2FsIGZ1bmN0aW9uIF8oYTApbG9jYWwgYTE9KFgoKS5kZWZhdWx0L2UuZGFtYWdlLmRlZmF1bHQpXjAuNCooYTAgb3IgMSkrMC41LShhMCBvciAxKSowLjU7YTE9YTEvKChjLmJlYW10aW1lIG9yIDEvMzApKjMwKV4wLjQ7TyhjLCJjb3JldGhpY2tuZXNzIixhMSlPKGMsInRoaWNrbmVzcyIsYTEpTyhjLCJsYXNlcmZsYXJlc2l6ZSIsYTEqMC4xKzAuOSllbmQ7bG9jYWwgZnVuY3Rpb24gYTIodSxaKWlmIHQodSlhbmQgdihaKXRoZW4gaWYgY1twXT49NDAgYW5kIG5vdCBjLmltcGFjdG9ubHkgdGhlbiBUKDAuOTUpZW5kO0MoYywiaW1wYWN0b25seSIscCwiY29yZXRoaWNrbmVzcyIsciwiaW50ZW5zaXR5IiwibGFzZXJmbGFyZXNpemUiLCJyZ2Jjb2xvciIsInRoaWNrbmVzcyIsInNpemUiLCJzb3VuZGhpdGRyeSIsInNvdW5kaGl0d2V0IilfKCllbmQgZW5kO2U9YS5hcm1sbHRbal0uYXJtX2xpZ2h0bGFzZXI7Zm9yIHUsWiBpbiBwYWlyc3tsZWdpbmZlc3Rvcj0iZmVzdG9yYmVhbSIsbGVnbGh0PSJoZWF0X3JheSIsbGVnc2g9ImhlYXRfcmF5IixsZWdoZWxpb3M9ImhlYXRfcmF5In1kbyBhMih1LFopZW5kO2U9YS5hcm1iZWFtZXJbal0uYXJtYmVhbWVyX3dlYXBvbjtmb3IgdSxaIGluIHBhaXJze2xlZ2hlYXZ5ZHJvbmU9ImhlYXRfcmF5IixsZWdpbmM9ImhlYXRyYXlsYXJnZSIsbGVna2Fyaz0iaGVhdF9yYXkiLGxlZ2Jhc3Rpb249InQyaGVhdHJheSIsbGVnYW5hdnlmbGFnc2hpcD0ibGVnX2V4cGVyaW1lbnRhbF9oZWF0cmF5IixsZWduYXZ5ZGVzdHJvPSJsZWdfbWVkaXVtX2hlYXRyYXkiLGxlZ2VoZWF0cmF5bWVjaD0iaGVhdHJheTEiLGxlZ2Vob3ZlcnRhbms9ImhlYXRfcmF5IixsZWdhaGVhdHRhbms9ImhlYXRfcmF5In1kbyBhMih1LFopZW5kO2U9YS5jb3JobHRbal0uY29yX2xhc2VyaDE7Zm9yIHUsWiBpbiBwYWlyc3tsZWdyYWlsPSJyYWlsZ3VuIixsZWdzcmFpbD0icmFpbGd1bnQyIixsZWdhbmF2eWZsYWdzaGlwPSJsZWdfZXhwZXJpbWVudGFsX3JhaWxndW4iLGxlZ2VyYWlsdGFuaz0idDNfcmFpbF9hY2NlbGVyYXRvciJ9ZG8gaWYgdCh1KWFuZCB2KFopdGhlbiB3KGMpQyhjLCJ3ZWFwb250eXBlIiwiYmVhbXRpbWUiLCJpbXB1bHNlZmFjdG9yIiwibm9leHBsb2RlIiwibmFtZSIsImNvcmV0aGlja25lc3MiLHIsImludGVuc2l0eSIsImxhc2VyZmxhcmVzaXplIiwicmdiY29sb3IiLCJ0aGlja25lc3MiLCJzaXplIiwiY2VndGFnIiwic291bmRoaXRkcnkiLCJzb3VuZGhpdHdldCIsInNvdW5kc3RhcnQiLCJjeWxpbmRlcnRhcmdldGluZyIsImltcGFjdG9ubHkiLCJwcmVkaWN0Ym9vc3QiKWNbc109Yy5yYW5nZSsxMDA7ZC5vdmVycGVuZXRyYXRlPW5pbDtYKDEuMylfKDAuNjY2NyllbmQgZW5kO2ZvciB1LFogaW4gcGFpcnN7bGVncmFpbD0iYWFfcmFpbGd1biIsbGVnYWR2YWFib3Q9ImFhX3JhaWxndW4ifWRvIGlmIHQodSlhbmQgdihaKXRoZW4gbG9jYWwgYTMsYTQsYTU9Yy5yYW5nZSxjLmRhbWFnZS52dG9sLGMucmVsb2FkdGltZTtjPUEoWixhLmFybWFha1tqXS5sb25ncmFuZ2VtaXNzaWxlKWMucmFuZ2U9YTM7Yy5kYW1hZ2UudnRvbD1hNDtjLnJlbG9hZHRpbWU9YTUgZW5kIGVuZDtlPWEuYXJtcHdbal0uZW1nO2ZvciB1LFogaW4gcGFpcnN7bGVnc2NvdXQ9Imd1biIsbGVnZ29iPSJzZW1pYXV0byIsbGVnc3RyPSJhcm1tZ193ZWFwb24iLGxlZ21nPSJhcm1tZ193ZWFwb24iLGxlZ2ZtZz0iZ2F0bGluZ19ndW4iLGxlZ2Fwb3B1cGRlZj0ic3RhbmRhcmRfbWluaWd1biIsbGVnYW5hdmFsZGVmdHVycmV0PSJsZWdpb25faGVhdnlfbWluaWd1biIsbGVnYW5hdnljcnVpc2VyPSJtZ19ndW5zIixsZWduYXZ5c2NvdXQ9Im1nX2d1bnMiLGxlZ2phdj0ibWdfZ3VucyIsbGVna2VyZXM9ImxlZ2tlcmVzX2dhdGxpbmciLGxlZ2Zsb2F0PSJsZWdmbG9hdF9nYXRsaW5nIixsZWdnYXQ9ImFybW1nX3dlYXBvbiIsbGVnZm9ydD0ic2VtaWF1dG8ifWRvIGlmIHQodSlhbmQgdihaKXRoZW4gQyhjLHEsciwiZ3Jhdml0eWFmZmVjdGVkIiwiaW50ZW5zaXR5IiwicmdiY29sb3IiLCJzaXplIiwic291bmRzdGFydCIsIndlYXBvbnR5cGUiKU8oYyxzLDAuNjE1NClPKGMsIm93bmVyRXhwQWNjV2VpZ2h0IiwwLjUpWCgxLjA4MzMpVCgxLjAxKWVuZCBlbmQ7ZT1hLmFybWZpZ1tqXS5hcm12dG9sX21pc3NpbGU7Zm9yIHUsWiBpbiBwYWlyc3tsZWdmaWc9InNlbWlhdXRvIixsZWdhZmlnZGVmPSJsZWdndW4ifWRvIGlmIHQodSlhbmQgdihaKXRoZW4gbG9jYWwgYTYsYTM9Yy5kYW1hZ2UudnRvbCooYy5idXJzdCBvciAxKS9jLnJlbG9hZHRpbWUsYy5yYW5nZTtjPUEoWixlKWMucmFuZ2U9YTM7WChhNi9lLmRhbWFnZS52dG9sKmUucmVsb2FkdGltZSliW2ldWzFdLm1heGFuZ2xlZGlmPW5pbCBlbmQgZW5kO2U9YS5hcm1jbGF3W2pdLmRjbGF3O2ZvciB1LFogaW4gcGFpcnN7bGVna2Fyaz0ibGVnaW9uX3Nob3RndW4iLGxlZ2Nhcj0ic2hvdCIsbGVnYW5hdnliYXR0bGVzaGlwPSJsZWdpb25fc2hvdGd1biIsbGVnZXNob3RndW5tZWNoPSJzaG90Z3VuIixsZWdzdHJvbmdob2xkPSJzaG90Z3VuIixsZWdhbmF2YWxkZWZ0dXJyZXQ9ImFkdmFuY2VkX3Nob3RndW4ifWRvIGlmIHQodSlhbmQgdihaKXRoZW4gQyhjLCJ3ZWFwb250eXBlIiwibmFtZSIsImFjY3VyYWN5Iiwic3ByYXlhbmdsZSIsImJ1cnN0cmF0ZSIsImR1cmF0aW9uIixyLCJpbXB1bHNlZmFjdG9yIiwiaW50ZW5zaXR5Iiwic291bmRoaXQiLCJzb3VuZGhpdHdldCIsInNvdW5kc3RhcnQiLCJ0aGlja25lc3MiLCJjdXN0b21wYXJhbXMiKWMuYnVyc3Q9Yy5wcm9qZWN0aWxlcyooYy5idXJzdCBvciAxKWMucHJvamVjdGlsZXM9bmlsO2Mud2VhcG9udmVsb2NpdHk9Yy5yYW5nZSsyMCBlbmQgZW5kO2U9YS5jb3JyZWFwW2pdLmNvcl9yZWFwO2ZvciB1LFogaW4gcGFpcnN7bGVnY2VuPSJnYXVzcyIsbGVnYXNraXJtdGFuaz0ibGVnbWdwbGFzbWEiLGxlZ21ydj0icXVpY2tzaG90X2Nhbm5vbiIsbGVnYW5hdnliYXR0bGVzaGlwPSJidXJzdF9wbGFzbWFfdDIifWRvIGlmIHQodSlhbmQgdihaKXRoZW4gbG9jYWwgYTc9Yy5idXJzdDtDKGMsdSwiaW1wYWN0b25seSIsImltcHVsc2VmYWN0b3IiLHMscSljLmJ1cnN0PW5pbDtjLmltcGFjdG9ubHk9bmlsO1goYTcpbG9jYWwgYTg9bWF0aC5jbGFtcChjLmRhbWFnZS5kZWZhdWx0KigxLTEvYTcpL2UuZGFtYWdlLmRlZmF1bHQsMCwxKyhhNy0xKS8xMCljW3BdPW1hdGgubWl4KGNbcF0sZVtwXSxhOCllbmQgZW5kO2xvY2FsIGZ1bmN0aW9uIGE5KHUsWixhYSlpZiB0KHUpYW5kIHYoWil0aGVuIGU9YS5hcm1hbWJbal0uYXJtYW1iX2d1bjtDKGMsImNlZ3RhZyIscilsb2NhbCBhYj13KGMpLmNsdXN0ZXJfbnVtYmVyIG9yIDU7WCgxK21hdGguc3FydChhYip2KGFhIG9yImNsdXN0ZXJfbXVuaXRpb24iKS5kYW1hZ2UuZGVmYXVsdC92KFopLmRhbWFnZS5kZWZhdWx0KSlkLmNsdXN0ZXJfZGVmLGQuY2x1c3Rlcl9udW1iZXI9bmlsLG5pbCBlbmQgZW5kO2ZvciB1LFogaW4gcGFpcnN7bGVnYW1jbHVzdGVyPSJjbHVzdGVyX2FydGlsbGVyeSIsbGVnY2x1c3Rlcj0icGxhc21hIixsZWdhY2x1c3Rlcj0icGxhc21hIixsZWdscnBjPSJscnBjIixsZWdlYWxsdGVycmFpbm1lY2g9InBsYXNtYV9sb3cifWRvIGE5KHUsWillbmQ7Zm9yIHUsWiBpbiBwYWlyc3tsZWdjbHVzdGVyPSJwbGFzbWFfaGlnaCIsbGVnYWNsdXN0ZXI9InBsYXNtYV9oaWdoIixsZWdlYWxsdGVycmFpbm1lY2g9InBsYXNtYV9oaWdoIn1kbyBhOSh1LFopZW5kO2E5KCJsZWdhbmF2eWFydHlzaGlwIiwibGVnX21vYmlsZV9jbHVzdGVyX2xycGNfY2Fubm9uIiwiY2x1c3Rlcl9tdW5pdGlvbl9tYWluIilhOSgibGVnYW5hdnlhcnR5c2hpcCIsImxlZ19tb2JpbGVfY2x1c3Rlcl9wbGFzbWEiLCJjbHVzdGVyX211bml0aW9uX3NlY29uZGFyeSIpaWYgdCgibGVnYmFyIil0aGVuIGIuc3BlZWQ9NDk7Yz1BKCJjbHVzdGVybmFwYWxtIixhLmxlZ2Vob3ZlcnRhbmtbal0ucGFyYWJvbGljX3JvY2tldHMpY1twXT01NjtjW3FdPTAuMjU7Y1tyXT0iY3VzdG9tOmdlbmVyaWNzaGVsbGV4cGxvc2lvbi1zbWFsbC1ib21iImMuYnVyc3Q9MztjLmJ1cnN0cmF0ZT0wLjQ7Yy5yYW5nZT02MTA7Y1tzXT0yNjAgZW5kO2lmIHQoImxlZ2JhcnQiKXRoZW4gQSgiY2x1c3Rlcm5hcGFsbSIsYS5hcm1maWRvW2pdLmJmaWRvKVQoMC44NSllbmQ7aWYgdCgibGVnaW5mIil0aGVuIGM9QSgicmFwaWRuYXBhbG0iLGEuY29ydHJlbVtqXS50cmVtb3Jfc3ByZWFkX2ZpcmUpYy5idXJzdD0zO2MuYnVyc3RyYXRlPTAuMzMzMztjLnJlbG9hZHRpbWU9MjtjLm15Z3Jhdml0eT0wLjE4O2MucmFuZ2U9MTIwMDtjW3NdPTQ2MCBlbmQ7aWYgdCgibGVncGVyZGl0aW9uIil0aGVuIEEoIm5hcGFsbW1pc3NpbGUiLGEuY29ydHJvbltqXS5jb3J0cm9uX3dlYXBvbillbmQ7aWYgdCgibGVnbWVkIil0aGVuIEEoImxhc2VyIixhLmNvcmFrW2pdLmdhdG9yX2xhc2VyKWJbaV1bMV1bb109IlZUT0wiYltpXVsyXVtvXT0iVlRPTCJiW2ldWzJdLnNsYXZldG89bmlsO3YoImxlZ21lZF9taXNzaWxlIikuY3VzdG9tcGFyYW1zPXtwcm9qZWN0aWxlX2Rlc3RydWN0aW9uX21ldGhvZD0iZGVzY2VuZCIsb3ZlcnJhbmdlX2Rpc3RhbmNlPTEwOTN9ZT1jO3YoImxhc2VyIikucmFuZ2U9ZS5yYW5nZSBlbmQ7aWYgdCgibGVnY2liIil0aGVuIGJbaV1bMV0uZGVmPSJlbXAiYz1BKCJlbXAiLGEuYXJtc3RpbC53ZWFwb25kZWZzLnN0aWxldHRvX2JvbWIpY1twXT0xMjA7Yy5wYXJhbHl6ZXRpbWU9MTA7Yy5yYW5nZT1iLnNwZWVkKjM7Yy5yZWxvYWR0aW1lPTEwO1goMC4xKWVuZDtpZiB0KCJsZWdhbXBoIil0aGVuIEEoImhlYXRfcmF5IixhLmNvcm1hd1tqXS5kbWF3KUEoImNvYXhfZGVwdGhjaGFyZ2UiLGEuY29ybW9ydFtqXS5jb3JfbW9ydCliW2ldWzJdW25dPSJTVVJGQUNFImVuZDtmb3IgRCx1IGluIHBhaXJzeyJsZWdrYXJrIiwibGVnYW1waCIsImxlZ3Nob3QifWRvIGlmIHQodSl0aGVuIHcoYilsb2NhbCBhYz0xL2IuZGFtYWdlbW9kaWZpZXI7bG9jYWwgYWQ9ZC5yZWFjdGl2ZV9hcm1vcl9oZWFsdGg7ZC5yZWFjdGl2ZV9hcm1vcl9oZWFsdGg9bmlsO2QucmVhY3RpdmVfYXJtb3JfcmVzdG9yZT1uaWw7bG9jYWwgYWU9YWQqKDAuNSttYXRoLnNxcnQoYWQqYWMvYi5oZWFsdGgpKihhYy0xKSliLmhlYWx0aD1iLmhlYWx0aCthZSBlbmQgZW5kO2ZvciB1LFogaW4gcGFpcnN7bGVnaGl2ZT0icGxhc21hIixsZWdmaGl2ZT0icGxhc21hIixsZWdzcGNhcnJpZXI9ImxlZ19kcm9uZV9jb250cm9sbGVyIixsZWd2Y2Fycnk9InRhcmdldGluZyIsbGVnYW5hdnlhbnRpbnVrZWNhcnJpZXI9ImxlZ19kcm9uZV9jb250cm9sbGVyIn1kbyBpZiB0KHUpYW5kIHYoWil0aGVuIFQoMC43NSllPWJbaV1bMV1lW25dPSJWVE9MImVbb109IkxJR0hUQUlSU0NPVVQiYy5yYW5nZT0xNjAwO2U9YS5hcm1maWc7Qyh3KGMpLGssbClkLmNhcnJpZWRfdW5pdD0ibGVnZmlnImQuY29udHJvbHJhZGl1cz0xNjAwIGVuZCBlbmQ7aWYgdCgibGVnbG9iIil0aGVuIGJbaV1bMl09bmlsIGVuZDtmb3IgdSxaIGluIHBhaXJze2xlZ21nPSJhcm1tZ193ZWFwb24iLGxlZ2ZtZz0iZ2F0bGluZ19ndW4ifWRvIGlmIHQodSlhbmQgdihaKXRoZW4gYi5jYW50YmV0cmFuc3BvcnRlZD10cnVlO2MucmFuZ2U9NjI1O2MuYWNjdXJhY3k9MTAwO2Muc3ByYXlhbmdsZT04ODA7VCgxLjA3KWVuZCBlbmQ7aWYgdCgibGVnZmxvYXQiKXRoZW4gYi5tb3ZlbWVudGNsYXNzPSJNVEFOSzMiYi53YXRlcmxpbmU9bmlsO2IuZmxvYXRlcj1uaWwgZW5kO2lmIHQoImxlZ25hdnlmcmlnYXRlIil0aGVuIGJbaV1bMV1bbl09Ik5PVFNVQiJiW2ldWzJdPW5pbDtUKDAuODUpZW5kO2lmIHQoImxlZ25hdnlkZXN0cm8iKXRoZW4gZT1hLmxlZ25hdnlhcnR5c2hpcDtDKGIsImJ1aWxkcGljIiwiY29sbGlzaW9udm9sdW1lb2Zmc2V0cyIsImNvbGxpc2lvbnZvbHVtZXNjYWxlcyIsImNvbGxpc2lvbnZvbHVtZXR5cGUiLCJvYmplY3RuYW1lIiwic2NyaXB0IilBKCJkZXB0aGNoYXJnZSIsYS5jb3Jyb3lbal0uZGVwdGhjaGFyZ2UpYltpXVsyXT15KGEuY29ycm95W2ldWzJdKWJbal0uZHJvbmVfY29udHJvbF9tYXRyaXg9bmlsO1QoMS4wOCllbmQ7aWYgdCgibGVnYW5hdnliYXR0bGVzaGlwIil0aGVuIGIubW92ZW1lbnRjbGFzcz0iQk9BVDkiVCgwLjg4KWVuZDtpZiB0KCJsZWdhcCIpdGhlbiB0YWJsZS5pbnNlcnQoYi5idWlsZG9wdGlvbnMsImNvcmZpbmsiKWVuZDthLmxlZ2thbT15KGEuYXJtdGh1bmQpYS5sZWdwaG9lbml4PW5pbDtpZiB0KCJsZWdtaW5lYiIpdGhlbiBBKCJjb3Jfc2VhYWR2Ym9tYiIsYS5jb3JodXJjW2pdLmNvcmFkdmJvbWIpVCgwLjk0KWVuZDtpZiB0KCJsZWdyYW1wYXJ0Iil0aGVuIGIucmFkYXJkaXN0YW5jZWphbT1uaWw7YltpXVsyXT1uaWw7VCgwLjkpZW5kO2EubGVnZWxycGNtZWNoPW5pbDtpZiB0KCJsZWdlYWxsdGVycmFpbm1lY2giKXRoZW4gYltpXVs1XT1uaWw7VCgwLjkpZW5kO2EubGVnc3RhcmZhbGw9eShhLmFybXZ1bGMp

