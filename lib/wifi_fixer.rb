require "wifi_fixer/version"

HOST_TO_PING  = "google.com"
RESTART_AFTER = 4
PASSING_REGEX = Regexp.new("1 packets received")


module WifiFixer
  class ScriptProvider
    require 'rbconfig'

    # http://stackoverflow.com/questions/11784109/detecting-operating-systems-in-ruby
    def os
      @os ||= (
        host_os = RbConfig::CONFIG['host_os']
        case host_os
        when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
          :windows
        when /darwin|mac os/
          :macosx
        when /linux/
          :linux
        when /solaris|bsd/
          :unix
        else
          raise Error::WebDriverError, "unknown os: #{host_os.inspect}"
        end
      )
    end

    def script
      case os
        when :macosx
          "networksetup -setairportpower en0 off && networksetup -setairportpower en0 on > /dev/null"
        when :linux
          # this might require more refinement + sudo rights??
          "sudo systemctl restart networking.service"
      end
    end
  end

  class Runner
    def initialize
      @failed = 0
      @pings  = 0
    end

    def loop
      while true do
        full_process
        print_progress
        sleep 1
      end
    end

    private

    def print_progress
      if @pings % 5 == 0
        puts "#{@pings}..."
      end
    end

    def full_process
      if check.match(PASSING_REGEX)
        reset_failed
      else
        increase_failed
        restart_if_needed!
      end
    end

    # 1 ping with timeout of 1 second
    def check
      @pings += 1
      `ping -c 1 -t 1 #{HOST_TO_PING}`
    end

    def increase_failed
      @failed += 1
    end

    def restart_if_needed!
      return if @failed < RESTART_AFTER
      puts "restarting at #{Time.now}"
      `#{script_provider.script}`
    end

    def script_provider
      @script_provider ||= ScriptProvider.new
    end

    def reset_failed
      @failed = 0
    end
  end
end
