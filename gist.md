# SMOOTH LEGION

## Tweakdefs

```lua
--SMOOTH LEGION
local UD = UnitDefs
local unitDef, weaponDef, cparams, ref
local divisors = { 2, 4, 5, 8, 12, 20, 50, 125, 250 }
local m2e, m2b = 60, 30
local weapons, weapondefs = "weapons", "weapondefs"
local metalcost, energycost, buildtime = "metalcost", "energycost", "buildtime"
local onlytargetcategory = "onlytargetcategory"
local badtargetcategory = "badtargetcategory"

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
		if weaponDef.areaofeffect >= 40 and weaponDef.impactonly ~= 1 then
			costs(0.95)
		end
		copyref(weaponDef, "impactonly", "areaofeffect",
			"corethickness", "explosiongenerator", "intensity", "laserflaresize", "rgbcolor", "thickness", "size",
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
			"corethickness", "explosiongenerator", "intensity", "laserflaresize", "rgbcolor", "thickness", "size",
			"soundhitdry", "soundhitwet", "soundstart",
			"cylindertargeting", "impactonly", "predictboost")
		weaponDef.weaponvelocity = weaponDef.range + 100
		cparams.overpenetrate = nil
		damages(1.3)
		scaleLaserFX(0.6667)
	end
end
for name, wname in pairs { legrail = "aa_railgun", legadvaabot = "aa_railgun" } do
	if unit(name) and weapon(wname) then
		local range = weaponDef.range
		local vtol = weaponDef.damage.vtol
		local reloadtime = weaponDef.reloadtime
		weaponDef = copyweapon(wname, UD.armaak[weapondefs].longrangemissile)
		weaponDef.range = range
		weaponDef.damage.vtol = vtol
		weaponDef.reloadtime = reloadtime
	end
end

-- Burst plasma
ref = UD.correap[weapondefs].cor_reap
for name, wname in pairs { legcen = "gauss", legaskirmtank = "legmgplasma", legmrv = "quickshot_cannon", leganavybattleship = "burst_plasma_t2", } do
	if unit(name) and weapon(wname) then
		weaponDef.name = "Medium Plasma Cannon"
		weaponDef.impactonly = false
		local burst = weaponDef.burst
		copyref(weaponDef, "impactonly", "impulsefactor", "weaponvelocity", "edgeeffectiveness")
		local base = weaponDef.damage.default
		damages(burst)
		weaponDef.burst = nil
		local t = math.clamp((weaponDef.damage.default - base) / (ref.damage.default - base), 0, 1 + burst / 3)
		weaponDef.areaofeffect = math.mix(weaponDef.areaofeffect, ref.areaofeffect, t)
	end
end

-- Cluster plasma
local function toplasma(name, wname, cname)
	if unit(name) and weapon(wname) then
		ref = UD.armamb[weapondefs].armamb_gun -- TODO: need existence checks for ref, too.
		copyref(weaponDef, "cegtag", "explosiongenerator")
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
	weaponDef.areaofeffect = 56
	weaponDef.edgeeffectiveness = 0.25
	weaponDef.explosiongenerator = "custom:genericshellexplosion-small-bomb"
	weaponDef.burst = 3
	weaponDef.burstrate = 0.4
	weaponDef.range = 610
	weaponDef.weaponvelocity = 260
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
	weaponDef.weaponvelocity = 460
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
	unitDef[weapons][1].def = "emp_pulse"
	weaponDef = copyweapon("emp_pulse", weaponDef)
	unitDef[weapondefs].juno_pulse_mini = nil
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
		custom(weaponDef)
		copyref(cparams, metalcost, energycost)
		cparams.carried_unit = "legfig"
		cparams.controlradius = 1600
	end
end

--------------------------------------------------------------------------------
-- Nuh-uh ----------------------------------------------------------------------

if unit("leglob") then
	unitDef[weapons][2] = nil
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

> bG9jYWwgYT1Vbml0RGVmcztsb2NhbCBiLGMsZCxlO2xvY2FsIGY9ezIsNCw1LDgsMTIsMjAsNTAsMTI1LDI1MH1sb2NhbCBnLGg9NjAsMzA7bG9jYWwgaSxqPSJ3ZWFwb25zIiwid2VhcG9uZGVmcyJsb2NhbCBrLGwsbT0ibWV0YWxjb3N0IiwiZW5lcmd5Y29zdCIsImJ1aWxkdGltZSJsb2NhbCBuPSJvbmx5dGFyZ2V0Y2F0ZWdvcnkibG9jYWwgbz0iYmFkdGFyZ2V0Y2F0ZWdvcnkibG9jYWwgZnVuY3Rpb24gcChxKWI9YVtxXXJldHVybiBiIGVuZDtsb2NhbCBmdW5jdGlvbiByKHEpYz1iW2pdW3FdcmV0dXJuIGMgZW5kO2xvY2FsIGZ1bmN0aW9uIHModClkPXQuY3VzdG9tcGFyYW1zIG9ye310LmN1c3RvbXBhcmFtcz1kO3JldHVybiBkIGVuZDtsb2NhbCBmdW5jdGlvbiB1KHEsdClsb2NhbCB2PXRhYmxlLmNvcHkodCBvciBlKWJbal1bcV09djtyZXR1cm4gdiBlbmQ7bG9jYWwgZnVuY3Rpb24gdyh0LC4uLilmb3IgeCx5IGluIGlwYWlycyh7Li4ufSlkbyB0W3ldPWVbeV1lbmQgZW5kO2xvY2FsIGZ1bmN0aW9uIHooQSxCKWlmIEIgdGhlbiBBPUEvQiBlbHNlIEI9MSBlbmQ7aWYgQTw9MzAgdGhlbiByZXR1cm4gbWF0aC5mbG9vcihBKzAuNSkqQiBlbmQ7bG9jYWwgQz17fWZvciB4LEQgaW4gaXBhaXJzKGYpZG8gQ1tEXT1tYXRoLmZsb29yKEEvRCswLjUpKkQgZW5kO2xvY2FsIEU9Q1tmWzFdXWxvY2FsIEY9RS1BO0Y9RipGL2ZbMV1mb3IgRz0yLCNmIGRvIGxvY2FsIEg9ZltHXWxvY2FsIEk9Q1tIXS1BO0k9SSpJL2ZbR11pZiBGPkkgdGhlbiBFPUNbSF1GPUkgZW5kIGVuZDtyZXR1cm4gRSpCIGVuZDtsb2NhbCBmdW5jdGlvbiBKKEssTCxNLE4sQilsb2NhbCBBPXRvbnVtYmVyKEtbTF0paWYgdHlwZShBKT09Im51bWJlciJ0aGVuIEtbTF09eihBKihNIG9yIDEpKyhOIG9yIDApLEIpZW5kIGVuZDtsb2NhbCBmdW5jdGlvbiBPKE0sUCxRLFIpUD1QIG9yIDA7UT1RIG9yIFAqKChiW2tdb3IgMCk-MCBhbmQgYltsXS9iW2tdb3IgZylSPVIgb3IgUCooKGJba11vciAwKT4wIGFuZCBiW21dL2Jba11vciBoKUooYixrLE0sUCwxMClKKGIsbCxNLFEsMTApSihiLG0sTSxSLDEwKWVuZDtsb2NhbCBmdW5jdGlvbiBTKE0sTilmb3IgVCBpbiBwYWlycyhjLmRhbWFnZSlkbyBKKGMuZGFtYWdlLFQsTSxOKWVuZDtyZXR1cm4gYy5kYW1hZ2UgZW5kO2U9cCgibGVnY29tIilbaV1lWzFdW25dPSJOT1RTVUIiZVsxXS5mYXN0YXV0b3JldGFyZ2V0aW5nPXRydWU7ZVs0XT1uaWw7ZT1hLmFybWNvbVtqXXUoImxlZ2NvbWxhc2VyIixlLmFybWNvbWxhc2VyKXUoInRvcnBlZG8iLGUuYXJtY29tc2VhbGFzZXIpaWYgcCgibGVnbWV4Iil0aGVuIGIuZXh0cmFjdHNtZXRhbD0wLjAwMTtiLmVuZXJneXVwa2VlcD0zIGVuZDtmb3IgeCxxIGluIHBhaXJzeyJsZWdrYXJrIiwibGVnZ2F0In1kbyBpZiBwKHEpdGhlbiBPKDAuOSlKKGIsImhlYWx0aCIsMC45KUooYiwic3BlZWQiLDEuMDcpZm9yIFUgaW4gcGFpcnMoYltqXSlkbyByKFUpUygwLjkyKWVuZCBlbmQgZW5kO2xvY2FsIGZ1bmN0aW9uIFYoVylsb2NhbCBYPW1hdGguc3FydChTKCkuZGVmYXVsdC9lLmRhbWFnZS5kZWZhdWx0KSooVyBvciAxKSswLjUtKFcgb3IgMSkqMC41O1g9WC8oKGMuYmVhbXRpbWUgb3IgMS8zMCkqMzApSihjLCJjb3JldGhpY2tuZXNzIixYKUooYywidGhpY2tuZXNzIixYKUooYywibGFzZXJmbGFyZXNpemUiLFgqMC4xKzAuOSllbmQ7bG9jYWwgZnVuY3Rpb24gWShxLFUpaWYgcChxKWFuZCByKFUpdGhlbiBpZiBjLmFyZWFvZmVmZmVjdD49NDAgYW5kIGMuaW1wYWN0b25seX49MSB0aGVuIE8oMC45NSllbmQ7dyhjLCJpbXBhY3Rvbmx5IiwiYXJlYW9mZWZmZWN0IiwiY29yZXRoaWNrbmVzcyIsImV4cGxvc2lvbmdlbmVyYXRvciIsImludGVuc2l0eSIsImxhc2VyZmxhcmVzaXplIiwicmdiY29sb3IiLCJ0aGlja25lc3MiLCJzaXplIiwic291bmRoaXRkcnkiLCJzb3VuZGhpdHdldCIpVigpZW5kIGVuZDtlPWEuYXJtbGx0W2pdLmFybV9saWdodGxhc2VyO2ZvciBxLFUgaW4gcGFpcnN7bGVnaW5mZXN0b3I9ImZlc3RvcmJlYW0iLGxlZ2xodD0iaGVhdF9yYXkiLGxlZ3NoPSJoZWF0X3JheSIsbGVnaGVsaW9zPSJoZWF0X3JheSJ9ZG8gWShxLFUpZW5kO2U9YS5hcm1iZWFtZXJbal0uYXJtYmVhbWVyX3dlYXBvbjtmb3IgcSxVIGluIHBhaXJze2xlZ2hlYXZ5ZHJvbmU9ImhlYXRfcmF5IixsZWdpbmM9ImhlYXRyYXlsYXJnZSIsbGVna2Fyaz0iaGVhdF9yYXkiLGxlZ2Jhc3Rpb249InQyaGVhdHJheSIsbGVnYW5hdnlmbGFnc2hpcD0ibGVnX2V4cGVyaW1lbnRhbF9oZWF0cmF5IixsZWduYXZ5ZGVzdHJvPSJsZWdfbWVkaXVtX2hlYXRyYXkiLGxlZ2VoZWF0cmF5bWVjaD0iaGVhdHJheTEiLGxlZ2Vob3ZlcnRhbms9ImhlYXRfcmF5IixsZWdhaGVhdHRhbms9ImhlYXRfcmF5In1kbyBZKHEsVSllbmQ7ZT1hLmNvcmhsdFtqXS5jb3JfbGFzZXJoMTtmb3IgcSxVIGluIHBhaXJze2xlZ3JhaWw9InJhaWxndW4iLGxlZ3NyYWlsPSJyYWlsZ3VudDIiLGxlZ2FuYXZ5ZmxhZ3NoaXA9ImxlZ19leHBlcmltZW50YWxfcmFpbGd1biIsbGVnZXJhaWx0YW5rPSJ0M19yYWlsX2FjY2VsZXJhdG9yIn1kbyBpZiBwKHEpYW5kIHIoVSl0aGVuIHMoYyljLm5hbWU9IkhlYXZ5IExhc2VyIncoYywid2VhcG9udHlwZSIsImJlYW10aW1lIiwiaW1wdWxzZWZhY3RvciIsIm5vZXhwbG9kZSIsImNvcmV0aGlja25lc3MiLCJleHBsb3Npb25nZW5lcmF0b3IiLCJpbnRlbnNpdHkiLCJsYXNlcmZsYXJlc2l6ZSIsInJnYmNvbG9yIiwidGhpY2tuZXNzIiwic2l6ZSIsInNvdW5kaGl0ZHJ5Iiwic291bmRoaXR3ZXQiLCJzb3VuZHN0YXJ0IiwiY3lsaW5kZXJ0YXJnZXRpbmciLCJpbXBhY3Rvbmx5IiwicHJlZGljdGJvb3N0IiljLndlYXBvbnZlbG9jaXR5PWMucmFuZ2UrMTAwO2Qub3ZlcnBlbmV0cmF0ZT1uaWw7UygxLjMpVigwLjY2NjcpZW5kIGVuZDtmb3IgcSxVIGluIHBhaXJze2xlZ3JhaWw9ImFhX3JhaWxndW4iLGxlZ2FkdmFhYm90PSJhYV9yYWlsZ3VuIn1kbyBpZiBwKHEpYW5kIHIoVSl0aGVuIGxvY2FsIFo9Yy5yYW5nZTtsb2NhbCBfPWMuZGFtYWdlLnZ0b2w7bG9jYWwgYTA9Yy5yZWxvYWR0aW1lO2M9dShVLGEuYXJtYWFrW2pdLmxvbmdyYW5nZW1pc3NpbGUpYy5yYW5nZT1aO2MuZGFtYWdlLnZ0b2w9XztjLnJlbG9hZHRpbWU9YTAgZW5kIGVuZDtlPWEuY29ycmVhcFtqXS5jb3JfcmVhcDtmb3IgcSxVIGluIHBhaXJze2xlZ2Nlbj0iZ2F1c3MiLGxlZ2Fza2lybXRhbms9ImxlZ21ncGxhc21hIixsZWdtcnY9InF1aWNrc2hvdF9jYW5ub24iLGxlZ2FuYXZ5YmF0dGxlc2hpcD0iYnVyc3RfcGxhc21hX3QyIn1kbyBpZiBwKHEpYW5kIHIoVSl0aGVuIGMubmFtZT0iTWVkaXVtIFBsYXNtYSBDYW5ub24iYy5pbXBhY3Rvbmx5PWZhbHNlO2xvY2FsIGExPWMuYnVyc3Q7dyhjLCJpbXBhY3Rvbmx5IiwiaW1wdWxzZWZhY3RvciIsIndlYXBvbnZlbG9jaXR5IiwiZWRnZWVmZmVjdGl2ZW5lc3MiKWxvY2FsIGEyPWMuZGFtYWdlLmRlZmF1bHQ7UyhhMSljLmJ1cnN0PW5pbDtsb2NhbCBhMz1tYXRoLmNsYW1wKChjLmRhbWFnZS5kZWZhdWx0LWEyKS8oZS5kYW1hZ2UuZGVmYXVsdC1hMiksMCwxK2ExLzMpYy5hcmVhb2ZlZmZlY3Q9bWF0aC5taXgoYy5hcmVhb2ZlZmZlY3QsZS5hcmVhb2ZlZmZlY3QsYTMpZW5kIGVuZDtsb2NhbCBmdW5jdGlvbiBhNChxLFUsYTUpaWYgcChxKWFuZCByKFUpdGhlbiBlPWEuYXJtYW1iW2pdLmFybWFtYl9ndW47dyhjLCJjZWd0YWciLCJleHBsb3Npb25nZW5lcmF0b3IiKWxvY2FsIGE2PXMoYykuY2x1c3Rlcl9udW1iZXIgb3IgNTtTKDErbWF0aC5zcXJ0KGE2KnIoYTUgb3IiY2x1c3Rlcl9tdW5pdGlvbiIpLmRhbWFnZS5kZWZhdWx0L3IoVSkuZGFtYWdlLmRlZmF1bHQpKWQuY2x1c3Rlcl9kZWYsZC5jbHVzdGVyX251bWJlcj1uaWwsbmlsIGVuZCBlbmQ7Zm9yIHEsVSBpbiBwYWlyc3tsZWdhbWNsdXN0ZXI9ImNsdXN0ZXJfYXJ0aWxsZXJ5IixsZWdjbHVzdGVyPSJwbGFzbWEiLGxlZ2FjbHVzdGVyPSJwbGFzbWEiLGxlZ2xycGM9ImxycGMiLGxlZ2VhbGx0ZXJyYWlubWVjaD0icGxhc21hX2xvdyJ9ZG8gYTQocSxVKWVuZDtmb3IgcSxVIGluIHBhaXJze2xlZ2NsdXN0ZXI9InBsYXNtYV9oaWdoIixsZWdhY2x1c3Rlcj0icGxhc21hX2hpZ2giLGxlZ2VhbGx0ZXJyYWlubWVjaD0icGxhc21hX2hpZ2gifWRvIGE0KHEsVSllbmQ7YTQoImxlZ2FuYXZ5YXJ0eXNoaXAiLCJsZWdfbW9iaWxlX2NsdXN0ZXJfbHJwY19jYW5ub24iLCJjbHVzdGVyX211bml0aW9uX21haW4iKWE0KCJsZWdhbmF2eWFydHlzaGlwIiwibGVnX21vYmlsZV9jbHVzdGVyX3BsYXNtYSIsImNsdXN0ZXJfbXVuaXRpb25fc2Vjb25kYXJ5IilpZiBwKCJsZWdiYXIiKXRoZW4gYi5zcGVlZD00OTtjPXUoImNsdXN0ZXJuYXBhbG0iLGEubGVnZWhvdmVydGFua1tqXS5wYXJhYm9saWNfcm9ja2V0cyljLmFyZWFvZmVmZmVjdD01NjtjLmVkZ2VlZmZlY3RpdmVuZXNzPTAuMjU7Yy5leHBsb3Npb25nZW5lcmF0b3I9ImN1c3RvbTpnZW5lcmljc2hlbGxleHBsb3Npb24tc21hbGwtYm9tYiJjLmJ1cnN0PTM7Yy5idXJzdHJhdGU9MC40O2MucmFuZ2U9NjEwO2Mud2VhcG9udmVsb2NpdHk9MjYwIGVuZDtpZiBwKCJsZWdiYXJ0Iil0aGVuIHUoImNsdXN0ZXJuYXBhbG0iLGEuYXJtZmlkb1tqXS5iZmlkbylPKDAuODUpZW5kO2lmIHAoImxlZ2luZiIpdGhlbiBjPXUoInJhcGlkbmFwYWxtIixhLmNvcnRyZW1bal0udHJlbW9yX3NwcmVhZF9maXJlKWMuYnVyc3Q9MztjLmJ1cnN0cmF0ZT0wLjMzMzM7Yy5yZWxvYWR0aW1lPTI7Yy5teWdyYXZpdHk9MC4xODtjLnJhbmdlPTEyMDA7Yy53ZWFwb252ZWxvY2l0eT00NjAgZW5kO2lmIHAoImxlZ3BlcmRpdGlvbiIpdGhlbiB1KCJuYXBhbG1taXNzaWxlIixhLmNvcnRyb25bal0uY29ydHJvbl93ZWFwb24pZW5kO2lmIHAoImxlZ21lZCIpdGhlbiB1KCJsYXNlciIsYS5jb3Jha1tqXS5nYXRvcl9sYXNlciliW2ldWzFdW29dPSJWVE9MImJbaV1bMl1bb109IlZUT0wiYltpXVsyXS5zbGF2ZXRvPW5pbDtyKCJsZWdtZWRfbWlzc2lsZSIpLmN1c3RvbXBhcmFtcz17Y3J1aXNlX21heF9oZWlnaHQ9NDAsY3J1aXNlX21pbl9oZWlnaHQ9MTUsbG9ja29uX2Rpc3Q9MTAwLHNwZWNlZmZlY3Q9ImNydWlzZSIscHJvamVjdGlsZV9kZXN0cnVjdGlvbl9tZXRob2Q9ImRlc2NlbmQiLG92ZXJyYW5nZV9kaXN0YW5jZT0xMDkzfWU9YztyKCJsYXNlciIpLnJhbmdlPWUucmFuZ2UgZW5kO2lmIHAoImxlZ2NpYiIpYW5kIHIoImp1bm9fcHVsc2VfbWluaSIpdGhlbiBiW2ldWzFdLmRlZj0iZW1wX3B1bHNlImM9dSgiZW1wX3B1bHNlIixjKWJbal0uanVub19wdWxzZV9taW5pPW5pbDtjLmN1c3RvbXBhcmFtcz1uaWw7Yy5wYXJhbHl6ZXI9dHJ1ZTtjLnBhcmFseXpldGltZT01O2MuYXJlYW9mZWZmZWN0PTQyMDtjLmVkZ2VlZmZlY3RpdmVuZXNzPTA7Yy5kYW1hZ2UuZGVmYXVsdD0zMDA7Yy5kYW1hZ2UudnRvbD0xMCBlbmQ7aWYgcCgibGVnYW1waCIpdGhlbiB1KCJoZWF0X3JheSIsYS5jb3JtYXdbal0uZG1hdyl1KCJjb2F4X2RlcHRoY2hhcmdlIixhLmNvcm1vcnRbal0uY29yX21vcnQpYltpXVsyXVtuXT0iU1VSRkFDRSJlbmQ7Zm9yIHgscSBpbiBwYWlyc3sibGVna2FyayIsImxlZ2FtcGgiLCJsZWdzaG90In1kbyBpZiBwKHEpdGhlbiBzKGIpbG9jYWwgYTc9MS9iLmRhbWFnZW1vZGlmaWVyO2xvY2FsIGE4PWQucmVhY3RpdmVfYXJtb3JfaGVhbHRoO2QucmVhY3RpdmVfYXJtb3JfaGVhbHRoPW5pbDtkLnJlYWN0aXZlX2FybW9yX3Jlc3RvcmU9bmlsO2xvY2FsIGE5PWE4KigwLjUrbWF0aC5zcXJ0KGE4KmE3L2IuaGVhbHRoKSooYTctMSkpYi5oZWFsdGg9Yi5oZWFsdGgrYTkgZW5kIGVuZDtmb3IgcSxVIGluIHBhaXJze2xlZ2hpdmU9InBsYXNtYSIsbGVnZmhpdmU9InBsYXNtYSIsbGVnc3BjYXJyaWVyPSJsZWdfZHJvbmVfY29udHJvbGxlciIsbGVndmNhcnJ5PSJ0YXJnZXRpbmciLGxlZ2FuYXZ5YW50aW51a2VjYXJyaWVyPSJsZWdfZHJvbmVfY29udHJvbGxlciJ9ZG8gaWYgcChxKWFuZCByKFUpdGhlbiBPKDAuNzUpZT1iW2ldWzFdZVtuXT0iVlRPTCJlW29dPSJMSUdIVEFJUlNDT1VUImMucmFuZ2U9MTYwMDtlPWEuYXJtZmlnO3MoYyl3KGQsayxsKWQuY2FycmllZF91bml0PSJsZWdmaWciZC5jb250cm9scmFkaXVzPTE2MDAgZW5kIGVuZDtpZiBwKCJsZWdsb2IiKXRoZW4gYltpXVsyXT1uaWwgZW5kO2lmIHAoImxlZ21nIilhbmQgcigiYXJtbWdfd2VhcG9uIil0aGVuIGIuY2FudGJldHJhbnNwb3J0ZWQ9dHJ1ZTtPKDEuMDcpYy5yYW5nZT02MjA7Yy5vd25lckV4cEFjY1dlaWdodD0yO2MuYWNjdXJhY3k9MTAwO2Muc3ByYXlhbmdsZT04ODAgZW5kO2lmIHAoImxlZ2Zsb2F0Iil0aGVuIGIubW92ZW1lbnRjbGFzcz0iTVRBTkszImIud2F0ZXJsaW5lPW5pbDtiLmZsb2F0ZXI9bmlsIGVuZDtpZiBwKCJsZWduYXZ5ZnJpZ2F0ZSIpdGhlbiBiW2ldWzFdW25dPSJOT1RTVUIiYltpXVsyXT1uaWw7TygwLjg1KWVuZDtpZiBwKCJsZWduYXZ5ZGVzdHJvIil0aGVuIGU9YS5sZWduYXZ5YXJ0eXNoaXA7dyhiLCJidWlsZHBpYyIsImNvbGxpc2lvbnZvbHVtZW9mZnNldHMiLCJjb2xsaXNpb252b2x1bWVzY2FsZXMiLCJjb2xsaXNpb252b2x1bWV0eXBlIiwib2JqZWN0bmFtZSIsInNjcmlwdCIpdSgiZGVwdGhjaGFyZ2UiLGEuY29ycm95W2pdLmRlcHRoY2hhcmdlKWJbaV1bMl09dGFibGUuY29weShhLmNvcnJveVtpXVsyXSliW2pdLmRyb25lX2NvbnRyb2xfbWF0cml4PW5pbDtPKDEuMDgpZW5kO2lmIHAoImxlZ2FuYXZ5YmF0dGxlc2hpcCIpdGhlbiBiLm1vdmVtZW50Y2xhc3M9IkJPQVQ5Ik8oMC44OCllbmQ7aWYgcCgibGVnYXAiKXRoZW4gdGFibGUuaW5zZXJ0KGIuYnVpbGRvcHRpb25zLCJjb3JmaW5rIillbmQ7aWYgcCgibGVnZmlnIil0aGVuIGU9YS5hcm1maWc7dyhiLG0sbCxrLCJzcGVlZCIsInR1cm5yYWRpdXMiKXUoInNlbWlhdXRvIixlW2pdLmFybXZ0b2xfbWlzc2lsZSliW2ldWzFdLm1heGFuZ2xlZGlmPW5pbCBlbmQ7YS5sZWdrYW09dGFibGUuY29weShhLmFybXRodW5kKWEubGVncGhvZW5peD1uaWw7aWYgcCgibGVnbWluZWIiKXRoZW4gdSgiY29yX3NlYWFkdmJvbWIiLGEuY29yaHVyY1tqXS5jb3JhZHZib21iKU8oMC45NCllbmQ7aWYgcCgibGVncmFtcGFydCIpdGhlbiBiLnJhZGFyZGlzdGFuY2VqYW09bmlsO2JbaV1bMl09bmlsO08oMC45KWVuZDthLmxlZ2VscnBjbWVjaD1uaWw7aWYgcCgibGVnZWFsbHRlcnJhaW5tZWNoIil0aGVuIGJbaV1bNV09bmlsO08oMC45KWVuZDthLmxlZ3N0YXJmYWxsPXRhYmxlLmNvcHkoYS5hcm12dWxjKQ

