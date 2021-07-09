defmodule Glooper.Factory do
  @moduledoc """
  A factory is an agent that produces a `Glooper.Product` in accordance with
  a `Recipe`. **PLEASE NOTE THERE IS CURRENTLY NO SUPPORT FOR COMPONENTS***
  """
  use Agent

  import Glooper.BankHelpers

  @behaviour Glooper.Agent

  alias Glooper.Inventory

  defmodule State do
    @moduledoc false
    alias __MODULE__

    @enforce_keys [:sim_no, :agent_no, :bank, :product]
    @optional_keys [
      label: "The Factory",
      account_no: "",
      initial_deposit: 0,

      # Staff
      workers_max: 0,

      # Inventory
      inventory: nil,
      inventory_max: 0,

      # Production
      suppliers: [],
      worker_output: 0
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
      [
        # Mandatory
        sim_no: sim_no,
        agent_no: agent_no,
        label: Map.fetch!(config, "label"),
        bank: Map.fetch!(config, "bank"),
        product: Map.fetch!(config, "product"),

        # Optional
        initial_deposit: Map.get(config, "initial_deposit", 0),
        inventory_max: Map.get(config, "inventory_max", 0),
        workers_max: Map.get(config, "workers_max", 0),
        worker_output: Map.get(config, "worker_output", 0)
      ]
    end
  end

  #############################################################################
  #### Initialization
  #############################################################################

  @doc """
  Starts a factory agent linked to the current process.
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
    # Keep track of the non-sandbox agent id through the internal state
    fields = Keyword.put(fields, :agent_no, agent_no)
    # Link the agent to the calling process (which we assume is the simulation)
    {:ok, pid} = Agent.start_link(fn -> struct!(State, fields) end, opts)
    # Return the pid and the name used to start the process
    {:ok, pid, Keyword.fetch!(opts, :name)}
  end

  @doc """
  Starts a factory from config linked to the current process.
  """
  def start_from_config(sim_no, agent_no, config \\ %{}, opts \\ []) do
    # Set the proper prefixed name for starting the process
    # Create factory from config
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

    # Initialize the inventory according to the maximum capacity
    Agent.update(agent, fn state ->
      %{state | inventory: Inventory.create(capacity: state.inventory_max)}
    end)

    :ok
  end

  @doc """
  """
  @impl true
  def eval(agent, _simulation) do
    state = Agent.get(agent, & &1)
    IO.puts("--> evaluating #{state.agent_no}")

    # 1. produce
    # 2. sell to market (unless passive)
    # 3. pay salaries
    # 4. hire/fire employees
    # 5. discard inventory

    :ok
  end
end
