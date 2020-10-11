using RecipesBase
using Setfield
getLensParam(lens::Setfield.PropertyLens{F}) where F = F
getLensParam(::Setfield.IdentityLens) = :p
getLensParam(::Setfield.IndexLens{Tuple{Int64}}) = :p

@recipe function f(contres::BranchResult; plotfold = true, putbifptlegend = true, filterbifpoints = false, vars = nothing, plotstability = true, plotbifpoints = true, branchlabel = "")
	colorbif = Dict(:fold => :black, :hopf => :red, :bp => :blue, :nd => :magenta, :none => :yellow, :ns => :orange, :pd => :green)
	axisDict = Dict(:p => 1, :sol => 2, :itnewton => 3, :ds => 4, :theta => 5, :step => 6)
	# Special case labels when vars = (:p,:y,:z) or (:x) or [:x,:y] ...
	if typeof(vars) <: Tuple && (typeof(vars[1]) == Symbol && typeof(vars[2]) == Symbol)
		ind1 = vars[1]
		ind2 = vars[2]
	elseif typeof(vars) <: Tuple && (typeof(vars[1]) <: Int && typeof(vars[2]) <: Int)
		ind1 = vars[1]
		ind2 = vars[2]
	else
		ind1 = :param
		ind2 = getfirstusertype(contres)
	end

	@series begin
		if length(contres.stability) > 2 && plotstability
			linewidth --> map(x -> isodd(x) ? 2.0 : 1.0, contres.stability)
		end
		if ind1 == 1
			xguide --> getLensParam(contres.param_lens)
		end
		label --> branchlabel
		getproperty(contres.branch, ind1), getproperty(contres.branch, ind2)
	end

	# display bifurcation points
	bifpoints = vcat(contres.bifpoint, filter(x->x.type != :none, contres.foldpoint))
	if length(bifpoints) >= 1 && plotbifpoints
		id = 1
		bifpoints[1].type == :none ? id = 2 : id = 1
		if plotfold
			bifpt = bifpoints[id:end]
		else
			bifpt = filter(x -> x.type != :fold, bifpoints[id:end])
		end
		if filterbifpoints == true
			bifpt = filterBifurcations(bifpt)
		end
		@series begin
			seriestype := :scatter
			seriescolor --> map(x -> colorbif[x.type], bifpt)
			markershape --> map(x -> x.status == :guess ? :square : :circle, bifpt)
			markersize --> 2
			markerstrokewidth --> 0
			label --> ""
			map(x -> getproperty(x, ind1), bifpt), map(x -> getproperty(x.printsol, ind2), bifpt)
		end
		# add legend for bifurcation points
		if putbifptlegend && length(bifpoints) >= 1
			bps = unique(x -> x.type, [pt for pt in bifpt if pt.type != :none])
			(length(bps) == 0) && return
			for pt in bps
				@series begin
					seriestype := :scatter
					seriescolor --> colorbif[pt.type]
					label --> "$(pt.type)"
					markersize --> 2
					markerstrokewidth --> 0
					[getproperty(pt,ind1)], [getproperty(pt.printsol, ind2)]
				end
			end
		end

	end
end

@recipe function Plots(brs::BranchResult...; plotfold = true, putbifptlegend = true, filterbifpoints = false, vars = nothing, pspan=nothing, plotstability = true, plotbifpoints = true, branchlabel = repeat([""],length(brs)))
	colorbif = Dict(:fold => :black, :hopf => :red, :bp => :blue, :nd => :magenta, :none => :yellow, :ns => :orange, :pd => :green)
	if length(brs) == 0; return; end
	# bp = unique([pt.type for pt in brs[1].bifpoint])
	bp = unique(x -> x.type, [(type = pt.type, param = pt.param, x = pt.printsol[1]) for pt in brs[1].bifpoint if pt.type != :none])
	for (id,res) in enumerate(brs)
		@series begin
			putbifptlegend --> false
			plotfold --> plotfold
			plotbifpoints --> plotbifpoints
			plotstability --> plotstability
			branchlabel --> branchlabel[id]
			xguide --> getLensParam(res.param_lens)
			for pt in res.bifpoint
				pt.type!=:none && push!(bp, (type = pt.type, param = pt.param, x = pt.printsol[1]))
			end
			res
		end
	end
	# add legend for bifurcation points
	if putbifptlegend && length(bp) > 0
		for pt in unique(x -> x.type, bp)
			@series begin
				seriestype := :scatter
				seriescolor --> colorbif[pt.type]
				label --> "$(pt.type)"
				markersize --> 2
				markerstrokewidth --> 0
				[pt.param], [pt.x]
			end
		end
	end
end


####################################################################################################
"""
Plot the branch of solutions during the continuation
"""
function plotBranchCont(contres::ContResult, sol::BorderedArray, contparms, plotuserfunction)
	colorbif = Dict(:fold => :black, :hopf => :red, :bp => :blue, :nd => :magenta, :none => :yellow, :ns => :orange, :pd => :green)

	l = computeEigenElements(contparms) ? (Plots.@layout [a{0.5w} [b; c]; e{0.2h}]) : Plots.@layout [a{0.5w} [b; c]]
	Plots.plot(layout = l)

	plot!(contres ; filterbifpoints = true, putbifptlegend = false,
		xlabel = getLensParam(contres.param_lens),
		ylabel = getfirstusertype(contres),
		label = "", plotfold = false, subplot = 1)

		# put arrow to indicate the order of computation
	length(contres) > 1 &&	plot!([contres.branch[end-1:end].param], [getproperty(contres.branch,1)[end-1:end]], label = "", arrow = true, subplot = 1)

	plot!(contres;	vars = (:step, :param), putbifptlegend = false, plotbifpoints = false, xlabel = "step", ylabel = getLensParam(contres.param_lens), label = "", subplot = 2)

	if computeEigenElements(contparms)
		eigvals = contres.eig[end].eigenvals
		scatter!(real.(eigvals), imag.(eigvals), subplot=4, label = "", markerstrokewidth = 0, markersize = 3, color = :black)
	end

	plotuserfunction(sol.u, sol.p; subplot = 3)
	display(title!(""))
end

function filterBifurcations(bifpt)
	# this function filters Fold points and Branch points which are located at the same/previous/next point
	length(bifpt) == 0 && return bifpt
	res = [(type = :none, idx = 1, param = 1., printsol = bifpt[1].printsol, status = :guess)]
	ii = 1
	while ii <= length(bifpt) - 1
		if (abs(bifpt[ii].idx - bifpt[ii+1].idx) <= 1) && bifpt[ii].type ∈ [:fold, :bp]
			if (bifpt[ii].type == :fold && bifpt[ii].type == :bp) ||
				(bifpt[ii].type == :bp && bifpt[ii].type == :fold)
				push!(res, (type = :fold, idx = bifpt[ii].idx, param = bifpt[ii].param, printsol = bifpt[ii].printsol, status = bifpt[ii].status) )
			else
				push!(res, (type = bifpt[ii].type, idx = bifpt[ii].idx, param = bifpt[ii].param, printsol = bifpt[ii].printsol, status = bifpt[ii].status) )
				push!(res, (type = bifpt[ii+1].type, idx = bifpt[ii+1].idx, param = bifpt[ii+1].param, printsol = bifpt[ii+1].printsol,status = bifpt[ii].status) )
			end
			ii += 2
		else
			push!(res, (type = bifpt[ii].type, idx = bifpt[ii].idx, param = bifpt[ii].param, printsol = bifpt[ii].printsol, status = bifpt[ii].status) )
			ii += 1
		end
	end
	0 < ii <= length(bifpt) &&	push!(res, (type = bifpt[ii].type, idx = bifpt[ii].idx, param = bifpt[ii].param, printsol = bifpt[ii].printsol, status = bifpt[ii].status) )

	return res[2:end]
end
