# Inventory Script (SAMP)
By CuervO for CuervO

Powered by
-
<a href=""http://forum.sa-mp.com/showthread.php?t=91354">ZCMD 0.3.1</a> - <a href="http://forum.sa-mp.com/showthread.php?t=56564">MYSQL R39-3</a> - <a href="http://forum.sa-mp.com/showthread.php?t=102865">Streamer 2.7.5.2</a><br>   
<a href="http://forum.sa-mp.com/showthread.php?t=120356">Sscanf 2.8.1</a> - <a href="http://forum.sa-mp.com/showthread.php?t=262796">Crashdetect</a> - <a href="http://forum.sa-mp.com/showthread.php?t=343172">SortArray</a> 


Introduction
-
As seen in DayZ Standalone! Fully working inventory & object management Script. With complete dynamic features and now easier to edit! Get yourself one while they are fresh!

Featuring a complete GUI and (sort of) easy manipulation in game, pretty much everything is intuitive.


DATABASE STRUCTURE
-

actions (ActionID, UsesType, ActionName)<br>
<br>
ActionID: Internal SQL ID (Primary Key) (INT)<br>
UsesType: The type that the action will be attached to. (INT)<br>
ActionName: The name of the action itself. (VARCHAR)<br>
<br>
<br>
objectinventory (InventoryID, PlayerObjectID, InsideIDs)<br>
<br>
InventoryID: Internal SQL ID (Primary Key) (INT)<br>
PlayerObjectID: The ID of the player object that the inventory belongs to. (INT)<br>
InsideIDs: The ids objects inside of the inventory, separated by commas. (VARCHAR)<br>
<br>
<br>
objects (ID, Name, Size, UsesType, UsesSlot, SlotsInside, Weight, MaxUses, Display, DisplayColor, DisplayOffsets, OnHandOffsets, OnBodyOffsets, ObjectScales, SpecialFlag_1, SpecialFlag_2, SpecialFlag_3)<br>
<br>
ID: Internal SQL ID (Primary Key) (INT)<br>
Name: Name of the base object (VARCHAR)<br>
Size: Size (slots it takes) (INT)<br>
UsesType: ID of the type it uses (INT)<br>
UsesSlot: ID of the slot it uses (INT)<br>
SlotsInside: Amount of slots it haves inside (INT)<br>
Weight: Unused, for scrapped weight (FLOAT)<br>
MaxUses: Total amount of uses (INT)<br>
Display: Object ID to use as dropped object / portraits (INT)<br>
DisplayColor: Color of the object (INT)<br>
DisplayOffsets: RX,RY,RZ and Zoom of the portrait (INT)<br>
OnHandOffsets: X, Y, Z, RX, RY, RZ of the object while on hands (VARCHAR)<br>
OnBodyOffsets: boneid, X, Y, Z, RX, RY, RZ of the object while on body (VARCHAR)<br>
ObjectScales: X, Y, Z that the object will use as scale for both OnHand and OnBody (VARCHAR)<br>
SpecialFlag_1: Special flag value 1 (INT)<br>
SpecialFlag_2: Special flag value 2 (INT)<br>
SpecialFlag_3: Special flag value 2 (INT)<br>
<br>
<br>
playerinventories (PlayerName, ...)<br>
<br>
PlayerName: name of the player attached to the inventory (VARCHAR)<br>
[number]: ID of the slot, these are dynamic columns and are created/removed by altering the slots.<br>
<br>
<br>
playerobjects (PlayerID, PlayerName, BaseObjectID, CurrentUses, Position, Status, Condition, WorldX, WorldY, WorldZ, P_SpecialFlag_1, P_SpecialFlag_2)<br>
<br>
PlayerID: Internal SQL ID (Primary Key) (INT)<br>
PlayerName: Name of the owner if applies (VARCHAR)<br>
BaseObjectID: ID of the base object it uses (INT)<br>
CurrentUses: Current amount of uses it has if applies (INT)<br>
Position: Current position inside of a object/as a container (INT)<br>
Status: Current Status -> 1: Is a player owned container  2: Is inside any container   3: Is dropped    4: To be deleted next script reload.   5: Dropped object on hand.  (INT)<br>
Condition: Unused, default 100. (INT)<br>
WorldX: Position X inside of world. (FLOAT)<br>
WorldY: Position Y inside of world. (FLOAT)<br>
WorldZ: Position Z inside of world (FLOAT)<br>
P_SpecialFlag_1: Player Special flag value 1 (INT)<br>
P_SpecialFlag_2: Player Special flag value 2 (INT)<br>
<br>
<br>
slots (SlotID, SlotName, MaxObjects)<br>
<br>
SlotID: Internal SQL ID (Primary Key) (INT)<br>
SlotName: Name of the slot (VARCHAR)<br>
MaxObjects: Max amount of objects to allow in that slot as containers (INT)<br>
<br>
<br>
types (TypeID, TypeName)<br>
<br>
TypeID: Internal SQL ID (Primary Key) (INT)<br>
TypeName: Name of the Type (VARCHAR)<br>

<b>Notes</b><br>
- What are special flags? These are used as optional fields which serve a porpuse for the script. These values could have pretty much their own column, but creating columns for each type of object that you want to implement would take a lot of space and make a big cluster of data; instead, you use the special flags to give objects optional values, and script their functionality based upon them. For example, 'SpecialFlag_1', for objects that have a weapon type (2, 12), it  represents the GTA SA weapon id of the weapon itself, and 'SpecialFlag_2' determines the caliber of the weapon, which is determined at 'SpecialFlag_1' for bullet & magazines type of objects (6, 7).<br>
<br>
- 'playerinventories' is a dynamic table which gets altered in the game itself when you create or remove a object slot. For each slot you add, a new column appears with a name of the ID of the slot, and this is used to keep track of the player inventories as in how many objects inside that slot the player has.<br>
<br>

SCRIPT ARCHITECTURE
-
In the previous version, the whole architecture was based off the SQL, and every time you needed a variable or a configuration of an object you would have to access the SQL, if you didn't have the value stored in a limited memory (the objects that were displayed). <br>
On the new version, the architecture was completely rewritten, moving everything to the memory. The SQL is accessed very few times and everything is stored into the memory, which allows more clean, faster and effective manipulation and usage of the data.<br>
Not only the whole script architecture was rewritten, as in completely all the callbacks and functions modified, but having access to the whole object information in the memory allowed me to make more flexible functions and defenitely easier to read and modify functions.<br>
<br>
When I reworked the architecture, I assigned the variables index to their corresponding object id, (Object ID 13 would be stored at ObjectData[13][eObjectData]), however I realized that IDs get skipped a LOT in the database (as objects are created and removed very frequentely), so I reworked it for a third time and the objects were stored on indexes independent to their ID (Object ID 13 could be ObjectData[7][eObjectData])<br>
<br>
<b>Refeer to the in git wiki for functions and variables</b>
<br>
Limits and Definitions
-
<b>MAX_PLAYER_OBJECTS:</b> 32768 - Max amount of player objects that can be loaded into the memory from the database (affects heavily the .amx size)<br>
<b>MAX_BASE_OBJECTS:</b> 2048 - Max amount of base objects that can be loaded into the memory from the database<br>
<b>MAX_OBJECT_TYPES:</b> 150 - Max amount of types that can be loaded into the memory from the database<br>
<b>MAX_TOTAL_ACTIONS:</b> 150 - Max amount of actions that can be loaded into the memory from the database<br>
<b>MAX_SLOTS:</b> 50 - Max amount of slots that can be loaded into the memory from the database<br>
<b>MAX_OBJECT_ACTIONS:</b> 3 - Max actions that can be listed in an object when double clicked<br>
<b>MAX_CARRY_OBJECTS:</b> 40 - Max inventory slots for a single object<br>
<b>MAX_LIST_ITEMS:</b> 20 - Max items that can be listed in one list<br>
<br>
<b>MAX_CONTAINERS_PER_PAGE:</b> 4 - Max amount of containers that can be displayed at once (separated for global and player containers)<br>
<b>MAX_CONTAINERS_LIMIT:</b> 50 - Max amount of containers to be loaded in the memory at once (separated for global and player containers)<br>

Usage
-
<b>GAMEWISE</b><br>
- Press <b>KEY_CTRL_BACK</B> Default '<B>H</B>' to open the inventory (or type /inventory)
- Select an object by clicking it's portrait.
- You can move around the object by selecting it and clicking on any slot.
- Swap objects by clicking another object with a selected object.
- Open action menu by double clicking any (player) object.
- Swap containers by clicking a container with another container.
- Drop any object by clicking the Near Objects box with a selected object.
- Equip a container by double clicking a dropped container or by clicking your player image with a selected object. (If the object uses slots, it will check if the slot is not occupied by another object, if it is, it will attempt to add the object inside any container)
- Pickup any object by double clicking it, moving it into your player image or moving it directly into one of your objects.
- You can put objects in your hands by clicking the 'Hands' Box with a selected object.
- You can manipulate the on hand inventory the same way you do with the rest of the inventory (except actions).
- Some objects might not allow to be swapped right away as they might have more than one action with the object you have selected.
- You can also move an object to a container by clicking the actual container header box with the object you want to put inside of it.
- Equipping a container will move it to the last position, you can move the container around by swapping it with other containers.

<b>SCRIPTWISE</b><br>
- Lots of scripted actions already added. If you wish to add your actions you will need to create the action first (a command in game), after the action is created it will be ready for use, you can script an action by using the OnPlayerClickAction callback, you can help yourself with OnObjectSwapAttempt if you wish to create special interactions between objects.<br>
<br>
<color="#ff0000"><B>WARNING:</B> Most of the actually scripted functions will get broken if you delete the types. If you edit an action or a type, make sure to edit the script on wherever the edited type/actions are used!!</font>
<br>
- Scripted actions work mainly by the Type ID attached and the Action itself. Special interactions have negative types ids attached so you can control them via the script. If you change an object type and remove it's weapon status, it will no longer function as weapon; if you remove the weapon type all together the script will no longer recognize weapons as the script works heavily by the types and actions ids.

- Use the callbacks OnObjectSwapAttempt, OnObjectMovedAttempt to prevent an object from being moved or swapped if it doesn't fit your needs, and use the callbacks OnObjectSwapped, OnServerObjectMoved to apply new variables (for example, SpecialFlags).

- The magic happens at OnPlayerClickPlayerTextDraw, most of the core functions are called from there. I tried to make the variables names as clear as possible, but doing something wrong in there might screw the whole script up.

- Scripted Actions can be as easy as a few lines (Eat Food, Eat All Food) or as hard as several hundred lines (Weapon system all together). You could try to modify the script and add fuel powered object (objects that require fuel just like weapons require bullets) by using the already scripted weapon system.

- Special Flags are really usefull tools that allow lots of flexibility for the script.

- Status 4 on objects flags them for deletion after the server starts, this is useful to create temporary objects (looting system).

- As already explained, MoveObjectToObject pos parameter offers a lot of flexibility, as -1 will attempt to add the object to the destination container, and if it doesn't fit, into any other container, and if it still doesn't fit, it will drop the object; -2 will attempt to add the object to any slot in the destination container, and if it doesn't fit, prevent the move.

Already Scripted Actions
-
At the moment there are several scripted functions included in:<br>
<br>
- Swap, Add Into (Attached Type -1): This is an internal action used for bullets interaction with magazines or ammo boxes
- Eat Food, Eat All Food (Attached Type 5): Allows you to eat an item labeled as food (type 5) and consume one or all of the uses, giving you a health value defined in the SpecialFlag_1 of the object base.
- Empty Magazine (Attached Type 6): Empties the magazine and adds the content inside of it into the container the magazine currently is.
- Split (Attached Type 7): Splits the bullet stack into two.
- Check Ammo (Attached Type 6): Checks how many bullets are inside the magazine
- Combine, Swap (Attached Type -2): Scripted actions for interactions between bullets.
- Empty Gun, Empty Bolt Gun (Attached Types 2 & 12): Same as empty magazine but for weapons
- Check Magazine, Check Chamber (Attached Types 2 & 12): Same as check ammo but for weapons
- Swap Container, Add Into Container (Attached Types -3): Internal function for containers to allow them to be swaped or add into interactions.

Slots
-
Slots are a new feature in the rework that limits the amount of containers you can have. A container is assigned a slot, and then the script keeps track of how many objects of a slot you have equiped. If you reach the Max Objects defined on the slots table, the script wont let you add that object as a container (and will instead try to add it inside your containers).<br>
<br>
Swapping option between dropped containers and your containers (new feature) is only given if the objects have the same slot.<br>
<br>
The player inventory data is kept in playerinventories database, which featuers a dynamic structure. For each new slot you create with /newslot, a new column is added to the playerinventory data, with the ID of the slot, this way, when the player equips a container, it saves it on the slot column that the container uses. (Columns are also deleted when you remove a slot)<br>
<br>

Weapon System
-
Along with the whole core functions, I also added a fully working weapon script that works exactly like (except the weapon attachments) the DayZ SA weapons. You can put a weapon on your hand, but it wont fire unless it haves ammo or a mag with ammo of it's correspondient caliber.<br>
<br>
This was the main thing that made me create the SpecialFlags architecture. When I was creating the weapon system, I realized I needed several fields of data to make the system work, as in, what was the GTA weapon ID of the object when I put it on my hand with ammo? What kind of bullets can it take? How many bullets can it take? What kind of mag can it take?..
Making a column for each field needed would be pretty bad and would look like a cluster when there could be 10 weapons-or-so and 500 other objects with different functions, and then those objects would need custom fields, this is when I came up with the SpecialFlags, which are field of data that can hold an integer, and you can assign that integer to whatever you want in the script, in essence:<br>
<br>
SpecialFlag_1, for weapons (Type 2 & 12) determines the GTA SA weapon id to give;<br>
SpecialFlag_2, for weapons (Type 2 & 12) determines the caliber id of the ammo/mags it would take;<br>
SpecialFlag_3, for bolt weapons (Type 12) determines the chamber size;<br>
SpecialFlag_1, for magazines and bullets (Type 6,7) determines the caliber id of them;<br>
SpecialFlag_2, for magazines (Type 6) determines the amount of bullets it can take inside.<br>
<br>
On the same way, P_SpecialFlags are player object special flags that work in the same way, but are individual to each player object, in essence:<br>
<br>
P_SpecialFlag_1, for weapons (Type 2 & 12), stores the Player Object ID of the mag or the bullet that is inside it's chamber;<br>
P_SpecialFlag_1, for mags (Type 6), stores the Player Object ID of the bullet that's inside of it;<br>
P_SpecialFlag_1, for bullets (Type 7), also stores the Player Object ID of the mag it is inside of;<br>
<br>
This way, you can mold your object system any way you want, another example is on the Food items, where SpecialFlag_1 stores the amount of HP it will restore with each use.<br>
<br>
Having explained that now what's left is pretty easy: You can dynamically create an object in game. You can assign that object the weapon type, and assign it any SpecialFlags; You can also create another object and assign them the bullet type, also assigning it any SpecialFlags; Finally, combining both, you can make a whole new weapon with any kind of ammo in a few seconds. You could create an AK-74 which doesn't use 7.62x51mm, but 7.62x39mm, instead of the AK-47, or along the AK-47. You could also create a custom damage system based off this, as the AK47 would have more damage (51mm) than the AK74 (39mm).<br>
