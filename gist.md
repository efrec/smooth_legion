# SMOOTH LEGION

## Tweakdefs

```lua
--SHORT LEGION
local UD = UnitDefs
local unitDef, weaponDef, cparams, ref
local divisors = { 2, 4, 5, 8, 12, 20, 50, 125, 250 }
local m2e, m2b = 20, 30

--------------------------------------------------------------------------------
-- Initialize ------------------------------------------------------------------

local function unit(name)
	unitDef = UD[name]
	return unitDef
end

local function weapon(name)
	weaponDef = unitDef.weapondefs[name]
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

local function damages(mult, base)
	if not base then base = 0 end
	for armor in pairs(weaponDef.damage) do
		set(weaponDef.damage, armor, mult, base)
	end
	return weaponDef.damage
end

--------------------------------------------------------------------------------
-- Commander -------------------------------------------------------------------

UD.legcom.weapons[1].onlytargetcategory = "NOTSUB"
UD.legcom.weapons[1].fastautoretargeting = true
UD.legcom.weapondefs.legcomlaser = table.copy(UD.armcom.weapondefs.armcomlaser)
UD.legcom.weapondefs.torpedo = table.copy(UD.armcom.weapondefs.armcomsealaser)
UD.legcom.weapons[4] = nil

--------------------------------------------------------------------------------
-- Basic economy ---------------------------------------------------------------

UD.legmex.extractsmetal = 0.001
UD.legmex.energyupkeep = 3

--------------------------------------------------------------------------------
-- Make T1.5 units smoother ----------------------------------------------------

for _, name in ipairs { "legkark", "leggat" } do
	unit(name) costs(0.9) set(unitDef, "health", 0.9) set(unitDef, "speed", 1.07)
	for wname in pairs(unitDef.weapondefs) do
		weapon(wname) damages(0.92)
	end
end

--------------------------------------------------------------------------------
-- Weapon conversions ----------------------------------------------------------

-- These are total conversions that otherwise preserve the stats of the weapon.
-- Overall stat changes (eg total burst size) should be done in other sections.

local function scaleLaserFX(grav)
	local scale = math.sqrt(damages().default / ref.damage.default) * (grav or 1) + (0.5 - (grav or 1) * 0.5)
	scale = scale / ((weaponDef.beamtime or (1/30)) * 30)
	set(weaponDef, "corethickness", scale)
	set(weaponDef, "thickness", scale)
	set(weaponDef, "laserflaresize", scale * 0.1 + 0.9)
end

-- Heat rays
local function scaleHeatRay(name, wname)
	unit(name) weapon(wname)
	if weaponDef.areaofeffect >= 40 and weaponDef.impactonly ~= 1 then
		costs(0.95)
	end
	copy(weaponDef, "impactonly", "areaofeffect",
		"corethickness", "explosiongenerator", "intensity", "laserflaresize", "rgbcolor", "thickness", "size",
		"soundhitdry", "soundhitwet")
	scaleLaserFX()
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
	unit(name) weapon(wname) custom(weaponDef)
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
ref = UD.armaak.weapondefs.longrangemissile
for name, wname in pairs { legrail = "aa_railgun", legadvaabot = "aa_railgun" } do
	unit(name) weapon(wname)
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

-- Burst plasma
ref = UD.correap.weapondefs.cor_reap
for name, wname in pairs { legcen = "gauss", legaskirmtank = "legmgplasma", legmrv = "quickshot_cannon", leganavybattleship = "burst_plasma_t2", } do
	unit(name) weapon(wname)
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

-- Cluster plasma
ref = UD.armamb.weapondefs.armamb_gun
local function toplasma(name, wname, cname)
	unit(name) weapon(wname) custom(weaponDef)
	copy(weaponDef, "cegtag", "explosiongenerator")
	local count = cparams.cluster_number or 5
	local damage = unitDef.weapondefs[cname or "cluster_munition"].damage.default
	damages(1 + math.sqrt(count * damage / weaponDef.damage.default))
	cparams.cluster_def, cparams.cluster_number = nil, nil
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
unit("legbar").weapondefs.clusternapalm = table.copy(UD.legehovertank.weapondefs.parabolic_rockets)
unitDef.speed = 49
weapon("clusternapalm")
weaponDef.areaofeffect = 56
weaponDef.edgeeffectiveness = 0.25
weaponDef.explosiongenerator = "custom:genericshellexplosion-small-bomb"
weaponDef.burst = 3
weaponDef.burstrate = 0.4
weaponDef.range = 610
weaponDef.weaponvelocity = 260

unit("legbart").weapondefs.clusternapalm = table.copy(UD.armfido.weapondefs.bfido)
costs(0.85)

unit("leginf").weapondefs.rapidnapalm = table.copy(UD.cortrem.weapondefs.tremor_spread_fire)
weapon("rapidnapalm")
weaponDef.burst = 3
weaponDef.burstrate = 0.3333
weaponDef.reloadtime = 2
weaponDef.mygravity = 0.18
weaponDef.range = 1200
weaponDef.weaponvelocity = 460

UD.legperdition.weapondefs.napalmmissile = table.copy(UD.cortron.weapondefs.cortron_weapon)

-- Medusa
unit("legmed").weapondefs.laser = table.copy(UD.corak.weapondefs.gator_laser)
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

-- Blindfold
unit("legcib") weapon("juno_pulse_mini")
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

-- Telchine
UD.legamph.weapondefs.heat_ray = table.copy(UD.cormaw.weapondefs.dmaw)
UD.legamph.weapondefs.coax_depthcharge = table.copy(UD.cormort.weapondefs.cor_mort)
UD.legamph.weapons[2].onlytargetcategory = "SURFACE"

--------------------------------------------------------------------------------
-- Reactive armor --------------------------------------------------------------

for _, name in ipairs { "legkark", "legamph", "legshot" } do
	unit(name) custom(unitDef)
	local armoredMult = 1 / unitDef.damagemodifier
	local armorHealth = cparams.reactive_armor_health
	local healthBonus = armorHealth * (0.5 + math.sqrt(armorHealth * armoredMult / unitDef.health) * (armoredMult - 1))
	unitDef.health = unitDef.health + healthBonus
	cparams.reactive_armor_health = nil
	cparams.reactive_armor_restore = nil
end

--------------------------------------------------------------------------------
-- Drones ----------------------------------------------------------------------

ref = UD.armfig
for name, wname in pairs { leghive = "plasma", legfhive = "plasma", legspcarrier = "leg_drone_controller", legvcarry = "targeting", leganavyantinukecarrier = "leg_drone_controller" } do
	UD[name].weapondefs[wname].range = 1600
	UD[name].weapondefs[wname].customparams.carried_unit = "legfig"
	UD[name].weapondefs[wname].customparams.controlradius = 1600
	UD[name].weapondefs[wname].customparams.metalcost = ref.metalcost
	UD[name].weapondefs[wname].customparams.energycost = ref.energycost
	UD[name].weapons[1].onlytargetcategory = "VTOL"
	UD[name].weapons[1].badtargetcategory = "LIGHTAIRSCOUT"
	costs(0.75)
end

--------------------------------------------------------------------------------
-- Nuh-uh ----------------------------------------------------------------------

UD.leglob.weapons[2] = nil

unit("legmg") weapon("armmg_weapon")
unitDef.cantbetransported = true
costs(1.07)
weaponDef.range = 620
weaponDef.ownerExpAccWeight = 2
weaponDef.accuracy = 100
weaponDef.sprayangle = 880

unit("legnavyfrigate").weapons[1].onlytargetcategory = "NOTSUB"
unitDef.weapons[2] = nil
costs(0.85)

ref = UD.legnavyartyship
unit("legnavydestro")
copy(unitDef, "buildpic", "collisionvolumeoffsets", "collisionvolumescales", "collisionvolumetype", "objectname", "script")
unitDef.weapons[2] = table.copy(UD.corroy.weapons[2])
unitDef.weapondefs.depthcharge = table.copy(UD.corroy.weapondefs.depthcharge)
unitDef.weapondefs.drone_control_matrix = nil
costs(1.08)

UD.levnavyartyship = nil

ref = UD.armfig
unit("legfig")
copy(unitDef, "buildtime", "energycost", "metalcost", "speed", "turnradius")
unitDef.weapondefs.semiauto = table.copy(ref.weapondefs.armvtol_missile)
unitDef.weapons[1].maxangledif = nil

UD.legkam = table.copy(UD.armthund)

table.insert(UD.legap.buildoptions, "corfink")

UD.legfloat.movementclass = "MTANK3"
UD.legfloat.waterline = nil
UD.legfloat.floater = nil

unit("leganavybattleship").movementclass = "BOAT9"
costs(0.88)

UD.legphoenix = nil

unit("legmineb").weapondefs.cor_seaadvbomb = table.copy(UD.corhurc.weapondefs.coradvbomb)
costs(0.94)

unit("legrampart").radardistancejam = nil
unitDef.weapons[2] = nil
costs(0.9)

UD.legelrpcmech = nil

UD.legeallterrainmech.weapons[5] = nil

UD.legstarfall = table.copy(UD.armvulc)
```

## Tweakunits

<!-- tweakunits_readable -->

## Tweakdefs encoded (URL-safe base64)

> bG9jYWwgYT1Vbml0RGVmcztsb2NhbCBiLGMsZCxlO2xvY2FsIGY9ezIsNCw1LDgsMTIsMjAsNTAsMTI1LDI1MH1sb2NhbCBnLGg9MjAsMzA7bG9jYWwgZnVuY3Rpb24gaShqKWI9YVtqXXJldHVybiBiIGVuZDtsb2NhbCBmdW5jdGlvbiBrKGopYz1iLndlYXBvbmRlZnNbal1yZXR1cm4gYyBlbmQ7bG9jYWwgZnVuY3Rpb24gbChtKWQ9bS5jdXN0b21wYXJhbXMgb3J7fW0uY3VzdG9tcGFyYW1zPWQ7cmV0dXJuIGQgZW5kO2xvY2FsIGZ1bmN0aW9uIG4obSwuLi4pZm9yIG8scCBpbiBpcGFpcnMoey4uLn0pZG8gbVtwXT1lW3BdZW5kIGVuZDtsb2NhbCBmdW5jdGlvbiBxKHIscylpZiBzIHRoZW4gcj1yL3MgZWxzZSBzPTEgZW5kO2lmIHI8PTMwIHRoZW4gcmV0dXJuIG1hdGguZmxvb3IociswLjUpKnMgZW5kO2xvY2FsIHQ9e31mb3Igbyx1IGluIGlwYWlycyhmKWRvIHRbdV09bWF0aC5mbG9vcihyL3UrMC41KSp1IGVuZDtsb2NhbCB2PXRbZlsxXV1sb2NhbCB3PXYtcjt3PXcqdy9mWzFdZm9yIHg9MiwjZiBkbyBsb2NhbCB5PWZbeF1sb2NhbCB6PXRbeV0tcjt6PXoqei9mW3hdaWYgdz56IHRoZW4gdj10W3lddz16IGVuZCBlbmQ7cmV0dXJuIHYqcyBlbmQ7bG9jYWwgZnVuY3Rpb24gQShCLEMsRCxFLHMpbG9jYWwgcj10b251bWJlcihCW0NdKWlmIHR5cGUocik9PSJudW1iZXIidGhlbiBCW0NdPXEociooRCBvciAxKSsoRSBvciAwKSxzKWVuZCBlbmQ7bG9jYWwgZnVuY3Rpb24gRihELEcsSCxJKWxvY2FsIEo9YjtpZiBub3QgRyB0aGVuIEc9MCBlbmQ7aWYgbm90IEggdGhlbiBIPUcqKEoubWV0YWxjb3N0IGFuZCBKLm1ldGFsY29zdD4wIGFuZCBKLmVuZXJneWNvc3QvSi5tZXRhbGNvc3Qgb3IgZyllbmQ7aWYgbm90IEkgdGhlbiBJPUcqKEoubWV0YWxjb3N0IGFuZCBKLm1ldGFsY29zdD4wIGFuZCBKLmJ1aWxkdGltZS9KLm1ldGFsY29zdCBvciBoKWVuZDtsb2NhbCBLPXEoSi5tZXRhbGNvc3QqRCtHLDEwKWxvY2FsIEw9Sy9KLm1ldGFsY29zdDtKLm1ldGFsY29zdD1LO0EoSiwiZW5lcmd5Y29zdCIsRCxILDEwKUEoSiwiYnVpbGR0aW1lIixELEksMTApZm9yIG8sTSBpbiBwYWlycyhKLmZlYXR1cmVkZWZzIG9ye30pZG8gTS5tZXRhbD1tYXRoLmZsb29yKEwqTS5tZXRhbCswLjUpZW5kIGVuZDtsb2NhbCBmdW5jdGlvbiBOKEQsTylpZiBub3QgTyB0aGVuIE89MCBlbmQ7Zm9yIFAgaW4gcGFpcnMoYy5kYW1hZ2UpZG8gQShjLmRhbWFnZSxQLEQsTyllbmQ7cmV0dXJuIGMuZGFtYWdlIGVuZDthLmxlZ2NvbS53ZWFwb25zWzFdLm9ubHl0YXJnZXRjYXRlZ29yeT0iTk9UU1VCImEubGVnY29tLndlYXBvbnNbMV0uZmFzdGF1dG9yZXRhcmdldGluZz10cnVlO2EubGVnY29tLndlYXBvbmRlZnMubGVnY29tbGFzZXI9dGFibGUuY29weShhLmFybWNvbS53ZWFwb25kZWZzLmFybWNvbWxhc2VyKWEubGVnY29tLndlYXBvbmRlZnMudG9ycGVkbz10YWJsZS5jb3B5KGEuYXJtY29tLndlYXBvbmRlZnMuYXJtY29tc2VhbGFzZXIpYS5sZWdjb20ud2VhcG9uc1s0XT1uaWw7YS5sZWdtZXguZXh0cmFjdHNtZXRhbD0wLjAwMTthLmxlZ21leC5lbmVyZ3l1cGtlZXA9Mztmb3IgbyxqIGluIGlwYWlyc3sibGVna2FyayIsImxlZ2dhdCJ9ZG8gaShqKUYoMC45KUEoYiwiaGVhbHRoIiwwLjkpQShiLCJzcGVlZCIsMS4wNylmb3IgUSBpbiBwYWlycyhiLndlYXBvbmRlZnMpZG8gayhRKU4oMC45MillbmQgZW5kO2xvY2FsIGZ1bmN0aW9uIFIoUylsb2NhbCBUPW1hdGguc3FydChOKCkuZGVmYXVsdC9lLmRhbWFnZS5kZWZhdWx0KSooUyBvciAxKSswLjUtKFMgb3IgMSkqMC41O1Q9VC8oKGMuYmVhbXRpbWUgb3IgMS8zMCkqMzApQShjLCJjb3JldGhpY2tuZXNzIixUKUEoYywidGhpY2tuZXNzIixUKUEoYywibGFzZXJmbGFyZXNpemUiLFQqMC4xKzAuOSllbmQ7bG9jYWwgZnVuY3Rpb24gVShqLFEpaShqKWsoUSlpZiBjLmFyZWFvZmVmZmVjdD49NDAgYW5kIGMuaW1wYWN0b25seX49MSB0aGVuIEYoMC45NSllbmQ7bihjLCJpbXBhY3Rvbmx5IiwiYXJlYW9mZWZmZWN0IiwiY29yZXRoaWNrbmVzcyIsImV4cGxvc2lvbmdlbmVyYXRvciIsImludGVuc2l0eSIsImxhc2VyZmxhcmVzaXplIiwicmdiY29sb3IiLCJ0aGlja25lc3MiLCJzaXplIiwic291bmRoaXRkcnkiLCJzb3VuZGhpdHdldCIpUigpZW5kO2U9YS5hcm1sbHQud2VhcG9uZGVmcy5hcm1fbGlnaHRsYXNlcjtmb3IgaixRIGluIHBhaXJze2xlZ2luZmVzdG9yPSJmZXN0b3JiZWFtIixsZWdsaHQ9ImhlYXRfcmF5IixsZWdzaD0iaGVhdF9yYXkiLGxlZ2hlbGlvcz0iaGVhdF9yYXkifWRvIFUoaixRKWVuZDtlPWEuYXJtYmVhbWVyLndlYXBvbmRlZnMuYXJtYmVhbWVyX3dlYXBvbjtmb3IgaixRIGluIHBhaXJze2xlZ2hlYXZ5ZHJvbmU9ImhlYXRfcmF5IixsZWdpbmM9ImhlYXRyYXlsYXJnZSIsbGVna2Fyaz0iaGVhdF9yYXkiLGxlZ2Jhc3Rpb249InQyaGVhdHJheSIsbGVnYW5hdnlmbGFnc2hpcD0ibGVnX2V4cGVyaW1lbnRhbF9oZWF0cmF5IixsZWduYXZ5ZGVzdHJvPSJsZWdfbWVkaXVtX2hlYXRyYXkiLGxlZ2VoZWF0cmF5bWVjaD0iaGVhdHJheTEiLGxlZ2Vob3ZlcnRhbms9ImhlYXRfcmF5IixsZWdhaGVhdHRhbms9ImhlYXRfcmF5In1kbyBVKGosUSllbmQ7ZT1hLmNvcmhsdC53ZWFwb25kZWZzLmNvcl9sYXNlcmgxO2ZvciBqLFEgaW4gcGFpcnN7bGVncmFpbD0icmFpbGd1biIsbGVnc3JhaWw9InJhaWxndW50MiIsbGVnYW5hdnlmbGFnc2hpcD0ibGVnX2V4cGVyaW1lbnRhbF9yYWlsZ3VuIixsZWdlcmFpbHRhbms9InQzX3JhaWxfYWNjZWxlcmF0b3IifWRvIGkoailrKFEpbChjKWMubmFtZT0iSGVhdnkgTGFzZXIibihjLCJ3ZWFwb250eXBlIiwiYmVhbXRpbWUiLCJpbXB1bHNlZmFjdG9yIiwibm9leHBsb2RlIiwiY29yZXRoaWNrbmVzcyIsImV4cGxvc2lvbmdlbmVyYXRvciIsImludGVuc2l0eSIsImxhc2VyZmxhcmVzaXplIiwicmdiY29sb3IiLCJ0aGlja25lc3MiLCJzaXplIiwic291bmRoaXRkcnkiLCJzb3VuZGhpdHdldCIsInNvdW5kc3RhcnQiLCJjeWxpbmRlcnRhcmdldGluZyIsImltcGFjdG9ubHkiLCJwcmVkaWN0Ym9vc3QiKWMud2VhcG9udmVsb2NpdHk9Yy5yYW5nZSsxMDA7ZC5vdmVycGVuZXRyYXRlPW5pbDtOKDEuMylSKDAuNjY2NyllbmQ7ZT1hLmFybWFhay53ZWFwb25kZWZzLmxvbmdyYW5nZW1pc3NpbGU7Zm9yIGosUSBpbiBwYWlyc3tsZWdyYWlsPSJhYV9yYWlsZ3VuIixsZWdhZHZhYWJvdD0iYWFfcmFpbGd1biJ9ZG8gaShqKWsoUSljLm5hbWU9IkxvbmctUmFuZ2UgQW50aS1BaXIgTWlzc2lsZSBMYXVuY2hlciJsb2NhbCBWPWMucmFuZ2U7bG9jYWwgVz1jLmRhbWFnZS52dG9sO2xvY2FsIFg9Yy5yZWxvYWR0aW1lO2xvY2FsIFk9dGFibGUuY29weShlKVkucmFuZ2U9VjtZLnZ0b2w9VztZLnJlbG9hZHRpbWU9WDtiLndlYXBvbmRlZnNbUV09WSBlbmQ7ZT1hLmNvcnJlYXAud2VhcG9uZGVmcy5jb3JfcmVhcDtmb3IgaixRIGluIHBhaXJze2xlZ2Nlbj0iZ2F1c3MiLGxlZ2Fza2lybXRhbms9ImxlZ21ncGxhc21hIixsZWdtcnY9InF1aWNrc2hvdF9jYW5ub24iLGxlZ2FuYXZ5YmF0dGxlc2hpcD0iYnVyc3RfcGxhc21hX3QyIn1kbyBpKGopayhRKWMubmFtZT0iTWVkaXVtIFBsYXNtYSBDYW5ub24iYy5pbXBhY3Rvbmx5PWZhbHNlO2xvY2FsIFo9Yy5idXJzdDtuKGMsImltcGFjdG9ubHkiLCJpbXB1bHNlZmFjdG9yIiwid2VhcG9udmVsb2NpdHkiLCJlZGdlZWZmZWN0aXZlbmVzcyIpbG9jYWwgTz1jLmRhbWFnZS5kZWZhdWx0O04oWiljLmJ1cnN0PW5pbDtsb2NhbCBfPW1hdGguY2xhbXAoKGMuZGFtYWdlLmRlZmF1bHQtTykvKGUuZGFtYWdlLmRlZmF1bHQtTyksMCwxK1ovMyljLmFyZWFvZmVmZmVjdD1tYXRoLm1peChjLmFyZWFvZmVmZmVjdCxlLmFyZWFvZmVmZmVjdCxfKWVuZDtlPWEuYXJtYW1iLndlYXBvbmRlZnMuYXJtYW1iX2d1bjtsb2NhbCBmdW5jdGlvbiBhMChqLFEsYTEpaShqKWsoUSlsKGMpbihjLCJjZWd0YWciLCJleHBsb3Npb25nZW5lcmF0b3IiKWxvY2FsIGEyPWQuY2x1c3Rlcl9udW1iZXIgb3IgNTtsb2NhbCBhMz1iLndlYXBvbmRlZnNbYTEgb3IiY2x1c3Rlcl9tdW5pdGlvbiJdLmRhbWFnZS5kZWZhdWx0O04oMSttYXRoLnNxcnQoYTIqYTMvYy5kYW1hZ2UuZGVmYXVsdCkpZC5jbHVzdGVyX2RlZixkLmNsdXN0ZXJfbnVtYmVyPW5pbCxuaWwgZW5kO2ZvciBqLFEgaW4gcGFpcnN7bGVnYW1jbHVzdGVyPSJjbHVzdGVyX2FydGlsbGVyeSIsbGVnY2x1c3Rlcj0icGxhc21hIixsZWdhY2x1c3Rlcj0icGxhc21hIixsZWdscnBjPSJscnBjIixsZWdlYWxsdGVycmFpbm1lY2g9InBsYXNtYV9sb3cifWRvIGEwKGosUSllbmQ7Zm9yIGosUSBpbiBwYWlyc3tsZWdjbHVzdGVyPSJwbGFzbWFfaGlnaCIsbGVnYWNsdXN0ZXI9InBsYXNtYV9oaWdoIixsZWdlYWxsdGVycmFpbm1lY2g9InBsYXNtYV9oaWdoIn1kbyBhMChqLFEpZW5kO2EwKCJsZWdhbmF2eWFydHlzaGlwIiwibGVnX21vYmlsZV9jbHVzdGVyX2xycGNfY2Fubm9uIiwiY2x1c3Rlcl9tdW5pdGlvbl9tYWluIilhMCgibGVnYW5hdnlhcnR5c2hpcCIsImxlZ19tb2JpbGVfY2x1c3Rlcl9wbGFzbWEiLCJjbHVzdGVyX211bml0aW9uX3NlY29uZGFyeSIpaSgibGVnYmFyIikud2VhcG9uZGVmcy5jbHVzdGVybmFwYWxtPXRhYmxlLmNvcHkoYS5sZWdlaG92ZXJ0YW5rLndlYXBvbmRlZnMucGFyYWJvbGljX3JvY2tldHMpYi5zcGVlZD00OTtrKCJjbHVzdGVybmFwYWxtIiljLmFyZWFvZmVmZmVjdD01NjtjLmVkZ2VlZmZlY3RpdmVuZXNzPTAuMjU7Yy5leHBsb3Npb25nZW5lcmF0b3I9ImN1c3RvbTpnZW5lcmljc2hlbGxleHBsb3Npb24tc21hbGwtYm9tYiJjLmJ1cnN0PTM7Yy5idXJzdHJhdGU9MC40O2MucmFuZ2U9NjEwO2Mud2VhcG9udmVsb2NpdHk9MjYwO2koImxlZ2JhcnQiKS53ZWFwb25kZWZzLmNsdXN0ZXJuYXBhbG09dGFibGUuY29weShhLmFybWZpZG8ud2VhcG9uZGVmcy5iZmlkbylGKDAuODUpaSgibGVnaW5mIikud2VhcG9uZGVmcy5yYXBpZG5hcGFsbT10YWJsZS5jb3B5KGEuY29ydHJlbS53ZWFwb25kZWZzLnRyZW1vcl9zcHJlYWRfZmlyZSlrKCJyYXBpZG5hcGFsbSIpYy5idXJzdD0zO2MuYnVyc3RyYXRlPTAuMzMzMztjLnJlbG9hZHRpbWU9MjtjLm15Z3Jhdml0eT0wLjE4O2MucmFuZ2U9MTIwMDtjLndlYXBvbnZlbG9jaXR5PTQ2MDthLmxlZ3BlcmRpdGlvbi53ZWFwb25kZWZzLm5hcGFsbW1pc3NpbGU9dGFibGUuY29weShhLmNvcnRyb24ud2VhcG9uZGVmcy5jb3J0cm9uX3dlYXBvbilpKCJsZWdtZWQiKS53ZWFwb25kZWZzLmxhc2VyPXRhYmxlLmNvcHkoYS5jb3Jhay53ZWFwb25kZWZzLmdhdG9yX2xhc2VyKWIud2VhcG9uc1sxXS5iYWR0YXJnZXRjYXRlZ29yeT0iVlRPTCJiLndlYXBvbnNbMl0uYmFkdGFyZ2V0Y2F0ZWdvcnk9IlZUT0wiYi53ZWFwb25zWzJdLnNsYXZldG89bmlsO2soImxlZ21lZF9taXNzaWxlIikuY3VzdG9tcGFyYW1zPXtjcnVpc2VfbWF4X2hlaWdodD00MCxjcnVpc2VfbWluX2hlaWdodD0xNSxsb2Nrb25fZGlzdD0xMDAsc3BlY2VmZmVjdD0iY3J1aXNlIixwcm9qZWN0aWxlX2Rlc3RydWN0aW9uX21ldGhvZD0iZGVzY2VuZCIsb3ZlcnJhbmdlX2Rpc3RhbmNlPTEwOTN9ZT1jO2soImxhc2VyIikucmFuZ2U9ZS5yYW5nZTtpKCJsZWdjaWIiKWsoImp1bm9fcHVsc2VfbWluaSIpYi53ZWFwb25kZWZzLmVtcF9wdWxzZT10YWJsZS5jb3B5KGMpYi53ZWFwb25zWzFdLmRlZj0iZW1wX3B1bHNlImIud2VhcG9uZGVmcy5qdW5vX3B1bHNlX21pbmk9bmlsO2soImVtcF9wdWxzZSIpYy5jdXN0b21wYXJhbXM9bmlsO2MucGFyYWx5emVyPXRydWU7Yy5wYXJhbHl6ZXRpbWU9NTtjLmFyZWFvZmVmZmVjdD00MjA7Yy5lZGdlZWZmZWN0aXZlbmVzcz0wO2MuZGFtYWdlLmRlZmF1bHQ9MzAwO2MuZGFtYWdlLnZ0b2w9MTA7YS5sZWdhbXBoLndlYXBvbmRlZnMuaGVhdF9yYXk9dGFibGUuY29weShhLmNvcm1hdy53ZWFwb25kZWZzLmRtYXcpYS5sZWdhbXBoLndlYXBvbmRlZnMuY29heF9kZXB0aGNoYXJnZT10YWJsZS5jb3B5KGEuY29ybW9ydC53ZWFwb25kZWZzLmNvcl9tb3J0KWEubGVnYW1waC53ZWFwb25zWzJdLm9ubHl0YXJnZXRjYXRlZ29yeT0iU1VSRkFDRSJmb3IgbyxqIGluIGlwYWlyc3sibGVna2FyayIsImxlZ2FtcGgiLCJsZWdzaG90In1kbyBpKGopbChiKWxvY2FsIGE0PTEvYi5kYW1hZ2Vtb2RpZmllcjtsb2NhbCBhNT1kLnJlYWN0aXZlX2FybW9yX2hlYWx0aDtsb2NhbCBhNj1hNSooMC41K21hdGguc3FydChhNSphNC9iLmhlYWx0aCkqKGE0LTEpKWIuaGVhbHRoPWIuaGVhbHRoK2E2O2QucmVhY3RpdmVfYXJtb3JfaGVhbHRoPW5pbDtkLnJlYWN0aXZlX2FybW9yX3Jlc3RvcmU9bmlsIGVuZDtlPWEuYXJtZmlnO2ZvciBqLFEgaW4gcGFpcnN7bGVnaGl2ZT0icGxhc21hIixsZWdmaGl2ZT0icGxhc21hIixsZWdzcGNhcnJpZXI9ImxlZ19kcm9uZV9jb250cm9sbGVyIixsZWd2Y2Fycnk9InRhcmdldGluZyIsbGVnYW5hdnlhbnRpbnVrZWNhcnJpZXI9ImxlZ19kcm9uZV9jb250cm9sbGVyIn1kbyBhW2pdLndlYXBvbmRlZnNbUV0ucmFuZ2U9MTYwMDthW2pdLndlYXBvbmRlZnNbUV0uY3VzdG9tcGFyYW1zLmNhcnJpZWRfdW5pdD0ibGVnZmlnImFbal0ud2VhcG9uZGVmc1tRXS5jdXN0b21wYXJhbXMuY29udHJvbHJhZGl1cz0xNjAwO2Fbal0ud2VhcG9uZGVmc1tRXS5jdXN0b21wYXJhbXMubWV0YWxjb3N0PWUubWV0YWxjb3N0O2Fbal0ud2VhcG9uZGVmc1tRXS5jdXN0b21wYXJhbXMuZW5lcmd5Y29zdD1lLmVuZXJneWNvc3Q7YVtqXS53ZWFwb25zWzFdLm9ubHl0YXJnZXRjYXRlZ29yeT0iVlRPTCJhW2pdLndlYXBvbnNbMV0uYmFkdGFyZ2V0Y2F0ZWdvcnk9IkxJR0hUQUlSU0NPVVQiRigwLjc1KWVuZDthLmxlZ2xvYi53ZWFwb25zWzJdPW5pbDtpKCJsZWdtZyIpaygiYXJtbWdfd2VhcG9uIiliLmNhbnRiZXRyYW5zcG9ydGVkPXRydWU7RigxLjA3KWMucmFuZ2U9NjIwO2Mub3duZXJFeHBBY2NXZWlnaHQ9MjtjLmFjY3VyYWN5PTEwMDtjLnNwcmF5YW5nbGU9ODgwO2koImxlZ25hdnlmcmlnYXRlIikud2VhcG9uc1sxXS5vbmx5dGFyZ2V0Y2F0ZWdvcnk9Ik5PVFNVQiJiLndlYXBvbnNbMl09bmlsO0YoMC44NSllPWEubGVnbmF2eWFydHlzaGlwO2koImxlZ25hdnlkZXN0cm8iKW4oYiwiYnVpbGRwaWMiLCJjb2xsaXNpb252b2x1bWVvZmZzZXRzIiwiY29sbGlzaW9udm9sdW1lc2NhbGVzIiwiY29sbGlzaW9udm9sdW1ldHlwZSIsIm9iamVjdG5hbWUiLCJzY3JpcHQiKWIud2VhcG9uc1syXT10YWJsZS5jb3B5KGEuY29ycm95LndlYXBvbnNbMl0pYi53ZWFwb25kZWZzLmRlcHRoY2hhcmdlPXRhYmxlLmNvcHkoYS5jb3Jyb3kud2VhcG9uZGVmcy5kZXB0aGNoYXJnZSliLndlYXBvbmRlZnMuZHJvbmVfY29udHJvbF9tYXRyaXg9bmlsO0YoMS4wOClhLmxldm5hdnlhcnR5c2hpcD1uaWw7ZT1hLmFybWZpZztpKCJsZWdmaWciKW4oYiwiYnVpbGR0aW1lIiwiZW5lcmd5Y29zdCIsIm1ldGFsY29zdCIsInNwZWVkIiwidHVybnJhZGl1cyIpYi53ZWFwb25kZWZzLnNlbWlhdXRvPXRhYmxlLmNvcHkoZS53ZWFwb25kZWZzLmFybXZ0b2xfbWlzc2lsZSliLndlYXBvbnNbMV0ubWF4YW5nbGVkaWY9bmlsO2EubGVna2FtPXRhYmxlLmNvcHkoYS5hcm10aHVuZCl0YWJsZS5pbnNlcnQoYS5sZWdhcC5idWlsZG9wdGlvbnMsImNvcmZpbmsiKWEubGVnZmxvYXQubW92ZW1lbnRjbGFzcz0iTVRBTkszImEubGVnZmxvYXQud2F0ZXJsaW5lPW5pbDthLmxlZ2Zsb2F0LmZsb2F0ZXI9bmlsO2koImxlZ2FuYXZ5YmF0dGxlc2hpcCIpLm1vdmVtZW50Y2xhc3M9IkJPQVQ5IkYoMC44OClhLmxlZ3Bob2VuaXg9bmlsO2koImxlZ21pbmViIikud2VhcG9uZGVmcy5jb3Jfc2VhYWR2Ym9tYj10YWJsZS5jb3B5KGEuY29yaHVyYy53ZWFwb25kZWZzLmNvcmFkdmJvbWIpRigwLjk0KWkoImxlZ3JhbXBhcnQiKS5yYWRhcmRpc3RhbmNlamFtPW5pbDtiLndlYXBvbnNbMl09bmlsO0YoMC45KWEubGVnZWxycGNtZWNoPW5pbDthLmxlZ2VhbGx0ZXJyYWlubWVjaC53ZWFwb25zWzVdPW5pbDthLmxlZ3N0YXJmYWxsPXRhYmxlLmNvcHkoYS5hcm12dWxjKQ

