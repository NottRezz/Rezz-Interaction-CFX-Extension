# rezz-interaction

A **proximity-based interaction system for RedM** with floating world markers. Players hold a key to enter targeting mode — nearby registered entities and zones display interactive dots at their world position on screen. Clicking a dot expands an options dropdown. Selecting an option triggers a client event in your resource.

## Features

- **Proximity scanning** — discovers all nearby peds, vehicles, objects, and zones within range simultaneously
- **Floating world markers** — interactive dots render at each entity's screen-projected position with smooth tracking
- **Click-to-expand** — dots expand into an options dropdown on click; only one can be open at a time
- **Model targeting** — register options by model name or hash
- **Entity targeting** — register options by network ID
- **Global type targeting** — blanket options on all peds, vehicles, or objects
- **Zone targeting** — location-based interactions with configurable radius
- **Conditional visibility** — `canInteract` callbacks per option
- **C# / JS interop** — event-based API alongside Lua exports
- **Western-themed UI** — dark, gold-accented styling with pulse animations and smooth transitions

---

## Installation

1. Place the `rezz-interaction` folder in your server's `resources` directory.
2. Add to your `server.cfg`:
   ```
   ensure rezz-interaction
   ```
3. Make sure it starts **before** any resources that register targets.

---

## Configuration

Edit `config.lua`:

| Setting | Default | Description |
|---|---|---|
| `Config.TargetKey` | `0x8AAA0AD4` | Control hash to hold for targeting mode (Left Alt) |
| `Config.MaxDistance` | `5.0` | Maximum proximity scan distance in game units |
| `Config.ScanInterval` | `100` | How often (ms) to scan for nearby targets while in targeting mode |
| `Config.Debug` | `false` | Enable debug mode |
| `Config.DefaultZoneDistance` | `2.5` | Default radius for zone-based targets |

---

## How It Works

1. Player holds **Left Alt** → enters targeting mode, NUI focus is enabled
2. A proximity scan runs every 50 ms, finding all peds, vehicles, objects, and zones within `MaxDistance`
3. Each entity/zone with registered options gets a floating **dot marker** projected to its screen position
4. The dot displays the icon of the first registered option and pulses gently
5. Player clicks a dot → the options dropdown expands below it
6. Player clicks an option → the associated client event fires with entity handle, network ID, and custom data
7. Releasing Alt or pressing Escape closes targeting mode
8. Stale entity targets are automatically pruned every 5 seconds

---

## API Reference — Lua Exports

All exports are called as:
```lua
exports['rezz-interaction']:functionName(...)
```

### addModel(models, options)

Register options for one or more model hashes.

```lua
exports['rezz-interaction']:addModel('a_c_horse_americanpaint_greyovero', {
    { label = 'Pet Horse', icon = 'fas fa-horse', event = 'myScript:pet' },
})

-- Multiple models:
exports['rezz-interaction']:addModel({
    'a_c_horse_americanpaint_greyovero',
    'a_c_horse_morgan_bay',
}, {
    { label = 'Feed', icon = 'fas fa-apple-whole', event = 'myScript:feed' },
})
```

### removeModel(models)

Remove all options for the given model(s).

```lua
exports['rezz-interaction']:removeModel('a_c_horse_americanpaint_greyovero')
```

### addEntity(netIds, options)

Register options for specific entities by **network ID**.

```lua
local netId = NetworkGetNetworkIdFromEntity(someEntity)
exports['rezz-interaction']:addEntity(netId, {
    { label = 'Talk', icon = 'fas fa-comment', event = 'myScript:talk' },
})
```

### removeEntity(netIds)

Remove all options for the given network ID(s).

```lua
exports['rezz-interaction']:removeEntity(netId)
```

### addGlobalPed(options)

Add options that appear on **all peds**.

```lua
exports['rezz-interaction']:addGlobalPed({
    { label = 'Inspect', icon = 'fas fa-magnifying-glass', event = 'myScript:inspect' },
})
```

### addGlobalVehicle(options)

Add options that appear on **all vehicles**.

```lua
exports['rezz-interaction']:addGlobalVehicle({
    { label = 'Hitch', icon = 'fas fa-link', event = 'myScript:hitch' },
})
```

### addGlobalObject(options)

Add options that appear on **all objects**.

```lua
exports['rezz-interaction']:addGlobalObject({
    { label = 'Pick Up', icon = 'fas fa-hand', event = 'myScript:pickup' },
})
```

### addZone(name, data)

Register a location-based interaction zone.

```lua
exports['rezz-interaction']:addZone('saloon_door', {
    coords = vector3(-315.0, 808.0, 118.0),
    radius = 1.5,
    options = {
        { label = 'Enter Saloon', icon = 'fas fa-door-open', event = 'myScript:enter' },
    },
})
```

### removeZone(name)

Remove a registered zone by name.

```lua
exports['rezz-interaction']:removeZone('saloon_door')
```

---

## API Reference — Events (C# / JS)

These events mirror the exports above. Use `TriggerEvent` from C# or other languages that cannot call Lua exports directly.

| Event | Parameters |
|---|---|
| `rezz-interaction:addModel` | `(models, options)` |
| `rezz-interaction:removeModel` | `(models)` |
| `rezz-interaction:addEntity` | `(netIds, options)` |
| `rezz-interaction:removeEntity` | `(netIds)` |
| `rezz-interaction:addGlobalPed` | `(options)` |
| `rezz-interaction:addGlobalVehicle` | `(options)` |
| `rezz-interaction:addGlobalObject` | `(options)` |
| `rezz-interaction:addZone` | `(name, data)` |
| `rezz-interaction:removeZone` | `(name)` |

---

## Option Properties

Each option is a table (Lua) or dictionary (C#) with these fields:

| Field | Type | Required | Description |
|---|---|---|---|
| `label` | string | **Yes** | Text displayed on the button |
| `event` | string | **Yes** | Client event name triggered on click |
| `icon` | string | No | Font Awesome class (default: `fas fa-hand-pointer`) |
| `description` | string | No | Smaller sub-text below the label |
| `keybind` | string | No | Keybind badge shown on the right (display only) |
| `data` | table | No | Arbitrary data passed to the event callback |
| `canInteract` | function | No | Lua-only. Return `true`/`false` to show/hide dynamically. Receives `(entity)`. **Not available from C#.** |

---

## Callback Data

When a player clicks an option, the specified event fires with a single argument:

| Field | Type | Description |
|---|---|---|
| `entity` | number | Local entity handle (client-side) |
| `netId` | number | Network ID of the entity (0 if not networked) |
| `data` | table | The `data` field from the option definition |

**Lua:**

```lua
AddEventHandler('myScript:talk', function(info)
    local entity = info.entity
    local netId  = info.netId
    local custom = info.data
end)
```

**C#:**

```csharp
EventHandlers["myScript:talk"] += new Action<IDictionary<string, object>>((info) =>
{
    int entityHandle = Convert.ToInt32(info["entity"]);
    int networkId    = Convert.ToInt32(info["netId"]);
});
```

---

## Full Examples

### Lua

```lua
-- Register horse interactions
exports['rezz-interaction']:addModel('a_c_horse_americanpaint_greyovero', {
    {
        label = 'Pet Horse',
        icon = 'fas fa-horse',
        event = 'ranch:petHorse',
        description = 'Show some love',
    },
    {
        label = 'Feed Horse',
        icon = 'fas fa-apple-whole',
        event = 'ranch:feedHorse',
        description = 'Give food',
        keybind = 'E',
    },
    {
        label = 'Mount',
        icon = 'fas fa-person-walking',
        event = 'ranch:mountHorse',
    },
})

-- Conditional option (Lua only)
exports['rezz-interaction']:addGlobalPed({
    {
        label = 'Loot Body',
        icon = 'fas fa-sack-dollar',
        event = 'loot:searchBody',
        canInteract = function(entity)
            return IsEntityDead(entity)
        end,
    },
})

-- Handle the event
AddEventHandler('ranch:petHorse', function(info)
    print('Petting horse, entity: ' .. info.entity .. ', netId: ' .. info.netId)
end)

-- Zone example
exports['rezz-interaction']:addZone('general_store', {
    coords = vector3(-329.5, 770.8, 116.5),
    radius = 2.0,
    options = {
        { label = 'Browse Goods', icon = 'fas fa-store', event = 'shop:open' },
        { label = 'Sell Items',   icon = 'fas fa-coins',  event = 'shop:sell' },
    },
})

-- Cleanup
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        exports['rezz-interaction']:removeModel('a_c_horse_americanpaint_greyovero')
        exports['rezz-interaction']:removeZone('general_store')
    end
end)
```

### C#

```csharp
using System;
using System.Collections.Generic;
using CitizenFX.Core;
using static CitizenFX.Core.Native.API;

// Register a model target
TriggerEvent("rezz-interaction:addModel",
    new[] { "a_c_horse_americanpaint_greyovero" },
    new object[] {
        new Dictionary<string, object> {
            { "label", "Pet Horse" },
            { "icon", "fas fa-horse" },
            { "description", "Show some love" },
            { "event", "ranch:petHorse" }
        },
        new Dictionary<string, object> {
            { "label", "Feed Horse" },
            { "icon", "fas fa-apple-whole" },
            { "event", "ranch:feedHorse" }
        }
    }
);

// Register an entity by network ID
int netId = entity.NetworkId;
TriggerEvent("rezz-interaction:addEntity",
    new[] { netId },
    new object[] {
        new Dictionary<string, object> {
            { "label", "Talk" },
            { "icon", "fas fa-comment" },
            { "event", "myResource:talk" }
        }
    }
);

// Register a zone
TriggerEvent("rezz-interaction:addZone", "my_shop",
    new Dictionary<string, object> {
        { "coords", new float[] { -329.5f, 770.8f, 116.5f } },
        { "radius", 2.0f },
        { "options", new object[] {
            new Dictionary<string, object> {
                { "label", "Open Shop" },
                { "icon", "fas fa-store" },
                { "event", "myResource:openShop" }
            }
        }}
    }
);

// Handle the callback
EventHandlers["ranch:petHorse"] += new Action<IDictionary<string, object>>((info) =>
{
    int entityHandle = Convert.ToInt32(info["entity"]);
    int networkId = Convert.ToInt32(info["netId"]);
    Debug.WriteLine($"Player chose to pet horse! NetID: {networkId}");
});

// Remove targets
TriggerEvent("rezz-interaction:removeModel", new[] { "a_c_horse_americanpaint_greyovero" });
TriggerEvent("rezz-interaction:removeEntity", new[] { netId });
TriggerEvent("rezz-interaction:removeZone", "my_shop");
```

---

## Common Icons

The UI uses [Font Awesome 6](https://fontawesome.com/icons?d=gallery&s=solid). Some useful picks for RedM:

| Icon | Class |
|---|---|
| Horse | `fas fa-horse` |
| Weapon | `fas fa-gun` |
| Talk | `fas fa-comment` |
| Search | `fas fa-magnifying-glass` |
| Loot | `fas fa-sack-dollar` |
| Shop | `fas fa-store` |
| Money | `fas fa-coins` |
| Enter | `fas fa-door-open` |
| Hand | `fas fa-hand` |
| Food | `fas fa-apple-whole` |
| Health | `fas fa-heart` |
| Danger | `fas fa-skull` |
| Camp | `fas fa-campground` |
| Fire | `fas fa-fire` |
| Lock | `fas fa-lock` |
| Unlock | `fas fa-unlock` |

---

## Troubleshooting

**No markers appear when holding Alt**
- Verify the resource is running: `restart rezz-interaction` in console
- Check `Config.TargetKey` matches your desired input hash
- Check for errors in the F8 console

**Options don't appear on an entity**
- Ensure the entity is within `Config.MaxDistance` (default 5.0)
- For `addEntity`, pass the **network ID**, not the entity handle — use `NetworkGetNetworkIdFromEntity(entity)`
- For `addModel`, verify the model name/hash is correct
- Enable `Config.Debug = true` for additional diagnostics

**`canInteract` doesn't work from C#**
- `canInteract` only works with Lua exports (it's a function callback)
- From C#, add/remove targets dynamically instead

**Cursor doesn't appear when options show**
- Check for conflicts with other resources controlling NUI focus

**Option fires but nothing happens**
- Ensure your `AddEventHandler` matches the exact event string
- The callback receives a **table** (Lua) / **IDictionary** (C#), not individual parameters

---

## License

MIT
