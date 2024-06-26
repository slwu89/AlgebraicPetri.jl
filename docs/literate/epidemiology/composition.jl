# # [Composition of Epidemiological Models](@id epidemiology_basic)
#
#md # [![](https://img.shields.io/badge/show-nbviewer-579ACA.svg)](@__NBVIEWER_ROOT_URL__/generated/epidemiology/composition.ipynb)

using AlgebraicPetri
using AlgebraicPetri.Epidemiology

using LabelledArrays
using OrdinaryDiffEq
using Plots

using Catlab

display_uwd(ex) = to_graphviz(ex, box_labels=:name, junction_labels=:variable, edge_attrs=Dict(:len=>".75"));

# In this tutorial we introduce the basic concepts of modeling with open Petri nets (PN). Specifically,
# methods from the section "Compositional methods of model specification" of
# [[Libkind 2022](https://doi.org/10.1098/rsta.2021.0309)] are presented, which should
# be consulted for more information.

# ## Petri nets

# Petri nets are a mathematical language to describe state transition systems which
# can effectively represent complex relationships between processes, such as parallelism,
# concurrency, dependency, and conflict. Originally developed for the design of digital
# systems, their extremely general formulation has made them useful for modeling in chemistry,
# biology, ecology, and epidemiology, among other domains. For more information, see the [Wikipedia article](https://en.wikipedia.org/wiki/Petri_net).

# The type of Petri nets used in AlgebraicPetri are *whole-grain Petri nets*
# introduced by [[Kock 2020](https://arxiv.org/abs/2005.05108)]. Briefly, these Petri nets
# can be described by the following *schema*, where $S$ is the set of places or species,
# $T$ is the set of transitions, and $I$ and $O$ are the sets of input (transition to place)
# and output (place to transition) arcs. For a concrete instance of a Petri net, the labeled
# boxes in the diagram become sets, and arrows become functions, and such a data instance
# on a schema is known as a C-Set (or acset, for Attributed C-Set); please see [Catlab.jl](https://github.com/AlgebraicJulia/Catlab.jl)
# for more details.

to_graphviz(SchPetriNet)

# ## SIS Model

# The susceptible-infectious-susceptible (SIS) model is one of the simplest models
# of mathematical epidemiology. Nonetheless it is a useful starting point to understand
# how to use PNs to express and build more complex epidemiological models. 

# We first show how to build the SIS model directly. We use the `LabelledPetriNet` type
# which is an elaboration of the schema shown above which allows us to attach names to
# the places and transitions, for enhanced readability. The first argument gives the list
# of place names. Remaining arguments specify transitions. The first element of the pair type
# is the name of the transition. The second element is another pair whose first element gives
# the names of input species and second element is the names of output species. The
# `to_graphviz` method from Catlab displays the Petri net.

si = LabelledPetriNet([:S, :I], :inf=>((:S,:I)=>(:I,:I)), :rec=>:I=>:S)
to_graphviz(si)

# Now we demonstrate how to use the category of open Petri nets to build the SIS model
# compositionally. While the additional complexity is superfluous for the SIS system,
# it is the simplest non-trivial system which demonstrates the concepts.

# An open Petri net is a Petri net where certain places are "exposed" as gluing points that
# can be joined with other systems, supporting a compositional style of modeling where a 
# complex system can be broken down into interactions of more basic systems. Open Petri nets are
# a type of object called a "structured multicospan", which is an object containing the original Petri net ``S`` ("apex"),
# a list of finite sets ``A_{1},\dots,A_{n}`` ("feet"), and functions ``A_{1}\to S,\dots,A_{n}\to S`` ("legs").
# The legs specify the places in the apex Petri net where it may be joined to other systems.

# To generate the SIS model compositionally, we first make two open Petri nets, one containing the
# infection transition and the other containing the recovery transition. We can use the helper
# methods `exposure_petri` and `spontaneous_petri` from the `Epidemiology` module of AlgebraicPetri
# to quickly generate the open labelled Petri nets.

si_inf = exposure_petri(:S, :I, :I, :inf);
si_rec = spontaneous_petri(:I, :S, :rec);

# The resulting objects are structured multicospans, and by default, each place is exposed as a leg.
# Because each of these elementary Petri nets has only two distinct places, there are two legs. We
# can view the map into the apex from the first leg using Catlab's graphviz functionality:

to_graphviz(first(legs(si_inf)))

# Now we must specify a *composition syntax* describing how to glue together the open Petri nets
# to generate the composed system. Specifically, composition is described using an undirected wiring diagram (UWD),
# a graphical language for describing relations between objects. We can specify the UWD for the SIS system
# using the `@relation` macro from Catlab; the function-like syntax in the body are "boxes" and variables
# are "junctions". Generally, boxes represent processes which may consume or produce resources represented
# as junctions. 

# To compose the open Petri nets, each box in the UWD will correspond to an open PN whose feet attach to
# the junctions that box is connected to. The composite PN is then constructed by
# gluing the component PNs along at the shared junctions (places).

si_uwd = @relation (s,i) begin
    infection(s,i)
    recovery(i,s)
end

display_uwd(si_uwd)

# To produce the composite Petri net from our building blocks, the `oapply` method from Catlab performs the gluing.
# We provide the UWD as first argument and a dictionary mapping box names to open Petri nets as the second, and view
# the result.

si = oapply(si_uwd, Dict(:infection=>si_inf, :recovery=>si_rec))

to_graphviz(si)

# ## SIR Model

# The susceptible-infectious-recovered (SIR) model is another basic model of mathematical epidemiology.

sir = @relation (s,i,r) begin
    infection(s,i)
    recovery(i,r)
end
display_uwd(sir)

# To generate the SIR model as a Petri net, we use the helper function `oapply_epi` from the `Epidemiology`
# module of AlgebraicPetri, which has some definitions of common "atomic" Petri nets from
# epidemiological models. For more details, please see the documentation for that method.

p_sir = apex(oapply_epi(sir))
to_graphviz(p_sir)

# Labelled vectors are used to create the initial state and reaction rate parameters for each transition.

u0 = LVector(S=10, I=1, R=0);
p = LVector(inf=0.4, rec=0.4);

# The `vectorfield` method interprets the PN as describing mass-action kinetics
# with a rate constant associated to each transition, which can be used to
# simulate ODEs associated to the PN.

prob = ODEProblem(vectorfield(p_sir),u0,(0.0,7.5),p);
sol = solve(prob,Tsit5())

plot(sol, labels=["S" "I" "R"])

# ## SEIR Model

# For the susceptible-exposed-infectious-recovered (SEIR) model, we again define a UWD to describe composition 
# syntax.

seir = @relation (s,e,i,r) begin
    exposure(s,i,e)
    illness(e,i)
    recovery(i,r)
end
display_uwd(seir)
#-
p_seir = apex(oapply_epi(seir))
to_graphviz(p_seir)

# Define initial states and transition rates, then
# create, solve, and visualize ODE problem:

u0 = LVector(S=10, E=1, I=0, R=0);
p = LVector(exp=.9, ill=.2, rec=.5);

prob = ODEProblem(vectorfield(p_seir),u0,(0.0,15.0),p);
sol = solve(prob,Tsit5())

plot(sol, labels=["S" "E" "I" "R"])

# #### SEIRD Model

# We can add a deceased component and a death process to the SEIR model, specified with
# an undirected wiring diagram.
seird = @relation (s,e,i,r,d) begin
    exposure(s,i,e)
    illness(e,i)
    recovery(i,r)
    death(i,d)
end
display_uwd(seird)
#-
p_seird = apex(oapply_epi(seird))
to_graphviz(p_seird)

# Define initial states and transition rates, then
# create, solve, and visualize ODE problem:

u0 = LVector(S=10, E=1, I=0, R=0, D=0);
p = LVector(exp=0.9, ill=0.2, rec=0.5, death=0.1);

prob = ODEProblem(vectorfield(p_seird),u0,(0.0,15.0),p);
sol = solve(prob,Tsit5())

plot(sol, labels=["S" "E" "I" "R" "D"])
