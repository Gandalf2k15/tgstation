#define CABLE_LAYER_1 1
#define CABLE_LAYER_2 2
#define CABLE_LAYER_3 4

#define MACHINERY_LAYER_1 1

#define SOLAR_TRACK_OFF     0
#define SOLAR_TRACK_TIMED   1
#define SOLAR_TRACK_AUTO    2

//General defines for items that use power and the cell component.
/// The minimal amount of power an item can use.
#define POWER_CELL_USE_MINIMUM 1
/// For items that barely use any power at all.
#define POWER_CELL_USE_VERY_LOW 10
/// For items that generally wouldn't use very much power.
#define POWER_CELL_USE_LOW 30
/// For items that use a average amount of power.
#define POWER_CELL_USE_NORMAL 50
/// For items that use a high amount of power.
#define POWER_CELL_USE_HIGH 70
/// For items that use A LOT OF POWER.
#define POWER_CELL_USE_INSANE 100
