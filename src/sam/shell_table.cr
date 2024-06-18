require "./task"

{% if flag?(:win32) %}
  require "lib_c"
  
  lib LibC
    fun GetConsoleScreenBufferInfo(handle : UInt32, info : UInt8*) : Int32
  end
{% end %}

module Sam
  # :nodoc:
  class ShellTable
    BORDER = " | "

    getter tasks : Array(Task), width : Int32

    def initialize(@tasks)
      @width = terminal_width
    end

    def generate
      String.build do |io|
        write_header(io)
        tasks.each { |task| write_task(io, task) }
      end
    end

    private def terminal_width
      {% if flag?(:win32) %}
        get_windows_width
      {% else %}
        if has_tput?
          `tput cols`.to_i
        elsif has_stty?
          `stty size`.chomp.split(' ')[1].to_i
        else
          80
        end
      {% end %}
    end


    private def has_tput?
      {% if flag?(:win32) %}
        false
      {% else %}
        !`which tput`.empty?
      {% end %}
    end

    private def get_windows_width : Int32
      handle = LibC.GetStdHandle(-12).address.to_u32
      csbi = Bytes.new(22)
      
      return 80 unless LibC.GetConsoleScreenBufferInfo(handle, csbi.to_unsafe) != 0
      
      right = csbi[14].to_i32 | (csbi[15].to_i32 << 8)
      left = csbi[10].to_i32 | (csbi[11].to_i32 << 8)
      
      right - left + 1
    end

    private def has_stty?
      {% if flag?(:win32) %}
        false
      {% else %}
        return false if `which stty`.empty?

        /\d* \d*/.matches?(`stty size`)
      {% end %}
    end

    private def write_header(io)
      io << "Name".ljust(name_column_width) << "   Description\n"
      io << "-" * name_column_width << BORDER << "-" * description_column_width << "\n"
    end

    private def write_task(io, task)
      name = task.path
      description = task.description
      while !(name.empty? && description.empty?)
        if !name.empty?
          segment_length = [name.size, name_column_width].min
          io << name[0...segment_length].ljust(name_column_width)

          name = name.size == segment_length ? "" : name[segment_length..-1]
        else
          io << " " * name_column_width
        end
        io << BORDER

        if !description.empty?
          segment_length = [description.size, description_column_width].min
          io << description[0...segment_length]
          description = description.size == segment_length ? "" : description[segment_length..-1]
        else
          io << " " * description_column_width
        end
        io << "\n"
      end
    end

    private def name_column_width
      @name_column_width ||=
        [
          [
            tasks.map(&.path.size).max,
            clean_width * min_content_width_ratio,
          ].max,
          clean_width * max_content_width_ration,
        ].min.to_i.as(Int32)
    end

    private def description_column_width
      @description_column_width ||= (clean_width - name_column_width).as(Int32)
    end

    private def max_content_width_ration
      0.5
    end

    private def min_content_width_ratio
      0.1
    end

    private def clean_width
      width - 3
    end
  end
end
