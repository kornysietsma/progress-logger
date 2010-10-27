# ProgressLogger is a simple tool for regular progress logging in a long-running loop
#
# Author:: Kornelis Sietsma (mailto: korny@sietsma.com)
# Copyright:: Copyright (c) 2010 Kornelis Sietsma. See LICENSE for details.

# The ProgressLogger class is the workhorse of this gem - it is used to wrap your logging code (or whatever you are doing)
# you construct it with a set of criteria for when it should log, and a block to do the actual logging (or other activity):
# <tt> p = ProgressLogger.new(:count => 100000, :minutes => 30) do |state|
#     puts "processed #{state.count} rows"
# end</tt>
# and then every time "p.trigger()" is called:
# * p.count is incremented
# * if p.count is a multiple of 100000, or 30 minutes have passed since the last time-based tick
# ** the block is called, with a 'state' object as a parameter
#
# You can do pretty well anything you want in the passed block - log something, flush a database, update a gui, whatever.
#
# See the ProgressLogger::State class for what you can get from the state object

class ProgressLogger

  # Internal state passed to the ProgressLogger block whenever the criteria are met.
  # count is the current count of triggers processed
  # now is the Time.now value when this action was triggered (useful if you are handling state slowly)
  class State
    attr_reader :count, :now
    # the number of triggers processed since the last action
    def count_delta
      @count - @last_count
    end
    # the amount of time passed since the first trigger (or since ProgressLogger.start was called)
    def time_total
      @now - @start_time
    end
    # the amount of time passed since the last action
    def time_delta
      @now - @last_report
    end
    # the processing rate, in triggers-per-second, using the count since the last action for a short-term speed
    # * will return nil if this is called on the very first call to trigger, as no time will have elapsed!
    def short_rate
      return nil if @now == @last_report
      (@count - @last_count) / (1.0 * (@now - @last_report))
    end
    # the processing rate, in triggers-per-second, using the count since the first action for a long-term speed
    # * will return nil if this is called on the very first call to trigger, as no time will have elapsed!
    def long_rate
      return nil if @now == @start_time
      (@count - @start_count) / (1.0 * (@now - @start_time))
    end
    # the estimated time to complete, based on the short-term speed (short_rate)
    # * raises ArgumentError if you don't have a :max parameter in the main ProgressLogger constructor
    # * will return nil if this is called on the very first call to trigger, as no time will have elapsed!
    def short_eta
      raise ArgumentError.new("Can't calculate ETA when no max specified") if @max.nil?
      rate = short_rate
      return nil if rate.nil?
      return (@max - @count) / rate
    end
    # the estimated time to complete, based on the long-term speed (long_rate)
    # * raises ArgumentError if you don't have a :max parameter in the main ProgressLogger constructor
    # * will return nil if this is called on the very first call to trigger, as no time will have elapsed!
    def long_eta
      raise ArgumentError.new("Can't calculate ETA when no max specified") if @max.nil?
      rate = long_rate
      return nil if rate.nil?
      return (@max - @count) / rate
    end
    private
    def initialize(count, start_count, now, start_time, last_report, last_count, max = nil)
      @count = count
      @start_count = start_count
      @now = now
      @start_time = start_time
      @last_report = last_report
      @last_count = last_count
      @max = max
    end
  end
  # count of triggers processed so far
  attr_reader :count

  # create a ProgressLogger with specified criteria
  # you *must* specify either a :step or one of :seconds, :minutes, and/or :hours
  # parameters:
  # * :step - the passed block is called after this many calls to trigger()
  # * :seconds, :minutes, :hours - the passed block is called after this number of seconds/minutes/hours
  # ** you can specify more than one of these, they'll just get added together
  # * :max - this is an expected maximum number of triggers - it's used to calculate eta values for the ProgressLogger::State object
  # * block - you must pass a block, it is called (with a state parameter) when the above criteria are met

  def initialize(params = {}, &block)
    unless params[:step] || params[:seconds] || params[:minutes] || params[:hours]
      raise ArgumentError.new("You must specify a :step, :seconds, :minutes or :hours interval criterion to ProgressLogger")
    end
    unless block_given?
      raise ArgumentError.new("You must pass a block to ProgressLogger")
    end
    @stepsize = params[:step]
    raise ArgumentError.new("Step size must be greater than 0") if @stepsize && @stepsize <= 0
    @max = params[:max]
    raise ArgumentError.new("Max count must be greater than 0") if @max && @max <= 0

    @count_based = params[:step]
    @time_based = params[:seconds] || params[:minutes] || params[:hours]
    if @time_based
      @seconds = params[:seconds] || 0
      @seconds += params[:minutes] * 60 if params[:minutes]
      @seconds += params[:hours] * 60 * 60 if params[:hours]
      raise ArgumentError.new("You must specify a total time greater than 0") if @seconds <= 0
    end

    @count = 0
    @block = block
    @started = false  # don't start yet - allow for startup time in loops; can start manually with start() below
  end

  # manually start timers
  # normally timers are initialized on the first call to trigger() - this is because quite often, a processing loop
  # like the following has a big startup time as cursors are allocated etc:
  # <tt>
  # p = ProgressLogger.new ...
  # @db.find({:widget => true).each do  # this takes 5 minutes to cache cursors!
  #   p.trigger
  # </tt>
  # If the timers were initialized when ProgressLogger.new was called, they'd be messed up by the loop start time.
  # If for some reason you want the timers to be manually started earlier, you can explicitly call start,
  # optionally passing it your own special version of Time.now
  def start(now = Time.now)
    @started = true
    @start_time = now
    @last_report = now
    @last_timecheck = now  # last time interval, so count-based reports don't stop time-based reports
    @start_count = @last_count = @count
  end

  # trigger whatever regular event you are watching - if the criteria are met, this will call your block of code
  def trigger
    start unless @started  # note - will set start and last counts to 0, which may be slightly inaccurate!
    @count += 1
    now = Time.now
    if @time_based
      time_delta = now - @last_timecheck
      its_time = (time_delta > @seconds)
    else
      its_time = false
    end
    its_enough = @count_based && (@count % @stepsize == 0)
    if its_time || its_enough
      run_block now
      @last_report = now
      @last_count = @count
      @last_timecheck = now if its_time
    end
  end

  private

  def run_block(now)
    @block.call(State.new(@count, @start_count, now, @start_time, @last_report, @last_count, @max))
  end

end