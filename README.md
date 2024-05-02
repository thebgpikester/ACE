# ACE
Another Campaign Engine by Pikey 2024 v1.0

## CREDITS
MOOSE Team, forefathers of MOOSE and those that pioneered.
Chromium for the towns.lua idea pointer.
Frank for helping complete the import.
AppleEvangelist for [STRATEGO])https://flightcontrol-master.github.io/MOOSE_DOCS_DEVELOP/Documentation/Functional.Stratego.html##(STRATEGO)) class and inpiring me to look at node based engines again.

## REQUIRES
Requires DEVELOPMENT [MOOSE.lua](https://github.com/FlightControl-Master/MOOSE_INCLUDE/blob/develop/Moose_Include_Static/Moose.lua) to be loaded first. 
Requires your installation to be modified so that io and lfs are not sanitized.
Demo requires Syria terrain.

## SUPPORT
Caucasus, Falklands, MarianaIslands, Normandy, PersianGulf, Syria, Kola supported at time of writing "Sinai" not supported because it has no published towns file in the terrain.
Q&A on the Moose Discord only, look for pikey. or "Mike". No specific help for [CHIEF](https://flightcontrol-master.github.io/MOOSE_DOCS_DEVELOP/Documentation/Ops.Chief.html##(CHIEF)) or classes, and no support for "I changed something and now it doesn't work".
I may or may not update or change this, since its a demo.

## PREAMBLE
This is a demo mission to setup a lot of AI fighting in a mission, or just a building block for a campaign before you start getting deep and adding detail or new classes. There's a few newish approaches by using the native terrain files list of towns and their locations pulling that data into the mission (Idea from Chromium, assistance from FunkyFranky, new class from AppleEvangelist). I made an algorithm that creates a numeric value against each of these towns according to things like density, variation of objects, distance from airfield. This is eventually fed into CHIEF Strategic Zones as Priority and importance. And finally because that is all automated, a simple CHIEF setup is added on top so that you can see the technique being used.
Hopefully this gives people a somewhat easy to setup map-agnostic CHIEF with an automated layout of Strategic zones that allowed fighting and conquest of these zones.
I also hope that you can 'steal' and reuse some of the part of this to further your own knowledge, rather than use it as a game itself.
Note, this is not meant to be an upstanding example of how to write code, its just another dude sharing and it has imperfections in style and inefficiencies.

## WHAT IT DOES
- Scans all towns in the zone called 'zone', writes them to table. This happens once only.
- Performs a long scan of each zone included in that zone to give an 'importance' score.
- Sends the final list to MOOSE [STRATEGO])https://flightcontrol-master.github.io/MOOSE_DOCS_DEVELOP/Documentation/Functional.Stratego.html##(STRATEGO))  for processing towns into enhanced nodes.
- Creates strategic zones from towns by importance and priority by distance from home.
- Sets up two AI CHIEF coalitions to fight over them.
- Deploys AI groups to each side and in the conflict zone, launches attacks, fights, captures, etc, does CHIEF-things.

## HOW TO USE
The only supported configuration is via the supplied demo. It's released as working. After that use it as you like, in whole or in part, on your own. The script requires a single zone called 'zone' that is the limit of the area, three zones for sides, Blue Border, Contested and Red Border.
A RedBase zone and a Blue Base zone to be placed at each extremity of the play area.
A 'Blue Spawn' and a 'Red Spawn' zones for ground troops ot appear at.
Each side must have three warehouses of that coalition: blue brigade, blue airwing and blue airwing2
Each side must have 6 ground tmeplates named exactly as per the demo, 2 helicopters (attack and transport) named exactly and 2 fixed wing, CAP and cas named exactly as per demo.
Names are all case sensitive, its a lua thing.
Change debug to false below to not get the zones marked and tactical overviews.

## WHAT IS EXPECTED TO HAPPEN?
For the first ten minutes each side places its troops in zones.
It will begin to try to capture empty zones or send attack waves to occupied zones.
There is a defensive Intercept task.
Can be tweaked how you prefer.
