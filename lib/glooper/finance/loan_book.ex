defmodule Glooper.LoanBook do
  @moduledoc """
  A record of the loans held by a bank.
  """

  # TODO: add support for unscheduled loan payments

  alias __MODULE__, as: LB
  alias Glooper.Loan

  @enforce_keys []
  @optional_keys [loans: %{}, customers: %{}]

  defstruct @enforce_keys ++ @optional_keys

  @loan_types Glooper.Finance.loan_types()

  def create(fields \\ []) do
    struct!(LB, fields)
  end

  #############################################################################
  #### Customers
  #############################################################################

  @doc """
  Returns true if loans with outstanding payments are found registered to
  `customer_no`, otherwise false.
  """
  def has_debt?(%LB{customers: customers}, customer_no)
      when not is_map_key(customers, customer_no),
      do: false

  def has_debt?(%LB{customers: customers} = lb, customer_no)
      when is_map_key(customers, customer_no) do
    length(outstanding_loans(lb, customer_no)) > 0
  end

  #############################################################################
  #### Loans
  #############################################################################

  @doc """
  Adds a new loan with precalculated payments to the loan book. Optionally the
  loan is associated with a creator and/or customer.
  """
  def add_loan(%LB{} = lb, amount, rate, duration, period, type, customer_no, creator \\ nil)
      when type in @loan_types do
    loan =
      Loan.create(amount, rate, duration, period, type, customer_no: customer_no, creator: creator)

    loans = Map.put(lb.loans, loan.loan_no, loan)

    customers =
      Map.update(lb.customers, customer_no, MapSet.new([loan.loan_no]), fn x ->
        MapSet.put(x, loan.loan_no)
      end)

    {:ok, {%LB{lb | loans: loans, customers: customers}, loan.loan_no}}
  end

  @doc """
  Get the loan matching `loan_no`.
  """
  def get_loan(%LB{loans: loans}, loan_no) when is_map_key(loans, loan_no) do
    {:ok, loans[loan_no]}
  end

  def get_loan(%LB{loans: loans}, loan_no) when not is_map_key(loans, loan_no),
    do: {:error, :not_found}

  @doc """
  Gets all loans belonging to the given customer.
  """
  def get_loans(%LB{customers: customers, loans: loans}, customer_no)
      when is_binary(customer_no) do
    Enum.map(customers[customer_no], fn loan_no -> loans[loan_no] end)
  end

  @doc """
  Gets loans with outstanding payments matching `customer_no`.
  """
  def outstanding_loans(%LB{customers: customers}, customer_no)
      when not is_map_key(customers, customer_no),
      do: []

  def outstanding_loans(%LB{customers: customers} = lb, customer_no)
      when is_map_key(customers, customer_no) do
    customers[customer_no]
    |> Enum.map(fn loan_no -> lb.loans[loan_no] end)
    |> Enum.filter(fn loan -> length(loan.payments_remaining) > 0 end)
  end

  @doc """
  Gets loans that have been paid fully matching `customer_no`.
  """
  def paid_loans(%LB{customers: customers}, customer_no)
      when not is_map_key(customers, customer_no),
      do: []

  def paid_loans(%LB{customers: customers} = lb, customer_no)
      when is_map_key(customers, customer_no) do
    customers[customer_no]
    |> Enum.map(fn loan_no -> lb.loans[loan_no] end)
    |> Enum.filter(fn loan -> length(loan.payments_remaining) == 0 end)
  end

  #############################################################################
  #### Payments
  #############################################################################

  @doc """
  Gets the next loan payment due for loan matching `loan_no`.
  """
  def next_payment(%LB{loans: loans}, loan_no)
      when is_binary(loan_no) and is_map_key(loans, loan_no) do
    Loan.next_payment(loans[loan_no])
  end

  @doc """
  Marks the next payment on the loan matching `loan_no` as paid.
  """
  def make_payment(%LB{loans: loans} = lb, loan_no, payment_no)
      when is_binary(loan_no) and is_map_key(loans, loan_no) do
    case Loan.make_payment(loans[loan_no], payment_no) do
      {:ok, loan} -> {:ok, %LB{lb | loans: Map.put(loans, loan_no, loan)}}
      {:error, _} = err -> err
    end
  end
end
