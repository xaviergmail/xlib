-- Credits: code_gs AKA github.com/Kefta
-- https://github.com/Facepunch/garrysmod/pull/847/

--[[ --------------------------------------------------------
--	Name:	TraceEntityOBB
--	Params:	<table tracedata> <ent entity> <bool quick> <bool verbose>
--	Returns: <table result> <table verboseresults>
--	Desc:	Traces using an entity's bounding box offset along a line.
--	"Quick" parameter skips tracing through every corner and only traces between the start corner and end corner.
--	"Verbose" parameter returns every trace performed in a table
--	WARNING: This traces lines between an ent's bounding box corners. Small entities may "slip through".
--	TraceData structure:
--		Vector mins: Offset mins (lower back left corner). Optional.
--		Vector maxs: Offset maxs (upper front right corner). Optional.
--		Vector start: Traces from this position, if you /really/ want to. Optional.
--		Vector endpos: Traces from the entity's position (or the starting position) to this position. Optional.
--		Entity filter: Things the trace should not hit. Can also be a table of entities or a function with one argument.
--		boolean ignoreworld: Should the trace ignore world or not
--		table output: If set, the trace result will be written to the supplied table instead of returning a new table
-----------------------------------------------------------]]
function util.TraceEntityOBB(tracedata, ent, quick, verbose)
	local mins, maxs = ent:GetCollisionBounds()
	mins = mins + (tracedata.mins or Vector())
	maxs = maxs + (tracedata.maxs or Vector())
	local corners = {
		mins, --back left bottom
		Vector(mins[1], maxs[2], mins[3]), --back right bottom
		Vector(maxs[1], maxs[2], mins[3]), --front right bottom
		Vector(maxs[1], mins[2], mins[3]), --front left bottom
		Vector(mins[1], mins[2], maxs[3]), --back left top
		Vector(mins[1], maxs[2], maxs[3]), --back right top
		maxs, --front right top
		Vector(maxs[1], mins[2], maxs[3]), --front left top
	}
	local out = {}
	local tr = {}
	for i = 1, #corners do
		if quick then
			util.TraceLine{
				start = LocalToWorld(corners[i], Angle(), tracedata.start or ent:GetPos(), ent:GetAngles()),
				endpos = LocalToWorld(corners[i], Angle(), tracedata.endpos or ent:GetPos(), ent:GetAngles()),
				mask = tracedata.mask,
				filter = tracedata.filter,
				ignoreworld = tracedata.ignoreworld,
				output = tr,
			}
			if verbose then
				out[#out + 1] = {}
				table.CopyFromTo(tr, out[#out])
			else
				if tr.Hit then
					if tracedata.output then
						table.CopyFromTo(tr, tracedata.output)
						break
					end
					return tr
				end
			end
		else
			for j = 1, #corners do
				if corners[i] == corners[j] then continue end
				util.TraceLine{
					start = LocalToWorld(corners[i], Angle(), tracedata.start or ent:GetPos(), ent:GetAngles()),
					endpos = LocalToWorld(corners[j], Angle(), tracedata.endpos or ent:GetPos(), ent:GetAngles()),
					mask = tracedata.mask,
					filter = tracedata.filter,
					ignoreworld = tracedata.ignoreworld,
					output = tr,
				}
				if verbose then
					out[#out + 1] = {}
					table.CopyFromTo(tr, out[#out])
				else
					if tr.Hit then
						if tracedata.output then
							table.CopyFromTo(tr, tracedata.output)
							break
						end
						return tr
					end
				end
			end
		end
	end
	for i = 1, #out do
		if out[i].Hit then
			return tr, out
		end
	end
	return tr
end

--[[ --------------------------------------------------------
--	Name:	TraceOBB
--	Params:	<table tracedata> <bool quick> <bool verbose>
--	Returns: <table result> <table verboseresults>
--	Desc:	Traces using a bounding box offset along a line.
--	"Quick" parameter skips tracing through every corner and only traces between the start corner and end corner.
--	"Verbose" parameter returns every trace performed in a table
--	WARNING: This traces lines between bounding box corners. Small entities may "slip through".
--	TraceData structure:
--		Vector mins: OBB mins (lower back left corner).
--		Vector maxs: OBB maxs (upper front right corner).
--		Angle angles: Angles of the OBB.
--		Vector start: The start position of the trace.
--		Vector endpos: The end position of the trace.
--		Entity filter: Things the trace should not hit. Can also be a table of entities or a function with one argument.
--		boolean ignoreworld: Should the trace ignore world or not
--		table output: If set, the trace result will be written to the supplied table instead of returning a new table
-----------------------------------------------------------]]
function util.TraceOBB(tracedata, quick, verbose)
	local mins, maxs = tracedata.mins, tracedata.maxs
	local corners = {
		mins, --back left bottom
		Vector(mins[1], maxs[2], mins[3]), --back right bottom
		Vector(maxs[1], maxs[2], mins[3]), --front right bottom
		Vector(maxs[1], mins[2], mins[3]), --front left bottom
		Vector(mins[1], mins[2], maxs[3]), --back left top
		Vector(mins[1], maxs[2], maxs[3]), --back right top
		maxs, --front right top
		Vector(maxs[1], mins[2], maxs[3]), --front left top
	}
	local out = {}
	local tr = {}
	for i = 1, #corners do
		if quick then
			util.TraceLine{
				start = LocalToWorld(corners[i], Angle(), tracedata.start, tracedata.angles),
				endpos = LocalToWorld(corners[i], Angle(), tracedata.endpos, tracedata.angles),
				mask = tracedata.mask,
				filter = tracedata.filter,
				ignoreworld = tracedata.ignoreworld,
				output = tr,
			}
			if verbose then
				out[#out + 1] = {}
				table.CopyFromTo(tr, out[#out])
			else
				if tr.Hit then
					if tracedata.output then
						table.CopyFromTo(tr, tracedata.output)
						break
					end
					return tr
				end
			end
		else
			for j = 1, #corners do
				if corners[i] == corners[j] then continue end
				util.TraceLine{
					start = LocalToWorld(corners[i], Angle(), tracedata.start, tracedata.angles),
					endpos = LocalToWorld(corners[j], Angle(), tracedata.endpos, tracedata.angles),
					mask = tracedata.mask,
					filter = tracedata.filter,
					ignoreworld = tracedata.ignoreworld,
					output = tr,
				}
				if verbose then
					out[#out + 1] = {}
					table.CopyFromTo(tr, out[#out])
				else
					if tr.Hit then
						if tracedata.output then
							table.CopyFromTo(tr, tracedata.output)
							break
						end
						return tr
					end
				end
			end
		end
	end
	for i = 1, #out do
		if out[i].Hit then
			return tr, out
		end
	end
	return tr
end
