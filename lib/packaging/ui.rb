module Packaging
  class UI
    LEVELS = %w(silent error warn confirm info debug)

    def warn(message, newline = nil)
      puts message
    end

    def debug(message, newline = nil)
      puts message
    end

    def trace(message, newline = nil)
      puts message
    end

    def error(message, newline = nil)
      puts message
    end

    def info(message, newline = nil)
      puts message
    end

    def confirm(message, newline = nil)
    end

    def debug?
      true
    end

    def ask(message)
    end

    def quiet?
      false
    end

    def level=(level)
      raise ArgumentError unless LEVELS.include?(level.to_s)
      @level = level
    end

    def level(name = nil)
      name ? LEVELS.index(name) <= LEVELS.index(@level) : @level
    end

    def silence
      old_level, @level = @level, "silent"
      yield
    ensure
      @level = old_level
    end
  end
end
