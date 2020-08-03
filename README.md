# XLIB
A collection of snippets and tools for Garry's Mod development. (Short for Xavier's Library)

*TODO: LDoc documentation. This library is mostly limited to internal use, but is a dependency for some of my future releases.*


- [XLIB](#xlib)
  - [Credential Store](#credential-store)
    - [Configuration](#configuration)
    - [Lua Usage](#lua-usage)
  - [GDBC](#gdbc)
    - [Declarative Syntax](#declarative-syntax)
    - [Control Flow](#control-flow)
  - [XLoader](#xloader)
  - [XLIB.Timer](#xlibtimer)
  - [NetWrapper](#netwrapper)
  - [XLIB Extended](#xlib-extended)
    - [DevCommand](#devcommand)
    - [gmod-sentry](#gmod-sentry)
- [Contributing](#contributing)

## Credential Store
***Preamble:** Most Garry's Mod scripts configurations hardcode credentials. This is less than ideal for source controlled projects.*

This aims to solve this issue by allowing you to store all of your credentials in a schemaless `GarrysMod/garrysmod/CREDENTIAL_STORE`
[Valve VDF](https://developer.valvesoftware.com/wiki/KeyValues#File_Format) file
in the root of your Garry's Mod installation. In turn, this allows you to maintain separate configuration files for each environment (development, staging, production).

The VDF file is exposed as the global `CREDENTIALS` table in Lua.

### Configuration
`CREDENTIAL_STORE.txt`
```
credentials
{
    // Here are the fields XLib uses
    development_mode "1" // Makes IsTestServer() return true
    extended "1"  // Enables parts of XLib that are meant to be for "internal use" AKA not guaranteed to not cause any conflicts outside of our environments.
    production "0" // No particular use, for now. Slightly redundant, but you can use `CREDENTIALS.production` as a predicate in your code.
    mysql
    {
        cats_database
        {
            host "localhost"
            db   "cats"
            user "cat_lover"
            pass "CatLover1546"
            port "3306"
        }
    }

    // You can also have any custom values here to configure your custom scripts.
    example_script {
        url "https://test-endpoint.com/"
        apikey "some_api_key"
    }
}
```

### Lua Usage
```lua
require "credentialstore"

if CREDENTIALS.development_mode then
    print("Server is running in development mode!")
end

if not CREDENTIALS.mysql.cats_databse then
    print("cats_database credentials not found, resorting to sqlite.")
else
    print("cats_database login info", SPrintTable(CREDENTIALS.mysql.cats_database))
end
```

## GDBC
"Garry's Mod Database Connector" - Spawned by the disdain of hardcoding MySQL queries everywhere. Originally featured its own libmysql <-> Lua bindings but was
retrofitted for use with [MysqlOO](https://github.com/FredyH/MySQLOO) for ease of maintainability.

Some of the main features include:
* Unique chaining control flow avoids callback hell
* Prepared Statements (Actual prepared statements OR falls back to formatting the SQL query and sending it if `connect.usePreparedStatememts=false`)
* MySQL Connection Pool (Set `connect.threads= >1`)
* Database Versioning (Through a basic key-value `config` table added to each schema)
* Schema Migrations (Players are not allowed to join until all migrations are complete!)

### Declarative Syntax
For connection info, queries and migrations
```lua
schema "darkrp"
{
    connect
    {
        host = CREDENTIALS.mysql.darkrp.host,
        user = CREDENTIALS.mysql.darkrp.user,
        pass = CREDENTIALS.mysql.darkrp.pass,
        database = CREDENTIALS.mysql.darkrp.db,
        port = CREDENTIALS.mysql.darkrp.port,
        
        --[=====================================================================[
            Whether this database connection should use prepared statements.
            
            Before you enable this, ensure that all of your queries are
            compatible for use within prepared statements.

            https://mariadb.com/kb/en/prepare-statement/#permitted-statements/

            If you would like to benefit from prepared statements while still
            maintaining the ability to use statements not yet implemented,
            use :queryraw() along with :prepare():

            DB.schema_name
                :queryraw(DB.schema_name.table_name.query_name:prepare(...))
                :exec()

        ]=====================================================================]
        usePreparedStatements = false,

        --[=====================================================================[
            CAREFUL! Only queries contained within the same GDBC Query Sequence
            are guaranteed to be executed in order with strong consistency.

            In single-connection mode, initiating two query sequences one after
            the other will guarantee that the first sequence will finish before
            the second 

            IF YOU'RE UNSURE WHAT THIS MEANS, LEAVE THREADS=1 TO AVOID ISSUES.
            I'm serious! Blindly enabling this feature without having designed
            your database interaction logic with this in mind could lead to
            bugs that will be nearly impossible to diagnose.

            Note:
            By default, GDBC already initiates a second connection that can be
            specifically targeted by calling :low() on the sequence.
            I recommend you call :low() on non-critical, write-intensive spammy
            queries (such as statistics collection or logging) and reevaluating
            performance before resorting to connection pools.
        ]=====================================================================]

        -- For the reasons listed above, I recommend leaving this parameter out
        -- entirely if you plan on distributing your script to avoid other 
        -- people from being tempted to blindly modify its value.
        -- threads = 1,  -- Set > 1 to enable connection pool. READ ABOVE!
    };

    table "players"
    {
        get = [[SELECT id FROM players WHERE steamid=?]];
        steamid = [[SELECT id, steamid from players WHERE id=?]];
        insert = [[INSERT INTO players (steamid) VALUES (?)]];
    };

    table "player_info"
    {
        get = [[SELECT * FROM player_info WHERE player_id=?]];

        setLuck = [[UPDATE player_info SET luck=?]];
        setHappiness = [[UPDATE player_info SET happiness=?]];
        setRPName = [[UPDATE player_info SET rpname=?]];
        setSteamName = [[UPDATE player_info SET steamname=?]];

        getNames = [[
            SELECT steamname, rpname FROM player_info WHERE player_id=?
        ]];

        getNamesSteamID = [[
            SELECT player_info.rpname, player_info.steamname
            FROM player_info
            INNER JOIN players
            ON player_info.player_id = players.id
            WHERE players.steamid=?
        ]];
    };

    migration (1)
        [[
            -- -----------------------------------------------------
            -- Table `players`
            -- -----------------------------------------------------
            CREATE TABLE IF NOT EXISTS `players` (
              `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
              `steamid` VARCHAR(25) NOT NULL,
              PRIMARY KEY (`id`),
              UNIQUE INDEX `steamid_UNIQUE` (`steamid` ASC),
              INDEX `steamid_INDEX` (`steamid` ASC))
            ENGINE = InnoDB;

            -- -----------------------------------------------------
            -- Table `player_info`
            -- -----------------------------------------------------
            CREATE TABLE IF NOT EXISTS `player_info` (
              `player_id` INT UNSIGNED NOT NULL,
              `steamname` VARCHAR(45) NULL,
              `rpname` VARCHAR(45) NULL,
              `happiness` INT UNSIGNED NULL DEFAULT 75,
              `luck` INT NULL DEFAULT 100,
              PRIMARY KEY (`player_id`),
              UNIQUE INDEX `player_id_UNIQUE` (`player_id` ASC),
              CONSTRAINT `fk_player_info.player_id:players.id`
                FOREIGN KEY (`player_id`)
                REFERENCES `players` (`id`)
                ON DELETE NO ACTION
                ON UPDATE NO ACTION)
            ENGINE = InnoDB;
        ]];

    migration (2)
        [[
            -- -----------------------------------------------------
            -- Steam updated their maximum display name length.
            -- Update `player_info`.`steamname` accordingly.
            -- -----------------------------------------------------
            ALTER TABLE `player_info` MODIFY `steamname` VARCHAR(64);
        ]];

    -- Support for function-based migration for additional logic
    migration (3) (function(db, callback)
        db()
            :queryraw("SELECT VERSION() AS `version`")
                :result(function(q, row)
                    if row.version:lower():find("mariadb") then
                        return "alter"
                    end
                end)

            :queryraw "alter" [[
                ALTER TABLE `csidarkrp`.`player_inventory` ADD SYSTEM VERSIONING;
            ]]

            :success(function(q)
                callback(true)
            end)

            :fail(function(q, err, sql, traceback)
                callback(false, "Migration SQL error occurred: "..err)
            end)

            :exec()
    end);
}
```

### Control Flow
```lua
function CSIDB:InitPlayer(ply)
    local steamid = ply:SteamID()
    local player_id

    -- Initiate a query chain
    DB.darkrp()
        -- Add a sequential query to the chain
        :query(DB.darkrp.players.select(steamid))
            :result(function(q, row)
                -- Return next_action, vararg parameters.
                -- If next_action is nil, execute the next sequential query or operation
                -- The remaining returned objects are passed to the sequence or the query object.
                return "on_id", row['id']
            end)

            :empty(function()
                -- The entry does not exist in the database yet, create it!
                return "insert", steamid
            end)

        -- Add a named query to the chain
        -- You can pass arguments to the query object if they are knonwn in advance
        :query "insert" (DB.darkrp.players.insert(steamid))
            :empty(function(q, last_insert)
                return "on_id", last_insert
            end)

        -- Store id into a local variable for future use
        :procedure "on_id" (function(q, id)
            player_id = id
            return "get_info", id
        end)

        -- Add another named query to the chain
        -- This time we don't know the player_id, so it is the caller's job to pass it in its return statement
        :query "get_info" (DB.darkrp.player_info.get)
            :result(function(q, row)
                -- We have the data, proceed!
                return "done", row
            end)

            :empty(function()
                -- The entry does not exist in the database yet, create it!
                return "default_info"
            end)

        :procedure "default_info" (function(q)
            if not IsValid(ply) then
                return false  -- Returning false will abort the query chain
            end

            -- Asynchronously populate `csidarkrp`.`player_info` with player_id and move on
            local info = CSIDB:SaveDefaultInfo(player_id)

            return "done", info
        end)

        :procedure "done" (function(q, player_id)
            if not IsValid(ply) then
                return  -- The player managed to disconnect during the query chain
            end

            hook.Run("CSIDB:PlayerReady", ply)
        end)

        -- Enable logging the SQL queries sent from this particular chain only
        :log()

        -- Execute this query sequence on the single-threaded low-priority queue
        :low()

        -- Used to delay flushing of write-intensive queries to the latest
        -- dataset based on unique_id after max of time_in_seconds
        :throttle("unique_id", time_in_seconds)

        -- Execute the chain. This will start with the first sequential query.
        :exec()
end

function CSIDB:SaveDefaultInfo(player_id)
    local default_info = {
        steamname = "UNKNOWN",
        rpname = "John Doe",
        luck = 100,
        happiness = 100,
    }

    -- TODO: Save default_info asynchronously here with a different query chain

    return default_info
end

-- Workaround for GM.Think to get called even with no players on the server
-- Required for MySQLOO Query callbacks to be processed.\
-- Enable this if you want need to load information from the database
-- before allowing player connections.
RunConsoleCommand("sv_hibernate_think", "1")

-- GDBC exposes two hooks, GDBC:InitSchemas and GDBC:Ready
hook.Add("GDBC:Ready", "CSIDB:Ready", function()
    -- The database has connected and migrations have all been successfully executed.
    -- Execute any server initialization queries here
end)


hook.Add("GDBC:InitSchemas", "CSIDB:InitSchemas", function()
    -- GDBC is ready to load schemas and start executing migrations.
    -- GDBC.LoadSchema("path/to/schema.lua")

    -- Note that GDBC.LoadSchema uses CompileFile internally.
    -- This means that file paths are relative to the Lua mount path, NOT the current file!
    -- This also means you should properly namespace these files to avoid conflicts.

    -- e.g file in garrysmod/addons/my_cool_addon/lua/cool_addon/database/schema.lua
    GDBC.LoadSchema("cool_addon/database/schema.lua")

    -- e.g file in garrysmod/gamemodes/gm_name/gamemode/database/schema.lua
    GDBC.LoadSchema((GM or GAMEMODE).FolderName .. "/gamemode/database/schema.lua")
end)

```

## XLoader
"Xavier's Loader" - Predictable automatic recursive file includer

Some of the main features include:
* Automatically `include()` and `AddCSLuaFile()` files in the specified directory
* Auto-refresh aware [Upstream bug](https://github.com/Facepunch/garrysmod-issues/issues/935)
* Guaranteed predictable load order

The include order is as follows:
1. All `sh_*.lua` files for the current directory, sorted alphanumerically
2. All `sv_*.lua` or `cl_*.lua` files for the current directory, sorted alphanumerically
3. Recurse steps 1, 2, 3 in subfolders. Subfolders of subfolders take priority.

```lua
require "xloader"
xloader("xlib", function(f) include(f) end)

-- Breakdown:
-- First argument is the directory relative to the Lua mount path
-- Second argument is required boilerplate to make it autorefresh-aware. View linked bug report above.
```

## XLIB.Timer
This is an easy-to-use timing tool for basic profiling purposes.
`XLIB.Time(identifier)`
The identifier does not need to be unique. It will be used as a prefix for printing results.
It allows you to log different "stages" during the profiling process and will time each step.

If you want precise, multi-run profiling, check out [FProfiler](https://github.com/FPtje/FProfiler) instead.
The main goal of this small module is to isolate lenghty processes once you have already figured out the bottleneck.

```lua
    clock:Start()  -- Starts the timer. Optional, call :Log() to start as well. Returns clock object.
    clock:Log(event)  -- Logs an event at this point in time
    clock("evt")      -- Alias to clock:Log() allows for `clock "Something"`
    clock:Print(...)  -- Queues the print to be printed with prefix at the end of execution.
                      -- It will print instantly if the clock is not started

    clock:Finish()    -- Finishes the timer and prints out the results

```

```lua
-- If you intend to re-use this clock, you can store it locally outside this scope
-- local clock = XLIB.Time("pairs vs ipairs vs for")
-- then call start in your event loop or something
-- clock:Start()

-- Alternatively, :Start() will return the clock object as well for one seamless operation
local clock = XLIB.Time("pairs vs ipairs vs for"):Start()

local b = 0
local str = string.rep("TEST", 10^3)
local t = {}
for i=1, 1000 do
    table.Add(t, {string.byte(str, 1, str:len())})
end

-- Clock:Print(...) will defer printing (with timer prefix) to the end of the
-- timing process to keep the output linear and to reduce I/O bottlenecks
clock:Print("Testing with", #t, "iterations")

-- Call :Log() after an action to add a memo at this particular timestamp
-- Calling :Log() will also call :Start() if it has not yet been started.
clock:Log("Build test data")

b = 0
for k, v in pairs(t) do
    b = b + v
end
clock:Log("pairs")

b = 0
for k, v in ipairs(t) do
    b = b + v
end
clock:Log("ipairs")

b = 0
for i=1, #t do
    b = b + t[i]
end
clock "for"  -- Using alternative, faster to write for quick iterations

b = 0
local l = #t
for i=1, l do
    b = b + t[i]
end
clock "for w/ cached len"

clock:Finish()

```

Output
```

[pairs vs ipairs vs for]  Testing with 4000000 iterations
[pairs vs ipairs vs for]  Build test data took 0.879236  - T+0.879236
[pairs vs ipairs vs for]  pairs took 0.023838  - T+0.903073
[pairs vs ipairs vs for]  ipairs took 0.004902  - T+0.907975
[pairs vs ipairs vs for]  for took 0.005205  - T+0.91318
[pairs vs ipairs vs for]  for w/ cached len took 0.003529  - T+0.916708
[pairs vs ipairs vs for]  Finished in  0.91671
```

## NetWrapper
This library packages my fork of [netwrapper](https://github.com/xaviergmail/netwrapper).

NetWrapper is a lightweight, bandwidth-focused wrapper around the existing `net` library. You can view its documentation [here](./lua/xlib/netwrapper) as well as examples [here](./lua/xlib/netwrapper/example.lua)



## XLIB Extended
This is a part of XLIB disabled by default for use in packaged applications.
To enable, simply set `extended "1"` in your `CREDENTIAL_STORE`

The current features include:
### DevCommand
`DevCommand(cmdname, callback(ply, cmd, args, arg_str), realm=SERVER)`

This requires a function `IsDeveloper` (not provided by XLIB at this time) to be present on the Player metatable.
Functionally similar to concommand.Add, this takes care of the boilerplate of doing concommand authentication.

XLIB Extended also ships with two DevCommands: **`lua`** and **`luacl`**
These evaluate the passed string on either the server or client without needing RCON access or sv_allowcslua=1 respectively.

When executing the server-side `lua` command, any output from `print`, `Msg`, `MsgC`, `PrintTable` will be redirected to the client's console.
This is also true for any syntax or runtime errors.

It also provides some useful shorthand globals to help you avoid the low character count restriction:

| Name        | Object                     |
|-------------|----------------------------|
| me (SERVER) | Player running the command |
| me (CLIENT) | LocalPlayer()              |
| metr        | me:GetEyeTrace()           |
| metrent     | me:GetEyeTrace().Entity    |


### gmod-sentry
This library packages [gmod-sentry](https://github.com/Lexicality/gmod-sentry) with CREDENTIAL_STORE support for convenience.

To enable, simply add and customize the following to your `GarrysMod/garrysmod/CREDENTIAL_STORE` file
```
sentry
{
    dsn "https://dsn_example@sentry.io/dsn_example"
    // auto "false"

    // The following are all optional, this is passed directly to sentry.Setup
    options {
        server_name "Sandbox-1"
        environment "Production"
        // release ""

        // tags {
        //     foo "bar"
        // }

        // no_detour "hook.Call net.Receive"  // space-separated
    }
}
```

View [gmod-sentry Setup Options](https://github.com/Lexicality/gmod-sentry/blob/36f8899963c4c55898a433662c0f71c28aeb0488/README.md#sentrysetup) for more documentation on the sentry options.

Alternatively, if you want to have dynamic control over the `sentry.Setup` call, set `auto "false"` and use the following code:
```lua
require "credentialstore"
require "xlib_sentry"

if CREDENTIALS.sentry then
    local options = CREDENTIALS.sentry.options or {}

    options.release = (GM or GAMEMODE).Version  -- Or anything else
    sentry.Setup(CREDENTIALS.sentry.dsn, options)
end
```


# Contributing
If you would like to contribute, feel free to create a pull request. As this is a personal project, I can't guarantee that every request will be merged. However, if it benefits the project, I will gladly consider it.

I'm not enforcing any strict code guidelines as this project is already all over the place but please try to match the project's dominant style.

If you would like to enable autorefresh support while modifying XLib files themselves, create an empty file named `XLIB_AUTOLOAD` inside the `garrysmod` directory.
