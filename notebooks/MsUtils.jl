
module MsUtils

using Compose, Colors, PGFPlots
import LujiaLt
FEM = LujiaLt.FEM

export binsum, fdtest, plot_domain, compose_bonds, compose_atoms, plot_int
export mat2tup, tup2mat
export compose_strain, compose_displacement, plot_strain

"""
`binsum(p, i, maxi)` returns an array `s` of length `maxi`
such that s[n] = sum_{ i[m] == n } p[m]

If the `maxi` argument is omitted, then `maxi = maximum(i)`.

This is a useful auxiliary function to implement forces.
"""
function binsum{TI <: Integer}(p::Vector, i::Vector{TI}, maxi::Integer)
    s = zeros(maxi)
    for n in 1:length(p)
        s[i[n]] += p[n]
    end
    return s
end

binsum{TI <: Integer}(p::Vector, i::Vector{TI}) = binsum(p, i, maximum(i))


"contruct a piecewise linear envelope of the data (x, y)"
function envelope(x, y, nbins)
    x0, x1 = extrema(x)
    xbin = collect(linspace(x0+1/(x1-x0), x1, nbins))
    ybin = minimum(y) * ones(nbins)
    for n = 1:length(y)
        ibin = ceil(Int, (x[n] - x0)/(x1-x0))
        ibin = min( max(ibin, 1), nbins)
        ybin[ibin] = max(ybin[ibin], y[n])
    end
    return xbin, ybin
end


"perform finite difference test for an energy functional, gradient and hessian"
function fdtest(U, energy_, grad_, hess_)
    E = energy_(U)
    ∇E = grad_(U)
    ∇²E = full(hess_(U))
    @printf("    h  | ∇E-error   ∇²E-error  \n")
    @printf("-------|----------------------- \n")
    for p = 2:12
        h = 0.1^p
        ∇E_h = zeros(∇E)
        ∇²E_h = zeros(∇²E)
        for n = 1:length(U)
            U[n] += h
            ∇E_h[n] = (energy_(U) - E) / h
            ∇²E_h[:,n] = (grad_(U) - ∇E) / h
            U[n] -= h
        end
        @printf(" %1.0e | %4.2e   %4.2e  \n",
                h, norm(∇E - ∇E_h, Inf), vecnorm(∇²E - ∇²E_h, Inf))
    end
    return nothing
end


############  PLOTTING  ###################

mat2tup(X::Matrix) = (X[1,:][:], X[2,:][:])
tup2mat(X::Tuple) = [X[1]'; X[2]']

"return a reasonable choice for the plotting axis"
autoaxis(X::Matrix) = autoaxis(mat2tup(X))
function autoaxis(X::Tuple)
    xLim = [extrema(X[1])...]
    width = xLim[2]-xLim[1]
    yLim = [extrema(X[2])...]
    height = yLim[2]-yLim[1]
    buffer = min( 1.0, 0.05 * width, 0.05 * height )
    xLim[1] -= buffer; xLim[2] += buffer
    yLim[1] -= buffer; yLim[2] += buffer
    return [xLim[1]; xLim[2]; yLim[1]; yLim[2]]
end

_ub_(axis) = UnitBox(axis[1], axis[3], axis[2]-axis[1], axis[4]-axis[3])
import Compose.context
context(axis::Vector) = context(units=_ub_(axis))


colfromname(name) = RGB( ([Colors.color_names[name]...]/255)... )
const red = colfromname("tomato")
const blue = colfromname("darkblue")
const alice = colfromname("aliceblue")
const green = colfromname("darkgreen")

edges2path(X, E) = insert_nans( [X[:, E[1,:][:]]; X[:, E[2,:][:]]] )
insert_nans(P) = reshape( [P; NaN * ones(2, size(P, 2))], 2, 3 * size(P, 2) )

mat2points(P::Matrix) = NTuple{2, Float64}[ tuple(P[:,n]...) for n = 1:size(P, 2) ]

function drawtofile(ctx, filename, ax, width)
    (filename[end-2:end] == "svg") && (img = auto_img(SVG, filename, ax, width))
    (filename[end-2:end] == "pdf") && (img = auto_img(PDF, filename, ax, width))
    (filename[end-2:end] == "png") && (img = auto_img(PNG, filename, ax, width))
    draw(img, ctx)
end

compose_atoms(X) = compose_atoms(X, [0.2;], 0.0, autoaxis(X), red)

draw_atoms(X) = draw(auto_img(SVG, autoaxis(X), 15cm),
                     compose(context(), compose_atoms(X)) )

compose_atoms(X, radii, lwidth, axis, col) =
    ( context(axis), circle(X[1,:][:], X[2,:][:], radii),
      stroke(col), linewidth(lwidth), fill(col) )

compose_bonds(X, B::Tuple, lwidth, col, axis) =
    compose_bonds(X, tup2mat(B), lwidth, col, axis)

compose_bonds(X, B::Matrix, lwidth, col, axis) =
    ( context(axis), line(mat2points(edges2path(X, B))),
      stroke(col), linewidth(lwidth) )


relative_height(ax, width) = (ax[4]-ax[3])/(ax[2]-ax[1]) * width
auto_img(ImgT, ax, width) = ImgT(width, relative_height(ax, width))
auto_img(ImgT, fname, ax, width) = ImgT(fname, width, relative_height(ax, width))


function compose_defint(axis)
   # a shaded polygon
   r = 0.4; a = sqrt(3)/2
   poly = [ (-0.5-r, 0.0); (0.0, -a-r); (0.5+r, 0.0); (0.0, a+r) ]
   return ( context(axis), polygon(poly), stroke("grey50"), fill("grey90") )
end

function plot_int(X, B, ee; axis=autoaxis(X), lwidth=0.6,
                  filename=nothing, printwidth = 10cm, plotwidth=15cm)
    # indices of defect atom and connected to defect
    Id = [ size(X,2) ] # B[1][find(B[2] .== size(X,2))];
    B = tup2mat(B)
    ctx = compose( context(axis),
                   # defect atoms
                   compose_atoms(X[:,Id], [0.15], 0.5, axis, red),
                   # homogeneous lattice atoms
                   compose_atoms(X, [0.15], 0.5, axis, blue),
                   # normal bonds
                   compose_bonds(X, B[:, find(abs(ee) .<= 1e-10)], lwidth, blue, axis),
                   # defect bonds
                   compose_bonds(X, B[:, find(abs(ee) .> 1e-10)], lwidth, red, axis),
                   # defect region
                   compose_defint(axis) )

    # draw the plot to a file
    if filename != nothing
        drawtofile(ctx, filename, axis, printwidth)
    end
    if plotwidth != nothing
        draw(auto_img(SVG, axis, plotwidth), ctx)
    end
    return ctx
end

_reflect_(x::Array) = [1 0; 0 -1] * x

function plot_screw(X, B, ee; axis=autoaxis(_reflect_(X)), lwidth=0.6,
                  filename=nothing, printwidth = 10cm, plotwidth=15cm,
                  ξ = [0.0;0.0]) # [0.5;sqrt(3)/6]
   X = _reflect_(X); ξ = _reflect_(ξ)
   B = tup2mat(B)
   ctx = compose( context(axis),
               # place holder for the defect core.
               compose_atoms(reshape(ξ, 2,1), [0.15], 0.5, axis, red),
               # homogeneous lattice atoms
               compose_atoms(X, [0.15], 0.5, axis, blue),
               # normal bonds
               compose_bonds(X, B, lwidth, blue, axis)
            )

    # draw the plot to a file
    if filename != nothing
        drawtofile(ctx, filename, axis, printwidth)
    end
    if plotwidth != nothing
        draw(auto_img(SVG, axis, plotwidth), ctx)
    end
    return ctx
end


"compute a color from a value, a color-axis and a color-map"
val2col(x, cmap, cax) = cmap[val2colidx(x, cmap, cax)]
val2colfidx(x, cax) = max(0, min((x-cax[1]) / (cax[2]-cax[1]), 1))
val2colidx(x, cmap, cax) = round(Int, 1 + (length(cmap)-1) * val2colfidx(x, cax))


function compose_strain(X, B, ee; axis=autoaxis(X), lwidth=0.6,
                  cmap = colormap("RdBu")[end:-1:1], caxis = extrema(ee))
    ctx = context(axis)
    for n = 1:length(ee)
        p = MsUtils.mat2points(X[:, [B[1][n];B[2][n]]])
        col = val2col(ee[n], cmap, caxis)
        ctx = compose(ctx,
                      ( context(axis),
                        line(p),
                        linewidth(lwidth),
                        stroke(col) )
                      )
    end
    return ctx
end


# compose_strain(m::AtmModel; ee=m.e, kwargs...) =
#     compose_strains(m.X, m.B, ee; kwargs...)


function compose_displacement(X, u; axis=autoaxis(X), lwidth=0.6,
                              cmap = colormap("RdBu")[end:-1:1],
                              caxis = extrema(ee), radius = 0.15 )
    ctx = context(axis)
    for n = 1:length(u)
        col = val2col(u[n], cmap, caxis)
        ctx = compose(ctx,
                      ( context(axis),
                        circle( [X[1,n];], [X[2,n];], [radius;] ),
                        linewidth(0.0),
                        fill(col) )
                      )
    end
    return ctx
end


function plot_strain(X, B, ee; axis=autoaxis(X), lwidth=0.6,
                     cmap = colormap("RdBu")[end:-1:1], caxis = extrema(ee),
                     filename=nothing, printwidth = 10cm, plotwidth=10cm,
                     radius=0.15)

      X = copy(X)
      X[2,:] = - X[2,:]

    ctx1 = compose_strain(X, B, ee, axis=axis, lwidth=lwidth,
                          cmap = cmap, caxis = caxis)
    nX = size(X,2)
    u = (1.0/6.0) * (binsum(ee, B[1], nX) + binsum(ee, B[2], nX))
    ctx2 = compose_displacement(X, u; axis=axis, lwidth=lwidth,
                                cmap=cmap, caxis=caxis, radius=radius)

    ctx = compose(context(axis), ctx2, ctx1)
    # draw the plot to a file or notebook
    if filename != nothing
        drawtofile(ctx, filename, axis, printwidth)
    end
    if plotwidth != nothing
        draw(auto_img(SVG, axis, plotwidth), ctx)
    end
    return ctx
end



"contruct a piecewise linear envelope of the data (x, y)"
function envelope(x, y, xbin)
    ybin = minimum(y) * ones(length(xbin))
    for n = 1:length(y)
        ybin[1] = max(ybin[1], y[n])
        for m = 1:length(xbin)
            if xbin[m] <= x[n]
                ybin[m] = max(ybin[m], y[n])
            end
        end
    end
    return xbin, ybin
end

envelope(x, y, nbins::Number) =
    envelope(x, y, linspace(extrema(x)..., nbins+1)[2:end])


plot_slope(x1, x2, c, s; col="black") =
    Plots.Linear([x1;x2], c*[x1;x2].^s, mark="none", style=col*", dotted, thick")



function plot_acgeom(ac; ξ=[0.0;0.0], axis=autoaxis(ac.X), lwidth=0.6,
                     filename=nothing, printwidth = 10cm, plotwidth=15cm)

   # node indices
   Ii = union(ac.Bi[1], ac.Bi[2])
   Ia = setdiff(union(ac.Bat[1], ac.Bat[2]), Ii)
   Ic = setdiff(collect(1:size(ac.X,2)), union(Ii, Ia))

   # some other atom fields that we want to plot
   Xghost = LujiaLt.lattice_ball( R = maximum(2*sqrt(sumabs2(ac.X,1))) )[1] .+ ξ
   Xbdry = ac.X[:, setdiff(1:size(ac.X,2), ac.Ifree)]

   ctx = compose( context(axis),
                  # atomistic nodes
                  compose_atoms(Xbdry, [0.15], 0.0, axis, blue),
                  # atomistic nodes
                  compose_atoms(ac.X[:,Ia], [0.15], 0.0, axis, red),
                  # interface nodes
                  compose_atoms(ac.X[:,Ii], [0.15], 0.0, axis, green),
                  # ghost atoms
                  compose_atoms(Xghost, [0.07], 0.0, axis, "grey60"),
                  # atomistic bonds
                  compose_bonds(ac.X, ac.Bat, lwidth, red, axis),
                  # interface bonds
                  compose_bonds(ac.X, ac.Bi, lwidth, green, axis),
                  # elements
                  FEM.compose_elements(ac.tri, alice, blue, lwidth, _ub_(axis)),
                  # and lastly a little shade under the defect
                  compose_defint(axis)
                )

   # draw the plot to a file
   if filename != nothing
      drawtofile(ctx, filename, axis, printwidth)
   end
   if plotwidth != nothing
      draw(auto_img(SVG, axis, plotwidth), ctx)
   end
   return ctx
end


find_index(X, x::Vector) = find(sumabs2(X.-x, 1) .<= 1e-10)[1]
find_index(X, x::Matrix) = [ find_index(X, x[:,i]) for i = 1:size(x,2) ]



# ===========================================================================
#    Error analysis
# ===========================================================================


end
