# ColorScales Domain Glossary

## Color range

The closed numeric span `(low, high)` mapped onto a colormap. A color-range
method derives this span from data or a supplied distribution. Selecting a
color range is independent of selecting class edges.

## Class edge

One value in an ordered sequence that divides a color range into graduated
classes. Except for constant data, `k` classes have `k + 1` class edges.

## Graduated class

A numeric interval assigned one color. Classes are right-closed, `(a, b]`,
except that the first class includes the color range's lower endpoint.

## Break method

A rule that derives class edges from observations and a color range. A
requested class count is a target for methods such as pretty breaks; tied data
can also reduce the resulting count.

## Color specification

A renderer-neutral result containing a color range, optional class edges and
labels, and a PlotUtils gradient. A continuous color specification has no
class edges. A graduated color specification has a categorical gradient.

## Argument rule

How a color specification reaches a plot: it goes last, the argument before it
is what gets colored, and everything before that is position. The plotting
library's own classification of the plot type decides whether the colored
argument stays positional or becomes a color attribute.

## Plotting extension

The Makie- or Plots-specific code implementing the argument rule, living in a
package extension. An extension never recomputes the color range or class
edges; it only widens a zero-width range into renderer-safe display limits.

