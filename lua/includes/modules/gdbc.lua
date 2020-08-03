-- TODO: Handle promising queries running on Shutdown
-- Implementation:
--  - Currently running query list (to :wait())
--  - Currently running or queued up query sequences
--  - :wait() on every running query and subsequent queries

require "xlib"

GDBC = GDBC or {}

local MySQLOO_MetaName = "MySQLOO table"

-- Current context when calling _G.schema()
local context = {}

local function IsMySQLOODB(tbl)
	local mt = istable(tbl) and getmetatable(tbl) or {}
	return mt and istable(mt) and mt.MetaName == MySQLOO_MetaName
end

if not mysqloo then
	require("mysqloo")
end

if (mysqloo.VERSION != "9") then
	error("Using outdated mysqloo version")
end

local fakedelay = CreateConVar("gdbc_fakedelay", "0", FCVAR_NONE, "Sets the latency in milliseconds to delay MySQL callbacks by", 0, 30)
local fakelag = CreateConVar("gdbc_fakelag", "0", FCVAR_NONE, "Sets the latency in milliseconds to SLEEP() by to simulate slow queries", 0, 30)

local DB =
{
	__schemas = _G.DB and _G.DB.__schemas or {}
}
_G.DB = DB

local DB_mt =
{
	__index = function(t, k)
		if t.__schemas and t.__schemas[k] then
			return t.__schemas[k]
		end
		return rawget(t, k)
	end,

	__newindex = function(t, k, v)
		if k == "__schemas" then return end
		rawset(t, k, v)
	end,

	__metatable = true,
}

if not getmetatable(DB) then setmetatable(DB, DB_mt) end

file.Append("query_log.txt", "\n\n\n\n"..util.DateStamp().."\n")
local concat = table.concat
local function log(identifier, ...)
	local args = table.PackNil(...)

	local str = ("[%s] %s\n\n"):format(identifier, concat(args, ", "))

	print(str)
	file.Append("query_log.txt", str)
end

GDBC_LOG = GDBC_LOG

if DevCommand then
	DevCommand("gdbc_log", function()
		GDBC_LOG = not GDBC_LOG
		print("GDBC Log is now ", GDBC_LOG and "ACTIVE" or "inactive")
	end)
end

local traceback = ""

local Query =
{
	sequence = nil,
	query = nil,
	proceed = false,
	success_callback = function() end,
	result_callback = function() end,
	empty_callback = function() end,
	failure_callback = function() end,
}

function Query:checkProceed(result, ...)
	if result != nil then
		self.sequence:proceed(result, ...)
		return true
	end
end

function Query:onSuccess(result, last_insert)
	local stop
	if result then
		for k, v in pairs(result) do
			if istable(v) then
				for k2, v2 in pairs(v) do
					if tonumber(v2) then
						v[k2] = tonumber(v2)
					end
				end
			elseif tonumber(v) then
				result[k] = tonumber(v)
			end
		end
		stop = self:checkProceed(self:result_callback(result, last_insert))
	else
		stop = self:checkProceed(self:empty_callback(last_insert))
	end
	if not stop then
		self.sequence:proceed(self:success_callback(result, last_insert))
	else
		self:success_callback(result, last_insert)
	end
end

function Query:onFailure(_error, sql_str, traceback)
	self:checkProceed(self:failure_callback(_error, sql_str, traceback))
end

function Query:get(k)
	return self.sequence:get(k)
end

function Query:set(k, v)
	self.sequence:set(k, v)
end

function Query:run(...)
	if not self.sequence then
		error("Query has invalid sqeuence?? Aborting.\n")
	elseif not IsMySQLOODB(self.sequence.database) then
		error("Sequence has invalid database?? Aborting.\n")
	end

	local shouldLog = self.sequence.shouldLog or GDBC_LOG

	local db = self.sequence.database

	if isfunction(self.query) then
		self.formatargs = table.PackNil(...)
		self.sql = self.query(...).sql
	elseif isstring(self.query) then
		self.sql = self.query
	elseif not istable(self.query) then
		error("Wrong query type. Expected 'function' or 'string' but got "..type(self.query).."\n")
	end

	local id = os.time()

	local usePrepared = not fakelag:GetBool() and db.usePreparedStatements
	local query
	local sql = self.sql or ""
	local traceback = ""

	if usePrepared and self.prepared then
		local conn = db:getLeastOccupiedDB()
		local connid = conn.ConnectionID

		query = self.prepared[connid]

		if query then
			if shouldLog then
				local data = self.sql.."\nArgs: "..SPrintTable(self.formatargs)
				log(id, "Executing Prepared Statement:\n"..data)
				traceback = "Prepared Statement:\n"..data.."\nTraceback:\n"..debug.traceback()
			end

			for k, v in ipairs(self.formatargs) do
				local t = TypeID(v)
				if t == table.NIL then
					query:setNull(k)
				elseif tonumber(v) then
					query:setNumber(k, tonumber(v))
				elseif isbool(v) then
					query:setBool(k, v)
				elseif isstring(v) then
					query:setString(k, v)
				else
					error("GDBC: Tried to pass invalid argument to prepared query of type "..type(v))
				end
			end
		end
	end

	if shouldLog then
		print("Query had", format, query, self.query)
	end

	if self.format and not query then
		-- TODO: Switch to **actual** prepared statements
		sql = ""
		local l = #self.sql
		for i=1, l do
			local c = self.sql[i]
			if c == '?' then
				local s = table.remove(self.formatargs, 1)
				if s == table.NIL then
					s = 'NULL'
				elseif isstring(s) then
					s = self.sequence.database:escape(s)
				end

				sql = sql .. "'" .. s .. "'"
			else
				sql = sql .. c
			end
		end
	end

	if not query then
		if fakelag:GetBool() then
			sql = sql .. "; DO SLEEP("..(fakelag:GetInt()/1000)..");"
		end

		if shouldLog then
			log(id, "Executing Query:\n"..sql)
			traceback = debug.traceback()
		end


		query = self.sequence.database:query(sql)
	end

	function query.onAborted(q)
	end

	function query.onError(q, err, sql)
		local e = err:Trim():lower()
		if e:match("connection was killed") or err:match("gone away") or err:match("can't connect") then
			ErrorNoHalt("GDBC: Connection to SQL server was lost. ("..err..")\nRe-running query:\n"..sql)
			q:start()
			return
		end

		if e:match("wsrep has not yet prepared node for application use") then
			hook.Run("GDBC:Error", err:Trim())
		end

	 	local args = {err=err, sql=sql, traceback=traceback}
	 	local str = "GDBC Query FAILED:\n"..SPrintTable(args).."\n"
 		log(id, str)
 		hook.Run("Log::Error", { text = str })

 		if fakedelay:GetBool() then
	 		timer.Simple(fakedelay:GetInt()/1000, function() self:onFailure(err, sql, traceback) end)
 		else
	 		self:onFailure(err, sql, traceback)
	 	end
	end

	function query.onSuccess(q, data)
		if not self.all then
			if #data == 0 then
				data = falsen
			else
				data = data[1]
			end
		end

	 	if fakedelay:GetBool() then
		 	timer.Simple(fakedelay:GetInt()/1000, function() self:onSuccess(data, q:lastInsert()) end)
	 	else
		 	self:onSuccess(data, q:lastInsert())
		 end
	end

	function query.onData(q, data)
	end

	query:start()
end


Query.__index = Query
setmetatable(Query,
{
	__call = function(_, sequence, query, all, format, ...)
		local formatargs = table.PackNil(...)
		local prepared

		if istable(query) then
			prepared = query.prepared
			formatargs = query.formatargs
			query = query.sql
		end

		return setmetatable(
			{
				sequence = sequence,
				query = query,
				all = all,
				format = format,
				formatargs = formatargs,
				data = sequence.data,
				prepared = prepared,
			}, Query)
	end
})

local QuerySequence = {}
function QuerySequence:___stringwrap(func)
	return function(_, str, ...)
		if type(str) == "string" then
			local args = table.PackNil(...)

			return setmetatable({},
			{
				__call = function(t, arg, ...)
					func(self, str, arg, ...)
					return self
				end,
				__index = function(t, k)
					func(self, nil, str, table.UnpackNil(args))

					local v = self[k]

					if type(v) ~= "function" then return v end
					return function(_t, ...)
						return _t == t and v(self, ...) or v(_t, ...)
					end
				end,
				__newindex = t,
			})
		else
			func(self, nil, str, ...)
			return self
		end
	end
end

function QuerySequence:___addquery(str, _query, all, format, ...)
	local query = Query(self, _query, all, format, ...)
	self.__cur_query = query

	if str then
		self.__queries[str] = query
	else
		table.insert(self.__queries, query)
	end

	return self
end

function QuerySequence:_queryraw_sw(str, query)
	return self:addquery(str, query, false, false)
end

function QuerySequence:_queryrawall_sw(str, query)
	return self:addquery(str, query, true, false)
end

function QuerySequence:_query_sw(str, query, ...)
	return self:addquery(str, query, false, true, ...)
end

function QuerySequence:_queryall_sw(str, query, ...)
	return self:addquery(str, query, true, true, ...)
end

function QuerySequence:_success_(func)
	self.__cur_query.success_callback = func
	return self
end

function QuerySequence:_result_(func)
	self.__cur_query.result_callback = func
	return self
end

function QuerySequence:_empty_(func)
	self.__cur_query.empty_callback = func
	return self
end

function QuerySequence:_fail_(func)
	self.__cur_query.failure_callback = func
	return self
end

function QuerySequence:_done_(func)
	self.__on_completed = func
	return self
end

function QuerySequence:_procedure_sw(str, func)
	if not str then return end
	self.__procedures[str] = func
	return self
end

function QuerySequence:_low_()
	if self.database.low then
		self.database = self.database.low
	else
		XLIB.WarnTrace("Query sequence tried to execute on low priority queue but did not ")
	end

	return self
end

function QuerySequence:_exec_sw(str, data)

	self.data = data or {}

	self.__query_idx = 0

	local args = {}
	if self.data.args then
		args = self.data.args
	end

	if self.throttle_data then
		XLIB.Throttle(self.throttle_data.identifier, self.throttle_data.time,
			f.apply(self.proceed, self, str, table.UnpackNil(args))
		)
	else
		self:proceed(str, table.UnpackNil(args))
	end
end

function QuerySequence:_throttle_(identifier, time)
	if identifier == false then
		self.throttle_data = nil
	else
		self.throttle_data = {identifier=identifier, time=time}
	end
	return self
end

function QuerySequence:_get_(k)
	if self.data then
		return self.data[k]
	end
end

function QuerySequence:_set_(k, v)
	if self.data then
		self.data[k] = v
	end
end

function QuerySequence:_log_()
	self.shouldLog = true
	return self
end

function QuerySequence.___splitargs(str)
	local ret = {}
	local last = 1

	for _start, _end in str:gmatch "() ()" do
		table.insert(ret, str:sub(last, _start - 1))
		last = _end
	end

	table.insert(ret, str:sub(last))
	return function()
		return table.remove(ret, 1)
	end
end

function QuerySequence:___proceed(identifier, ...)
	if identifier == false then return end

	local query

	if type(identifier) == "string" then
		if identifier == "break" then
			return
		end

		if self.__procedures[identifier] then
			return self:proceed(self.__procedures[identifier](self, ...))
		elseif self.__queries[identifier] then
			query = self.__queries[identifier]
		else
			error("Unknown query label \""..identifier.."\"\n")
		end
	elseif type(identifier) == "number" then
		if self.__queries[identifier] then
			query = self.__queries[identifier]
			self.__query_idx = identifier
		else
			error("Unknown query #"..identifier.."\n")
		end
	elseif identifier == nil or type(identifier) == "boolean" then
		self.__query_idx = self.__query_idx + 1
		if self.__queries[self.__query_idx] then
			query = self.__queries[self.__query_idx]
		else
			if self.__on_completed then
				self.__on_completed(self)
			end

			return
		end
	else
		error("Invalid query label type \""..type(identifier).."\"\n")
	end

	query:run(...)
end

local QuerySequence_mt =
{
	__index = function(t, k)
		if QuerySequence["_"..k.."_sw"] then --String Wrapped sequenceable functions
			local fn = QuerySequence["_"..k.."_sw"]
			return t:stringwrap(fn)
		end

			if QuerySequence["_"..k.."_"] then --Sequenceable functions
			local fn = QuerySequence["_"..k.."_"]
			return fn
		end

		if QuerySequence["___"..k] then --Internal functions
			local fn = QuerySequence["___"..k]
			return fn
		end

		return rawget(t, k)
	end;
}

local schema_mt =
{
	__call = function(t)
		if not t.database then
			error("DB: Attempt to run sequence without connection info!\n")
		end

		local sequence =
		{
			__queries = {};
			__query_idx = 0;
			__procedures = {};
			data = {};
			database = t.database;
		}
		setmetatable(sequence, QuerySequence_mt)

		return sequence
	end;

	__index = function(t, k)
		local db = rawget(t, "database")
		if db and db[k] then
			local v = db[k]
			if type(v) == "function" then
				return function(_, ...) v(db, ...) end
			end
			return v
		end
		return rawget(t, k)
	end;
}

local migration_mt = { mtID = "migration" }

local make_config_table, make_config_migration, perform_migrations
local table_insert = table.insert
local function schema(name)
	context = {name=name}
	return function(tbl)
		table_insert(tbl, make_config_table())
		table_insert(tbl, make_config_migration())

		local _schema = {name=name, migrations={}, tables={}}
		context.schema = _schema
		for k, v in pairs(tbl) do
			if IsMySQLOODB(v) then
				_schema.database = v
				context.database = v
			elseif v then
				if getmetatable(v) and getmetatable(v).mtID == migration_mt.mtID then
					_schema.migrations[v.id] = v.query
				else
					_schema[v[1]] = v[2]
					_schema.tables[v[1]] = v[2]
				end
			else
				Error("GDBC: Could not connect to database!")
			end
		end
		setmetatable(_schema, schema_mt)
		DB.__schemas[name] = _schema
	end
end

local function mysqloo_connect(connid, commitInterval, host, username, password, database, port, socket)
	local ctx = context -- Keep a reference as the global gets overwritten

	local db = mysqloo.connect(host, username, password, database, port, socket)
	db:setAutoReconnect(true)
	db.ConnectionID = connid
	db.getLeastOccupiedDB = function() return db end

	function db:onConnectionFailed(err)
		Error("Database '"..ctx.connect.database.."'["..connid.."] - connection failed with username ".. ctx.connect.user .."\n")
	end

	if commitInterval then
		local id = string.format("GDBC.TransactionCommit [%s][%s][%p]", ctx.name, tostring(connid), db)

		local q = db:query([[
			SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
			SET SESSION AUTOCOMMIT=0;
		]])

		function q:onSuccess() print(ctx.connect.database.."["..connid.."]: Initialized manual commit interval:", commitInterval) end
		function q:onError(err) ErrorNoHalt(ctx.connect.database.."["..connid.."]: Errored: "..err.."\n") end

		q:start()

		timer.Create(id, commitInterval, 0, function()
			if db:status() != mysqloo.DATABASE_CONNECTED then return end
			if GDBC_LOG then
				log(id, "Committing")
			end

			local q = db:query("COMMIT;")
			function q:onError(err) ErrorNoHalt(ctx.connect.database.."["..connid.."]: Errored while committing: "..err.."\n") end

			q:start()
		end)
	end

	function db:onConnected(err)
		db.usePreparedStatements = ctx.connect.usePreparedStatements

		local str = "!"
		if self.usePreparedStatements then
			for tblName, tbl in pairs(ctx.schema.tables) do
				for name, sql in pairs(tbl.__queries) do
					tbl.__prepared[name][self.ConnectionID] = self:prepare(sql)
				end
			end
		end

		print(ctx.connect.database.."["..connid.."]: Connected"..str)
	end

	db:connect()

	return db
end

local function connect(i)
	context.connect = i

	if !mysqloo then return end

	local threads = i.threads or 1
	local commitInterval = false

	if (tonumber(i.commitInterval) or 0) > 0 then
		commitInterval = tonumber(i.commitInterval)
	end

	local db
	if threads > 1 then
		db = mysqloo.CreateConnectionPool2(threads, commitInterval, i.host, i.user, i.pass, i.database, i.port)
	else
		db = mysqloo_connect(1, commitInterval, i.host, i.user, i.pass, i.database, i.port)
	end

	do
		low = mysqloo_connect("low", commitInterval, i.host, i.user, i.pass, i.database, i.port)
		db.low = low
	end
	return db
end

local function escape(str)
	if str == table.NIL then return 'NULL' end
	if isnumber(str) then return str end
	return str:gsub("'", "\\'")
end

local table_funcs = {}

-- XXX: Misnomer!! This doesn't _prepare_ a statement but rather formats and escapes
-- a query using prepared statement syntax `?` and returns the given SQL string.
function table_funcs:prepare(query, ...)
	if self.__queries[query] then
		local query = self.__queries[query]
		local build = ""

		local len = string.len(query)

		local idx = 1
		local formatargs = table.PackNil(...)

		for i = 1, string.len(query) do
			local c = string.sub(query, i, i)
			if c == '?' then
				local format = formatargs[idx]
				if not format then
					error("MISSING FORMAT ARGUMENT WHILE PREPARING QUERY")
				end

				c = string.format("'%s'", escape(format))

				idx = idx + 1
			end

			build = build .. c
		end
		return build;
	end
	error("Unknown Query: "..query)
end

local table_mt =
{
	__index = function(t, k)
		if t.__queries and t.__queries[k] then
			return function(...)
				local sql = t.__queries[k]

				local argcount = select('#', ...)
				local count = 0
				for _ in string.gfind(sql, "?") do
					count = count + 1
				end

				if argcount ~= count then
					error(string.format("DB: Prepared statement called with improper argument count: expected %d but got %d instead.\n %s", count, argcount, debug.traceback()))
				end

				return {sql=sql, formatargs=table.PackNil(...), prepared=t.__prepared[k]}
			end
		end

		if table_funcs[k] then
			return table_funcs[k]
		end
	end,
	__newindex = function() end,
	__metatable = true,
}

local function table(name)
	return function (tbl)
		_table = {}
		_table.__prepared = {}
		for queryName, sql in pairs(tbl) do
			_table.__prepared[queryName] = {}

			sql = sql:gsub("__T__", name):gsub("%s+", " ")

			if sql:Trim():sub(sql:len()) != ";" then
				sql = sql..";"
			end
			tbl[queryName] = sql
		end
		_table.__queries = tbl
		setmetatable(_table, table_mt)
		return {name, _table}
	end
end

local function migration(id)
	return function(sql)
		return setmetatable({id=id, query=sql}, migration_mt)
    end
end


local env = setmetatable({
	schema=schema,
	table=table,
	connect=connect,
	migration=migration,
}, {__index=_G})

local g = _G
function GDBC.LoadSchema(fname)
	setfenv(CompileFile(fname), env)()
end

function GDBC.InitSchemas()
	local succ, err = xpcall(hook.Run, debug.traceback, "GDBC:InitSchemas")

	if not succ then
		ErrorNoHalt("GDBC:InitSchemas failed "..err)
	end
end
DevCommand("gdbc_reload", GDBC.InitSchemas)

hook.Add("Initialize", "InitSchemas", function()
	GDBC.InitSchemas()

	for k, v in pairs(DB.__schemas) do
		perform_migrations(v)
	end

	RunConsoleCommand("sv_hibernate_think", 1)


	hook.Add("Think", "GDBC:PollMigrations", function()
		for k, v in pairs(DB.__schemas) do
			if not v.MIGRATIONS_COMPLETED then return end
		end


		hook.Remove("Think", "GDBC:PollMigrations")
		hook.Remove("CheckPassword", "GDBC:WaitForMigrations")
		hook.Run("GDBC:Ready")
	end)
end)

if not CHECKPASSWORD_DB then
	CHECKPASSWORD_DB = true
	hook.Add("CheckPassword", "GDBC:WaitForMigrations", function()
		return false, "Server is starting up. Try again in 30 seconds!"
	end)
end

function make_config_table()
	return
    table "config"
    {
        getDatabaseVersion =
        [[
        	SELECT `configInt`
            FROM `__T__`
            WHERE
                 `configName`='db_version'
        ]];

        updateDatabaseVersion =
        [[
        	REPLACE INTO `__T__`
            (configName, configInt)
            VALUES('db_version', ?)
        ]];

        getString =
        [[
			SELECT `configStr`, `configStr` as `value`
			FROM `__T__`
			WHERE
				`configName`=?
	    ]];

       	setString =
       	[[
       		REPLACE INTO `__T__`
       		(configName, configStr)
       		VALUES(?, ?)
       	]];

        getInt =
        [[
	        SELECT `configInt`
			FROM `__T__`
			WHERE
				`configName`=?
		]];

       	setInt =
       	[[
       		REPLACE INTO `__T__`
			(configName, configInt)
			VALUES(?, ?)
		]];

    }
end

function make_config_migration()
	return
	migration (0)
	[[
		CREATE TABLE IF NOT EXISTS `config` (
			`configName` VARCHAR(45) NOT NULL,
			`configInt` INT NULL,
			`configStr` TEXT NULL,
			PRIMARY KEY (`configName`))
		ENGINE = InnoDB;

	]]
end

function perform_migrations(db)
	local on_migration_completed
	local get_database_version
	local check_migrations
	local execute_migration

	local function log(...)
		print(db.name..": ", ...)
	end

	log("UpdateDBVersion", db.config.updateDatabaseVersion)

	function on_migration_completed()
	    log("Completed Migration")
	    get_database_version(check_migrations)
	end

	function get_database_version(callback)
	    db()
	        :query (db.config.getDatabaseVersion)
	            :result(function(self, row)
	                db.DATABASE_VERSION = tonumber(row['configInt'])
	                log("Got Database Version:", db.DATABASE_VERSION)
	                if callback then callback() end
	            end)
	            :fail(function(self, row)
					-- TODO: 1: Add error suppression support
					-- TODO: 2: Make this work without erroring to begin with
					log("EVERYTHING IS FINE! Ignore the `Table db.config doesn't exist` error above.")
	            	execute_migration(0)
            	end)


	        :exec()
	end

	function check_migrations()
	    if not db.DATABASE_VERSION then
	        log("Checking For Migrations!")
	        get_database_version(check_migrations)
	        return
	    end

	    local nxt = db.DATABASE_VERSION+1
	    if db.migrations[nxt] then
	        log("Executing Migration", nxt)
	        execute_migration(nxt)
	    else
	        log("Completed All Migrations!")
	        db.MIGRATIONS_COMPLETED = true
	    end
	end

	function execute_migration(id)
	    log("Running Migration", id)
	    local action = db.migrations[id]
	    if isstring(action) then
		    db()
		        :queryrawall (db.migrations[id])
		            :success(function()
		            	log("Migration query successful: ", id)
		                return "updateDatabaseVersion", id
		            end)

		        :query "updateDatabaseVersion" (db.config.updateDatabaseVersion)
			        :success(on_migration_completed)

		        :exec()
	    elseif isfunction(action) then
	    	action(db, function(success, reason)
	    		if success then
	    			db()
				        :query (db.config.updateDatabaseVersion(id))
					        :success(on_migration_completed)
				        :exec()

		            log("Migration function successful: ", id)
	    		else
	    			error("Migration "..id.."failed: "..reason)
	    		end
		    end)
	    end
	end

	check_migrations(0)
end



local spreadAttributes = { onConnected=true, onConnectionFailed=true }
local pool = {}
local poolMT = {
	MetaName = MySQLOO_MetaName,
	__index = function(t, k)
		if spreadAttributes[k] then
			return self._Connections[1][k]
		end
		return rawget(pool, k)
	end,
	__newindex = function(self, k, v)
		if spreadAttributes[k] then
			for _, db in ipairs(self._Connections) do
				db[k] = v
			end
		else
			rawset(self, k, v)
		end
	end
}

function mysqloo.CreateConnectionPool2(conCount, commitInterval, ...)
	if (conCount < 1) then
		conCount = 1
	end

	local newPool = setmetatable({}, poolMT)
	newPool._Connections = {}

	for i = 1, conCount do
		local db = mysqloo_connect(i, commitInterval, ...)
		db.ConnectionID = i
		table_insert(newPool._Connections, db)
	end

	return newPool
end

function pool:queueSize()
	local count = 0
	for _, v in pairs(self._Connections) do
		count = count + v:queueSize()
	end
	return count
end

function pool:abortAllQueries()
	for _, v in pairs(self._Connections) do
		v:abortAllQueries()
	end
end

function pool:getLeastOccupiedDB()
	local lowest = nil
	local lowestCount = 0
	for _, db in ipairs(self._Connections) do
		local queueSize = db:queueSize()
		if (not lowest or queueSize < lowestCount) then
			lowest = db
			lowestCount = queueSize
		end
	end

	if not lowest then
		error("Failed to find available database from connection pool")
	end

	return lowest
end

local overrideFunctions = {"escape", "query", "prepare", "createTransaction", "status", "serverVersion", "hostInfo", "serverInfo", "ping"}
for _, name in ipairs(overrideFunctions) do
	pool[name] = function(pool, ...)
		local db = pool:getLeastOccupiedDB()
		return db[name](db, ...)
	end
end

local spreadFunctions = {"setAutoReconnect", "setMultiStatements", "setCachePreparedStatements", "wait", "setCharacterSet", "connect", "disconnect"}
for _, name in ipairs(spreadFunctions) do
	pool[name] = function(pool, ...)
		for k, db in ipairs(pool._Connections) do
			db[name](db, ...)
		end
	end
end

-- Allows us to get the return values from these functions passed through a callback
local cbSpreadFunctions = {"setCharacterSets"}
for _, name in ipairs(cbSpreadFunctions) do
	local rets = {}
	pool[name] = function(pool, cb, ...)
		for k, db in ipairs(pool._Connections) do
			cb(k, db[name](db, ...))
		end
	end
end

print("GDBC Wrapper loaded")
