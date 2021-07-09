defmodule Glooper.Population do
  @moduledoc """
  The population agent is a super agent capable of simulating a population of
  a few workers to thousands.

  The population agent is fairly flexible with the capability of running a wide
  variety of processing strategies from a one-to-one mapping involving thousands
  of processes all running async at the same time to running each person in
  random order one-by-one using only one process.
  """
  use Agent

  import Glooper.BankHelpers

  alias Glooper.{Need, Person}

  @behaviour Glooper.Agent

  defmodule State do
    @moduledoc false
    alias __MODULE__

    @enforce_keys [:sim_no, :agent_no, :bank]
    @optional_keys [
      label: "The Population",

      # Population startup values
      initial_population: 0,
      initial_deposit: 0,
      desired_salary: 0,

      # Population
      population: %{},

      # Taxes & Benefits
      needs: %{}
    ]

    defstruct @enforce_keys ++ @optional_keys

    @doc """
    Creates a new factory.
    """
    def create(init_args \\ [])

    def create(init_args) when is_list(init_args) do
      struct!(State, init_args)
    end

    @doc """
    Takes a Glooper government config and returns a new Government.
    """
    def fields_from_config(sim_no, agent_no, config) do
      # Go through all the benefits and add them to the government
      needs =
        Enum.reduce(Map.get(config, "needs", []), %{}, fn {key, need}, needs ->
          Map.put_new(needs, key, %Need{
            product: key,
            purchase: need["purchase"],
            consume: need["consume"],
            store: need["store"]
          })
        end)

      [
        sim_no: sim_no,
        agent_no: agent_no,
        label: Map.fetch!(config, "label"),
        bank: Map.fetch!(config, "bank"),
        desired_salary: Map.get(config, "desired_salary", 0),
        initial_population: Map.get(config, "initial_population", 0),
        initial_deposit: Map.get(config, "initial_deposit", 0),
        needs: needs
      ]
    end
  end

  #############################################################################
  #### Initialization
  #############################################################################

  @doc """
  Starts a population agent linked to the current process.
  """
  def start_link(sim_no, agent_no, fields \\ [], opts \\ []) do
    # Generate a unique identifier for this agent and use the sim_no prefix to
    # sandbox the agent within that simulation
    name = "#{sim_no}_#{agent_no}"

    opts =
      opts
      |> Keyword.put_new(:name, name)
      # Change the name to a :via tuple to allow strings to be used as identifiers
      |> Keyword.put(:name, Glooper.via_tuple(name, __MODULE__))

    # For sanity reasons we assign the given sim_no regardless of previous value
    fields = Keyword.put(fields, :sim_no, sim_no)
    # Keep track of the agent_no through the internal state
    fields = Keyword.put(fields, :agent_no, agent_no)
    # Link the agent to the calling process (which we assume is the simulation)
    {:ok, pid} = Agent.start_link(fn -> State.create(fields) end, opts)
    # Return the pid and the name used to start the process
    {:ok, pid, Keyword.fetch!(opts, :name)}
  end

  @doc """
  Starts a population agent from config linked to the current process.
  """
  def start_from_config(sim_no, agent_no, config \\ %{}, opts \\ []) do
    # Create population from config
    fields = State.fields_from_config(sim_no, agent_no, config)
    # Start the linked process as usual
    start_link(sim_no, agent_no, fields, opts)
  end

  #############################################################################
  #### Evaluation
  #############################################################################

  @impl true
  def init(agent, _simulation) do
    state = Agent.get(agent, & &1)
    IO.puts("--> initializing #{state.agent_no} population")

    # 1. spawn the population with accounts and initial deposits
    people =
      Enum.map(1..state.initial_population, fn x ->
        person_no = "#{state.agent_no}_#{x}"

        with {:ok, account_no} <-
               open_account(state.sim_no, state.bank, person_no, person_no),
             {:ok, _t} <-
               deposit_cash(
                 state.sim_no,
                 state.bank,
                 account_no,
                 state.initial_deposit,
                 person_no
               ) do
          {person_no,
           %Person{
             person_no: person_no,
             label: person_no |> String.capitalize(),
             bank: state.bank,
             needs: state.needs,
             account_no: account_no
           }}
        end
      end)

    # Open up a deposit account and deposit the initial cash
    Agent.update(agent, fn state -> %{state | population: Map.new(people)} end)

    :ok
  end

  @impl true
  def eval(agent, _simulation) do
    state = Agent.get(agent, & &1)
    IO.puts("--> evaluating #{state.agent_no} population")

    # 1. find a job (unless employed)
    # 2. work job (unless unemployed)
    # 3. purchase/consume

    :ok
  end
end
