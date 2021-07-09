defmodule Glooper.Utils do
  # Global config defaults
  @alphabet Application.get_env(:glooper, :alphabet)
  @name_size Application.get_env(:glooper, :name_size, 6)
  @agent_no_digits Application.get_env(:glooper, :agent_no_digits, 6)
  @account_no_digits Application.get_env(:glooper, :account_no_digits, 6)
  @loan_no_digits Application.get_env(:glooper, :loan_no_digits, 6)
  @product_no_digits Application.get_env(:glooper, :product_no_digits, 10)
  @sim_no_digits Application.get_env(:glooper, :sim_no_digits, 10)
  @agent_no_digits Application.get_env(:glooper, :agent_no_digits, 6)

  def gen_nanoid(prefix \\ "", delimiter \\ "_", size \\ @name_size, alphabet \\ @alphabet) do
    case prefix do
      "" -> "#{Nanoid.generate(size, alphabet)}"
      _ -> "#{prefix}#{delimiter}#{Nanoid.generate(size, alphabet)}"
    end
  end

  def gen_account_no(prefix \\ "", delimiter \\ "_"),
    do: gen_nanoid(prefix, delimiter, @account_no_digits)

  def gen_agent_no(prefix \\ "", delimiter \\ "_"),
    do: gen_nanoid(prefix, delimiter, @agent_no_digits)

  def gen_sim_no(prefix \\ "SIM", delimiter \\ "_"),
    do: gen_nanoid(prefix, delimiter, @sim_no_digits)

  def gen_loan_no(prefix \\ "LOAN", delimiter \\ "_"),
    do: gen_nanoid(prefix, delimiter, @loan_no_digits)

  def gen_product_no(prefix \\ "PROD", delimiter \\ "_"),
    do: gen_nanoid(prefix, delimiter, @product_no_digits)
end
