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
	if not add_m then add_m = 0 end
	if not add_e then
		add_e = add_m * (unitDef[metalcost] and unitDef[metalcost] > 0 and unitDef[energycost] / unitDef[metalcost] or m2e)
	end
	if not add_bp then
		add_bp = add_m * (unitDef[metalcost] and unitDef[metalcost] > 0 and unitDef[buildtime] / unitDef[metalcost] or m2b)
	end
	local metal = neat(unitDef[metalcost] * mult + add_m, 10)
	unitDef[metalcost] = metal
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

ref = UD.armfig
for name, wname in pairs { leghive = "plasma", legfhive = "plasma", legspcarrier = "leg_drone_controller", legvcarry = "targeting", leganavyantinukecarrier = "leg_drone_controller" } do
	if unit(name) and weapon(wname) then
		costs(0.75)
		unitDef[weapons][1][onlytargetcategory] = "VTOL"
		unitDef[weapons][1][badtargetcategory] = "LIGHTAIRSCOUT"
		weaponDef.range = 1600
		custom(weaponDef)
		cparams.carried_unit = "legfig"
		cparams.controlradius = 1600
		cparams[metalcost] = ref[metalcost]
		cparams[energycost] = ref[energycost]
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

> bG9jYWwgYT1Vbml0RGVmcztsb2NhbCBiLGMsZCxlO2xvY2FsIGY9ezIsNCw1LDgsMTIsMjAsNTAsMTI1LDI1MH1sb2NhbCBnLGg9NjAsMzA7bG9jYWwgaSxqPSJ3ZWFwb25zIiwid2VhcG9uZGVmcyJsb2NhbCBrLGwsbT0ibWV0YWxjb3N0IiwiZW5lcmd5Y29zdCIsImJ1aWxkdGltZSJsb2NhbCBuPSJvbmx5dGFyZ2V0Y2F0ZWdvcnkibG9jYWwgbz0iYmFkdGFyZ2V0Y2F0ZWdvcnkibG9jYWwgZnVuY3Rpb24gcChxKWI9YVtxXXJldHVybiBiIGVuZDtsb2NhbCBmdW5jdGlvbiByKHEpYz1iW2pdW3FdcmV0dXJuIGMgZW5kO2xvY2FsIGZ1bmN0aW9uIHModClkPXQuY3VzdG9tcGFyYW1zIG9ye310LmN1c3RvbXBhcmFtcz1kO3JldHVybiBkIGVuZDtsb2NhbCBmdW5jdGlvbiB1KHEsdClsb2NhbCB2PXRhYmxlLmNvcHkodCBvciBlKWJbal1bcV09djtyZXR1cm4gdiBlbmQ7bG9jYWwgZnVuY3Rpb24gdyh0LC4uLilmb3IgeCx5IGluIGlwYWlycyh7Li4ufSlkbyB0W3ldPWVbeV1lbmQgZW5kO2xvY2FsIGZ1bmN0aW9uIHooQSxCKWlmIEIgdGhlbiBBPUEvQiBlbHNlIEI9MSBlbmQ7aWYgQTw9MzAgdGhlbiByZXR1cm4gbWF0aC5mbG9vcihBKzAuNSkqQiBlbmQ7bG9jYWwgQz17fWZvciB4LEQgaW4gaXBhaXJzKGYpZG8gQ1tEXT1tYXRoLmZsb29yKEEvRCswLjUpKkQgZW5kO2xvY2FsIEU9Q1tmWzFdXWxvY2FsIEY9RS1BO0Y9RipGL2ZbMV1mb3IgRz0yLCNmIGRvIGxvY2FsIEg9ZltHXWxvY2FsIEk9Q1tIXS1BO0k9SSpJL2ZbR11pZiBGPkkgdGhlbiBFPUNbSF1GPUkgZW5kIGVuZDtyZXR1cm4gRSpCIGVuZDtsb2NhbCBmdW5jdGlvbiBKKEssTCxNLE4sQilsb2NhbCBBPXRvbnVtYmVyKEtbTF0paWYgdHlwZShBKT09Im51bWJlciJ0aGVuIEtbTF09eihBKihNIG9yIDEpKyhOIG9yIDApLEIpZW5kIGVuZDtsb2NhbCBmdW5jdGlvbiBPKE0sUCxRLFIpaWYgbm90IFAgdGhlbiBQPTAgZW5kO2lmIG5vdCBRIHRoZW4gUT1QKihiW2tdYW5kIGJba10-MCBhbmQgYltsXS9iW2tdb3IgZyllbmQ7aWYgbm90IFIgdGhlbiBSPVAqKGJba11hbmQgYltrXT4wIGFuZCBiW21dL2Jba11vciBoKWVuZDtsb2NhbCBTPXooYltrXSpNK1AsMTApYltrXT1TO0ooYixsLE0sUSwxMClKKGIsbSxNLFIsMTApZW5kO2xvY2FsIGZ1bmN0aW9uIFQoTSxOKWZvciBVIGluIHBhaXJzKGMuZGFtYWdlKWRvIEooYy5kYW1hZ2UsVSxNLE4pZW5kO3JldHVybiBjLmRhbWFnZSBlbmQ7ZT1wKCJsZWdjb20iKVtpXWVbMV1bbl09Ik5PVFNVQiJlWzFdLmZhc3RhdXRvcmV0YXJnZXRpbmc9dHJ1ZTtlWzRdPW5pbDtlPWEuYXJtY29tW2pddSgibGVnY29tbGFzZXIiLGUuYXJtY29tbGFzZXIpdSgidG9ycGVkbyIsZS5hcm1jb21zZWFsYXNlcilpZiBwKCJsZWdtZXgiKXRoZW4gYi5leHRyYWN0c21ldGFsPTAuMDAxO2IuZW5lcmd5dXBrZWVwPTMgZW5kO2ZvciB4LHEgaW4gcGFpcnN7ImxlZ2thcmsiLCJsZWdnYXQifWRvIGlmIHAocSl0aGVuIE8oMC45KUooYiwiaGVhbHRoIiwwLjkpSihiLCJzcGVlZCIsMS4wNylmb3IgViBpbiBwYWlycyhiW2pdKWRvIHIoVilUKDAuOTIpZW5kIGVuZCBlbmQ7bG9jYWwgZnVuY3Rpb24gVyhYKWxvY2FsIFk9bWF0aC5zcXJ0KFQoKS5kZWZhdWx0L2UuZGFtYWdlLmRlZmF1bHQpKihYIG9yIDEpKzAuNS0oWCBvciAxKSowLjU7WT1ZLygoYy5iZWFtdGltZSBvciAxLzMwKSozMClKKGMsImNvcmV0aGlja25lc3MiLFkpSihjLCJ0aGlja25lc3MiLFkpSihjLCJsYXNlcmZsYXJlc2l6ZSIsWSowLjErMC45KWVuZDtsb2NhbCBmdW5jdGlvbiBaKHEsVilpZiBwKHEpYW5kIHIoVil0aGVuIGlmIGMuYXJlYW9mZWZmZWN0Pj00MCBhbmQgYy5pbXBhY3Rvbmx5fj0xIHRoZW4gTygwLjk1KWVuZDt3KGMsImltcGFjdG9ubHkiLCJhcmVhb2ZlZmZlY3QiLCJjb3JldGhpY2tuZXNzIiwiZXhwbG9zaW9uZ2VuZXJhdG9yIiwiaW50ZW5zaXR5IiwibGFzZXJmbGFyZXNpemUiLCJyZ2Jjb2xvciIsInRoaWNrbmVzcyIsInNpemUiLCJzb3VuZGhpdGRyeSIsInNvdW5kaGl0d2V0IilXKCllbmQgZW5kO2U9YS5hcm1sbHRbal0uYXJtX2xpZ2h0bGFzZXI7Zm9yIHEsViBpbiBwYWlyc3tsZWdpbmZlc3Rvcj0iZmVzdG9yYmVhbSIsbGVnbGh0PSJoZWF0X3JheSIsbGVnc2g9ImhlYXRfcmF5IixsZWdoZWxpb3M9ImhlYXRfcmF5In1kbyBaKHEsVillbmQ7ZT1hLmFybWJlYW1lcltqXS5hcm1iZWFtZXJfd2VhcG9uO2ZvciBxLFYgaW4gcGFpcnN7bGVnaGVhdnlkcm9uZT0iaGVhdF9yYXkiLGxlZ2luYz0iaGVhdHJheWxhcmdlIixsZWdrYXJrPSJoZWF0X3JheSIsbGVnYmFzdGlvbj0idDJoZWF0cmF5IixsZWdhbmF2eWZsYWdzaGlwPSJsZWdfZXhwZXJpbWVudGFsX2hlYXRyYXkiLGxlZ25hdnlkZXN0cm89ImxlZ19tZWRpdW1faGVhdHJheSIsbGVnZWhlYXRyYXltZWNoPSJoZWF0cmF5MSIsbGVnZWhvdmVydGFuaz0iaGVhdF9yYXkiLGxlZ2FoZWF0dGFuaz0iaGVhdF9yYXkifWRvIFoocSxWKWVuZDtlPWEuY29yaGx0W2pdLmNvcl9sYXNlcmgxO2ZvciBxLFYgaW4gcGFpcnN7bGVncmFpbD0icmFpbGd1biIsbGVnc3JhaWw9InJhaWxndW50MiIsbGVnYW5hdnlmbGFnc2hpcD0ibGVnX2V4cGVyaW1lbnRhbF9yYWlsZ3VuIixsZWdlcmFpbHRhbms9InQzX3JhaWxfYWNjZWxlcmF0b3IifWRvIGlmIHAocSlhbmQgcihWKXRoZW4gcyhjKWMubmFtZT0iSGVhdnkgTGFzZXIidyhjLCJ3ZWFwb250eXBlIiwiYmVhbXRpbWUiLCJpbXB1bHNlZmFjdG9yIiwibm9leHBsb2RlIiwiY29yZXRoaWNrbmVzcyIsImV4cGxvc2lvbmdlbmVyYXRvciIsImludGVuc2l0eSIsImxhc2VyZmxhcmVzaXplIiwicmdiY29sb3IiLCJ0aGlja25lc3MiLCJzaXplIiwic291bmRoaXRkcnkiLCJzb3VuZGhpdHdldCIsInNvdW5kc3RhcnQiLCJjeWxpbmRlcnRhcmdldGluZyIsImltcGFjdG9ubHkiLCJwcmVkaWN0Ym9vc3QiKWMud2VhcG9udmVsb2NpdHk9Yy5yYW5nZSsxMDA7ZC5vdmVycGVuZXRyYXRlPW5pbDtUKDEuMylXKDAuNjY2NyllbmQgZW5kO2ZvciBxLFYgaW4gcGFpcnN7bGVncmFpbD0iYWFfcmFpbGd1biIsbGVnYWR2YWFib3Q9ImFhX3JhaWxndW4ifWRvIGlmIHAocSlhbmQgcihWKXRoZW4gbG9jYWwgXz1jLnJhbmdlO2xvY2FsIGEwPWMuZGFtYWdlLnZ0b2w7bG9jYWwgYTE9Yy5yZWxvYWR0aW1lO2M9dShWLGEuYXJtYWFrW2pdLmxvbmdyYW5nZW1pc3NpbGUpYy5yYW5nZT1fO2MuZGFtYWdlLnZ0b2w9YTA7Yy5yZWxvYWR0aW1lPWExIGVuZCBlbmQ7ZT1hLmNvcnJlYXBbal0uY29yX3JlYXA7Zm9yIHEsViBpbiBwYWlyc3tsZWdjZW49ImdhdXNzIixsZWdhc2tpcm10YW5rPSJsZWdtZ3BsYXNtYSIsbGVnbXJ2PSJxdWlja3Nob3RfY2Fubm9uIixsZWdhbmF2eWJhdHRsZXNoaXA9ImJ1cnN0X3BsYXNtYV90MiJ9ZG8gaWYgcChxKWFuZCByKFYpdGhlbiBjLm5hbWU9Ik1lZGl1bSBQbGFzbWEgQ2Fubm9uImMuaW1wYWN0b25seT1mYWxzZTtsb2NhbCBhMj1jLmJ1cnN0O3coYywiaW1wYWN0b25seSIsImltcHVsc2VmYWN0b3IiLCJ3ZWFwb252ZWxvY2l0eSIsImVkZ2VlZmZlY3RpdmVuZXNzIilsb2NhbCBhMz1jLmRhbWFnZS5kZWZhdWx0O1QoYTIpYy5idXJzdD1uaWw7bG9jYWwgYTQ9bWF0aC5jbGFtcCgoYy5kYW1hZ2UuZGVmYXVsdC1hMykvKGUuZGFtYWdlLmRlZmF1bHQtYTMpLDAsMSthMi8zKWMuYXJlYW9mZWZmZWN0PW1hdGgubWl4KGMuYXJlYW9mZWZmZWN0LGUuYXJlYW9mZWZmZWN0LGE0KWVuZCBlbmQ7bG9jYWwgZnVuY3Rpb24gYTUocSxWLGE2KWlmIHAocSlhbmQgcihWKXRoZW4gZT1hLmFybWFtYltqXS5hcm1hbWJfZ3VuO3coYywiY2VndGFnIiwiZXhwbG9zaW9uZ2VuZXJhdG9yIilsb2NhbCBhNz1zKGMpLmNsdXN0ZXJfbnVtYmVyIG9yIDU7VCgxK21hdGguc3FydChhNypyKGE2IG9yImNsdXN0ZXJfbXVuaXRpb24iKS5kYW1hZ2UuZGVmYXVsdC9yKFYpLmRhbWFnZS5kZWZhdWx0KSlkLmNsdXN0ZXJfZGVmLGQuY2x1c3Rlcl9udW1iZXI9bmlsLG5pbCBlbmQgZW5kO2ZvciBxLFYgaW4gcGFpcnN7bGVnYW1jbHVzdGVyPSJjbHVzdGVyX2FydGlsbGVyeSIsbGVnY2x1c3Rlcj0icGxhc21hIixsZWdhY2x1c3Rlcj0icGxhc21hIixsZWdscnBjPSJscnBjIixsZWdlYWxsdGVycmFpbm1lY2g9InBsYXNtYV9sb3cifWRvIGE1KHEsVillbmQ7Zm9yIHEsViBpbiBwYWlyc3tsZWdjbHVzdGVyPSJwbGFzbWFfaGlnaCIsbGVnYWNsdXN0ZXI9InBsYXNtYV9oaWdoIixsZWdlYWxsdGVycmFpbm1lY2g9InBsYXNtYV9oaWdoIn1kbyBhNShxLFYpZW5kO2E1KCJsZWdhbmF2eWFydHlzaGlwIiwibGVnX21vYmlsZV9jbHVzdGVyX2xycGNfY2Fubm9uIiwiY2x1c3Rlcl9tdW5pdGlvbl9tYWluIilhNSgibGVnYW5hdnlhcnR5c2hpcCIsImxlZ19tb2JpbGVfY2x1c3Rlcl9wbGFzbWEiLCJjbHVzdGVyX211bml0aW9uX3NlY29uZGFyeSIpaWYgcCgibGVnYmFyIil0aGVuIGIuc3BlZWQ9NDk7Yz11KCJjbHVzdGVybmFwYWxtIixhLmxlZ2Vob3ZlcnRhbmtbal0ucGFyYWJvbGljX3JvY2tldHMpYy5hcmVhb2ZlZmZlY3Q9NTY7Yy5lZGdlZWZmZWN0aXZlbmVzcz0wLjI1O2MuZXhwbG9zaW9uZ2VuZXJhdG9yPSJjdXN0b206Z2VuZXJpY3NoZWxsZXhwbG9zaW9uLXNtYWxsLWJvbWIiYy5idXJzdD0zO2MuYnVyc3RyYXRlPTAuNDtjLnJhbmdlPTYxMDtjLndlYXBvbnZlbG9jaXR5PTI2MCBlbmQ7aWYgcCgibGVnYmFydCIpdGhlbiB1KCJjbHVzdGVybmFwYWxtIixhLmFybWZpZG9bal0uYmZpZG8pTygwLjg1KWVuZDtpZiBwKCJsZWdpbmYiKXRoZW4gYz11KCJyYXBpZG5hcGFsbSIsYS5jb3J0cmVtW2pdLnRyZW1vcl9zcHJlYWRfZmlyZSljLmJ1cnN0PTM7Yy5idXJzdHJhdGU9MC4zMzMzO2MucmVsb2FkdGltZT0yO2MubXlncmF2aXR5PTAuMTg7Yy5yYW5nZT0xMjAwO2Mud2VhcG9udmVsb2NpdHk9NDYwIGVuZDtpZiBwKCJsZWdwZXJkaXRpb24iKXRoZW4gdSgibmFwYWxtbWlzc2lsZSIsYS5jb3J0cm9uW2pdLmNvcnRyb25fd2VhcG9uKWVuZDtpZiBwKCJsZWdtZWQiKXRoZW4gdSgibGFzZXIiLGEuY29yYWtbal0uZ2F0b3JfbGFzZXIpYltpXVsxXVtvXT0iVlRPTCJiW2ldWzJdW29dPSJWVE9MImJbaV1bMl0uc2xhdmV0bz1uaWw7cigibGVnbWVkX21pc3NpbGUiKS5jdXN0b21wYXJhbXM9e2NydWlzZV9tYXhfaGVpZ2h0PTQwLGNydWlzZV9taW5faGVpZ2h0PTE1LGxvY2tvbl9kaXN0PTEwMCxzcGVjZWZmZWN0PSJjcnVpc2UiLHByb2plY3RpbGVfZGVzdHJ1Y3Rpb25fbWV0aG9kPSJkZXNjZW5kIixvdmVycmFuZ2VfZGlzdGFuY2U9MTA5M31lPWM7cigibGFzZXIiKS5yYW5nZT1lLnJhbmdlIGVuZDtpZiBwKCJsZWdjaWIiKWFuZCByKCJqdW5vX3B1bHNlX21pbmkiKXRoZW4gYltpXVsxXS5kZWY9ImVtcF9wdWxzZSJjPXUoImVtcF9wdWxzZSIsYyliW2pdLmp1bm9fcHVsc2VfbWluaT1uaWw7Yy5jdXN0b21wYXJhbXM9bmlsO2MucGFyYWx5emVyPXRydWU7Yy5wYXJhbHl6ZXRpbWU9NTtjLmFyZWFvZmVmZmVjdD00MjA7Yy5lZGdlZWZmZWN0aXZlbmVzcz0wO2MuZGFtYWdlLmRlZmF1bHQ9MzAwO2MuZGFtYWdlLnZ0b2w9MTAgZW5kO2lmIHAoImxlZ2FtcGgiKXRoZW4gdSgiaGVhdF9yYXkiLGEuY29ybWF3W2pdLmRtYXcpdSgiY29heF9kZXB0aGNoYXJnZSIsYS5jb3Jtb3J0W2pdLmNvcl9tb3J0KWJbaV1bMl1bbl09IlNVUkZBQ0UiZW5kO2ZvciB4LHEgaW4gcGFpcnN7ImxlZ2thcmsiLCJsZWdhbXBoIiwibGVnc2hvdCJ9ZG8gaWYgcChxKXRoZW4gcyhiKWxvY2FsIGE4PTEvYi5kYW1hZ2Vtb2RpZmllcjtsb2NhbCBhOT1kLnJlYWN0aXZlX2FybW9yX2hlYWx0aDtkLnJlYWN0aXZlX2FybW9yX2hlYWx0aD1uaWw7ZC5yZWFjdGl2ZV9hcm1vcl9yZXN0b3JlPW5pbDtsb2NhbCBhYT1hOSooMC41K21hdGguc3FydChhOSphOC9iLmhlYWx0aCkqKGE4LTEpKWIuaGVhbHRoPWIuaGVhbHRoK2FhIGVuZCBlbmQ7ZT1hLmFybWZpZztmb3IgcSxWIGluIHBhaXJze2xlZ2hpdmU9InBsYXNtYSIsbGVnZmhpdmU9InBsYXNtYSIsbGVnc3BjYXJyaWVyPSJsZWdfZHJvbmVfY29udHJvbGxlciIsbGVndmNhcnJ5PSJ0YXJnZXRpbmciLGxlZ2FuYXZ5YW50aW51a2VjYXJyaWVyPSJsZWdfZHJvbmVfY29udHJvbGxlciJ9ZG8gaWYgcChxKWFuZCByKFYpdGhlbiBPKDAuNzUpYltpXVsxXVtuXT0iVlRPTCJiW2ldWzFdW29dPSJMSUdIVEFJUlNDT1VUImMucmFuZ2U9MTYwMDtzKGMpZC5jYXJyaWVkX3VuaXQ9ImxlZ2ZpZyJkLmNvbnRyb2xyYWRpdXM9MTYwMDtkW2tdPWVba11kW2xdPWVbbF1lbmQgZW5kO2lmIHAoImxlZ2xvYiIpdGhlbiBiW2ldWzJdPW5pbCBlbmQ7aWYgcCgibGVnbWciKWFuZCByKCJhcm1tZ193ZWFwb24iKXRoZW4gYi5jYW50YmV0cmFuc3BvcnRlZD10cnVlO08oMS4wNyljLnJhbmdlPTYyMDtjLm93bmVyRXhwQWNjV2VpZ2h0PTI7Yy5hY2N1cmFjeT0xMDA7Yy5zcHJheWFuZ2xlPTg4MCBlbmQ7aWYgcCgibGVnZmxvYXQiKXRoZW4gYi5tb3ZlbWVudGNsYXNzPSJNVEFOSzMiYi53YXRlcmxpbmU9bmlsO2IuZmxvYXRlcj1uaWwgZW5kO2lmIHAoImxlZ25hdnlmcmlnYXRlIil0aGVuIGJbaV1bMV1bbl09Ik5PVFNVQiJiW2ldWzJdPW5pbDtPKDAuODUpZW5kO2lmIHAoImxlZ25hdnlkZXN0cm8iKXRoZW4gZT1hLmxlZ25hdnlhcnR5c2hpcDt3KGIsImJ1aWxkcGljIiwiY29sbGlzaW9udm9sdW1lb2Zmc2V0cyIsImNvbGxpc2lvbnZvbHVtZXNjYWxlcyIsImNvbGxpc2lvbnZvbHVtZXR5cGUiLCJvYmplY3RuYW1lIiwic2NyaXB0Iil1KCJkZXB0aGNoYXJnZSIsYS5jb3Jyb3lbal0uZGVwdGhjaGFyZ2UpYltpXVsyXT10YWJsZS5jb3B5KGEuY29ycm95W2ldWzJdKWJbal0uZHJvbmVfY29udHJvbF9tYXRyaXg9bmlsO08oMS4wOCllbmQ7aWYgcCgibGVnYW5hdnliYXR0bGVzaGlwIil0aGVuIGIubW92ZW1lbnRjbGFzcz0iQk9BVDkiTygwLjg4KWVuZDtpZiBwKCJsZWdhcCIpdGhlbiB0YWJsZS5pbnNlcnQoYi5idWlsZG9wdGlvbnMsImNvcmZpbmsiKWVuZDtpZiBwKCJsZWdmaWciKXRoZW4gZT1hLmFybWZpZzt3KGIsbSxsLGssInNwZWVkIiwidHVybnJhZGl1cyIpdSgic2VtaWF1dG8iLGVbal0uYXJtdnRvbF9taXNzaWxlKWJbaV1bMV0ubWF4YW5nbGVkaWY9bmlsIGVuZDthLmxlZ2thbT10YWJsZS5jb3B5KGEuYXJtdGh1bmQpYS5sZWdwaG9lbml4PW5pbDtpZiBwKCJsZWdtaW5lYiIpdGhlbiB1KCJjb3Jfc2VhYWR2Ym9tYiIsYS5jb3JodXJjW2pdLmNvcmFkdmJvbWIpTygwLjk0KWVuZDtpZiBwKCJsZWdyYW1wYXJ0Iil0aGVuIGIucmFkYXJkaXN0YW5jZWphbT1uaWw7YltpXVsyXT1uaWw7TygwLjkpZW5kO2EubGVnZWxycGNtZWNoPW5pbDtpZiBwKCJsZWdlYWxsdGVycmFpbm1lY2giKXRoZW4gYltpXVs1XT1uaWw7TygwLjkpZW5kO2EubGVnc3RhcmZhbGw9dGFibGUuY29weShhLmFybXZ1bGMp

