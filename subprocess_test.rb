# Copyright 2011 Exavideo LLC.
# 
# This file is part of Exaboard.
# 
# Exaboard is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# Exaboard is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with Exaboard.  If not, see <http://www.gnu.org/licenses/>.

require_relative 'subprocess.rb'
require 'test/unit'

class ASubprocess < Subprocess
    stdout /one/ do
        @stdout = 1
    end

    stderr /two/ do
        @stderr = 2
    end

    stderr /(match)/ do |match|
        @match = match[0]
    end

    cmd 'cat test_stdout.txt; cat test_stderr.txt 1>&2'

    attr_reader :stdout, :stderr, :match
end

class TestSubprocess < Test::Unit::TestCase
    def test_basics
        subp = ASubprocess.new
        subp.start

        subp.wait

        assert_equal 1, subp.stdout
        assert_equal 2, subp.stderr
        assert_equal 'match', subp.match
    end
end
