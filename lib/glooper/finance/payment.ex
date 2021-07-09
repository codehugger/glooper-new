defmodule Glooper.Payment do
  @moduledoc """
  A payment is a description of the principal and interest due when paying off a
  loan.
  """

  alias __MODULE__

  @enforce_keys [:payment_no]
  @optional_keys [principal: 0, interest: 0]

  defstruct @enforce_keys ++ @optional_keys

  def create(init_arg) do
    struct!(Payment, init_arg)
  end

  def create(payment_no, principal, interest \\ 0)
      when is_binary(payment_no) and is_number(principal) and is_number(interest) do
    create(payment_no: payment_no, principal: principal, interest: interest)
  end

  def total(%Payment{} = payment), do: payment.principal + payment.interest
end
