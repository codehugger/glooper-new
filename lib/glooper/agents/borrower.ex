defmodule Glooper.Borrower do
  @moduledoc """
  A borrower is an agent that requests a loan from a bank, then uses
  the loan to pay it back. When the money runs out the borrower asks the
  bank to hire her and the bank pays the borrower enough to pay back the
  rest of the loan.
  """
  use Agent

  import Glooper.BankHelpers

  @behaviour Glooper.Agent

  defmodule State do
    @moduledoc false
    @enforce_keys [:sim_no, :agent_no, :bank]
    @optional_keys [
      label: "The Borrower",
      account_no: "",

      # Employment
      employed: false,

      # Loan
      loan_no: "",
      loan_amount: 1200,
      loan_interest: 10.0,
      loan_duration: 12
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
        loan_amount: Map.fetch!(config, "loan_amount"),
        loan_interest: Map.fetch!(config, "loan_interest"),
        loan_duration: Map.fetch!(config, "loan_duration")
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

  defp renew_loan(borrower) do
    Agent.get_and_update(borrower, fn state ->
      case get_loan(state.sim_no, state.bank, state.loan_no, state.agent_no) do
        {:ok, _loan} ->
          {:ok, state}

        {:error, :not_found} ->
          {:ok, loan_no} =
            request_loan(
              state.sim_no,
              state.bank,
              state.account_no,
              state.loan_amount,
              state.loan_duration,
              state.loan_interest,
              state.agent_no
            )

          {:ok, %{state | loan_no: loan_no}}
      end
    end)
  end

  defp hire_borrower(sim_no, bank, agent_no, account_no, loan_no) do
    IO.puts("... \"#{agent_no}\" is broke and is asking bank \"#{bank}\" for a job")
    [{bank, module}] = get_bank_agent(sim_no, bank)
    apply(module, :hire_borrower, [bank, agent_no, account_no, loan_no])
  end

  defp make_loan_payment(borrower) do
    Agent.get_and_update(borrower, fn state ->
      case get_loan(state.sim_no, state.bank, state.loan_no, state.agent_no) do
        {:ok, _loan} ->
          case make_next_payment(
                 state.sim_no,
                 state.bank,
                 state.loan_no,
                 state.account_no,
                 state.agent_no
               ) do
            {:error, :insufficient_funds} ->
              hire_borrower(
                state.sim_no,
                state.bank,
                state.agent_no,
                state.account_no,
                state.loan_no
              )

              {state, state}

            {:error, :loan_paid_off} ->
              {:ok, %{state | loan_no: ""}}

            {:ok, _} ->
              {:ok, state}

            {:error, _} = err ->
              {err, state}
          end

        {:error, _} = err ->
          {err, state}
      end
    end)

    :ok
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
      with {:ok, account_no} <-
             open_account(state.sim_no, state.bank, state.agent_no, state.agent_no),
           {:ok, _t} <-
             deposit_cash(
               state.sim_no,
               state.bank,
               account_no,
               round(state.loan_amount * 0.1),
               state.agent_no
             ),
           {:ok, loan_no} <-
             request_loan(
               state.sim_no,
               state.bank,
               account_no,
               state.loan_amount,
               state.loan_duration,
               state.loan_interest,
               state.agent_no
             ) do
        %{state | account_no: account_no, loan_no: loan_no}
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

    :ok = make_loan_payment(agent)
    :ok = renew_loan(agent)

    # Everything went fine
    :ok
  end
end
