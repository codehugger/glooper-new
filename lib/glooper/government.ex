defmodule Glooper.Government do
  @moduledoc """
  A government is an agent that pays benefits and collects taxes according to
  defined policies.
  """
  use Agent

  import Glooper.BankHelpers

  alias Glooper.{BenefitPolicy, TaxPolicy}

  @behaviour Glooper.Agent

  defmodule State do
    @moduledoc false
    alias __MODULE__

    @enforce_keys [:sim_no, :agent_no, :bank]
    @optional_keys [
      label: "The Government",
      account_no: "",
      initial_deposit: 0,

      # Staff
      wages_min: 0,
      civil_servants_max: 0,

      # Taxes & Benefits
      benefits: %{},
      taxes: %{}
    ]

    defstruct @enforce_keys ++ @optional_keys

    #############################################################################
    #### Initialization
    #############################################################################

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
      benefits =
        Enum.reduce(Map.get(config, "benefits", []), %{}, fn {key, pol}, benefits ->
          Map.put_new(benefits, key, %BenefitPolicy{
            label: pol["label"],
            value: pol["value"],
            target: pol["target"]
          })
        end)

      # Go through all the taxes and add them to the government
      taxes =
        Enum.reduce(Map.get(config, "taxes", []), %{}, fn {key, pol}, taxes ->
          Map.put_new(taxes, key, %TaxPolicy{
            label: pol["label"],
            value: pol["value"],
            target: pol["target"]
          })
        end)

      [
        sim_no: sim_no,
        agent_no: agent_no,
        label: Map.fetch!(config, "label"),
        bank: Map.fetch!(config, "bank"),
        wages_min: Map.get(config, "wages_min", 0),
        civil_servants_max: Map.get(config, "civil_servants_max", 0),
        initial_deposit: Map.get(config, "initial_deposit", 0),
        benefits: benefits,
        taxes: taxes
      ]
    end
  end

  #############################################################################
  #### Initialization
  #############################################################################

  @doc """
  Starts a government agent linked to the current process.
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
  Starts a government agent from config linked to the current process.
  """
  def start_from_config(sim_no, agent_no, config \\ %{}, opts \\ []) do
    # Create government from config
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
    IO.puts("--> initializing #{state.agent_no}")

    # Open up a deposit account and deposit the initial cash
    Agent.update(agent, fn state ->
      with {:ok, account_no} <-
             open_account(state.sim_no, state.bank, state.agent_no, state.agent_no),
           {:ok, _t} <-
             deposit_cash(
               state.sim_no,
               state.bank,
               account_no,
               state.initial_deposit,
               state.agent_no
             ) do
        %{state | account_no: account_no}
      end
    end)
  end

  @impl true
  def eval(agent, _simulation) do
    state = Agent.get(agent, & &1)
    IO.puts("--> evaluating #{state.agent_no}")

    # 1. pay benefits
    # 2. hire/fire employees (civil servants)
    # 3. collect taxes

    :ok
  end
end
