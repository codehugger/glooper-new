defmodule Glooper.Agent do
  @moduledoc """
  The `Glooper.Agent` module describes the behaviour of an agent capable of
  running inside a `Glooper.Simulation`
  """

  @typedoc "The agent name"
  @type agent :: Agent.agent()

  @typedoc "The simulation name"
  @type simulation :: Agent.agent()

  @doc """
  Initialize the agent within the simulation before the first cycle is run.
  """
  @callback init(agent, simulation) :: :ok | Glooper.error()

  @doc """
  Evaluate the agent against the simulation and updates the agent state.
  """
  @callback eval(agent, simulation) :: :ok | Glooper.error()
end
