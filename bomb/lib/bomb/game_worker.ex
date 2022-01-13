defmodule Bomb.GameWorker do
  use GenServer
  alias Bomb.Game

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def key_press(key), do: GenServer.cast(__MODULE__, {:key_pressed, key})
  def bomb_exploded, do: GenServer.cast(__MODULE__, :bomb_exploded)

  def init(_opts) do
    state = %{
      keys: [],
      bomb_password: "",
      defuse_password: "",
      stage: :start,
      task: nil
    }

    send(self(), :start)
    {:ok, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  # stage :start
  def handle_info(:start, state) do
    :ok = Buzzer.turn_off()
    :ok = Game.set_start_screen()

    state = %{state | stage: :create_password}
    {:noreply, state}
  end

  # stage: :bomb_activated
  def handle_info(:bomb_activated, state) do
    keys = state[:keys]
    bomb_password = Game.create_password(keys)

    :ok = Game.set_password_screen(bomb_password)
    task = Task.async(fn -> Game.activate_timer() end)

    state = %{
      state
      | bomb_password: bomb_password,
        stage: :bomb_defusing,
        task: task.pid
    }

    {:noreply, state}
  end

  def handle_cast({:key_pressed, "#"}, %{stage: :create_password, keys: keys} = state)
      when keys != [] do
    send(self(), :bomb_activated)

    {:noreply, %{state | stage: :bomb_activated}}
  end

  # stage: :create_password
  def handle_cast({:key_pressed, key}, %{stage: :create_password} = state) do
    if length(state[:keys]) < 7 and key != "#" do
      :ok = LCD.print(key)
      keys = state[:keys] ++ [key]

      {:noreply, %{state | keys: keys}}
    else
      {:noreply, state}
    end
  end

  # stage :bomb_defusing
  def handle_cast({:key_pressed, key}, %{stage: :bomb_defusing} = state)
      when key not in ["#", "*"] do
    bomb_password = state[:bomb_password]
    new_defuse_password = state[:defuse_password] <> key

    bomb_password_len = String.length(bomb_password)
    new_defuse_password_len = String.length(new_defuse_password)

    cond do
      bomb_password == new_defuse_password ->
        :ok = GenServer.cast(__MODULE__, :bomb_defused)
        {:noreply, %{state | stage: :bomb_defused}}

      new_defuse_password_len == bomb_password_len ->
        :ok = Game.set_new_password_screen(new_defuse_password, bomb_password)
        Process.sleep(250)
        :ok = Game.set_password_screen(bomb_password)
        {:noreply, %{state | defuse_password: ""}}

      true ->
        :ok = Game.set_new_password_screen(new_defuse_password, bomb_password)
        {:noreply, %{state | defuse_password: new_defuse_password}}
    end
  end

  def handle_cast({:key_pressed, _key}, state) do
    {:noreply, state}
  end

  def handle_cast(:bomb_defused, state) do
    :ok = Buzzer.turn_off()
    # _ = Process.exit(state[:task], :kill)
    :ok = Game.set_bomb_defused_screen()

    :ok = restart()

    {:noreply, state}
  end

  def handle_cast(:bomb_exploded, %{stage: :bomb_defusing} = state) do
    :ok = Game.set_game_over_screen()

    :ok = restart()
    {:noreply, %{state | stage: :bomb_exploded}}
  end

  def restart do
    Process.sleep(5000)
    GenServer.stop(self(), :normal)

    :ok
  end
end
