# Inventory Script (SAMP)
By CuervO

Powered by
-
<a href=""http://forum.sa-mp.com/showthread.php?t=91354">ZCMD 0.3.1</a> - <a href="http://forum.sa-mp.com/showthread.php?t=56564">MYSQL R39-3</a> - <a href="http://forum.sa-mp.com/showthread.php?t=102865">Streamer 2.7.5.2</a>   
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

<b>Notes</b>
- What are special flags? These are used as optional fields which serve a porpuse for the script. These values could have pretty much their own column, but creating columns for each type of object that you want to implement would take a lot of space and make a big cluster of data; instead, you use the special flags to give objects optional values, and script their functionality based upon them. For example, 'SpecialFlag_1', for objects that have a weapon type (2, 12), it  represents the GTA SA weapon id of the weapon itself, and 'SpecialFlag_2' determines the caliber of the weapon, which is determined at 'SpecialFlag_1' for bullet & magazines type of objects (6, 7).

- 'playerinventories' is a dynamic table which gets altered in the game itself when you create or remove a object slot. For each slot you add, a new column appears with a name of the ID of the slot, and this is used to keep track of the player inventories as in how many objects inside that slot the player has.

SCRIPT ARCHITECTURE
-
In the previous version, the whole architecture was based off the SQL, and every time you needed a variable or a configuration of an object you would have to access the SQL, if you didn't have the value stored in a limited memory (the objects that were displayed). 
On the new version, the architecture was completely rewritten, moving everything to the memory. The SQL is accessed very few times and everything is stored into the memory, which allows more clean, faster and effective manipulation and usage of the data.
Not only the whole script architecture was rewritten, as in completely all the callbacks and functions modified, but having access to the whole object information in the memory allowed me to make more flexible functions and defenitely easier to read and modify functions.


Before we begin, here a glossary:<br>
<br>
<b>PLAYER OBJECT:</b> Actual in game object, which can be owned by a player or not.<br>
<b>BASE OBJECT:</b> The object template that all the player objects use<br>
<br>
<b>SOURCE:</b> The source is the ID of the container an object is inside if applies<br>
<b>DESTINATION:</b> The destination is the ID of the container that an object is getting moved to if applies<br>
<br>
<b>SELECTED OBJECT:</b> ID of the object that the player has selected<br>
<b>SECOND OBJECT:</b> ID of the object that the player has clicked with a selected object<br>
<br>
This is a list of the new enumerators and attached variables:<br>
enum PlayerObjectInfo<br>
{<br>
	BaseID,<br>
	PlayerID,<br>
 	OwnerName[24],<br>
	CurrentUses,<br>
	Position,<br>
	Status,<br>
	Condition,<br>
	Float:WorldX,<br>
	Float:WorldY,<br>
	Float:WorldZ,<br>
	P_SpecialFlag_1,<br>
	P_SpecialFlag_2,<br>
	InventoryID,<br>
	Inventory[64],<br>
	GameObject,<br>
	AreaID,<br>
	IsNear[PLAYERS]<br>
}<br>
new ObjectInfo[MAX_PLAYER_OBJECTS][PlayerObjectInfo];<br>
new LastObjectInfoIndexUsed, TotalLoadedPlayerObjects;<br>
// Stores player object data into the memory<br>
<br>
enum eObjectData<br>
{<br>
	ID,<br>
	Name[32],<br>
	Size,<br>
	UsesType,<br>
	SlotsInside,<br>
	UsesSlot,<br>
	MaxUses,<br>
	Float:Weight,<br>
	Display,<br>
	DisplayColor,<br>
	Float:DisplayOffsets[4],<br>
	Float:OnHandOffsets[6],<br>
	Float:OnBodyOffsets[7],<br>
	Float:ObjectScales[3],<br>
	SpecialFlag_1,<br>
	SpecialFlag_2,<br>
	SpecialFlag_3<br>
}<br>
new ObjectData[MAX_BASE_OBJECTS][eObjectData];<br>
new LastObjectDataIndexUsed, TotalLoadedBaseObjects;<br>
// Stores each object individual information<br>
<br>
<br>
enum eSlotData<br>
{<br>
	SlotID,<br>
	SlotName[32],<br>
 	MaxObjects<br>
}<br>
new SlotData[MAX_SLOTS][eSlotData];<br>
new LastSlotDataIndexUsed, TotalLoadedSlots;<br>
// Stores each object individual information<br>
<br>
enum PlayerVariables<br>
{<br>
	ContainersInPages[13], //MAX_CONTAINERS_LIMIT / MAX_CONTAINERS_PER_PAGE rounded up<br>
	DroppedContainersInPages[13], //MAX_CONTAINERS_LIMIT / MAX_CONTAINERS_PER_PAGE rounded up<br>
	ContainerStoredInSlot[MAX_CONTAINERS_PER_PAGE+1], //+1 for the onhand inventory<br>
	DroppedContainerStoredInSlot[MAX_CONTAINERS_PER_PAGE],<br>
	ActionStored[MAX_OBJECT_ACTIONS],<br>
	ObjectInAction,<br>
	ObjectInActionGlobal,<br>
	ObjectInActionSource,<br>
	CurrentListTotal,<br>
	CurrentListPerPage,<br>
	CurrentListPage,<br>
	CurrentListTotalPages,<br>
	CurrentListStorage[MAX_LIST_ITEMS],<br>
	InventoryOpen,<br>
	ContainersListingPage,<br>
	DroppedContainersListingPage,<br>
	ContainersListingMin,<br>
	DroppedContainersListingMin,<br>
	SelectedObjectID,<br>
	SelectedContainerID,<br>
	SelectedObjectSourceID,<br>
	SelectedObjectGlobal,<br>
	EdittingObjectID,<br>
	EdittingActionID,<br>
  EdittingSlotID,<br>
	EdittingTypeID,<br>
	EdittingListItem,<br>
	OnHandObjectID,<br>
	OnHandTypeID,<br>
	OnHandWeaponID,<br>
	OnHandAmmoObjectID,<br>
	OnHandMagObjectID,<br>
	OnHandSourceID,<br>
	OnHandSourcePosition,<br>
	ObjectStoredInIndex[10],<br>
	ActionSwapStep,<br>
	HasInvalidAmmo,<br>
	WearingArmor,<br>
	Float:DisplayingModelRotation,<br>
	LastClickedObjectTick,<br>
	LastClickedObjectID,<br>
	OverridePosition,<br>
	MemorySlot[2],<br>
	Float:SelectedObjectHeaderY[MAX_CONTAINERS_PER_PAGE],<br>
	HideTooltipTimerID,<br>
	PlayerSlots[MAX_SLOTS]<br>
}<br>
new PlayerVar[PLAYERS][PlayerVariables];<br>
<br>
<br>
enum eTypeInfo<br>
{<br>
	TypeID, //ID in database<br>
	TypeName[32] //Name of the type itself<br>
}<br>
new TypeData[MAX_OBJECT_TYPES][eTypeInfo];<br>
new LastTypeDataIndexUsed, TotalLoadedTypes;<br>
<br>
enum eActionInfo<br>
{<br>
	ActionID, //ID in database<br>
	TypeIDAttached, //ID of the type that the action goes with<br>
	ActionName[32] //Name of the action itself<br>
}<br>
new ActionData[MAX_TOTAL_ACTIONS][eActionInfo];<br>
new LastActionDataIndexUsed, TotalLoadedActions;<br>
<br>
<br>
enum eGlobalInfo<br>
{<br>
	ScriptLoaded<br>
}<br>
new GlobalData[eGlobalInfo];<br>
