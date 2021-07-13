defmodule Glooper.BankHelpers do
  alias Glooper.Simulation

  #############################################################################
  #### Banking
  #############################################################################

  def get_bank_agent(sim_no, bank) do
    Simulation.get_agent(sim_no, bank)
  end

  def open_account(sim_no, bank, agent_no, label \\ "agent") do
    IO.puts("... \"#{label}\" is opening a deposit account")
    [{bank, module}] = get_bank_agent(sim_no, bank)

    case apply(module, :open_account, [bank, agent_no]) do
      {:ok, account_no} = res ->
        IO.puts("... \"#{label}\" successfully opened an account no: \"#{account_no}\"")
        res

      {:error, _reason} = err ->
        IO.puts("... \"#{label}\" was unable to open a deposit account \"#{err}\"")
        err
    end
  end

  def deposit_cash(_sim_no, _bank, _account_no, _amount, _label \\ "agent")
  # swallow zero deposit configurations instead of putting condition checks in every agent
  def deposit_cash(_sim_no, _bank, _account_no, amount, _label) when amount == 0,
    do: {:ok, nil}

  def deposit_cash(sim_no, bank, account_no, amount, label) when amount > 0 do
    IO.puts("... \"#{label}\" is depositing cash amount #{amount} to \"#{account_no}\"")
    [{bank, module}] = get_bank_agent(sim_no, bank)
    apply(module, :deposit_cash, [bank, account_no, amount])
  end

  def get_loan(_sim_no, _bank, _account_no, _label \\ "agent")

  def get_loan(_sim_no, _bank, "", _label) do
    {:error, :not_found}
  end

  def get_loan(sim_no, bank, loan_no, label) do
    IO.puts("... \"#{label}\" fetching information on loan \"#{loan_no}\" from \"#{bank}\"")
    [{bank, module}] = get_bank_agent(sim_no, bank)
    apply(module, :get_loan, [bank, loan_no])
  end

  def request_loan(sim_no, bank, account_no, amount, duration, interest, label \\ "agent") do
    IO.puts(
      "... \"#{label}\" requesting loan (amount: #{amount}, duration: #{duration}, interest: #{interest}) for account #{account_no}"
    )

    [{bank, module}] = get_bank_agent(sim_no, bank)

    case apply(module, :request_loan, [bank, account_no, amount, duration, interest]) do
      {:ok, loan_no} = res ->
        IO.puts(
          "... \"#{label}\" was granted loan \"#{loan_no}\" with #{amount} deposited to \"#{account_no}\""
        )

        res

      {:error, _reason} = err ->
        IO.puts("... \"#{label}\" was unable to secure a loan")
        err
    end
  end

  def make_next_payment(sim_no, bank, loan_no, account_no, label \\ "agent") do
    IO.puts(
      "... \"#{label}\" is making the next payment of loan \"#{loan_no}\" from account \"#{account_no}\""
    )

    [{bank, module}] = get_bank_agent(sim_no, bank)

    case apply(module, :make_next_payment, [bank, loan_no, account_no]) do
      {:ok, _t} = res ->
        IO.puts("... \"#{label}\" successfully made the next payment to loan \"#{loan_no}\"")
        res

      {:error, reason} = err ->
        IO.puts("... \"#{label}\" could not make next payment to loan \"#{loan_no}\" (#{reason})")
        err
    end
  end

  #############################################################################
  #### Time-tracking
  #############################################################################

  def current_timestamp(sim_no) do
    {:ok, Simulation.current_timestamp(sim_no)}
  end
end
