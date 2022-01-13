defmodule LCD do
  use GenServer
  use Bitwise

  @rows 2
  @cols 16
  @name __MODULE__

  @lcd_i2c_address 0x27
  @i2c_bus "i2c-1"

  @backlight_on 0x08
  @display_on 0x04
  @enable_bit 0x04
  @entry_left 0x02
  @font_size_5x8 0x00
  @font_size_5x10 0x04
  @number_of_lines_2 0x08
  @shift_right 0x04

  # commands
  @cmd_clear_display 0x01
  @cmd_display_control 0x08
  @cmd_entry_mode_set 0x04
  @cmd_function_set 0x20
  @cmd_cursor_shift_control 0x10
  @cmd_set_ddram_address 0x80

  # Interface
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  def clear, do: GenServer.cast(@name, :clear)
  def print(text) when is_binary(text), do: GenServer.cast(@name, {:print, text})
  def set_cursor(row, col), do: GenServer.cast(@name, {:set_cursor, row, col})
  def move_cursor_right(cols), do: GenServer.cast(@name, {:cursor_right, cols})
  def move_cursor_left(cols), do: GenServer.cast(@name, {:cursor_left, cols})

  def init(_opts) do
    {:ok, i2c_ref} = Circuits.I2C.open(@i2c_bus)
    _i2c_ref = initialize_display(i2c_ref)

    {:ok, %{i2c_ref: i2c_ref}}
  end

  # Handlers
  def handle_cast(:clear, state) do
    state[:i2c_ref]
    |> write_instruction(@cmd_clear_display)
    |> delay(2)

    {:noreply, state}
  end

  def handle_cast({:print, text}, state) do
    rs_bit = 1

    text
    |> to_charlist()
    |> Enum.each(&write_byte(state[:i2c_ref], &1, rs_bit))

    {:noreply, state}
  end

  def handle_cast({:cursor_left, cols}, state) when cols > 0 do
    Enum.each(1..cols, fn _ ->
      write_instruction(state[:i2c_ref], @cmd_cursor_shift_control)
    end)

    {:noreply, state}
  end

  def handle_cast({:cursor_right, cols}, state) when cols > 0 do
    Enum.each(1..cols, fn _ ->
      write_instruction(state[:i2c_ref], @cmd_cursor_shift_control ||| @shift_right)
    end)

    {:noreply, state}
  end

  def handle_cast({:set_cursor, row_pos, col_pos}, state) do
    col_pos = min(col_pos, @cols - 1)
    row_pos = min(row_pos, @rows - 1)

    ddram_address =
      {0x00, 0x40, 0x00 + @cols, 0x40  + @cols}
      |> elem(row_pos)
      |> Kernel.+(col_pos)

    _ = write_instruction(state[:i2c_ref], @cmd_set_ddram_address ||| ddram_address)

    {:noreply, state}
  end

  # Helpers

  # Initializes the display for 4-bit interface.
  # See Hitachi HD44780 datasheet page 46 for details.
  defp initialize_display(i2c_ref) do
    entry_mode =  @cmd_entry_mode_set ||| @entry_left
    display_control = @cmd_display_control ||| @display_on
    function_set = @cmd_function_set ||| @font_size_5x8 ||| @number_of_lines_2

    i2c_ref
    # Function set (8-bit mode; Interface is 8 bits long)
    |> write_four_bits(0x03)
    |> delay(5)
    |> write_four_bits(0x03)
    |> delay(5)
    |> write_four_bits(0x03)
    |> delay(1)
    |> write_four_bits(0x02) # Function set (4-bit mode; Interface is 8 bits long)
    |> write_instruction(function_set) # Function set (4-bit mode; Interface is 4 bits long)
    |> write_instruction(display_control)
    |> write_instruction(@cmd_clear_display)
    |> delay(2)
    |> write_instruction(entry_mode)
  end

  defp write_instruction(i2c_ref, byte), do: write_byte(i2c_ref, byte, 0)

  defp write_byte(i2c_ref, byte, rs_bit) when byte in 0..255 and rs_bit in 0..1 do
    <<high_four_bits::4, low_four_bits::4>> = <<byte>>

    i2c_ref
    |> write_four_bits(high_four_bits, rs_bit)
    |> write_four_bits(low_four_bits, rs_bit)
  end

  defp write_four_bits(i2c_ref, four_bits, rs_bit \\ 0)
       when is_integer(four_bits) and four_bits in 0..15 and rs_bit in 0..1 do
    # Map the four bits to the data pins.
    <<d7::1, d6::1, d5::1, d4::1>> = <<four_bits::4>>
    <<data_byte>> = <<d7::1, d6::1, d5::1, d4::1, 0::1, 0::1, 0::1, rs_bit::1>>

    i2c_ref
    |> execute_write(data_byte)
    |> pulse_enable(data_byte)
  end

  defp pulse_enable(i2c_ref, byte) do
    i2c_ref
    |> execute_write(byte ||| @enable_bit)
    |> execute_write(byte &&& ~~~@enable_bit)
  end

  defp execute_write(i2c_ref, byte) do
    data = byte ||| @backlight_on
    :ok = Circuits.I2C.write(i2c_ref, @lcd_i2c_address, [data])

    i2c_ref
  end

  defp delay(i2c_ref, time) do
    :ok = Process.sleep(time)

    i2c_ref
  end
end
