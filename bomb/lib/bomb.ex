defmodule Bomb do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Buzzer,
      {Keypad, %{function: &Bomb.GameWorker.key_press/1}},
      LCD,
      Bomb.GameWorker
    ]

    opts = [strategy: :one_for_one, name: Bomb.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
