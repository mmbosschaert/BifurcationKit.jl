abstract type AbstractEvent end
abstract type AbstractContinuousEvent <: AbstractEvent end
abstract type AbstractDiscreteEvent <: AbstractEvent end

# evaluate the functional whose roots are seek
(eve::AbstractEvent)(iter, state) = eve.fct(iter, state)

# init function, must return the same type as eve(iter, state)
init(eve::AbstractEvent, T) = error("Initialization method not implemented for event ", eve)

# whether the event is active
isActive(::AbstractEvent) = true

# whether the event requires computing eigen-elements
@inline computeEigenElements(::AbstractEvent) = false

# general condition for detecting a (continuous) event. Made it default behaviour
# Basically, we want to detect if some component of `abs.(fct(iter, state))` is below ϵ
isEvent(::AbstractEvent, iter, state) = !isnothing(findfirst(x -> abs(x) < iter.contParams.tolBisectionEvent, state.event[2]))

# this function is called to determine if callbaclVals is an event
test(::AbstractEvent, callbaclVals, precision) = false
####################################################################################################
# default event which does nothing
struct DefaultEvent <: AbstractEvent end
isActive(::DefaultEvent) = false
init(::DefaultEvent, T) = nothing