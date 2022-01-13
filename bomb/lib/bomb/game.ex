defmodule Bomb.Game do
  def activate_timer do
    for _n <- 1..15, do: make_bip(0.5)
    for _n <- 1..15, do: make_bip(1)
    for _n <- 1..15, do: make_bip(1.5)
    for _n <- 1..15, do: make_bip(2)

    :ok = Buzzer.turn_on()
    :ok = Bomb.GameWorker.bomb_exploded()
  end

  defp make_bip(bip_per_sec) do
    :ok = Buzzer.turn_on()
    Process.sleep(100)
    :ok = Buzzer.turn_off()

    case bip_per_sec do
      0.5 -> Process.sleep(2000)
      1 -> Process.sleep(1000)
      1.5 -> Process.sleep(750)
      2 -> Process.sleep(500)
    end
  end

  def create_password(keys) do
    keys
    |> Enum.split(7)
    |> elem(0)
    |> Enum.map(fn
      "*" -> Enum.random(0..9)
      key -> key
    end)
    |> Enum.join("")
  end

  def set_start_screen do
    :ok = LCD.clear()
    :ok = LCD.print("Create Password:")
    :ok = LCD.set_cursor(2, 4)

    :ok
  end

  def set_password_screen(password) do
    keys_length = String.length(password)
    cols_indentation = Integer.floor_div(16 - keys_length, 2)

    :ok = LCD.clear()
    :ok = LCD.set_cursor(1, cols_indentation)
    :ok = Enum.each(1..keys_length, fn _ -> LCD.print("*") end)

    :ok
  end

  def set_new_password_screen(defuse_password, bomb_password) do
    password_length = String.length(bomb_password)
    cols_indent = Integer.floor_div(16 - password_length, 2)
    difference = password_length - String.length(defuse_password)
    numbers_left = if difference == 0, do: "", else: for(_i <- 1..difference, into: "", do: "*")

    :ok = LCD.clear()
    :ok = LCD.set_cursor(1, cols_indent)
    :ok = LCD.print(defuse_password <> numbers_left)

    :ok
  end

  def set_bomb_defused_screen do
    :ok = LCD.clear()
    :ok = LCD.move_cursor_right(6)
    :ok = LCD.print("BOMB")
    :ok = LCD.set_cursor(2, 4)
    :ok = LCD.print("DEFUSED!")

    :ok
  end

  def set_game_over_screen do
    :ok = LCD.clear()
    :ok = LCD.set_cursor(2, 3)
    :ok = LCD.print("GAME OVER!")

    :ok
  end
end
