#include <a_samp>
#include <a_mysql>
#include <zcmd>
#include <sscanf2>
#include <streamer>
#include <crashdetect>
#include <SortArray> //Ty slice!

#define MYSQL_HOST  "localhost"
#define MYSQL_USER  "root"
#define MYSQL_UPASS ""
#define MYSQL_DB    "inventory"

#define KEY_AIM 128

#define PRESSED(%0) \
	(((newkeys & (%0)) == (%0)) && ((oldkeys & (%0)) != (%0)))
	
#define RELEASED(%0) \
	(((newkeys & (%0)) != (%0)) && ((oldkeys & (%0)) == (%0)))
	
#define HOLDING(%0) \
	((newkeys & (%0)) == (%0))

#define PLAYERS 			200     //Max players, affects really heavily the .amx size.

#define 	MAX_PLAYER_OBJECTS  		32768   //Max amount of player objects that can be loaded into the memory from the database (affects heavily the .amx size)
#define 	MAX_BASE_OBJECTS  			2048    //Max amount of base objects that can be loaded into the memory from the database
#define 	MAX_OBJECT_TYPES    		150     //Max amount of types that can be loaded into the memory from the database
#define 	MAX_TOTAL_ACTIONS   		150     //Max amount of actions that can be loaded into the memory from the database
#define     MAX_SLOTS                   50      //Max amount of slots that can be loaded into the memory from the database
#define 	MAX_OBJECT_ACTIONS  		3       //Max actions that can be listed in an object when double clicked
#define 	MAX_CARRY_OBJECTS   		40      //Max inventory slots for a single object
#define 	MAX_LIST_ITEMS      		20      //Max items that can be listed in one list

#define     MAX_CONTAINERS_PER_PAGE    	4       //Max amount of containers that can be displayed at once (both for global and player containers)
#define     MAX_CONTAINERS_LIMIT        50      //Max amount of containers to be loaded in the memory at once (both for global and player containers)


#define VERSION     "Second"

#define TYPE_ERROR  	1
#define TYPE_INFO   	2
#define TYPE_ADMIN  	3
#define TYPE_WARNING    4
#define TYPE_USAGE      5
#define TYPE_TIP        6
#define TYPE_OTHER      999

#define 	INVALID_SLOT_ID             MAX_SLOTS-1
#define 	INVALID_BASEOBJECT_ID       MAX_BASE_OBJECTS-1
#define 	INVALID_PLAYEROBJECT_ID     MAX_PLAYER_OBJECTS-1
#define 	INVALID_ACTION_ID           MAX_OBJECT_ACTIONS-1
#define 	INVALID_TYPE_ID     		MAX_OBJECT_TYPES-1

	/*These are all player textdraws, since most use More than two dimensions I can't list them in PlayerVar*/
new PlayerText:Inv[PLAYERS][24],
    PlayerText:GeneralTxt[PLAYERS][2],
    PlayerText:InventoryObjectsHead[PLAYERS][5][MAX_CONTAINERS_PER_PAGE],
    PlayerText:InventoryObjectsSlots[PLAYERS][MAX_CARRY_OBJECTS][MAX_CONTAINERS_PER_PAGE+1], //+1 is the onhand inventory
    PlayerText:InventoryObjectsAmount[PLAYERS][MAX_CARRY_OBJECTS][MAX_CONTAINERS_PER_PAGE],
    PlayerText:GlobalObjectsHead[PLAYERS][5][MAX_CONTAINERS_PER_PAGE],
    PlayerText:GlobalObjectsSlots[PLAYERS][MAX_CARRY_OBJECTS][MAX_CONTAINERS_PER_PAGE],
    PlayerText:GlobalObjectsAmount[PLAYERS][MAX_CARRY_OBJECTS][MAX_CONTAINERS_PER_PAGE],

    PlayerText:ActionMenu[PLAYERS][5];

	/*This can't go into PlayerVar because of the three dimensions*/
new ObjectStoredInContainer[PLAYERS][MAX_CARRY_OBJECTS][MAX_CONTAINERS_PER_PAGE+1], //+1 is the onhand inventory
	ObjectStoredInDroppedContainer[PLAYERS][MAX_CARRY_OBJECTS][MAX_CONTAINERS_PER_PAGE];
	
    
new dbHandle, query[128], medquery[256], bigquery[512], nname[24], msg[144];


enum PlayerObjectInfo
{
	BaseID,
	PlayerID,
 	OwnerName[24],
	CurrentUses,
	Position,
	Status,
	Condition,
	Float:WorldX,
	Float:WorldY,
	Float:WorldZ,
	P_SpecialFlag_1,
	P_SpecialFlag_2,
	InventoryID,
	Inventory[64],
	GameObject,
	AreaID,
	IsNear[PLAYERS]
}
new ObjectInfo[MAX_PLAYER_OBJECTS][PlayerObjectInfo];
new LastObjectInfoIndexUsed, TotalLoadedPlayerObjects;
// Stores player object data into the memory

enum eObjectData
{
	ID,
	Name[32],
	Size,
	UsesType,
	SlotsInside,
	UsesSlot,
	MaxUses,
	Float:Weight,
	Display,
	DisplayColor,
	Float:DisplayOffsets[4],
	Float:OnHandOffsets[6],
	Float:OnBodyOffsets[7],
	Float:ObjectScales[3],
	SpecialFlag_1,
	SpecialFlag_2,
	SpecialFlag_3
}
new ObjectData[MAX_BASE_OBJECTS][eObjectData];
new LastObjectDataIndexUsed, TotalLoadedBaseObjects;
// Stores each object individual information


enum eSlotData
{
	SlotID,
	SlotName[32],
 	MaxObjects
}
new SlotData[MAX_SLOTS][eSlotData];
new LastSlotDataIndexUsed, TotalLoadedSlots;
// Stores each object individual information

enum PlayerVariables
{
	ContainersInPages[13], //MAX_CONTAINERS_LIMIT / MAX_CONTAINERS_PER_PAGE rounded up
	DroppedContainersInPages[13], //MAX_CONTAINERS_LIMIT / MAX_CONTAINERS_PER_PAGE rounded up
	ContainerStoredInSlot[MAX_CONTAINERS_PER_PAGE+1], //+1 for the onhand inventory
	DroppedContainerStoredInSlot[MAX_CONTAINERS_PER_PAGE],
	ActionStored[MAX_OBJECT_ACTIONS],
	ObjectInAction,
	ObjectInActionGlobal,
	ObjectInActionSource,
	CurrentListTotal,
	CurrentListPerPage,
	CurrentListPage,
	CurrentListTotalPages,
	CurrentListStorage[MAX_LIST_ITEMS],
	InventoryOpen,
	ContainersListingPage,
	DroppedContainersListingPage,
	ContainersListingMin,
	DroppedContainersListingMin,
	SelectedObjectID,
	SelectedContainerID,
	SelectedObjectSourceID,
	SelectedObjectGlobal,
	EdittingObjectID,
	EdittingActionID,
    EdittingSlotID,
	EdittingTypeID,
	EdittingListItem,
	OnHandObjectID,
	OnHandTypeID,
	OnHandWeaponID,
	OnHandAmmoObjectID,
	OnHandMagObjectID,
	OnHandSourceID,
	OnHandSourcePosition,
	ObjectStoredInIndex[10],
	ActionSwapStep,
	HasInvalidAmmo,
	WearingArmor,
	Float:DisplayingModelRotation,
	LastClickedObjectTick,
	LastClickedObjectID,
	OverridePosition,
	MemorySlot[2],
	Float:SelectedObjectHeaderY[MAX_CONTAINERS_PER_PAGE],
	HideTooltipTimerID,
	PlayerSlots[MAX_SLOTS]
}
new PlayerVar[PLAYERS][PlayerVariables];


enum eTypeInfo
{
	TypeID, //ID in database
	TypeName[32] //Name of the type itself
}
new TypeData[MAX_OBJECT_TYPES][eTypeInfo];
new LastTypeDataIndexUsed, TotalLoadedTypes;

enum eActionInfo
{
	ActionID, //ID in database
	TypeIDAttached, //ID of the type that the action goes with
	ActionName[32] //Name of the action itself
}
new ActionData[MAX_TOTAL_ACTIONS][eActionInfo];
new LastActionDataIndexUsed, TotalLoadedActions;


enum eGlobalInfo
{
	ScriptLoaded
}
new GlobalData[eGlobalInfo];


public OnFilterScriptInit()
{
	print("\n-------------------------------------------");
	print(" 	Inventory script by CuervO			");
	print(" ");
	printf("                %s                      ", VERSION);
	print(" ");
	print("Objects, Inventory, Actions - All In One!");
	print("-------------------------------------------\n");

    GlobalData[ScriptLoaded] = 0;
	ConnectMySQL();
	return 1;
}


forward LoadObjectData();
public LoadObjectData()
{
	new rows, fields, id;
	cache_get_data(rows, fields);
	
	for(new i = 0; i < rows; i ++)
	{
	    if(i == INVALID_BASEOBJECT_ID)
	        return printf("[INVENTORY ERROR]: Maximum number of Base Objects reached (%d).",MAX_BASE_OBJECTS);
	
	    id = cache_get_field_content_int(i, "ID");
	    
	    ObjectData[i][ID] = id;
		//printf("ObjectData[%d][ID] = %d", id,id);
	    
	    new temp[64];
	    cache_get_field_content(i, "Name", temp);
	    format(ObjectData[i][Name], 32, "%s", temp);
	    
        ObjectData[i][Size] = cache_get_field_content_int(i, "Size");
        ObjectData[i][UsesType] = cache_get_field_content_int(i, "UsesType");
        ObjectData[i][UsesSlot] = cache_get_field_content_int(i, "UsesSlot");
        ObjectData[i][SlotsInside] = cache_get_field_content_int(i, "SlotsInside");
        ObjectData[i][Weight] = cache_get_field_content_float(i, "Weight");
        ObjectData[i][MaxUses] = cache_get_field_content_int(i, "MaxUses");
        
        
        ObjectData[i][Display] = cache_get_field_content_int(i, "Display");
        ObjectData[i][DisplayColor] = cache_get_field_content_int(i, "DisplayColor");
        
        ObjectData[i][SpecialFlag_1] = cache_get_field_content_int(i, "SpecialFlag_1");
        ObjectData[i][SpecialFlag_2] = cache_get_field_content_int(i, "SpecialFlag_2");
        ObjectData[i][SpecialFlag_3] = cache_get_field_content_int(i, "SpecialFlag_3");
        
        cache_get_field_content(i, "OnHandOffsets", temp);
		sscanf(temp, "p<,>a<f>[6]", ObjectData[i][OnHandOffsets]);
		
		cache_get_field_content(i, "DisplayOffsets", temp);
		sscanf(temp, "p<,>a<f>[4]", ObjectData[i][DisplayOffsets]);
		
		cache_get_field_content(i, "OnBodyOffsets", temp);
		sscanf(temp, "p<,>a<f>[7]", ObjectData[i][OnBodyOffsets]);
		
		cache_get_field_content(i, "ObjectScales", temp);
		sscanf(temp, "p<,>a<f>[3]", ObjectData[i][ObjectScales]);

		LastObjectDataIndexUsed = i;
		TotalLoadedBaseObjects ++;
	}
	printf("[INVENTORY SUCCESS]: Loaded %d base objects (Last index: %d).", TotalLoadedBaseObjects, LastObjectDataIndexUsed);
	
	mysql_format(dbHandle, medquery, sizeof medquery, "SELECT * FROM playerobjects \
	JOIN objects ON playerobjects.BaseObjectID = objects.ID JOIN objectinventory ON playerobjects.PlayerID = objectinventory.PlayerObjectID");
	mysql_tquery(dbHandle, medquery, "LoadPlayerObjects", "");
	return 1;
}

forward LoadPlayerObjects();
public LoadPlayerObjects()
{
	new rows, fields, id;
	cache_get_data(rows, fields);
	for(new i = 0; i < rows; i ++)
	{
	    if(i == INVALID_PLAYEROBJECT_ID)
	        return printf("[INVENTORY ERROR]: Maximum number of Player Objects reached (%d).", MAX_PLAYER_OBJECTS);
	
	    if(cache_get_field_content_int(i, "Status") == 4)
	    {
            RemoveObjectFromDatabase(cache_get_field_content_int(i, "PlayerID"), true);
            continue;
		}
	
		id = cache_get_field_content_int(i, "PlayerID");

	    ObjectInfo[i][PlayerID] = id;
	    ObjectInfo[i][BaseID] = cache_get_field_content_int(i, "ID");

        new temp[64];
        cache_get_field_content(i, "PlayerName", temp);
	    format(ObjectInfo[i][OwnerName], 32, "%s", temp);

        ObjectInfo[i][CurrentUses] = cache_get_field_content_int(i, "CurrentUses");
        
        ObjectInfo[i][Position] = cache_get_field_content_int(i, "Position");
        ObjectInfo[i][Status] = cache_get_field_content_int(i, "Status");
        ObjectInfo[i][Condition] = cache_get_field_content_int(i, "Condition");

        ObjectInfo[i][WorldX] = cache_get_field_content_float(i, "WorldX");
        ObjectInfo[i][WorldY] = cache_get_field_content_float(i, "WorldY");
        ObjectInfo[i][WorldZ] = cache_get_field_content_float(i, "WorldZ");

        ObjectInfo[i][P_SpecialFlag_1] = cache_get_field_content_int(i, "P_SpecialFlag_1");
        ObjectInfo[i][P_SpecialFlag_2] = cache_get_field_content_int(i, "P_SpecialFlag_2");
        
        cache_get_field_content(i, "InsideIDs", temp);
		format(ObjectInfo[i][Inventory], 64, "%s", temp);
		ObjectInfo[i][InventoryID] = cache_get_field_content_int(i, "InventoryID");


		if(ObjectInfo[i][Status] == 3)
		{
		    new ObjectDataMem = GetObjectDataMemory(ObjectInfo[i][BaseID]);
		
			ObjectInfo[i][GameObject] = CreateDynamicObject(ObjectData[ObjectDataMem][Display], ObjectInfo[i][WorldX], ObjectInfo[i][WorldY], ObjectInfo[i][WorldZ], 0.0, 0.0, 0.0);
			if(ObjectData[ObjectDataMem][DisplayColor] != -1)
				SetObjectColors(ObjectInfo[i][GameObject], ObjectInfo[i][PlayerID], ObjectInfo[i][BaseID]);
				
			ObjectInfo[i][AreaID] = CreateDynamicRectangle(ObjectInfo[i][WorldX]-1, ObjectInfo[i][WorldY]-1, ObjectInfo[i][WorldX]+1, ObjectInfo[i][WorldY]+1);
		}

		LastObjectInfoIndexUsed = i;
		TotalLoadedPlayerObjects ++;
	}
	printf("[INVENTORY SUCCESS]: Loaded %d player objects (Last index: %d).", TotalLoadedPlayerObjects, LastObjectInfoIndexUsed);

	mysql_tquery(dbHandle, "SELECT * FROM actions", "LoadActionsAndTypesData");
	return 1;
}


forward LoadActionsAndTypesData();
public LoadActionsAndTypesData()
{
	new rows, fields, id;
	cache_get_data(rows, fields);

	for(new i = 0; i < rows; i ++)
	{
	    if(i == INVALID_TYPE_ID)
	        return printf("[INVENTORY ERROR]: Maximum number of Actions reached (%d).", MAX_OBJECT_ACTIONS);
	
	    id = cache_get_field_content_int(i, "ActionID");
	    
	    ActionData[i][ActionID] = id;
	    ActionData[i][TypeIDAttached] = cache_get_field_content_int(i, "UsesType");

     	new temp[32];
	    cache_get_field_content(i, "ActionName", temp);
	    format(ActionData[i][ActionName], 32, "%s", temp);

		LastActionDataIndexUsed = i;
		TotalLoadedActions ++;
	}
	
	mysql_tquery(dbHandle, "SELECT * FROM types", "LoadTypesData");
	return 1;
}

forward LoadTypesData();
public LoadTypesData()
{
	new rows, fields, id;
	cache_get_data(rows, fields);

	for(new i = 0; i < rows; i ++)
	{
	    if(i == INVALID_TYPE_ID)
	        return printf("[INVENTORY ERROR]: Maximum number of Types reached (%d).", MAX_OBJECT_TYPES);
	
	    id = cache_get_field_content_int(i, "TypeID");
	    TypeData[i][TypeID] = id;
	    
	    new temp[32];
	    cache_get_field_content(i, "TypeName", temp);
	    format(TypeData[i][TypeName], 32, "%s", temp);

		LastTypeDataIndexUsed = i;
		TotalLoadedTypes ++;
	}
	mysql_tquery(dbHandle, "SELECT * FROM slots", "LoadSlotsData");
	printf("[INVENTORY SUCCESS]: Loaded %d actions and %d types.",TotalLoadedActions,TotalLoadedTypes);
	return 1;
}

forward LoadSlotsData();
public LoadSlotsData()
{
    new rows, fields, id;
	cache_get_data(rows, fields);

	for(new i = 0; i < rows; i ++)
	{
	    if(i == INVALID_SLOT_ID)
	        return printf("[INVENTORY ERROR]: Maximum number of Slots reached (%d).", MAX_SLOTS);
	
	    id = cache_get_field_content_int(i, "SlotID");
	    SlotData[i][SlotID] = id;
	    SlotData[i][MaxObjects] = cache_get_field_content_int(i, "MaxObjects");

	    new temp[32];
	    cache_get_field_content(i, "SlotName", temp);
	    format(SlotData[i][SlotName], 32, "%s", temp);

		LastSlotDataIndexUsed ++;
		TotalLoadedSlots ++;
	}
	printf("[INVENTORY SUCCESS]: Loaded %d object slots (Last index: %d).", TotalLoadedSlots, LastSlotDataIndexUsed);
	
	GlobalData[ScriptLoaded] = 1;
	for(new i = 0; i < PLAYERS; i ++)
	    if(IsPlayerConnected(i))
	        OnPlayerConnect(i),
	        OnPlayerSpawn(i);
	        
	return 1;
}

public OnFilterScriptExit()
{
	new deleted;
	GlobalData[ScriptLoaded] = 0;

    for(new i = 0; i < PLAYERS; i ++)
	    if(IsPlayerConnected(i))
	        OnPlayerDisconnect(i, 1);

	for(new i = 0; i <= LastObjectInfoIndexUsed; i ++)
	{
		if(ObjectInfo[i][PlayerID] == 0) continue;
	
	    if(ObjectInfo[i][Status] == 3)
	    {
	        DestroyDynamicObject(ObjectInfo[i][GameObject]);
	        DestroyDynamicArea(ObjectInfo[i][AreaID]);
	        deleted ++;
	    }
	    ObjectInfo[i][PlayerID] = 0;
	}
		
	printf("[INVENTORY SUCCESS]: Unloaded inventory. Deleted %d pickups and dynamic areas.",deleted);
	return 1;
}



forward ConnectMySQL();
public ConnectMySQL()
{
    mysql_close(1);
  	mysql_log(LOG_ERROR | LOG_WARNING | LOG_DEBUG);
	dbHandle = mysql_connect(MYSQL_HOST,MYSQL_USER,MYSQL_DB,MYSQL_UPASS);
	if (!mysql_errno())
	{
	    print("[INVENTORY SUCCESS]: Connection to database succcessfully establishied.");
	    
	    mysql_format(dbHandle, medquery, sizeof medquery, "SELECT * FROM objects");
		mysql_tquery(dbHandle, medquery, "LoadObjectData", "");
	    return 1;
	}
	else
	{
		print("[CRITICAL INVENTORY]: Connection to database could not pass. Filterscript wont work at all.");
		return 0;
	}
}

stock SetObjectColors(GTAObjectID, PlayerObjectID, ObjectBaseID = -1)
{
	new objectmodel = Streamer_GetIntData(STREAMER_TYPE_OBJECT, GTAObjectID, E_STREAMER_MODEL_ID);
	if(objectmodel >= 321 && objectmodel <= 397)
	    return 1;

	if(ObjectBaseID == -1)
		ObjectBaseID = GetObjectBaseID(PlayerObjectID);

	new ObjectDataMem = GetObjectDataMemory(ObjectBaseID);

    SetDynamicObjectMaterial(GTAObjectID, 0, -1, "none", "none", RGBAToARGB(ObjectData[ObjectDataMem][DisplayColor]));
    SetDynamicObjectMaterial(GTAObjectID, 1, -1, "none", "none", RGBAToARGB(ObjectData[ObjectDataMem][DisplayColor]));
    SetDynamicObjectMaterial(GTAObjectID, 2, -1, "none", "none", RGBAToARGB(ObjectData[ObjectDataMem][DisplayColor]));
    SetDynamicObjectMaterial(GTAObjectID, 3, -1, "none", "none", RGBAToARGB(ObjectData[ObjectDataMem][DisplayColor]));
    SetDynamicObjectMaterial(GTAObjectID, 4, -1, "none", "none", RGBAToARGB(ObjectData[ObjectDataMem][DisplayColor]));
    SetDynamicObjectMaterial(GTAObjectID, 5, -1, "none", "none", RGBAToARGB(ObjectData[ObjectDataMem][DisplayColor]));
	return 1;
}

public OnPlayerSpawn(playerid)
{
	new ToSort[MAX_CONTAINERS_LIMIT][2], internal;
	SetPlayerArmour(playerid, 0.0); //ARMOR CHANGE, you might want to remove it
	
	for(new i = 0; i < MAX_CONTAINERS_LIMIT; i ++)
		ToSort[i][1] = 999;
	
    for(new i = 0; i <= LastObjectInfoIndexUsed; i ++)
	{
	    if(ObjectInfo[i][PlayerID] == 0) continue;
	    if(ObjectInfo[i][Status] != 1) continue;
	    if(strcmp(ObjectInfo[i][OwnerName], PlayerName(playerid), true) != 0) continue;
	    if(internal >= MAX_CONTAINERS_LIMIT) break;

		OnPlayerEquipContainer(playerid, ObjectInfo[i][PlayerID]);
	    ToSort[internal][0] = ObjectInfo[i][PlayerID];
	    ToSort[internal][1] = ObjectInfo[i][Position];
	    internal ++;
	}

	SortDeepArray(ToSort, 1);

	for(new i = 0; i < 9; i ++)
	{
    	if(RenderPlayerContainer(playerid, ToSort[i][0]) == 0) break;
	}
	return 1;
}

forward CheckIfPlayerHasInventory(playerid);
public CheckIfPlayerHasInventory(playerid)
{
    new rows, fields;
	cache_get_data(rows, fields);
	
	if(!rows)
	{//No inventory detected
	    mysql_format(dbHandle, medquery, sizeof medquery, "INSERT INTO playerinventories (`PlayerName`) VALUES ('%e')",PlayerName(playerid));
	    mysql_tquery(dbHandle, medquery, "OnPlayerInventoryCreated", "i", playerid);
	}
	else
	{//Inventory detected
	    mysql_format(dbHandle, medquery, sizeof medquery, "SELECT * FROM playerinventories WHERE PlayerName = '%e'",PlayerName(playerid));
		mysql_tquery(dbHandle, medquery, "LoadPlayerInventory", "i", playerid);
	}

	return 1;
}

forward OnPlayerInventoryCreated(playerid);
public OnPlayerInventoryCreated(playerid)
{
	mysql_format(dbHandle, medquery, sizeof medquery, "SELECT * FROM playerinventories WHERE PlayerName = '%e'",PlayerName(playerid));
	mysql_tquery(dbHandle, medquery, "LoadPlayerInventory", "i", playerid);
	return 1;
}

forward LoadPlayerInventory(playerid);
public LoadPlayerInventory(playerid)
{
	new charid[5];
	for(new i = 0; i <= LastSlotDataIndexUsed; i ++)
	{
	    format(charid, sizeof charid, "%d", i);
	    PlayerVar[playerid][PlayerSlots][i] = cache_get_field_content_int(0, charid);
	}
	return 1;
}


public OnPlayerConnect(playerid)
{
    for(new i; i < sizeof Inv[]; i ++)
        Inv[playerid][i] = PlayerText:INVALID_TEXT_DRAW;

	CreateInventory(playerid);
	CreatePlayerTextdraws(playerid);
	
	for(new i; i < sizeof(InventoryObjectsHead[]); i ++)
	{
	    for(new a; a < sizeof(InventoryObjectsHead[][]); a ++)
	    {
	        InventoryObjectsHead[playerid][i][a] = PlayerText:INVALID_TEXT_DRAW;
	   	}
	}

	for(new i; i < sizeof(InventoryObjectsSlots[]); i ++)
	{
	    for(new a; a < sizeof(InventoryObjectsSlots[][]); a ++)
	    {
	        InventoryObjectsSlots[playerid][i][a] = PlayerText:INVALID_TEXT_DRAW;
	   	}
	}

    
    for(new i; i < sizeof(GlobalObjectsHead[]); i ++)
	{
	    for(new a; a < sizeof(GlobalObjectsHead[][]); a ++)
	    {
	        GlobalObjectsHead[playerid][i][a] = PlayerText:INVALID_TEXT_DRAW;
	   	}
	}

	for(new i; i < sizeof(GlobalObjectsSlots[]); i ++)
	{
	    for(new a; a < sizeof(GlobalObjectsSlots[][]); a ++)
	    {
        	GlobalObjectsSlots[playerid][i][a] = PlayerText:INVALID_TEXT_DRAW;
		}
	}
	
	for(new i; i < sizeof(GlobalObjectsAmount[]); i ++)
	{
	    for(new a; a < sizeof(GlobalObjectsAmount[][]); a ++)
	    {
        	GlobalObjectsAmount[playerid][i][a] = PlayerText:INVALID_TEXT_DRAW;
		}
	}
	for(new i; i < sizeof(InventoryObjectsAmount[]); i ++)
	{
	    for(new a; a < sizeof(InventoryObjectsAmount[][]); a ++)
	    {
        	InventoryObjectsAmount[playerid][i][a] = PlayerText:INVALID_TEXT_DRAW;
		}
	}
	
    for(new i; i < sizeof ActionMenu[]; i ++)
        ActionMenu[playerid][i] = PlayerText:INVALID_TEXT_DRAW;

    for(new i = 0; i < 13; i ++)
    {
    	PlayerVar[playerid][ContainersInPages][i] = 0;
    	PlayerVar[playerid][DroppedContainersInPages][i] = 0;
	}
	for(new i = 0; i < MAX_CONTAINERS_PER_PAGE; i ++)
    {
        PlayerVar[playerid][ContainerStoredInSlot][i] = 0;
        PlayerVar[playerid][DroppedContainerStoredInSlot][i] = 0;
    }
    for(new i = 0; i < MAX_OBJECT_ACTIONS; i ++)
    {
        PlayerVar[playerid][ActionStored][i] = 0;
    }
	PlayerVar[playerid][ObjectInAction] = 0;
	PlayerVar[playerid][ObjectInActionGlobal] = 0;
    PlayerVar[playerid][ObjectInActionSource] = 0;
    
    PlayerVar[playerid][CurrentListTotal] = 0;
    PlayerVar[playerid][CurrentListPerPage] = 0;
    PlayerVar[playerid][CurrentListPage] = 0;
    PlayerVar[playerid][CurrentListTotalPages] = 0;
    for(new i = 0; i < MAX_LIST_ITEMS; i ++)
    {
		PlayerVar[playerid][CurrentListStorage][i] = -1;
    }
	
	PlayerVar[playerid][InventoryOpen] = 0;
 	PlayerVar[playerid][ContainersListingPage] = 1;
 	PlayerVar[playerid][DroppedContainersListingPage] = 1;
 	PlayerVar[playerid][ContainersListingMin] = 0;
 	PlayerVar[playerid][DroppedContainersListingMin] = 0;
 	
 	
 	PlayerVar[playerid][SelectedObjectID] = 0;
 	PlayerVar[playerid][SelectedContainerID] = 0;
 	PlayerVar[playerid][SelectedObjectSourceID] = 0;
 	PlayerVar[playerid][SelectedObjectGlobal] = 0;
 	
 	PlayerVar[playerid][EdittingObjectID] = 0;
 	PlayerVar[playerid][EdittingActionID] = 0;
 	PlayerVar[playerid][EdittingTypeID] = 0;
 	PlayerVar[playerid][EdittingListItem] = 0;
 	
 	PlayerVar[playerid][OnHandObjectID] = 0;
 	PlayerVar[playerid][OnHandTypeID] = 0;
 	PlayerVar[playerid][OnHandWeaponID] = 0;
 	PlayerVar[playerid][OnHandAmmoObjectID] = 0;
 	PlayerVar[playerid][OnHandMagObjectID] = 0;
 	PlayerVar[playerid][OnHandSourceID] = 0;
 	PlayerVar[playerid][OnHandSourcePosition] = 0;
 	
 	PlayerVar[playerid][ActionSwapStep] = 0;
 	PlayerVar[playerid][HasInvalidAmmo] = 0;
 	PlayerVar[playerid][WearingArmor] = 0;
 	PlayerVar[playerid][DisplayingModelRotation] = 0.0;
 	PlayerVar[playerid][LastClickedObjectTick] = GetTickCount();
 	PlayerVar[playerid][LastClickedObjectID] = 0;
 	PlayerVar[playerid][OverridePosition] = -1;
 	
 	for(new i = 0; i < MAX_SLOTS; i ++)
    {
        PlayerVar[playerid][PlayerSlots][i] = 0;
 	}
 	
 	for(new i = 0; i <= LastObjectInfoIndexUsed; i ++)
	{
	    if(ObjectInfo[i][PlayerID] == 0) continue;

	   	ObjectInfo[i][IsNear][playerid] = 0;
	}
	
	for(new i = 0; i < 2; i ++)
    {
        PlayerVar[playerid][MemorySlot][i] = 0;
    }
    for(new i = 0; i < MAX_CONTAINERS_PER_PAGE; i ++)
    {
        PlayerVar[playerid][SelectedObjectHeaderY][i] = 0;
    }
    
    PlayerVar[playerid][HideTooltipTimerID] = 0;
    
    for(new i = 1; i < 10; i ++)
		RemovePlayerAttachedObject(playerid, i),
		PlayerVar[playerid][ObjectStoredInIndex][i] = 0;
    
    mysql_format(dbHandle, medquery, sizeof medquery, "SELECT PlayerName FROM playerinventories WHERE PlayerName = '%e'",PlayerName(playerid));
	mysql_tquery(dbHandle, medquery, "CheckIfPlayerHasInventory", "i", playerid);
	return 1;
}


new ammo, pweapon, Float:armor, OnHandIDMemSlot, WearingIDMemSlot;
public OnPlayerUpdate(playerid)
{
	if(PlayerVar[playerid][OnHandObjectID] != 0)
	{
	    OnHandIDMemSlot = GetPlayerObjectMemory(PlayerVar[playerid][OnHandAmmoObjectID]);
	
	    if(ObjectInfo[OnHandIDMemSlot][PlayerID] == 0 && PlayerVar[playerid][OnHandAmmoObjectID] != 0)
	        PlayerVar[playerid][OnHandAmmoObjectID] = 0,
	        PlayerVar[playerid][HasInvalidAmmo] = 1,
	    	ResetPlayerWeapons(playerid);
	
	    GetPlayerWeaponData(playerid, GetWeaponSlot(PlayerVar[playerid][OnHandWeaponID]), pweapon, ammo);
	    
	    if(PlayerVar[playerid][OnHandWeaponID] != GetPlayerWeapon(playerid) && ammo != 0)
	        if(ammo > 0)
		        SetPlayerArmedWeapon(playerid, PlayerVar[playerid][OnHandWeaponID]);

        if(ammo <= 0)
        {
			SetPlayerArmedWeapon(playerid, 0);
		}
		
		if(PlayerVar[playerid][OnHandAmmoObjectID] != 0 && PlayerVar[playerid][HasInvalidAmmo] == 0)
		{
			if(ammo != ObjectInfo[OnHandIDMemSlot][CurrentUses] && ObjectInfo[OnHandIDMemSlot][CurrentUses] != 0)
			{
			    ObjectInfo[OnHandIDMemSlot][CurrentUses] = ammo;

			    format(query, sizeof query,"UPDATE playerobjects SET CurrentUses = %d WHERE PlayerID = %d", ammo, ObjectInfo[OnHandIDMemSlot][CurrentUses]);
				mysql_tquery(dbHandle, query, "", "");

			    if(ObjectInfo[OnHandIDMemSlot][CurrentUses] == 0)
			    {
			        RemoveObjectFromObject(INVALID_PLAYER_ID, PlayerVar[playerid][OnHandAmmoObjectID], PlayerVar[playerid][OnHandMagObjectID]);
				    RemoveObjectFromObject(INVALID_PLAYER_ID, PlayerVar[playerid][OnHandAmmoObjectID], PlayerVar[playerid][OnHandObjectID]);
			        RemoveObjectFromDatabase(PlayerVar[playerid][OnHandAmmoObjectID], true);

			        format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = 0 WHERE PlayerID = %d", PlayerVar[playerid][OnHandAmmoObjectID]);
					mysql_tquery(dbHandle, query, "", "");

					for(new i = 0; i <= LastObjectInfoIndexUsed; i ++)
			    	{
			    	    if(ObjectInfo[i][PlayerID] == 0) continue;
			    	    if(ObjectInfo[i][P_SpecialFlag_1] != PlayerVar[playerid][OnHandAmmoObjectID]) continue;

			    	    ObjectInfo[i][P_SpecialFlag_1] = 0;
	    			}

	    			PlayerVar[playerid][OnHandAmmoObjectID] = 0;
	    			PlayerVar[playerid][HasInvalidAmmo] = 1;
	    			ResetPlayerWeapons(playerid);
			    }
			}
		}
	}
	
	if(PlayerVar[playerid][WearingArmor] != 0)
	{
		WearingIDMemSlot = GetPlayerObjectMemory(PlayerVar[playerid][WearingArmor]);
		if(ObjectInfo[WearingIDMemSlot][CurrentUses] != 0)
		{
		    GetPlayerArmour(playerid, armor);

		    if(armor < ObjectInfo[WearingIDMemSlot][CurrentUses])
		    {
		   	 	ObjectInfo[WearingIDMemSlot][CurrentUses] = floatround(armor);
			}
			if(armor <= 0)
	   	 	{
	   	 	    ObjectInfo[WearingIDMemSlot][CurrentUses] = 0;
	   	 	}
		}
	}
 	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	if(PlayerVar[playerid][OnHandObjectID] != 0)
	{
		OnPlayerClickPlayerTextDraw(playerid, Inv[playerid][13]);
	}
	
	for(new i = 1; i < 10; i ++)
	    RemovePlayerAttachedObject(playerid, i);

	PlayerVar[playerid][ActionSwapStep] = 0;
	DestroyInventory(playerid);
	DestroyPlayerTextdraws(playerid);
	DestroyInventoryObjects(playerid);
	DestroyActions(playerid);
	DestroyNearInventoryObjects(playerid);
	return 1;
}

/*CMD:test(playerid, params[])
{
	//new cont,slt;
	//sscanf(params,"ii",cont,slt);

	//format(msg, sizeof msg, "Selected ID %d",PlayerVar[playerid][SelectedObjectID]);
	//RenderMessage(playerid, 0xFF0000FF, msg);
	
	//format(msg, sizeof msg, "First Empty Slot in Container %d is: %d",strval(params),FindFirstEmptySlotInContainer(strval(params)));
	//RenderMessage(playerid, 0xFF0000FF, msg);
	
	//format(msg, sizeof msg, "Player Containers: %s",GetPlayerContainers(playerid));
	//RenderMessage(playerid, 0xFF0000FF, msg);
	
	//format(msg, sizeof msg, "Container ID %d slot number %d free: %d",cont,slt,IsContainerSlotFree(cont,slt));
	//RenderMessage(playerid, 0xFF0000FF, msg);
	
	//SendTDMessage(playerid, strval(params), "Le Test Message");
	
	//SetPlayerPos(playerid, 1984.44, -266.185, 4.244);
	
	SetPlayerSkin(playerid, strval(params));
	return 1;
}*/

CMD:spawnobject(playerid, params[])
{
    if(!IsPlayerAdmin(playerid))
        return 0;

	new id[32];
	if(sscanf(params,"s[32]", id)) return Usage(playerid,"/spawnobject <object id or (part of) name>");

    new Float:fX,Float:fY,Float:fZ;
    GetPlayerPos(playerid, fX, fY, fZ);
    GetXYInFrontOfPlayer(playerid,fX,fY,1.0);

	if(IsNumeric(id))
	{
	    if(ObjectData[GetObjectDataMemory(strval(id))][ID] == 0)
			return SendTDMessage(playerid, TYPE_ERROR, "No object found in ID %d.", strval(id));
			
	    SpawnObject(fX,fY,fZ,strval(id),-1);
	}
	else
	{
	    for(new i = 0; i <= LastObjectDataIndexUsed; i ++)
		{
		    if(ObjectData[i][ID] == 0) continue; //Just in case
		
			if (strfind(ObjectData[i][Name], id, true) != -1)
			{
                SpawnObject(fX,fY,fZ,ObjectData[i][ID],-1);
				return 1;
			}
		}
		SendTDMessage(playerid, TYPE_ERROR, "No object found with a name like '%s'.", id);
	}
	return 1;
}


forward SpawnObject(Float:fX,Float:fY,Float:fZ, BaseObjectID, SpawnUses);
public SpawnObject(Float:fX,Float:fY,Float:fZ, BaseObjectID, SpawnUses)
{
    if(SpawnUses == -1) SpawnUses = ObjectData[GetObjectDataMemory(BaseObjectID)][MaxUses];
    
	mysql_format(dbHandle, medquery, sizeof medquery,
	"INSERT INTO playerobjects (BaseObjectID, CurrentUses, Status) VALUES (%d, %d, 3)",
	BaseObjectID, SpawnUses);
	
 	mysql_tquery(dbHandle, medquery, "OnNewPlayerObjectAdded", "fffii",fX,fY,fZ,SpawnUses,BaseObjectID);
	return 1;
}

forward OnNewPlayerObjectAdded(Float:fX,Float:fY,Float:fZ, SpawnUses, BaseObjectID);
public OnNewPlayerObjectAdded(Float:fX,Float:fY,Float:fZ, SpawnUses, BaseObjectID)
{
	new PlayerObjectID = cache_insert_id();
	
	//printf("OnNewPlayerObjectAdded(%.1f,%.1f,%.1f,%d,%d)",Float:fX,Float:fY,Float:fZ, SpawnUses, BaseObjectID);

    mysql_format(dbHandle, query, sizeof query, "INSERT INTO objectinventory (PlayerObjectID) VALUES (%d)",PlayerObjectID);
	mysql_tquery(dbHandle, query);
	
	
	//printf("LastObjectInfoIndexUsed %d", LastObjectInfoIndexUsed);
	//printf("New object: %d", LastObjectInfoIndexUsed+1);
	
	ObjectInfo[LastObjectInfoIndexUsed+1][PlayerID] = PlayerObjectID;
	ObjectInfo[LastObjectInfoIndexUsed+1][BaseID] = BaseObjectID;

    ObjectInfo[LastObjectInfoIndexUsed+1][CurrentUses] = SpawnUses;

    ObjectInfo[LastObjectInfoIndexUsed+1][Position] = 0;
    ObjectInfo[LastObjectInfoIndexUsed+1][Status] = 3;
    ObjectInfo[LastObjectInfoIndexUsed+1][Condition] = 100;

    ObjectInfo[LastObjectInfoIndexUsed+1][P_SpecialFlag_1] = 0;
    ObjectInfo[LastObjectInfoIndexUsed+1][P_SpecialFlag_2] = 0;
    
    LastObjectInfoIndexUsed ++;
	//printf("LastObjectInfoIndexUsed %d", LastObjectInfoIndexUsed);
	TotalLoadedPlayerObjects ++;

 	DropObjectOnPosition(-1, PlayerObjectID, fX, fY, fZ);
	return 1;
}


forward DropObjectOnPosition(playerid, PlayerObjectID, Float:fX, Float:fY, Float:fZ);
public DropObjectOnPosition(playerid, PlayerObjectID, Float:fX, Float:fY, Float:fZ)
{
	new baseid = GetObjectBaseID(PlayerObjectID);
	new memid = GetPlayerObjectMemory(PlayerObjectID);
	
	//printf("DropObjectOnPosition(%d, %d, %.1f, %.1f, %.1f) baseid = %d   memid = %d", playerid, PlayerObjectID, Float:fX, Float:fY, Float:fZ, baseid, memid);
	
	fZ -= 0.7;
	
	if(ObjectInfo[memid][Status] == 1)
	    OnPlayerUnEquipContainer(playerid, PlayerObjectID);

    ObjectInfo[memid][Status] = 3;
    ObjectInfo[memid][WorldX] = fX;
    ObjectInfo[memid][WorldY] = fY;
    ObjectInfo[memid][WorldZ] = fZ;
    ObjectInfo[memid][Position] = 0;

    format(medquery, sizeof(medquery), "UPDATE playerobjects SET PlayerName = '', Status = 3, Position = 0, WorldX = '%f', WorldY = '%f', WorldZ = '%f' WHERE PlayerID = %d", fX, fY, fZ, PlayerObjectID);
    mysql_tquery(dbHandle, medquery, "", "");

	ObjectInfo[memid][GameObject] = CreateDynamicObject(ObjectData[GetObjectDataMemory(baseid)][Display], fX,fY,fZ, 0.0, 0.0, 0.0);
	
	if(ObjectData[GetObjectDataMemory(baseid)][DisplayColor] != -1)
		SetObjectColors(ObjectInfo[memid][GameObject], PlayerObjectID);

	ObjectInfo[memid][AreaID] = CreateDynamicRectangle(fX-1.0, fY-1.0, fX+1.0, fY+1.0);

	for(new a = 0; a < PLAYERS; a ++)
	{
		if(!IsPlayerConnected(a)) continue;
		
		if(IsPlayerInRangeOfPoint(a, 1.0, fX, fY, fZ))
		    ObjectInfo[memid][IsNear][a] = 1;
		    
        if(IsPlayerInRangeOfPoint(a, 100.0, fX, fY, fZ))
			Streamer_Update(a);
	}

	if(playerid != -1)
	{
	    PlayerVar[playerid][SelectedObjectID] = 0;
        PlayerVar[playerid][SelectedContainerID] = 0;
        PlayerVar[playerid][SelectedObjectSourceID] = 0;

    	LoadPlayerContainers(playerid);
		LoadPlayerNearContainers(playerid);
	}

	CallLocalFunction("OnObjectDropped","iifff",playerid, PlayerObjectID, fX, fY, fZ);
	return 1;
}


CMD:remobject(playerid, params[])
{
    if(!IsPlayerAdmin(playerid))
        return 0;

	new id[32];
	if(sscanf(params,"s[32]", id)) return Usage(playerid,"/remobject <object id or (full) name>");

	if(IsNumeric(id))
	{
	    if(ObjectData[GetObjectDataMemory(strval(id))][ID] == 0)
	        return SendTDMessage(playerid, TYPE_ERROR, "No object found in ID %d.", strval(id));
	        
		DeleteBaseObject(strval(id));
		SendTDMessage(playerid, TYPE_INFO, "Object ID %d (%s) removed from the database. All objects using that ID (%d) were removed.", strval(id), ObjectData[GetObjectDataMemory(strval(id))][Name], strval(id));
	}
	else
	{
	    for(new i = 0; i <= LastObjectDataIndexUsed; i ++)
		{
		    if(ObjectData[i][ID] == 0) continue; //Just in case

			if (strfind(ObjectData[i][Name], id, true) != -1)
			{
                DeleteBaseObject(i);
                SendTDMessage(playerid, TYPE_INFO, "Object ID %d (%s) removed from the database. All objects using that ID (%d) were removed.", i, ObjectData[i][Name], i);
				return 1;
			}
		}
		SendTDMessage(playerid, TYPE_ERROR, "No object found in with name '%s'", id);
	}
	return 1;
}

forward DeleteBaseObject(BaseObjectID);
public DeleteBaseObject(BaseObjectID)
{
	mysql_format(dbHandle, query, sizeof query, "DELETE FROM objects WHERE ID = %d",BaseObjectID);
	mysql_tquery(dbHandle, query);
	
	//Deletes the base object from the database.
	
	for(new i = 0; i <= LastObjectInfoIndexUsed; i ++)
	{
        if(ObjectInfo[i][PlayerID] == 0) continue;
	    if(ObjectInfo[i][BaseID] != BaseObjectID) continue;
	    RemoveObjectFromDatabase(ObjectInfo[i][PlayerID], true);
	}
	
	ObjectData[GetObjectDataMemory(BaseObjectID)][ID] = 0;
	return 1;
}


CMD:actions(playerid, params[])
{
    if(!IsPlayerAdmin(playerid))
        return 0;

    new fActionID;
	sscanf(params,"I(0)",fActionID);

	if(fActionID == 0)
	{
	    ListActions(playerid, 10, 1);
	}
    else
    {
        EditAction(playerid, fActionID);
    }
	return 1;
}

forward ListActions(playerid, ItemsPerPage, Page);
public ListActions(playerid, ItemsPerPage, Page)
{
	if(ItemsPerPage > MAX_LIST_ITEMS)
	    ItemsPerPage = MAX_LIST_ITEMS;

    new characterstr[1536];
    new title[64], internal, ActionsLooped, BeginListAt, EndListAt;

    PlayerVar[playerid][CurrentListTotal] = TotalLoadedActions;
    PlayerVar[playerid][CurrentListPerPage] = ItemsPerPage;
    PlayerVar[playerid][CurrentListPage] = Page;
    PlayerVar[playerid][CurrentListTotalPages] = floatround(float(TotalLoadedActions)/float(ItemsPerPage),floatround_ceil);

    BeginListAt = (Page * ItemsPerPage) - (ItemsPerPage-1);
    EndListAt = (Page * ItemsPerPage) + (ItemsPerPage+1);

    for(new i = 0; i < MAX_LIST_ITEMS; i ++)
        PlayerVar[playerid][CurrentListStorage][i] = -1;

    for(new i = 0; i <= LastActionDataIndexUsed; i ++)
    {
        if(internal == ItemsPerPage) break;
        if(ActionData[i][ActionID] == 0) continue;

        ActionsLooped ++;

        if(ActionsLooped < BeginListAt) continue;
        if(ActionsLooped > EndListAt) break;

        format(characterstr, 1536, "%s{FF6600}ID: {FFFFFF}%02d",characterstr,ActionData[i][ActionID]);
        format(characterstr, 1536, "%s\t\t{FF6600}Attached Type: {FFFFFF}%02d",characterstr,ActionData[i][TypeIDAttached]);
		format(characterstr, 1536, "%s\t{FF6600}Action: {FFFFFF}%s",characterstr, ActionData[i][ActionName]);
		format(characterstr, 1536, "%s\n",characterstr);

        PlayerVar[playerid][CurrentListStorage][internal] = ActionData[i][ActionID];
        internal ++;
    }


    format(title, sizeof(title),"{FFFFFF}Click the action to edit it. {BBBBBB}(%d/%d)", Page, PlayerVar[playerid][CurrentListTotalPages]);
    ShowPlayerDialog(playerid, 850, DIALOG_STYLE_LIST, title,characterstr,"Expand","Next >");
	return 1;
}

forward EditAction(playerid, fActionID);
public EditAction(playerid, fActionID)
{
	new listingmessage[1024 + 512];
	new title[32];
	format(title, sizeof title,"Action ID %d Edition", fActionID);

	new ActionIDMem = GetActionDataMemory(fActionID);

	format(listingmessage, sizeof listingmessage, "{FF6600}Action:\t\t\t{FFFFFF}%s\n",ActionData[ActionIDMem][ActionName]);
	
	if(ActionData[ActionIDMem][TypeIDAttached] > 0)
	{
		format(listingmessage, sizeof listingmessage, "%s{FF6600}Attached Type:\t\t{FFFFFF}%d (%s)\n",listingmessage, ActionData[ActionIDMem][TypeIDAttached], TypeData[GetTypeDataMemory(ActionData[ActionIDMem][TypeIDAttached])][TypeName]);
	}
	else
	{
	    format(listingmessage, sizeof listingmessage, "%s{FF6600}Attached Type:\t\t{FFFFFF}%d (Scripted Event)\n",listingmessage, ActionData[ActionIDMem][TypeIDAttached]);
	}

	PlayerVar[playerid][EdittingActionID] = fActionID;
    ShowPlayerDialog(playerid, 851, DIALOG_STYLE_LIST, title, listingmessage, "Edit", "Exit");
	return 1;
}


CMD:newaction(playerid, params[])
{
    if(!IsPlayerAdmin(playerid))
        return 0;

    if(!isnull(params)) return Usage(playerid,"/newaction");

    mysql_format(dbHandle, query, 128, "INSERT INTO `actions` (ActionName,UsesType) VALUES ('New_Action',10)");
	mysql_tquery(dbHandle, query, "OnPlayerCreateAction", "i", playerid);
	return 1;
}


forward OnPlayerCreateAction(playerid);
public OnPlayerCreateAction(playerid)
{
	new fActionID = cache_insert_id();
	
	ActionData[LastActionDataIndexUsed+1][ActionID] = fActionID;
	ActionData[LastActionDataIndexUsed+1][TypeIDAttached] = 10;
	format(ActionData[LastActionDataIndexUsed+1][ActionName], 32, "New_Action");
	
    LastActionDataIndexUsed ++;
    EditAction(playerid, fActionID);
	return 1;
}

CMD:remaction(playerid, params[])
{
    if(!IsPlayerAdmin(playerid))
        return 0;

	new id[32];
	if(sscanf(params,"s[32]", id)) return Usage(playerid,"/remaction <action id or (part of) name>");

	if(IsNumeric(id))
	{
	    if(ActionData[GetActionDataMemory(strval(id))][ActionID] == 0)
	        return SendTDMessage(playerid, TYPE_ERROR, "No action found in ID %d.", strval(id));

		DeleteAction(strval(id));
		SendTDMessage(playerid, TYPE_INFO, "Action ID %d (%s) removed from the database & the memory.", strval(id), ActionData[GetActionDataMemory(strval(id))][ActionName]);
	}
	else
	{
	    for(new i = 0; i <= LastActionDataIndexUsed; i ++)
		{
		    if(ActionData[i][ActionID] == 0) continue; //Just in case

			if (strfind(ActionData[i][ActionName], id, true) != -1)
			{
			    SendTDMessage(playerid, TYPE_INFO, "Action ID %d (%s) removed from the database & the memory.", ActionData[i][ActionID], ActionData[i][ActionName]);
                DeleteAction(ActionData[i][ActionID]);
				return 1;
			}
		}
		SendTDMessage(playerid, TYPE_ERROR, "No action found with a name like '%s'", id);
	}
	return 1;
}

forward DeleteAction(fActionID);
public DeleteAction(fActionID)
{
	format(query, sizeof query,"DELETE FROM actions WHERE ActionID = %d",fActionID);
	mysql_tquery(dbHandle, query);
	
	ActionData[GetActionDataMemory(fActionID)][ActionID] = 0;
	return 1;
}

CMD:types(playerid, params[])
{
    if(!IsPlayerAdmin(playerid))
        return 0;

    new itype;
	sscanf(params,"I(0)",itype);

	if(itype == 0)
	{
	    ListTypes(playerid, 10, 1);
	}
    else
    {
		EditType(playerid, itype);
    }
	return 1;
}

CMD:newtype(playerid, params[])
{
    if(!IsPlayerAdmin(playerid))
        return 0;

    if(!isnull(params)) return Usage(playerid,"/newtype");

    mysql_format(dbHandle, query, 128, "INSERT INTO `types` (TypeName) VALUES ('New_Type')");
	mysql_tquery(dbHandle, query, "OnPlayerCreateType", "i", playerid);
	return 1;
}

forward OnPlayerCreateType(playerid);
public OnPlayerCreateType(playerid)
{
    new iTypeID = cache_insert_id();

	TypeData[LastTypeDataIndexUsed+1][TypeID] = iTypeID;
	format(TypeData[LastTypeDataIndexUsed+1][TypeName], 32, "New_Type");

    LastTypeDataIndexUsed ++;
	TotalLoadedTypes ++;

    EditType(playerid, iTypeID);
	return 1;
}

CMD:remtype(playerid, params[])
{
    if(!IsPlayerAdmin(playerid))
        return 0;

	new id[32];
	if(sscanf(params,"s[32]", id)) return Usage(playerid,"/remtype <type id or (part of) name>");

	if(IsNumeric(id))
	{
	    if(TypeData[GetTypeDataMemory(strval(id))][TypeID] == 0)
	        return SendTDMessage(playerid, TYPE_ERROR, "No type found in ID %d.", strval(id));

		DeleteType(strval(id));
		SendTDMessage(playerid, TYPE_INFO, "Type ID %d (%s) removed from the database & the memory.", strval(id), TypeData[GetTypeDataMemory(strval(id))][TypeName]);
	}
	else
	{
	    for(new i = 0; i <= LastTypeDataIndexUsed; i ++)
		{
		    if(TypeData[i][TypeID] == 0) continue; //Just in case

			if (strfind(TypeData[i][TypeName], id, true) != -1)
			{
			    SendTDMessage(playerid, TYPE_INFO, "Type ID %d (%s) removed from the database & the memory.", TypeData[i][TypeID], TypeData[i][TypeName]);
                DeleteType(TypeData[i][TypeID]);
				return 1;
			}
		}
		SendTDMessage(playerid, TYPE_ERROR, "No object found with a name like '%s'", id);
	}
	return 1;
}

forward DeleteType(iTypeID);
public DeleteType(iTypeID)
{
	format(query, sizeof query,"DELETE FROM types WHERE TypeID = %d",iTypeID);
	mysql_tquery(dbHandle, query);
	
	format(query, sizeof(query),"UPDATE objects SET UsesType = 10 WHERE UsesType = %d", iTypeID); // 10 = No Type
    mysql_tquery(dbHandle, query);

	for(new i = 0; i <= LastObjectDataIndexUsed; i ++)
	{
	    if(ObjectData[i][ID] == 0) continue;

		if(ObjectData[i][UsesType] == iTypeID)
		    ObjectData[i][UsesType] = 10;
	}
	
	format(query, sizeof(query),"UPDATE actions SET UsesType = 10 WHERE UsesType = %d", iTypeID);
    mysql_tquery(dbHandle, query);

	for(new i = 0; i <= LastActionDataIndexUsed; i ++)
	{
	    if(ActionData[i][ActionID] == 0) continue;

		if(ActionData[i][TypeIDAttached] == iTypeID)
		    ActionData[i][TypeIDAttached] = 10;
	}
	
	TotalLoadedTypes --;

	TypeData[GetTypeDataMemory(iTypeID)][TypeID] = 0;
	return 1;
}

forward ListTypes(playerid, ItemsPerPage, Page);
public ListTypes(playerid, ItemsPerPage, Page)
{
	if(ItemsPerPage > MAX_LIST_ITEMS)
	    ItemsPerPage = MAX_LIST_ITEMS;

    new characterstr[1536];
    new title[64], internal, TypesLooped, BeginListAt, EndListAt;

    PlayerVar[playerid][CurrentListTotal] = TotalLoadedTypes;
    PlayerVar[playerid][CurrentListPerPage] = ItemsPerPage;
    PlayerVar[playerid][CurrentListPage] = Page;
    PlayerVar[playerid][CurrentListTotalPages] = floatround(float(TotalLoadedTypes)/float(ItemsPerPage),floatround_ceil);

    BeginListAt = (Page * ItemsPerPage) - (ItemsPerPage-1);
    EndListAt = (Page * ItemsPerPage) + (ItemsPerPage+1);

    for(new i = 0; i < MAX_LIST_ITEMS; i ++)
        PlayerVar[playerid][CurrentListStorage][i] = -1;

    for(new i = 0; i <= LastTypeDataIndexUsed; i ++)
    {
        if(internal == ItemsPerPage) break;
        if(TypeData[i][TypeID] == 0) continue;

        TypesLooped ++;

        if(TypesLooped < BeginListAt) continue;
        if(TypesLooped > EndListAt) break;

        format(characterstr, 1536, "%s{FF6600}ID: {FFFFFF}%02d",characterstr,TypeData[i][TypeID]);
		format(characterstr, 1536, "%s\t{FF6600}Name: {FFFFFF}%s",characterstr, TypeData[i][TypeName]);
		format(characterstr, 1536, "%s\n",characterstr);

        PlayerVar[playerid][CurrentListStorage][internal] = TypeData[i][TypeID];
        internal ++;
    }


    format(title, sizeof(title),"{FFFFFF}Click the type to edit it. {BBBBBB}(%d/%d)", Page, PlayerVar[playerid][CurrentListTotalPages]);
    ShowPlayerDialog(playerid, 950, DIALOG_STYLE_LIST, title,characterstr,"Expand","Next >");
	return 1;
}

forward EditType(playerid, ifTypeID);
public EditType(playerid, ifTypeID)
{
	new listingmessage[1024 + 512];
	new title[32];
	
	format(title, sizeof title,"Type ID %d Edition", ifTypeID);
	format(listingmessage, sizeof listingmessage, "{FF6600}Name:\t\t{FFFFFF}%s\n",TypeData[GetTypeDataMemory(ifTypeID)][TypeName]);

    PlayerVar[playerid][EdittingTypeID] = ifTypeID;
    ShowPlayerDialog(playerid, 951, DIALOG_STYLE_LIST, title, listingmessage, "Edit", "Exit");
	return 1;
}

CMD:slots(playerid, params[])
{
    if(!IsPlayerAdmin(playerid))
        return 0;

    new slot;
	sscanf(params,"I(0)",slot);

	if(slot == 0)
	{
	    ListSlots(playerid, 10, 1);
	}
    else
    {
        PlayerEditSlot(playerid, slot);
    }
	return 1;
}

forward ListSlots(playerid, ItemsPerPage, Page);
public ListSlots(playerid, ItemsPerPage, Page)
{
	if(ItemsPerPage > MAX_LIST_ITEMS)
	    ItemsPerPage = MAX_LIST_ITEMS;

    new characterstr[1536];
    new title[64], internal, SlotsLooped, BeginListAt, EndListAt;

    PlayerVar[playerid][CurrentListTotal] = TotalLoadedActions;
    PlayerVar[playerid][CurrentListPerPage] = ItemsPerPage;
    PlayerVar[playerid][CurrentListPage] = Page;
    PlayerVar[playerid][CurrentListTotalPages] = floatround(float(TotalLoadedSlots)/float(ItemsPerPage),floatround_ceil);

    BeginListAt = (Page * ItemsPerPage) - (ItemsPerPage-1);
    EndListAt = (Page * ItemsPerPage) + (ItemsPerPage+1);

    for(new i = 0; i < MAX_LIST_ITEMS; i ++)
        PlayerVar[playerid][CurrentListStorage][i] = -1;

    for(new i = 0; i <= LastSlotDataIndexUsed; i ++)
    {
        if(internal == ItemsPerPage) break;
        if(SlotData[i][SlotID] == 0) continue;

        SlotsLooped ++;

        if(SlotsLooped < BeginListAt) continue;
        if(SlotsLooped > EndListAt) break;

        format(characterstr, 1536, "%s{FF6600}ID: {FFFFFF}%02d",characterstr,SlotData[i][SlotID]);
        format(characterstr, 1536, "%s\t\t{FF6600}Max Objects: {FFFFFF}%02d",characterstr, SlotData[i][MaxObjects]);
		format(characterstr, 1536, "%s\t{FF6600}Slot Name: {FFFFFF}%s",characterstr, SlotData[i][SlotName]);
		format(characterstr, 1536, "%s\n",characterstr);

        PlayerVar[playerid][CurrentListStorage][internal] = SlotData[i][SlotID];
        internal ++;
    }


    format(title, sizeof(title),"{FFFFFF}Click the slot to edit it. {BBBBBB}(%d/%d)", Page, PlayerVar[playerid][CurrentListTotalPages]);
    ShowPlayerDialog(playerid, 1000, DIALOG_STYLE_LIST, title,characterstr,"Expand","Next >");
	return 1;
}

forward PlayerEditSlot(playerid, fSlotID);
public PlayerEditSlot(playerid, fSlotID)
{
	new listingmessage[1024 + 512];
	new title[32];
	format(title, sizeof title,"Slot ID %d Edition", fSlotID);

	format(listingmessage, sizeof listingmessage, "{FF6600}Slot Name:\t\t\t{FFFFFF}%s\n",SlotData[GetSlotDataMemory(fSlotID)][SlotName]);
	format(listingmessage, sizeof listingmessage, "%s{FF6600}Max Objects:\t\t\t{FFFFFF}%d\n",listingmessage, SlotData[GetSlotDataMemory(fSlotID)][MaxObjects]);

	PlayerVar[playerid][EdittingSlotID] = fSlotID;
    ShowPlayerDialog(playerid, 1001, DIALOG_STYLE_LIST, title, listingmessage, "Edit", "Exit");
	return 1;
}

CMD:newslot(playerid, params[])
{
    if(!IsPlayerAdmin(playerid))
        return 0;

    if(!isnull(params)) return Usage(playerid,"/newslot");

    mysql_format(dbHandle, query, 128, "INSERT INTO `slots` (SlotName) VALUES ('New_Slot')");
	mysql_tquery(dbHandle, query, "OnPlayerCreateSlot", "i", playerid);
	return 1;
}


CMD:remslot(playerid, params[])
{
    if(!IsPlayerAdmin(playerid))
        return 0;

	new id[32];
	if(sscanf(params,"s[32]", id)) return Usage(playerid,"/remslot <type id or (part of) name>");

	if(IsNumeric(id))
	{
	    if(SlotData[GetSlotDataMemory(strval(id))][SlotID] == 0)
	        return SendTDMessage(playerid, TYPE_ERROR, "No slot found in ID %d.", strval(id));

		DeleteSlot(strval(id));
		SendTDMessage(playerid, TYPE_INFO, "Slot ID %d (%s) removed from the database & the memory.", strval(id), SlotData[GetSlotDataMemory(strval(id))][SlotName]);
	}
	else
	{
	    for(new i = 0; i <= LastSlotDataIndexUsed; i ++)
		{
		    if(SlotData[i][SlotID] == 0) continue; //Just in case

			if (strfind(SlotData[i][SlotName], id, true) != -1)
			{
			    SendTDMessage(playerid, TYPE_INFO, "Slot ID %d (%s) removed from the database & the memory.", SlotData[i][SlotID], SlotData[i][SlotName]);
                DeleteSlot(SlotData[i][SlotID]);
				return 1;
			}
		}
		SendTDMessage(playerid, TYPE_ERROR, "No slot found with a name like '%s'", id);
	}
	return 1;
}

forward OnPlayerCreateSlot(playerid);
public OnPlayerCreateSlot(playerid)
{
	mysql_format(dbHandle, query, sizeof query,"ALTER TABLE playerinventories ADD `%d` INT(5)",cache_insert_id());
	mysql_tquery(dbHandle, query);
	
	SlotData[LastSlotDataIndexUsed+1][SlotID] = cache_insert_id();
	format(SlotData[LastSlotDataIndexUsed+1][SlotName], 32, "New_Slot");

    LastSlotDataIndexUsed ++;
    TotalLoadedSlots ++;

	PlayerEditSlot(playerid, cache_insert_id());
	return 1;
}

forward DeleteSlot(fSlotID);
public DeleteSlot(fSlotID)
{
    format(query, sizeof query, "ALTER TABLE playerinventories DROP COLUMN `%d`",fSlotID);
    mysql_tquery(dbHandle, query);

    format(query, sizeof(query),"UPDATE objects SET UsesSlot = 1 WHERE UsesSlot = %d", fSlotID);
    mysql_tquery(dbHandle, query);

    format(query, sizeof(query),"DELETE FROM slots WHERE SlotID = %d", fSlotID);
    mysql_tquery(dbHandle, query);

	SlotData[GetSlotDataMemory(fSlotID)][SlotID] = 0;
	
	for(new i = 0; i <= LastObjectDataIndexUsed; i ++)
	{
	    if(ObjectData[i][ID] == 0) continue;
	    
		if(ObjectData[i][UsesSlot] == fSlotID)
		    ObjectData[i][UsesSlot] = 1;
	}

    TotalLoadedSlots --;
	return 1;
}



CMD:objects(playerid, params[])
{
    if(!IsPlayerAdmin(playerid))
        return 0;

    new object;
	sscanf(params,"I(0)",object);
	
	if(object == 0)
	{
	    ListObjects(playerid, 10, 1);
	}
    else
    {
        PlayerEditBaseObject(playerid, object);
    }
	return 1;
}

forward ListObjects(playerid, ItemsPerPage, Page);
public ListObjects(playerid, ItemsPerPage, Page)
{
	if(ItemsPerPage > MAX_LIST_ITEMS)
	    ItemsPerPage = MAX_LIST_ITEMS;

    new characterstr[1536];
    new title[64], internal, ObjectsLooped, BeginListAt, EndListAt;
    
    PlayerVar[playerid][CurrentListTotal] = TotalLoadedBaseObjects;
    PlayerVar[playerid][CurrentListPerPage] = ItemsPerPage;
    PlayerVar[playerid][CurrentListPage] = Page;
    PlayerVar[playerid][CurrentListTotalPages] = floatround(float(TotalLoadedBaseObjects)/float(ItemsPerPage),floatround_ceil);
    
    BeginListAt = (Page * ItemsPerPage) - (ItemsPerPage-1);
    EndListAt = (Page * ItemsPerPage) + (ItemsPerPage+1);
    
    for(new i = 0; i < MAX_LIST_ITEMS; i ++)
        PlayerVar[playerid][CurrentListStorage][i] = -1;
	
    for(new i = 0; i <= LastObjectDataIndexUsed; i ++)
    {
        if(internal == ItemsPerPage) break;
        if(ObjectData[i][ID] == 0) continue;
        
        ObjectsLooped ++;
        
        if(ObjectsLooped < BeginListAt) continue;
        if(ObjectsLooped > EndListAt) break;
        
        format(characterstr, 1536, "%s{FF6600}ID: {FFFFFF}%02d",characterstr,ObjectData[i][ID]);
		format(characterstr, 1536, "%s\t{FF6600}Name: {FFFFFF}%s",characterstr, ObjectData[i][Name]);
		if(strlen(ObjectData[i][Name]) < 8)
		    format(characterstr, 1536, "%s\t\t",characterstr);
		else if(strlen(ObjectData[i][Name]) < 15)
		    format(characterstr, 1536, "%s\t",characterstr);

		format(characterstr, 1536, "%s\t{FF6600}Type: {FFFFFF}%s",characterstr, TypeData[GetTypeDataMemory(ObjectData[i][UsesType])][TypeName]);
		format(characterstr, 1536, "%s\n",characterstr);
    
        PlayerVar[playerid][CurrentListStorage][internal] = ObjectData[i][ID];
        internal ++;
    }


    format(title, sizeof(title),"{FFFFFF}Click the object to edit it. {BBBBBB}(%d/%d)", Page, PlayerVar[playerid][CurrentListTotalPages]);
    ShowPlayerDialog(playerid, 900, DIALOG_STYLE_LIST, title,characterstr,"Expand","Next >");
	return 1;
}


CMD:newobject(playerid, params[])
{
    if(!IsPlayerAdmin(playerid))
        return 0;

    if(!isnull(params)) return Usage(playerid,"/newobject");

    mysql_format(dbHandle, query, 128, "INSERT INTO `objects` (Name) VALUES ('New_Object')");
	mysql_tquery(dbHandle, query, "OnPlayerCreateBaseObject", "ii", playerid, 0);
	return 1;
}



forward OnPlayerCreateBaseObject(playerid, Duplicate);
public OnPlayerCreateBaseObject(playerid, Duplicate)
{
    new BaseObjectID = cache_insert_id();
	ObjectData[LastObjectDataIndexUsed+1][ID] = BaseObjectID;
	
	if(Duplicate == 0)
	{
		format(ObjectData[LastObjectDataIndexUsed+1][Name],32,"New_Object");
		ObjectData[LastObjectDataIndexUsed+1][Size] = 0;

		ObjectData[LastObjectDataIndexUsed+1][UsesType] = 10; //10 is No Type
		ObjectData[LastObjectDataIndexUsed+1][UsesSlot] = 1;
		ObjectData[LastObjectDataIndexUsed+1][SlotsInside] = 0;
		ObjectData[LastObjectDataIndexUsed+1][MaxUses] = 0;
		ObjectData[LastObjectDataIndexUsed+1][Weight] = 0.0;

		ObjectData[LastObjectDataIndexUsed+1][DisplayOffsets][3] = 1.0;

		ObjectData[LastObjectDataIndexUsed+1][Display] = 19999;
		ObjectData[LastObjectDataIndexUsed+1][DisplayColor] = -1;

	    ObjectData[LastObjectDataIndexUsed+1][ObjectScales][0] = 1.0;
	    ObjectData[LastObjectDataIndexUsed+1][ObjectScales][1] = 1.0;
	    ObjectData[LastObjectDataIndexUsed+1][ObjectScales][2] = 1.0;
	}
	else
	{
		new DuplicateMemSlot = GetObjectDataMemory(Duplicate);
	
	    format(ObjectData[LastObjectDataIndexUsed+1][Name],32,"%s (Copy)",ObjectData[DuplicateMemSlot][Name]);
		ObjectData[LastObjectDataIndexUsed+1][Size] = ObjectData[DuplicateMemSlot][Size];

		ObjectData[LastObjectDataIndexUsed+1][UsesType] = ObjectData[DuplicateMemSlot][UsesType];
		ObjectData[LastObjectDataIndexUsed+1][UsesSlot] = ObjectData[DuplicateMemSlot][UsesSlot];
		ObjectData[LastObjectDataIndexUsed+1][SlotsInside] = ObjectData[DuplicateMemSlot][SlotsInside];
		ObjectData[LastObjectDataIndexUsed+1][MaxUses] = ObjectData[DuplicateMemSlot][MaxUses];
		ObjectData[LastObjectDataIndexUsed+1][Weight] = ObjectData[DuplicateMemSlot][Weight];

		for(new i = 0; i < 4; i ++)
	        ObjectData[LastObjectDataIndexUsed+1][DisplayOffsets][i] = ObjectData[DuplicateMemSlot][DisplayOffsets][i];
        for(new i = 0; i < 6; i ++)
	        ObjectData[LastObjectDataIndexUsed+1][OnHandOffsets][i] = ObjectData[DuplicateMemSlot][OnHandOffsets][i];
        for(new i = 0; i < 7; i ++)
	        ObjectData[LastObjectDataIndexUsed+1][OnBodyOffsets][i] = ObjectData[DuplicateMemSlot][OnBodyOffsets][i];
        for(new i = 0; i < 3; i ++)
	        ObjectData[LastObjectDataIndexUsed+1][ObjectScales][i] = ObjectData[DuplicateMemSlot][ObjectScales][i];

		ObjectData[LastObjectDataIndexUsed+1][Display] = ObjectData[DuplicateMemSlot][Display];
		ObjectData[LastObjectDataIndexUsed+1][DisplayColor] = ObjectData[DuplicateMemSlot][DisplayColor];
		
		ObjectData[LastObjectDataIndexUsed+1][SpecialFlag_1] = ObjectData[DuplicateMemSlot][SpecialFlag_1];
		ObjectData[LastObjectDataIndexUsed+1][SpecialFlag_2] = ObjectData[DuplicateMemSlot][SpecialFlag_2];
		ObjectData[LastObjectDataIndexUsed+1][SpecialFlag_3] = ObjectData[DuplicateMemSlot][SpecialFlag_3];
		
        mysql_format(dbHandle, medquery, sizeof medquery,"UPDATE objects SET DisplayOffsets = '%.3f,%.3f,%.3f,%.3f' WHERE ID = %d",
		ObjectData[LastObjectDataIndexUsed+1][DisplayOffsets][0], ObjectData[LastObjectDataIndexUsed+1][DisplayOffsets][1], ObjectData[LastObjectDataIndexUsed+1][DisplayOffsets][2],
		ObjectData[LastObjectDataIndexUsed+1][DisplayOffsets][3], BaseObjectID);
		mysql_tquery(dbHandle, medquery, "", "");
		
		mysql_format(dbHandle, medquery, sizeof medquery,"UPDATE objects SET OnHandOffsets = '%.3f,%.3f,%.3f,%.3f,%.3f,%.3f' WHERE ID = %d",
		ObjectData[LastObjectDataIndexUsed+1][OnHandOffsets][0], ObjectData[LastObjectDataIndexUsed+1][OnHandOffsets][1], ObjectData[LastObjectDataIndexUsed+1][OnHandOffsets][2],
		ObjectData[LastObjectDataIndexUsed+1][OnHandOffsets][3], ObjectData[LastObjectDataIndexUsed+1][OnHandOffsets][4], ObjectData[LastObjectDataIndexUsed+1][OnHandOffsets][5], BaseObjectID);
		mysql_tquery(dbHandle, medquery, "", "");
		
		mysql_format(dbHandle, medquery, sizeof medquery,"UPDATE objects SET OnBodyOffsets = '%.0f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f' WHERE ID = %d",
		ObjectData[LastObjectDataIndexUsed+1][OnBodyOffsets][0], ObjectData[LastObjectDataIndexUsed+1][OnBodyOffsets][1], ObjectData[LastObjectDataIndexUsed+1][OnBodyOffsets][2],
		ObjectData[LastObjectDataIndexUsed+1][OnBodyOffsets][3], ObjectData[LastObjectDataIndexUsed+1][OnBodyOffsets][4], ObjectData[LastObjectDataIndexUsed+1][OnBodyOffsets][5],
		ObjectData[LastObjectDataIndexUsed+1][OnBodyOffsets][6], BaseObjectID);
		mysql_tquery(dbHandle, medquery, "", "");
		
		mysql_format(dbHandle, medquery, sizeof medquery,"UPDATE objects SET ObjectScales = '%.3f,%.3f,%.3f' WHERE ID = %d",
		ObjectData[LastObjectDataIndexUsed+1][ObjectScales][0], ObjectData[LastObjectDataIndexUsed+1][ObjectScales][1], ObjectData[LastObjectDataIndexUsed+1][ObjectScales][2], BaseObjectID);
		mysql_tquery(dbHandle, medquery, "", "");
		
		mysql_format(dbHandle, medquery, sizeof medquery,
		"UPDATE objects SET Name = '%e', Size = %d, UsesType = %d, UsesSlot = %d, SlotsInside = %d, MaxUses = %d, Weight = %.2f, Display = %d, DisplayColor = %d, SpecialFlag_1 = %d, SpecialFlag_2 = %d, SpecialFlag_3 = %d WHERE ID = %d",
		ObjectData[LastObjectDataIndexUsed+1][Name], ObjectData[LastObjectDataIndexUsed+1][Size], ObjectData[LastObjectDataIndexUsed+1][UsesType], ObjectData[LastObjectDataIndexUsed+1][UsesSlot], ObjectData[LastObjectDataIndexUsed+1][SlotsInside],
		ObjectData[LastObjectDataIndexUsed+1][MaxUses], ObjectData[LastObjectDataIndexUsed+1][Weight], ObjectData[LastObjectDataIndexUsed+1][Display], ObjectData[LastObjectDataIndexUsed+1][DisplayColor], ObjectData[LastObjectDataIndexUsed+1][SpecialFlag_1],
		ObjectData[LastObjectDataIndexUsed+1][SpecialFlag_2], ObjectData[LastObjectDataIndexUsed+1][SpecialFlag_3], BaseObjectID);
		mysql_tquery(dbHandle, medquery, "", "");

	}
	
	LastObjectDataIndexUsed ++;
    TotalLoadedBaseObjects ++;

    PlayerEditBaseObject(playerid, BaseObjectID);
	return 1;
}

forward PlayerEditBaseObject(playerid, BaseObjectID);
public PlayerEditBaseObject(playerid, BaseObjectID)
{

	new listingmessage[2048];
	new title[32];
	format(title, 32, "Object ID %d Edition", BaseObjectID);
	
	new BaseObjectMem = GetObjectDataMemory(BaseObjectID);

	format(listingmessage, sizeof listingmessage, "{FF6600}Name:\t\t{FFFFFF}%s\n",ObjectData[BaseObjectMem][Name]);
	format(listingmessage, sizeof listingmessage, "%s{FF6600}Size:\t\t{FFFFFF}%d\n",listingmessage, ObjectData[BaseObjectMem][Size]);
    format(listingmessage, sizeof listingmessage, "%s{FF6600}Type:\t\t{FFFFFF}%s\n",listingmessage, TypeData[GetTypeDataMemory(ObjectData[BaseObjectMem][UsesType])][TypeName]);
    format(listingmessage, sizeof listingmessage, "%s{FF6600}Slot:\t\t{FFFFFF}%s\n",listingmessage, SlotData[GetSlotDataMemory(ObjectData[BaseObjectMem][UsesSlot])][SlotName]);
	format(listingmessage, sizeof listingmessage, "%s{FF6600}Inventory Size:\t{FFFFFF}%d\n",listingmessage, ObjectData[BaseObjectMem][SlotsInside]);
    format(listingmessage, sizeof listingmessage, "%s{FF6600}Max Uses:\t{FFFFFF}%d\n",listingmessage, ObjectData[BaseObjectMem][MaxUses]);
    format(listingmessage, sizeof listingmessage, "%s{FF6600}Display:\t\t{FFFFFF}%d\n",listingmessage, ObjectData[BaseObjectMem][Display]);
    format(listingmessage, sizeof listingmessage, "%s{FF6600}Display Color:\t{FFFFFF}%08x\n",listingmessage, ObjectData[BaseObjectMem][DisplayColor]);
    format(listingmessage, sizeof listingmessage, "%s{FF6600}Display RX:\t{FFFFFF}%.1f\n",listingmessage, ObjectData[BaseObjectMem][DisplayOffsets][0]);
    format(listingmessage, sizeof listingmessage, "%s{FF6600}Display RY:\t{FFFFFF}%.1f\n",listingmessage, ObjectData[BaseObjectMem][DisplayOffsets][1]);
    format(listingmessage, sizeof listingmessage, "%s{FF6600}Display RZ:\t{FFFFFF}%.1f\n",listingmessage, ObjectData[BaseObjectMem][DisplayOffsets][2]);
    format(listingmessage, sizeof listingmessage, "%s{FF6600}Display Zoom:\t{FFFFFF}%.1f\n",listingmessage, ObjectData[BaseObjectMem][DisplayOffsets][3]);
    format(listingmessage, sizeof listingmessage, "%s{FF6600}Flag 1:\t\t{FFFFFF}%d\n",listingmessage, ObjectData[BaseObjectMem][SpecialFlag_1]);
    format(listingmessage, sizeof listingmessage, "%s{FF6600}Flag 2:\t\t{FFFFFF}%d\n",listingmessage, ObjectData[BaseObjectMem][SpecialFlag_2]);
    format(listingmessage, sizeof listingmessage, "%s{FF6600}Flag 3:\t\t{FFFFFF}%d\n \n",listingmessage, ObjectData[BaseObjectMem][SpecialFlag_3]);
    format(listingmessage, sizeof listingmessage, "%s{00FF00}-> Edit On Hand Offsets\n",listingmessage);
    format(listingmessage, sizeof listingmessage, "%s{00FF00}-> Edit On Body Offsets\n",listingmessage);
    format(listingmessage, sizeof listingmessage, "%s{00FF00}-> Duplicate Object\n",listingmessage);
    format(listingmessage, sizeof listingmessage, "%s{FF0000}-> Delete Object\n",listingmessage);
    
    PlayerVar[playerid][EdittingObjectID] = BaseObjectID;
    ShowPlayerDialog(playerid, 901, DIALOG_STYLE_LIST, title, listingmessage, "Edit", "Exit");
	return 1;
}


public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid == 850)
	{
		if(response)
		{
		    EditAction(playerid, PlayerVar[playerid][CurrentListStorage][listitem]);
		}
		else
		{
		    if(PlayerVar[playerid][CurrentListTotal] > PlayerVar[playerid][CurrentListPerPage])
			{
			    if(PlayerVar[playerid][CurrentListPage] == PlayerVar[playerid][CurrentListTotalPages])
			    {
			        ListActions(playerid, PlayerVar[playerid][CurrentListPerPage], 1);
			        return 1;
			    }

			    ListActions(playerid, PlayerVar[playerid][CurrentListPerPage], PlayerVar[playerid][CurrentListPage]+1);
				return 1;
			}
		}
		return 1;
	}

	if(dialogid == 851)
	{
		if(response)
		{
		    if(listitem == 0)
		        ShowPlayerDialog(playerid, 852, DIALOG_STYLE_INPUT, "New name", "Type below the new name for the action", "Ok", "Back");
		    else if(listitem == 1)
		        ShowPlayerDialog(playerid, 852, DIALOG_STYLE_INPUT, "New type", "Type below the new attached type for the action", "Ok", "Back");


            PlayerVar[playerid][EdittingListItem] = listitem;

		}
		else
	    {
	        ShowPlayerDialog(playerid, 853, DIALOG_STYLE_MSGBOX, "What do you want to do?", "Do you want to go back to edit the actions or leave the dialog?", "Actions", "Leave");
	    }
	}
	if(dialogid == 852)
	{
	    if(response)
	    {
	        if(PlayerVar[playerid][EdittingListItem] == 0)
			{ // action name
			    if(strlen(inputtext) > 32)
			        return ShowPlayerDialog(playerid, 852, DIALOG_STYLE_INPUT, "New name", "Type below the new name for the action\n\n{FF0000}ERROR: {AA0000}Name too long.", "Ok", "Back");

				mysql_format(dbHandle, query, sizeof query,"UPDATE actions SET ActionName = '%e' WHERE ActionID = %d",inputtext, PlayerVar[playerid][EdittingActionID]);
				mysql_tquery(dbHandle, query, "", "");
				
				format(ActionData[GetActionDataMemory(PlayerVar[playerid][EdittingActionID])][ActionName], 32, "%s", inputtext);
			}
			else if(PlayerVar[playerid][EdittingListItem] == 1)
			{ // type id attached
			    if(!IsNumeric(inputtext) && strval(inputtext) > 0)
			        return ShowPlayerDialog(playerid, 852, DIALOG_STYLE_INPUT, "New attached ID", "Type below the new attached type of the action\n\n{FF0000}ERROR: {AA0000}Must be a number", "Ok", "Back");


			    mysql_format(dbHandle, query, sizeof query,"UPDATE actions SET UsesType = '%d' WHERE ActionID = %d",strval(inputtext), PlayerVar[playerid][EdittingActionID]);
				mysql_tquery(dbHandle, query, "", "");
				
				ActionData[GetActionDataMemory(PlayerVar[playerid][EdittingActionID])][TypeIDAttached] = strval(inputtext);
			}

			EditAction(playerid, PlayerVar[playerid][EdittingActionID]);
	    }
	    else
	    {
		    EditAction(playerid, PlayerVar[playerid][EdittingActionID]);
	    }

	}


	if(dialogid == 853)
	{
	    if(response)
	    {
			ListActions(playerid, PlayerVar[playerid][CurrentListPerPage], PlayerVar[playerid][CurrentListPage]);
	    }
	}

 	if(dialogid == 900)
	{
		if(response)
		{
		    PlayerEditBaseObject(playerid, PlayerVar[playerid][CurrentListStorage][listitem]);
		}
		else
		{
			if(PlayerVar[playerid][CurrentListTotal] > PlayerVar[playerid][CurrentListPerPage])
			{
			    if(PlayerVar[playerid][CurrentListPage] == PlayerVar[playerid][CurrentListTotalPages])
			    {
			        ListObjects(playerid, PlayerVar[playerid][CurrentListPerPage], 1);
			        return 1;
			    }
			    
			    ListObjects(playerid, PlayerVar[playerid][CurrentListPerPage], PlayerVar[playerid][CurrentListPage]+1);
				return 1;
			}
		}
		return 1;
	}
	
	if(dialogid == 901)
	{
		if(response)
		{
		    if(listitem == 0)
		        ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New name", "Type below the new name for the object", "Ok", "Back");
		    else if(listitem == 1)
		        ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New size", "Type below the new size for the object", "Ok", "Back");
		    else if(listitem == 2)
		        ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New type", "Type below the new type for the object", "Ok", "Back");
            else if(listitem == 3)
		        ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New slot", "Type below the new slot for the object", "Ok", "Back");
            else if(listitem == 4)
		        ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New inventory size", "Type below the new inventory size for the object", "Ok", "Back");
            else if(listitem == 5)
		        ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New amount of uses", "Type below the new amount of uses for the object", "Ok", "Back");
            else if(listitem == 6)
		        ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New display", "Type below the new display id for the object", "Ok", "Back");
            else if(listitem == 11)
		        ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New display zoom offset", "Type below the new display zoom offset for the object", "Ok", "Back");
            else if(listitem == 8)
		        ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New display rx offset", "Type below the new display rx offset for the object", "Ok", "Back");
            else if(listitem == 9)
		        ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New display ry offset", "Type below the new display ry offset for the object", "Ok", "Back");
            else if(listitem == 10)
		        ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New display rz offset", "Type below the new display rz offset for the object", "Ok", "Back");
            else if(listitem == 7)
		        ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New display color", "Type below the new display color for the object", "Ok", "Back");
            else if(listitem == 12)
		        ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New flag", "Type below the new flag 1 for the object", "Ok", "Back");
		    else if(listitem == 13)
		        ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New flag 2", "Type below the new flag 2 for the object", "Ok", "Back");
		    else if(listitem == 14)
		        ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New flag 3", "Type below the new flag 3 for the object", "Ok", "Back"); //THERE IS A ONE LISTITEM JUMP HERE, 15 IS USED AS SEPARATOR
            else if(listitem == 16) //Edit on hand attachment offsets
            {
                new ObjectBaseID = PlayerVar[playerid][EdittingObjectID];
                new ObjectBaseMem = GetObjectDataMemory(ObjectBaseID);
            
                SetPlayerAttachedObject(playerid, 0, ObjectData[ObjectBaseMem][Display], 6,
				ObjectData[ObjectBaseMem][OnHandOffsets][0], ObjectData[ObjectBaseMem][OnHandOffsets][1], ObjectData[ObjectBaseMem][OnHandOffsets][2],
				ObjectData[ObjectBaseMem][OnHandOffsets][3], ObjectData[ObjectBaseMem][OnHandOffsets][4], ObjectData[ObjectBaseMem][OnHandOffsets][5],
				ObjectData[ObjectBaseMem][ObjectScales][0], ObjectData[ObjectBaseMem][ObjectScales][1], ObjectData[ObjectBaseMem][ObjectScales][2],
				RGBAToARGB(ObjectData[ObjectBaseMem][DisplayColor]), RGBAToARGB(ObjectData[ObjectBaseMem][DisplayColor]));

				EditAttachedObject(playerid, 0);
			}
			else if(listitem == 17) //Edit on body attachment offsets
            {
				new info[512], ObjectBaseID = PlayerVar[playerid][EdittingObjectID], ObjectBaseMem = GetObjectDataMemory(ObjectBaseID);
                format(info, sizeof info,
				"{FFFFFF}Press {FF6600}'Confirm' {FFFFFF}to change the object's bone attachement id.\
				\nPress {FF6600}'Continue' {FFFFFF}to not change it. {BBBBBB}(Current bone: %d)",
				floatround(ObjectData[ObjectBaseMem][OnBodyOffsets][0]));
				
				strcat(info, "\n\n\nBONE LIST:\n1 - Spine\t\t2- Head\t\t\t3 - Left Upper Arm\n4 - Right Upper Arm\t5 - Left Hand\t\t6 - Right Hand\
				\n7 - Left Thigh\t\t8 Right Thigh\t\t9 - Left Foot\n10 - Right Foot\t\t11 - Right calf\t\t12 - Left calf\
				\n13 - Left forearm\t14 - Right forearm\t15 - Left clavicle\n16 - Right clavicle\t17 - Neck\t\t18 - Jaw\n\t\t\t0 - Not Attached");
				
                ShowPlayerDialog(playerid, 904, DIALOG_STYLE_INPUT, "Edit Object Bone", info, "Confirm", "Continue");
			}
			else if(listitem == 18) //Dupe item
            {
				mysql_format(dbHandle, query, 128, "INSERT INTO `objects` (Name) VALUES ('New_Object')");
				mysql_tquery(dbHandle, query, "OnPlayerCreateBaseObject", "ii", playerid, PlayerVar[playerid][EdittingObjectID]);
            }
            else if(listitem == 19) //delete item
            {
                format(msg, sizeof msg, "{FFFFFF}Are you sure you want to delete Object ID %d?\n\n\t{FF0000}THIS CANNOT BE UNDONE",PlayerVar[playerid][EdittingObjectID]);
                ShowPlayerDialog(playerid, 905, DIALOG_STYLE_MSGBOX, "CONFIRM", msg, "Yes", "No");
            }
			else
			    PlayerEditBaseObject(playerid, PlayerVar[playerid][EdittingObjectID]);
			    
		    PlayerVar[playerid][EdittingListItem] = listitem;
		
		}
		else
	    {
	        ShowPlayerDialog(playerid, 903, DIALOG_STYLE_MSGBOX, "What do you want to do?", "Do you want to go back to edit the objects or leave the dialog?", "Objects", "Leave");
	    }
	}
	if(dialogid == 902)
	{
	    if(response)
	    {
	        if(PlayerVar[playerid][EdittingListItem] == 0)
			{ //name
			    if(strlen(inputtext) > 32)
			        return ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New name", "Type below the new name for the object\n\n{FF0000}ERROR: {AA0000}Name too long.", "Ok", "Back");
			        
				mysql_format(dbHandle, query, sizeof query,"UPDATE objects SET Name = '%e' WHERE ID = %d",inputtext, PlayerVar[playerid][EdittingObjectID]);
				mysql_tquery(dbHandle, query, "", "");
				
				format(ObjectData[GetObjectDataMemory(PlayerVar[playerid][EdittingObjectID])][Name], 32, "%s", inputtext);
			}
			else if(PlayerVar[playerid][EdittingListItem] == 1)
			{ // size
			    if(!IsNumeric(inputtext))
			        return ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New size", "Type below the new size of the object\n\n{FF0000}ERROR: {AA0000}Must be a number", "Ok", "Back");
			
			    if(strval(inputtext) > MAX_CARRY_OBJECTS)
			        return ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New size", "Type below the new size of the object\n\n{FF0000}ERROR: {AA0000}Exceded the limit", "Ok", "Back");
			        

			    mysql_format(dbHandle, query, sizeof query,"UPDATE objects SET Size = '%d' WHERE ID = %d",strval(inputtext), PlayerVar[playerid][EdittingObjectID]);
				mysql_tquery(dbHandle, query, "", "");
				
				ObjectData[GetObjectDataMemory(PlayerVar[playerid][EdittingObjectID])][Size] = strval(inputtext);
			}
			else if(PlayerVar[playerid][EdittingListItem] == 2)
			{ // type
			    if(IsNumeric(inputtext))
				{
				    if(TypeData[GetTypeDataMemory(strval(inputtext))][TypeID] == 0)
				        return ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New name", "Type below the new type of the object\n\n{FF0000}ERROR: {AA0000}Type not found", "Ok", "Back");

                    mysql_format(dbHandle, query, sizeof query,"UPDATE objects SET UsesType = %d WHERE ID = %d", strval(inputtext), PlayerVar[playerid][EdittingObjectID]);
					mysql_tquery(dbHandle, query, "", "");
					
					ObjectData[GetObjectDataMemory(PlayerVar[playerid][EdittingObjectID])][UsesType] = strval(inputtext);
				}
				else
				{
				    new found;
				    for(new i = 0; i <= LastTypeDataIndexUsed; i ++)
					{
					    if(TypeData[i][TypeID] == 0) continue; //Just in case

						if (strfind(TypeData[i][TypeName], inputtext, true) != -1)
						{
						    mysql_format(dbHandle, query, sizeof query,"UPDATE objects SET UsesType = %d WHERE ID = %d", TypeData[i][TypeID], PlayerVar[playerid][EdittingObjectID]);
							mysql_tquery(dbHandle, query, "", "");

							ObjectData[GetObjectDataMemory(PlayerVar[playerid][EdittingObjectID])][UsesType] = TypeData[i][TypeID];
							found = 1;
							break;
						}
					}
					if(!found)
                        return ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New name", "Type below the new type of the object\n\n{FF0000}ERROR: {AA0000}Type not found", "Ok", "Back");
				}
			}
			else if(PlayerVar[playerid][EdittingListItem] == 3)
			{ // slot
			    if(IsNumeric(inputtext))
				{
				    if(SlotData[GetSlotDataMemory(strval(inputtext))][SlotID] == 0)
				        return ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New slot", "Type below the new slot of the object\n\n{FF0000}ERROR: {AA0000}Slot not found", "Ok", "Back");

                    mysql_format(dbHandle, query, sizeof query,"UPDATE objects SET UsesSlot = %d WHERE ID = %d", strval(inputtext), PlayerVar[playerid][EdittingObjectID]);
					mysql_tquery(dbHandle, query, "", "");

					ObjectData[GetObjectDataMemory(PlayerVar[playerid][EdittingObjectID])][UsesSlot] = strval(inputtext);
				}
				else
				{
				    new found;
				    for(new i = 0; i <= LastSlotDataIndexUsed; i ++)
					{
					    if(SlotData[i][SlotID] == 0) continue; //Just in case

						if (strfind(SlotData[i][SlotName], inputtext, true) != -1)
						{
						    mysql_format(dbHandle, query, sizeof query,"UPDATE objects SET UsesSlot = %d WHERE ID = %d", SlotData[i][SlotID], PlayerVar[playerid][EdittingObjectID]);
							mysql_tquery(dbHandle, query, "", "");

							ObjectData[GetObjectDataMemory(PlayerVar[playerid][EdittingObjectID])][UsesSlot] = SlotData[i][SlotID];
							found = 1;
							break;
						}
					}
					if(!found)
                        return ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New slot", "Type below the new slot of the object\n\n{FF0000}ERROR: {AA0000}Slot not found", "Ok", "Back");
				}
			}
			else if(PlayerVar[playerid][EdittingListItem] == 4)
			{ // slots
			    if(!IsNumeric(inputtext))
			        return ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New amount of slots", "Type below the new amount of slots of the object\n\n{FF0000}ERROR: {AA0000}Must be a number", "Ok", "Back");

			    if(strval(inputtext) > MAX_CARRY_OBJECTS)
			        return ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New amount of slots", "Type below the new amount of slots of the object\n\n{FF0000}ERROR: {AA0000}Exceeded the limit", "Ok", "Back");


			    mysql_format(dbHandle, query, sizeof query,"UPDATE objects SET SlotsInside = '%d' WHERE ID = %d",strval(inputtext), PlayerVar[playerid][EdittingObjectID]);
				mysql_tquery(dbHandle, query, "", "");
				
				ObjectData[GetObjectDataMemory(PlayerVar[playerid][EdittingObjectID])][SlotsInside] = strval(inputtext);
			}
			else if(PlayerVar[playerid][EdittingListItem] == 5)
			{ // Max uses
			    if(!IsNumeric(inputtext))
			        return ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New amount of uses", "Type below the new amount of uses of the object\n\n{FF0000}ERROR: {AA0000}Must be a number", "Ok", "Back");


			    mysql_format(dbHandle, query, sizeof query,"UPDATE objects SET MaxUses = '%d' WHERE ID = %d",strval(inputtext), PlayerVar[playerid][EdittingObjectID]);
				mysql_tquery(dbHandle, query, "", "");
				
				ObjectData[GetObjectDataMemory(PlayerVar[playerid][EdittingObjectID])][MaxUses] = strval(inputtext);
			}
			else if(PlayerVar[playerid][EdittingListItem] == 6)
			{ // display
			    if(!IsNumeric(inputtext))
			        return ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New display", "Type below the new displaying id of the object\n\n{FF0000}ERROR: {AA0000}Must be a number", "Ok", "Back");


			    mysql_format(dbHandle, query, sizeof query,"UPDATE objects SET Display = '%d' WHERE ID = %d",strval(inputtext), PlayerVar[playerid][EdittingObjectID]);
				mysql_tquery(dbHandle, query, "", "");
				
				ObjectData[GetObjectDataMemory(PlayerVar[playerid][EdittingObjectID])][Display] = strval(inputtext);
				
				for(new i = 0; i < PLAYERS; i ++)
		        {
		            if(!IsPlayerConnected(i)) continue;
		            for(new a = 1; a < 10; a ++)
		            {
						if(ObjectInfo[GetPlayerObjectMemory(PlayerVar[i][ObjectStoredInIndex][a])][BaseID] != PlayerVar[playerid][EdittingObjectID]) continue;
						RenderPlayerContainer(i, PlayerVar[i][ObjectStoredInIndex][a]);
						break;
		            }
				}
				for(new i = 0; i <= LastObjectInfoIndexUsed; i ++)
				{
				    if(ObjectInfo[i][PlayerID] == 0) continue;
				    if(ObjectInfo[i][Status] != 3) continue;
				    if(ObjectInfo[i][BaseID] != PlayerVar[playerid][EdittingObjectID]) continue;
				    
				    
				    DestroyDynamicObject(ObjectInfo[i][GameObject]);
				    ObjectInfo[i][GameObject] = CreateDynamicObject(ObjectData[GetObjectDataMemory(ObjectInfo[i][BaseID])][Display], ObjectInfo[i][WorldX], ObjectInfo[i][WorldY], ObjectInfo[i][WorldZ], 0.0, 0.0, 0.0);
				    SetObjectColors(ObjectInfo[i][GameObject], ObjectInfo[i][PlayerID]);
				}
			}
			else if(PlayerVar[playerid][EdittingListItem] == 7)
			{ // display color
                if(strlen(inputtext) != 8)
			        return ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New display color", "Type below the new color of the object\n\n{FF0000}ERROR: {AA0000}Must be a hex (and alpha)", "Ok", "Back");

			    mysql_format(dbHandle, query, sizeof query,"UPDATE objects SET DisplayColor = '%d' WHERE ID = %d",HexToInt(inputtext), PlayerVar[playerid][EdittingObjectID]);
				mysql_tquery(dbHandle, query, "", "");

				ObjectData[GetObjectDataMemory(PlayerVar[playerid][EdittingObjectID])][DisplayColor] = HexToInt(inputtext);
				
                for(new i = 0; i < PLAYERS; i ++)
		        {
		            if(!IsPlayerConnected(i)) continue;
		            for(new a = 1; a < 10; a ++)
		            {
						if(ObjectInfo[GetPlayerObjectMemory(PlayerVar[i][ObjectStoredInIndex][a])][BaseID] != PlayerVar[playerid][EdittingObjectID]) continue;
						RenderPlayerContainer(i, PlayerVar[i][ObjectStoredInIndex][a]);
						break;
		            }
				}
				for(new i = 0; i <= LastObjectInfoIndexUsed; i ++)
				{
				    if(ObjectInfo[i][PlayerID] == 0) continue;
				    if(ObjectInfo[i][Status] != 3) continue;
				    if(ObjectInfo[i][BaseID] != PlayerVar[playerid][EdittingObjectID]) continue;

				    SetObjectColors(ObjectInfo[i][GameObject], ObjectInfo[i][PlayerID]);
				}
			}
			else if(PlayerVar[playerid][EdittingListItem] == 8)
			{ // display rx
			    if(!IsFloat(inputtext))
			        return ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New display RX offset", "Type below the new displaying rx offset of the object\n\n{FF0000}ERROR: {AA0000}Must be a float", "Ok", "Back");


				new EdittingObjectMem = GetObjectDataMemory(PlayerVar[playerid][EdittingObjectID]);

			    mysql_format(dbHandle, medquery, sizeof medquery,"UPDATE objects SET DisplayOffsets = '%.3f,%.3f,%.3f,%.3f' WHERE ID = %d",
				floatstr(inputtext), ObjectData[EdittingObjectMem][DisplayOffsets][1], ObjectData[EdittingObjectMem][DisplayOffsets][2],
				ObjectData[EdittingObjectMem][DisplayOffsets][3], PlayerVar[playerid][EdittingObjectID]);
				mysql_tquery(dbHandle, medquery, "", "");
				
				ObjectData[EdittingObjectMem][DisplayOffsets][0] = floatstr(inputtext);
			}
			else if(PlayerVar[playerid][EdittingListItem] == 9)
			{ // display y
			    if(!IsFloat(inputtext))
			        return ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New display RY offset", "Type below the new displaying ry offset of the object\n\n{FF0000}ERROR: {AA0000}Must be a float", "Ok", "Back");

                new EdittingObjectMem = GetObjectDataMemory(PlayerVar[playerid][EdittingObjectID]);

			    mysql_format(dbHandle, medquery, sizeof medquery,"UPDATE objects SET DisplayOffsets = '%.3f,%.3f,%.3f,%.3f' WHERE ID = %d",
				ObjectData[EdittingObjectMem][DisplayOffsets][0], floatstr(inputtext), ObjectData[EdittingObjectMem][DisplayOffsets][2],
				ObjectData[EdittingObjectMem][DisplayOffsets][3], PlayerVar[playerid][EdittingObjectID]);
				mysql_tquery(dbHandle, medquery, "", "");

				ObjectData[EdittingObjectMem][DisplayOffsets][1] = floatstr(inputtext);
			}
			else if(PlayerVar[playerid][EdittingListItem] == 10)
			{ // display z
			    if(!IsFloat(inputtext))
			        return ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New display RZ offset", "Type below the new displaying rz offset of the object\n\n{FF0000}ERROR: {AA0000}Must be a float", "Ok", "Back");

                new EdittingObjectMem = GetObjectDataMemory(PlayerVar[playerid][EdittingObjectID]);

			    mysql_format(dbHandle, medquery, sizeof medquery,"UPDATE objects SET DisplayOffsets = '%.3f,%.3f,%.3f,%.3f' WHERE ID = %d",
				ObjectData[EdittingObjectMem][DisplayOffsets][0], ObjectData[EdittingObjectMem][DisplayOffsets][1], floatstr(inputtext),
				ObjectData[EdittingObjectMem][DisplayOffsets][3], PlayerVar[playerid][EdittingObjectID]);
				mysql_tquery(dbHandle, medquery, "", "");

				ObjectData[EdittingObjectMem][DisplayOffsets][2] = floatstr(inputtext);
			}
			else if(PlayerVar[playerid][EdittingListItem] == 11)
			{ // display zoom
			    if(!IsFloat(inputtext))
			        return ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New display Zoom offset", "Type below the new displaying zoom of the object\n\n{FF0000}ERROR: {AA0000}Must be a float", "Ok", "Back");

                new EdittingObjectMem = GetObjectDataMemory(PlayerVar[playerid][EdittingObjectID]);

			    mysql_format(dbHandle, medquery, sizeof medquery,"UPDATE objects SET DisplayOffsets = '%.3f,%.3f,%.3f,%.3f' WHERE ID = %d",
				ObjectData[EdittingObjectMem][DisplayOffsets][0], ObjectData[EdittingObjectMem][DisplayOffsets][1],
				ObjectData[EdittingObjectMem][DisplayOffsets][2], floatstr(inputtext), PlayerVar[playerid][EdittingObjectID]);
				mysql_tquery(dbHandle, medquery, "", "");

				ObjectData[EdittingObjectMem][DisplayOffsets][3] = floatstr(inputtext);
			}
			else if(PlayerVar[playerid][EdittingListItem] == 12)
			{ // flag 1
			    if(!IsNumeric(inputtext))
			        return ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New flag 1", "Type below the new flag 1 of the object\n\n{FF0000}ERROR: {AA0000}Must be a number", "Ok", "Back");

			    mysql_format(dbHandle, query, sizeof query,"UPDATE objects SET SpecialFlag_1 = '%d' WHERE ID = %d",strval(inputtext), PlayerVar[playerid][EdittingObjectID]);
				mysql_tquery(dbHandle, query, "", "");
				
				ObjectData[GetObjectDataMemory(PlayerVar[playerid][EdittingObjectID])][SpecialFlag_1] = strval(inputtext);
			}
			else if(PlayerVar[playerid][EdittingListItem] == 13)
			{ // flag 2
			    if(!IsNumeric(inputtext))
			        return ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New flag 2", "Type below the new flag 2 of the object\n\n{FF0000}ERROR: {AA0000}Must be a number", "Ok", "Back");

			    mysql_format(dbHandle, query, sizeof query,"UPDATE objects SET SpecialFlag_2 = '%d' WHERE ID = %d",strval(inputtext), PlayerVar[playerid][EdittingObjectID]);
				mysql_tquery(dbHandle, query, "", "");
				
				ObjectData[GetObjectDataMemory(PlayerVar[playerid][EdittingObjectID])][SpecialFlag_2] = strval(inputtext);
			}
			else if(PlayerVar[playerid][EdittingListItem] == 14)
			{ // flag 3
			    if(!IsNumeric(inputtext))
			        return ShowPlayerDialog(playerid, 902, DIALOG_STYLE_INPUT, "New flag 3", "Type below the new flag 3 of the object\n\n{FF0000}ERROR: {AA0000}Must be a number", "Ok", "Back");

			    mysql_format(dbHandle, query, sizeof query,"UPDATE objects SET SpecialFlag_3 = '%d' WHERE ID = %d",strval(inputtext), PlayerVar[playerid][EdittingObjectID]);
				mysql_tquery(dbHandle, query, "", "");
				
				ObjectData[GetObjectDataMemory(PlayerVar[playerid][EdittingObjectID])][SpecialFlag_3] = strval(inputtext);
			}
			
			PlayerEditBaseObject(playerid, PlayerVar[playerid][EdittingObjectID]);
	    }
	    else
	    {
		    PlayerEditBaseObject(playerid, PlayerVar[playerid][EdittingObjectID]);
	    }
	
	}
	
	
	if(dialogid == 903)
	{
	    if(response)
	    {
	        ListObjects(playerid, PlayerVar[playerid][CurrentListPerPage], PlayerVar[playerid][CurrentListPage]);
	    }
	}
	
	if(dialogid == 904)
	{
	    new ObjectBaseID = PlayerVar[playerid][EdittingObjectID];
	    new ObjectBaseMem = GetObjectDataMemory(ObjectBaseID);
	    
	    if(response)
	    {//set new bone
	        if(!IsNumeric(inputtext) || strval(inputtext) < 0 || strval(inputtext) > 19)
	        {
	            new info[512];
                format(info, sizeof info,
				"{FFFFFF}Press {FF6600}'Confirm' {FFFFFF}to change the object's bone attachement id.\
				\nPress {FF6600}'Continue' {FFFFFF}to not change it. {BBBBBB}(Current bone: %d)\
				\n\n{FF0000}ERROR: {BB0000}Input must be a valid bone!{BBBBBB}", floatround(ObjectData[ObjectBaseMem][OnBodyOffsets][0]));
				
				strcat(info, "\n\nBONE LIST:\n1 - Spine\t\t2- Head\t\t\t3 - Left Upper Arm\n4 - Right Upper Arm\t5 - Left Hand\t\t6 - Right Hand\
				\n7 - Left Thigh\t\t8 Right Thigh\t\t9 - Left Foot\n10 - Right Foot\t\t11 - Right calf\t\t12 - Left calf\
				\n13 - Left forearm\t14 - Right forearm\t15 - Left clavicle\n16 - Right clavicle\t17 - Neck\t\t18 - Jaw\n\t\t\t0 - Not Attached");

                ShowPlayerDialog(playerid, 904, DIALOG_STYLE_INPUT, "Edit Object Bone", info, "Confirm", "Continue");
                return 1;
			}
			
			ObjectData[ObjectBaseMem][OnBodyOffsets][0] = floatstr(inputtext);
			
			if(strval(inputtext) == 0)
			{
			    format(medquery, sizeof medquery,"UPDATE objects SET OnBodyOffsets = '0,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f' WHERE ID = %d",
				ObjectData[ObjectBaseMem][OnBodyOffsets][1], ObjectData[ObjectBaseMem][OnBodyOffsets][2], ObjectData[ObjectBaseMem][OnBodyOffsets][3],
				ObjectData[ObjectBaseMem][OnBodyOffsets][4], ObjectData[ObjectBaseMem][OnBodyOffsets][5], ObjectData[ObjectBaseMem][OnBodyOffsets][6],
				ObjectData[ObjectBaseMem][ObjectScales][0], ObjectData[ObjectBaseMem][ObjectScales][1], ObjectData[ObjectBaseMem][ObjectScales][2], ObjectBaseID);
				mysql_tquery(dbHandle, medquery, "", "");
			    return PlayerEditBaseObject(playerid, PlayerVar[playerid][EdittingObjectID]);
			}
			
			SetPlayerAttachedObject(playerid, 0, ObjectData[ObjectBaseMem][Display], floatround(ObjectData[ObjectBaseMem][OnBodyOffsets][0]),
			ObjectData[ObjectBaseMem][OnBodyOffsets][1], ObjectData[ObjectBaseMem][OnBodyOffsets][2], ObjectData[ObjectBaseMem][OnBodyOffsets][3],
			ObjectData[ObjectBaseMem][OnBodyOffsets][4], ObjectData[ObjectBaseMem][OnBodyOffsets][5], ObjectData[ObjectBaseMem][OnBodyOffsets][6],
			ObjectData[ObjectBaseMem][ObjectScales][0], ObjectData[ObjectBaseMem][ObjectScales][1], ObjectData[ObjectBaseMem][ObjectScales][2],
			RGBAToARGB(ObjectData[ObjectBaseMem][DisplayColor]), RGBAToARGB(ObjectData[ObjectBaseMem][DisplayColor]));

			EditAttachedObject(playerid, 0);
	    }
	    else
	    {//continue
	        if(floatround(ObjectData[ObjectBaseMem][OnBodyOffsets][0]) != 0)
	        {
	            SetPlayerAttachedObject(playerid, 0, ObjectData[ObjectBaseMem][Display], floatround(ObjectData[ObjectBaseMem][OnBodyOffsets][0]),
				ObjectData[ObjectBaseMem][OnBodyOffsets][1], ObjectData[ObjectBaseMem][OnBodyOffsets][2], ObjectData[ObjectBaseMem][OnBodyOffsets][3],
				ObjectData[ObjectBaseMem][OnBodyOffsets][4], ObjectData[ObjectBaseMem][OnBodyOffsets][5], ObjectData[ObjectBaseMem][OnBodyOffsets][6],
				ObjectData[ObjectBaseMem][ObjectScales][0], ObjectData[ObjectBaseMem][ObjectScales][1], ObjectData[ObjectBaseMem][ObjectScales][2],
				RGBAToARGB(ObjectData[ObjectBaseMem][DisplayColor]), RGBAToARGB(ObjectData[ObjectBaseMem][DisplayColor]));

				EditAttachedObject(playerid, 0);
	    	}
	    	else
	    		return PlayerEditBaseObject(playerid, PlayerVar[playerid][EdittingObjectID]);
		}
	}
	if(dialogid == 905)
	{
		if(response)
		{
		    new idstr[5];
		    format(idstr, 5, "%d", PlayerVar[playerid][EdittingObjectID]);
		    cmd_remobject(playerid, idstr);
		    PlayerVar[playerid][EdittingObjectID] = 0;
		}
		else
		{
		    PlayerEditBaseObject(playerid, PlayerVar[playerid][EdittingObjectID]);
		    return 1;
		}
		ListObjects(playerid, PlayerVar[playerid][CurrentListPerPage], PlayerVar[playerid][CurrentListPage]);
		return 1;
	}
	
	if(dialogid == 950)
	{
		if(response)
		{
		    EditType(playerid, PlayerVar[playerid][CurrentListStorage][listitem]);
		}
		else
		{
			if(PlayerVar[playerid][CurrentListTotal] > PlayerVar[playerid][CurrentListPerPage])
			{
			    if(PlayerVar[playerid][CurrentListPage] == PlayerVar[playerid][CurrentListTotalPages])
			    {
			        ListTypes(playerid, PlayerVar[playerid][CurrentListPerPage], 1);
			        return 1;
			    }

			    ListTypes(playerid, PlayerVar[playerid][CurrentListPerPage], PlayerVar[playerid][CurrentListPage]+1);
				return 1;
			}
		}
		return 1;
	}

	if(dialogid == 951)
	{
		if(response)
		{
		    if(listitem == 0)
		        ShowPlayerDialog(playerid, 952, DIALOG_STYLE_INPUT, "New name", "Type below the new name for the type", "Ok", "Back");

		    PlayerVar[playerid][EdittingListItem] = listitem;

		}
		else
	    {
	        ShowPlayerDialog(playerid, 953, DIALOG_STYLE_MSGBOX, "What do you want to do?", "Do you want to go back to edit the types or leave the dialog?", "Types", "Leave");
	    }
	}
	if(dialogid == 952)
	{
	    if(response)
	    {
	        if(PlayerVar[playerid][EdittingListItem] == 0)
			{ // typename
			    if(strlen(inputtext) > 32)
			        return ShowPlayerDialog(playerid, 952, DIALOG_STYLE_INPUT, "New name", "Type below the new name for the type\n\n{FF0000}ERROR: {AA0000}Name too long.", "Ok", "Back");

				mysql_format(dbHandle, query, sizeof query,"UPDATE types SET TypeName = '%e' WHERE TypeID = %d",inputtext, PlayerVar[playerid][EdittingTypeID]);
				mysql_tquery(dbHandle, query, "", "");
				
				format(TypeData[GetTypeDataMemory(PlayerVar[playerid][EdittingTypeID])][TypeName], 32, "%s", inputtext);
			}

			EditType(playerid, PlayerVar[playerid][EdittingTypeID]);
	    }
	    else
	    {
		    EditType(playerid, PlayerVar[playerid][EdittingTypeID]);
	    }

	}


	if(dialogid == 953)
	{
	    if(response)
	    {
	        ListTypes(playerid, PlayerVar[playerid][CurrentListPerPage], PlayerVar[playerid][CurrentListPage]);
	    }
	}
	
	if(dialogid == 1000)
	{
		if(response)
		{
		    PlayerEditSlot(playerid, PlayerVar[playerid][CurrentListStorage][listitem]);
		}
		else
		{
		    if(PlayerVar[playerid][CurrentListTotal] > PlayerVar[playerid][CurrentListPerPage])
			{
			    if(PlayerVar[playerid][CurrentListPage] == PlayerVar[playerid][CurrentListTotalPages])
			    {
			        ListSlots(playerid, PlayerVar[playerid][CurrentListPerPage], 1);
			        return 1;
			    }

			    ListSlots(playerid, PlayerVar[playerid][CurrentListPerPage], PlayerVar[playerid][CurrentListPage]+1);
				return 1;
			}
		}
		return 1;
	}

	if(dialogid == 1001)
	{
		if(response)
		{
		    if(listitem == 0)
		        ShowPlayerDialog(playerid, 1002, DIALOG_STYLE_INPUT, "New name", "Type below the new name for the slot", "Ok", "Back");
            else if(listitem == 1)
		        ShowPlayerDialog(playerid, 1002, DIALOG_STYLE_INPUT, "New max objects", "Type below the number of max objects for the slot", "Ok", "Back");

            PlayerVar[playerid][EdittingListItem] = listitem;

		}
		else
	    {
	        ShowPlayerDialog(playerid, 1003, DIALOG_STYLE_MSGBOX, "What do you want to do?", "Do you want to go back to edit the slots or leave the dialog?", "Slots", "Leave");
	    }
	}
	if(dialogid == 1002)
	{
	    if(response)
	    {
	        if(PlayerVar[playerid][EdittingListItem] == 0)
			{ // action name
			    if(strlen(inputtext) > 32)
			        return ShowPlayerDialog(playerid, 1002, DIALOG_STYLE_INPUT, "New name", "Type below the new name for the slot\n\n{FF0000}ERROR: {AA0000}Name too long.", "Ok", "Back");

				mysql_format(dbHandle, query, sizeof query,"UPDATE slots SET SlotName = '%e' WHERE SlotID = %d",inputtext, PlayerVar[playerid][EdittingSlotID]);
				mysql_tquery(dbHandle, query, "", "");

				format(SlotData[GetSlotDataMemory(PlayerVar[playerid][EdittingSlotID])][SlotName], 32, "%s", inputtext);
			}
			else if(PlayerVar[playerid][EdittingListItem] == 1)
			{ // max objects
			    if(!IsNumeric(inputtext))
			        return ShowPlayerDialog(playerid, 1002, DIALOG_STYLE_INPUT, "New max objects", "Type below the number of max objects for the slot\n\n{FF0000}ERROR: {AA0000}Must be a number", "Ok", "Back");

			    mysql_format(dbHandle, query, sizeof query,"UPDATE slots SET MaxObjects = %d WHERE SlotID = %d",strval(inputtext), PlayerVar[playerid][EdittingSlotID]);
				mysql_tquery(dbHandle, query, "", "");

				SlotData[GetSlotDataMemory(PlayerVar[playerid][EdittingSlotID])][MaxObjects] = strval(inputtext);
			}
			PlayerEditSlot(playerid, PlayerVar[playerid][EdittingSlotID]);
	    }
	    else
	    {
		    PlayerEditSlot(playerid, PlayerVar[playerid][EdittingSlotID]);
	    }

	}


	if(dialogid == 1003)
	{
	    if(response)
	    {
			ListSlots(playerid, PlayerVar[playerid][CurrentListPerPage], PlayerVar[playerid][CurrentListPage]);
	    }
	}
	return 1;
}





public OnPlayerEditAttachedObject(playerid, response, index, modelid, boneid, Float:fOffsetX, Float:fOffsetY, Float:fOffsetZ, Float:fRotX, Float:fRotY, Float:fRotZ, Float:fScaleX, Float:fScaleY, Float:fScaleZ)
{
    if(response)
    {
        if(PlayerVar[playerid][EdittingObjectID] != 0)
        {
			new ObjectBaseID = PlayerVar[playerid][EdittingObjectID];
			new ObjectBaseMem = GetObjectDataMemory(ObjectBaseID);
			
			if(PlayerVar[playerid][EdittingListItem] == 16)
			{
				ObjectData[ObjectBaseMem][OnHandOffsets][0] = fOffsetX;
				ObjectData[ObjectBaseMem][OnHandOffsets][1] = fOffsetY;
				ObjectData[ObjectBaseMem][OnHandOffsets][2] = fOffsetZ;

				ObjectData[ObjectBaseMem][OnHandOffsets][3] = fRotX;
				ObjectData[ObjectBaseMem][OnHandOffsets][4] = fRotY;
				ObjectData[ObjectBaseMem][OnHandOffsets][5] = fRotZ;

				ObjectData[ObjectBaseMem][ObjectScales][0] = fScaleX;
				ObjectData[ObjectBaseMem][ObjectScales][1] = fScaleY;
				ObjectData[ObjectBaseMem][ObjectScales][2] = fScaleZ;

				format(medquery, sizeof medquery,"UPDATE objects SET OnHandOffsets = '%.3f,%.3f,%.3f,%.3f,%.3f,%.3f' WHERE ID = %d",
				fOffsetX, fOffsetY, fOffsetZ, fRotX, fRotY, fRotZ, ObjectBaseID);
				mysql_tquery(dbHandle, medquery, "", "");
				
				format(query, sizeof query,"UPDATE objects SET ObjectScales = '%.3f,%.3f,%.3f' WHERE ID = %d",
				fScaleX,fScaleY,fScaleZ, ObjectBaseID);
				mysql_tquery(dbHandle, query, "", "");

		        RemovePlayerAttachedObject(playerid, 0);

		        for(new i = 0; i < PLAYERS; i ++)
		        {
		            if(!IsPlayerConnected(i)) continue;
		            if(PlayerVar[i][OnHandObjectID] == 0) continue;

					if(GetObjectBaseID(PlayerVar[i][OnHandObjectID]) == ObjectBaseID)
					{
			            SetPlayerAttachedObject(i, 0, ObjectData[ObjectBaseMem][Display], 6, ObjectData[ObjectBaseMem][OnHandOffsets][0],
						ObjectData[ObjectBaseMem][OnHandOffsets][1], ObjectData[ObjectBaseMem][OnHandOffsets][2],
						ObjectData[ObjectBaseMem][OnHandOffsets][3], ObjectData[ObjectBaseMem][OnHandOffsets][4],
						ObjectData[ObjectBaseMem][OnHandOffsets][5], ObjectData[ObjectBaseMem][ObjectScales][0],
						ObjectData[ObjectBaseMem][ObjectScales][1], ObjectData[ObjectBaseMem][ObjectScales][2],
						RGBAToARGB(ObjectData[ObjectBaseMem][DisplayColor]), RGBAToARGB(ObjectData[ObjectBaseMem][DisplayColor]));
					}
		        }
			}
			else if(PlayerVar[playerid][EdittingListItem] == 17)
			{
				ObjectData[ObjectBaseMem][OnBodyOffsets][1] = fOffsetX;
				ObjectData[ObjectBaseMem][OnBodyOffsets][2] = fOffsetY;
				ObjectData[ObjectBaseMem][OnBodyOffsets][3] = fOffsetZ;

				ObjectData[ObjectBaseMem][OnBodyOffsets][4] = fRotX;
				ObjectData[ObjectBaseMem][OnBodyOffsets][5] = fRotY;
				ObjectData[ObjectBaseMem][OnBodyOffsets][6] = fRotZ;

				ObjectData[ObjectBaseMem][ObjectScales][0] = fScaleX;
				ObjectData[ObjectBaseMem][ObjectScales][1] = fScaleY;
				ObjectData[ObjectBaseMem][ObjectScales][2] = fScaleZ;

				format(medquery, sizeof medquery,"UPDATE objects SET OnBodyOffsets = '%d,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f' WHERE ID = %d",
				boneid, fOffsetX, fOffsetY, fOffsetZ, fRotX, fRotY, fRotZ, ObjectBaseID);
				mysql_tquery(dbHandle, medquery, "", "");
				
				format(query, sizeof query,"UPDATE objects SET ObjectScales = '%.3f,%.3f,%.3f' WHERE ID = %d",
				fScaleX,fScaleY,fScaleZ, ObjectBaseID);
				mysql_tquery(dbHandle, query, "", "");

		        RemovePlayerAttachedObject(playerid, 0);
		        
		        for(new i = 0; i < PLAYERS; i ++)
		        {
		            if(!IsPlayerConnected(i)) continue;
		            for(new a = 1; a < 10; a ++)
		            {
						if(ObjectInfo[GetPlayerObjectMemory(PlayerVar[i][ObjectStoredInIndex][a])][BaseID] != PlayerVar[playerid][EdittingObjectID]) continue;
						RenderPlayerContainer(i, PlayerVar[i][ObjectStoredInIndex][a]);
						break;
		            }
				}
			}
			PlayerEditBaseObject(playerid, PlayerVar[playerid][EdittingObjectID]);
		}
    }
    else
    {
        if(PlayerVar[playerid][EdittingObjectID] != 0)
        {
            new ObjectBaseID = PlayerVar[playerid][EdittingObjectID];
            new ObjectBaseMem = GetObjectDataMemory(ObjectBaseID);
        
            RemovePlayerAttachedObject(playerid, 0);

            if(GetObjectBaseID(PlayerVar[playerid][OnHandObjectID]) == ObjectBaseID)
			{
	            SetPlayerAttachedObject(playerid, 0, ObjectData[ObjectBaseMem][Display], 6, ObjectData[ObjectBaseMem][OnHandOffsets][0],
				ObjectData[ObjectBaseMem][OnHandOffsets][1], ObjectData[ObjectBaseMem][OnHandOffsets][2],
				ObjectData[ObjectBaseMem][OnHandOffsets][3], ObjectData[ObjectBaseMem][OnHandOffsets][4],
				ObjectData[ObjectBaseMem][OnHandOffsets][5], ObjectData[ObjectBaseMem][ObjectScales][0],
				ObjectData[ObjectBaseMem][ObjectScales][1], ObjectData[ObjectBaseMem][ObjectScales][2],
				RGBAToARGB(ObjectData[ObjectBaseMem][DisplayColor]), RGBAToARGB(ObjectData[ObjectBaseMem][DisplayColor]));
			}
			PlayerEditBaseObject(playerid, PlayerVar[playerid][EdittingObjectID]);
		}
    }
    return 1;
}

CMD:inventory(playerid, params[])
{
    if(!isnull(params)) return Usage(playerid,"/inventory");
	if(GlobalData[ScriptLoaded] == 0) return TDError(playerid, "Please wait, the system hasn't loaded yet.");
    

    DestroyInventoryObjects(playerid);
    ShowInventoryBase(playerid);
	
	SelectTextDraw(playerid, 0xFFFFFFFF);
	//PlayerVar[playerid][ContainersListingPage] = 1;
	//PlayerVar[playerid][ContainersListingMin] = 0;
	
	PlayerTextDrawSetString(playerid, Inv[playerid][19], "1");
	PlayerVar[playerid][DroppedContainersListingPage] = 1;
	PlayerVar[playerid][DroppedContainersListingMin] = 0;
	
	PlayerVar[playerid][InventoryOpen] = 1;
	
	LoadPlayerContainers(playerid);
	LoadPlayerNearContainers(playerid);
	return 1;
}




forward LoadPlayerNearContainers(playerid);
public LoadPlayerNearContainers(playerid)
{
    //printf("LoadPlayerNearContainers(%d)", playerid);

	new totalcontainers, totalcapacity, objects[MAX_CONTAINERS_LIMIT+1], Float:x, internal, resti;
    new mindisplay = PlayerVar[playerid][DroppedContainersListingMin];

	for(new i = 0; i <= LastObjectInfoIndexUsed; i ++)
	{
	    if(ObjectInfo[i][PlayerID] == 0) continue;
	    if(ObjectInfo[i][IsNear][playerid] == 0) continue;
	    if(ObjectInfo[i][Status] != 3) continue;
	    if(totalcontainers >= MAX_CONTAINERS_LIMIT) break;

		totalcapacity += ObjectData[GetObjectDataMemory(ObjectInfo[i][BaseID])][SlotsInside];
	    objects[internal] = ObjectInfo[i][PlayerID];
	    totalcontainers ++;
	    internal ++;
	}
	


    new tempslots = -1, lines[50] = {-1, ...}, finaldisplay=-1, totallines;
   	if(totalcontainers == 1) //display that only object
   	{
	   	finaldisplay = 0;
	   	for(new i = 0; i < totalcontainers; i ++)
	    {
	        if(i+mindisplay == totalcontainers)
	            break;
	    
	        tempslots = ObjectData[GetPlayerObjectDataMemory(objects[i+mindisplay])][SlotsInside];
			lines[i] = floatround(float(tempslots) / 6, floatround_ceil);
	    }
	}
	else
	{
     	for(new i = 0; i < totalcontainers; i ++)
	    {
	        if(i+mindisplay == totalcontainers)
	            break;
	    
	        tempslots = ObjectData[GetPlayerObjectDataMemory(objects[i+mindisplay])][SlotsInside];
			lines[i+mindisplay] = floatround(float(tempslots) / 6, floatround_ceil);
	    }
		for(new i = 0; i < sizeof(lines); i ++)
		{
		    if(lines[i] == -1)
		        continue;

		    totallines += lines[i];
		}
		finaldisplay = mindisplay+3;

		new attempts = 0;
		while(totallines > 9)
		{
		    attempts ++;

			if(attempts == 1)
				totallines = lines[0+mindisplay]+1 + lines[1+mindisplay]+1 + lines[2+mindisplay]+1,
				finaldisplay = mindisplay+2;
			else if(attempts == 2)
			    totallines = lines[0+mindisplay]+1 + lines[1+mindisplay]+1,
			    finaldisplay = mindisplay+1;
			else if(attempts == 3)
			    totallines = lines[0+mindisplay]+1,
			    finaldisplay = mindisplay;
		}

	}
	if(finaldisplay > totalcontainers)
	    finaldisplay = totalcontainers-1;

 	DestroyNearInventoryObjects(playerid);

	new Float:headery = 159.0,fbaseid,fbaseidmem, ObjectMemSlot, ObjectBaseID, ObjectBaseMem;
	for(new i = 0; i <= finaldisplay ; i ++)
	{
        if(objects[i+mindisplay] == 0) continue;
        
		if(i > MAX_CONTAINERS_PER_PAGE-1)
		    break;

	    if(lines[i+mindisplay] == -1)
	        break;
	        
	   	if(headery >= 420)
			break;

		x = 12.5;

	    if(i != 0)
		    resti = 0;
		    
		ObjectMemSlot = GetPlayerObjectMemory(objects[i+mindisplay]);
		ObjectBaseID = GetObjectBaseID(objects[i+mindisplay]);
		ObjectBaseMem = GetObjectDataMemory(ObjectBaseID);

	    GlobalObjectsHead[playerid][0][i] = CreatePlayerTextDraw(playerid, 105.000000, headery-39.0, "_"); //object header box
		PlayerTextDrawAlignment(playerid, GlobalObjectsHead[playerid][0][i], 2);
		PlayerTextDrawBackgroundColor(playerid, GlobalObjectsHead[playerid][0][i], 255);
		PlayerTextDrawFont(playerid, GlobalObjectsHead[playerid][0][i], 1);
		PlayerTextDrawLetterSize(playerid, GlobalObjectsHead[playerid][0][i], 0.300000, 4.000000);
		PlayerTextDrawColor(playerid, GlobalObjectsHead[playerid][0][i], 0);
		PlayerTextDrawSetOutline(playerid, GlobalObjectsHead[playerid][0][i], 0);
		PlayerTextDrawSetProportional(playerid, GlobalObjectsHead[playerid][0][i], 1);
		PlayerTextDrawSetShadow(playerid, GlobalObjectsHead[playerid][0][i], 0);
		PlayerTextDrawUseBox(playerid, GlobalObjectsHead[playerid][0][i], 1);
	  	if(PlayerVar[playerid][SelectedObjectID] == ObjectInfo[ObjectMemSlot][PlayerID])
			PlayerTextDrawBoxColor(playerid, GlobalObjectsHead[playerid][0][i], 0xFF660044);
		else
		    PlayerTextDrawBoxColor(playerid, GlobalObjectsHead[playerid][0][i], 0x00000044);
		PlayerTextDrawTextSize(playerid, GlobalObjectsHead[playerid][0][i], 50.000000, 196.000000);
		PlayerTextDrawSetSelectable(playerid, GlobalObjectsHead[playerid][0][i], 1);
		PlayerTextDrawShow(playerid, GlobalObjectsHead[playerid][0][i]);

		GlobalObjectsHead[playerid][1][i] = CreatePlayerTextDraw(playerid, 105.000000, headery, "Object_Body");
		PlayerTextDrawAlignment(playerid, GlobalObjectsHead[playerid][1][i], 2);
		PlayerTextDrawBackgroundColor(playerid, GlobalObjectsHead[playerid][1][i], 255);
		PlayerTextDrawFont(playerid, GlobalObjectsHead[playerid][1][i], 1);
		PlayerTextDrawLetterSize(playerid, GlobalObjectsHead[playerid][1][i], 0.300000, 4.1 * lines[i+mindisplay]);
		PlayerTextDrawColor(playerid, GlobalObjectsHead[playerid][1][i], 0);
		PlayerTextDrawSetOutline(playerid, GlobalObjectsHead[playerid][1][i], 0);
		PlayerTextDrawSetProportional(playerid, GlobalObjectsHead[playerid][1][i], 1);
		PlayerTextDrawSetShadow(playerid, GlobalObjectsHead[playerid][1][i], 0);
		PlayerTextDrawUseBox(playerid, GlobalObjectsHead[playerid][1][i], 1);
		PlayerTextDrawBoxColor(playerid, GlobalObjectsHead[playerid][1][i], 0x00000044);
		PlayerTextDrawTextSize(playerid, GlobalObjectsHead[playerid][1][i], 0.000000, 196.000000);
		PlayerTextDrawShow(playerid, GlobalObjectsHead[playerid][1][i]);


		GlobalObjectsHead[playerid][2][i] = CreatePlayerTextDraw(playerid, 6.0000000, headery-35.0, "666");
		PlayerTextDrawBackgroundColor(playerid, GlobalObjectsHead[playerid][2][i], 0);
		PlayerTextDrawFont(playerid, GlobalObjectsHead[playerid][2][i], 5);
		PlayerTextDrawLetterSize(playerid, GlobalObjectsHead[playerid][2][i], 0.500000, 1.000000);
		PlayerTextDrawSetOutline(playerid, GlobalObjectsHead[playerid][2][i], 0);
		PlayerTextDrawSetProportional(playerid, GlobalObjectsHead[playerid][2][i], 1);
		PlayerTextDrawColor(playerid, GlobalObjectsHead[playerid][2][i], ObjectData[ObjectBaseMem][DisplayColor]);
		PlayerTextDrawSetPreviewModel(playerid, GlobalObjectsHead[playerid][2][i], ObjectData[ObjectBaseMem][Display]);
		PlayerTextDrawSetPreviewRot(playerid, GlobalObjectsHead[playerid][2][i], ObjectData[ObjectBaseMem][DisplayOffsets][0],
		ObjectData[ObjectBaseMem][DisplayOffsets][1],ObjectData[ObjectBaseMem][DisplayOffsets][2],
		ObjectData[ObjectBaseMem][DisplayOffsets][3]);
		PlayerTextDrawSetShadow(playerid, GlobalObjectsHead[playerid][2][i], 1);
		PlayerTextDrawUseBox(playerid, GlobalObjectsHead[playerid][2][i], 1);
		PlayerTextDrawBoxColor(playerid, GlobalObjectsHead[playerid][2][i], 255);
		PlayerTextDrawTextSize(playerid, GlobalObjectsHead[playerid][2][i], 30.000000, 30.000000);
		PlayerTextDrawShow(playerid, GlobalObjectsHead[playerid][2][i]);

        fbaseid = GetObjectBaseID(objects[i+mindisplay]);
        fbaseidmem = GetObjectDataMemory(fbaseid);

		GlobalObjectsHead[playerid][3][i] = CreatePlayerTextDraw(playerid, 34.000000, headery-33.0, ObjectData[fbaseidmem][Name]);
		PlayerTextDrawAlignment(playerid, GlobalObjectsHead[playerid][3][i], 1);
		PlayerTextDrawBackgroundColor(playerid, GlobalObjectsHead[playerid][3][i], 255);
		PlayerTextDrawFont(playerid, GlobalObjectsHead[playerid][3][i], 2);
		if(strlen(ObjectData[fbaseidmem][Name]) > 14 && strlen(ObjectData[fbaseidmem][Name]) < 20)
			PlayerTextDrawLetterSize(playerid, GlobalObjectsHead[playerid][3][i], 0.300000, 2.400000);
		else if(strlen(ObjectData[fbaseidmem][Name]) > 20)
			PlayerTextDrawLetterSize(playerid, GlobalObjectsHead[playerid][3][i], 0.200000, 2.400000);
		else
		    PlayerTextDrawLetterSize(playerid, GlobalObjectsHead[playerid][3][i], 0.400000, 2.400000);
		PlayerTextDrawColor(playerid, GlobalObjectsHead[playerid][3][i], -1);
		PlayerTextDrawSetOutline(playerid, GlobalObjectsHead[playerid][3][i], 1);
		PlayerTextDrawSetProportional(playerid, GlobalObjectsHead[playerid][3][i], 1);
		PlayerTextDrawShow(playerid, GlobalObjectsHead[playerid][3][i]);

		GlobalObjectsHead[playerid][4][i] = CreatePlayerTextDraw(playerid, 203.000000, headery-10.0, SlotData[GetSlotDataMemory(ObjectData[fbaseidmem][UsesSlot])][SlotName]);
		PlayerTextDrawAlignment(playerid, GlobalObjectsHead[playerid][4][i], 3);
		PlayerTextDrawBackgroundColor(playerid, GlobalObjectsHead[playerid][4][i], 255);
		PlayerTextDrawFont(playerid, GlobalObjectsHead[playerid][4][i], 1);
		PlayerTextDrawLetterSize(playerid, GlobalObjectsHead[playerid][4][i], 0.149999, 0.799999);
		PlayerTextDrawColor(playerid, GlobalObjectsHead[playerid][4][i], -120);
		PlayerTextDrawSetOutline(playerid, GlobalObjectsHead[playerid][4][i], 0);
		PlayerTextDrawSetProportional(playerid, GlobalObjectsHead[playerid][4][i], 1);
		PlayerTextDrawSetShadow(playerid, GlobalObjectsHead[playerid][4][i], 0);
		PlayerTextDrawShow(playerid, GlobalObjectsHead[playerid][4][i]);

		new objectslots = ObjectData[ObjectBaseMem][SlotsInside];
		for(new a = 0; a < objectslots; a ++)
		{
		    GlobalObjectsSlots[playerid][a][i] = CreatePlayerTextDraw(playerid, x+31*(a-resti), headery+0.4, "object_slot");
			PlayerTextDrawAlignment(playerid, GlobalObjectsSlots[playerid][a][i], 2);
			PlayerTextDrawBackgroundColor(playerid, GlobalObjectsSlots[playerid][a][i], -1145324664);
			PlayerTextDrawFont(playerid, GlobalObjectsSlots[playerid][a][i], 5);
			PlayerTextDrawLetterSize(playerid, GlobalObjectsSlots[playerid][a][i], 1.100000, 1.000001);
			PlayerTextDrawColor(playerid, GlobalObjectsSlots[playerid][a][i], -1);
			PlayerTextDrawSetOutline(playerid, GlobalObjectsSlots[playerid][a][i], 0);
			PlayerTextDrawSetProportional(playerid, GlobalObjectsSlots[playerid][a][i], 1);
			PlayerTextDrawSetPreviewModel(playerid, GlobalObjectsSlots[playerid][a][i], 19300);
			PlayerTextDrawSetShadow(playerid, GlobalObjectsSlots[playerid][a][i], 1);
			PlayerTextDrawUseBox(playerid, GlobalObjectsSlots[playerid][a][i], 1);
			PlayerTextDrawBoxColor(playerid, GlobalObjectsSlots[playerid][a][i], -1145324647);
			PlayerTextDrawSetSelectable(playerid, GlobalObjectsSlots[playerid][a][i], 1);
			PlayerTextDrawTextSize(playerid, GlobalObjectsSlots[playerid][a][i], 30.000000, 36.000000);
			PlayerTextDrawShow(playerid, GlobalObjectsSlots[playerid][a][i]);
			
			GlobalObjectsAmount[playerid][a][i] = CreatePlayerTextDraw(playerid, 42.5+31*(a-resti), headery+31, "_");
			PlayerTextDrawAlignment(playerid, GlobalObjectsAmount[playerid][a][i], 3);
			PlayerTextDrawBackgroundColor(playerid, GlobalObjectsAmount[playerid][a][i], 255);
			PlayerTextDrawFont(playerid, GlobalObjectsAmount[playerid][a][i], 1);
			PlayerTextDrawLetterSize(playerid, GlobalObjectsAmount[playerid][a][i], 0.120000, 0.599999);
			PlayerTextDrawColor(playerid, GlobalObjectsAmount[playerid][a][i], -1145324647);
			PlayerTextDrawSetOutline(playerid, GlobalObjectsAmount[playerid][a][i], 0);
			PlayerTextDrawSetProportional(playerid, GlobalObjectsAmount[playerid][a][i], 1);
			PlayerTextDrawSetShadow(playerid, GlobalObjectsAmount[playerid][a][i], 0);

			if((a+1) % 6 == 0)
			{
				headery += 37;
				x = 12.5;
				resti = a+1;
			}
		}

		PlayerVar[playerid][DroppedContainerStoredInSlot][i] = ObjectInfo[ObjectMemSlot][PlayerID];
		LoadNearObjectInventory(playerid, PlayerVar[playerid][DroppedContainerStoredInSlot][i], i);
		
		PlayerVar[playerid][DroppedContainersInPages][PlayerVar[playerid][DroppedContainersListingPage] ] = i+1;
		
		if(lines[i+mindisplay] == 1)
			headery = headery + 45.0 + 39;
		else
		    headery = headery + 45.0 + 2;
	}
	return 1;
}

stock LoadPlayerContainers(playerid)
{
	//printf("LoadPlayerContainers(%d)", playerid);

    DestroyInventoryObjects(playerid);
    new totalcontainers, totalcapacity, objects[MAX_CONTAINERS_LIMIT+1][2], Float:x, internal, resti;
    new mindisplay = PlayerVar[playerid][ContainersListingMin];
    
    for(new i = 0; i < sizeof(objects); i ++)
        objects[i][1] = 999;

	for(new i = 0; i <= LastObjectInfoIndexUsed; i ++)
	{
	    if(ObjectInfo[i][PlayerID] == 0) continue;
	    if(ObjectInfo[i][Status] != 1) continue;
	    if(strcmp(ObjectInfo[i][OwnerName], PlayerName(playerid), true) != 0) continue;
	    if(totalcontainers >= MAX_CONTAINERS_LIMIT) break;
	    
		totalcapacity += ObjectData[GetObjectDataMemory(ObjectInfo[i][BaseID])][SlotsInside];
	    objects[internal][0] = ObjectInfo[i][PlayerID];
	    objects[internal][1] = ObjectInfo[i][Position];
	    totalcontainers ++;
	    internal ++;
	}
	
	SortDeepArray(objects, 1);
	
	
	
	new tempslots = -1, lines[50] = {-1, ...}, finaldisplay=-1, totallines;
   	if(totalcontainers == 1) //display that only object
   	{
	   	finaldisplay = 0;
	   	for(new i = 0; i < totalcontainers; i ++)
	    {
	        if(i+mindisplay == totalcontainers)
	            break;
	    
	        tempslots = ObjectData[GetPlayerObjectDataMemory(objects[i+mindisplay][0])][SlotsInside];
			lines[i] = floatround(float(tempslots) / 7, floatround_ceil);
	    }
	}
	else
	{
	    for(new i = 0; i < totalcontainers; i ++)
	    {
	        if(i+mindisplay == totalcontainers)
	            break;
	    
	        tempslots = ObjectData[GetPlayerObjectDataMemory(objects[i+mindisplay][0])][SlotsInside];
			lines[i+mindisplay] = floatround(float(tempslots) / 7, floatround_ceil);
	    }
		for(new i = 0; i < sizeof(lines); i ++)
		{
		    if(lines[i] == -1)
		        continue;

		    totallines += lines[i];
		}
		finaldisplay = mindisplay+3;

		new attempts = 0;
		while(totallines > 9)
		{
		    attempts ++;

			if(attempts == 1)
				totallines = lines[0+mindisplay]+1 + lines[1+mindisplay]+1 + lines[2+mindisplay]+1,
				finaldisplay = mindisplay+2;
			else if(attempts == 2)
			    totallines = lines[0+mindisplay]+1 + lines[1+mindisplay]+1,
			    finaldisplay = mindisplay+1;
			else if(attempts == 3)
			    totallines = lines[0+mindisplay]+1,
			    finaldisplay = mindisplay;
		}

	}

	if(finaldisplay > totalcontainers)
	    finaldisplay = totalcontainers-1;
	
    new Float:headery = 159.0, fbaseid, fbaseidmem, ObjectBaseID, ObjectBaseMemory, ObjectMemoryID, objectslots;
	for(new i = 0; i <= finaldisplay ; i ++)
	{
		if(objects[i+mindisplay][0] == 0) continue;
		
		if(lines[i+mindisplay] == -1)
	        break;
	        
		if(i > MAX_CONTAINERS_PER_PAGE-1)
		    break;
		    
        ObjectBaseID = GetObjectBaseID(objects[i+mindisplay][0]);
		ObjectMemoryID = GetPlayerObjectMemory(objects[i+mindisplay][0]);
		ObjectBaseMemory = GetObjectDataMemory(ObjectBaseID);
        objectslots = ObjectData[ObjectBaseMemory][SlotsInside];
        
        if(headery >= 420 || headery+(31*(objectslots/7)) >= 420)
			break;

        PlayerVar[playerid][SelectedObjectHeaderY][i] = headery;
        x = 419.0;
        if(i != 0)
		    resti = 0;
		    
	    InventoryObjectsHead[playerid][0][i] = CreatePlayerTextDraw(playerid, 527.000000, headery-39.0, "_"); //object header box
		PlayerTextDrawAlignment(playerid, InventoryObjectsHead[playerid][0][i], 2);
		PlayerTextDrawBackgroundColor(playerid, InventoryObjectsHead[playerid][0][i], 255);
		PlayerTextDrawFont(playerid, InventoryObjectsHead[playerid][0][i], 1);
		PlayerTextDrawLetterSize(playerid, InventoryObjectsHead[playerid][0][i], 0.300000, 4.000000);
		PlayerTextDrawColor(playerid, InventoryObjectsHead[playerid][0][i], 0);
		PlayerTextDrawSetOutline(playerid, InventoryObjectsHead[playerid][0][i], 0);
		PlayerTextDrawSetProportional(playerid, InventoryObjectsHead[playerid][0][i], 1);
		PlayerTextDrawSetShadow(playerid, InventoryObjectsHead[playerid][0][i], 0);
		PlayerTextDrawUseBox(playerid, InventoryObjectsHead[playerid][0][i], 1);
		
		if(PlayerVar[playerid][SelectedObjectID] == ObjectInfo[ObjectMemoryID][PlayerID])
			PlayerTextDrawBoxColor(playerid, InventoryObjectsHead[playerid][0][i], 0xFF660044);
		else
		    PlayerTextDrawBoxColor(playerid, InventoryObjectsHead[playerid][0][i], 0x00000044);
		    
		PlayerTextDrawTextSize(playerid, InventoryObjectsHead[playerid][0][i], 50.000000, 216.000000);
		PlayerTextDrawSetSelectable(playerid, InventoryObjectsHead[playerid][0][i], 1);
		PlayerTextDrawShow(playerid, InventoryObjectsHead[playerid][0][i]);

		InventoryObjectsHead[playerid][1][i] = CreatePlayerTextDraw(playerid, 527.000000, headery, "Object_Body");
		PlayerTextDrawAlignment(playerid, InventoryObjectsHead[playerid][1][i], 2);
		PlayerTextDrawBackgroundColor(playerid, InventoryObjectsHead[playerid][1][i], 255);
		PlayerTextDrawFont(playerid, InventoryObjectsHead[playerid][1][i], 1);
		PlayerTextDrawLetterSize(playerid, InventoryObjectsHead[playerid][1][i], 0.300000, 4.1 * lines[i+mindisplay]);
		PlayerTextDrawColor(playerid, InventoryObjectsHead[playerid][1][i], 0);
		PlayerTextDrawSetOutline(playerid, InventoryObjectsHead[playerid][1][i], 0);
		PlayerTextDrawSetProportional(playerid, InventoryObjectsHead[playerid][1][i], 1);
		PlayerTextDrawSetShadow(playerid, InventoryObjectsHead[playerid][1][i], 0);
		PlayerTextDrawUseBox(playerid, InventoryObjectsHead[playerid][1][i], 1);
		PlayerTextDrawBoxColor(playerid, InventoryObjectsHead[playerid][1][i], 0x00000044);
		PlayerTextDrawTextSize(playerid, InventoryObjectsHead[playerid][1][i], 0.000000, 216.000000);
		PlayerTextDrawShow(playerid, InventoryObjectsHead[playerid][1][i]);
		
  		InventoryObjectsHead[playerid][2][i] = CreatePlayerTextDraw(playerid, 416.000000, headery-35.0, "666");
		PlayerTextDrawBackgroundColor(playerid, InventoryObjectsHead[playerid][2][i], 0);
		PlayerTextDrawFont(playerid, InventoryObjectsHead[playerid][2][i], 5);
		PlayerTextDrawLetterSize(playerid, InventoryObjectsHead[playerid][2][i], 0.500000, 1.000000);
		PlayerTextDrawColor(playerid, InventoryObjectsHead[playerid][2][i], ObjectData[ObjectBaseMemory][DisplayColor]);
		PlayerTextDrawSetOutline(playerid, InventoryObjectsHead[playerid][2][i], 0);
		PlayerTextDrawSetProportional(playerid, InventoryObjectsHead[playerid][2][i], 1);
		PlayerTextDrawSetPreviewModel(playerid, InventoryObjectsHead[playerid][2][i], ObjectData[ObjectBaseMemory][Display]);
		PlayerTextDrawSetPreviewRot(playerid, InventoryObjectsHead[playerid][2][i], ObjectData[ObjectBaseMemory][DisplayOffsets][0],
		ObjectData[ObjectBaseMemory][DisplayOffsets][1],ObjectData[ObjectBaseMemory][DisplayOffsets][2],
		ObjectData[ObjectBaseMemory][DisplayOffsets][3]);
		PlayerTextDrawSetShadow(playerid, InventoryObjectsHead[playerid][2][i], 1);
		PlayerTextDrawUseBox(playerid, InventoryObjectsHead[playerid][2][i], 1);
		PlayerTextDrawBoxColor(playerid, InventoryObjectsHead[playerid][2][i], 255);
		PlayerTextDrawTextSize(playerid, InventoryObjectsHead[playerid][2][i], 30.000000, 30.000000);
		PlayerTextDrawShow(playerid, InventoryObjectsHead[playerid][2][i]);

		fbaseid = GetObjectBaseID(objects[i+mindisplay][0]);
		fbaseidmem = GetObjectDataMemory(fbaseid);

		InventoryObjectsHead[playerid][3][i] = CreatePlayerTextDraw(playerid, 454.000000, headery-33.0, ObjectData[fbaseidmem][Name]);
		PlayerTextDrawAlignment(playerid, InventoryObjectsHead[playerid][3][i], 1);
		PlayerTextDrawBackgroundColor(playerid, InventoryObjectsHead[playerid][3][i], 255);
		PlayerTextDrawFont(playerid, InventoryObjectsHead[playerid][3][i], 2);
		if(strlen(ObjectData[fbaseidmem][Name]) > 14 && strlen(ObjectData[fbaseid][Name]) < 20)
			PlayerTextDrawLetterSize(playerid, InventoryObjectsHead[playerid][3][i], 0.300000, 2.400000);
		else if(strlen(ObjectData[fbaseidmem][Name]) > 20)
			PlayerTextDrawLetterSize(playerid, InventoryObjectsHead[playerid][3][i], 0.200000, 2.400000);
		else
		    PlayerTextDrawLetterSize(playerid, InventoryObjectsHead[playerid][3][i], 0.400000, 2.400000);
		PlayerTextDrawColor(playerid, InventoryObjectsHead[playerid][3][i], -1);
		PlayerTextDrawSetOutline(playerid, InventoryObjectsHead[playerid][3][i], 1);
		PlayerTextDrawSetProportional(playerid, InventoryObjectsHead[playerid][3][i], 1);
		PlayerTextDrawShow(playerid, InventoryObjectsHead[playerid][3][i]);
		
		InventoryObjectsHead[playerid][4][i] = CreatePlayerTextDraw(playerid, 635.000000, headery-10.0, SlotData[GetSlotDataMemory(ObjectData[fbaseidmem][UsesSlot])][SlotName]);
		PlayerTextDrawAlignment(playerid, InventoryObjectsHead[playerid][4][i], 3);
		PlayerTextDrawBackgroundColor(playerid, InventoryObjectsHead[playerid][4][i], 255);
		PlayerTextDrawFont(playerid, InventoryObjectsHead[playerid][4][i], 1);
		PlayerTextDrawLetterSize(playerid, InventoryObjectsHead[playerid][4][i], 0.149999, 0.799999);
		PlayerTextDrawColor(playerid, InventoryObjectsHead[playerid][4][i], -120);
		PlayerTextDrawSetOutline(playerid, InventoryObjectsHead[playerid][4][i], 0);
		PlayerTextDrawSetProportional(playerid, InventoryObjectsHead[playerid][4][i], 1);
		PlayerTextDrawSetShadow(playerid, InventoryObjectsHead[playerid][4][i], 0);
		PlayerTextDrawShow(playerid, InventoryObjectsHead[playerid][4][i]);
		
		for(new a = 0; a < objectslots; a ++)
		{
		    InventoryObjectsSlots[playerid][a][i] = CreatePlayerTextDraw(playerid, x+31*(a-resti), headery+0.4, "object_slot");
			PlayerTextDrawAlignment(playerid, InventoryObjectsSlots[playerid][a][i], 2);
			PlayerTextDrawBackgroundColor(playerid, InventoryObjectsSlots[playerid][a][i], -1145324664);
			PlayerTextDrawFont(playerid, InventoryObjectsSlots[playerid][a][i], 5);
			PlayerTextDrawLetterSize(playerid, InventoryObjectsSlots[playerid][a][i], 1.100000, 1.000001);
			PlayerTextDrawColor(playerid, InventoryObjectsSlots[playerid][a][i], -1);
			PlayerTextDrawSetOutline(playerid, InventoryObjectsSlots[playerid][a][i], 0);
			PlayerTextDrawSetProportional(playerid, InventoryObjectsSlots[playerid][a][i], 1);
			PlayerTextDrawSetPreviewModel(playerid, InventoryObjectsSlots[playerid][a][i], 19300);
			PlayerTextDrawSetShadow(playerid, InventoryObjectsSlots[playerid][a][i], 1);
			PlayerTextDrawUseBox(playerid, InventoryObjectsSlots[playerid][a][i], 1);
			PlayerTextDrawBoxColor(playerid, InventoryObjectsSlots[playerid][a][i], -1145324647);
			PlayerTextDrawSetSelectable(playerid, InventoryObjectsSlots[playerid][a][i], 1);
			PlayerTextDrawTextSize(playerid, InventoryObjectsSlots[playerid][a][i], 30.000000, 36.000000);
			PlayerTextDrawShow(playerid, InventoryObjectsSlots[playerid][a][i]);

            InventoryObjectsAmount[playerid][a][i] = CreatePlayerTextDraw(playerid, 449+31*(a-resti), headery+31, "_");
			PlayerTextDrawAlignment(playerid, InventoryObjectsAmount[playerid][a][i], 3);
			PlayerTextDrawBackgroundColor(playerid, InventoryObjectsAmount[playerid][a][i], 255);
			PlayerTextDrawFont(playerid, InventoryObjectsAmount[playerid][a][i], 1);
			PlayerTextDrawLetterSize(playerid, InventoryObjectsAmount[playerid][a][i], 0.120000, 0.599999);
			PlayerTextDrawColor(playerid, InventoryObjectsAmount[playerid][a][i], -1145324647);
			PlayerTextDrawSetOutline(playerid, InventoryObjectsAmount[playerid][a][i], 0);
			PlayerTextDrawSetProportional(playerid, InventoryObjectsAmount[playerid][a][i], 1);
			PlayerTextDrawSetShadow(playerid, InventoryObjectsAmount[playerid][a][i], 0);
			//PlayerTextDrawShow(playerid, InventoryObjectsAmount[playerid][a][i]);

			if((a+1) % 7 == 0)
			{
				headery += 37;
				x = 419.0;
				resti = a+1;
			}
		}
		PlayerVar[playerid][ContainerStoredInSlot][i] = ObjectInfo[ObjectMemoryID][PlayerID];
		LoadObjectInventory(playerid, PlayerVar[playerid][ContainerStoredInSlot][i], i);

        PlayerVar[playerid][ContainersInPages][PlayerVar[playerid][ContainersListingPage]] = i+1;
		headery = headery + 45.0 + 39;
	}
	
	if(PlayerVar[playerid][OnHandObjectID] != 0)
		if(ObjectData[GetObjectDataMemory(GetObjectBaseID(PlayerVar[playerid][OnHandObjectID]))][SlotsInside] > 0)
        	LoadOnHandObjectInventory(playerid, PlayerVar[playerid][OnHandObjectID]);
        
    return 1;
}




forward LoadNearObjectInventory(playerid, ContainerObjectID, memslot);
public LoadNearObjectInventory(playerid, ContainerObjectID, memslot)
{
	new tempobjects[MAX_CARRY_OBJECTS], position, ObjectID, MemoryID, display, totaluses, ObjectBaseID, ObjectBaseMemory, usesstr[5];
	new condition[24];
	format(condition, 24, "p<,>a<i>[%d]", MAX_CARRY_OBJECTS);
	sscanf(ObjectInfo[GetPlayerObjectMemory(ContainerObjectID)][Inventory], condition, tempobjects);

    for(new i = 0; i < sizeof(ObjectStoredInDroppedContainer[]); i ++)
	{
		  ObjectStoredInDroppedContainer[playerid][i][memslot] = 0;
	}
	
	for(new i = 0; i < sizeof(tempobjects); i ++)
	{
	    if(tempobjects[i] == 0)
	        break;
	
		position = ObjectInfo[GetPlayerObjectMemory(tempobjects[i])][Position];
	    ObjectStoredInDroppedContainer[playerid][position][memslot] = tempobjects[i];
	}
	
    for(new i = 0; i < sizeof(ObjectStoredInDroppedContainer[]); i ++)
	{
	    if(ObjectStoredInDroppedContainer[playerid][i][memslot] == 0)
			continue;

		MemoryID = GetPlayerObjectMemory(ObjectStoredInDroppedContainer[playerid][i][memslot]);
		ObjectID = ObjectStoredInDroppedContainer[playerid][i][memslot];
		position = ObjectInfo[MemoryID][Position];
		ObjectBaseID = GetObjectBaseID(ObjectID);
		ObjectBaseMemory = GetObjectDataMemory(ObjectBaseID);
		display = ObjectData[ObjectBaseMemory][Display];
		totaluses = ObjectData[ObjectBaseMemory][MaxUses];
		
		if(totaluses > 0)
		{
		    format(usesstr, 5, "%d%%", (ObjectInfo[MemoryID][CurrentUses]*100)/ObjectData[ObjectBaseMemory][MaxUses]);
		    PlayerTextDrawSetString(playerid, GlobalObjectsAmount[playerid][i][memslot], usesstr);
		    PlayerTextDrawShow(playerid, GlobalObjectsAmount[playerid][i][memslot]);
		}

		PlayerTextDrawHide(playerid, GlobalObjectsSlots[playerid][position][memslot]);
		PlayerTextDrawSetPreviewModel(playerid, GlobalObjectsSlots[playerid][position][memslot], display);
		PlayerTextDrawSetPreviewRot(playerid, GlobalObjectsSlots[playerid][position][memslot], ObjectData[ObjectBaseMemory][DisplayOffsets][0], ObjectData[ObjectBaseMemory][DisplayOffsets][1],
	 	ObjectData[ObjectBaseMemory][DisplayOffsets][2],ObjectData[ObjectBaseMemory][DisplayOffsets][3]);
		PlayerTextDrawColor(playerid, GlobalObjectsSlots[playerid][position][memslot], ObjectData[ObjectBaseMemory][DisplayColor]);

		if(PlayerVar[playerid][SelectedObjectID] == ObjectID)
			PlayerTextDrawBackgroundColor(playerid, GlobalObjectsSlots[playerid][position][memslot], 0xFF660066);
		else
		    PlayerTextDrawBackgroundColor(playerid, GlobalObjectsSlots[playerid][position][memslot], 0x00000066);

		PlayerTextDrawShow(playerid, GlobalObjectsSlots[playerid][position][memslot]);

		new HorizontalSize = ObjectData[ObjectBaseMemory][Size];
	    if(HorizontalSize >= 1)
	    {
	        for(new a = 1; a < HorizontalSize; a ++)
	        {
	            if(PlayerVar[playerid][SelectedObjectID] == ObjectID)
		            PlayerTextDrawBackgroundColor(playerid, GlobalObjectsSlots[playerid][position+a][memslot], 0xFF660066);
				else
				    PlayerTextDrawBackgroundColor(playerid, GlobalObjectsSlots[playerid][position+a][memslot], 0x00000066);

				PlayerTextDrawColor(playerid, GlobalObjectsSlots[playerid][position+a][memslot], ObjectData[ObjectBaseMemory][DisplayColor]);
	   	 		PlayerTextDrawShow(playerid, GlobalObjectsSlots[playerid][position+a][memslot]);
	        }
	    }
	}
	return 1;
}


forward LoadObjectInventory(playerid, ContainerObjectID, memslot);
public LoadObjectInventory(playerid, ContainerObjectID, memslot)
{
	new tempobjects[MAX_CARRY_OBJECTS], position, ObjectID, display, MemoryID, ObjectBaseID, condition[24],usesstr[5],totaluses, ObjectBaseMemory;
	format(condition, 24, "p<,>a<i>[%d]",MAX_CARRY_OBJECTS);
	sscanf(ObjectInfo[GetPlayerObjectMemory(ContainerObjectID)][Inventory], condition, tempobjects);

    for(new i = 0; i < sizeof(ObjectStoredInContainer[]); i ++)
	{
 		ObjectStoredInContainer[playerid][i][memslot] = 0;
	}


	for(new i = 0; i < sizeof(tempobjects); i ++)
	{
	    if(tempobjects[i] == 0)
	        break;

		position = ObjectInfo[GetPlayerObjectMemory(tempobjects[i])][Position];
	    ObjectStoredInContainer[playerid][position][memslot] = tempobjects[i];
	}

	for(new i = 0; i < sizeof(ObjectStoredInContainer[]); i ++)
	{
	    if(ObjectStoredInContainer[playerid][i][memslot] == 0)
			continue;
  
        MemoryID = GetPlayerObjectMemory(ObjectStoredInContainer[playerid][i][memslot]);
		position = ObjectInfo[MemoryID][Position];
		ObjectID = ObjectStoredInContainer[playerid][i][memslot];
		ObjectBaseID = GetObjectBaseID(ObjectID);
		ObjectBaseMemory = GetObjectDataMemory(ObjectBaseID);
		display = ObjectData[ObjectBaseMemory][Display];
		totaluses = ObjectData[ObjectBaseMemory][MaxUses];
		
		if(totaluses > 0)
		{
		    format(usesstr, 5, "%d%%", (ObjectInfo[MemoryID][CurrentUses]*100)/ObjectData[GetObjectDataMemory(GetObjectBaseID(ObjectStoredInContainer[playerid][i][memslot]))][MaxUses]);
		    PlayerTextDrawSetString(playerid, InventoryObjectsAmount[playerid][i][memslot], usesstr);
		    PlayerTextDrawShow(playerid, InventoryObjectsAmount[playerid][i][memslot]);
		}

		PlayerTextDrawHide(playerid, InventoryObjectsSlots[playerid][position][memslot]);
		PlayerTextDrawSetPreviewModel(playerid, InventoryObjectsSlots[playerid][position][memslot], display);

		PlayerTextDrawSetPreviewRot(playerid, InventoryObjectsSlots[playerid][position][memslot], ObjectData[ObjectBaseMemory][DisplayOffsets][0], ObjectData[ObjectBaseMemory][DisplayOffsets][1],
	 	ObjectData[ObjectBaseMemory][DisplayOffsets][2],ObjectData[ObjectBaseMemory][DisplayOffsets][3]);
		PlayerTextDrawColor(playerid, InventoryObjectsSlots[playerid][position][memslot], ObjectData[ObjectBaseMemory][DisplayColor]);

		if(PlayerVar[playerid][SelectedObjectID] == ObjectID)
			PlayerTextDrawBackgroundColor(playerid, InventoryObjectsSlots[playerid][position][memslot], 0xFF660066);
		else
		    PlayerTextDrawBackgroundColor(playerid, InventoryObjectsSlots[playerid][position][memslot], 0x00000066);

		PlayerTextDrawShow(playerid, InventoryObjectsSlots[playerid][position][memslot]);

		new HorizontalSize = ObjectData[ObjectBaseMemory][Size];
	    if(HorizontalSize >= 1)
	    {
	        for(new a = 1; a < HorizontalSize; a ++)
	        {
	            if(PlayerVar[playerid][SelectedObjectID] == ObjectID)
		            PlayerTextDrawBackgroundColor(playerid, InventoryObjectsSlots[playerid][position+a][memslot], 0xFF660066);
				else
				    PlayerTextDrawBackgroundColor(playerid, InventoryObjectsSlots[playerid][position+a][memslot], 0x00000066);

				PlayerTextDrawColor(playerid, InventoryObjectsSlots[playerid][position+a][memslot], ObjectData[ObjectBaseMemory][DisplayColor]);
	   	 		PlayerTextDrawShow(playerid, InventoryObjectsSlots[playerid][position+a][memslot]);
	        }

	    }
	}
	return 1;
}

forward LoadOnHandObjectInventory(playerid, ObjectID);
public LoadOnHandObjectInventory(playerid, ObjectID)
{
	new tempobjects[7], position, trueid, display, MemoryID, ObjectBaseID, ObjectBaseMemory;
	sscanf(ObjectInfo[GetPlayerObjectMemory(ObjectID)][Inventory], "p<,>a<i>[7]", tempobjects);

    for(new i = 0; i < sizeof(ObjectStoredInContainer[]); i ++)
	{
 		ObjectStoredInContainer[playerid][i][MAX_CONTAINERS_PER_PAGE] = 0;
	}

	for(new i = 0; i < sizeof(tempobjects); i ++)
	{
	    if(tempobjects[i] == 0)
	        break;

		position = ObjectInfo[GetPlayerObjectMemory(tempobjects[i])][Position];
		if(position > 6) continue; //no object after position 6 (seventh from 0) should load
		
	    ObjectStoredInContainer[playerid][position][MAX_CONTAINERS_PER_PAGE] = tempobjects[i];
	}
	
	PlayerVar[playerid][ContainerStoredInSlot][MAX_CONTAINERS_PER_PAGE] = ObjectID;
	new ObjectCapacity = ObjectData[GetObjectDataMemory(GetObjectBaseID(ObjectID))][SlotsInside];
	if(ObjectCapacity > 7) ObjectCapacity = 7;
	
	new Float:basex = 222.0;
	for(new a = 0; a < ObjectCapacity; a ++)
	{
	    InventoryObjectsSlots[playerid][a][MAX_CONTAINERS_PER_PAGE] = CreatePlayerTextDraw(playerid, basex+26*(a), 414.399993, "object_slot");
		PlayerTextDrawAlignment(playerid, InventoryObjectsSlots[playerid][a][MAX_CONTAINERS_PER_PAGE], 2);
		PlayerTextDrawBackgroundColor(playerid, InventoryObjectsSlots[playerid][a][MAX_CONTAINERS_PER_PAGE], -1145324664);
		PlayerTextDrawFont(playerid, InventoryObjectsSlots[playerid][a][MAX_CONTAINERS_PER_PAGE], 5);
		PlayerTextDrawLetterSize(playerid, InventoryObjectsSlots[playerid][a][MAX_CONTAINERS_PER_PAGE], 1.100000, 1.000001);
		PlayerTextDrawColor(playerid, InventoryObjectsSlots[playerid][a][MAX_CONTAINERS_PER_PAGE], -1);
		PlayerTextDrawSetOutline(playerid, InventoryObjectsSlots[playerid][a][MAX_CONTAINERS_PER_PAGE], 0);
		PlayerTextDrawSetProportional(playerid, InventoryObjectsSlots[playerid][a][MAX_CONTAINERS_PER_PAGE], 1);
		PlayerTextDrawSetPreviewModel(playerid, InventoryObjectsSlots[playerid][a][MAX_CONTAINERS_PER_PAGE], 19300);
		PlayerTextDrawSetShadow(playerid, InventoryObjectsSlots[playerid][a][MAX_CONTAINERS_PER_PAGE], 1);
		PlayerTextDrawUseBox(playerid, InventoryObjectsSlots[playerid][a][MAX_CONTAINERS_PER_PAGE], 1);
		PlayerTextDrawBoxColor(playerid, InventoryObjectsSlots[playerid][a][MAX_CONTAINERS_PER_PAGE], -1145324647);
		PlayerTextDrawSetSelectable(playerid, InventoryObjectsSlots[playerid][a][MAX_CONTAINERS_PER_PAGE], 1);
		PlayerTextDrawTextSize(playerid, InventoryObjectsSlots[playerid][a][MAX_CONTAINERS_PER_PAGE], 25.000000, 31.000000);
		PlayerTextDrawShow(playerid, InventoryObjectsSlots[playerid][a][MAX_CONTAINERS_PER_PAGE]);
	}
	

	new memslot = MAX_CONTAINERS_PER_PAGE;
	for(new i = 0; i < ObjectCapacity; i ++)
	{
	    if(ObjectStoredInContainer[playerid][i][memslot] == 0)
			continue;

		trueid = ObjectStoredInContainer[playerid][i][memslot];
		ObjectBaseID = GetObjectBaseID(trueid);
		ObjectBaseMemory = GetObjectDataMemory(ObjectBaseID);
		MemoryID = GetPlayerObjectMemory(trueid);
		
		position = ObjectInfo[MemoryID][Position];
		display = ObjectData[ObjectBaseMemory][Display];

		PlayerTextDrawHide(playerid, InventoryObjectsSlots[playerid][position][memslot]);
		PlayerTextDrawSetPreviewModel(playerid, InventoryObjectsSlots[playerid][position][memslot], display);

		PlayerTextDrawSetPreviewRot(playerid, InventoryObjectsSlots[playerid][position][memslot], ObjectData[ObjectBaseMemory][DisplayOffsets][0], ObjectData[ObjectBaseMemory][DisplayOffsets][1],
	 	ObjectData[ObjectBaseMemory][DisplayOffsets][2],ObjectData[ObjectBaseMemory][DisplayOffsets][3]);
		PlayerTextDrawColor(playerid, InventoryObjectsSlots[playerid][position][memslot], ObjectData[ObjectBaseMemory][DisplayColor]);

		if(PlayerVar[playerid][SelectedObjectID] == trueid)
			PlayerTextDrawBackgroundColor(playerid, InventoryObjectsSlots[playerid][position][memslot], 0xFF660066);
		else
		    PlayerTextDrawBackgroundColor(playerid, InventoryObjectsSlots[playerid][position][memslot], 0x00000066);

		PlayerTextDrawShow(playerid, InventoryObjectsSlots[playerid][position][memslot]);

		new HorizontalSize = ObjectData[ObjectBaseMemory][Size];
	    if(HorizontalSize >= 1)
	    {
	        for(new a = 1; a < HorizontalSize; a ++)
	        {
	            if(PlayerVar[playerid][SelectedObjectID] == trueid)
		            PlayerTextDrawBackgroundColor(playerid, InventoryObjectsSlots[playerid][position+a][memslot], 0xFF660066);
				else
				    PlayerTextDrawBackgroundColor(playerid, InventoryObjectsSlots[playerid][position+a][memslot], 0x00000066);

				PlayerTextDrawColor(playerid, InventoryObjectsSlots[playerid][position+a][memslot], ObjectData[ObjectBaseMemory][DisplayColor]);
	   	 		PlayerTextDrawShow(playerid, InventoryObjectsSlots[playerid][position+a][memslot]);
	        }

	    }
	}
	return 1;
}

stock HideOnHandObjectInventory(playerid)
{
    for(new i = 0; i < 7; i ++)
	{
		PlayerTextDrawHide(playerid, InventoryObjectsSlots[playerid][i][MAX_CONTAINERS_PER_PAGE]);
	}
	return 1;
}

stock SetObjectUses(playerid, ObjectID, iUses)
{
    format(query, sizeof query,"UPDATE playerobjects SET CurrentUses = %d WHERE PlayerID = %d",iUses, ObjectID);
    mysql_tquery(dbHandle, query, "", "");
    
	new MemoryID = GetPlayerObjectMemory(ObjectID);
    ObjectInfo[MemoryID][CurrentUses] = iUses;
    
    if(playerid != INVALID_PLAYER_ID)
	{
	    new str[5];
	    for(new i = 0; i < sizeof(ObjectStoredInContainer[]); i ++)
	    {
	        for(new a = 0; a < sizeof(ObjectStoredInContainer[][]); a ++)
	        {
	            if(ObjectStoredInContainer[playerid][i][a] == ObjectID)
	            {
	                format(str, 5, "%d%%", (ObjectInfo[MemoryID][CurrentUses]*100)/ObjectData[GetObjectDataMemory(GetObjectBaseID(ObjectID))][MaxUses]);
					PlayerTextDrawSetString(playerid, InventoryObjectsAmount[playerid][i][a], str);
	            }
			}
	    }
	    for(new i = 0; i < sizeof(ObjectStoredInDroppedContainer[]); i ++)
	    {
	        for(new a = 0; a < sizeof(ObjectStoredInDroppedContainer[][]); a ++)
	        {
	            if(ObjectStoredInDroppedContainer[playerid][i][a] == ObjectID)
	            {
	                format(str, 5, "%d%%", (ObjectInfo[MemoryID][CurrentUses]*100)/ObjectData[GetObjectDataMemory(GetObjectBaseID(ObjectID))][MaxUses]);
					PlayerTextDrawSetString(playerid, GlobalObjectsAmount[playerid][i][a], str);
	            }
			}
	    }
	}
	return 1;
}

stock RemoveObjectFromDatabase(ObjectID, bool:inventoryerase)
{
	new MemoryID = GetPlayerObjectMemory(ObjectID);
	ObjectInfo[MemoryID][PlayerID] = 0;
	ObjectInfo[MemoryID][BaseID] = 0;

    format(query, sizeof(query),"DELETE FROM playerobjects WHERE PlayerID = %d", ObjectID);
	mysql_tquery(dbHandle, query, "", "");

	if(inventoryerase)
	{
	    format(query, sizeof(query),"DELETE FROM objectinventory WHERE PlayerObjectID = %d", ObjectID);
		mysql_tquery(dbHandle, query, "", "");
	}
	
	format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = 0 WHERE P_SpecialFlag_1 = %d", ObjectID);
	mysql_tquery(dbHandle, query, "", "");
	format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_2 = 0 WHERE P_SpecialFlag_1 = %d", ObjectID);
	mysql_tquery(dbHandle, query, "", "");
	
	format(bigquery, sizeof bigquery,
	"SELECT * FROM objectinventory WHERE InsideIDs LIKE '%d,%%' UNION SELECT * FROM objectinventory WHERE InsideIDs LIKE '%%,%d,%%' UNION SELECT * FROM objectinventory WHERE InsideIDs LIKE '%%,%d' UNION SELECT * FROM objectinventory WHERE InsideIDs LIKE '%d'",
	ObjectID, ObjectID, ObjectID, ObjectID);
	mysql_tquery(dbHandle, bigquery, "OnObjectInsideChecked", "i", ObjectID);
	

	for(new i = 0; i <= LastObjectInfoIndexUsed; i ++)
	{
		if(ObjectInfo[i][PlayerID] == 0) continue;
	   	if(ObjectInfo[i][P_SpecialFlag_1] == 0 && ObjectInfo[i][P_SpecialFlag_2] == 0) continue;
	   	
	    if(ObjectInfo[i][P_SpecialFlag_1] == ObjectID)
	        ObjectInfo[i][P_SpecialFlag_1] = 0;
	        
        if(ObjectInfo[i][P_SpecialFlag_2] == ObjectID)
	        ObjectInfo[i][P_SpecialFlag_2] = 0;
	    
	}
	return 1;
}

forward OnObjectInsideChecked(ObjectID);
public OnObjectInsideChecked(ObjectID)
{
    new rows, fields;
	cache_get_data(rows, fields);
	
	if(rows == 0)
		return 1;
	if(rows > 1)
	{
	    printf("[INVENTORY ERROR]: Object to be removed detected in more than one inventory.");
	    return 1;
	}
	
	new InsideOfObject = cache_get_field_content_int(0, "PlayerObjectID");
	
	RemoveObjectFromObject(INVALID_PLAYER_ID, ObjectID, InsideOfObject);
	return 1;
}

stock CountObjectsInInventory(ObjectID)
{
	new tempobjects[MAX_CARRY_OBJECTS], count = 0, condition[24];
	format(condition, 24, "p<,>a<i>[%d]",MAX_CARRY_OBJECTS);
	sscanf(ObjectInfo[GetPlayerObjectMemory(ObjectID)][Inventory], condition, tempobjects);

	for(new i = 0; i < sizeof tempobjects; i ++)
	{
	    if(tempobjects[i] == 0) continue;
		count ++;
	}
	return count;
}

stock CountPlayerContainers(playerid)
{
	new count;
    for(new i = 0; i <= LastObjectInfoIndexUsed; i ++)
	{
	    if(ObjectInfo[i][PlayerID] == 0) continue;
	    if(ObjectInfo[i][Status] != 1) continue;

	    if(strcmp(ObjectInfo[i][OwnerName], PlayerName(playerid), true) == 0)
	    {
	        count ++;
	    }
	}
	return count;
}

stock GetPlayerContainers(playerid)
{
	new pname[24], count, containerstr[ (5 * MAX_CONTAINERS_LIMIT) + MAX_CONTAINERS_LIMIT - 1]; //Max 5 digits ids times the limit of containers that a player will load plus commas
	format(pname, 24, "%s",PlayerName(playerid));

	for(new i = 0; i <= LastObjectInfoIndexUsed; i ++)
	{
	    if(ObjectInfo[i][PlayerID] == 0) continue;
	    if(ObjectInfo[i][Status] != 1) continue;
	    
	    if(strcmp(ObjectInfo[i][OwnerName], pname, true) == 0)
	    {
	        if(count == MAX_CONTAINERS_LIMIT) break;
	    
	        if(count == 0)
	        	format(containerstr, sizeof(containerstr), "%d", ObjectInfo[i][PlayerID]);
			else
			    format(containerstr, sizeof(containerstr), "%s,%d", containerstr, ObjectInfo[i][PlayerID]);
			
			count ++;
	    }
	}

	return containerstr;
}

forward IsContainerSlotFree(Container, Slot);
public IsContainerSlotFree(Container, Slot)
{
	new ContainerSize = ObjectData[GetObjectDataMemory(GetObjectBaseID(Container))][SlotsInside];
	new InsideOfContainerInventory = CountObjectsInInventory(Container);

	new condition[24];
	new tempobjects[MAX_CARRY_OBJECTS];
	new totalslots[MAX_CARRY_OBJECTS];
	format(condition, 24, "p<,>a<i>[%d]",ContainerSize);
	sscanf(ObjectInfo[GetPlayerObjectMemory(Container)][Inventory], condition, tempobjects);

    new pos, size;
	for(new i = 0; i < InsideOfContainerInventory; i ++) //map the object slots with this loop
	{
		pos = ObjectInfo[GetPlayerObjectMemory(tempobjects[i])][Position];
		size = ObjectData[GetObjectDataMemory(GetObjectBaseID(tempobjects[i]))][Size];

		for(new a = pos; a < pos+size; a ++)
		{
		    totalslots[a] = 1;
		}
	}

	if(totalslots[Slot] == 0) return 1;
	return 0;
}

stock CountEmptySlotsAfterPosition(Container, fPosition)
{
	//printf("CountEmptySlotsAfterPosition(%d,%d)",Container,fPosition);

	new ContainerSize = ObjectData[GetObjectDataMemory(GetObjectBaseID(Container))][SlotsInside];
	new InsideOfContainerInventory = CountObjectsInInventory(Container);

	new condition[24], count;
	new tempobjects[MAX_CARRY_OBJECTS];
	new totalslots[MAX_CARRY_OBJECTS];
	format(condition, 24, "p<,>a<i>[%d]",ContainerSize);
	sscanf(ObjectInfo[GetPlayerObjectMemory(Container)][Inventory], condition, tempobjects);

    new pos, size;
	for(new i = 0; i < InsideOfContainerInventory; i ++) //map the object slots with this loop
	{
		pos = ObjectInfo[GetPlayerObjectMemory(tempobjects[i])][Position];
		size = ObjectData[GetObjectDataMemory(GetObjectBaseID(tempobjects[i]))][Size];

		for(new a = pos; a < pos+size; a ++)
		{
		    totalslots[a] = 1;
		}
	}

	for(new i = fPosition+1; i < ContainerSize; i ++)
	{
	    if(totalslots[i] == 0) count ++;
	    if(totalslots[i] == 1) break;
	}
	return count;
}

stock FindFirstEmptySlotInContainer(Container, start = 0)
{
	//printf("FindFirstEmptySlotInContainer(%d,%d)",Container,start);

	new ContainerSize = ObjectData[GetObjectDataMemory(GetObjectBaseID(Container))][SlotsInside];
	new InsideOfContainerInventory = CountObjectsInInventory(Container);
	
	new condition[24];
	new tempobjects[MAX_CARRY_OBJECTS];
	new totalslots[MAX_CARRY_OBJECTS];
	format(condition, 24, "p<,>a<i>[%d]",ContainerSize);
	sscanf(ObjectInfo[GetPlayerObjectMemory(Container)][Inventory], condition, tempobjects);

    new pos, size;
	for(new i = 0; i < InsideOfContainerInventory; i ++) //map the object slots with this loop
	{
		pos = ObjectInfo[GetPlayerObjectMemory(tempobjects[i])][Position];
		size = ObjectData[GetObjectDataMemory(GetObjectBaseID(tempobjects[i]))][Size];

		for(new a = pos; a < pos+size; a ++)
		{
		    totalslots[a] = 1;
		}
	}

	for(new i = start; i < ContainerSize; i ++)
	{
	    if(totalslots[i] == 0) return i;
	}
	return -1;
}

forward CheckIfObjectFitsInObject(ObjectToCheck, InsideOfObject, NewPosition);
public CheckIfObjectFitsInObject(ObjectToCheck, InsideOfObject, NewPosition)
{
    new InsideOfObjectCarry = ObjectData[GetObjectDataMemory(GetObjectBaseID(InsideOfObject))][SlotsInside];
    new ObjectToCheckSize = ObjectData[GetObjectDataMemory(GetObjectBaseID(ObjectToCheck))][Size];

	if(NewPosition + ObjectToCheckSize > InsideOfObjectCarry)
	    return 0;
	    
    if(!OnObjectMovedAttempt(INVALID_PLAYER_ID, ObjectToCheck, ObjectData[GetObjectDataMemory(GetObjectBaseID(ObjectToCheck))][UsesType], 0, 0, InsideOfObject, ObjectData[GetObjectDataMemory(GetObjectBaseID(InsideOfObject))][UsesType], INVALID_PLAYER_ID))
		return 0;

    new totalslots[MAX_CARRY_OBJECTS+1], tempobjects[MAX_CARRY_OBJECTS+1];
    new InsideOfObjectInventory = CountObjectsInInventory(InsideOfObject), condition[24];
    format(condition, 24, "p<,>a<i>[%d]",MAX_CARRY_OBJECTS+1);
	sscanf(ObjectInfo[GetPlayerObjectMemory(InsideOfObject)][Inventory], condition, tempobjects);

    new pos, size;
	for(new i = 0; i < InsideOfObjectInventory; i ++) //map the object slots with this loop
	{
		if(tempobjects[i] == ObjectToCheck) continue;

		pos = ObjectInfo[GetPlayerObjectMemory(tempobjects[i])][Position];
		size = ObjectData[GetObjectDataMemory(GetObjectBaseID(tempobjects[i]))][Size];

		for(new a = pos; a < pos+size; a ++)
		{
		    totalslots[a] = 1;
		}
	}
	
	for(new i = NewPosition; i < NewPosition+ObjectToCheckSize; i ++)
	{
	    if(totalslots[i] == 0) continue;
	    if(totalslots[i] == 1) return 0;
	}
	return 1;
}

forward CheckIfObjectFitsInPlaceOf(ObjectToCheck, SecondObject, SecondObjectContainer);
public CheckIfObjectFitsInPlaceOf(ObjectToCheck, SecondObject, SecondObjectContainer)
{
    new SecondObjectContainerCarry = ObjectData[GetPlayerObjectDataMemory(SecondObjectContainer)][SlotsInside];
    new ObjectToCheckSize = ObjectData[GetPlayerObjectDataMemory(ObjectToCheck)][Size];
	new SecondObjectPosition = ObjectInfo[GetPlayerObjectMemory(SecondObject)][Position];
	
	if(SecondObjectPosition + ObjectToCheckSize > SecondObjectContainerCarry)
	    return 0;

    new totalslots[MAX_CARRY_OBJECTS+1], tempobjects[MAX_CARRY_OBJECTS+1];
    new SecondObjectInventory = CountObjectsInInventory(SecondObjectContainer), condition[24];
    format(condition, 24, "p<,>a<i>[%d]",MAX_CARRY_OBJECTS+1);
	sscanf(ObjectInfo[GetPlayerObjectMemory(SecondObjectContainer)][Inventory], condition, tempobjects);

    new pos, size;
	for(new i = 0; i < SecondObjectInventory; i ++) //map the object slots with this loop
	{
		if(tempobjects[i] == SecondObject) continue;

		pos = ObjectInfo[GetPlayerObjectMemory(tempobjects[i])][Position];
		size = ObjectData[GetPlayerObjectDataMemory(tempobjects[i])][Size];

		for(new a = pos; a < pos+size; a ++)
		{
		    totalslots[a] = 1;
		}
	}
	
	/*printf("MAPPED INVENTORY OF OBJECT ID %d", SecondObjectContainer);
	new test[1024];
	for(new i = 0; i < 10; i ++)
	{
	    format(test, 1024, "%s|%d|",test, totalslots[i]);
	}
	printf("%s",test);
	test = "";
	for(new i = 10; i < 20; i ++)
	{
	    format(test, 1024, "%s|%d|",test, totalslots[i]);
	}
	printf("%s",test);
	test = "";
	for(new i = 20; i < 30; i ++)
	{
	    format(test, 1024, "%s|%d|",test, totalslots[i]);
	}
	printf("%s",test);
	test = "";
	for(new i = 30; i < 35; i ++)
	{
	    format(test, 1024, "%s|%d|",test, totalslots[i]);
	}
	printf("%s",test);
	test = "";*/
	
	for(new i = SecondObjectPosition; i < SecondObjectPosition+ObjectToCheckSize; i ++)
	{
	    if(totalslots[i] == 0) continue;
	    if(totalslots[i] == 1) return 0;
	}
	return 1;
}



forward CheckBulletLimit(playerid, BulletObject, BulletSource, BulletSourceType, Dest);
public CheckBulletLimit(playerid, BulletObject, BulletSource, BulletSourceType, Dest)
{
	new DestType = ObjectData[GetPlayerObjectDataMemory(Dest)][UsesType];

	new WeaponChamber;
	
	if(DestType == 12)
	    WeaponChamber = ObjectData[GetPlayerObjectDataMemory(Dest)][SpecialFlag_3];
	else if(DestType == 6)
	    WeaponChamber = ObjectData[GetPlayerObjectDataMemory(Dest)][SpecialFlag_2];
	else if(DestType == 2)
	    WeaponChamber = 1;
	
	new BulletUses = ObjectInfo[GetPlayerObjectMemory(BulletObject)][CurrentUses];
	new BulletObjectBase = GetObjectBaseID(BulletObject);

	if(BulletUses > WeaponChamber && WeaponChamber != 0)
	{
	    new splitamount = BulletUses - WeaponChamber;

	   	CreateNewSplittedObject(playerid, BulletObjectBase, Dest, DestType, WeaponChamber, PlayerName(playerid));
	    format(query, sizeof query, "UPDATE playerobjects SET CurrentUses = %d WHERE PlayerID = %d", splitamount, BulletObject);
	    mysql_tquery(dbHandle, query);
	    ObjectInfo[GetPlayerObjectMemory(BulletObject)][CurrentUses] = splitamount;
	    return 0;
	}
	return 1;
}

stock CreateNewSplittedObject(playerid, ObjectDataID, Dest, DestType, fUses, Owner[])
{
	mysql_format(dbHandle, medquery, sizeof medquery, "INSERT INTO playerobjects (PlayerName, BaseObjectID, CurrentUses, Status) VALUES ('%e',%d,%d,2)",Owner, ObjectDataID, fUses);
	mysql_tquery(dbHandle, medquery, "InsertObjectInventory", "iiiiii", playerid, 7, Dest, DestType, ObjectDataID, fUses);
	return 1;
}

forward InsertObjectInventory(playerid, Type, Dest, DestType, ObjectDataID, fUses);
public InsertObjectInventory(playerid, Type, Dest, DestType, ObjectDataID, fUses)
{
    new PlayerObjectID = cache_insert_id();

	ObjectInfo[LastObjectInfoIndexUsed+1][PlayerID] = PlayerObjectID;
	ObjectInfo[LastObjectInfoIndexUsed+1][BaseID] = ObjectDataID;

    ObjectInfo[LastObjectInfoIndexUsed+1][CurrentUses] = fUses;

    //ObjectInfo[PlayerObjectID][Position] = 0;
    //ObjectInfo[PlayerObjectID][Status] = 3;
    ObjectInfo[LastObjectInfoIndexUsed+1][Condition] = 100;

    ObjectInfo[LastObjectInfoIndexUsed+1][P_SpecialFlag_1] = 0;
    ObjectInfo[LastObjectInfoIndexUsed+1][P_SpecialFlag_2] = 0;

    LastObjectInfoIndexUsed ++;
	TotalLoadedPlayerObjects ++;

	format(medquery, sizeof medquery, "INSERT INTO objectinventory (PlayerObjectID, InsideIDs) VALUES (%d, '')",cache_insert_id());
	mysql_tquery(dbHandle, medquery, "OnObjectSplitted", "iiiii", playerid, Type, Dest, DestType, cache_insert_id());
	return 1;
}

forward OnObjectSplitted(playerid, Type, Dest, DestType, Object);
public OnObjectSplitted(playerid, Type, Dest, DestType, Object)
{
	MoveObjectToObject(playerid, -1, Object, Type, 0, 0, Dest, DestType, playerid, PlayerName(playerid));
	return 1;
}

stock PutObjectInFirstEmptySlotPla(playerid, Object, SourceContainer = 0, Exclude = 0, bool:Drop = true)
{
    new ContainersAmount = CountPlayerContainers(playerid);
    new ObjectBaseID = GetObjectBaseID(Object);
    new found, count;
    
	if(ContainersAmount > 0)
	{
		new PlayerContainers[MAX_CONTAINERS_LIMIT], condition[24], lPosition;
		format(condition, 24, "p<,>a<i>[%d]", MAX_CONTAINERS_LIMIT);
		sscanf(GetPlayerContainers(playerid), condition, PlayerContainers);

		for(new i = 0; i < ContainersAmount; i ++)
		{
		    if(Exclude != 0)
		        if(PlayerContainers[i] == Exclude) continue;
		
		    
		    if(ObjectData[GetPlayerObjectDataMemory(PlayerContainers[i])][UsesType] == 6 || ObjectData[GetPlayerObjectDataMemory(PlayerContainers[i])][UsesType] == 12 ||
		    ObjectData[GetPlayerObjectDataMemory(PlayerContainers[i])][UsesType] == 2) continue; //Exclude weapon containers.
		
			lPosition = FindFirstEmptySlotInContainer(PlayerContainers[i]);

			while(lPosition != -1)
			{
				if(CheckIfObjectFitsInObject(Object, PlayerContainers[i], lPosition) == 0)
				{
				    count = CountEmptySlotsAfterPosition(PlayerContainers[i],lPosition);
				    lPosition = FindFirstEmptySlotInContainer(PlayerContainers[i],lPosition+count+1);
				}
				else break;
			}
			
			if(lPosition == -1) continue;

			MoveObjectToObject(playerid, lPosition, Object, ObjectData[GetObjectDataMemory(ObjectBaseID)][UsesType], SourceContainer, ObjectData[GetPlayerObjectDataMemory(SourceContainer)][UsesType],
			PlayerContainers[i], ObjectData[GetPlayerObjectDataMemory(PlayerContainers[i])][UsesType], playerid, PlayerName(playerid));
			found = 1;
			break;
		}
	}
	
	if(found == 0 || ContainersAmount < 1)
	{
		if(Drop == true)
	    	DropObject(playerid, Object, ObjectData[GetObjectDataMemory(ObjectBaseID)][UsesType], SourceContainer);
  		else
		    return 0;
 	}
 	else
    	if(SourceContainer != 0 && found)
        	RemoveObjectFromObject(playerid, Object, SourceContainer);
	
	return 1;
}

stock PutObjectInFirstEmptySlotCont(playerid, Object, SourceContainer, DestinationContainer, bool:Drop = true)
{
    new ObjectBaseID = GetObjectBaseID(Object);
    new count, lPosition;

	lPosition = FindFirstEmptySlotInContainer(DestinationContainer);

	while(lPosition != -1)
	{
		if(CheckIfObjectFitsInObject(Object, DestinationContainer, lPosition) == 0)
		{
		    count = CountEmptySlotsAfterPosition(DestinationContainer,lPosition);
		    lPosition = FindFirstEmptySlotInContainer(DestinationContainer,lPosition+count+1);
		}
		else break;
	}

	if(lPosition == -1)
	{// not found
	    if(Drop == true)
	    	DropObject(playerid, Object, ObjectData[GetObjectDataMemory(ObjectBaseID)][UsesType], SourceContainer);
  		else
		    return 0;
	}

	MoveObjectToObject(playerid, lPosition, Object, ObjectData[GetObjectDataMemory(ObjectBaseID)][UsesType], SourceContainer, ObjectData[GetPlayerObjectDataMemory(SourceContainer)][UsesType],
	DestinationContainer, ObjectData[GetPlayerObjectDataMemory(DestinationContainer)][UsesType], playerid, PlayerName(playerid));

	if(SourceContainer != 0)
    	RemoveObjectFromObject(playerid, Object, SourceContainer);

	return 1;
}


forward MoveObjectToObject(playerid, pos, PlayerObjectID, PlayerObjectType, SourceContainer, SourceType, DestinationContainer, DestinationType, NewOwner, OldOwner[24]);
public MoveObjectToObject(playerid, pos, PlayerObjectID, PlayerObjectType, SourceContainer, SourceType, DestinationContainer, DestinationType, NewOwner, OldOwner[24])
{
    if(!OnObjectMovedAttempt(playerid, PlayerObjectID, PlayerObjectType, SourceContainer, SourceType, DestinationContainer, DestinationType, NewOwner))
		return 1;

	if(pos == -1)
	{// -1: Find first empty slot in dest, if no space, in inventory, if none, then drop the object.
	    if(PutObjectInFirstEmptySlotCont(playerid, PlayerObjectID, SourceContainer, DestinationContainer, false) == 0)
	    {
	        PutObjectInFirstEmptySlotPla(playerid, PlayerObjectID, SourceContainer, DestinationContainer, true);
		}
		return 1;
	}
	else if(pos == -2)
	{// -2: Find first empty slot in dest, if none, do not allow the move at all
	    if(PutObjectInFirstEmptySlotCont(playerid, PlayerObjectID, SourceContainer, DestinationContainer, false) == 0)
	    {
	        if(playerid != INVALID_PLAYER_ID)
			 	RenderMessage(playerid, 0xFF6600FF, "There's no room for that object inside.");
		}
	    
	    return 1;
	}
	
	if(CheckIfObjectFitsInObject(PlayerObjectID, DestinationContainer, pos) == 0)
	{
	    if(playerid != INVALID_PLAYER_ID)
    		RenderMessage(playerid, 0xFF6600FF, "There's no room for that object inside.");
    		
		return 1;
	}

	new MemoryID = GetPlayerObjectMemory(PlayerObjectID);
	if(ObjectInfo[MemoryID][Status] == 3)
	{//item was on ground
	    DestroyDynamicObject(ObjectInfo[MemoryID][GameObject]);
	   	DestroyDynamicArea(ObjectInfo[MemoryID][AreaID]);
	   	ObjectInfo[MemoryID][Status] = 2;
	   	ObjectInfo[MemoryID][Position] = pos;

     	for(new a = 0; a < PLAYERS; a ++)
        {
            if(!IsPlayerConnected(a)) continue;
			if(ObjectInfo[MemoryID][IsNear][a] == 1)
			    ObjectInfo[MemoryID][IsNear][a] = 0;

            if(a == playerid) continue;
			LoadPlayerNearContainers(a);
		}

	}
	if(ObjectInfo[MemoryID][Status] == 1)
	{//item was a container
	    if(playerid != INVALID_PLAYER_ID)
	    	OnPlayerUnEquipContainer(playerid, PlayerObjectID);
	}
	
	mysql_format(dbHandle, medquery, sizeof medquery,"UPDATE `playerobjects` SET `Position` = %d, `Status` = 2 WHERE `PlayerID` = %d", pos, PlayerObjectID);
	mysql_tquery(dbHandle, medquery, "", "");
	
	ObjectInfo[MemoryID][Status] = 2;
	ObjectInfo[MemoryID][Position] = pos;

	if(DestinationContainer != SourceContainer)
	{
	    RemoveObjectFromObject(playerid, PlayerObjectID, SourceContainer);
	    AddObjectToObject(playerid, PlayerObjectID, DestinationContainer);
	}

	if(SourceContainer == PlayerObjectID)
	{//Container into object
	    new ObjectSlotID = ObjectData[GetPlayerObjectDataMemory(PlayerObjectID)][UsesSlot];
		if(ObjectSlotID != 1 && PlayerVar[playerid][SelectedObjectGlobal] == 0)
		{
		    if(playerid != INVALID_PLAYER_ID)
		    {
			    if(PlayerVar[playerid][PlayerSlots][ObjectSlotID] > 0)
			    {
				    PlayerVar[playerid][PlayerSlots][ObjectSlotID] --;
				    
            		mysql_format(dbHandle, query, sizeof query, "UPDATE playerinventories SET `%d` = %d WHERE PlayerName = '%e'", ObjectSlotID, PlayerVar[playerid][PlayerSlots][ObjectSlotID], PlayerName(playerid));
					mysql_tquery(dbHandle, query);
				}
			}
	    }
	    UnrenderPlayerContainer(playerid, PlayerObjectID);
	}
	
	if(playerid != INVALID_PLAYER_ID)
	{
	    PlayerVar[playerid][SelectedObjectID] = 0;
	    PlayerVar[playerid][SelectedObjectSourceID] = 0;
	    PlayerVar[playerid][SelectedContainerID] = 0;

		LoadPlayerContainers(playerid);
		LoadPlayerNearContainers(playerid);
	}
	
	if(NewOwner != INVALID_PLAYER_ID)
	{
	    mysql_format(dbHandle, query, sizeof query, "UPDATE playerobjects SET PlayerName = '%e', WorldX = '0.0', WorldY = '0.0', WorldZ = '0.0' WHERE PlayerID = %d", PlayerName(playerid), PlayerObjectID);
	    mysql_tquery(dbHandle, query, "", "");
	    
	    format(ObjectInfo[MemoryID][OwnerName],24,"%s",PlayerName(playerid));
	}
	OnServerObjectMoved(playerid, PlayerObjectID, PlayerObjectType, SourceContainer, SourceType, DestinationContainer, DestinationType, NewOwner);
	return 1;
}

forward InternalSwapObject(playerid, ObjectsSource, SelectedObject, SecondObject, SelectedObjectType, SecondObjectType, SecondObjectSourceType, SelectedObjectSourceType, SelectedObjectPosition, SecondObjectPosition, mem);
public InternalSwapObject(playerid, ObjectsSource, SelectedObject, SecondObject, SelectedObjectType, SecondObjectType, SecondObjectSourceType, SelectedObjectSourceType, SelectedObjectPosition, SecondObjectPosition, mem)
{
    if(!OnObjectSwapAttempt(playerid, ObjectsSource, ObjectsSource, SelectedObject, SecondObject, SelectedObjectType, SecondObjectType, SecondObjectSourceType, SelectedObjectSourceType))
		return 1;
    	
    if(playerid != INVALID_PLAYER_ID)
    	PlayerVar[playerid][ActionSwapStep] = 0;

    if(CheckIfObjectFitsInPlaceOf(SelectedObject, SecondObject, ObjectsSource) == 0)
	{
	    if(playerid != INVALID_PLAYER_ID)
	    	RenderMessage(playerid,0xFF6600FF,"The selected object wont fit.");
	    	
	    return 1;
	}
	if(CheckIfObjectFitsInPlaceOf(SecondObject, SelectedObject, ObjectsSource) == 0)
	{
	    if(playerid != INVALID_PLAYER_ID)
	    	RenderMessage(playerid,0xFF6600FF,"The selected object wont fit.");
	    	
	    return 1;
	}


    mysql_format(dbHandle, medquery, sizeof medquery,"UPDATE `playerobjects` SET `Position` = %d, `Status` = 2 WHERE `PlayerID` = %d", SecondObjectPosition, SelectedObject);
	mysql_tquery(dbHandle, medquery, "", "");

	mysql_format(dbHandle, medquery, sizeof medquery,"UPDATE `playerobjects` SET `Position` = %d, `Status` = 2 WHERE `PlayerID` = %d", SelectedObjectPosition, SecondObject);
	mysql_tquery(dbHandle, medquery, "", "");
	

	ObjectInfo[GetPlayerObjectMemory(SecondObject)][Position] = SelectedObjectPosition;
	ObjectInfo[GetPlayerObjectMemory(SelectedObject)][Position] = SecondObjectPosition;

  	if(playerid != INVALID_PLAYER_ID)
	{
        PlayerVar[playerid][SelectedObjectID] = 0;
        PlayerVar[playerid][SelectedObjectSourceID] = 0;
        PlayerVar[playerid][SelectedContainerID] = 0;

    	LoadPlayerContainers(playerid);
		LoadPlayerNearContainers(playerid);
	}
	
	OnObjectSwapped(playerid, ObjectsSource, ObjectsSource, SelectedObject, SecondObject, SelectedObjectType, SecondObjectType, SecondObjectSourceType, SelectedObjectSourceType);
	return 1;
}

forward SwapObjectWithObject(playerid, SelectedObjectSource, SecondObjectSource, SelectedObject, SecondObject, SelectedObjectType, SecondObjectType, SecondObjectSourceType, SelectedObjectSourceType, SelectedObjectPosition, SecondObjectPosition, mem);
public SwapObjectWithObject(playerid, SelectedObjectSource, SecondObjectSource, SelectedObject, SecondObject, SelectedObjectType, SecondObjectType, SecondObjectSourceType, SelectedObjectSourceType, SelectedObjectPosition, SecondObjectPosition, mem)
{
    if(!OnObjectSwapAttempt(playerid, SelectedObjectSource, SecondObjectSource, SelectedObject, SecondObject, SelectedObjectType, SecondObjectType, SecondObjectSourceType, SelectedObjectSourceType))
		return 1;

    if(playerid != INVALID_PLAYER_ID)
		PlayerVar[playerid][ActionSwapStep] = 0;

    if(CheckIfObjectFitsInPlaceOf(SelectedObject, SecondObject, SecondObjectSource) == 0)
	{
	    if(playerid != INVALID_PLAYER_ID)
	    	RenderMessage(playerid,0xFF6600FF,"The selected object wont fit in the other container.");
	    	
	    return 1;
	}
	if(CheckIfObjectFitsInPlaceOf(SecondObject, SelectedObject, SelectedObjectSource) == 0)
	{
	    if(playerid != INVALID_PLAYER_ID)
	    	RenderMessage(playerid,0xFF6600FF,"The other object wont fit in the selected object container.");
	    	
	    return 1;
	}

    mysql_format(dbHandle, medquery, sizeof medquery,"UPDATE `playerobjects` SET `Position` = %d, `Status` = 2 WHERE `PlayerID` = %d", SecondObjectPosition, SelectedObject);
	mysql_tquery(dbHandle, medquery, "", "");
	
	mysql_format(dbHandle, medquery, sizeof medquery,"UPDATE `playerobjects` SET `Position` = %d, `Status` = 2 WHERE `PlayerID` = %d", SelectedObjectPosition, SecondObject);
	mysql_tquery(dbHandle, medquery, "", "");
	
	ObjectInfo[GetPlayerObjectMemory(SelectedObject)][Position] = SecondObjectPosition;
	ObjectInfo[GetPlayerObjectMemory(SecondObject)][Position] = SelectedObjectPosition;
	
	AddObjectToObject(playerid, SelectedObject, SecondObjectSource);
	AddObjectToObject(playerid, SecondObject, SelectedObjectSource);
	
	RemoveObjectFromObject(playerid, SelectedObject, SelectedObjectSource);
	RemoveObjectFromObject(playerid, SecondObject, SecondObjectSource);

  	if(playerid != INVALID_PLAYER_ID)
	{
        PlayerVar[playerid][SelectedObjectID] = 0;
        PlayerVar[playerid][SelectedObjectSourceID] = 0;
        PlayerVar[playerid][SelectedContainerID] = 0;
    	
    	LoadPlayerContainers(playerid);
		LoadPlayerNearContainers(playerid);
	}
	
	OnObjectSwapped(playerid, SelectedObjectSource, SecondObjectSource, SelectedObject, SecondObject, SelectedObjectType, SecondObjectType, SecondObjectSourceType, SelectedObjectSourceType);
	return 1;
}


forward DropObject(playerid, PlayerObjectID, PlayerObjectType, SourceContainer);
public DropObject(playerid, PlayerObjectID, PlayerObjectType, SourceContainer)
{
	new Float:fPos[3];
	GetPlayerPos(playerid, fPos[0], fPos[1], fPos[2]);

	if(SourceContainer != -1)
	{//Drop an object that is inside a container
	    RemoveObjectFromObject(playerid, PlayerObjectID, SourceContainer);
	    DropObjectOnPosition(playerid, PlayerObjectID, fPos[0], fPos[1], fPos[2]);
        RenderMessage(playerid, 0x00FF00FF,"Object dropped successfully");
	}
	else
	{//Drop a container:
	    new ObjectSlotID = ObjectData[GetPlayerObjectDataMemory(PlayerObjectID)][UsesSlot];
		if(ObjectSlotID != 1)
		{
		    if(PlayerVar[playerid][PlayerSlots][ObjectSlotID] > 0)
		    {
			    PlayerVar[playerid][PlayerSlots][ObjectSlotID] --;
				mysql_format(dbHandle, query, sizeof query, "UPDATE playerinventories SET `%d` = %d WHERE PlayerName = '%e'", ObjectSlotID, PlayerVar[playerid][PlayerSlots][ObjectSlotID], PlayerName(playerid));
				mysql_tquery(dbHandle, query);
				
			}
		}
		UnrenderPlayerContainer(playerid, PlayerObjectID);
	    DropObjectOnPosition(playerid, PlayerObjectID, fPos[0], fPos[1], fPos[2]);
	    RenderMessage(playerid, 0x00FF00FF,"Object dropped successfully");
	}
	
	if(PlayerObjectType == 6 || PlayerObjectType == 7)
	{//Object is a bullet or a mag, remove it from any weapon that has it inside
	    if(PlayerObjectType == 7)
	    {//Dropped a bullet, check if any mag has these bullets inside, also reset where the bullet is.
			format(query, sizeof query, "UPDATE playerobjects SET P_SpecialFlag_1 = 0 WHERE P_SpecialFlag_1 = %d", PlayerObjectID);
			mysql_tquery(dbHandle, query, "", "");
			format(query, sizeof query, "UPDATE playerobjects SET P_SpecialFlag_1 = 0 WHERE PlayerID = %d", PlayerObjectID);
			mysql_tquery(dbHandle, query, "", "");

			for(new i = 0; i <= LastObjectInfoIndexUsed; i ++)
	    	{
	    	    if(ObjectInfo[i][PlayerID] == 0) continue;
	    	    if(ObjectInfo[i][P_SpecialFlag_1] != PlayerObjectID) continue;

	    	    ObjectInfo[i][P_SpecialFlag_1] = 0;
	    	}
	    	ObjectInfo[GetPlayerObjectMemory(PlayerObjectID)][P_SpecialFlag_1] = 0;
		}
		else if(PlayerObjectType == 6)
	    {//Dropped a mag, check if it's inside any weapon
	        if(ObjectData[GetPlayerObjectDataMemory(SourceContainer)][UsesType] == 2)
	        {
				format(query, sizeof query, "UPDATE playerobjects SET P_SpecialFlag_1 = 0 WHERE PlayerID = %d", ObjectInfo[GetPlayerObjectMemory(SourceContainer)][P_SpecialFlag_1]);
				mysql_tquery(dbHandle, query, "", "");
				
                ObjectInfo[GetPlayerObjectMemory(ObjectInfo[GetPlayerObjectMemory(SourceContainer)][P_SpecialFlag_1])][P_SpecialFlag_1] = 0;
			}
    	}

    	if(PlayerObjectID == PlayerVar[playerid][OnHandAmmoObjectID])
	    	PlayerVar[playerid][OnHandAmmoObjectID] = 0;
    	if(PlayerObjectID == PlayerVar[playerid][OnHandMagObjectID])
	    	PlayerVar[playerid][OnHandAmmoObjectID] = 0,
	    	PlayerVar[playerid][OnHandMagObjectID] = 0;

    	if(PlayerVar[playerid][OnHandObjectID] == SourceContainer)
			CheckOnHandWeaponAmmo(playerid);
	}
	return 1;
}


forward AddObjectToObject(playerid, object, dest);
public AddObjectToObject(playerid, object, dest)
{
    new objectstr[140];
	format(objectstr, 140, "%s", ObjectInfo[GetPlayerObjectMemory(dest)][Inventory]);

	if(strlen(objectstr) == 0)
        format(objectstr,sizeof(objectstr),"%d",object);
	else
    	format(objectstr,sizeof(objectstr),"%s,%d",objectstr,object);

    mysql_format(dbHandle, query, sizeof query,"UPDATE objectinventory SET InsideIDs = '%s' WHERE PlayerObjectID = %d",objectstr,dest);
	mysql_tquery(dbHandle, query, "", "");

	format(ObjectInfo[GetPlayerObjectMemory(dest)][Inventory], 100, "%s", objectstr);

    RefreshObjectInventoryForNear(dest, playerid);
	return 1;
}

forward RemoveObjectFromObject(playerid, object, source);
public RemoveObjectFromObject(playerid, object, source)
{
	new objectstr[140], tempobjects[MAX_CARRY_OBJECTS], condition[24];
	format(objectstr, 140, "%s", ObjectInfo[GetPlayerObjectMemory(source)][Inventory]);
	format(condition, 24, "p<,>a<i>[%d]",MAX_CARRY_OBJECTS);
	sscanf(objectstr, condition, tempobjects);
	objectstr = "";

	for(new i = 0; i < sizeof tempobjects; i ++)
	{
	    if(tempobjects[i] == object)
	    {
	        tempobjects[i] = 0,
	        object = -1;
		}
		if(tempobjects[i] != 0)
		{
	    	format(objectstr,sizeof(objectstr),"%s%d,",objectstr,tempobjects[i]);
		}
	}
	strdel(objectstr, strlen(objectstr)-1, strlen(objectstr));
	mysql_format(dbHandle, query, sizeof query,"UPDATE objectinventory SET InsideIDs = '%s' WHERE PlayerObjectID = %d",objectstr,source);
	mysql_tquery(dbHandle, query, "", "");
	format(ObjectInfo[GetPlayerObjectMemory(source)][Inventory], 100, "%s", objectstr);

	RefreshObjectInventoryForNear(source, playerid);
	return 1;
}


forward OnPlayerClickAction(playerid, ObjectID, fActionID, fActionName[], ObjectType, ActionObjectUses, aTotalUses, Flag1, Flag2, Flag3, objectsource, SpFlag1, SpFlag2, mem1, mem2);
public OnPlayerClickAction(playerid, ObjectID, fActionID, fActionName[], ObjectType, ActionObjectUses, aTotalUses, Flag1, Flag2, Flag3, objectsource, SpFlag1, SpFlag2, mem1, mem2)
{
    PlayerVar[playerid][MemorySlot][0] = 0;
    PlayerVar[playerid][MemorySlot][1] = 0;
    PlayerVar[playerid][ObjectInAction] = 0;
    DestroyActions(playerid);
    
    new ObjectIDMemory = GetPlayerObjectMemory(ObjectID);
    new SelectedObjectMemory = GetPlayerObjectMemory(PlayerVar[playerid][SelectedObjectID]);
    
	if(ActionData[GetActionDataMemory(fActionID)][TypeIDAttached] == -3) //THIS IS INTERNAL
	{//SPECIAL: Container Swap / Add into
		if(fActionID == 20)
		{//AddInto
		    PlayerVar[playerid][ActionSwapStep] = 0;
		
	        new SelectedObjectBaseID = GetObjectBaseID(PlayerVar[playerid][SelectedObjectID]);
	        new SourceBase = GetObjectBaseID(PlayerVar[playerid][SelectedObjectSourceID]);
	        //new DestBase = GetObjectBaseID(ObjectID);

	        MoveObjectToObject(playerid, -2, PlayerVar[playerid][SelectedObjectID], ObjectData[GetObjectDataMemory(SelectedObjectBaseID)][UsesType],
			PlayerVar[playerid][SelectedObjectSourceID], ObjectData[GetObjectDataMemory(SourceBase)][UsesType], ObjectID, ObjectType, playerid, PlayerName(playerid));
			return 1;
		}
		else if(fActionID == 19)
		{//SWAP Container Positions
		    PlayerVar[playerid][ActionSwapStep] = 0;
		    
		    new SelectedObjectPosition = ObjectInfo[SelectedObjectMemory][Position];
	 		new SecondContainerPosition = ObjectInfo[ObjectIDMemory][Position];
		    
		    if(PlayerVar[playerid][SelectedObjectGlobal] == 0 && PlayerVar[playerid][ObjectInActionGlobal] == 0)
		    {//If the container is player and the other container is player too, swap internally
			    ObjectInfo[ObjectIDMemory][Position] = SelectedObjectPosition;
			    ObjectInfo[SelectedObjectMemory][Position] = SecondContainerPosition;

			    format(query, sizeof(query),"UPDATE playerobjects SET position = %d WHERE PlayerID = %d", SelectedObjectPosition, ObjectID);
	    		mysql_tquery(dbHandle, query, "", "");

			    format(query, sizeof(query),"UPDATE playerobjects SET position = %d WHERE PlayerID = %d", SecondContainerPosition, PlayerVar[playerid][SelectedObjectID]);
				mysql_tquery(dbHandle, query, "", "");
				
				PlayerVar[playerid][SelectedObjectID] = 0;
			 	PlayerVar[playerid][SelectedContainerID] = 0;
			 	PlayerVar[playerid][SelectedObjectSourceID] = 0;
			 	PlayerVar[playerid][SelectedObjectGlobal] = 0;
			}
			else
			{//Else do the external swap
			
			    new Float:fPos[3];
			    GetPlayerPos(playerid, fPos[0], fPos[1], fPos[2]);
			    
			    if(PlayerVar[playerid][ObjectInActionGlobal] == 1)
			    {
			        DropObjectOnPosition(-1, PlayerVar[playerid][SelectedObjectID], fPos[0], fPos[1], fPos[2]);
			    	UnrenderPlayerContainer(playerid, PlayerVar[playerid][SelectedObjectID]);
			    	PlayerVar[playerid][OverridePosition] = SelectedObjectPosition;
			    
			        PlayerVar[playerid][SelectedObjectID] = ObjectID;
			        PlayerVar[playerid][SelectedObjectGlobal] = 1;
			        PlayerVar[playerid][SelectedObjectSourceID] = objectsource;
			        PlayerVar[playerid][SelectedContainerID] = ObjectID;
			    }
			    else
			    {
			        DropObjectOnPosition(-1, ObjectID, fPos[0], fPos[1], fPos[2]);
			    	UnrenderPlayerContainer(playerid, ObjectID);
			    	PlayerVar[playerid][OverridePosition] = SecondContainerPosition;
			    }

			    PlayerVar[playerid][PlayerSlots][ObjectData[GetPlayerObjectDataMemory(ObjectID)][UsesSlot]] --;
			    OnPlayerClickPlayerTextDraw(playerid, Inv[playerid][9]);
			}
			LoadPlayerContainers(playerid);
			return 1;
		}
	}

	//Food eating example, auto remove if CurrentUses reach to 0
    if(ObjectType == 5)
    {//Food object on DB
        if(fActionID == 7) // Eat Food
        {
            new Float:HP;
            GetPlayerHealth(playerid, HP);
            HP = HP + float(Flag1);
            if(HP > 100)
                HP = 100;
            
            SetPlayerHealth(playerid, HP);
            SetObjectUses(playerid, ObjectID, ActionObjectUses - 1);
            
            if(ActionObjectUses-1 == 0)
            {
			    if(objectsource == -1)
			    {//food was depleted from outside an object
			        RemoveObjectFromDatabase(ObjectID, true);
			        LoadPlayerContainers(playerid);
			    }
			    else
			    {
			        RemoveObjectFromObject(playerid, ObjectID, objectsource);
			        RemoveObjectFromDatabase(ObjectID, true);
			        LoadPlayerContainers(playerid);
			    }
			    RenderMessage(playerid, 0xFF6600FF, "You ate the remaining food on the can.");
			}
			return 1;
        }
		else if(fActionID == 6) // Eat All Food
		{
		    new Float:HP;
            GetPlayerHealth(playerid, HP);
            HP = HP + float(Flag1*ActionObjectUses);
            if(HP > 100)
                HP = 100;

            SetPlayerHealth(playerid, HP);
            if(objectsource == -1)
		    {//food was depleted from outside an object
		        RemoveObjectFromDatabase(ObjectID, true);
		        LoadPlayerContainers(playerid);
		    }
		    else
		    {
		        RemoveObjectFromObject(playerid, ObjectID, objectsource);
		        RemoveObjectFromDatabase(ObjectID, true);
		        LoadPlayerContainers(playerid);
		    }
		}
		return 1;
    }
    if(ObjectType == 2 || ObjectType == 12) // weapon or bolt weapon
    {
        if(fActionID == 2)
        {//add into
            PlayerVar[playerid][ActionSwapStep] = 0;
            new SelObjectID = PlayerVar[playerid][SelectedObjectID];
            new SelObjectBaseID = GetObjectBaseID(SelObjectID);
            new SelObjectSource = PlayerVar[playerid][SelectedObjectSourceID];
			new SelObjectSourceBase = GetObjectBaseID(SelObjectSource);

            if(SpFlag1 > 0)
                return RenderMessage(playerid, 0xFF6600FF, "That weapon already haves ammo inside!");
                
			MoveObjectToObject(playerid, 0, SelObjectID, ObjectData[GetObjectDataMemory(SelObjectBaseID)][UsesType], SelObjectSource, ObjectData[GetObjectDataMemory(SelObjectSourceBase)][UsesType], ObjectID, ObjectType, playerid, PlayerName(playerid));
		}
		else if(fActionID == 15 || fActionID == 16) //empty weapon
        {
            if(SpFlag1 >= 1)
            {
                MoveObjectToObject(playerid, -1, SpFlag1, ObjectData[GetPlayerObjectDataMemory(SpFlag1)][UsesType],ObjectID,ObjectData[GetPlayerObjectDataMemory(ObjectID)][UsesType],
				objectsource, ObjectData[GetPlayerObjectDataMemory(objectsource)][UsesType], playerid, PlayerName(playerid));
            }
            else
            {
                RenderMessage(playerid, 0xFF6600FF, "The weapon is empty.");
            }
        }
        else if(fActionID == 17) // check inside
        {
			if(SpFlag1 >= 1)
			{//mag detected inside
			    if(ObjectData[GetPlayerObjectDataMemory(SpFlag1)][UsesType] == 6)
					RenderMessage(playerid, 0xFF6600FF, "There's currently a magazine inside of the weapon.");
				else if(ObjectData[GetPlayerObjectDataMemory(SpFlag1)][UsesType] == 7)
					RenderMessage(playerid, 0xFF6600FF, "There's currently a bullet chambered in the weapon.");
			}
			else
			{
			    RenderMessage(playerid, 0xFF6600FF, "The weapon is empty.");
			}
        }
        else if(fActionID == 18) // check magazine
        {
			if(SpFlag1 >= 1)
			{//mag detected inside
				RenderMessage(playerid, 0xFF6600FF, "There's currently some bullets inside of the chamber.");
			}
			else
			{
			    RenderMessage(playerid, 0xFF6600FF, "The weapon doesn't have any bullet chambered.");
			}
        }
		else if(fActionID == 1 || fActionID == 14)
        {//Swap
            if(objectsource != PlayerVar[playerid][SelectedObjectSourceID])
            {
				SwapObjectWithObject(playerid, PlayerVar[playerid][SelectedObjectSourceID], objectsource, PlayerVar[playerid][SelectedObjectID],
				ObjectID, ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][SelectedObjectID])][UsesType], ObjectType, ObjectData[GetPlayerObjectDataMemory(objectsource)][UsesType],
				ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][SelectedObjectSourceID])][UsesType], ObjectInfo[SelectedObjectMemory][Position], mem1, mem2);
			}
			else
			{
			    InternalSwapObject(playerid, PlayerVar[playerid][SelectedObjectSourceID], PlayerVar[playerid][SelectedObjectID], ObjectID,
				ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][SelectedObjectID])][UsesType], ObjectType, ObjectData[GetPlayerObjectDataMemory(objectsource)][UsesType],
				ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][SelectedObjectSourceID])][UsesType],ObjectInfo[SelectedObjectMemory][Position], mem1, mem2);
			}
		}
    }
    if(ObjectType == 6 || ObjectType == 11) // magazine or ammo box (for add/swap)
    {
        if(fActionID == 12) // check ammo
        {
			if(SpFlag1 >= 1)
			{//ammo inside
				RenderFormattedMessage(playerid, 0xFF6600FF, "There's currently %d bullets inside this magazine.", ObjectInfo[GetPlayerObjectMemory(SpFlag1)][CurrentUses]);
			}
			else
			{
			    RenderMessage(playerid, 0xFF6600FF, "The magazine is empty.");
			}
        }
        else if(fActionID == 8) //empty magazine
        {
            if(SpFlag1 >= 1)
            {
                if(ObjectData[GetPlayerObjectDataMemory(objectsource)][UsesType] == 2)
					return RenderMessage(playerid, 0xFF6600FF, "Remove the magazine from the weapon before doing that.");
            
                MoveObjectToObject(playerid, -1, SpFlag1, ObjectData[GetPlayerObjectDataMemory(SpFlag1)][UsesType],ObjectID,ObjectData[GetPlayerObjectDataMemory(ObjectID)][UsesType],
				objectsource,ObjectData[GetPlayerObjectDataMemory(objectsource)][UsesType], playerid, PlayerName(playerid));
            }
            else
            {
                RenderMessage(playerid, 0xFF6600FF, "The magazine is empty.");
            }
        }
        
        if(fActionID == 2)
        {//add into
            PlayerVar[playerid][ActionSwapStep] = 0;
            new SelObjectID = PlayerVar[playerid][SelectedObjectID];
            new SelObjectBaseID = GetObjectBaseID(SelObjectID);
            new SelObjectSource = PlayerVar[playerid][SelectedObjectSourceID];
			new SelObjectSourceBase = GetObjectBaseID(SelObjectSource);
        
            if(ObjectType == 6) // magazine
            {
                if(SpFlag1 > 0)
                    return RenderMessage(playerid, 0xFF6600FF, "That magazine already haves ammo inside!");
                    
				if(ObjectData[GetPlayerObjectDataMemory(objectsource)][UsesType] == 2)
					return RenderMessage(playerid, 0xFF6600FF, "Remove the magazine from the weapon before doing that.");
                    
				MoveObjectToObject(playerid, 0, SelObjectID, ObjectData[GetObjectDataMemory(SelObjectBaseID)][UsesType], SelObjectSource, ObjectData[GetObjectDataMemory(SelObjectSourceBase)][UsesType], ObjectID, ObjectType, playerid, PlayerName(playerid));
        	}
        	else if(ObjectType == 11) // Ammo Box
            {
                MoveObjectToObject(playerid, -2, SelObjectID, ObjectData[GetObjectDataMemory(SelObjectBaseID)][UsesType], SelObjectSource, ObjectData[GetObjectDataMemory(SelObjectSourceBase)][UsesType], ObjectID, ObjectType, playerid, PlayerName(playerid));
            }
		}
		else if(fActionID == 1 || fActionID == 14)
        {//Swap
            if(objectsource != PlayerVar[playerid][SelectedObjectSourceID])
            {
                PlayerVar[playerid][ActionSwapStep] = 1;
            
				SwapObjectWithObject(playerid, PlayerVar[playerid][SelectedObjectSourceID], objectsource, PlayerVar[playerid][SelectedObjectID],
				ObjectID, ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][SelectedObjectID])][UsesType], ObjectType, ObjectData[GetPlayerObjectDataMemory(objectsource)][UsesType],
				ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][SelectedObjectSourceID])][UsesType], ObjectInfo[SelectedObjectMemory][Position], mem1, mem2);
			}
			else
			{
			    PlayerVar[playerid][ActionSwapStep] = 1;
			
			    InternalSwapObject(playerid, PlayerVar[playerid][SelectedObjectSourceID], PlayerVar[playerid][SelectedObjectID], ObjectID,
				ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][SelectedObjectID])][UsesType], ObjectType, ObjectData[GetPlayerObjectDataMemory(objectsource)][UsesType],
				ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][SelectedObjectSourceID])][UsesType],ObjectInfo[SelectedObjectMemory][Position], mem1, mem2);
			}
		}
    }
    if(ObjectType == 7)
    {
        if(fActionID == 10)
        {//split
			if(ActionObjectUses == 1)
			    return RenderMessage(playerid, 0xFF6600FF, "You can't split a single bullet.");
        
            if(SpFlag1 > 0)
                return RenderMessage(playerid, 0xFF6600FF, "You need to take them off the magazine/weapon to do that.");
        
            new newammo, oldammo;
            newammo = ActionObjectUses / 2;
            oldammo = ActionObjectUses / 2;
            
            if(ActionObjectUses % 2 == 1)
				newammo ++;
        
            SplitAmmo(playerid, ObjectID, newammo, oldammo, objectsource);
        }
        else if(fActionID == 13)
        {//combine
            if(SpFlag1 > 0)
                return RenderMessage(playerid, 0xFF6600FF, "You need to take them off the magazine/weapon to do that.");
        
			CheckForBulletCombining(playerid, ObjectID, ActionObjectUses, aTotalUses, PlayerVar[playerid][SelectedObjectID], PlayerVar[playerid][SelectedObjectSourceID], Flag1);
        }
        else if(fActionID == 1 || fActionID == 14)
        {//swap
            if(objectsource != PlayerVar[playerid][SelectedObjectSourceID])
            {
                PlayerVar[playerid][ActionSwapStep] = 1;
            
				SwapObjectWithObject(playerid, PlayerVar[playerid][SelectedObjectSourceID], objectsource, PlayerVar[playerid][SelectedObjectID],
				ObjectID, ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][SelectedObjectID])][UsesType], ObjectType, ObjectData[GetPlayerObjectDataMemory(objectsource)][UsesType],
				ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][SelectedObjectSourceID])][UsesType], ObjectInfo[SelectedObjectMemory][Position], mem1, mem2);
			}
			else
			{
			    PlayerVar[playerid][ActionSwapStep] = 1;
			
			    InternalSwapObject(playerid, PlayerVar[playerid][SelectedObjectSourceID], PlayerVar[playerid][SelectedObjectID], ObjectID,
				ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][SelectedObjectID])][UsesType], ObjectType, ObjectData[GetPlayerObjectDataMemory(objectsource)][UsesType],
				ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][SelectedObjectSourceID])][UsesType],ObjectInfo[SelectedObjectMemory][Position], mem1, mem2);
			}
        }
    }
    PlayerVar[playerid][ObjectInActionGlobal] = 0;
    //CallRemoteFunction("OnPlayerClickAction","iiisiiii",playerid, ObjectID, fActionID, ActionName, ObjectType, CurrentUses, TotalUses, umemoryslot);
	return 1;
}


forward SplitAmmo(playerid, ObjectID, newammo, oldammo, ObjectSource);
public SplitAmmo(playerid, ObjectID, newammo, oldammo, ObjectSource)
{
    new objectdata = GetObjectBaseID(ObjectID);
    CreateNewSplittedObject(playerid, objectdata, ObjectSource, 0, newammo, PlayerName(playerid));
    RenderMessage(playerid, 0xFF6600FF, "Splitted the ammo.");

    mysql_format(dbHandle, query, sizeof query, "UPDATE playerobjects SET CurrentUses = %d WHERE PlayerID = %d", oldammo, ObjectID);
    mysql_tquery(dbHandle, query);
    
    ObjectInfo[GetPlayerObjectMemory(ObjectID)][CurrentUses] = oldammo;
	return 1;
}

forward CheckForBulletCombining(playerid, destobject, destuses, desttotaluses, source, source_source, destcaliber);
public CheckForBulletCombining(playerid, destobject, destuses, desttotaluses, source, source_source, destcaliber)
{
    PlayerVar[playerid][ActionSwapStep] = 0;

    if(destuses == desttotaluses)
	    return 1;
	    
	new sourcecaliber = ObjectData[GetPlayerObjectDataMemory(source)][SpecialFlag_1];
	if(sourcecaliber != destcaliber)
	    return RenderMessage(playerid, 0xFF6600FF, "You can't combine different caliber bullets.");
	    

	new sourceammo = ObjectInfo[GetPlayerObjectMemory(source)][CurrentUses];
	new ammoneeded = desttotaluses - destuses;

	if(sourceammo > ammoneeded)
	{//just reduce the first ammo
	    SetObjectUses(playerid, source, sourceammo-ammoneeded);
	    SetObjectUses(playerid, destobject, destuses + ammoneeded);
	}
	else
	{//remove ammo object
	    SetObjectUses(playerid, destobject, destuses + sourceammo);
	
        RemoveObjectFromObject(playerid, source, source_source);
        RemoveObjectFromDatabase(source, true);
        
        PlayerVar[playerid][SelectedObjectID] = 0;
	    PlayerVar[playerid][SelectedObjectSourceID] = 0;
	    PlayerVar[playerid][SelectedContainerID] = 0;
        LoadPlayerContainers(playerid);
	}
	
	RenderMessage(playerid, 0xFF6600FF, "Successfully combined the bullet stacks.");
	return 1;
}

forward OnPlayerPutObjectInHand(playerid, object, object_type);
public OnPlayerPutObjectInHand(playerid, object, object_type)
{
	new ObjectBaseID = GetObjectBaseID(object);
	new ObjectBaseMem = GetObjectDataMemory(ObjectBaseID);

	new display = ObjectData[ObjectBaseMem][Display];
    new color = ObjectData[ObjectBaseMem][DisplayColor];
    new Float:fRotX = ObjectData[ObjectBaseMem][DisplayOffsets][0];
    new Float:fRotY = ObjectData[ObjectBaseMem][DisplayOffsets][1];
    new Float:fRotZ = ObjectData[ObjectBaseMem][DisplayOffsets][2];
    new Float:fZoom = ObjectData[ObjectBaseMem][DisplayOffsets][3];

    PlayerTextDrawHide(playerid, Inv[playerid][18]);
    PlayerTextDrawSetPreviewModel(playerid, Inv[playerid][18], display);
    PlayerTextDrawSetPreviewRot(playerid, Inv[playerid][18], fRotX, fRotY, fRotZ, fZoom);
    PlayerTextDrawColor(playerid, Inv[playerid][18], color);
    PlayerTextDrawShow(playerid, Inv[playerid][18]);

    SetPlayerAttachedObject(playerid, 0, display, 6, ObjectData[ObjectBaseMem][OnHandOffsets][0],
	ObjectData[ObjectBaseMem][OnHandOffsets][1], ObjectData[ObjectBaseMem][OnHandOffsets][2],
	ObjectData[ObjectBaseMem][OnHandOffsets][3], ObjectData[ObjectBaseMem][OnHandOffsets][4],
	ObjectData[ObjectBaseMem][OnHandOffsets][5], ObjectData[ObjectBaseMem][ObjectScales][0],
	ObjectData[ObjectBaseMem][ObjectScales][1], ObjectData[ObjectBaseMem][ObjectScales][2],
	RGBAToARGB(ObjectData[ObjectBaseMem][DisplayColor]), RGBAToARGB(ObjectData[ObjectBaseMem][DisplayColor]));
    
   	PlayerVar[playerid][OnHandObjectID] = object;
    PlayerVar[playerid][OnHandWeaponID] = 0;
    PlayerVar[playerid][OnHandAmmoObjectID] = 0;
    PlayerVar[playerid][OnHandMagObjectID] = 0;
    
    if(ObjectData[ObjectBaseMem][SlotsInside] > 0)
    {
        LoadOnHandObjectInventory(playerid, object);
    }
    
    if(object_type == 2 || object_type == 12 || object_type == 9) //weapon (only accepts magazines), bolt weapon (only accepts ammo, not magazines), melee weapon (nothing needed)
    {
        OnPlayerPutWeaponOnHand(playerid);
    }
    
    for(new a = 1; a < 10; a ++)
    {
		if(PlayerVar[playerid][ObjectStoredInIndex][a] != object) continue;
		RemovePlayerAttachedObject(playerid, a);
		break;
    }
    
	PlayerVar[playerid][SelectedObjectID] = 0;
 	PlayerVar[playerid][SelectedContainerID] = 0;
 	PlayerVar[playerid][SelectedObjectSourceID] = 0;
 	PlayerVar[playerid][SelectedObjectGlobal] = 0;
 	LoadPlayerContainers(playerid);
	return 1;
}


stock CheckOnHandWeaponAmmo(playerid)
{
	ResetPlayerWeapons(playerid);

	new WeaponObjectID = PlayerVar[playerid][OnHandObjectID];
	new WeaponBaseID = GetObjectBaseID(WeaponObjectID);
	new WeaponBaseMem = GetObjectDataMemory(WeaponBaseID);
	new TypeOfWeapon = ObjectData[WeaponBaseMem][UsesType];

    if(TypeOfWeapon == 2)
	{//Magazined weapon
		new ObjectID = ObjectInfo[GetPlayerObjectMemory(WeaponObjectID)][P_SpecialFlag_1]; //ID of the mag or the bullet that is inside
		
		if(ObjectID == 0)
		{
    	    PlayerVar[playerid][HasInvalidAmmo] = 1;
    	    return 1;
		}
		
        if(ObjectData[GetPlayerObjectDataMemory(ObjectID)][UsesType] == 6)
	    {//Magazine inside
	    	new MagazineObjectID = ObjectID;
			new AmmoInsideOfMag = ObjectInfo[GetPlayerObjectMemory(MagazineObjectID)][P_SpecialFlag_1];

		    PlayerVar[playerid][OnHandAmmoObjectID] = AmmoInsideOfMag;
		    PlayerVar[playerid][OnHandMagObjectID] = MagazineObjectID;

	    	PlayerVar[playerid][OnHandWeaponID] = ObjectData[WeaponBaseMem][SpecialFlag_1];
		    ResetPlayerWeapons(playerid);

			if(AmmoInsideOfMag == 0)
			{
			    PlayerVar[playerid][HasInvalidAmmo] = 1;
			    return 2;
			}
			
			PlayerVar[playerid][HasInvalidAmmo] = 0;
			GivePlayerWeapon(playerid, ObjectData[WeaponBaseMem][SpecialFlag_1], ObjectInfo[GetPlayerObjectMemory(AmmoInsideOfMag)][CurrentUses]);
			return 3;
		}
		else
		{// Chambered
		    new AmmoInsideOfWeapon = ObjectInfo[GetPlayerObjectMemory(WeaponObjectID)][P_SpecialFlag_1];

		    PlayerVar[playerid][OnHandAmmoObjectID] = AmmoInsideOfWeapon;
		    PlayerVar[playerid][OnHandMagObjectID] = AmmoInsideOfWeapon;

	    	if(AmmoInsideOfWeapon == 0)
	    	{
	    	    PlayerVar[playerid][HasInvalidAmmo] = 1;
	    	    return 1;
	    	}

	    	PlayerVar[playerid][OnHandWeaponID] = ObjectData[WeaponBaseMem][SpecialFlag_1];
		    ResetPlayerWeapons(playerid);

            PlayerVar[playerid][HasInvalidAmmo] = 0;
			GivePlayerWeapon(playerid, ObjectData[WeaponBaseMem][SpecialFlag_1], ObjectInfo[GetPlayerObjectMemory(AmmoInsideOfWeapon)][CurrentUses]);
			return 3;
		}
	}
	else if(TypeOfWeapon == 12)
	{//Bolt Action weapon
	    new AmmoInsideOfWeapon = ObjectInfo[GetPlayerObjectMemory(WeaponObjectID)][P_SpecialFlag_1];

	    PlayerVar[playerid][OnHandAmmoObjectID] = AmmoInsideOfWeapon;
	    PlayerVar[playerid][OnHandMagObjectID] = AmmoInsideOfWeapon;

    	if(AmmoInsideOfWeapon == 0)
    	{
    	    PlayerVar[playerid][HasInvalidAmmo] = 1;
    	    return 1;
    	}

    	PlayerVar[playerid][OnHandWeaponID] = ObjectData[WeaponBaseMem][SpecialFlag_1];
	    ResetPlayerWeapons(playerid);

        PlayerVar[playerid][HasInvalidAmmo] = 0;
		GivePlayerWeapon(playerid, ObjectData[WeaponBaseMem][SpecialFlag_1], ObjectInfo[GetPlayerObjectMemory(AmmoInsideOfWeapon)][CurrentUses]);
		return 3;
	}
	else if(TypeOfWeapon == 9)
	{//Melee
        PlayerVar[playerid][OnHandWeaponID] = ObjectData[WeaponBaseMem][SpecialFlag_1];
	    ResetPlayerWeapons(playerid);
	
	    PlayerVar[playerid][HasInvalidAmmo] = 2; //melee weapon
	    GivePlayerWeapon(playerid, ObjectData[WeaponBaseMem][SpecialFlag_1], 1);
        return 3;
	}
	return 1;
}

forward OnPlayerPutWeaponOnHand(playerid);
public OnPlayerPutWeaponOnHand(playerid)
{
	new returned = CheckOnHandWeaponAmmo(playerid);
	
	if(returned == 1)
	    return RenderMessage(playerid, 0xFF6600FF, "The weapon is now on your hand. It doesn't seem to have anything inside.");
	
	else if(returned == 2)
	    return RenderMessage(playerid, 0xFF6600FF, "You've put the weapon on your hand, the magazine seems to be empty.");

	else if(returned == 3)
	    return RenderMessage(playerid, 0xFF6600FF, "You've put the weapon on your hand.");

	return 1;
}

forward OnPlayerRemoveWeaponFromHand(playerid);
public OnPlayerRemoveWeaponFromHand(playerid)
{
	ResetPlayerWeapons(playerid);

    PlayerVar[playerid][OnHandWeaponID] = 0;
    PlayerVar[playerid][OnHandAmmoObjectID] = 0;
    PlayerVar[playerid][OnHandMagObjectID] = 0;
	return 1;
}

forward OnObjectMovedAttempt(playerid, object, type, source, sourcetype, dest, desttype, newowner);
public OnObjectMovedAttempt(playerid, object, type, source, sourcetype, dest, desttype, newowner)
{
	//if(type == TYPE_AMMO && desttype == TYPE_WEAPON) <- Ammo added to a weapon, for example... Use Special flags variables in the DB to store the ID of the ammo that was just added
	//OnPlayerWeaponShot to decrease the ammo? Or even less resourceful, when disconnecting or moving/dropping the object
	//printf("OnServerObjectMoved(%d, %d, %d, %d, %d, %d, %d, %d)",playerid, object, type, source, sourcetype, dest, desttype, newowner);

	if(desttype == 2 && (type != 6 && type != 7))
	{
	    RenderMessage(playerid, 0xFF6600FF, "You can only put magazines or bullets on weapons.");
	    return 0;
	}
	if(desttype == 12 && type != 7)
	{
	    RenderMessage(playerid, 0xFF6600FF, "You can only put bullets on bolt action weapons.");
	    return 0;
	}
	if(desttype == 6 && type != 7)
	{
	    RenderMessage(playerid, 0xFF6600FF, "You can only put ammo on magazines.");
	    return 0;
	}
	if(desttype == 12 && type != 7)
	{
	    RenderMessage(playerid, 0xFF6600FF, "You can only put ammo on the ammo boxes.");
	    return 0;
	}
	
	if((desttype == 2 || desttype == 12) && ObjectInfo[GetPlayerObjectMemory(dest)][P_SpecialFlag_1] != 0)
	{
	    RenderMessage(playerid, 0xFF6600FF, "That weapon already haves ammo inside, remove/swap it first.");
	    return 0;
	}
	if(desttype == 6 && ObjectInfo[GetPlayerObjectMemory(dest)][P_SpecialFlag_1] != 0)
	{
	    RenderMessage(playerid, 0xFF6600FF, "That magazine already haves ammo inside, remove/swap it first.");
	    return 0;
	}
	
	if((desttype == 2 || desttype == 12) && (type == 7 || type == 6))
	{//Check for bullets or mags into weapons
		if(ObjectData[GetPlayerObjectDataMemory(dest)][SpecialFlag_2] != ObjectData[GetPlayerObjectDataMemory(object)][SpecialFlag_1])
		{
		    RenderMessage(playerid, 0xFF6600FF, "That doesn't seem to fit into the weapon.");
		    return 0;
		}
	}
	if(desttype == 6 && type == 7)
	{
	    if(ObjectData[GetPlayerObjectDataMemory(dest)][SpecialFlag_1] != ObjectData[GetPlayerObjectDataMemory(object)][SpecialFlag_1])
		{
		    RenderMessage(playerid, 0xFF6600FF, "That bullet wont fit into that magazine!");
		    return 0;
		}
	}
	
	if(type == 7 && (desttype == 2 || desttype == 12 || desttype == 6) )
		if(CheckBulletLimit(playerid, object, source, sourcetype, dest) == 0) //If the bullet has to be split, then it will not be moved, a new one has to be created
	        return 0;

	return 1;
}

forward OnServerObjectMoved(playerid, object, type, source, sourcetype, dest, desttype, newowner);
public OnServerObjectMoved(playerid, object, type, source, sourcetype, dest, desttype, newowner)
{
	new ObjectMemory = GetPlayerObjectMemory(object);
	new SourceMemory = GetPlayerObjectMemory(source);
	new DestMemory = GetPlayerObjectMemory(dest);

	if(type == 7 && desttype == 6)
	{//ammo into mag
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = %d WHERE PlayerID = %d",object, dest);
	    mysql_tquery(dbHandle, query, "", "");
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = %d WHERE PlayerID = %d",dest, object);
	    mysql_tquery(dbHandle, query, "", "");

	    ObjectInfo[DestMemory][P_SpecialFlag_1] = object;
	    ObjectInfo[ObjectMemory][P_SpecialFlag_1] = dest;
	}
	if(type == 7 && sourcetype == 6)
	{//ammo outside mag
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = 0 WHERE PlayerID = %d", source);
	    mysql_tquery(dbHandle, query, "", "");
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = 0 WHERE PlayerID = %d", object);
	    mysql_tquery(dbHandle, query, "", "");

	    ObjectInfo[SourceMemory][P_SpecialFlag_1] = 0;
	    ObjectInfo[ObjectMemory][P_SpecialFlag_1] = 0;

		if(playerid != INVALID_PLAYER_ID)
			if(object == PlayerVar[playerid][OnHandAmmoObjectID])
		    	PlayerVar[playerid][OnHandAmmoObjectID] = 0;
	}

	if(type == 7 && (desttype == 12 || desttype == 2))
	{//bullet into weapon
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = %d WHERE PlayerID = %d",object, dest);
	    mysql_tquery(dbHandle, query, "", "");
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = %d WHERE PlayerID = %d",dest, object);
	    mysql_tquery(dbHandle, query, "", "");

	    ObjectInfo[DestMemory][P_SpecialFlag_1] = object;
	    ObjectInfo[ObjectMemory][P_SpecialFlag_1] = dest;
	}
	if(type == 7 && (sourcetype == 12 || sourcetype == 2))
	{//bullet outside weapon
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = 0 WHERE PlayerID = %d", source);
	    mysql_tquery(dbHandle, query, "", "");
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = 0 WHERE PlayerID = %d", object);
	    mysql_tquery(dbHandle, query, "", "");

	    ObjectInfo[SourceMemory][P_SpecialFlag_1] = 0;
	    ObjectInfo[ObjectMemory][P_SpecialFlag_1] = 0;

        if(playerid != INVALID_PLAYER_ID)
	    	if(object == PlayerVar[playerid][OnHandAmmoObjectID])
		    	PlayerVar[playerid][OnHandAmmoObjectID] = 0;
	}

    if(type == 6 && desttype == 2)
	{//mag into weapon
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = %d WHERE PlayerID = %d",object, dest);
	    mysql_tquery(dbHandle, query, "", "");

	    ObjectInfo[DestMemory][P_SpecialFlag_1] = object;
	}
	if(type == 6 && sourcetype == 2)
	{//mag outside weapon
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = 0 WHERE PlayerID = %d", source);
	    mysql_tquery(dbHandle, query, "", "");

	    ObjectInfo[SourceMemory][P_SpecialFlag_1] = 0;

        if(playerid != INVALID_PLAYER_ID)
	    	if(object == PlayerVar[playerid][OnHandMagObjectID])
   	 			PlayerVar[playerid][OnHandAmmoObjectID] = 0,
		    	PlayerVar[playerid][OnHandMagObjectID] = 0;
	}

    if(playerid != INVALID_PLAYER_ID)
		if((PlayerVar[playerid][OnHandObjectID] == source && source != 0) || (PlayerVar[playerid][OnHandObjectID] == dest && dest != 0)) //on hand object affected in any way
			CheckOnHandWeaponAmmo(playerid);

	return 1;
}

forward OnObjectSwapAttempt(playerid, object1source, object2source, object, object2, object1type, object2type, object1desttype, object1sourcetype);
public OnObjectSwapAttempt(playerid, object1source, object2source, object, object2, object1type, object2type, object1desttype, object1sourcetype)
{
    new
		object1dest = object2source,
		object2dest = object1source,
		object2desttype = object1sourcetype;

	if(PlayerVar[playerid][ActionSwapStep] == 0) //IF YOU WANT SPECIAL INTERACTIONS, YOU HAVE TO PUT THEM HERE.
	{
	    new bool:found = false, bool:global = false;
	    for(new i = 0; i < sizeof(ObjectStoredInContainer[]); i ++)
		{
		    for(new a = 0; a < sizeof(ObjectStoredInContainer[][]); a ++)
		    {
		        if(ObjectStoredInContainer[playerid][i][a] == object2)
		        {
		            if(ObjectData[GetPlayerObjectDataMemory(object2)][Size] == 0) break;

					PlayerVar[playerid][MemorySlot][0] = a;
					PlayerVar[playerid][MemorySlot][1] = i;
					found = true;
					global = false;
					break;
		        }
		    }
		}
		if(found == false)
		{
			for(new i = 0; i < sizeof(ObjectStoredInDroppedContainer[]); i ++)
			{
			    for(new a = 0; a < sizeof(ObjectStoredInDroppedContainer[][]); a ++)
			    {
			        if(ObjectStoredInDroppedContainer[playerid][i][a] == object2)
			        {
			            if(ObjectData[GetPlayerObjectDataMemory(object2)][Size] == 0) break;

						PlayerVar[playerid][MemorySlot][0] = a;
						PlayerVar[playerid][MemorySlot][1] = i;
						found = true;
						global = true;
						break;
			        }
			    }
			}
		}
	
		if((object2type == 6 || object2type == 11) && object1type == 7  ||  (object2type == 2 || object2type == 12) && (object1type == 7 || object1type == 6))
		{//ammo into mag/ammo into weapon/mag into weapon - already found, check if he wants to swap or add them
	    	PlayerVar[playerid][ActionSwapStep] = 1;
	    	
			PlayerVar[playerid][ObjectInAction] = object2;
			OnPlayerRequestActionList(playerid, object2, PlayerVar[playerid][MemorySlot][0], -1, object2source, global);
		    return 0;
		}
		if(object2type == 7 && object1type == 7)
		{//SWAP OR COMBINE
		    PlayerVar[playerid][ActionSwapStep] = 1;

			PlayerVar[playerid][ObjectInAction] = object2;
			OnPlayerRequestActionList(playerid, object2, PlayerVar[playerid][MemorySlot][0], -2, object2source, global);
		    return 0;
		}
	}
	
    if(object == PlayerVar[playerid][OnHandObjectID] || object2 == PlayerVar[playerid][OnHandObjectID])
	{
	    RenderMessage(playerid, 0xFF6600FF, "Remove the object from your hand before doing that.");
	    return 0;
	}

	if(object1desttype == 2 && (object1type != 6 && object1type != 7))
	{
	    RenderMessage(playerid, 0xFF6600FF, "You can only attach magazines or chamber bullets on weapons.");
	    return 0;
	}
	if(object1desttype == 6 && object1type != 7)
	{
	   	RenderMessage(playerid, 0xFF6600FF, "You can only attach bullets on magazines.");
	    return 0;
	}
	if(object1desttype == 12 && object1type != 7)
	{
	   	RenderMessage(playerid, 0xFF6600FF, "You can only atatch bullets on bolt weapons.");
	    return 0;
	}

	if((object1desttype == 2 || object1desttype == 12) && (object1type == 7 || object1type == 6))
	{//Check for bullets or mags into weapons
		if(ObjectData[GetPlayerObjectDataMemory(object1dest)][SpecialFlag_2] != ObjectData[GetPlayerObjectDataMemory(object)][SpecialFlag_1])
		{
		    RenderMessage(playerid, 0xFF6600FF, "That doesn't seem to fit into the weapon.");
		    return 0;
		}
	}
	if(object1desttype == 6 && object1type == 7)
	{
	    if(ObjectData[GetPlayerObjectDataMemory(object1dest)][SpecialFlag_1] != ObjectData[GetPlayerObjectDataMemory(object)][SpecialFlag_1])
		{
		    RenderMessage(playerid, 0xFF6600FF, "That bullet wont fit into that magazine!");
		    return 0;
		}
	}


	if(object2desttype == 2 && (object2type != 6 && object2type != 7))
	{
	    RenderMessage(playerid, 0xFF6600FF, "You can only attach magazines or chamber bullets on weapons.");
	    return 0;
	}
	if(object2desttype == 6 && object2type != 7)
	{
	   	RenderMessage(playerid, 0xFF6600FF, "You can only attach bullets on magazines.");
	    return 0;
	}
	if(object2desttype == 12 && object2type != 7)
	{
	   	RenderMessage(playerid, 0xFF6600FF, "You can only atatch bullets on bolt weapons.");
	    return 0;
	}

	if((object2desttype == 2 || object2desttype == 12) && (object2type == 7 || object2type == 6))
	{//Check for bullets or mags into weapons
		if(ObjectData[GetPlayerObjectDataMemory(object2dest)][SpecialFlag_2] != ObjectData[GetPlayerObjectDataMemory(object2)][SpecialFlag_1])
		{
		    RenderMessage(playerid, 0xFF6600FF, "That doesn't seem to fit into the weapon.");
		    return 0;
		}
	}
	if(object2desttype == 6 && object2type == 7)
	{
	    if(ObjectData[GetPlayerObjectDataMemory(object2dest)][SpecialFlag_1] != ObjectData[GetPlayerObjectDataMemory(object2)][SpecialFlag_1])
		{
		    RenderMessage(playerid, 0xFF6600FF, "That bullet wont fit into that magazine!");
		    return 0;
		}
	}
	
	if(object1type == 7)
	{
	    if(ObjectInfo[GetPlayerObjectMemory(object)][P_SpecialFlag_1] != 0)
	    {
	        RenderMessage(playerid, 0xFF6600FF, "Can't swap bullets that are inside a magazine or a weapon.");
	        PlayerVar[playerid][ActionSwapStep] = 0;
	        return 0;
	    }
	}
	if(object2type == 7)
	{
	    if(ObjectInfo[GetPlayerObjectMemory(object2)][P_SpecialFlag_1] != 0)
	    {
	        RenderMessage(playerid, 0xFF6600FF, "Can't swap bullets that are inside a magazine or a weapon.");
	        PlayerVar[playerid][ActionSwapStep] = 0;
	        return 0;
	    }
	}
	return 1;
}

forward OnObjectSwapped(playerid, object1source, object2source, object, object2, object1type, object2type, object1desttype, object1sourcetype);
public OnObjectSwapped(playerid, object1source, object2source, object, object2, object1type, object2type, object1desttype, object1sourcetype)
{
	new
		object1dest = object2source,
		object2dest = object1source,
		object2sourcetype = object1desttype,
		object2desttype = object1sourcetype;
		

	new objectmemory = GetPlayerObjectMemory(object);
	new object1sourcememory = GetPlayerObjectMemory(object1source);
	new object2memory = GetPlayerObjectMemory(object2);
	new object2sourcememory = GetPlayerObjectMemory(object2source);
	
	new object1destmemory = object2sourcememory,
	    object2destmemory = object1sourcememory;

    if(object1type == 7 && object1sourcetype == 6) // Object 1 is a bullet and it is coming out of a magazine
	{
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = 0 WHERE PlayerID = %d", object1source);
	    mysql_tquery(dbHandle, query, "", "");
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = 0 WHERE PlayerID = %d", object);
	    mysql_tquery(dbHandle, query, "", "");

	    ObjectInfo[objectmemory][P_SpecialFlag_1] = 0; //Store the ID of the mag that the bullet is now inside
	    ObjectInfo[object1sourcememory][P_SpecialFlag_1] = 0; //Store the ID of the bullet that is now inside of the mag
	    
	    if(object == PlayerVar[playerid][OnHandAmmoObjectID])
	        PlayerVar[playerid][OnHandAmmoObjectID] = 0;
	}
	if(object2type == 7 && object2sourcetype == 6) // Object 2 is a bullet and is coming out of a magazine
	{
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = 0 WHERE PlayerID = %d",object2source);
	    mysql_tquery(dbHandle, query, "", "");
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = 0 WHERE PlayerID = %d", object2);
	    mysql_tquery(dbHandle, query, "", "");

	    ObjectInfo[object2memory][P_SpecialFlag_1] = 0; //Store the ID of the mag that the bullet is now inside
	    ObjectInfo[object2sourcememory][P_SpecialFlag_1] = 0; //Store the ID of the bullet that is now inside of the mag
	    
	    if(object2 == PlayerVar[playerid][OnHandAmmoObjectID])
	        PlayerVar[playerid][OnHandAmmoObjectID] = 0;
	}

	if(object1type == 7 && object1desttype == 6) // Object 1 is a bullet and is going into a magazine
	{
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = %d WHERE PlayerID = %d",object, object1dest);
	    mysql_tquery(dbHandle, query, "", "");
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = %d WHERE PlayerID = %d",object1dest, object);
	    mysql_tquery(dbHandle, query, "", "");
	    
	    ObjectInfo[objectmemory][P_SpecialFlag_1] = object1dest; //Store the ID of the mag that the bullet is now inside
	    ObjectInfo[object1destmemory][P_SpecialFlag_1] = object; //Store the ID of the bullet that is now inside of the mag
	}
	if(object2type == 7 && object2desttype == 6) // Object 2 is a bullet and is going into a magazine
	{
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = %d WHERE PlayerID = %d",object2, object2dest);
	    mysql_tquery(dbHandle, query, "", "");
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = %d WHERE PlayerID = %d",object2dest, object);
	    mysql_tquery(dbHandle, query, "", "");

	    ObjectInfo[object2memory][P_SpecialFlag_1] = object2dest; //Store the ID of the mag that the bullet is now inside
	    ObjectInfo[object2destmemory][P_SpecialFlag_1] = object2; //Store the ID of the bullet that is now inside of the mag
	}
	
	

    if(object1type == 6 && object1sourcetype == 2) //Object 1 is a mag and is coming out of a weapon
	{
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = 0 WHERE PlayerID = %d", object1source);
	    mysql_tquery(dbHandle, query, "", "");
	    
	    ObjectInfo[object1sourcememory][P_SpecialFlag_1] = 0;
	    
	    if(object == PlayerVar[playerid][OnHandMagObjectID])
	        PlayerVar[playerid][OnHandAmmoObjectID] = 0,
		    PlayerVar[playerid][OnHandMagObjectID] = 0;
	}
	if(object2type == 6 && object2sourcetype == 2) //Object 2 is a mag and is coming out of a weapon
	{
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = 0 WHERE PlayerID = %d", object2source);
	    mysql_tquery(dbHandle, query, "", "");

	    ObjectInfo[object2sourcememory][P_SpecialFlag_1] = 0;
	    
	    if(object2 == PlayerVar[playerid][OnHandMagObjectID])
	        PlayerVar[playerid][OnHandAmmoObjectID] = 0,
		    PlayerVar[playerid][OnHandMagObjectID] = 0;
	}
	
	if(object1type == 6 && object1desttype == 2) // Object 1 is a mag and is going inside a weapon
	{
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = %d WHERE PlayerID = %d",object, object1dest);
	    mysql_tquery(dbHandle, query, "", "");
	    
	    ObjectInfo[object1destmemory][P_SpecialFlag_1] = object;
	}
	if(object2type == 6 && object2desttype == 2) // Object 2 is a mag and is going inside a weapon
	{
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = %d WHERE PlayerID = %d",object2, object2dest);
	    mysql_tquery(dbHandle, query, "", "");

	    ObjectInfo[object2destmemory][P_SpecialFlag_1] = object2;
	}
	
	if(object1type == 7 && (object2sourcetype == 2 || object2sourcetype == 12)) //Object 1 is a bullet and is coming out of a weapon
	{
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = 0 WHERE PlayerID = %d", object1source);
	    mysql_tquery(dbHandle, query, "", "");
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = 0 WHERE PlayerID = %d", object);
	    mysql_tquery(dbHandle, query, "", "");

	    ObjectInfo[object1sourcememory][P_SpecialFlag_1] = 0;
	    ObjectInfo[objectmemory][P_SpecialFlag_1] = 0;
	    
	    if(object == PlayerVar[playerid][OnHandAmmoObjectID])
	        PlayerVar[playerid][OnHandAmmoObjectID] = 0;
	}
	if(object2type == 7 && (object2sourcetype == 2 || object2sourcetype == 12)) //Object 2 is a bullet and is coming out of a weapon
	{
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = 0 WHERE PlayerID = %d", object2source);
	    mysql_tquery(dbHandle, query, "", "");
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = 0 WHERE PlayerID = %d", object2);
	    mysql_tquery(dbHandle, query, "", "");

	    ObjectInfo[object2sourcememory][P_SpecialFlag_1] = 0;
	    ObjectInfo[object2memory][P_SpecialFlag_1] = 0;
	    
	    if(object2 == PlayerVar[playerid][OnHandAmmoObjectID])
	        PlayerVar[playerid][OnHandAmmoObjectID] = 0;
	}
	
	if(object1type == 7 && (object1desttype == 12 || object1desttype == 2)) // Object 1 is a bullet and is going into a weapon
	{
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = %d WHERE PlayerID = %d",object, object1dest);
	    mysql_tquery(dbHandle, query, "", "");
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = %d WHERE PlayerID = %d",object1dest, object);
	    mysql_tquery(dbHandle, query, "", "");

	    ObjectInfo[objectmemory][P_SpecialFlag_1] = object1dest;
	    ObjectInfo[object1destmemory][P_SpecialFlag_1] = object;
	}
	if(object2type == 7 && (object1desttype == 12 || object1desttype == 2)) // Object 2 is a bullet and is going into a weapon
	{
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = %d WHERE PlayerID = %d",object2, object2dest);
	    mysql_tquery(dbHandle, query, "", "");
	    format(query, sizeof query,"UPDATE playerobjects SET P_SpecialFlag_1 = %d WHERE PlayerID = %d",object2dest, object);
	    mysql_tquery(dbHandle, query, "", "");

	    ObjectInfo[object2memory][P_SpecialFlag_1] = object2dest;
	    ObjectInfo[object2destmemory][P_SpecialFlag_1] = object2;
	}
	
	if(PlayerVar[playerid][OnHandObjectID] == object1dest || PlayerVar[playerid][OnHandObjectID] == object2dest)
		CheckOnHandWeaponAmmo(playerid);
		
	return 1;
}



forward OnObjectDropped(playerid, object, Float:fX, Float:fY, Float:fZ);
public OnObjectDropped(playerid, object, Float:fX, Float:fY, Float:fZ)
{
	return 1;
}


forward UpdateObjectLastPosition(playerid, object);
public UpdateObjectLastPosition(playerid, object)
{
	new rows, fields;
	cache_get_data(rows, fields);
	if(rows == 0)
	    return 1;
	    
    new maxpos = cache_get_row_int (0, 0);
    format(query, sizeof(query),"UPDATE playerobjects SET position = %d WHERE PlayerID = %d", maxpos+1, object);
    mysql_tquery(dbHandle, query, "", "");
    
    ObjectInfo[GetPlayerObjectMemory(object)][Position] = maxpos + 1;
    
    if(playerid != -1)
    {
        PlayerVar[playerid][SelectedObjectID] = 0;
	 	PlayerVar[playerid][SelectedContainerID] = 0;
	 	PlayerVar[playerid][SelectedObjectSourceID] = 0;
        LoadPlayerContainers(playerid);
    }
	return 1;
}

public OnPlayerClickTextDraw(playerid, Text:clickedid)
{
	if(clickedid == Text:INVALID_TEXT_DRAW)
	{
	    if(PlayerVar[playerid][InventoryOpen] != 0)
			OnPlayerClickPlayerTextDraw(playerid, Inv[playerid][14]);
	}
	return 1;
}

public OnPlayerClickPlayerTextDraw(playerid, PlayerText:playertextid)
{
	new Keys, ud, lr;
	GetPlayerKeys(playerid, Keys, ud, lr);
	
	new SelectedObjectMemory;
	if(PlayerVar[playerid][SelectedObjectID] != 0)
		SelectedObjectMemory = GetPlayerObjectMemory(PlayerVar[playerid][SelectedObjectID]);

    if(playertextid == ActionMenu[playerid][3])
    {
        PlayerVar[playerid][MemorySlot][0] = 0;
        PlayerVar[playerid][MemorySlot][1] = 0;
        PlayerVar[playerid][ObjectInAction] = 0;
        PlayerVar[playerid][ObjectInActionGlobal] = 0;
    	PlayerVar[playerid][ActionSwapStep] = 0;
        DestroyActions(playerid);
        return 1;
    }
    for(new i = 0; i < sizeof(ActionMenu[]); i ++)
    {
        if(playertextid == ActionMenu[playerid][i])
        {
            new ActionIDs = PlayerVar[playerid][ActionStored][i];
            new ObjectAffected = PlayerVar[playerid][ObjectInAction];
            new ObjectAffectedBase = GetObjectBaseID(ObjectAffected);
            new ObjectAffectedBaseMem = GetObjectDataMemory(ObjectAffectedBase);
            new ObjectAffectedMemory = GetPlayerObjectMemory(ObjectAffected);
        
			CallLocalFunction("OnPlayerClickAction","iiisiiiiiiiiiii",playerid, ObjectAffected, ActionIDs, ActionData[GetActionDataMemory(ActionIDs)][ActionName], ObjectData[ObjectAffectedBaseMem][UsesType],
			ObjectInfo[ObjectAffectedMemory][CurrentUses], ObjectData[ObjectAffectedBaseMem][MaxUses], ObjectData[ObjectAffectedBaseMem][SpecialFlag_1], ObjectData[ObjectAffectedBaseMem][SpecialFlag_2],
			ObjectData[ObjectAffectedBaseMem][SpecialFlag_3], PlayerVar[playerid][ObjectInActionSource], ObjectInfo[ObjectAffectedMemory][P_SpecialFlag_1], ObjectInfo[ObjectAffectedMemory][P_SpecialFlag_2],
			PlayerVar[playerid][MemorySlot][1], PlayerVar[playerid][MemorySlot][0]);
			return 1;
        }
    }

    if(playertextid == Inv[playerid][14])
    {
        HideInventoryBase(playerid);
        CancelSelectTextDraw(playerid);
        DestroyInventoryObjects(playerid);
        DestroyActions(playerid);
        DestroyNearInventoryObjects(playerid);
        
        PlayerVar[playerid][SelectedObjectID] = 0;
        PlayerVar[playerid][SelectedObjectSourceID] = 0;
        PlayerVar[playerid][SelectedContainerID] = 0;
		
	    PlayerVar[playerid][InventoryOpen] = 0;
	    PlayerVar[playerid][ObjectInAction] = 0;
	    PlayerVar[playerid][ObjectInActionGlobal] = 0;
        return 1;
    }
    else if(playertextid == Inv[playerid][13])
    {
        if(PlayerVar[playerid][OnHandWeaponID] != 0)
        {
			OnPlayerRemoveWeaponFromHand(playerid);
        }
        
        if(ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][OnHandWeaponID])][SlotsInside] > 0)
	    {
	        HideOnHandObjectInventory(playerid);
	    }
    
        PlayerTextDrawSetPreviewModel(playerid, Inv[playerid][18], 19300);
        HideOnHandObjectInventory(playerid);
        
		for(new a = 1; a < 10; a ++)
	    {
			if(PlayerVar[playerid][ObjectStoredInIndex][a] != PlayerVar[playerid][OnHandObjectID]) continue;
			RenderPlayerContainer(playerid, PlayerVar[playerid][OnHandObjectID]);
			break;
	    }
	    
	    new OnHand = PlayerVar[playerid][OnHandObjectID];
	    
		PlayerVar[playerid][OnHandObjectID] = 0;
		PlayerVar[playerid][OnHandWeaponID] = 0;
		PlayerVar[playerid][OnHandAmmoObjectID] = 0;
		PlayerVar[playerid][OnHandMagObjectID] = 0;
		
     	RemovePlayerAttachedObject(playerid, 0);
		PlayerTextDrawHide(playerid, Inv[playerid][18]);
		
		if(ObjectInfo[GetPlayerObjectMemory(OnHand)][Status] == 5)
	    {
	        new Float:fPos[3];
	        GetPlayerPos(playerid, fPos[0], fPos[1], fPos[2]);
	        DropObjectOnPosition(playerid, OnHand, fPos[0], fPos[1], fPos[2]);
	    }
		return 1;
    }
    else if(playertextid == Inv[playerid][7])
	{ //Previous Page
		if(PlayerVar[playerid][ContainersListingPage] == 1)
		    return 1;
	        
	    new mindisplay = PlayerVar[playerid][ContainersListingMin];
	    PlayerVar[playerid][ContainersListingMin] = mindisplay - PlayerVar[playerid][ContainersInPages][PlayerVar[playerid][ContainersListingPage]-1];
        PlayerVar[playerid][ContainersListingPage] --;
        
        LoadPlayerContainers(playerid);
        new pagestr[2];
		valstr(pagestr, PlayerVar[playerid][ContainersListingPage]);
		PlayerTextDrawSetString(playerid, Inv[playerid][6], pagestr);
		return 1;
	}
	else if(playertextid == Inv[playerid][20])
	{ //Previous near page
	    if(PlayerVar[playerid][DroppedContainersListingPage]  == 1)
		    return 1;

	    new mindisplay = PlayerVar[playerid][DroppedContainersListingMin];
	    PlayerVar[playerid][DroppedContainersListingMin] = mindisplay - PlayerVar[playerid][DroppedContainersInPages][PlayerVar[playerid][DroppedContainersListingPage]-1];
        PlayerVar[playerid][DroppedContainersListingPage] --;

        LoadPlayerNearContainers(playerid);
        new pagestr[2];
		valstr(pagestr, PlayerVar[playerid][DroppedContainersListingPage]);
		PlayerTextDrawSetString(playerid, Inv[playerid][19], pagestr);
	}
	else if(playertextid == Inv[playerid][21])
	{ //Next near page
        new mindisplay = PlayerVar[playerid][DroppedContainersListingMin];
        PlayerVar[playerid][DroppedContainersListingMin] = mindisplay + PlayerVar[playerid][DroppedContainersInPages][PlayerVar[playerid][DroppedContainersListingPage]];
        PlayerVar[playerid][DroppedContainersListingPage] ++;
        
        LoadPlayerNearContainers(playerid);
        new pagestr[2];
		valstr(pagestr, PlayerVar[playerid][DroppedContainersListingPage]);
		PlayerTextDrawSetString(playerid, Inv[playerid][19], pagestr);
	    return 1;
	}
	else if(playertextid == Inv[playerid][8])
	{ //Next Page
        new mindisplay = PlayerVar[playerid][ContainersListingMin];
        PlayerVar[playerid][ContainersListingMin] = mindisplay + PlayerVar[playerid][ContainersInPages][PlayerVar[playerid][ContainersListingPage]];
        PlayerVar[playerid][ContainersListingPage] ++;
	        
		LoadPlayerContainers(playerid);
		new pagestr[2];
		valstr(pagestr, PlayerVar[playerid][ContainersListingPage]);
		PlayerTextDrawSetString(playerid, Inv[playerid][6], pagestr);
	    return 1;
	}
	else if(playertextid == Inv[playerid][9])
	{
	    if(PlayerVar[playerid][ObjectInAction])
	        OnPlayerClickPlayerTextDraw(playerid, ActionMenu[playerid][3]);
	
		if(PlayerVar[playerid][SelectedContainerID] == 0 && PlayerVar[playerid][SelectedObjectID] == 0)
		{//Clicked player image without a selected object
	        PlayerTextDrawSetPreviewRot(playerid, Inv[playerid][9], 0, 0, PlayerVar[playerid][DisplayingModelRotation]+45.0, 1.0);
    	    PlayerTextDrawShow(playerid, Inv[playerid][9]);
        	PlayerVar[playerid][DisplayingModelRotation] += 45.0;
			return 1;
		}
		else
		{//Clicked player image with a selected object
		    if(ObjectInfo[SelectedObjectMemory][Status] == 1)
		        return 1;
		
		    new type = ObjectData[GetObjectDataMemory(ObjectInfo[SelectedObjectMemory][BaseID])][UsesType];
		    new capacity = ObjectData[GetObjectDataMemory(ObjectInfo[SelectedObjectMemory][BaseID])][SlotsInside];
		
		    if(type == 2)
			    if(PlayerVar[playerid][OnHandObjectID] == PlayerVar[playerid][SelectedObjectID])
			        return 1;

            if(type == 7)
			    if(PlayerVar[playerid][OnHandAmmoObjectID] == PlayerVar[playerid][SelectedObjectID])
			        return 1;

            if(type == 6)
			    if(PlayerVar[playerid][OnHandMagObjectID] == PlayerVar[playerid][SelectedObjectID])
			        return 1;
		
			if(capacity == 0)
			    return 1;
				   
			new ObjectSlotID = ObjectData[GetObjectDataMemory(ObjectInfo[SelectedObjectMemory][BaseID])][UsesSlot];
			new SlotMaxObjects = SlotData[GetSlotDataMemory(ObjectSlotID)][MaxObjects];
			if(ObjectSlotID != 1)
			{
			    if(PlayerVar[playerid][PlayerSlots][ObjectSlotID] == SlotMaxObjects)
			    {
			        if(PlayerVar[playerid][SelectedObjectGlobal] == 1)
			        {
				        if(PutObjectInFirstEmptySlotPla(playerid, PlayerVar[playerid][SelectedObjectID], PlayerVar[playerid][SelectedObjectID], 0, false) == 0)
						{
				        	RenderFormattedMessage(playerid, 0xFF6600FF, "Seems like you can't carry any more %ss there is no room in your inventory for that!", SlotData[GetSlotDataMemory(ObjectSlotID)][SlotName]);
				        }
					}
					else
					{
					    if(SlotMaxObjects != 0)
					    {
				    		RenderFormattedMessage(playerid, 0xFF6600FF, "Seems like you can't carry more %ss!", SlotData[GetSlotDataMemory(ObjectSlotID)][SlotName]);
						}
						else
						{
				    		RenderMessage(playerid, 0xFF6600FF, "There are no slots in your inventory for that kind of object.");
						}
					}
			        return 1;
			    }
			    else
				{
				    PlayerVar[playerid][PlayerSlots][ObjectSlotID] ++;
					mysql_format(dbHandle, query, sizeof query, "UPDATE playerinventories SET `%d` = %d WHERE PlayerName = '%e'", ObjectSlotID, PlayerVar[playerid][PlayerSlots][ObjectSlotID], PlayerName(playerid));
					mysql_tquery(dbHandle, query);
				}
			}
		
		    mysql_format(dbHandle, medquery, sizeof medquery,"UPDATE playerobjects SET Status = 1, PlayerName = '%e', Position = 0, WorldX = '0.0', WorldY = '0.0', WorldZ = '0.0' WHERE PlayerID = %d",PlayerName(playerid), PlayerVar[playerid][SelectedObjectID]);
		    mysql_tquery(dbHandle, medquery, "", "");
		    
		    new PlayerObject = PlayerVar[playerid][SelectedObjectID];
		    new OldStatus = ObjectInfo[SelectedObjectMemory][Status];
		    
		    if(OldStatus == 3)
			{//item was on ground
			    DestroyDynamicObject(ObjectInfo[SelectedObjectMemory][GameObject]);
			   	DestroyDynamicArea(ObjectInfo[SelectedObjectMemory][AreaID]);
			   	ObjectInfo[SelectedObjectMemory][Status] = 1;

			   	for(new a = 0; a < PLAYERS; a ++)
		        {
		            if(!IsPlayerConnected(a)) continue;
					if(ObjectInfo[SelectedObjectMemory][IsNear][a] == 1)
					    ObjectInfo[SelectedObjectMemory][IsNear][a] = 0;

		            if(a == playerid) continue;
					LoadPlayerNearContainers(a);
				}
			}
			if(OldStatus == 2 && PlayerVar[playerid][SelectedObjectGlobal] == 1)
			{
			    RefreshObjectInventoryForNear(PlayerVar[playerid][SelectedObjectSourceID], playerid);
			}
		    
		    ObjectInfo[SelectedObjectMemory][Status] = 1;
		    PlayerVar[playerid][SelectedObjectGlobal] = 0;
			//ObjectInfo[PlayerObject][Position] = 0;
			ObjectInfo[SelectedObjectMemory][WorldX] = 0.0;
			ObjectInfo[SelectedObjectMemory][WorldY] = 0.0;
			ObjectInfo[SelectedObjectMemory][WorldZ] = 0.0;
			format(ObjectInfo[SelectedObjectMemory][OwnerName], 24,  "%s", PlayerName(playerid));
			RenderPlayerContainer(playerid, PlayerVar[playerid][SelectedObjectID]);
			
			if(OldStatus == 2)
                RemoveObjectFromObject(playerid, PlayerObject, PlayerVar[playerid][SelectedObjectSourceID]);
			
			if(PlayerVar[playerid][OverridePosition] != -1)
			{
			    format(query, sizeof(query),"UPDATE playerobjects SET position = %d WHERE PlayerID = %d",  PlayerVar[playerid][OverridePosition], PlayerObject);
			    mysql_tquery(dbHandle, query, "", "");

			    ObjectInfo[SelectedObjectMemory][Position] =  PlayerVar[playerid][OverridePosition];
				PlayerVar[playerid][OverridePosition] = -1;
				
		        PlayerVar[playerid][SelectedObjectID] = 0;
			 	PlayerVar[playerid][SelectedContainerID] = 0;
			 	PlayerVar[playerid][SelectedObjectSourceID] = 0;
		        LoadPlayerContainers(playerid);
			}
			else
			{
	    		mysql_format(dbHandle, medquery, sizeof medquery,"SELECT MAX(position) FROM playerobjects WHERE PlayerName = '%e' AND Status = 1", PlayerName(playerid));
				mysql_tquery(dbHandle, medquery, "UpdateObjectLastPosition", "ii", playerid, PlayerVar[playerid][SelectedObjectID]);
			}
			LoadPlayerNearContainers(playerid);
			OnPlayerEquipContainer(playerid, PlayerObject);
			return 1;
		
		}
	}
	
	for(new i = 0; i < MAX_CONTAINERS_PER_PAGE; i ++)
	{
	    if(playertextid == InventoryObjectsHead[playerid][0][i])
	    {
	        if(PlayerVar[playerid][LastClickedObjectTick] > GetTickCount() && PlayerVar[playerid][LastClickedObjectID] == PlayerVar[playerid][ContainerStoredInSlot][i])
	        {
	            if(PlayerVar[playerid][ObjectInAction] != 0)
					return 1;
	        
	            if(PlayerVar[playerid][SelectedObjectID] != 0 && PlayerVar[playerid][SelectedObjectID] != PlayerVar[playerid][ContainerStoredInSlot][i])
	                return 1;
	        
	            PlayerVar[playerid][LastClickedObjectTick] = GetTickCount()-500;
	            PlayerVar[playerid][LastClickedObjectID] = PlayerVar[playerid][ContainerStoredInSlot][i];
	            OnPlayerClickPlayerTextDraw(playerid, playertextid);
				OnPlayerRequestActionList(playerid, PlayerVar[playerid][ContainerStoredInSlot][i], i, ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][ContainerStoredInSlot][i])][UsesType], PlayerVar[playerid][ContainerStoredInSlot][i], false);
	            PlayerVar[playerid][MemorySlot][0] = i;
	            PlayerVar[playerid][MemorySlot][1] = 0;
	            PlayerVar[playerid][ObjectInActionGlobal] = 0;
	            PlayerVar[playerid][ObjectInAction] = PlayerVar[playerid][ContainerStoredInSlot][i];

				if(PlayerVar[playerid][SelectedObjectID] == PlayerVar[playerid][ObjectInAction])
				{
				    PlayerVar[playerid][SelectedObjectID] = 0;
			        PlayerVar[playerid][SelectedObjectSourceID] = 0;
			        PlayerVar[playerid][SelectedContainerID] = 0;

			        PlayerTextDrawHide(playerid, InventoryObjectsHead[playerid][0][i]);
		            PlayerTextDrawBoxColor(playerid, InventoryObjectsHead[playerid][0][i], 0x00000044);
	          	  	PlayerTextDrawShow(playerid, InventoryObjectsHead[playerid][0][i]);
				}

	            return 1;
	        }
	        if(PlayerVar[playerid][ObjectInAction] != 0)
	            return 1;
	        
	        PlayerVar[playerid][LastClickedObjectTick] = GetTickCount()+300;
	        PlayerVar[playerid][LastClickedObjectID] = PlayerVar[playerid][ContainerStoredInSlot][i];
	        
			if(PlayerVar[playerid][SelectedObjectID] == 0)
			{
			    PlayerVar[playerid][SelectedObjectID] = PlayerVar[playerid][ContainerStoredInSlot][i];
			    PlayerVar[playerid][SelectedObjectSourceID] = PlayerVar[playerid][ContainerStoredInSlot][i];
			    PlayerVar[playerid][SelectedContainerID] = PlayerVar[playerid][ContainerStoredInSlot][i];
		        PlayerVar[playerid][SelectedObjectGlobal] = 0;

		        PlayerTextDrawHide(playerid, InventoryObjectsHead[playerid][0][i]);
	            PlayerTextDrawBoxColor(playerid, InventoryObjectsHead[playerid][0][i], 0xFF660044);
	            PlayerTextDrawShow(playerid, InventoryObjectsHead[playerid][0][i]);
			}
			else
			{
			    if(PlayerVar[playerid][SelectedObjectID] == PlayerVar[playerid][ContainerStoredInSlot][i])
			    {//Deselect container
			        PlayerVar[playerid][SelectedObjectID] = 0;
			        PlayerVar[playerid][SelectedObjectSourceID] = 0;
			        PlayerVar[playerid][SelectedContainerID] = 0;
			    
			        PlayerTextDrawHide(playerid, InventoryObjectsHead[playerid][0][i]);
		            PlayerTextDrawBoxColor(playerid, InventoryObjectsHead[playerid][0][i], 0x00000044);
	          	  	PlayerTextDrawShow(playerid, InventoryObjectsHead[playerid][0][i]);
			    }
			    else
			    {//Add object to container
			        if(PlayerVar[playerid][SelectedContainerID] != 0 &&
					((PlayerVar[playerid][SelectedObjectGlobal] == 1 &&
					ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][ContainerStoredInSlot][i])][UsesSlot] ==
					ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][SelectedObjectID])][UsesSlot]) ||
					PlayerVar[playerid][SelectedObjectGlobal] == 0))
			        {//Is the Selected Object a container?, offer to add into or SWAP
				        if(PlayerVar[playerid][ActionSwapStep] == 0)
						{
					    	PlayerVar[playerid][ActionSwapStep] = 1;
					    	PlayerVar[playerid][MemorySlot][0] = i;
				            PlayerVar[playerid][MemorySlot][1] = 0;
                            OnPlayerRequestActionList(playerid, PlayerVar[playerid][ContainerStoredInSlot][i], i, -3, PlayerVar[playerid][ContainerStoredInSlot][i], false);
						}
			        }
			        else
			        {//If not just attempt to add the object inside
			            if(PlayerVar[playerid][SelectedObjectSourceID] == PlayerVar[playerid][ContainerStoredInSlot][i])
			                return 1;
			        
				        new SelectedObjectBaseID = GetObjectBaseID(PlayerVar[playerid][SelectedObjectID]);
				        new SourceBase = GetObjectBaseID(PlayerVar[playerid][SelectedObjectSourceID]);
				        new DestBase = GetObjectBaseID(PlayerVar[playerid][ContainerStoredInSlot][i]);

				        MoveObjectToObject(playerid, -2, PlayerVar[playerid][SelectedObjectID], ObjectData[GetObjectDataMemory(SelectedObjectBaseID)][UsesType],
						PlayerVar[playerid][SelectedObjectSourceID], ObjectData[GetObjectDataMemory(SourceBase)][UsesType], PlayerVar[playerid][ContainerStoredInSlot][i],
						ObjectData[GetObjectDataMemory(DestBase)][UsesType], playerid, PlayerName(playerid));
					}
				}
			}
			return 1;
	    }
	    else if(playertextid == GlobalObjectsHead[playerid][0][i])
	    {
	        if(PlayerVar[playerid][LastClickedObjectTick] > GetTickCount() && PlayerVar[playerid][LastClickedObjectID] == PlayerVar[playerid][DroppedContainerStoredInSlot][i])
	        {
	            if(PlayerVar[playerid][ObjectInAction] != 0)
					return 1;

	            if(PlayerVar[playerid][SelectedObjectID] != 0 && PlayerVar[playerid][SelectedObjectID] != PlayerVar[playerid][DroppedContainerStoredInSlot][i])
	                return 1;

	            PlayerVar[playerid][LastClickedObjectTick] = GetTickCount()-500;
	            PlayerVar[playerid][LastClickedObjectID] = PlayerVar[playerid][DroppedContainerStoredInSlot][i];
	            
	            if(ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][DroppedContainerStoredInSlot][i])][SlotsInside] != 0)
					OnPlayerClickPlayerTextDraw(playerid, Inv[playerid][9]);
				else
				    if(PutObjectInFirstEmptySlotPla(playerid, PlayerVar[playerid][DroppedContainerStoredInSlot][i], PlayerVar[playerid][DroppedContainerStoredInSlot][i], 0, false) == 0)
						    return RenderMessage(playerid, 0xFF6600FF, "There's no room anywhere in your inventory for that object.");
						    
	            return 1;
	        }
	        if(PlayerVar[playerid][ObjectInAction] != 0)
	            return 1;

	        PlayerVar[playerid][LastClickedObjectTick] = GetTickCount()+300;
	        PlayerVar[playerid][LastClickedObjectID] = PlayerVar[playerid][DroppedContainerStoredInSlot][i];
	    
	        if(PlayerVar[playerid][SelectedObjectID] == 0)
			{
			    PlayerVar[playerid][SelectedObjectID] = PlayerVar[playerid][DroppedContainerStoredInSlot][i];
			    PlayerVar[playerid][SelectedObjectSourceID] = PlayerVar[playerid][DroppedContainerStoredInSlot][i];
			    PlayerVar[playerid][SelectedContainerID] = PlayerVar[playerid][DroppedContainerStoredInSlot][i];
			    PlayerVar[playerid][SelectedObjectGlobal] = 1;

		        PlayerTextDrawHide(playerid, GlobalObjectsHead[playerid][0][i]);
	            PlayerTextDrawBoxColor(playerid, GlobalObjectsHead[playerid][0][i], 0xFF660044);
	            PlayerTextDrawShow(playerid, GlobalObjectsHead[playerid][0][i]);
			}
			else
			{
			    if(PlayerVar[playerid][SelectedObjectID] == PlayerVar[playerid][DroppedContainerStoredInSlot][i])
			    {
			        PlayerVar[playerid][SelectedObjectID] = 0;
					PlayerVar[playerid][SelectedObjectSourceID] = 0;
					PlayerVar[playerid][SelectedContainerID] = 0;
					PlayerVar[playerid][SelectedObjectGlobal] = 0;

			        PlayerTextDrawHide(playerid, GlobalObjectsHead[playerid][0][i]);
		            PlayerTextDrawBoxColor(playerid, GlobalObjectsHead[playerid][0][i], 0x00000044);
	          	  	PlayerTextDrawShow(playerid, GlobalObjectsHead[playerid][0][i]);
			    }
			    else
			    {//Add object to container
			        if(PlayerVar[playerid][SelectedContainerID] != 0 &&
					(PlayerVar[playerid][SelectedObjectGlobal] == 0 &&
					ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][DroppedContainerStoredInSlot][i])][UsesSlot] ==
					ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][SelectedObjectID])][UsesSlot]))
			        {//Is the Selected Object a container?, offer to add into or SWAP
				        if(PlayerVar[playerid][ActionSwapStep] == 0)
						{
					    	PlayerVar[playerid][ActionSwapStep] = 1;
					    	PlayerVar[playerid][MemorySlot][0] = i;
				            PlayerVar[playerid][MemorySlot][1] = 0;
                            OnPlayerRequestActionList(playerid, PlayerVar[playerid][DroppedContainerStoredInSlot][i], i, -3, PlayerVar[playerid][DroppedContainerStoredInSlot][i], true);
						}
			        }
			        else
			        {//If not just attempt to add the object inside
			            if(PlayerVar[playerid][DroppedContainerStoredInSlot][i] == PlayerVar[playerid][SelectedObjectSourceID])
			                return 1;

				        new SelectedObjectBaseID = GetObjectBaseID(PlayerVar[playerid][SelectedObjectID]);
				        new SourceBase = GetObjectBaseID(PlayerVar[playerid][SelectedObjectSourceID]);
				        new DestBase = GetObjectBaseID(PlayerVar[playerid][DroppedContainerStoredInSlot][i]);

				        MoveObjectToObject(playerid, -2, PlayerVar[playerid][SelectedObjectID], ObjectData[GetObjectDataMemory(SelectedObjectBaseID)][UsesType],
						PlayerVar[playerid][SelectedObjectSourceID], ObjectData[GetObjectDataMemory(SourceBase)][UsesType], PlayerVar[playerid][DroppedContainerStoredInSlot][i],
						ObjectData[GetObjectDataMemory(DestBase)][UsesType], playerid, PlayerName(playerid));
					}
				}
			}
	        return 1;
	    }
	}
	
	for(new i = 0; i < sizeof(GlobalObjectsSlots[]); i ++)
	{
	    for(new a = 0; a < sizeof(GlobalObjectsSlots[][]); a ++)
	    {
			if(playertextid == GlobalObjectsSlots[playerid][i][a])
			{
			    if(PlayerVar[playerid][ObjectInAction])
	        		OnPlayerClickPlayerTextDraw(playerid, ActionMenu[playerid][3]);
			
			    if(ObjectStoredInDroppedContainer[playerid][i][a] == 0)
			    {//empty slot found
			        if(PlayerVar[playerid][SelectedObjectID] != 0)
			        {//move object check
			        
						//new ContainerBaseID = GetObjectBaseID(PlayerVar[playerid][DroppedContainerStoredInSlot][a]);
						//new ObjectBaseID = GetObjectBaseID(PlayerVar[playerid][SelectedObjectID]);
						
                        /*if(CheckIfObjectFitsInObject(PlayerVar[playerid][SelectedObjectID], PlayerVar[playerid][DroppedContainerStoredInSlot][a], i) == 0)
						    return RenderMessage(playerid, 0xFF6600FF, "The object wont fit in there.");*/
						
						if(PlayerVar[playerid][SelectedContainerID] == PlayerVar[playerid][DroppedContainerStoredInSlot][a])
						    return RenderMessage(playerid, 0xFF0000FF, "Can't put a container inside itself.");
						
						new PlayerObjectID = PlayerVar[playerid][SelectedObjectID];
						new SourceContainer = PlayerVar[playerid][SelectedObjectSourceID];
						
						MoveObjectToObject(playerid, i, PlayerObjectID, ObjectData[GetPlayerObjectDataMemory(PlayerObjectID)][UsesType],
						SourceContainer, ObjectData[GetPlayerObjectDataMemory(SourceContainer)][UsesType], PlayerVar[playerid][DroppedContainerStoredInSlot][a],
						ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][DroppedContainerStoredInSlot][a])][UsesType], playerid, PlayerName(playerid));
						return 1;
			        }
					return 1;
				}
				else if(ObjectStoredInDroppedContainer[playerid][i][a] == 0)
				{
					return 1;
				}
				else
				{
				    if(PlayerVar[playerid][LastClickedObjectTick] > GetTickCount() && PlayerVar[playerid][LastClickedObjectID] == ObjectStoredInDroppedContainer[playerid][i][a])
			        {
			            if(ObjectData[GetPlayerObjectDataMemory(ObjectStoredInDroppedContainer[playerid][i][a])][Size] == 0)
				        	return 1;

						if(PlayerVar[playerid][ObjectInAction] != 0)
						    return 1;

                        if(PlayerVar[playerid][SelectedObjectID] != 0 && PlayerVar[playerid][SelectedObjectID] != ObjectStoredInDroppedContainer[playerid][i][a])
	                		return 1;

						if(PutObjectInFirstEmptySlotPla(playerid, ObjectStoredInDroppedContainer[playerid][i][a], PlayerVar[playerid][DroppedContainerStoredInSlot][a], 0, false) == 0)
						    return RenderMessage(playerid, 0xFF6600FF, "There's no room anywhere in your inventory for that object.");

                        PlayerVar[playerid][LastClickedObjectID] = ObjectStoredInDroppedContainer[playerid][i][a];

			            return 1;
			        }
			        if(PlayerVar[playerid][ObjectInAction] != 0)
	            		return 1;

			       	PlayerVar[playerid][LastClickedObjectTick] = GetTickCount()+300;
			       	PlayerVar[playerid][LastClickedObjectID] = ObjectStoredInDroppedContainer[playerid][i][a];
				
				    if(PlayerVar[playerid][SelectedObjectID] == 0)
				    {
				        new size = ObjectData[GetPlayerObjectDataMemory(ObjectStoredInDroppedContainer[playerid][i][a])][Size];

				        if(size == 0)
				        	return 1;
				        	
                        PlayerVar[playerid][SelectedObjectID] = ObjectStoredInDroppedContainer[playerid][i][a];
						PlayerVar[playerid][SelectedObjectSourceID] = PlayerVar[playerid][DroppedContainerStoredInSlot][a];
						PlayerVar[playerid][SelectedContainerID] = 0;
						PlayerVar[playerid][SelectedObjectGlobal] = 1;

					    PlayerTextDrawHide(playerid, GlobalObjectsSlots[playerid][i][a]);
                        PlayerTextDrawBackgroundColor(playerid, GlobalObjectsSlots[playerid][i][a], 0xFF660066);
                        PlayerTextDrawShow(playerid, GlobalObjectsSlots[playerid][i][a]);

                        for(new z = i; z < i+size; z ++)
                        {
                            PlayerTextDrawHide(playerid, GlobalObjectsSlots[playerid][z][a]);
	                        PlayerTextDrawBackgroundColor(playerid, GlobalObjectsSlots[playerid][z][a], 0xFF660066);
	                        PlayerTextDrawShow(playerid, GlobalObjectsSlots[playerid][z][a]);
                        }
				        return 1;
					}
					else
					{
					    if(PlayerVar[playerid][SelectedObjectID] == ObjectStoredInDroppedContainer[playerid][i][a])
					    {
					        new size = ObjectData[GetPlayerObjectDataMemory(ObjectStoredInDroppedContainer[playerid][i][a])][Size];

					        if(size == 0)
					        	return 1;

					        for(new z = i; z < i+size; z ++)
	                        {
	                            PlayerTextDrawHide(playerid, GlobalObjectsSlots[playerid][z][a]);
		                        PlayerTextDrawBackgroundColor(playerid, GlobalObjectsSlots[playerid][z][a], 0x00000066);
		                        PlayerTextDrawShow(playerid, GlobalObjectsSlots[playerid][z][a]);
	                        }

                            PlayerVar[playerid][SelectedObjectID] = 0;
							PlayerVar[playerid][SelectedObjectSourceID] = 0;
							PlayerVar[playerid][SelectedContainerID] = 0;

					    	PlayerTextDrawHide(playerid, GlobalObjectsSlots[playerid][i][a]);
					    	PlayerTextDrawBackgroundColor(playerid, GlobalObjectsSlots[playerid][i][a], 0x00000066);
                        	PlayerTextDrawShow(playerid, GlobalObjectsSlots[playerid][i][a]);

				        	return 1;
					    }
					    else
					    {
					        new SecondObjectSize = ObjectData[GetPlayerObjectDataMemory(ObjectStoredInDroppedContainer[playerid][i][a])][Size];
					        new SelectedObjectPosition = ObjectInfo[SelectedObjectMemory][Position];
					        
							if(PlayerVar[playerid][DroppedContainerStoredInSlot][a] != PlayerVar[playerid][SelectedObjectSourceID] && SecondObjectSize != 0 && PlayerVar[playerid][SelectedContainerID] == 0)
							{//one object from one to another container
							    if(PlayerVar[playerid][ObjectInAction])
	        						OnPlayerClickPlayerTextDraw(playerid, ActionMenu[playerid][3]);
	        						
							    SwapObjectWithObject(playerid, PlayerVar[playerid][SelectedObjectSourceID],PlayerVar[playerid][DroppedContainerStoredInSlot][a],PlayerVar[playerid][SelectedObjectID],
							    ObjectStoredInDroppedContainer[playerid][i][a],ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][SelectedObjectID])][UsesType],ObjectData[GetPlayerObjectDataMemory(ObjectStoredInDroppedContainer[playerid][i][a])][UsesType],
							    ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][DroppedContainerStoredInSlot][a])][UsesType],ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][SelectedObjectSourceID])][UsesType],SelectedObjectPosition,i,-1);
								return 1;
							}
							else if(PlayerVar[playerid][SelectedObjectSourceID] == PlayerVar[playerid][DroppedContainerStoredInSlot][a] && SecondObjectSize != 0 && PlayerVar[playerid][SelectedContainerID] == 0)
							{
							    if(PlayerVar[playerid][ObjectInAction])
	        						OnPlayerClickPlayerTextDraw(playerid, ActionMenu[playerid][3]);
							
                                InternalSwapObject(playerid, PlayerVar[playerid][SelectedObjectSourceID], PlayerVar[playerid][SelectedObjectID], ObjectStoredInDroppedContainer[playerid][i][a],
								ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][SelectedObjectID])][UsesType], ObjectData[GetPlayerObjectDataMemory(ObjectStoredInDroppedContainer[playerid][i][a])][UsesType],
								ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][DroppedContainerStoredInSlot][a])][UsesType], ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][SelectedObjectSourceID])][UsesType],
								SelectedObjectPosition, i, a);
								return 1;
							}
					    }
					}
					return 1;
				}
			}
		}
	}

 	for(new i = 0; i < sizeof(InventoryObjectsSlots[]); i ++)
	{
	    for(new a = 0; a < sizeof(InventoryObjectsSlots[][]); a ++)
	    {
			if(playertextid == InventoryObjectsSlots[playerid][i][a])
			{
       			if(ObjectStoredInContainer[playerid][i][a] == 0)
			    {//empty slot found
			        if(PlayerVar[playerid][SelectedObjectID] != 0)
			        {//move object check
			         	if(PlayerVar[playerid][ObjectInAction])
	        				OnPlayerClickPlayerTextDraw(playerid, ActionMenu[playerid][3]);

						//new ContainerBaseID = GetObjectBaseID(PlayerVar[playerid][ContainerStoredInSlot][a]);
						//new ObjectBaseID = GetObjectBaseID(PlayerVar[playerid][SelectedObjectID]);

						/*if(CheckIfObjectFitsInObject(PlayerVar[playerid][SelectedObjectID], PlayerVar[playerid][ContainerStoredInSlot][a], i) == 0)
						    return RenderMessage(playerid, 0xFF6600FF, "The object wont fit in there.");*/

						if(PlayerVar[playerid][SelectedContainerID] == PlayerVar[playerid][ContainerStoredInSlot][a])
						    return RenderMessage(playerid, 0xFF0000FF, "Can't put a container inside itself.");

						new PlayerObjectID = PlayerVar[playerid][SelectedObjectID];
						new SourceContainer = PlayerVar[playerid][SelectedObjectSourceID];

						MoveObjectToObject(playerid, i, PlayerObjectID, ObjectData[GetPlayerObjectDataMemory(PlayerObjectID)][UsesType], SourceContainer, ObjectData[GetPlayerObjectDataMemory(SourceContainer)][UsesType],
						PlayerVar[playerid][ContainerStoredInSlot][a], ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][ContainerStoredInSlot][a])][UsesType], playerid, PlayerName(playerid));
						return 1;
			        }
					return 1;
				}
				else if(ObjectStoredInContainer[playerid][i][a] == 0)
				{
					return 1;
				}
				else
				{
				    if(PlayerVar[playerid][LastClickedObjectTick] > GetTickCount() && PlayerVar[playerid][LastClickedObjectID] == ObjectStoredInContainer[playerid][i][a])
			        {
			            if(ObjectData[GetPlayerObjectDataMemory(ObjectStoredInContainer[playerid][i][a])][Size] == 0)
				        	return 1;

						if(PlayerVar[playerid][ObjectInAction] != 0)
						    return 1;
						    
                        if(PlayerVar[playerid][SelectedObjectID] != 0 && PlayerVar[playerid][SelectedObjectID] != ObjectStoredInContainer[playerid][i][a])
	                		return 1;

			            PlayerVar[playerid][MemorySlot][0] = a;
			            PlayerVar[playerid][MemorySlot][1] = i;
						OnPlayerRequestActionList(playerid, ObjectStoredInContainer[playerid][i][a], a, ObjectData[GetPlayerObjectDataMemory(ObjectStoredInContainer[playerid][i][a])][UsesType], PlayerVar[playerid][ContainerStoredInSlot][a], false);
			           	PlayerVar[playerid][LastClickedObjectTick] = GetTickCount()-500;
			           	PlayerVar[playerid][LastClickedObjectID] = ObjectStoredInContainer[playerid][i][a];
			            OnPlayerClickPlayerTextDraw(playerid, playertextid);
			            PlayerVar[playerid][ObjectInAction] = ObjectStoredInContainer[playerid][i][a];
			            
			            if(PlayerVar[playerid][SelectedObjectID] == PlayerVar[playerid][ObjectInAction])
			            {
			            	for(new z = i; z < i+ObjectData[GetPlayerObjectDataMemory(ObjectStoredInContainer[playerid][i][a])][Size]; z ++)
	                        {
	                            PlayerTextDrawHide(playerid, InventoryObjectsSlots[playerid][z][a]);
		                        PlayerTextDrawBackgroundColor(playerid, InventoryObjectsSlots[playerid][z][a], 0x00000066);
		                        PlayerTextDrawShow(playerid, InventoryObjectsSlots[playerid][z][a]);
	                        }

                            PlayerVar[playerid][SelectedObjectID] = 0;
							PlayerVar[playerid][SelectedObjectSourceID] = 0;
							PlayerVar[playerid][SelectedContainerID] = 0;

					    	PlayerTextDrawHide(playerid, InventoryObjectsSlots[playerid][i][a]);
					    	PlayerTextDrawBackgroundColor(playerid, InventoryObjectsSlots[playerid][i][a], 0x00000066);
                        	PlayerTextDrawShow(playerid, InventoryObjectsSlots[playerid][i][a]);
						}
			            return 1;
			        }
			        if(PlayerVar[playerid][ObjectInAction] != 0)
	            		return 1;

			       	PlayerVar[playerid][LastClickedObjectTick] = GetTickCount()+300;
			       	PlayerVar[playerid][LastClickedObjectID] = ObjectStoredInContainer[playerid][i][a];

				    if(PlayerVar[playerid][SelectedObjectID] == 0)
				    {
				        if(ObjectData[GetPlayerObjectDataMemory(ObjectStoredInContainer[playerid][i][a])][Size] == 0)
				        	return 1;
				        	
                        PlayerVar[playerid][SelectedObjectID] = ObjectStoredInContainer[playerid][i][a];
						PlayerVar[playerid][SelectedObjectSourceID] = PlayerVar[playerid][ContainerStoredInSlot][a];
						PlayerVar[playerid][SelectedContainerID] = 0;
						PlayerVar[playerid][SelectedObjectGlobal] = 0;

					    PlayerTextDrawHide(playerid, InventoryObjectsSlots[playerid][i][a]);
                        PlayerTextDrawBackgroundColor(playerid, InventoryObjectsSlots[playerid][i][a], 0xFF660066);
                        PlayerTextDrawShow(playerid, InventoryObjectsSlots[playerid][i][a]);

                        for(new z = i; z < i+ObjectData[GetPlayerObjectDataMemory(ObjectStoredInContainer[playerid][i][a])][Size]; z ++)
                        {
                            PlayerTextDrawHide(playerid, InventoryObjectsSlots[playerid][z][a]);
	                        PlayerTextDrawBackgroundColor(playerid, InventoryObjectsSlots[playerid][z][a], 0xFF660066);
	                        PlayerTextDrawShow(playerid, InventoryObjectsSlots[playerid][z][a]);
						}

				        return 1;
					}
					else
					{
					    if(PlayerVar[playerid][SelectedObjectID] == ObjectStoredInContainer[playerid][i][a])
					    {
							new size = ObjectData[GetPlayerObjectDataMemory(ObjectStoredInContainer[playerid][i][a])][Size];
					    
					        if(size == 0)
				        		return 1;

					        for(new z = i; z < i+size; z ++)
	                        {
	                            PlayerTextDrawHide(playerid, InventoryObjectsSlots[playerid][z][a]);
		                        PlayerTextDrawBackgroundColor(playerid, InventoryObjectsSlots[playerid][z][a], 0x00000066);
		                        PlayerTextDrawShow(playerid, InventoryObjectsSlots[playerid][z][a]);
	                        }

                            PlayerVar[playerid][SelectedObjectID] = 0;
							PlayerVar[playerid][SelectedObjectSourceID] = 0;
							PlayerVar[playerid][SelectedContainerID] = 0;

					    	PlayerTextDrawHide(playerid, InventoryObjectsSlots[playerid][i][a]);
					    	PlayerTextDrawBackgroundColor(playerid, InventoryObjectsSlots[playerid][i][a], 0x00000066);
                        	PlayerTextDrawShow(playerid, InventoryObjectsSlots[playerid][i][a]);
				        	return 1;
					    }
					    else
					    {
					        new SecondObjectSize = ObjectData[GetPlayerObjectDataMemory(ObjectStoredInContainer[playerid][i][a])][Size];
					        new SelectedObjectPosition = ObjectInfo[SelectedObjectMemory][Position];
					        
							if(PlayerVar[playerid][ContainerStoredInSlot][a] != PlayerVar[playerid][SelectedObjectSourceID] && SecondObjectSize != 0 && PlayerVar[playerid][SelectedContainerID] == 0)
							{//one object from one to another pack
							    if(PlayerVar[playerid][ObjectInAction])
	        						OnPlayerClickPlayerTextDraw(playerid, ActionMenu[playerid][3]);
	        						
							    SwapObjectWithObject(playerid, PlayerVar[playerid][SelectedObjectSourceID],PlayerVar[playerid][ContainerStoredInSlot][a],PlayerVar[playerid][SelectedObjectID],
							    ObjectStoredInContainer[playerid][i][a],ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][SelectedObjectID])][UsesType],ObjectData[GetPlayerObjectDataMemory(ObjectStoredInContainer[playerid][i][a])][UsesType],
							    ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][ContainerStoredInSlot][a])][UsesType],ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][SelectedObjectSourceID])][UsesType],SelectedObjectPosition,i,-1);
								return 1;
							}
                            else if(PlayerVar[playerid][SelectedObjectSourceID] == PlayerVar[playerid][ContainerStoredInSlot][a] && SecondObjectSize != 0 && PlayerVar[playerid][SelectedContainerID] == 0)
							{
							    if(PlayerVar[playerid][ObjectInAction])
	        						OnPlayerClickPlayerTextDraw(playerid, ActionMenu[playerid][3]);
	        						
                                InternalSwapObject(playerid, PlayerVar[playerid][SelectedObjectSourceID], PlayerVar[playerid][SelectedObjectID], ObjectStoredInContainer[playerid][i][a],
								ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][SelectedObjectID])][UsesType], ObjectData[GetPlayerObjectDataMemory(ObjectStoredInContainer[playerid][i][a])][UsesType],
								ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][ContainerStoredInSlot][a])][UsesType], ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][SelectedObjectSourceID])][UsesType],
								SelectedObjectPosition, i, a);
								return 1;
							}
					    }
					}
					return 1;
				}
			}
		}
	}

	if(playertextid == Inv[playerid][11])
	{
		if(PlayerVar[playerid][SelectedObjectID] != 0)
		{
			if(PlayerVar[playerid][OnHandObjectID] != 0)
			    return 1;
			    
			if(PlayerVar[playerid][ObjectInAction])
	        	OnPlayerClickPlayerTextDraw(playerid, ActionMenu[playerid][3]);
			    
			if(PlayerVar[playerid][SelectedObjectGlobal] == 1)
			{
			    if(ObjectInfo[SelectedObjectMemory][Status] == 3)
			    {
			        RemoveObjectFromNearPlayers(PlayerVar[playerid][SelectedObjectID]);
			        DestroyDynamicObject(ObjectInfo[SelectedObjectMemory][GameObject]);
	        		DestroyDynamicArea(ObjectInfo[SelectedObjectMemory][AreaID]);
			    }
			    else if(ObjectInfo[SelectedObjectMemory][Status] == 2)
			    {
			        RemoveObjectFromObject(playerid, PlayerVar[playerid][SelectedObjectID], PlayerVar[playerid][SelectedObjectSourceID]);
			    }
			    ObjectInfo[SelectedObjectMemory][Status] = 5;
			}
		    CallLocalFunction("OnPlayerPutObjectInHand", "iii", playerid, PlayerVar[playerid][SelectedObjectID], ObjectData[GetPlayerObjectDataMemory(PlayerVar[playerid][SelectedObjectID])][UsesType]);
		}
	
	    return 1;
	}
	else if(playertextid == Inv[playerid][17])
	{
	    if(PlayerVar[playerid][ObjectInAction])
	   		OnPlayerClickPlayerTextDraw(playerid, ActionMenu[playerid][3]);
	
	    if(PlayerVar[playerid][SelectedObjectID] != 0)
	    {
	        new PlayerObject = PlayerVar[playerid][SelectedObjectID];
	        new source = PlayerVar[playerid][SelectedObjectSourceID];
	        new type = ObjectData[GetPlayerObjectDataMemory(PlayerObject)][UsesType];

			if(PlayerVar[playerid][SelectedContainerID] != 0)
			    source = -1;
			    
			if(source == -1 && ObjectInfo[SelectedObjectMemory][Status] == 3)
			    return 1;

			if(PlayerVar[playerid][OnHandObjectID] == PlayerVar[playerid][SelectedObjectID])
				OnPlayerClickPlayerTextDraw(playerid, Inv[playerid][13]);

			DropObject(playerid, PlayerVar[playerid][SelectedObjectID], type, source);
		}
	    return 1;
	}
    //SendClientMessage(playerid, 0xFF0000FF, "Clicked!");
	return 0;
}

forward UnrenderPlayerContainer(playerid, ObjectID);
public UnrenderPlayerContainer(playerid, ObjectID)
{
    new ObjectBaseID = GetObjectBaseID(ObjectID);
    if(floatround(ObjectData[GetObjectDataMemory(ObjectBaseID)][OnBodyOffsets][0]) == 0)
	    return 1;

    new useindex;
	for(new i = 1; i < 10; i ++)
	{
	    if(PlayerVar[playerid][ObjectStoredInIndex][i] != ObjectID) continue;
	    useindex = i;
	    break;
	}
	if(useindex == 0) return 1;
	
	PlayerVar[playerid][ObjectStoredInIndex][useindex] = 0;
	RemovePlayerAttachedObject(playerid, useindex);
	return 1;
}

forward RenderPlayerContainer(playerid, ObjectID);
public RenderPlayerContainer(playerid, ObjectID)
{
	new ObjectBaseID = GetObjectBaseID(ObjectID);
	new ObjectBaseMem = GetObjectDataMemory(ObjectBaseID);
	
	if(floatround(ObjectData[ObjectBaseMem][OnBodyOffsets][0]) == 0)
	    return 1;

	new useindex;
	for(new i = 1; i < 10; i ++)
	{
	    if(PlayerVar[playerid][ObjectStoredInIndex][i] != 0 && PlayerVar[playerid][ObjectStoredInIndex][i] != ObjectID) continue;
	    useindex = i;
	    break;
	}
	if(useindex == 0) return 0;
	
	PlayerVar[playerid][ObjectStoredInIndex][useindex] = ObjectID;
	
	SetPlayerAttachedObject(playerid, useindex, ObjectData[ObjectBaseMem][Display],
	floatround(ObjectData[ObjectBaseMem][OnBodyOffsets][0]),ObjectData[ObjectBaseMem][OnBodyOffsets][1],
	ObjectData[ObjectBaseMem][OnBodyOffsets][2], ObjectData[ObjectBaseMem][OnBodyOffsets][3],
	ObjectData[ObjectBaseMem][OnBodyOffsets][4], ObjectData[ObjectBaseMem][OnBodyOffsets][5],
	ObjectData[ObjectBaseMem][OnBodyOffsets][6], ObjectData[ObjectBaseMem][ObjectScales][0],
	ObjectData[ObjectBaseMem][ObjectScales][1], ObjectData[ObjectBaseMem][ObjectScales][2],
	RGBAToARGB(ObjectData[ObjectBaseMem][DisplayColor]), RGBAToARGB(ObjectData[ObjectBaseMem][DisplayColor]));
	return useindex;
}


public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	if(PRESSED(KEY_CTRL_BACK))
	    return cmd_inventory(playerid, "");

	return 1;
}

public OnPlayerEnterDynamicArea(playerid, areaid)
{
	for(new i = 0; i <= LastObjectInfoIndexUsed; i ++)
	{
	    if(ObjectInfo[i][PlayerID] == 0) continue;
	
	    if(areaid == ObjectInfo[i][AreaID])
	    {
	        ObjectInfo[i][IsNear][playerid] = 1;
	    }
	}
	return 1;
}

public OnPlayerLeaveDynamicArea(playerid, areaid)
{
	for(new i = 0; i <= LastObjectInfoIndexUsed; i ++)
	{
	    if(ObjectInfo[i][PlayerID] == 0) continue;

	    if(areaid == ObjectInfo[i][AreaID])
	    {
	        ObjectInfo[i][IsNear][playerid] = 0;
	    }
	}
	return 1;
}

forward OnPlayerEquipContainer(playerid, ObjectID);
public OnPlayerEquipContainer(playerid, ObjectID)
{
	new ObjectBaseID = GetObjectBaseID(ObjectID);
	new ObjectType = ObjectData[GetObjectDataMemory(ObjectBaseID)][UsesType];
	
	if(ObjectType == 3) //Body armor just equipped
	{
	    PlayerVar[playerid][WearingArmor] = ObjectID;
	    SetPlayerArmour(playerid, ObjectInfo[GetPlayerObjectMemory(ObjectID)][CurrentUses]);
	}


	return 1;
}

forward OnPlayerUnEquipContainer(playerid, ObjectID);
public OnPlayerUnEquipContainer(playerid, ObjectID)
{
	new ObjectBaseID = GetObjectBaseID(ObjectID);
	new ObjectType = ObjectData[GetObjectDataMemory(ObjectBaseID)][UsesType];

	if(ObjectType == 3) //Body armor just unequipped
	{
	    if(PlayerVar[playerid][WearingArmor] == ObjectID)
	    {
			PlayerVar[playerid][WearingArmor] = 0;
	    	SetPlayerArmour(playerid, 0);
		}
	}

	return 1;
}

stock RefreshObjectInventoryForNear(ObjectID, Exclude = INVALID_PLAYER_ID)
{
	new ObjectIDMem = GetPlayerObjectMemory(ObjectID);

	for(new i = 0; i < PLAYERS; i ++)
	{
	    if(!IsPlayerConnected(i)) continue;
	    if(i == Exclude) continue;
	    
	    if(ObjectInfo[ObjectIDMem][IsNear][i] == 1)
            LoadPlayerNearContainers(i);
	}
	return 1;
}

stock RemoveObjectFromNearPlayers(ObjectID)
{
	new ObjectIDMem = GetPlayerObjectMemory(ObjectID);

	for(new i = 0; i < PLAYERS; i ++)
	{
	    if(!IsPlayerConnected(i)) continue;

	    if(ObjectInfo[ObjectIDMem][IsNear][i] == 1)
	    {
	        ObjectInfo[ObjectIDMem][IsNear][i] = 0;
            LoadPlayerNearContainers(i);
		}
	}
	return 1;
}


/*forward SwapContainerPosition(playerid, container1, container2);
public SwapContainerPosition(playerid, container1, container2)
{
	new Container1Position = ObjectInfo[container1][Position];
	new Container2Position = ObjectInfo[container2][Position];

	
	format(query, sizeof query, "UPDATE playerobjects SET Position = %d WHERE PlayerID = %d", Container1Position, container2);
	mysql_tquery(dbHandle, query, "", "");
    format(query, sizeof query, "UPDATE playerobjects SET Position = %d WHERE PlayerID = %d", Container2Position, container1);
	mysql_tquery(dbHandle, query, "", "");
	
	ObjectInfo[container1][Position] = Container2Position;
	ObjectInfo[container2][Position] = Container1Position;

	if(playerid != -1)
	{
	    LoadPlayerContainers(playerid);
	}

	return 1;
}*/


stock DestroyNearInventoryObjects(playerid)
{
    for(new i; i < sizeof(GlobalObjectsHead[]); i ++)
	{
	    for(new a; a < sizeof(GlobalObjectsHead[][]); a ++)
	    {
	        if(GlobalObjectsHead[playerid][i][a] != PlayerText:INVALID_TEXT_DRAW)
	        {
				PlayerTextDrawDestroy(playerid, GlobalObjectsHead[playerid][i][a]);
	            GlobalObjectsHead[playerid][i][a] = PlayerText:INVALID_TEXT_DRAW;
			}
	   	}
	}
	
	for(new i; i < sizeof(GlobalObjectsSlots[]); i ++)
	{
	    for(new a; a < sizeof(GlobalObjectsSlots[][]); a ++)
	    {
	        if(GlobalObjectsSlots[playerid][i][a] != PlayerText:INVALID_TEXT_DRAW)
	        {
	            PlayerTextDrawDestroy(playerid, GlobalObjectsSlots[playerid][i][a]);
	            GlobalObjectsSlots[playerid][i][a] = PlayerText:INVALID_TEXT_DRAW;
			}
	   	}
	}
	
	for(new i; i < sizeof(GlobalObjectsAmount[]); i ++)
	{
	    for(new a; a < sizeof(GlobalObjectsAmount[][]); a ++)
	    {
	        if(GlobalObjectsAmount[playerid][i][a] != PlayerText:INVALID_TEXT_DRAW)
	        {
	            PlayerTextDrawDestroy(playerid, GlobalObjectsAmount[playerid][i][a]);
	            GlobalObjectsAmount[playerid][i][a] = PlayerText:INVALID_TEXT_DRAW;
			}
	   	}
	}
	return 1;
}

stock DestroyActions(playerid)
{
    for(new i; i != sizeof ActionMenu[]; ++i)
    {
        if(ActionMenu[playerid][i] != PlayerText:INVALID_TEXT_DRAW)
        {
			PlayerTextDrawDestroy(playerid, ActionMenu[playerid][i]);
            ActionMenu[playerid][i] = PlayerText:INVALID_TEXT_DRAW;
		}
	}
	return 1;
}

stock DestroyInventoryObjects(playerid)
{
    for(new i = 0; i < sizeof(InventoryObjectsHead[]); i ++)
	{
	    for(new a = 0; a < sizeof(InventoryObjectsHead[][]); a ++)
    	{
	        if(InventoryObjectsHead[playerid][i][a] != PlayerText:INVALID_TEXT_DRAW)
	        {
				PlayerTextDrawDestroy(playerid, InventoryObjectsHead[playerid][i][a]);
	            InventoryObjectsHead[playerid][i][a] = PlayerText:INVALID_TEXT_DRAW;
			}
		}
	}
	for(new i = 0; i < sizeof(InventoryObjectsSlots[]); i ++)
	{
	    for(new a = 0; a < sizeof(InventoryObjectsSlots[][]); a ++)
    	{
	        if(InventoryObjectsSlots[playerid][i][a] != PlayerText:INVALID_TEXT_DRAW)
	        {
	            PlayerTextDrawDestroy(playerid, InventoryObjectsSlots[playerid][i][a]);
	            InventoryObjectsSlots[playerid][i][a] = PlayerText:INVALID_TEXT_DRAW;
			}
		}
	}
	
	for(new i = 0; i < sizeof(InventoryObjectsAmount[]); i ++)
	{
	    for(new a = 0; a < sizeof(InventoryObjectsAmount[][]); a ++)
    	{
	        if(InventoryObjectsAmount[playerid][i][a] != PlayerText:INVALID_TEXT_DRAW)
	        {
	            PlayerTextDrawDestroy(playerid, InventoryObjectsAmount[playerid][i][a]);
	            InventoryObjectsAmount[playerid][i][a] = PlayerText:INVALID_TEXT_DRAW;
			}
		}
	}
	return 1;
}

stock CreateInventory(playerid)
{
	Inv[playerid][0] = CreatePlayerTextDraw(playerid, 650.000000, 105.000000, "HeadBox");
	PlayerTextDrawBackgroundColor(playerid, Inv[playerid][0], 255);
	PlayerTextDrawFont(playerid, Inv[playerid][0], 1);
	PlayerTextDrawLetterSize(playerid, Inv[playerid][0], 0.500000, 1.000000);
	PlayerTextDrawColor(playerid, Inv[playerid][0], -1);
	PlayerTextDrawSetOutline(playerid, Inv[playerid][0], 0);
	PlayerTextDrawSetProportional(playerid, Inv[playerid][0], 1);
	PlayerTextDrawSetShadow(playerid, Inv[playerid][0], 1);
	PlayerTextDrawUseBox(playerid, Inv[playerid][0], 1);
	PlayerTextDrawBoxColor(playerid, Inv[playerid][0], 255);
	PlayerTextDrawTextSize(playerid, Inv[playerid][0], -10.000000, 0.000000);

	Inv[playerid][1] = CreatePlayerTextDraw(playerid, 650.000000, 111.000000, "BodyBox");
	PlayerTextDrawBackgroundColor(playerid, Inv[playerid][1], 255);
	PlayerTextDrawFont(playerid, Inv[playerid][1], 1);
	PlayerTextDrawLetterSize(playerid, Inv[playerid][1], 0.500000, 38.000000);
	PlayerTextDrawColor(playerid, Inv[playerid][1], -1);
	PlayerTextDrawSetOutline(playerid, Inv[playerid][1], 0);
	PlayerTextDrawSetProportional(playerid, Inv[playerid][1], 1);
	PlayerTextDrawSetShadow(playerid, Inv[playerid][1], 1);
	PlayerTextDrawUseBox(playerid, Inv[playerid][1], 1);
	PlayerTextDrawBoxColor(playerid, Inv[playerid][1], 0x00000000);
	PlayerTextDrawTextSize(playerid, Inv[playerid][1], 412.000000, 600.000000);
	PlayerTextDrawSetSelectable(playerid, Inv[playerid][1], 1);

	Inv[playerid][2] = CreatePlayerTextDraw(playerid, 529.000000, 106.000000, "Your Inventory");
	PlayerTextDrawAlignment(playerid, Inv[playerid][2], 2);
	PlayerTextDrawBackgroundColor(playerid, Inv[playerid][2], 255);
	PlayerTextDrawFont(playerid, Inv[playerid][2], 2);
	PlayerTextDrawLetterSize(playerid, Inv[playerid][2], 0.100000, 0.699998);
	PlayerTextDrawColor(playerid, Inv[playerid][2], -1);
	PlayerTextDrawSetOutline(playerid, Inv[playerid][2], 1);
	PlayerTextDrawSetProportional(playerid, Inv[playerid][2], 1);

	Inv[playerid][3] = CreatePlayerTextDraw(playerid, 213.000000, 111.000000, "_");
	PlayerTextDrawAlignment(playerid, Inv[playerid][3], 2);
	PlayerTextDrawBackgroundColor(playerid, Inv[playerid][3], 255);
	PlayerTextDrawFont(playerid, Inv[playerid][3], 1);
	PlayerTextDrawLetterSize(playerid, Inv[playerid][3], 0.500000, 39.000000);
	PlayerTextDrawColor(playerid, Inv[playerid][3], -1);
	PlayerTextDrawSetOutline(playerid, Inv[playerid][3], 0);
	PlayerTextDrawSetProportional(playerid, Inv[playerid][3], 1);
	PlayerTextDrawSetShadow(playerid, Inv[playerid][3], 1);
	PlayerTextDrawUseBox(playerid, Inv[playerid][3], 1);
	PlayerTextDrawBoxColor(playerid, Inv[playerid][3], 255);
	PlayerTextDrawTextSize(playerid, Inv[playerid][3], 9.000000, -2.000000);

	Inv[playerid][4] = CreatePlayerTextDraw(playerid, 413.000000, 111.000000, "_");
	PlayerTextDrawAlignment(playerid, Inv[playerid][4], 2);
	PlayerTextDrawBackgroundColor(playerid, Inv[playerid][4], 255);
	PlayerTextDrawFont(playerid, Inv[playerid][4], 1);
	PlayerTextDrawLetterSize(playerid, Inv[playerid][4], 0.500000, 39.000000);
	PlayerTextDrawColor(playerid, Inv[playerid][4], -1);
	PlayerTextDrawSetOutline(playerid, Inv[playerid][4], 0);
	PlayerTextDrawSetProportional(playerid, Inv[playerid][4], 1);
	PlayerTextDrawSetShadow(playerid, Inv[playerid][4], 1);
	PlayerTextDrawUseBox(playerid, Inv[playerid][4], 1);
	PlayerTextDrawBoxColor(playerid, Inv[playerid][4], 255);
	PlayerTextDrawTextSize(playerid, Inv[playerid][4], 9.000000, -2.000000);

	Inv[playerid][5] = CreatePlayerTextDraw(playerid, 101.000000, 106.000000, "Near Items");
	PlayerTextDrawAlignment(playerid, Inv[playerid][5], 2);
	PlayerTextDrawBackgroundColor(playerid, Inv[playerid][5], 255);
	PlayerTextDrawFont(playerid, Inv[playerid][5], 2);
	PlayerTextDrawLetterSize(playerid, Inv[playerid][5], 0.100000, 0.699998);
	PlayerTextDrawColor(playerid, Inv[playerid][5], -1);
	PlayerTextDrawSetOutline(playerid, Inv[playerid][5], 1);
	PlayerTextDrawSetProportional(playerid, Inv[playerid][5], 1);
	
	Inv[playerid][6] = CreatePlayerTextDraw(playerid, 624.000000, 104.500000, "1"); //Page number
	PlayerTextDrawAlignment(playerid, Inv[playerid][6], 2);
	PlayerTextDrawBackgroundColor(playerid, Inv[playerid][6], 255);
	PlayerTextDrawFont(playerid, Inv[playerid][6], 2);
	PlayerTextDrawLetterSize(playerid, Inv[playerid][6], 0.170000, 1.000000);
	PlayerTextDrawColor(playerid, Inv[playerid][6], -1);
	PlayerTextDrawSetOutline(playerid, Inv[playerid][6], 1);
	PlayerTextDrawSetProportional(playerid, Inv[playerid][6], 1);

	Inv[playerid][7] = CreatePlayerTextDraw(playerid, 612.000000, 105.500000, "~<~"); //Previous Page
	PlayerTextDrawBackgroundColor(playerid, Inv[playerid][7], 255);
	PlayerTextDrawFont(playerid, Inv[playerid][7], 1);
	PlayerTextDrawLetterSize(playerid, Inv[playerid][7], 0.379999, 0.799999);
	PlayerTextDrawColor(playerid, Inv[playerid][7], -1);
	PlayerTextDrawSetOutline(playerid, Inv[playerid][7], 0);
	PlayerTextDrawSetProportional(playerid, Inv[playerid][7], 1);
	PlayerTextDrawSetShadow(playerid, Inv[playerid][7], 0);
	PlayerTextDrawUseBox(playerid, Inv[playerid][7], 1);
	PlayerTextDrawBoxColor(playerid, Inv[playerid][7], 0);
	PlayerTextDrawTextSize(playerid, Inv[playerid][7], 618.000000, 8.000000);
	PlayerTextDrawSetSelectable(playerid, Inv[playerid][7], 1);

	Inv[playerid][8] = CreatePlayerTextDraw(playerid, 630.000000, 105.500000, "~>~"); // Next Page
	PlayerTextDrawBackgroundColor(playerid, Inv[playerid][8], 255);
	PlayerTextDrawFont(playerid, Inv[playerid][8], 1);
	PlayerTextDrawLetterSize(playerid, Inv[playerid][8], 0.379900, 0.799899);
	PlayerTextDrawColor(playerid, Inv[playerid][8], -1);
	PlayerTextDrawSetOutline(playerid, Inv[playerid][8], 0);
	PlayerTextDrawSetProportional(playerid, Inv[playerid][8], 1);
	PlayerTextDrawSetShadow(playerid, Inv[playerid][8], 0);
	PlayerTextDrawUseBox(playerid, Inv[playerid][8], 1);
	PlayerTextDrawBoxColor(playerid, Inv[playerid][8], 0);
	PlayerTextDrawTextSize(playerid, Inv[playerid][8], 635.000000, 8.000000);
	PlayerTextDrawSetSelectable(playerid, Inv[playerid][8], 1);

	Inv[playerid][9] = CreatePlayerTextDraw(playerid, 247.000000, 110.000000, "1");
	PlayerTextDrawBackgroundColor(playerid, Inv[playerid][9], 0);
	PlayerTextDrawFont(playerid, Inv[playerid][9], 5);
	PlayerTextDrawLetterSize(playerid, Inv[playerid][9], 0.500000, 1.000000);
	PlayerTextDrawColor(playerid, Inv[playerid][9], -1);
	PlayerTextDrawSetOutline(playerid, Inv[playerid][9], 0);
	PlayerTextDrawSetProportional(playerid, Inv[playerid][9], 1);
	PlayerTextDrawSetPreviewModel(playerid, Inv[playerid][9], 1);
	PlayerTextDrawSetShadow(playerid, Inv[playerid][9], 1);
	PlayerTextDrawUseBox(playerid, Inv[playerid][9], 1);
	PlayerTextDrawBoxColor(playerid, Inv[playerid][9], -1);
	PlayerTextDrawTextSize(playerid, Inv[playerid][9], 140.000000, 200.000000);
	PlayerTextDrawSetSelectable(playerid, Inv[playerid][9], 1);

	Inv[playerid][10] = CreatePlayerTextDraw(playerid, 313.000000, 339.000000, "Put");
	PlayerTextDrawAlignment(playerid, Inv[playerid][10], 2);
	PlayerTextDrawBackgroundColor(playerid, Inv[playerid][10], 255);
	PlayerTextDrawFont(playerid, Inv[playerid][10], 1);
	PlayerTextDrawLetterSize(playerid, Inv[playerid][10], 0.500000, 1.000000);
	PlayerTextDrawColor(playerid, Inv[playerid][10], 0);
	PlayerTextDrawSetOutline(playerid, Inv[playerid][10], 0);
	PlayerTextDrawSetProportional(playerid, Inv[playerid][10], 1);
	PlayerTextDrawSetShadow(playerid, Inv[playerid][10], 0);
	PlayerTextDrawUseBox(playerid, Inv[playerid][10], 1);
	PlayerTextDrawBoxColor(playerid, Inv[playerid][10], 255);
	PlayerTextDrawTextSize(playerid, Inv[playerid][10], 80.000000, 197.000000);

	Inv[playerid][11] = CreatePlayerTextDraw(playerid, 313.000000, 351.000000, "_"); //handsbody
	PlayerTextDrawAlignment(playerid, Inv[playerid][11], 2);
	PlayerTextDrawBackgroundColor(playerid, Inv[playerid][11], 255);
	PlayerTextDrawFont(playerid, Inv[playerid][11], 1);
	PlayerTextDrawLetterSize(playerid, Inv[playerid][11], 0.500000, 11.299997);
	PlayerTextDrawColor(playerid, Inv[playerid][11], 0);
	PlayerTextDrawSetOutline(playerid, Inv[playerid][11], 0);
	PlayerTextDrawSetProportional(playerid, Inv[playerid][11], 1);
	PlayerTextDrawSetShadow(playerid, Inv[playerid][11], 0);
	PlayerTextDrawUseBox(playerid, Inv[playerid][11], 1);
	PlayerTextDrawBoxColor(playerid, Inv[playerid][11], 0x00000044);
	PlayerTextDrawTextSize(playerid, Inv[playerid][11], 80.000000, 197.000000);
	PlayerTextDrawSetSelectable(playerid, Inv[playerid][11], 1);

	Inv[playerid][12] = CreatePlayerTextDraw(playerid, 230.000000, 340.000000, "Hands");
	PlayerTextDrawAlignment(playerid, Inv[playerid][12], 2);
	PlayerTextDrawBackgroundColor(playerid, Inv[playerid][12], 255);
	PlayerTextDrawFont(playerid, Inv[playerid][12], 2);
	PlayerTextDrawLetterSize(playerid, Inv[playerid][12], 0.100000, 0.699998);
	PlayerTextDrawColor(playerid, Inv[playerid][12], -1);
	PlayerTextDrawSetOutline(playerid, Inv[playerid][12], 1);
	PlayerTextDrawSetProportional(playerid, Inv[playerid][12], 1);

	Inv[playerid][13] = CreatePlayerTextDraw(playerid, 409.000000, 339.000000, "X");
	PlayerTextDrawAlignment(playerid, Inv[playerid][13], 2);
	PlayerTextDrawBackgroundColor(playerid, Inv[playerid][13], 255);
	PlayerTextDrawFont(playerid, Inv[playerid][13], 2);
	PlayerTextDrawLetterSize(playerid, Inv[playerid][13], 0.270000, 1.000000);
	PlayerTextDrawColor(playerid, Inv[playerid][13], -16776961);
	PlayerTextDrawSetOutline(playerid, Inv[playerid][13], 0);
	PlayerTextDrawSetProportional(playerid, Inv[playerid][13], 1);
	PlayerTextDrawSetShadow(playerid, Inv[playerid][13], 0);
	PlayerTextDrawUseBox(playerid, Inv[playerid][13], 1);
	PlayerTextDrawBoxColor(playerid, Inv[playerid][13], -587202424);
	PlayerTextDrawTextSize(playerid, Inv[playerid][13], 5.000000, 5.000000);
	PlayerTextDrawSetSelectable(playerid, Inv[playerid][13], 1);

	Inv[playerid][14] = CreatePlayerTextDraw(playerid, 4.000000, 105.000000, "X");
	PlayerTextDrawAlignment(playerid, Inv[playerid][14], 2);
	PlayerTextDrawBackgroundColor(playerid, Inv[playerid][14], 255);
	PlayerTextDrawFont(playerid, Inv[playerid][14], 2);
	PlayerTextDrawLetterSize(playerid, Inv[playerid][14], 0.270000, 1.000000);
	PlayerTextDrawColor(playerid, Inv[playerid][14], -16776961);
	PlayerTextDrawSetOutline(playerid, Inv[playerid][14], 0);
	PlayerTextDrawSetProportional(playerid, Inv[playerid][14], 1);
	PlayerTextDrawSetShadow(playerid, Inv[playerid][14], 0);
	PlayerTextDrawUseBox(playerid, Inv[playerid][14], 1);
	PlayerTextDrawBoxColor(playerid, Inv[playerid][14], -587202424);
	PlayerTextDrawTextSize(playerid, Inv[playerid][14], 5.000000, 5.000000);
	PlayerTextDrawSetSelectable(playerid, Inv[playerid][14], 1);
	
	Inv[playerid][17] = CreatePlayerTextDraw(playerid, 96.000000, 117.000000, "_");//proximity box
	PlayerTextDrawAlignment(playerid, Inv[playerid][17], 2);
	PlayerTextDrawBackgroundColor(playerid, Inv[playerid][17], 0);
	PlayerTextDrawFont(playerid, Inv[playerid][17], 1);
	PlayerTextDrawLetterSize(playerid, Inv[playerid][17], 3.099998, 37.000000);
	PlayerTextDrawColor(playerid, Inv[playerid][17], 0);
	PlayerTextDrawSetOutline(playerid, Inv[playerid][17], 0);
	PlayerTextDrawSetProportional(playerid, Inv[playerid][17], 1);
	PlayerTextDrawSetShadow(playerid, Inv[playerid][17], 1);
	PlayerTextDrawUseBox(playerid, Inv[playerid][17], 1);
	PlayerTextDrawBoxColor(playerid, Inv[playerid][17], 0x00000000);
	PlayerTextDrawTextSize(playerid, Inv[playerid][17], 300.000000, 230.000000);
	PlayerTextDrawSetSelectable(playerid, Inv[playerid][17], 1);
	
	Inv[playerid][18] = CreatePlayerTextDraw(playerid, 293.000000, 344.000000, "_"); //hands item
	PlayerTextDrawBackgroundColor(playerid, Inv[playerid][18], 0);
	PlayerTextDrawFont(playerid, Inv[playerid][18], 5);
	PlayerTextDrawLetterSize(playerid, Inv[playerid][18], 1.300000, 6.000000);
	PlayerTextDrawColor(playerid, Inv[playerid][18], -1);
	PlayerTextDrawSetOutline(playerid, Inv[playerid][18], 0);
	PlayerTextDrawSetProportional(playerid, Inv[playerid][18], 1);
	PlayerTextDrawSetPreviewModel(playerid, Inv[playerid][18], 19300);
	PlayerTextDrawSetShadow(playerid, Inv[playerid][18], 1);
	PlayerTextDrawUseBox(playerid, Inv[playerid][18], 1);
	PlayerTextDrawBoxColor(playerid, Inv[playerid][18], 255);
	PlayerTextDrawTextSize(playerid, Inv[playerid][18], 80.000000, 90.000000);
	
	Inv[playerid][19] = CreatePlayerTextDraw(playerid, 194.000000, 104.500000, "1"); //Page number (dropped)
	PlayerTextDrawAlignment(playerid, Inv[playerid][19], 2);
	PlayerTextDrawBackgroundColor(playerid, Inv[playerid][19], 255);
	PlayerTextDrawFont(playerid, Inv[playerid][19], 2);
	PlayerTextDrawLetterSize(playerid, Inv[playerid][19], 0.170000, 1.000000);
	PlayerTextDrawColor(playerid, Inv[playerid][19], -1);
	PlayerTextDrawSetOutline(playerid, Inv[playerid][19], 1);
	PlayerTextDrawSetProportional(playerid, Inv[playerid][19], 1);

	Inv[playerid][20] = CreatePlayerTextDraw(playerid, 182.000000, 105.500000, "~<~"); //previous page dropped
	PlayerTextDrawBackgroundColor(playerid, Inv[playerid][20], 255);
	PlayerTextDrawFont(playerid, Inv[playerid][20], 1);
	PlayerTextDrawLetterSize(playerid, Inv[playerid][20], 0.379999, 0.799998);
	PlayerTextDrawColor(playerid, Inv[playerid][20], -1);
	PlayerTextDrawSetOutline(playerid, Inv[playerid][20], 0);
	PlayerTextDrawSetProportional(playerid, Inv[playerid][20], 1);
	PlayerTextDrawSetShadow(playerid, Inv[playerid][20], 0);
	PlayerTextDrawUseBox(playerid, Inv[playerid][20], 1);
	PlayerTextDrawBoxColor(playerid, Inv[playerid][20], 0);
	PlayerTextDrawTextSize(playerid, Inv[playerid][20], 187.000000, 8.000000);
	PlayerTextDrawSetSelectable(playerid, Inv[playerid][20], 1);

	Inv[playerid][21] = CreatePlayerTextDraw(playerid, 200.000000, 105.500000, "~>~"); //next page dropped
	PlayerTextDrawBackgroundColor(playerid, Inv[playerid][21], 255);
	PlayerTextDrawFont(playerid, Inv[playerid][21], 1);
	PlayerTextDrawLetterSize(playerid, Inv[playerid][21], 0.379999, 0.799998);
	PlayerTextDrawColor(playerid, Inv[playerid][21], -1);
	PlayerTextDrawSetOutline(playerid, Inv[playerid][21], 0);
	PlayerTextDrawSetProportional(playerid, Inv[playerid][21], 1);
	PlayerTextDrawSetShadow(playerid, Inv[playerid][21], 0);
	PlayerTextDrawUseBox(playerid, Inv[playerid][21], 1);
	PlayerTextDrawBoxColor(playerid, Inv[playerid][21], 0);
	PlayerTextDrawTextSize(playerid, Inv[playerid][21], 205.000000, 8.000000);
	PlayerTextDrawSetSelectable(playerid, Inv[playerid][21], 1);
	return 1;
}

/*
OnPlayerRequestActionList(playerid, PlayerObjectID, memoryslotused, PlayerObjectType, Container, bool:Global)

playerid = The ID of hte player that requests the action menu
PlayerObjectID = The ID of the object to open the action menu at
memoryslotused = This is used to determine which position the object is on,
so I can calculate the correct position for the action menu X coordinates;
This varies, if it's a container, the position of the container (textdraw-wise),
if it's an object, which textdraw (0-40) of a container it is inside
PlayerObjectType = The type of the object to activate the menu on
Container = The container that the object is inside
Global = Is the object taken from Dropped Objects? True or false.
*/

forward OnPlayerRequestActionList(playerid, PlayerObjectID, memoryslotused, PlayerObjectType, Container, bool:Global);
public OnPlayerRequestActionList(playerid, PlayerObjectID, memoryslotused, PlayerObjectType, Container, bool:Global)
{
	new Float:fX, Float:fY;
	if(memoryslotused == MAX_CONTAINERS_PER_PAGE)
	    return 1;
	
	if(Global == false)
	{
		if(PlayerObjectID == Container)
		{
		    fY = PlayerVar[playerid][SelectedObjectHeaderY][memoryslotused];
		    fX = 419 + 30;
		}
		else
		{
			new actualposition = PlayerVar[playerid][MemorySlot][1];
			new in_line = floatround( float(actualposition+1) / 7.0, floatround_ceil);
		    fY = PlayerVar[playerid][SelectedObjectHeaderY][memoryslotused] + (37.0 * float(in_line)) + 1.0;
		    fX = 450.0 + 31.0 * float(actualposition % 7);
		}
	}
	else
	{
	    if(PlayerObjectID == Container)
		{
		    fY = PlayerVar[playerid][SelectedObjectHeaderY][memoryslotused];
		    fX = 12.5 + 30;
		}
		else
		{
			new actualposition = PlayerVar[playerid][MemorySlot][1];
			new in_line = floatround( float(actualposition+1) / 6.0, floatround_ceil);
		    fY = PlayerVar[playerid][SelectedObjectHeaderY][memoryslotused] + (37.0 * float(in_line)) + 1.0;
		    fX = 42.5 + 31.0 * float(actualposition % 6);
		}
	}
	
	
	if(fY > 415.0)
	    fY = fY-50.0;
	if(fX > 630.0)
	    fX = fX-32.0;


	DestroyActions(playerid);
	
	new baseid = GetObjectBaseID(PlayerObjectID);
	new baseidmem = GetObjectDataMemory(baseid);
	new name[64];
	
	if(ObjectData[baseidmem][MaxUses] > 0)
		format(name, sizeof name,"%s (%d)", ObjectData[baseidmem][Name], ObjectInfo[GetPlayerObjectMemory(PlayerObjectID)][CurrentUses]);
	else
	    format(name, sizeof name,"%s", ObjectData[baseidmem][Name]);
	    
	ActionMenu[playerid][4] = CreatePlayerTextDraw(playerid, fX,fY, name);
	PlayerTextDrawAlignment(playerid, ActionMenu[playerid][4], 2);
	PlayerTextDrawBackgroundColor(playerid, ActionMenu[playerid][4], 255);
	PlayerTextDrawFont(playerid, ActionMenu[playerid][4], 1);
	PlayerTextDrawLetterSize(playerid, ActionMenu[playerid][4], 0.159999, 0.799999);
	
	if(strlen(name) >= 13 && strlen(name) <= 20)
		PlayerTextDrawLetterSize(playerid, ActionMenu[playerid][4], 0.129999, 0.799999);
	else if(strlen(name) > 20)
		PlayerTextDrawLetterSize(playerid, ActionMenu[playerid][4], 0.089999, 0.799999);

	PlayerTextDrawColor(playerid, ActionMenu[playerid][4], -1);
	PlayerTextDrawSetOutline(playerid, ActionMenu[playerid][4], 1);
	PlayerTextDrawSetProportional(playerid, ActionMenu[playerid][4], 1);
	PlayerTextDrawUseBox(playerid, ActionMenu[playerid][4], 1);
	PlayerTextDrawBoxColor(playerid, ActionMenu[playerid][4], 0xFF000044);
	PlayerTextDrawTextSize(playerid, ActionMenu[playerid][4], 10.000000, 60.000000);
	PlayerTextDrawShow(playerid, ActionMenu[playerid][4]);
	fY += 10.55;
	
	PlayerVar[playerid][ObjectInAction] = PlayerObjectID;
	PlayerVar[playerid][ObjectInActionSource] = Container;
	PlayerVar[playerid][ObjectInActionGlobal] = Global;

	new totalactions;
    for(new i = 0; i <= LastActionDataIndexUsed+1; i ++)
    {
		if(ActionData[i][ActionID] == 0) continue;
        if(ActionData[i][TypeIDAttached] != PlayerObjectType) continue;
    
	    if(totalactions >= MAX_OBJECT_ACTIONS)
			break;
			
		PlayerVar[playerid][ActionStored][totalactions] = ActionData[i][ActionID];
		
	    ActionMenu[playerid][totalactions] = CreatePlayerTextDraw(playerid, fX,fY, ActionData[i][ActionName]);
		PlayerTextDrawAlignment(playerid, ActionMenu[playerid][totalactions], 2);
		PlayerTextDrawBackgroundColor(playerid, ActionMenu[playerid][totalactions], 255);
		PlayerTextDrawFont(playerid, ActionMenu[playerid][totalactions], 1);
		PlayerTextDrawLetterSize(playerid, ActionMenu[playerid][totalactions], 0.159999, 0.799999);
		PlayerTextDrawColor(playerid, ActionMenu[playerid][totalactions], 0xBBBBBBFF);
		PlayerTextDrawSetOutline(playerid, ActionMenu[playerid][totalactions], 1);
		PlayerTextDrawSetProportional(playerid, ActionMenu[playerid][totalactions], 1);
		PlayerTextDrawUseBox(playerid, ActionMenu[playerid][totalactions], 1);
		PlayerTextDrawBoxColor(playerid, ActionMenu[playerid][totalactions], -10092476);
		PlayerTextDrawTextSize(playerid, ActionMenu[playerid][totalactions], 8.5000000, 60.000000);
		PlayerTextDrawSetSelectable(playerid, ActionMenu[playerid][totalactions], 1);
		PlayerTextDrawShow(playerid, ActionMenu[playerid][totalactions]);
		
  		fY += 10.55;
  		totalactions ++;
	}
	
	ActionMenu[playerid][3] = CreatePlayerTextDraw(playerid, fX,fY, "Close");
	PlayerTextDrawAlignment(playerid, ActionMenu[playerid][3], 2);
	PlayerTextDrawBackgroundColor(playerid, ActionMenu[playerid][3], 255);
	PlayerTextDrawFont(playerid, ActionMenu[playerid][3], 1);
	PlayerTextDrawLetterSize(playerid, ActionMenu[playerid][3], 0.159999, 0.799999);
	PlayerTextDrawColor(playerid, ActionMenu[playerid][3], 0x999999FF);
	PlayerTextDrawSetOutline(playerid, ActionMenu[playerid][3], 1);
	PlayerTextDrawSetProportional(playerid, ActionMenu[playerid][3], 1);
	PlayerTextDrawUseBox(playerid, ActionMenu[playerid][3], 1);
	PlayerTextDrawBoxColor(playerid, ActionMenu[playerid][3], -10092476);
	PlayerTextDrawTextSize(playerid, ActionMenu[playerid][3], 8.5000000, 60.000000);
	PlayerTextDrawSetSelectable(playerid, ActionMenu[playerid][3], 1);
	PlayerTextDrawShow(playerid, ActionMenu[playerid][3]);
	return 1;
}

stock DestroyInventory(playerid)
{
	for(new i = 0; i < sizeof(Inv[]); i ++)
		PlayerTextDrawDestroy(playerid, Inv[playerid][i]);
	return 1;
}

stock ShowInventoryBase(playerid)
{
	PlayerTextDrawSetPreviewModel(playerid, Inv[playerid][9], GetPlayerSkin(playerid));

    for(new i = 0; i < sizeof(Inv[]); i ++)
		PlayerTextDrawShow(playerid, Inv[playerid][i]);
	return 1;
}

stock HideInventoryBase(playerid)
{
    for(new i = 0; i < sizeof(Inv[]); i ++)
		PlayerTextDrawHide(playerid, Inv[playerid][i]);
	return 1;
}

stock PlayerName(playerid)
{
  	GetPlayerName(playerid, nname, MAX_PLAYER_NAME);
  	return nname;
}

stock TDTip(playerid, tip[], time = 6000)
{
	PlayerTextDrawSetString(playerid, GeneralTxt[playerid][0], "Tip");
	PlayerTextDrawBoxColor(playerid, GeneralTxt[playerid][0], 0x00990044);
	PlayerTextDrawColor(playerid, GeneralTxt[playerid][0], 0x009900FF);
	PlayerTextDrawSetString(playerid, GeneralTxt[playerid][1], tip);
	
	PlayerTextDrawShow(playerid, GeneralTxt[playerid][0]);
	PlayerTextDrawShow(playerid, GeneralTxt[playerid][1]);
	
	KillTimer(PlayerVar[playerid][HideTooltipTimerID]);
	PlayerVar[playerid][HideTooltipTimerID] = SetTimerEx("GeneralTxtHide",time,false, "i", playerid);
	return 1;
}

stock TDInfo(playerid, info[], time = 6000)
{
	PlayerTextDrawSetString(playerid, GeneralTxt[playerid][0], "Information");
	PlayerTextDrawBoxColor(playerid, GeneralTxt[playerid][0], 0x00FFFF44);
	PlayerTextDrawColor(playerid, GeneralTxt[playerid][0], 0x00FFFFFF);
	PlayerTextDrawSetString(playerid, GeneralTxt[playerid][1], info);

	PlayerTextDrawShow(playerid, GeneralTxt[playerid][0]);
	PlayerTextDrawShow(playerid, GeneralTxt[playerid][1]);

	KillTimer(PlayerVar[playerid][HideTooltipTimerID]);
	PlayerVar[playerid][HideTooltipTimerID] = SetTimerEx("GeneralTxtHide",time, false, "i", playerid);
	return 1;
}
stock TDAdmin(playerid, message[], time = 6000)
{
	PlayerTextDrawSetString(playerid, GeneralTxt[playerid][0], "Administrator");
	PlayerTextDrawBoxColor(playerid, GeneralTxt[playerid][0], 0xBB110044);
	PlayerTextDrawColor(playerid, GeneralTxt[playerid][0], 0xBB1100FF);
	PlayerTextDrawSetString(playerid, GeneralTxt[playerid][1], message);

	PlayerTextDrawShow(playerid, GeneralTxt[playerid][0]);
	PlayerTextDrawShow(playerid, GeneralTxt[playerid][1]);

	KillTimer(PlayerVar[playerid][HideTooltipTimerID]);
	PlayerVar[playerid][HideTooltipTimerID] = SetTimerEx("GeneralTxtHide",time, false, "i", playerid);
	return 1;
}
stock TDWarning(playerid, warning[], time = 6000)
{
	PlayerTextDrawSetString(playerid, GeneralTxt[playerid][0], "Warning");
	PlayerTextDrawBoxColor(playerid, GeneralTxt[playerid][0], 0xFFFF0044);
	PlayerTextDrawColor(playerid, GeneralTxt[playerid][0], 0xFFFF00FF);
	PlayerTextDrawSetString(playerid, GeneralTxt[playerid][1], warning);

	PlayerTextDrawShow(playerid, GeneralTxt[playerid][0]);
	PlayerTextDrawShow(playerid, GeneralTxt[playerid][1]);

	KillTimer(PlayerVar[playerid][HideTooltipTimerID]);
	PlayerVar[playerid][HideTooltipTimerID] = SetTimerEx("GeneralTxtHide",time, false, "i", playerid);
	return 1;
}
stock Usage(playerid, error[], time = 6000)
{
	PlayerTextDrawSetString(playerid, GeneralTxt[playerid][0], "Correct Syntax:");
	PlayerTextDrawBoxColor(playerid, GeneralTxt[playerid][0], 0xFF660044);
	PlayerTextDrawColor(playerid, GeneralTxt[playerid][0], 0xFF6600FF);
	PlayerTextDrawSetString(playerid, GeneralTxt[playerid][1], error);

	PlayerTextDrawShow(playerid, GeneralTxt[playerid][0]);
	PlayerTextDrawShow(playerid, GeneralTxt[playerid][1]);

	KillTimer(PlayerVar[playerid][HideTooltipTimerID]);
	PlayerVar[playerid][HideTooltipTimerID] = SetTimerEx("GeneralTxtHide",time, false, "i", playerid);
	return 1;
}
stock TDError(playerid, error[], time = 6000)
{
	PlayerTextDrawSetString(playerid, GeneralTxt[playerid][0], "Error");
	PlayerTextDrawBoxColor(playerid, GeneralTxt[playerid][0], 0xFF000044);
	PlayerTextDrawColor(playerid, GeneralTxt[playerid][0], 0xFF0000FF);
	PlayerTextDrawSetString(playerid, GeneralTxt[playerid][1], error);

	PlayerTextDrawShow(playerid, GeneralTxt[playerid][0]);
	PlayerTextDrawShow(playerid, GeneralTxt[playerid][1]);

	KillTimer(PlayerVar[playerid][HideTooltipTimerID]);
	PlayerVar[playerid][HideTooltipTimerID] = SetTimerEx("GeneralTxtHide",time, false, "i", playerid);
	return 1;
}
stock TDOther(playerid, error[], time = 6000)
{
	PlayerTextDrawSetString(playerid, GeneralTxt[playerid][0], "Misc Information");
	PlayerTextDrawBoxColor(playerid, GeneralTxt[playerid][0], 0xFF66FF44);
	PlayerTextDrawColor(playerid, GeneralTxt[playerid][0], 0xFF66FFFF);
	PlayerTextDrawSetString(playerid, GeneralTxt[playerid][1], error);

	PlayerTextDrawShow(playerid, GeneralTxt[playerid][0]);
	PlayerTextDrawShow(playerid, GeneralTxt[playerid][1]);

	KillTimer(PlayerVar[playerid][HideTooltipTimerID]);
	PlayerVar[playerid][HideTooltipTimerID] = SetTimerEx("GeneralTxtHide",time, false, "i", playerid);
	return 1;
}


forward GeneralTxtHide(playerid);
public GeneralTxtHide(playerid)
{
	PlayerTextDrawHide(playerid, GeneralTxt[playerid][0]);
	PlayerTextDrawHide(playerid, GeneralTxt[playerid][1]);
	return 1;
}

stock CreatePlayerTextdraws(playerid)
{
	// big info
	GeneralTxt[playerid][0] = CreatePlayerTextDraw(playerid, 580.000000, 80.000000, " "); //header
	PlayerTextDrawAlignment(playerid, GeneralTxt[playerid][0], 2);
	PlayerTextDrawBackgroundColor(playerid, GeneralTxt[playerid][0], 255);
	PlayerTextDrawFont(playerid, GeneralTxt[playerid][0], 1);
	PlayerTextDrawLetterSize(playerid, GeneralTxt[playerid][0], 0.200000, 1.000000);
	PlayerTextDrawColor(playerid, GeneralTxt[playerid][0], -1);
	PlayerTextDrawSetOutline(playerid, GeneralTxt[playerid][0], 1);
	PlayerTextDrawSetProportional(playerid, GeneralTxt[playerid][0], 1);
	PlayerTextDrawUseBox(playerid, GeneralTxt[playerid][0], 1);
	PlayerTextDrawBoxColor(playerid, GeneralTxt[playerid][0], 16777028);
	PlayerTextDrawTextSize(playerid, GeneralTxt[playerid][0], 0.000000, 90.000000);

	GeneralTxt[playerid][1] = CreatePlayerTextDraw(playerid, 580.000000, 92.000000, " "); //message
	PlayerTextDrawAlignment(playerid, GeneralTxt[playerid][1], 2);
	PlayerTextDrawBackgroundColor(playerid, GeneralTxt[playerid][1], 255);
	PlayerTextDrawFont(playerid, GeneralTxt[playerid][1], 1);
	PlayerTextDrawLetterSize(playerid, GeneralTxt[playerid][1], 0.200000, 1.000000);
	PlayerTextDrawColor(playerid, GeneralTxt[playerid][1], -1);
	PlayerTextDrawSetOutline(playerid, GeneralTxt[playerid][1], 1);
	PlayerTextDrawSetProportional(playerid, GeneralTxt[playerid][1], 1);
	PlayerTextDrawUseBox(playerid, GeneralTxt[playerid][1], 1);
	PlayerTextDrawBoxColor(playerid, GeneralTxt[playerid][1], 68);
	PlayerTextDrawTextSize(playerid, GeneralTxt[playerid][1], 0.000000, 90.000000);
	return 1;
}

stock DestroyPlayerTextdraws(playerid)
{
	for(new i = 0; i < sizeof(GeneralTxt[]); i ++)
		PlayerTextDrawDestroy(playerid, GeneralTxt[playerid][i]);

	return 1;
}

stock RenderMessage(top, color, const text[])
{
    new temp[156], tosearch = 0, colorint, posscolor, lastcol[12];
    new mess[356], colors, tempc; format(mess, 356, "%s",text);

    while(strlen(mess) > 0)
    {
        if(strlen(mess) < 140)
        {
            SendClientMessage(top, color, mess);
            break;
        }

        strmid(temp, mess, 0, 140);
        while(strfind(temp, "{", true) != -1)
        {
            tempc = strfind(temp, "{", true);
            if(temp[tempc+7] == '}')
            {
            	colors ++;
          		strdel(temp, tempc, tempc+7);
            }
            else
            {
                temp[tempc] = '0';
                continue;
            }
        }
        temp = "";

        if(strlen(mess) <= 100+colors*8 && strlen(mess) <= 140)
        {
            SendClientMessage(top, color, mess);
            break;
        }
        tosearch = strfind(mess," ",true, 100+colors*8)+1;
        while(tosearch > 140 || tosearch <= 0)
        {
        	colors --;
        	tosearch = strfind(mess," ",true,100+colors*8)+1;
		}

        if(strfind(mess,"{",true) != -1) //color codes detection , YAY
        {
            posscolor = strfind(mess,"{",true);

            if(mess[posscolor+7] == '}') //detected one color
            colorint = posscolor;

        	while(strfind(mess,"{",true,colorint+1) != -1) //repeat until none are found
            {
                posscolor = strfind(mess,"{",true,colorint+1);
                if(posscolor > tosearch) //if next color will be on the other line, use last color found to render on the next line
                {
                    posscolor = colorint;
            		break;
               	}
                if(mess[posscolor+7] == '}') //if found, then assign the color
                {
                        colorint = posscolor;
                }
                else
                {
                    posscolor = colorint; //else, leave the last color.
                    break;
                }
           	}

			if(colorint == posscolor) //if the color position equals the one that was found
                strmid(lastcol,mess,colorint,colorint+8); //get the last used color string.
    	}

	    strmid(temp, mess, 0, tosearch);
     	SendClientMessage(top, color, temp);
	    strdel(mess, 0, tosearch);
	    strins(mess, lastcol, 0); //insert last used color into the new line to be processed.

        temp = "";
        tosearch = 0;
        colors = 0;
    }
    return 1;
}

stock RenderMessageToAll(color, const text[])
{
    new temp[156], tosearch = 0, colorint, posscolor, lastcol[12];
	new mess[356], colors, tempc; format(mess, 356, "%s",text);

    while(strlen(mess) > 0)
	{
	    if(strlen(mess) < 140)
        {
            SendClientMessageToAll(color, mess);
            break;
        }

		strmid(temp, mess, 0, 140);
	    while(strfind(temp, "{", true) != -1)
	    {
	        tempc = strfind(temp, "{", true);
	        if(temp[tempc+7] == '}')
	        {
				colors ++;
				strdel(temp, tempc, tempc+7);
			}
			else
   			{
   			    temp[tempc] = '0';
   			    continue;
   			}
	    }
	    temp = "";

        if(strlen(mess) <= 100+colors*8 && strlen(mess) <= 140)
        {
            SendClientMessageToAll(color, mess);
            break;
        }
     	tosearch = strfind(mess," ",true,100+colors*8)+1;
        while(tosearch > 140 || tosearch <= 0)
        {
        	colors --;
        	tosearch = strfind(mess," ",true,100+colors*8)+1;
		}

		if(strfind(mess,"{",true) != -1) //color codes detection , YAY
		{
			posscolor = strfind(mess,"{",true);

			if(mess[posscolor+7] == '}') //detected one color
		        colorint = posscolor;

            while(strfind(mess,"{",true,colorint+1) != -1) //repeat until none are found
			{
			    posscolor = strfind(mess,"{",true,colorint+1);
			    if(posscolor > tosearch) //if next color will be on the other line, use last color found to render on the next line
			    {
					posscolor = colorint;
			    	break;
			    }
				if(mess[posscolor+7] == '}') //if found, then assign the color
				{
					colorint = posscolor;
				}
				else
				{
				    posscolor = colorint; //else, leave the last color.
				    break;
				}
			}

            if(colorint == posscolor) //if the color position equals the one that was found
				strmid(lastcol,mess,colorint,colorint+8); //get the last used color string.
		}

        strmid(temp, mess, 0, tosearch);
        SendClientMessageToAll(color, temp);
		strdel(mess,0,tosearch);
		strins(mess, lastcol, 0);

    	temp = "";
		tosearch = 0;
		colors = 0;
	}
	return 1;
}

stock GetPlayerObjectMemory(PlayerObjectID) //returns the player object memory slot
{
	//printf("GetPlayerObjectMemory(%d)",PlayerObjectID);
	for(new i = 0; i <= LastObjectInfoIndexUsed; i ++)
	{
	    if(ObjectInfo[i][PlayerID] != PlayerObjectID) continue;
     	return i;
	}
	
	//printf("RETURNING INVALID_PLAYEROBJECT_ID ON PlayerObjectID = %d (%s)",PlayerObjectID, test);
	return INVALID_PLAYEROBJECT_ID;
}

stock  GetObjectDataMemory(BaseObjectID)//returns the base object memory slot
{
    //printf("GetObjectDataMemory(%d)",BaseObjectID);

	for(new i = 0; i <= LastObjectDataIndexUsed; i ++)
	{
	    if(ObjectData[i][ID] != BaseObjectID) continue;
	    return i;
	}
	
	//printf("RETURNING INVALID_BASEOBJECT_ID ON BaseObjectID = %d (%s)",BaseObjectID,test);
	return INVALID_BASEOBJECT_ID;
}

stock GetPlayerObjectDataMemory(PlayerObjectID) //gets the base object memory slot from a player object
{
    //printf("GetPlayerObjectDataMemory(%d)",PlayerObjectID);

	new BaseObject = GetObjectBaseID(PlayerObjectID);

	for(new i = 0; i <= LastObjectDataIndexUsed; i ++)
	{
	    if(ObjectData[i][ID] != BaseObject) continue;
	    return i;
	}
	//printf("RETURNING INVALID_BASEOBJECT_ID ON PlayerObjectID = %d (%s)",PlayerObjectID,test);
	return INVALID_BASEOBJECT_ID;
}

stock GetActionDataMemory(fActionID) //returns the base object memory slot
{
    //printf("GetActionDataMemory(%d)",fActionID);

	for(new i = 0; i <= LastActionDataIndexUsed; i ++)
	{
	    if(ActionData[i][ActionID] != fActionID) continue;
	    return i;
	}
	//printf("RETURNING INVALID_ACTION_ID ON fActionID = %d",fActionID);
	return INVALID_ACTION_ID;
}

stock GetSlotDataMemory(fSlotID) //returns the base object memory slot
{
    //printf("GetSlotDataMemory(%d)",fSlotID);

	for(new i = 0; i <= LastSlotDataIndexUsed; i ++)
	{
	    if(SlotData[i][SlotID] != fSlotID) continue;
	    return i;
	}
	return INVALID_SLOT_ID;
}

stock GetTypeDataMemory(fTypeID) //returns the base object memory slot
{
	for(new i = 0; i <= LastTypeDataIndexUsed; i ++)
	{
	    if(TypeData[i][TypeID] != fTypeID) continue;
	    return i;
	}
	return INVALID_TYPE_ID;
}

stock GetObjectBaseID(PlayerObjectID)
{
	if(PlayerObjectID == 0)
	    return 0;

	return ObjectInfo[GetPlayerObjectMemory(PlayerObjectID)][BaseID];
}

stock GetWeaponSlot(weaponid)
{
	new slot;
	if(weaponid == 0 || weaponid == 1)
	    slot = 0;
	else if(weaponid >= 2 && weaponid <= 9)
	    slot = 1;
	else if(weaponid >= 10 && weaponid <= 15)
		slot = 10;
	else if((weaponid >= 16 && weaponid <= 18) || weaponid == 39)
	    slot = 8;
	else if(weaponid >= 22 && weaponid <= 24)
	    slot = 2;
	else if(weaponid >= 25 && weaponid <= 27)
	    slot = 3;
	else if(weaponid == 28 || weaponid == 29 || weaponid == 32)
	    slot = 4;
	else if(weaponid == 30 || weaponid == 31)
	    slot = 5;
	else if(weaponid == 33 || weaponid == 34)
	    slot = 6;
	else if(weaponid >= 35 && weaponid <= 38)
	    slot = 7;
	else if(weaponid == 40)
	    slot = 12;
	else if(weaponid >= 41 && weaponid <= 43)
	    slot = 9;
	else if(weaponid >= 44 && weaponid <= 46)
	    slot = 11;

	return slot;
}

// not by me, probably most of them by Y_Less

#define BYTES_PER_CELL 				4

stock SendTDMessage(playerid, type, fstring[], {Float, _}:...) //by Y_Less, adapted for TD messages
{
    static const STATIC_ARGS = 3;
    new n = (numargs() - STATIC_ARGS) * BYTES_PER_CELL;
    if(n)
    {
        new message[144],arg_start,arg_end;
        #emit CONST.alt        fstring
        #emit LCTRL          5
        #emit ADD
        #emit STOR.S.pri        arg_start

        #emit LOAD.S.alt        n
        #emit ADD
        #emit STOR.S.pri        arg_end
        do
        {
            #emit LOAD.I
            #emit PUSH.pri
            arg_end -= BYTES_PER_CELL;
            #emit LOAD.S.pri      arg_end
        }
        while(arg_end > arg_start);

        #emit PUSH.S          fstring
        #emit PUSH.C          144
        #emit PUSH.ADR         message

        n += BYTES_PER_CELL * 3;
        #emit PUSH.S          n
        #emit SYSREQ.C         format

        n += BYTES_PER_CELL;
        #emit LCTRL          4
        #emit LOAD.S.alt        n
        #emit ADD
        #emit SCTRL          4

        if(playerid != INVALID_PLAYER_ID)
		{
            if(type == TYPE_ERROR)
                return TDError(playerid, message);
			else if(type == TYPE_INFO)
			    return TDInfo(playerid, message);
			else if(type == TYPE_ADMIN)
			    return TDAdmin(playerid, message);
			else if(type == TYPE_WARNING)
			    return TDWarning(playerid, message);
			else if(type == TYPE_USAGE)
			    return Usage(playerid, message);
			else if(type == TYPE_TIP)
			    return TDTip(playerid, message);
            else
			    return TDOther(playerid, message);
        }
    }
	else
	{
        if(playerid != INVALID_PLAYER_ID)
        {
		    if(type == TYPE_ERROR)
                return TDError(playerid, fstring);
			else if(type == TYPE_INFO)
			    return TDInfo(playerid, fstring);
			else if(type == TYPE_ADMIN)
			    return TDAdmin(playerid, fstring);
			else if(type == TYPE_WARNING)
			    return TDWarning(playerid, fstring);
			else if(type == TYPE_USAGE)
			    return Usage(playerid, fstring);
			else if(type == TYPE_TIP)
			    return TDTip(playerid, fstring);
            else
			    return TDOther(playerid, fstring);
        }
    }
    return 0;
}

stock RenderFormattedMessage(playerid, color, fstring[], {Float, _}:...) //Y_Less, yep, adapted for rendermessage
{
    static const STATIC_ARGS = 3;
    new n = (numargs() - STATIC_ARGS) * BYTES_PER_CELL;
    if(n)
    {
        new message[355],arg_start,arg_end;
        #emit CONST.alt        fstring
        #emit LCTRL          5
        #emit ADD
        #emit STOR.S.pri        arg_start

        #emit LOAD.S.alt        n
        #emit ADD
        #emit STOR.S.pri        arg_end
        do
        {
            #emit LOAD.I
            #emit PUSH.pri
            arg_end -= BYTES_PER_CELL;
            #emit LOAD.S.pri      arg_end
        }
        while(arg_end > arg_start);

        #emit PUSH.S          fstring
        #emit PUSH.C          144
        #emit PUSH.ADR         message

        n += BYTES_PER_CELL * 3;
        #emit PUSH.S          n
        #emit SYSREQ.C         format

        n += BYTES_PER_CELL;
        #emit LCTRL          4
        #emit LOAD.S.alt        n
        #emit ADD
        #emit SCTRL          4

        if(playerid == INVALID_PLAYER_ID)
        {
            #pragma unused playerid
            return RenderMessageToAll(color, message);
        }
		else
		{
            return RenderMessage(playerid, color, message);
        }
    }
	else
	{
        if(playerid == INVALID_PLAYER_ID)
        {
            #pragma unused playerid
            return RenderMessageToAll(color, fstring);
        }
		else 
		{
            return RenderMessage(playerid, color, fstring);
        }
    }
}


HexToInt(string[]){ //No idea who made this but ty
   if (string[0]==0) return 0;
   new i;
   new cur=1;
   new res=0;
   for (i=strlen(string);i>0;i--) {
     if (string[i-1]<58) res=res+cur*(string[i-1]-48); else res=res+cur*(string[i-1]-65+10);
     cur=cur*16;
   }
   return res;
 }
 
 
stock RemovePlayerWeapon(playerid, weaponid) //Also no idea
{
    if(!IsPlayerConnected(playerid) || weaponid < 0 || weaponid > 50)
        return;

    new
        saveweapon[13],
        saveammo[13];

    for(new slot = 0; slot < 13; slot++)
        GetPlayerWeaponData(playerid, slot, saveweapon[slot], saveammo[slot]);

    ResetPlayerWeapons(playerid);

    for(new slot; slot < 13; slot++)
    {
        GivePlayerWeapon(playerid, saveweapon[slot], saveammo[slot]);
    }
    //GivePlayerWeaponEx(playerid, 0, 1);
}

stock IsNumeric(const string[]) //No idea
{
	for (new i = 0, j = strlen(string); i < j; i++)
    {
   		if (string[i] > '9' || string[i] < '0') return 0;
   	}
   	return 1;
}

stock IsFloat(buf[]) //No idea
{
    new l = strlen(buf);
    new dcount = 0;
    for(new i=0; i<l; i++)
    {
        if(buf[i] == '.')
        {
            if(i == 0 || i == l-1) return 0;
            else
            {
                dcount++;
            }
        }
        if((buf[i] > '9' || buf[i] < '0') && buf[i] != '+' && buf[i] != '-' && buf[i] != '.') return 0;
        if(buf[i] == '+' || buf[i] == '-')
        {
            if(i != 0 || l == 1) return 0;
        }
    }
    if(dcount == 0 || dcount > 1) return 0;
    return 1;
}

stock GetXYInFrontOfPlayer(playerid, &Float:x, &Float:y, Float:distance) //no idea
{
	new Float:a;
	GetPlayerPos(playerid, x, y, a);
	GetPlayerFacingAngle(playerid, a);
	x += (distance * floatsin(-a, degrees));
	y += (distance * floatcos(-a, degrees));
}

stock RGBAToARGB( rgba ) //No idea
    return rgba >>> 8 | rgba << 24;
    
stock timestamp() //By Y-Less
{
	new h,m,s,d,n,y;
	gettime(h, m, s);
	getdate(y, n, d);
	return maketime(h, m, s, d, n, y);
}

stock maketime(hour, minute, second, day, month, year) //By Y-Less
{
	static days_of_month[12] = { 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
	static lMinute,	lHour,lDay,lMonth, lYear, lMinuteS, lHourS, lDayS, lMonthS, lYearS;
	if (year != lYear)
	{
		lYearS = 0;
		for (new j = 1970; j < year; j++)
		{
			lYearS += 31536000;
			if ((!(j % 4) && (j % 100)) || !(j % 400)) lYearS += 86400;
		}
		lYear = year;
	}
	if (month != lMonth)
	{
		lMonthS = 0;
		month--;
		for (new i = 0; i < month; i++)
		{
			lMonthS += days_of_month[i] * 86400;
			if ((i == 1) && ((!(year % 4) && (year % 100)) || !(year % 400))) lMonthS += 86400;
		}
		lMonth = month;
	}
	if (day != lDay)
	{
		lDayS = day * 86400;
		lDay = day;
	}
	if (hour != lHour)
	{
		lHourS = hour * 3600;
		lHour = hour;
	}
	if (minute != lMinute)
	{
		lMinuteS = minute * 60;
		lMinute = minute;
	}
	return lYearS + lMonthS + lDayS + lHourS + lMinuteS + second;
}
