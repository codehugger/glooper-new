defmodule Glooper.BankInvestor do
  @moduledoc """
  A bank investor is an agent that buys shares for a fixed amount at
  the beginning of a simulation and then just sits on it.
  """
  use Agent

  import Glooper.BankHelpers

  @behaviour Glooper.Agent

  defmodule State do
    @moduledoc false
    @enforce_keys [:sim_no, :agent_no, :bank]
    @optional_keys [
      label: "The Investor",

      # Investment
      initial_investment: 0,
      transactions: []
    ]
    defstruct @enforce_keys ++ @optional_keys

    def create(init_args \\ [])

    def create(init_args) when is_list(init_args) do
      struct!(State, init_args)
    end

    def fields_from_config(sim_no, agent_no, config) do
      [
        sim_no: sim_no,
        agent_no: agent_no,
        label: Map.fetch!(config, "label"),
        bank: Map.fetch!(config, "bank"),
        initial_investment: Map.fetch!(config, "initial_investment")
      ]
    end
  end

  #############################################################################
  #### Initialization
  #############################################################################

  @doc """
  Starts a borrower agent linked to the current process.
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
    {:ok, pid} = Agent.start_link(fn -> State.create(fields) end, opts)
    # Return the pid and the name used to start the process
    {:ok, pid, Keyword.fetch!(opts, :name)}
  end

  @doc """
  Starts a borrower agent from config linked to the current process.
  """
  def start_from_config(sim_no, agent_no, config \\ %{}, opts \\ []) do
    # Create borrower from config
    fields = State.fields_from_config(sim_no, agent_no, config)
    # Start the linked process as usual
    start_link(sim_no, agent_no, fields, opts)
  end

  #############################################################################
  #### Bank Helpers
  #############################################################################

  defp buy_shares(sim_no, bank, agent_no, amount) do
    IO.puts("... \"#{agent_no}\" is buying shares in \"#{bank}\" for a #{amount}")
    [{bank, module}] = get_bank_agent(sim_no, bank)
    apply(module, :sell_shares, [bank, agent_no, amount])
  end

  #############################################################################
  #### Evaluation
  #############################################################################

  @doc """
  Initializes the agent with a deposit account and an initial loan deposited to
  the newly opened account.
  """
  @impl true
  def init(agent, _simulation) do
    state = Agent.get(agent, & &1)
    IO.puts("--> initializing \"#{state.agent_no}\"")

    # Open up a deposit account, deposit the initial cash and request the first loan
    Agent.update(agent, fn state ->
      case buy_shares(state.sim_no, state.bank, state.agent_no, state.initial_investment) do
        {:ok, t} -> %{state | transactions: [t | state.transactions]}
      end
    end)
  end

  @doc """
  Makes continuous loan payments using the loan amount. After the loan amount
  runs out the agent applies for a job at the bank and uses that money to
  continue to pay off the loan. When loan is paid off a new loan is requested
  and the process repeats.
  """
  @impl true
  def eval(agent, _simulation) do
    state = Agent.get(agent, & &1)
    IO.puts("--> evaluating \"#{state.agent_no}\"")

    # Everything went fine
    :ok
  end
end
