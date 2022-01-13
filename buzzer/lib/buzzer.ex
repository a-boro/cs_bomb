defmodule Buzzer do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    gpio_pin = opts[:gpio_pin] || 21
    {:ok, gpio_ref} = Circuits.GPIO.open(gpio_pin, :output)

    {:ok, gpio_ref: gpio_ref}
  end

  def turn_on, do: GenServer.cast(__MODULE__, :on)
  def turn_off, do: GenServer.cast(__MODULE__, :off)

  @impl true
  def handle_cast(:on, state) do
    Circuits.GPIO.write(state[:gpio_ref], 1)

    {:noreply, state}
  end

  @impl true
  def handle_cast(:off, state) do
    Circuits.GPIO.write(state[:gpio_ref], 0)

    {:noreply, state}
  end
end
