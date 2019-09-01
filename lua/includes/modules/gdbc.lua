local MySQLOO_MetaName = "MySQLOO table"

local function IsMySQLOODB(tbl)
	local mt = istable(tbl) and getmetatable(tbl) or {}
	return mt and istable(mt) and mt.MetaName == MySQLOO_MetaName
end

if not mysqloo then
    require("mysqloo")
end

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

file.Write("query_log.txt", "")
local concat = table.concat
local function log(identifier, ...)
	local args = {...}

	local str = ("[%s] %s\n\n"):format(identifier, concat(args, ", "))

	print(str)
	file.Append("query_log.txt", str)
end

GDBC_LOG = false
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
	elseif !IsMySQLOODB(self.sequence.database) then
		error("Sequence has invalid database?? Aborting.\n")
	end

	if type(self.query) == "function" then
		self.formatargs = {...}
		self.sql = self.query(...)
	elseif type(self.query) == "string" then
		self.sql = self.query
	else
		error("Wrong query type. Expected 'function' or 'string' but got "..type(self.query).."\n")
	end

	local id = os.time()

	-- TODO: Switch to **actual** prepared statements
	local sql = ""
	local l = #self.sql
	for i=1, l do
		local c = self.sql[i]
		if c == '?' then
			local s = table.remove(self.formatargs, 1)
			if isstring(s) then
				s = self.sequence.database:escape(s)
			end

			sql = sql .. "'" .. s .. "'"
		else
			sql = sql .. c
		end
	end
	if GDBC_LOG then
		log(id, "Executing Query: "..sql)
		traceback = debug.traceback()
	end

	local query = self.sequence.database:query(sql)

	function query.onAborted(q)
	end

	function query.onError(q, err, sql)
	 	local args = {err, sql}
 		log(id, "FAILED:\n"..SPrintTable(args).."\n")
 		self:onFailure(err, sql, traceback)
	end

	function query.onSuccess(q, data)
		if not self.all then
			if #data == 0 then
				data = falsen
			else
				data = data[1]
			end
		end

	 	self:onSuccess(data, q:lastInsert())
	end

	function query.onData(q, data)
	end

	query:start()
end


Query.__index = Query
setmetatable(Query,
{
	__call = function(_, sequence, query, all, format, ...)
		return setmetatable(
			{
				sequence = sequence,
				query = query,
				all = all,
				format = format,
				formatargs = {...},
				data = sequence.data,
			}, Query)
	end
})

local QuerySequence = {}
function QuerySequence:___stringwrap(func)
	return function(_, str, ...)
		if type(str) == "string" then
			local args = {...}

			return setmetatable({},
			{
				__call = function(t, arg, ...)
					func(self, str, arg, ...)
					return self
				end,
				__index = function(t, k)
					func(self, nil, str, unpack(args))

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
end

function QuerySequence:_exec_sw(str, data)

	self.data = data or {}

	self.__query_idx = 0

	local args = {}
	if self.data.args then
		args = self.data.args
	end

	self:proceed(str, unpack(args))
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
	return function(tbl)
		table_insert(tbl, make_config_table())
		table_insert(tbl, make_config_migration())

		local _schema = {name=name, migrations={}}
		for k, v in pairs(tbl) do
			if IsMySQLOODB(v) then
				_schema.database = v
			elseif v then
				if getmetatable(v) and getmetatable(v).mtID == migration_mt.mtID then
					_schema.migrations[v.id] = v.query
				else
					_schema[v[1]] = v[2]
				end
			else
				Error("GDBC: Could not connect to database!")
			end
		end
		setmetatable(_schema, schema_mt)
		DB.__schemas[name] = _schema
	end
end

local function connect(i)
	if !mysqloo then return end
	local db = mysqloo.connect(i.host, i.user, i.pass, i.database, i.port)


	function db:onConnected(err)
		print(i.database..": Connected!")
	end

	function db:onConnectionFailed(err)
		Error("Database '"..i.database.."' - connection failed with username ".. i.user .."\n")
	end

    db:connect()

	return db
end

local function prepare(query, ...)
	local format = {...}
	local count = 0
	for _ in string.gfind(query, "?") do
		count = count + 1
	end

	if #format ~= count then
		error(string.format("DB: Prepared statement called with improper argument count: expected %d but got %d instead.\n %s", count, #format, debug.traceback()))
	end

	return query, unpack(format)
end

local function escape(str)
	if isnumber(str) then return str end
	return str:gsub("'", "\\'")
end

local table_funcs = {}

function table_funcs:prepare(query, ...)
	if self.__queries[query] then
		local query = self.__queries[query]
		local build = ""

		local len = string.len(query)

		local idx = 1
		local formatargs = {...}

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
				return prepare(t.__queries[k], ...)
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
		for k, v in pairs(tbl) do
			v = v:gsub("__T__", name):gsub("%s+", " ")

			if v:sub(v:len()) != ";" then
				v = v..";"
			end
			tbl[k] = v
		end
		_table = {}
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

hook.Add("Initialize", "InitSchemas", function()
	local oSchema = _G.schema
	local oTable = _G.table
	local oConnect = _G.connect
	local oMigration = _G.migration

	_G.schema = schema
	_G.table = table
	_G.connect = connect
	_G.migration = migration

	local succ, err = pcall(hook.Run, "GDBC:InitSchemas")

	_G.schema = oSchema
	_G.table = oTable
	_G.connect = oConnect
	_G.migration = oMigration

	if not succ then
		ErrorNoHalt("GDBC:InitSchemas failed "..err)
	end

	for k, v in pairs(DB.__schemas) do
		perform_migrations(v)
	end

	local hibernate = GetConVar("sv_hibernate_think")
	local changedTo = 31337  -- magic number to avoid collisions
	local origHibernate = hibernate:GetString()
	local changedHibernate = false
	if not hibernate:GetBool() then
		changedHibernate = true
		RunConsoleCommand(hibernate:GetName(), changedTo)
	end

	hook.Add("Think", "GDBC:PollMigrations", function()
		for k, v in pairs(DB.__schemas) do
			if not v.MIGRATIONS_COMPLETED then return end
		end

		if changedHibernate and hibernate:GetInt() == changedTo then
			RunConsoleCommand(hibernate:GetName(), origHibernate)
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
	    db()
	        :queryrawall (db.migrations[id])
	            :success(function()
	            	log("Migration query successful: ", id)
	                return "updateDatabaseVersion", id
	            end)

	        :query "updateDatabaseVersion" (db.config.updateDatabaseVersion)
		        :success(on_migration_completed)

	        :exec()
	end

	check_migrations(0)
end

print("GDBC Wrapper loaded")
