project="Xavier's Library"
title="Xavier's Library"
description=[[A collection of snippets and tools for Garry's Mod development. (Short for Xavier's Library)
Documentation is a work-in progress. Pull requests are welcome! Docs are generated with LDoc.
]]
format="markdown"
file={
	"lua/xlib/",
	"lua/includes/",
	exclude={
		"lua/xlib/thirdparty/sh_rxlua.lua",
	},
}
dir="docs"
not_luadoc=true
merge=true
style=true    -- use ./ldoc.css
template=true -- use ./ldoc.ltp