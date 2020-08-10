file = {
	"includes/modules",
--	"xlib",
--	"xlib_extended",
--	exclude = {"xlib/thirdparty"}
}

module_file = {
	CredentialStore = "includes/modules/credentialstore.lua",
	GDBC = "includes/modules/gdbc.lua",
    LuaSocket = "includes/modules/luasocket.lua",
    MapManager = "includes/modules/mapmanager.lua",
    MimeForLua = "includes/modules/mime.lua",
    MobDebug = "includes/modules/moddebug.lua",
    Redis = "includes/modules/redis.lua",
    SentryForGMOD = "includes/modules/xlib_sentry.lua",
    xLoader = "includes/modules/xloader.lua"
}

dir = "docs/html"
project = "XLib"
title = "A collection of snippets and tools for Garry's Mod development "

no_space_before_args = true
style = "docs/css"
template = "docs/templates"
format = "markdown"
ignore = true
topics = "docs/manual"
use_markdown_titles = true
kind_names = {module = "Modules", topic = "Manual"}
merge = true
sort = true

custom_tags = {
	{"realm", hidden = true},
	{"internal", hidden = true}
}

new_type("hooks", "Hooks", true)
new_type("panel", "Panels", true)


tparam_alias("query", "Query")
tparam_alias("callback", "Callback")
tparam_alias("module", "Module")

tparam_alias("string", "string")
tparam_alias("bool", "boolean")
tparam_alias("func", "function")
tparam_alias("player", "Player")
tparam_alias("entity", "Entity")
tparam_alias("color", "color")
tparam_alias("tab", "table")
tparam_alias("material", "material")
tparam_alias("vector", "vector")
tparam_alias("angle", "angle")