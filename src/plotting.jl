
module Plotting

using Compose, Colors

import LujiaLt.Potentials: nndist
import LujiaLt.MDTools: NeighbourList, uniquepairs
import LujiaLt: Model, Atm, Domain, positions, ACModel
import LujiaLt.FEM: Triangulation, elements

export plot

const ljatcol = "tomato"
const ljbondcol = "darkblue"
const ljlinecol = "darkblue"
const ljelcol = "aliceblue"


"return a reasonable choice for the plotting axis"
function autoaxis(X)
    xLim = [extrema(X[1,:])...]
    width = xLim[2]-xLim[1]
    yLim = [extrema(X[2,:])...]
    height = yLim[2]-yLim[1]
    buffer = min( 1.0, 0.05 * width, 0.05 * height )
    xLim[1] -= buffer; xLim[2] += buffer
    yLim[1] -= buffer; yLim[2] += buffer
    return [xLim[1]; xLim[2]; yLim[1]; yLim[2]]
end

"turn axis into UnitBox for creating contexts"
_ub_(axis) = UnitBox(axis[1], axis[3], axis[2]-axis[1], axis[4]-axis[3])

import Compose.context
context(axis::Vector) = context(units=_ub_(axis))

relative_height(ax, width) = (ax[4]-ax[3])/(ax[2]-ax[1]) * width
relative_width(ax, height) = (ax[2]-ax[1])/(ax[4]-ax[3]) * height

compose_atoms(X; radii=[0.2], lwidth=0.3, axis=autoaxis(X),
                  fillcolor=ljatcol, linecolor=ljbondcol ) =
   ( context(axis), circle(X[1,:][:], X[2,:][:], radii),
     stroke(linecolor), linewidth(lwidth), fill(fillcolor) )

nanvec(dim::Integer) = NaN * ones(dim)

edges2path(X, B) = insert_nans( [X[:, B[1]]; X[:, B[2]]] )
insert_nans(P) = reshape( [P; NaN * ones(2, size(P, 2))], 2, 3 * size(P, 2) )
mat2points(P::Matrix) = NTuple{2, Float64}[ tuple(P[:,n]...) for n = 1:size(P, 2) ]

function compose_bonds(X, B; lwidth=1.0, linecolor=ljbondcol,
                              axis=autoaxis(X))
   # create a matrix of points, including NaN points where the path is
   # to be broken up.
   # dim = size(X, 1)
   # P = [ X[:, B[1]]; X[:, B[2]]; NaN * ones(dim,length(B[1])) ]
   # P = reshape(P, dim, length(P) ÷ dim)
   # # convert into points
   # P = [ tuple(P[:, n]...) for n = 1:size(P, 2) ]
   dim = size(X,1)
   P = Float64[]
   for n = 1:length(B[1])
      append!(P, [X[:, B[1][n]] X[:, B[2][n]] nanvec(dim) ][:])
   end
   P = mat2points(reshape(P, dim, length(P) ÷ dim))
   # return the required tuple to compose
   return ( context(axis), line(P), stroke(linecolor), linewidth(lwidth) )
end


# ########################## PLOTTING ############################


function compose_elements(tri::Triangulation; X = tri.X, axis=autoaxis(X),
                           elcol=ljelcol, linecol=ljbondcol, lwidth=0.5 )
   dim = size(X, 1)
   P = Float64[]
   for el in elements(tri)
      append!(P, [X[:, el.t] X[:, el.t[1]] nanvec(dim)][:])
   end
   P = mat2points( reshape(P, dim, length(P) ÷ dim) )
   return ( context(axis), polygon(P), fill(elcol),
            stroke(linecol), linewidth(lwidth) )
end






"""
`plot(at::Atm; kwargs...)`
`plot(at::Triangulation; kwargs...)`

## Keyword arguments
* X : positions (default, reference positions)
* axis : default is an autoaxis
* plotwidth: default is 12cm
* Img : image type, default is SVG
* rnn : bond-length, default derived from at.V
"""
function plot( at::Atm; X=positions(at), axis = autoaxis(X),
               plotwidth = 12cm, Img=SVG, rnn = 1.4 * nndist(at.V) )
   i, j = uniquepairs(NeighbourList(X, rnn))
   ctx = compose( context(axis),
                  compose_atoms( X, radii=[0.2], axis=axis ),
                  compose_bonds( X, (i, j), lwidth=0.7, axis=axis ) )
   draw( Img(plotwidth, relative_height(axis, plotwidth)), ctx )
   return nothing
end


function plot( tri::Triangulation; axis = autoaxis(tri.X),
               plotwidth = 12cm, Img=SVG, elcol = ljelcol, linecol=ljbondcol,
               lwidth=0.5 )
   ctx = compose( context(axis),
                  compose_elements(tri, elcol=elcol, linecol=linecol,
                                    axis=axis, lwidth=lwidth ) )
   draw( Img(plotwidth, relative_height(axis, plotwidth)), ctx )
   return nothing
end


# TODO: visualise the transition via adjusting the shades of the atoms and
#       of the elements
function plot( m::ACModel; X=positions(m), axis = autoaxis(X),
               plotwidth = 12cm, Img=SVG, elcol = ljelcol, linecol=ljbondcol,
               lwidth=0.5 )
   Xat = X[:, find(m.volX .> 0.0)]
   ctx = compose( context(axis),
                  compose_atoms( Xat, radii=[0.3], axis=axis ),
                  compose_elements( m.geom.tri, X=X, elcol=elcol, axis=axis,
                                    linecol=linecol, lwidth=lwidth ) )
   draw( Img(plotwidth, relative_height(axis, plotwidth)), ctx )
   return nothing
end



end


# # code to plot in a REPL window
# using Gtk
# c = Gtk.@GtkCanvas(400,300);
# w = Gtk.@GtkWindow(c,"data win");
# show(c);
# using Compose
# function sierpinski(n)
#     if n == 0
#         compose(context(), polygon([(1,1), (0,1), (1/2, 0)]))
#     else
#         t = sierpinski(n - 1)
#         compose(context(),
#                 (context(1/4,   0, 1/2, 1/2), t),
#                 (context(  0, 1/2, 1/2, 1/2), t),
#                 (context(1/2, 1/2, 1/2, 1/2), t))
#     end
# end
# co = sierpinski(5);
# Gtk.draw(c) do widget
#     Compose.draw(CAIROSURFACE(c.back),co)
# end
# Gtk.draw(c)
