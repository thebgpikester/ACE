--Another Campaign Engine by Pikey 2023 v1.3 (May 2024)
--Requires MOOSE.lua to be loaded first. 
--Requires your installation to be modified so that require, io, and lfs are not sanitized.

-- Caucasus, Falklands, MarianaIslands, Normandy, PersianGulf, Syria, Kola supported
-- at time of writing "Sinai" not supported because it has no published towns file in the terrain.

--WHAT IT DOES
--Scans all towns in the zone called 'zone', writes them to table. This happens once only.
--Performs a long scan of each zone included in that zone to give an importance score.
--Sends the final list to MOOSE STRATEGO for processing towns into enhanced nodes
--Creates strategic zones from towns by importance
--sets up two AI sides to fight over them.

--HOW TO USE
--The only supported configuration is via the supplied demo. It's released as working. After that use it as you like, in whole or in part, on your own.
--The script requires a single zone called 'zone' that is the limit of the area, 
-- three zones for sides, Blue Border, Contested and Red Border.
-- a RedBase zone and a Blue Base zone to be placed at each extremity of the play area.
-- a 'Blue Spawn' and a 'Red Spawn' zones for ground troops ot appear at.
--Each side must have three warehouses of that coalition: blue brigade, blue airwing and blue airwing2
--Each side must have 6 ground tmeplates named exactly as per the demo, 2 helicopters (attack and transport) named exactly and 2 fixed wing, CAP and cas named exactly as per demo.
--Names are all case sensitive, its a lua thing.
--Change debug to false below to not get the zones marked and tactical overviews.
--
--WHAT IS EXPECTED TO HAPPEN?
--For the first ten minutes each side places its troops in zones.
--It will begin to try to capture empty zones or send attack waves to occupied zones.
--There is a defensive CAP
----------------------------

local mapname = UTILS.GetDCSMap()
local path = "\\Mods\\terrains\\"..mapname.."\\Map\\towns.lua" --NO NEED TO EDIT
local mappath = ace.folder..path
local sFile = mapname.."Towns.lua"
local savepath = lfs.writedir().."\\"..sFile
local zone =  ZONE:New('zone') --name of the inclusion zone
local minDistanceToRoad = 500 -- The distance in Metres that any road has to be, in order to count as a zone else zone is discarded as being worthless
local scanRadius = 1000 -- 500=30seconds, 800=75seconds (less is faster, but relies on density rather than size)
local zoneRadius = 2000 -- When STRATEGO draws the zone, the radius of the medium sized zone is this in M
local lowThreshold = 10 -- Read the TownsTable and put a manual number roughly seperating the bottom third
local highThreshold = 20 -- Read the TownsTable and put a manual number roughly seperating the top third 
local railmultiplication = 2 --multiplication factor of importance if there is nearby railway
local TownMax = 30 --Maximum number of towns to be kept. There are usually many more.
local map = {} --leave it
local BlueBase= "BlueBase"--name of zone on map with furthest extent behind Blue lines 
local RedBase = "RedBase"--name of zone on map with furthest extent behind Red lines
local RedSams = 2 --The number of red sams to be randomly placed in any red zones
local BlueSams = 2 --the number of blue sams to be randomly placed in any blue zones
local ZoneRedBorder=ZONE:New("Red Border")
if ace.debug then ZoneRedBorder:DrawZone() end
local ZoneBlueBorder=ZONE:New("Blue Border")
if ace.debug then ZoneBlueBorder:DrawZone() end
local ZoneContestedBorder=ZONE:New("Contested")
if ace.debug then ZoneContestedBorder:DrawZone() end

--Error check
if lfs then --this is required, remove it if you are  heavily editing and importing twos in some other way.

--FUNCTIONS
function require(text) --stops the attempt to translate localised town names /AppleEvangelist 3/5/2024
 local fakefunction = {}
 fakefunction.translate = function(input) return input end
 return fakefunction
end

function write(data, file)
  local File = io.open(file, "w")
  File:write(data)
  File:close()
end

function file_exists(name) --check if the file already exists for writing
    if lfs.attributes(name) then
    return true
    else
    return false end 
end

function table_has_key(tab, key_val)
    for key, value in pairs(tab) do
        -- env.info(" key is " .. key.. "   key_val is ".. key_val ) 
        if key == key_val then
            return true
        end
    end
    return false
end

function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

function countkeys(t)
  local count=0
for _ in pairs(t) do count = count + 1 end
  return count
end

function deletelowest(t)
local r=1000
local key
  for k,v in pairs(t) do
    if v<r then r=v
    key=k
    else 
    end
  end
  t[key]=nil
  return key
end
----------------------------------
--INTEGRATED SERIALISE WITH CYCLES. The classic and best
----------------------------------
function IntegratedbasicSerialize(s)
    if s == nil then
      return "\"\""
    else
      if ((type(s) == 'number') or (type(s) == 'boolean') or (type(s) == 'function') or (type(s) == 'table') or (type(s) == 'userdata') ) then
        return tostring(s)
      elseif type(s) == 'string' then
        return string.format('%q', s)
      end
    end
  end
-- imported slmod.serializeWithCycles (Speed)
  function IntegratedserializeWithCycles(name, value, saved)
    local basicSerialize = function (o)
      if type(o) == "number" then
        return tostring(o)
      elseif type(o) == "boolean" then
        return tostring(o)
      else -- assume it is a string
        return IntegratedbasicSerialize(o)
      end
    end

    local t_str = {}
    saved = saved or {}       -- initial value
    if ((type(value) == 'string') or (type(value) == 'number') or (type(value) == 'table') or (type(value) == 'boolean')) then
      table.insert(t_str, name .. " = ")
      if type(value) == "number" or type(value) == "string" or type(value) == "boolean" then
        table.insert(t_str, basicSerialize(value) ..  "\n")
      else

        if saved[value] then    -- value already saved?
          table.insert(t_str, saved[value] .. "\n")
        else
          saved[value] = name   -- save name for next time
          table.insert(t_str, "{}\n")
          for k,v in pairs(value) do      -- save its fields
            local fieldname = string.format("%s[%s]", name, basicSerialize(k))
            table.insert(t_str, IntegratedserializeWithCycles(fieldname, v, saved))
          end
        end
      end
      return table.concat(t_str)
    else
      return ""
    end
  end

--------------
--SCENERY SCAN
--------------
function sceneryList(coord,radius)
_,_,_,unitstable,staticstable,scenerytable=coord:ScanObjects(radius, false, false, true)

local temptable={}
local count = 0

for index, SceneryID in pairs(scenerytable) do

    count = count + 1

        local SceneryObject = SCENERY:Register(SceneryID:getTypeName(), SceneryID)
        local scenCoord = SceneryObject:GetCoordinate()
        local name = SceneryObject:GetName()
        temptable[name]=1
end

local counttypes = 0

for _ in pairs(temptable) do counttypes = counttypes + 1 end

return count, counttypes
end

--END OF FUNCTIONS

--SCRIPT START
local NodeZone={}--for zones only
if file_exists(savepath) then
  dofile(savepath)--reads and stores an existing TownTable.lua already on disk
  dofile(mappath)--read and execute the terrain map towns.lua and creates towns table
  map=towns --towns is defined from executing the lua in the directory that says towns={}

else 

dofile(mappath)  
map=towns --towns is defined from executing the lua in the directory that says towns={}
TownTable={}

for townKey, details in pairs(map) do
  local coord=COORDINATE:NewFromLLDD(details.latitude, details.longitude) --make a coordinate from the towns.lua file in the terrain directory 
    if zone:IsCoordinateInZone(coord) then
    
      local road = coord:GetClosestPointToRoad() --railroads?
        if coord:Get2DDistance(road) < minDistanceToRoad then
          coord=road -- shift it to a nice place for travel
          local count, counttypes = sceneryList(coord,scanRadius)
          local _,dist=coord:GetClosestAirbase()
          local rail = coord:GetClosestPointToRoad(true) --rail
            if coord:Get2DDistance(rail) < minDistanceToRoad then
              railmultiplication = 2
            end
          local importance = round(((count/2)*(counttypes))/(dist/2)*railmultiplication,2) --the main algorithm for weighting. can be adjusted.
          TownTable[townKey]=importance --make the TownTable key with numerical importance as value
        end
    end
end

end --end of dofile if not exist

--Delete too many towns
local no = countkeys(TownTable)
for i = 1, no-TownMax do
  deletelowest(TownTable) --keep the top X towns with the highest value
end

--Walk the TownTable to add all those Zones but go back to the map table to get the Vec2 again. It happened this way, dont ask. 
for k,v in pairs (TownTable) do
  local key = map[k]
  local coord=COORDINATE:NewFromLLDD(key.latitude, key.longitude)
  local radius=zoneRadius
    --change the size of the zones
    if v < lowThreshold then radius = radius * 0.9 --small/medium and large radius zones, avoids the outliers that are huge or mini
    elseif v > highThreshold then radius = radius * 1.1 
    end

 NodeZone[k] = ZONE_RADIUS:New("POI-"..k, coord:GetClosestPointToRoad():GetVec2(), radius) --make Zone with a prefix of POI- from the coords for STRATEGO to use thats on a road

end 

local Str = IntegratedserializeWithCycles("TownTable",TownTable) --save TownTable to file as a serialised type e.g.: TownTable["Akrotiri"] = 15.340021407369
write(Str, savepath) --save to disk

--Launch STRATEGO
 Nodes = STRATEGO:New("Nodes",coalition.side.BLUE,10)
 Nodes:SetCaptureOptions(1, 0)
 Nodes:SetDebug(false, ace.debug, false)
 Nodes:SetStrategoZone(zone)
 --Nodes:SetUsingBudget(true, 500)
 Nodes:Start()

--Apply the importance value to each node by walking the TownTable yet again  
 for k,v in pairs(TownTable) do
  Nodes:SetNodeWeight("POI-"..k,v)
 end
 
 --DEBUG
if ace.debug then UTILS.PrintTableToLog(TownTable, 1) end



else--if lfs
  env.info("ERROR: LFS must be available to run this!!!!!!!")
end



--NOW COMES THE AI TEAMS



--==BLUE PLATOONS
local bPlatoon1=PLATOON:New("blueinf", 1000, "Squaddies")
:SetGrouping(5)
bPlatoon1:SetAttribute(GROUP.Attribute.GROUND_INFANTRY)
bPlatoon1:AddMissionCapability({AUFTRAG.Type.PATROLZONE, AUFTRAG.Type.ONGUARD, AUFTRAG.Type.GROUNDATTACK}, 50)

local bPlatoon2=PLATOON:New("bluetruck", 250, "Platoon truck")
:SetGrouping(1)
bPlatoon2:SetAttribute(GROUP.Attribute.GROUND_TRUCK)
bPlatoon2:AddMissionCapability({AUFTRAG.Type.OPSTRANSPORT, AUFTRAG.Type.TROOPTRANSPORT},80)

local bPlatoon3=PLATOON:New("blueIFV", 27, "Platoon IFV")
:SetGrouping(1)
bPlatoon3:SetAttribute(GROUP.Attribute.GROUND_IFV)
bPlatoon3:AddMissionCapability({AUFTRAG.Type.ONGUARD, AUFTRAG.Type.CAPTUREZONE, AUFTRAG.Type.PATROLZONE, AUFTRAG.Type.RECON, AUFTRAG.Type.GROUNDATTACK, AUFTRAG.Type.ARMOREDGUARD, AUFTRAG.Type.ARMORATTACK},80)

local bPlatoon4=PLATOON:New("bluetank", 35, "Platoon tank")
:SetGrouping(3)
bPlatoon4:SetAttribute(GROUP.Attribute.GROUND_TANK)
bPlatoon4:AddMissionCapability({ AUFTRAG.Type.CAPTUREZONE, AUFTRAG.Type.PATROLZONE, AUFTRAG.Type.GROUNDATTACK, AUFTRAG.Type.ARMOREDGUARD, AUFTRAG.Type.ARMORATTACK},100)

local bPlatoon5=PLATOON:New("blueAPC", 125, "Platoon APC")
:SetGrouping(2)
bPlatoon5:SetAttribute(GROUP.Attribute.GROUND_APC)
bPlatoon5:AddMissionCapability({AUFTRAG.Type.TROOPTRANSPORT, AUFTRAG.Type.ONGUARD, AUFTRAG.Type.OPSTRANSPORT},60)

local bPlatoon6=PLATOON:New("blueSAM", 5, "Air Defence Platoon")
:SetGrouping(5)
bPlatoon6:SetAttribute(GROUP.Attribute.GROUND_SAM)
bPlatoon6:AddMissionCapability({AUFTRAG.Type.AIRDEFENSE},100)

--BLUE BRIGADES
local BlueBrigade=BRIGADE:New("blue brigade", "blue brigade")
BlueBrigade:SetSpawnZone(ZONE:New("Blue Spawn"))

BlueBrigade:AddPlatoon(bPlatoon1)
BlueBrigade:AddPlatoon(bPlatoon2)
BlueBrigade:AddPlatoon(bPlatoon3)
BlueBrigade:AddPlatoon(bPlatoon4)
BlueBrigade:AddPlatoon(bPlatoon5)
BlueBrigade:AddPlatoon(bPlatoon6)

-- BLUE AIRWINGS
local blueair=SQUADRON:New("bluehelitransport", 24, "2nd Airlift Helo Squadron")
blueair:SetGrouping(1)
blueair:AddMissionCapability({AUFTRAG.Type.OPSTRANSPORT}, 100)
blueair:SetAttribute(GROUP.Attribute.AIR_TRANSPORTHELO) 
blueair:SetTurnoverTime(10, 30)

local blueairT=SQUADRON:New("blueheli", 24, "1st Atttack helo Squadron")
blueairT:SetGrouping(1)
blueairT:AddMissionCapability({AUFTRAG.Type.CAS}, 75)
blueairT:SetAttribute(GROUP.Attribute.AIR_ATTACKHELO) 
blueairT:SetTurnoverTime(10, 30)

local BlueWing=AIRWING:New("blue airwing", "blue airwing")

local blueair2=SQUADRON:New("bluecas", 24, "3rd Strike Squadron")
blueair2:SetGrouping(1)
blueair2:AddMissionCapability({AUFTRAG.Type.CAS, AUFTRAG.Type.CASENHANCED, AUFTRAG.Type.RECON, AUFTRAG.Type.GROUNDATTACK}, 100)
blueair2:SetAttribute(GROUP.Attribute.AIR_FIGHTER, GROUP.Attribute.AIR_BOMBER) 
blueair2:SetTurnoverTime(20, 30)

local blueair3=SQUADRON:New("bluecap", 8, "4th Air Superiority Squadron")
blueair3:SetGrouping(1)
blueair3:AddMissionCapability({AUFTRAG.Type.CAP, AUFTRAG.Type.INTERCEPT,AUFTRAG.Type.GCICAP }, 100)
blueair3:SetAttribute(GROUP.Attribute.AIR_FIGHTER) 
blueair3:SetTurnoverTime(20, 30)

local BlueWing2=AIRWING:New("blue airwing2", "blue airwing2")

BlueWing:AddSquadron(blueair)
BlueWing:AddSquadron(blueairT)
BlueWing:NewPayload("bluehelitransport", 100, {AUFTRAG.Type.OPSTRANSPORT}, 100)
BlueWing:NewPayload("blueheli", 100, { AUFTRAG.Type.CAS}, 80)

BlueWing2:AddSquadron(blueair2)
BlueWing2:AddSquadron(blueair3)
BlueWing2:NewPayload("bluecap", 100, {AUFTRAG.Type.CAP, AUFTRAG.Type.INTERCEPT, AUFTRAG.Type.GCICAP}, 100)
BlueWing2:NewPayload("bluecas", 100, {AUFTRAG.Type.CAS, AUFTRAG.Type.CASENHANCED, AUFTRAG.Type.RECON, AUFTRAG.Type.GROUNDATTACK}, 100)
-- CHIEF OF STAFF
local blueAgents=SET_GROUP:New():FilterCoalitions("blue"):FilterStart()
local BlueChief=CHIEF:New(coalition.side.BLUE, blueAgents)
BlueChief:AddBorderZone(ZoneBlueBorder)
BlueChief:AddConflictZone(ZoneContestedBorder)
BlueChief:AddAttackZone(ZoneRedBorder)
if ace.debug then BlueChief:SetTacticalOverviewOn() end
BlueChief:SetLimitMission(3, AUFTRAG.Type.CASENHANCED)
BlueChief:SetLimitMission(3, AUFTRAG.Type.CAPTUREZONE)
BlueChief:SetLimitMission(2, AUFTRAG.Type.INTERCEPT)
BlueChief:SetLimitMission(3, AUFTRAG.Type.CAS)
--BlueChief:SetLimitMission(30)

-- Add legions(s) [airwings, brigades, flotillas] to the chief.
BlueChief:AddBrigade(BlueBrigade)
BlueChief:AddAirwing(BlueWing)
BlueChief:AddAirwing(BlueWing2)
BlueChief:AllowGroundTransport()
BlueChief:SetStrategy(CHIEF.Strategy.AGGRESSIVE)
BlueChief:__Start(5)

-- EMPTY custom resources
local BlueResourceListEmpty, BlueResourceInf=BlueChief:CreateResource( AUFTRAG.Type.ONGUARD, 1, 1, GROUP.Attribute.GROUND_INFANTRY)
BlueChief:AddTransportToResource(BlueResourceInf, 1, 1, {GROUP.Attribute.AIR_TRANSPORTHELO})

-- OCCUPIED custom resources
local BlueResourceListOccupied, ResourceBlueParas=BlueChief:CreateResource(AUFTRAG.Type.PATROLZONE, 1, 1, GROUP.Attribute.GROUND_INFANTRY)
local BlueResourceIFV=BlueChief:AddToResource(BlueResourceListOccupied, AUFTRAG.Type.CAPTUREZONE, 1, 1, GROUP.Attribute.GROUND_IFV)
local BlueResourceTank=BlueChief:AddToResource(BlueResourceListOccupied, AUFTRAG.Type.CAPTUREZONE, 1, 1, GROUP.Attribute.GROUND_TANK)
local BlueResourceHeli=BlueChief:AddToResource(BlueResourceListOccupied, AUFTRAG.Type.CAS, 1, 1, GROUP.Attribute.AIR_ATTACKHELO)
BlueChief:AddTransportToResource(ResourceBlueParas, 1, 1, { GROUP.Attribute.GROUND_APC })

-----
--RED
-----
--==RED PLATOONS
local rPlatoon1=PLATOON:New("redinf", 1000, "rSquaddies")
:SetGrouping(5)
rPlatoon1:SetAttribute(GROUP.Attribute.GROUND_INFANTRY)
rPlatoon1:AddMissionCapability({AUFTRAG.Type.PATROLZONE, AUFTRAG.Type.ONGUARD, AUFTRAG.Type.GROUNDATTACK}, 50)

local rPlatoon2=PLATOON:New("redtruck", 250, "rPlatoon truck")
:SetGrouping(1)
rPlatoon2:SetAttribute(GROUP.Attribute.GROUND_TRUCK)
rPlatoon2:AddMissionCapability({AUFTRAG.Type.OPSTRANSPORT, AUFTRAG.Type.TROOPTRANSPORT},100)

local rPlatoon3=PLATOON:New("redIFV", 27, "rPlatoon IFV")
:SetGrouping(1)
rPlatoon3:SetAttribute(GROUP.Attribute.GROUND_IFV)
rPlatoon3:AddMissionCapability({AUFTRAG.Type.ONGUARD, AUFTRAG.Type.CAPTUREZONE, AUFTRAG.Type.PATROLZONE, AUFTRAG.Type.RECON, AUFTRAG.Type.GROUNDATTACK, AUFTRAG.Type.ARMOREDGUARD, AUFTRAG.Type.ARMORATTACK},80)

local rPlatoon4=PLATOON:New("redtank", 35, "rPlatoon tank")
:SetGrouping(3)
rPlatoon4:SetAttribute(GROUP.Attribute.GROUND_TANK)
rPlatoon4:AddMissionCapability({ AUFTRAG.Type.CAPTUREZONE, AUFTRAG.Type.PATROLZONE, AUFTRAG.Type.GROUNDATTACK, AUFTRAG.Type.ARMOREDGUARD, AUFTRAG.Type.ARMORATTACK},100)

local rPlatoon5=PLATOON:New("redAPC", 125, "rPlatoon APC")
:SetGrouping(2)
rPlatoon5:SetAttribute(GROUP.Attribute.GROUND_APC)
rPlatoon5:AddMissionCapability({AUFTRAG.Type.OPSTRANSPORT, AUFTRAG.Type.TROOPTRANSPORT, AUFTRAG.Type.ONGUARD},90)

local rPlatoon6=PLATOON:New("redSAM", 5, "Air Defence Platoon")
:SetGrouping(5)
rPlatoon6:SetAttribute(GROUP.Attribute.GROUND_SAM)
rPlatoon6:AddMissionCapability({AUFTRAG.Type.AIRDEFENSE},100)

local RedBrigade=BRIGADE:New("red brigade", "red brigade")
RedBrigade:SetSpawnZone(ZONE:New("Red Spawn"))

RedBrigade:AddPlatoon(rPlatoon1)
RedBrigade:AddPlatoon(rPlatoon2)
RedBrigade:AddPlatoon(rPlatoon3)
RedBrigade:AddPlatoon(rPlatoon4)
RedBrigade:AddPlatoon(rPlatoon5)
RedBrigade:AddPlatoon(rPlatoon6)

-- RED AIRWINGS
local redair=SQUADRON:New("redhelitransport", 24, "2nd red Airlift Helo Squadron")
redair:SetGrouping(1)
redair:AddMissionCapability({AUFTRAG.Type.OPSTRANSPORT}, 100)
redair:SetAttribute(GROUP.Attribute.AIR_TRANSPORTHELO) 
redair:SetTurnoverTime(10, 30)

local redairT=SQUADRON:New("redheli", 24, "1st red Attack helo Squadron")
redairT:SetGrouping(1)
redairT:AddMissionCapability({ AUFTRAG.Type.CAS}, 100)
redairT:SetAttribute(GROUP.Attribute.AIR_ATTACKHELO) 
redairT:SetTurnoverTime(10, 30)

local RedWing=AIRWING:New("red airwing", "red airwing")

local redair2=SQUADRON:New("redcas", 24, "3rd red Strike Squadron")
redair2:SetGrouping(1)
redair2:SetAttribute(GROUP.Attribute.AIR_FIGHTER, GROUP.Attribute.AIR_BOMBER)
redair2:AddMissionCapability({AUFTRAG.Type.CASENHANCED, AUFTRAG.Type.CAS, AUFTRAG.Type.RECON, AUFTRAG.Type.GROUNDATTACK, AUFTRAG.Type.STRIKE}, 100)
redair2:SetTurnoverTime(20, 30)

local redair3=SQUADRON:New("redcap", 8, "4th red Air Superiority Squadron")
redair3:SetGrouping(1)
redair3:SetAttribute(GROUP.Attribute.AIR_FIGHTER)
redair3:AddMissionCapability({AUFTRAG.Type.CAP, AUFTRAG.Type.INTERCEPT,AUFTRAG.Type.GCICAP }, 100)
redair3:SetTurnoverTime(20, 30)
local RedWing2=AIRWING:New("red airwing2", "red airwing2")

RedWing:AddSquadron(redair)
RedWing:AddSquadron(redairT)
RedWing2:AddSquadron(redair2)
RedWing2:AddSquadron(redair3)

RedWing:NewPayload("redhelitransport", 100, {AUFTRAG.Type.OPSTRANSPORT}, 100)
RedWing:NewPayload("redheli", 100, {AUFTRAG.Type.CAS}, 100)
RedWing2:NewPayload("redcap", 100, {AUFTRAG.Type.CAP, AUFTRAG.Type.INTERCEPT, AUFTRAG.Type.GCICAP,}, 100)
RedWing2:NewPayload("redcas", 100, {AUFTRAG.Type.CASENHANCED, AUFTRAG.Type.CAS, AUFTRAG.Type.RECON, AUFTRAG.Type.GROUNDATTACK, AUFTRAG.Type.STRIKE}, 100)

-- RED CHIEF OF STAFF

local rAgents=SET_GROUP:New():FilterCoalitions("red"):FilterStart()
local RedChief=CHIEF:New(coalition.side.RED, rAgents)
RedChief:AddBorderZone(ZoneRedBorder)
RedChief:AddConflictZone(ZoneContestedBorder)
RedChief:AddAttackZone(ZoneBlueBorder)
if ace.debug then RedChief:SetTacticalOverviewOn() end
RedChief:SetLimitMission(3, AUFTRAG.Type.CASENHANCED)
RedChief:SetLimitMission(3, AUFTRAG.Type.CAS)
RedChief:SetLimitMission(3, AUFTRAG.Type.CAPTUREZONE)
RedChief:SetLimitMission(2, AUFTRAG.Type.INTERCEPT)
--RedChief:SetLimitMission(20, AUFTRAG.Type.ONGUARD)
--RedChief:SetLimitMission(30)

-- Add legions(s) [airwings, brigades, flotillas] to the chief.
RedChief:AddBrigade(RedBrigade)
RedChief:AddAirwing(RedWing)
RedChief:AddAirwing(RedWing2)
RedChief:AllowGroundTransport() --deprecated?
RedChief:SetStrategy(CHIEF.Strategy.AGGRESSIVE)
RedChief:__Start(10)

-- EMPTY custom resources
local RedResourceListEmpty, ResourceRedInf=RedChief:CreateResource( AUFTRAG.Type.ONGUARD, 1, 1, GROUP.Attribute.GROUND_INFANTRY)
RedChief:AddTransportToResource(ResourceRedInf, 1, 1,  GROUP.Attribute.AIR_TRANSPORTHELO)

-- OCCUPIED custom resources
local RedResourceListFull, ResourceParasR=RedChief:CreateResource(AUFTRAG.Type.PATROLZONE, 1, 1, GROUP.Attribute.GROUND_INFANTRY)
local ResourceRecon=RedChief:AddToResource(RedResourceListFull, AUFTRAG.Type.CAPTUREZONE, 1, 1, GROUP.Attribute.GROUND_IFV)
local ResourceTank=RedChief:AddToResource(RedResourceListFull, AUFTRAG.Type.CAPTUREZONE, 1, 1, GROUP.Attribute.GROUND_TANK)
local ResourceHeli=RedChief:AddToResource(RedResourceListFull, AUFTRAG.Type.CAS, 1, 1, GROUP.Attribute.AIR_ATTACKHELO)
RedChief:AddTransportToResource(ResourceParasR, 1, 1, {GROUP.Attribute.GROUND_APC})




local opszones=SET_OPSZONE:New():FilterPrefixes("POI-"):FilterOnce()
--FILL ZONES WITH CHEIF GROUPS AT START
opszones:ForEachZone(function(ops)
   local coord=ops:GetCoordinate()
  
   if ZoneRedBorder:IsCoordinateInZone(coord) then--we use the CHIEF Intel zone as the home zone, but you could use other things.
      --TODO maybe look at importance and set a different template for higher ones?
    local Rmission=AUFTRAG:NewONGUARD(coord)
    Rmission:SetTeleport(true)
    RedChief:AddMission(Rmission)
    RedChief.commander:CheckMissionQueue()
   end
   
   if ZoneBlueBorder:IsCoordinateInZone(coord) then
    local Bmission=AUFTRAG:NewONGUARD(coord)
    Bmission:SetTeleport(true)
    BlueChief:AddMission(Bmission)
    BlueChief.commander:CheckMissionQueue()
   end
      
   if ZoneContestedBorder:IsCoordinateInZone(coord) then
    --Add blue units
    --[[
    local mission=AUFTRAG:NewPATROLZONE(ops:GetZone(), 4, nil, "On Road")
    mission:SetTeleport(true)
    BlueChief:AddMission(mission)
    BlueChief.commander:CheckMissionQueue()
    --Also add red units
    local mission2=AUFTRAG:NewPATROLZONE(ops:GetZone(), 4, nil, "On Road")
    mission2:SetTeleport(true)
    RedChief:AddMission(mission2)
    RedChief.commander:CheckMissionQueue()
    --]]
   end

end)

--ADD SAMS TO SOME ZONES - can only be run once.
opszones:ForEachZone(function(ops)
 local coord=ops:GetCoordinate()
  
   if ZoneRedBorder:IsCoordinateInZone(ops:GetZone()) then
      if RedSams > 0 then
         local mission=AUFTRAG:NewAIRDEFENSE(ops:GetZone())
         mission:SetTeleport(true)
         RedChief:AddMission(mission)
         RedChief.commander:CheckMissionQueue()
         RedSams=RedSams-1
      end
  
   elseif ZoneBlueBorder:IsCoordinateInZone(coord)then
      if BlueSams > 0 then
         local mission=AUFTRAG:NewAIRDEFENSE(ops:GetZone())
         mission:SetTeleport(true)
         BlueChief:AddMission(mission)
         BlueChief.commander:CheckMissionQueue()
         BlueSams=BlueSams-1
      end
   end
end)

-- THIS DELETES CRASHED/DAMAGED CHOPPERS THAT TRIED TO LAND SOMEWHERE SILLY AND HURT THEMSELVES
local PlaneCoordTable = {} -- for keeping postitions
SCHEDULER:New( nil, function()

local AllPlanes=SET_UNIT:New():FilterCategories("helicopter"):FilterActive(true):FilterStart()

  AllPlanes:ForEachUnit(
  function (unit)

    if unit:InAir() == false then -- reduce CPU, ignore anything airborne

      if unit:GetPlayerName()==nil or unit:GetPlayerName()=="" then

        local plane = unit:GetName() 
        local coordx = unit:GetVec2().x
        local coordy = unit:GetVec2().y
        local coord = coordx + coordy --hash into a single value to simplify
        local health = unit:GetLifeRelative()
          if table_has_key(PlaneCoordTable, plane) then --check if the plane has already come to the table
                    
            if coord == PlaneCoordTable[plane] then
              unit:Destroy()
              PlaneCoordTable[plane]=nil
              --env.info("Deleted plane "..plane.." as it was not moving.") --If you want a log entry, uncomment this line
            elseif health < 1 then
              unit:Destroy()
              PlaneCoordTable[plane]=nil
            else
              PlaneCoordTable[plane]=coord --moved
             -- env.info(plane.." IS moving.")
            end
         
         else
            PlaneCoordTable[plane]=coord
         end
         
        end

    end

  end)
end, {}, 1, 500) --300=5 mins. Starts after 60 seconds, no randomisation

--DELAY FOR 5 mins
--MAKE STRATEGIC ZONES and apply priority
SCHEDULER:New( nil, function()
--Distance from base to base
local BlueBaseCoord=ZONE:FindByName(BlueBase):GetCoordinate(0)
local RedBaseCoord=ZONE:FindByName(RedBase):GetCoordinate(0)
local BaseSep=BlueBaseCoord:Get2DDistance(RedBaseCoord)

--TURN ALL OF THE OPS ZONES INTO STRATEGIC ZONES
opszones:ForEachZone(function(ops)
local BlueDist=ops:GetCoordinate():Get2DDistance(BlueBaseCoord)
local RedDist=ops:GetCoordinate():Get2DDistance(RedBaseCoord)
local name=ops:GetName()
local JustTheTownName=string.match(name, "-(.*)")
local prio = round(TownTable[JustTheTownName],0)
local BlueImp = round((BlueDist/BaseSep)*100,1)  -- a 1-100 number with 0 being at the home base and 100 being the enemy base.
local RedImp = round((RedDist/BaseSep)*100,1)  -- a 1-100 number with 0 being at the home base and 100 being the enemy base.
BlueChief:AddStrategicZone(ops, prio, BlueImp, BlueResourceListOccupied, BlueResourceListEmpty) 
RedChief:AddStrategicZone(ops, prio, RedImp, RedResourceListFull, RedResourceListEmpty)
end)
end, {}, 600)
 --[[
GROUP.Attribute.AIR_FIGHTER
GROUP.Attribute.AIR_BOMBER
GROUP.Attribute.AIR_AWACS  
GROUP.Attribute.AIR_TRANSPORTPLANE
GROUP.Attribute.AIR_TANKER
GROUP.Attribute.AIR_ATTACKHELO  
GROUP.Attribute.AIR_TRANSPORTHELO
GROUP.Attribute.AIR_UAV
GROUP.Attribute.GROUND_EWR
GROUP.Attribute.GROUND_SAM
GROUP.Attribute.GROUND_AAA
GROUP.Attribute.GROUND_ARTILLERY         
GROUP.Attribute.GROUND_TANK 
GROUP.Attribute.GROUND_IFV   
GROUP.Attribute.GROUND_APC
GROUP.Attribute.GROUND_INFANTRY 
GROUP.Attribute.GROUND_TRUCK
GROUP.Attribute.GROUND_TRAIN
GROUP.Attribute.NAVAL_AIRCRAFTCARRIER
GROUP.Attribute.NAVAL_WARSHIP
GROUP.Attribute.NAVAL_ARMEDSHIP
GROUP.Attribute.NAVAL_UNARMEDSHIP
GROUP.Attribute.GROUND_OTHER
GROUP.Attribute.NAVAL_OTHER
GROUP.Attribute.AIR_OTHER
GROUP.Attribute.OTHER_UNKNOWN

AUFTRAG.Type={
  ANTISHIP="Anti Ship",
  AWACS="AWACS",
  BAI="BAI",
  BOMBING="Bombing",
  BOMBRUNWAY="Bomb Runway",
  BOMBCARPET="Carpet Bombing",
  CAP="CAP",
  CAS="CAS",
  ESCORT="Escort",
  FAC="FAC",
  FACA="FAC-A",
  FERRY="Ferry Flight",
  GROUNDESCORT="Ground Escort",
  INTERCEPT="Intercept",
  ORBIT="Orbit",
  GCICAP="Ground Controlled CAP",
  RECON="Recon",
  RECOVERYTANKER="Recovery Tanker",
  RESCUEHELO="Rescue Helo",
  SEAD="SEAD",
  STRIKE="Strike",
  TANKER="Tanker",
  TROOPTRANSPORT="Troop Transport",
  ARTY="Fire At Point",
  PATROLZONE="Patrol Zone",
  OPSTRANSPORT="Ops Transport",
  AMMOSUPPLY="Ammo Supply",
  FUELSUPPLY="Fuel Supply",
  ALERT5="Alert5",
  ONGUARD="On Guard",
  ARMOREDGUARD="Armored Guard",
  BARRAGE="Barrage",
  ARMORATTACK="Armor Attack",
  CASENHANCED="CAS Enhanced",
  HOVER="Hover",
  LANDATCOORDINATE="Land at Coordinate",
  GROUNDATTACK="Ground Attack",
  CARGOTRANSPORT="Cargo Transport",
  RELOCATECOHORT="Relocate Cohort",
  AIRDEFENSE="Air Defence",
  EWR="Early Warning Radar",
  REARMING="Rearming",
  CAPTUREZONE="Capture Zone",
  NOTHING="Nothing",
  PATROLRACETRACK="Patrol Racetrack",
}
--]]
