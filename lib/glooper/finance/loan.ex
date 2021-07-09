defmodule Glooper.Loan do
  @moduledoc """
  A loan is the record associated with the lending of money to a customer
  detailing the amount, rate, duration, frequency of payments and the type
  of loan as well as the calculated payment schedule.
  """

  alias __MODULE__
  alias Glooper.{Payment, Utils}
  alias :math, as: Math

  @loan_types ~w(negative indexed compound simple)

  @enforce_keys [:principal, :rate, :duration, :frequency, :type]
  @optional_keys [
    payments_made: [],
    payments_remaining: [],
    creator: nil,
    customer_no: nil,
    loan_no: nil
  ]

  defstruct @enforce_keys ++ @optional_keys

  @doc """
  Creates a new loan with a unique loan number. The payments are initialized
  according to principal, rate, duration, frequency and loan type.
  """
  def create(init_args) do
    struct!(Loan, init_args)
    |> init_payments()
    |> init_loan_no()
  end

  def create(principal, rate, duration, frequency \\ 1, type \\ "compound", opts \\ [])
      when type in @loan_types do
    create(
      Keyword.merge(
        [principal: principal, rate: rate, duration: duration, frequency: frequency, type: type],
        opts
      )
    )
  end

  defp init_loan_no(%Loan{loan_no: nil} = loan), do: %{loan | loan_no: Utils.gen_loan_no()}
  defp init_loan_no(%Loan{loan_no: _} = loan), do: loan

  #############################################################################
  #### Payments
  #############################################################################

  @doc """
  Returns true if the loan has been paid off otherwise false.
  """
  def paid_off?(%Loan{payments_remaining: []}), do: true
  def paid_off?(%Loan{payments_remaining: [_next | _rest]}), do: false

  @doc """
  Get the next payment due for the loan. Returns nil if no payments are due.
  """
  def next_payment(%Loan{payments_remaining: []}), do: {:error, :loan_paid_off}
  def next_payment(%Loan{payments_remaining: [next | _rest]}), do: {:ok, next}

  @doc """
  Makes the next payment on the loan.
  """
  def make_payment(%Loan{payments_remaining: []}, _payment_no), do: {:error, :loan_paid_off}

  def make_payment(%Loan{payments_remaining: [next | rest]} = loan, payment_no)
      when next.payment_no == payment_no do
    {:ok, %Loan{loan | payments_remaining: rest, payments_made: [next | loan.payments_made]}}
  end

  @doc """
  Calculates the sum of principal of payments remaining.
  """
  def principal_outstanding(%Loan{payments_remaining: remaining}),
    do: Enum.reduce(remaining, 0, fn p, sum -> sum + p.principal end)

  @doc """
  Calculates the sum of interest of payments remaining.
  """
  def interest_outstanding(%Loan{payments_remaining: remaining}),
    do: Enum.reduce(remaining, 0, fn p, sum -> sum + p.interest end)

  @doc """
  Calculates the sum of principal and interest of payments remaining
  """
  def total_outstanding(%Loan{payments_remaining: remaining}),
    do: Enum.reduce(remaining, 0, fn p, sum -> sum + p.principal + p.interest end)

  @doc """
  Calculates the sum of principal of payments made.
  """
  def principal_paid(%Loan{payments_made: made}),
    do: Enum.reduce(made, 0, fn p, sum -> sum + p.principal end)

  @doc """
  Calculates the sum of interest of payments made.
  """
  def interest_paid(%Loan{payments_made: made}),
    do: Enum.reduce(made, 0, fn p, sum -> sum + p.interest end)

  @doc """
  Calculates the sum of principal and interest of payments made.
  """
  def total_paid(%Loan{payments_made: made}),
    do: Enum.reduce(made, 0, fn p, sum -> sum + p.principal + p.interest end)

  #############################################################################
  #### Loan Internals
  #############################################################################

  @doc """
  Calculates the payment count from duration and frequency.
  """
  def payment_count(%Loan{duration: duration, frequency: frequency}), do: div(duration, frequency)

  @doc """
  Calculates and assigns loan payments according to amount, rate, duration, frequency, and
  type for the loan type.
  """
  def calculate_payments(%Loan{type: "simple"} = loan) do
    # TODO: add support for unscheduled payments of arbitrary amount

    monthly_rate = loan.rate / 12.0

    no_payments = div(loan.duration, loan.frequency)
    payments_made = length(loan.payments_made)
    monthly_payment = loan.principal / no_payments

    principal_remains = loan.principal - principal_paid(loan)
    no_payments_remaining = trunc(Math.ceil(principal_remains / monthly_payment))
    payment_range = (payments_made + 1)..no_payments_remaining

    {schedule, _} =
      Enum.map_reduce(payment_range, {principal_remains, 0}, fn i, balance ->
        {principal_remains, interest_remains} = balance
        interest_payment = principal_remains * monthly_rate

        # compensate for floating point error when calculating last payment
        principal_rounding =
          case i do
            ^no_payments_remaining -> principal_remains - monthly_payment
            _ -> 0
          end

        interest_rounding =
          case i do
            ^no_payments_remaining -> interest_remains - interest_payment
            _ -> 0
          end

        {%Payment{
           payment_no: i,
           principal: round(monthly_payment + principal_rounding),
           interest: round(interest_payment + interest_rounding)
         }, {principal_remains - monthly_payment, 0}}
      end)

    {:ok, schedule}

    schedule
  end

  def calculate_payments(%Loan{type: "compound"} = loan) do
    # TODO: add support for unscheduled payments of arbitrary amount

    monthly_rate = loan.rate * 0.01 / 12.0

    no_payments = div(loan.duration, loan.frequency)
    payments_made = length(loan.payments_made)

    monthly_payment =
      case monthly_rate do
        x when x > 0.0 ->
          loan.principal * monthly_rate / (1.0 - Math.pow(1.0 + monthly_rate, -no_payments))

        x when x <= 0.0 ->
          loan.principal / no_payments
      end

    principal_remains = loan.principal - principal_paid(loan)

    # trunc(Math.ceil(principal_remains / monthly_payment))
    no_payments_remaining = no_payments

    payment_range = (payments_made + 1)..no_payments_remaining

    {schedule, _} =
      Enum.map_reduce(payment_range, {principal_remains, 0, 0}, fn i, balance ->
        {principal_remains, accumulated_interest, total_interest} = balance
        interest_amount = principal_remains * monthly_rate
        interest_payment = interest_amount
        principal_payment = monthly_payment - interest_amount

        # compensate for floating point errors when calculating the last payment
        principal_rounding =
          case i do
            ^no_payments_remaining -> round(principal_remains - principal_payment)
            _ -> 0
          end

        interest_rounding =
          case i do
            ^no_payments_remaining -> round(total_interest - accumulated_interest)
            _ -> 0
          end

        {%Payment{
           payment_no: i,
           principal: round(principal_payment) + principal_rounding,
           interest: round(interest_payment) + interest_rounding
         },
         {principal_remains - principal_payment, accumulated_interest + interest_payment,
          total_interest + interest_amount}}
      end)

    schedule
  end

  @doc """
  Calculate and assign payment schedule to loan.
  """
  def init_payments(%Loan{} = loan) do
    %{loan | payments_made: [], payments_remaining: calculate_payments(loan)}
  end
end
