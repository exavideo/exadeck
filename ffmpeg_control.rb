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

require 'patchbay'
require 'json'
require_relative 'subprocess'

class FfmpegSubprocess < Subprocess
    def initialize(title=nil)
        @title = title
        super
    end
        
    stderr /frame=\s*(\d+)/ do |match|
        @frames_encoded = match[1]
    end

    stderr /fps=\s*(\d+)/ do |match|
        @fps = match[1]
    end

    stderr /size=\s*(\d+\w+)/ do |match|
        @size = match[1]
    end

    stderr /time=\s*(\S+)/ do |match|
        @time = match[1]
    end

    stderr /bitrate=\s*(\S+)/ do |match|
        @bitrate = match[1]
    end

    attr_reader :frames, :fps, :size, :time, :bitrate
    attr_accessor :title

    cmd 'ffmpeg -i /home/armena/openreplay2/test.mjpg -f rawvideo -s 1920x1080 - >/dev/null'

    def json_status
        {
            :time => @time,
            :bitrate => @bitrate,
            :size => @size,
            :fps => @fps,
            :frames_encoded => @frames_encoded,
            :title => @title
        }.merge(super)
    end
end

class ProcessControlApp < Patchbay
    get '/processes' do
        render :json => (@processes.map { |x| x.json_status }).to_json
    end

    get '/process/:id' do
        render :json => @processes[params[:id].to_i].json_status.to_json
    end

    put '/process/:id/start' do
        pr = @processes[params[:id].to_i]
        pr.start

        render :json => ''
    end

    put '/process/:id/stop' do
        pr = @processes[params[:id].to_i]
        # send SIGTERM, if process not dead after 5 seconds send SIGKILL
        puts "sending TERM signal"
        pr.kill("-TERM")
        pr.wait(5)
        if pr.is_running
            puts "sending KILL signal"
            pr.kill("-KILL")
            pr.wait
        else
            puts "process died on its own"
        end

        render :json => ''
    end

    put '/process/:id' do
        data = incoming_json
        @processes[params[:id].to_i].cmd(data['cmd'])

        render :json => ''
    end

    attr_accessor :processes

    self.files_dir = 'public_html'
end

app = ProcessControlApp.new
app.processes = [ FfmpegSubprocess.new('Program'), FfmpegSubprocess.new('Multiviewer') ]
app.run

