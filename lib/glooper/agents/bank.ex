defmodule Glooper.Bank do
  @moduledoc """
  A `Glooper.Bank` is simple wrapper around the `Glooper.BankManager`
  core module that supports interbank money transfers.
  """

  use Agent

  @behaviour Glooper.Agent

  alias Glooper.BankManager, as: BM
  alias Glooper.{GBAN, Payment, Utils, Simulation}

  defmodule State do
    @moduledoc false
    @enforce_keys [:sim_no, :agent_no]
    @optional_keys [
      label: "The Bank",
      bank: nil,

      # Staff
      borrowers: [],
      workers_max: 0
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
        label: Map.fetch!(config, "label")
      ]
    end
  end

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
  #### Accounts
  #############################################################################

  @doc """
  Gets the fully qualified GBAN sequence for `acc_no`.
  """
  def get_account_gban(agent, acc_no) do
    Agent.get(agent, fn state -> BM.get_account_gban(state.bank, acc_no) end)
  end

  @doc """
  Gets the account matching `acc_no`.
  """
  def get_account(agent, acc_no) do
    Agent.get(agent, fn state -> BM.get_account(state.bank, acc_no) end)
  end

  @doc """
  Gets all the deposit accounts associated with `customer_no`.
  """
  def customer_accounts(agent, customer_no) do
    Agent.get(agent, fn state -> BM.get_accounts(state.bank, customer_no) end)
  end

  @doc """
  Opens a deposit account for `customer_no` with generated `acc_no`.
  """
  def open_account(agent, customer_no) do
    open_account(agent, customer_no, Utils.gen_account_no())
  end

  @doc """
  Opens a deposit account for `customer_no` with specified `acc_no`
  """
  def open_account(agent, customer_no, acc_no) when is_binary(acc_no) do
    Agent.get_and_update(agent, fn state ->
      {:ok, bank, acc_no} = BM.open_account(state.bank, customer_no, acc_no)
      {{:ok, acc_no}, %{state | bank: bank}}
    end)
  end

  #############################################################################
  #### Transfers
  #############################################################################

  @doc """
  Deposit cash into a customer deposit account.
  """
  def deposit_cash(agent, acc_no, amount, text \\ "Deposit cash") do
    Agent.get_and_update(agent, fn state ->
      ts = Simulation.current_timestamp(state.sim_no)
      {:ok, bank, t} = BM.deposit_cash(state.bank, acc_no, amount, text, ts)
      {{:ok, t}, %{state | bank: bank}}
    end)
  end

  @doc """
  Withdraw cash from a customer deposit account.
  """
  def withdraw_cash(agent, acc_no, amount, text \\ "Withdraw cash") do
    Agent.get_and_update(agent, fn state ->
      ts = Simulation.current_timestamp(state.sim_no)
      {:ok, bank, _t} = BM.withdraw_cash(state.bank, acc_no, amount, text, ts)
      {:ok, {%{state | bank: bank}, amount}}
    end)
  end

  @doc """
  Transfers the given amount using debit and credit account numbers.
  """
  def transfer(bank, from, to, amount, text \\ "Transfer") when amount > 0 do
    case {GBAN.parse(from), GBAN.parse(to)} do
      # Debit account is faulty
      {{:error, _} = err, _} ->
        err

      # Credit account is faulty
      {_, {:error, _} = err} ->
        err

      {src, dest} ->
        cond do
          src.bank == dest.bank ->
            Agent.get_and_update(bank, fn state ->
              ts = Simulation.current_timestamp(state.sim_no)
              {:ok, bank, t} = BM.transfer(state.bank, from, to, amount, text, ts)
              {{:ok, t}, %{state | bank: bank}}
            end)

          src.bank != dest.bank ->
            interbank_cash(from, to, amount)
        end
    end
  end

  defp interbank_cash(from, to, amount) do
    # A fun method of using "cash drones" for interbank transfers...
    case {GBAN.parse(from), GBAN.parse(to)} do
      {from_gban, to_gban} ->
        with :ok <-
               withdraw_cash(
                 from_gban.bank,
                 from_gban.account,
                 amount,
                 "Interbank transfer #{from}->#{to}"
               ),
             :ok <-
               deposit_cash(
                 to_gban.bank,
                 to_gban.account,
                 amount,
                 "Interbank transfer #{from}->#{to}"
               ) do
          :ok
        else
          {:error, _} = err -> err
        end
    end
  end

  #############################################################################
  #### Loans
  #############################################################################

  @doc """
  Checks to see if the customer matching `customer_no` has any outstanding debt
  in the bank's loan book.
  """
  def has_debt?(bank, customer_no) do
    Agent.get(bank, fn state -> BM.has_debt?(state.bank, customer_no) end)
  end

  @doc """
  Adds a new loan to the bank's loan book for the given amount, duration, rate,
  and type.
  """
  def request_loan(
        bank,
        acc_no,
        amount,
        duration,
        rate \\ 0.05,
        frequency \\ 1,
        type \\ "compound"
      ) do
    case get_account(bank, acc_no) do
      {:ok, _account} ->
        Agent.get_and_update(bank, fn state ->
          with ts <- Simulation.current_timestamp(state.sim_no),
               # a sanity check for easier reasoning later...
               {:ok, bank, loan_no, _t} <-
                 BM.request_loan(
                   state.bank,
                   acc_no,
                   amount,
                   duration,
                   rate,
                   frequency,
                   type,
                   ts
                 ) do
            {{:ok, loan_no}, %{state | bank: bank}}
          end
        end)

      {:error, _reason} ->
        {:error, :account_not_found}
    end
  end

  @doc """
  Get loan matching `loan_no`.
  """
  def get_loan(bank, loan_no) do
    Agent.get(bank, fn state -> BM.get_loan(state.bank, loan_no) end)
  end

  @doc """
  Get all loans belonging to a given customer.
  """
  def get_loans(bank, customer_no) do
    Agent.get(bank, fn state -> BM.get_loans(state.bank, customer_no) end)
  end

  @doc """
  Returns outstanding loans matching `customer_no`.
  """
  def outstanding_loans(bank, customer_no) do
    Agent.get(bank, fn state -> BM.outstanding_loans(state.bank, customer_no) end)
  end

  @doc """
  Returns fully paid loans matching `customer_no`.
  """
  def paid_loans(bank, customer_no) do
    Agent.get(bank, fn state -> BM.paid_loans(state.bank, customer_no) end)
  end

  @doc """
  Get the next loan payment due for loan matching `loan_no`.
  """
  def next_payment(bank, loan_no) when is_binary(loan_no) do
    Agent.get(bank, fn state -> BM.next_payment(state.bank, loan_no) end)
  end

  @doc """
  Uses the `loan_no` to find the next due payment and charge both principal and
  interest the account matching `acc_no` and return the corresponding transactions.
  """
  def make_next_payment(agent, loan_no, acc_no) do
    Agent.get_and_update(agent, fn state ->
      with ts <- Simulation.current_timestamp(state.sim_no),
           {:ok, bank, t} <- BM.make_next_payment(state.bank, loan_no, acc_no, ts) do
        {{:ok, t}, %{state | bank: bank}}
      else
        {:error, _reason} = err ->
          {err, state}
      end
    end)
  end

  #############################################################################
  #### Audit
  #############################################################################

  @doc """
  Get the total for ledgers matching `criteria`.

  Criteria can be a valid account type or the name of a ledger.
  """
  def ledger_total(bank, criteria) do
    Agent.get(bank, fn state ->
      BM.ledger_total(state.bank, criteria)
    end)
  end

  @doc """
  Audits the general ledger based on Assets = Liabilities + Equity.
  """
  def audit(bank) do
    Agent.get(bank, fn state ->
      BM.audit(state.bank)
    end)
  end

  #############################################################################
  #### Borrower POC
  #############################################################################

  @doc """
  Hire a borrower that gets paid to afford her next payment.
  """
  def hire_borrower(bank, customer_no, acc_no, loan_no) do
    Agent.get_and_update(bank, fn state ->
      IO.puts("... \"#{state.agent_no}\" hiring borrower \"#{customer_no}\"")

      case Enum.find(state.borrowers, fn b -> b == {customer_no, acc_no, loan_no} end) do
        nil -> {:ok, %{state | borrowers: [{customer_no, acc_no, loan_no} | state.borrowers]}}
        _ -> {:ok, state}
      end
    end)
  end

  defp fire_borrowers(bank) do
    state = Agent.get(bank, & &1)

    borrowers =
      Enum.filter(state.borrowers, fn {customer_no, _acc_no, _loan_no} ->
        has_debt?(bank, customer_no)
      end)

    if state.borrowers != borrowers do
      Agent.update(bank, fn state ->
        IO.puts("...firing borrowers #{inspect(state.borrowers -- borrowers)}")
        %{state | borrowers: borrowers}
      end)
    else
      :ok
    end
  end

  defp pay_borrowers(bank) do
    state = Agent.get(bank, & &1)

    if length(state.borrowers) > 0 do
      IO.puts("...paying borrowers #{inspect(state.borrowers)}")

      # Pay the borrowers enough so they can afford their next payment
      Enum.each(state.borrowers, fn {_customer_no, acc_no, loan_no} ->
        {:ok, payment} = next_payment(bank, loan_no)
        {:ok, account} = get_account(bank, "interest_income")

        {:ok, _trans} =
          transfer(
            bank,
            "interest_income",
            acc_no,
            min(Payment.total(payment), account.deposit),
            "Borrower salary payment"
          )
      end)
    else
      :ok
    end
  end

  #############################################################################
  #### Evaluation
  #############################################################################

  @impl true
  def init(agent, _simulation) do
    state = Agent.get(agent, & &1)
    IO.puts("--> initializing \"#{state.agent_no}\"")

    Agent.update(agent, fn state ->
      IO.puts("... creating the internal manager for \"#{state.agent_no}\"")
      %{state | bank: BM.create(bank_no: state.agent_no)}
    end)

    :ok
  end

  @doc """
  Evaluates the bank inside a simulation for example by collecting debt, paying
  interest, hiring or firing employees.
  """
  @impl true
  def eval(agent, _simulation) do
    state = Agent.get(agent, & &1)
    IO.puts("--> evaluating \"#{state.agent_no}\"")

    # Fire borrowers that have paid off their debt and pay salaries to the rest
    :ok = fire_borrowers(agent)
    :ok = pay_borrowers(agent)

    :ok
  end
end
