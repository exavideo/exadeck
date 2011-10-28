# Copyright 2011 Exavideo LLC.
# 
# This file is part of Exadeck.
# 
# Exadeck is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# Exadeck is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with Exadeck.  If not, see <http://www.gnu.org/licenses/>.

class Subprocess
    def start
        # check if the process is already running
        if @pid
            update_status
            if @pid
                fail "process was already running"
            end
        end

        pread_stdout, pwrite_stdout = IO.pipe
        pread_stderr, pwrite_stderr = IO.pipe
        pid = fork

        if pid == nil
            # child process
            Process.setsid
            $stdin.close
            $stdout.reopen pwrite_stdout
            $stderr.reopen pwrite_stderr

            exec cmd
            puts "exec failed???"
            exit! 1
        else
            @pid = pid
            @exited = nil
            @status = nil
            Thread.new { process_input(pread_stdout, stdout_filters) }
            Thread.new { process_input(pread_stderr, stderr_filters) }
        end
    end

    def process_line(filters, line)
        filters.each do |filter|
            match = filter[0].match(line)
            if match
                if (filter[1].arity == 1)
                    self.instance_exec(match, &filter[1])
                elsif (filter[1].arity == 0)
                    self.instance_exec(&filter[1])
                end
            end
        end
    end

    def process_input(pipe, filters)
        begin
            line = ''
            while true
                ch = pipe.read(1)

                if ch == nil
                    break
                elsif ch.ord < 32
                    process_line(filters, line)
                    line = ''
                else
                    line += ch 
                end
            end
        rescue EOFError
            # do nothing
        rescue Exception => e
            p e
        end
    end

    def update_status
        check_process
        @status ||= Process.waitpid(@pid, Process::WNOHANG)
        if @status
            @pid = nil
            @exited = true
        end
    end

    def is_running
        if @pid.nil?
            false
        else
            update_status
            if @status.nil?
                true
            else
                false
            end
        end
    end

    def exit_status
        fail 'process has not exited yet' unless @exited
        update_status
        @status.to_i
    end
    
    def wait_with_timeout(timeout)
        # use this hack because Ruby doesn't support various things
        # that would be needed to do it right (sigtimedwait etc)
        start_time = Time.now
        
        check_process

        while Time.now - start_time < timeout
            if @status.nil?
                break
            else
                update_status
            end
            sleep 0.1
        end
    end

    def wait(timeout = nil)
        if timeout
            wait_with_timeout(timeout)
        else
            check_process
            if @status.nil?
                @status = Process.waitpid(@pid)
            end
        end
    end

    def kill(signal)
        check_process
        Process.kill(signal, @pid)
    end

    def cmd
        @cmd ||= self.class.cmd
        @cmd
    end

    def cmd=(str)
        @cmd = str
    end

    def stderr_filters
        self.class.stderr_filters
    end

    def stdout_filters
        self.class.stdout_filters
    end


    def self.cmd(cmd=nil)
        @cmd ||= ''
        if cmd
            @cmd = cmd
        end
        @cmd
    end

    def self.stderr(regex, &block)
        stderr_filters << [ regex, block ]
    end

    def self.stdout(regex, &block)
        stdout_filters << [ regex, block ]
    end

    def self.stdout_filters
        @stdout_filters ||= []
        @stdout_filters
    end

    def self.stderr_filters
        @stderr_filters ||= []
        @stderr_filters
    end

    def cpu_usage_sample
        # this doesn't work!!

        # do cool shit with /proc eventually
        myproc = IO.read("/proc/#{@pid}/stat")
        global_stats = IO.readlines('/proc/stat')
        
        myproc_fields = myproc.split(/\s+/)
        p myproc_fields

        myproc_total_cpu = myproc_fields[15].to_i + myproc_fields[16].to_i 
        cpuline = ''
        global_stats.each do |line|
            if line =~ /cpu\s/
                cpuline = line
            end
        end

        total_cpu = 0
        cpufields = cpuline.split(/\s+/)
        p cpufields

        cpufields.drop(1).each do |field|
            total_cpu += field.to_i    
        end

        return [myproc_total_cpu, total_cpu]
    end

    def cpu_usage
        p1, t1 = cpu_usage_sample
        sleep 0.1
        p2, t2 = cpu_usage_sample

        (p2 - p1).to_f / (t2 - t1).to_f
    end

    def json_status
        if is_running
            {
                :is_running => true,
                :pid => @pid,
                :cpu => cpu_usage,
                :cmd => cmd
            }
        else
            {
                :is_running => false,
                :cmd => cmd
            }
        end
    end

protected
    def check_process
        if @pid == nil
            fail "process was never started"
        end
    end
end
