defmodule Keypad do
  use GenServer

  @matrix [
    ["1", "2", "3"],
    ["4", "5", "6"],
    ["7", "8", "9"],
    ["*", "0", "#"]
  ]

  @row_pins [26, 6, 13, 19]
  @col_pins [16, 12, 20]

  defguard valid_press(current, prev) when (current - prev) / 1.0e6 > 200

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(state) do
    state = %{
      function: Map.fetch!(state, :function),
      last_press: 0
    }

    send(self(), :init)

    {:ok, state}
  end

  def handle_info(:init, state) do
    pin_refs = initialize_rows_and_cols(@col_pins, @row_pins)

    state = Map.merge(state, pin_refs)

    {:noreply, state}
  end

  def handle_info({:circuits_gpio, row_pin, time, 0}, %{last_press: prev} = state)
      when valid_press(time, prev) do
    {row_pin, row_index} =
      state.row_pins
      |> Stream.with_index()
      |> Enum.find(fn {row, _i} ->
        Circuits.GPIO.pin(row) == row_pin
      end)

    col_index =
      state.col_pins
      |> Stream.with_index()
      |> Enum.reduce_while([], fn {col_pin, col_index}, _acc ->
        Circuits.GPIO.write(col_pin, 1)
        row_val = Circuits.GPIO.read(row_pin)
        Circuits.GPIO.write(col_pin, 0)

        case row_val do
          1 -> {:halt, col_index}
          0 -> {:cont, []}
        end
      end)

    key_pressed =
      @matrix
      |> Enum.at(row_index)
      |> Enum.at(col_index)

    function = state[:function]
    _ = function.(key_pressed)
    IO.inspect(key_pressed, label: "KEYPAD")

    {:noreply, %{state | last_press: time}}
  end

  # ignore messages that are too quick
  def handle_info({:circuits_gpio, _, _time, _}, state), do: {:noreply, state}

  defp initialize_rows_and_cols(col_pins, row_pins) do
    row_pins =
      Enum.map(row_pins, fn row_pin ->
        {:ok, pin_ref} = Circuits.GPIO.open(row_pin, :input, pull_mode: :pullup)
        :ok = Circuits.GPIO.set_interrupts(pin_ref, :falling)

        pin_ref
      end)

    col_pins =
      Enum.map(col_pins, fn col_pin ->
        {:ok, pin_ref} = Circuits.GPIO.open(col_pin, :output, initial_value: 0)

        pin_ref
      end)

    %{col_pins: col_pins, row_pins: row_pins}
  end
end
