require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe ProgressLogger do
  before :each do
    @event_count = 0  # count used all over the place to check number of block calls made
  end
  context "when handling invalid parameters" do
    it "should throw an exception if not passed any step criteria" do
      lambda {
        ProgressLogger.new
      }.should raise_error ArgumentError
    end
    it "should throw an exception if not passed a block" do
      lambda {
        ProgressLogger.new(:step => 1)
      }.should raise_error ArgumentError
    end
    it "should throw an exception if step size is zero or less" do
      lambda {
        ProgressLogger.new(:step => 0) {}
      }.should raise_error ArgumentError
      lambda {
        ProgressLogger.new(:step => -1) {}
      }.should raise_error ArgumentError
    end
    it "should throw an exception if step time is zero or less" do
      lambda {
        ProgressLogger.new(:seconds => 0) {}
      }.should raise_error ArgumentError
      lambda {
        ProgressLogger.new(:minutes => 0) {}
      }.should raise_error ArgumentError
      lambda {
        ProgressLogger.new(:hours => 0) {}
      }.should raise_error ArgumentError
    end
    it "should throw an exception if total step time is negative" do
      ProgressLogger.new(:seconds => 61, :minutes => -1) {}  # weird, but ok
      lambda {
        ProgressLogger.new(:seconds => 60, :minutes => -1) {}
      }.should raise_error ArgumentError
    end
    it "should throw an exception if max count is zero or less" do
      lambda {
        ProgressLogger.new(:step => 1, :max => 0) {}
      }.should raise_error ArgumentError
      lambda {
        ProgressLogger.new(:step => 1, :max => -1) {}
      }.should raise_error ArgumentError
    end
    it "should not allow calculating an ETA without a max count specified" do
      p = ProgressLogger.new(:step => 1) do |state|
        puts state.short_eta
      end
      lambda {
        p.trigger
      }.should raise_error ArgumentError
      p2 = ProgressLogger.new(:step => 1) do |state|
        puts state.long_eta
      end
      lambda {
        p2.trigger
      }.should raise_error ArgumentError

    end
  end

  context "with numeric step size" do
    it "should call the passed block every time when called with size of one" do
      p = ProgressLogger.new(:step => 1) do
        @event_count += 1
      end
      p.trigger
      @event_count.should == 1
      p.trigger
      @event_count.should == 2
    end
    it "should call the passed block every second times shen called with a size of 2" do
      p = ProgressLogger.new(:step => 2) do
        @event_count += 1
      end
      p.trigger
      @event_count.should == 0
      p.trigger
      @event_count.should == 1
      p.trigger
      @event_count.should == 1
      p.trigger
      @event_count.should == 2
    end
    it "should let you find the loop count at any time, even when not triggered" do
      p = ProgressLogger.new(:step => 10000) do
        @event_count += 1
      end
      p.count.should == 0
      p.trigger
      @event_count.should == 0  # no trigger yet
      p.count.should == 1
    end
  end
  context "with time-based step size" do
    it "should trigger the body once after the specified number of seconds" do
      p = ProgressLogger.new(:seconds => 10) do
        @event_count += 1
      end
      p.trigger
      @event_count.should == 0
      Delorean.jump 10
      p.trigger
      @event_count.should == 1
    end
    it "should start time counting from the first trigger unless start has been called" do
      p = ProgressLogger.new(:seconds => 10) do
        @event_count += 1
      end
      Delorean.jump 10
      p.trigger
      @event_count.should == 0
      Delorean.jump 10
      p.trigger
      @event_count.should == 1
    end
    it "should start counting interval when start is called manually" do
      p = ProgressLogger.new(:seconds => 10) do
        @event_count += 1
      end
      p.start
      Delorean.jump 10
      p.trigger
      @event_count.should == 1
    end
    it "should trigger the body only once even if multiple time intervals have passed" do
      p = ProgressLogger.new(:seconds => 10) do
        @event_count += 1
      end
      p.trigger
      Delorean.jump 1000
      p.trigger
      @event_count.should == 1
    end
    it "should trigger based on interval since last trigger, not total elapsed time (as it's easier)" do
      p = ProgressLogger.new(:seconds => 10) do
        @event_count += 1
      end
      p.trigger
      Delorean.jump 1000
      p.trigger
      @event_count.should == 1
      Delorean.jump 10
      p.trigger
      @event_count.should == 2
    end
    after :each do
      Delorean.back_to_the_present
    end
  end
  context "with both time and steps" do
    it "should not let count based intervals interfere with time based" do
      p = ProgressLogger.new(:step => 2, :seconds => 10) do
        @event_count += 1
      end
      p.trigger
      Delorean.jump 5
      p.trigger  # fires an event due to step
      Delorean.jump 5
      p.trigger  # should fire an event due to time, even though it's only 5 seconds since last event
      @event_count.should == 2
    end
    it "should not fire two events if step and time events coincide" do
      p = ProgressLogger.new(:step => 1, :seconds => 10) do
        @event_count += 1
      end
      p.trigger
      @event_count.should == 1
      Delorean.jump 10
      p.trigger  # fires an event due to both criteria
      @event_count.should == 2
    end
  end
  context "passing context to the included block" do
    before :each do
      @states = []
      @p = ProgressLogger.new(:step => 10) do |state|
        @states << state
      end
    end
    it "should include the count of triggers called" do
      20.times {@p.trigger}
      @states.size.should == 2
      @states.collect {|s| s.count}.should == [10,20]
    end
    it "should include the count change since the last trigger" do
      20.times {@p.trigger}
      @states.size.should == 2
      @states.collect {|s| s.count_delta}.should == [10,10]
    end
    it "should include the time since the start time" do
      @p.start  # set initial time
      20.times do
        Delorean.jump 1
        @p.trigger
      end
      @states.size.should == 2
      @states[0].time_total.should be_close(10, 0.1)
      @states[1].time_total.should be_close(20, 0.1)
    end
    it "should include the time since the first trigger if no start specified" do
      20.times do
        Delorean.jump 1
        @p.trigger
      end
      @states.size.should == 2
      @states[0].time_total.should be_close(9, 0.1)
      @states[1].time_total.should be_close(19, 0.1)
    end
    it "should include the delta time since the previous trigger" do
      @p.start  # set initial time
      20.times do
        Delorean.jump 1
        @p.trigger
      end
      @states.size.should == 2
      @states[0].time_delta.should be_close(10, 0.1)
      @states[1].time_delta.should be_close(10, 0.1)
    end
  end
  context "when dealing with rates and ETAs" do
    before :each do
      @states = []
      @p = ProgressLogger.new(:step => 10, :max => 100) do |state|
        @states << state
      end
      # we can reuse the same scenario for all our tests:
      @p.trigger  # the first trigger is quick, but
      Delorean.jump 100 # the first interval is a big one - slow startup speed!
      19.times do
        Delorean.jump 1
        @p.trigger
      end
    end
    it "should include the processing rate based on overall processing" do
      @states.size.should == 2
      # after 10 triggers we've taken 109 seconds - pretty slow
      @states[0].long_rate.should be_close((10.0/109), 0.001)
      # after 20 triggers it's picked up, but not a lot:
      @states[1].long_rate.should be_close((20.0/119), 0.001)
    end
    it "should include the processing rate based on single-step processing" do
      @states.size.should == 2
      # after 10 triggers we've taken 109 seconds - pretty slow
      @states[0].short_rate.should be_close((10.0/109), 0.001)
      # after 20 triggers we can ignore the slow start time = now chugging along at 1 per second
      @states[1].short_rate.should be_close(1, 0.01)
    end
    it "should calculate an ETA based on overall processing" do
      @states.size.should == 2
      # after 10 triggers we've taken 109 seconds - pretty slow - should take us 1090 seconds for the lot
      @states[0].long_eta.should be_close(1090 - 109, 0.1)
      # after 20 triggers it's picked up, we've taken 119 seconds - should take us (119/20)*80 seconds to finish
      @states[1].long_eta.should be_close((119.0/20)*80, 0.1)
    end
    it "should calculate an ETA based on single-step processing" do
      @states.size.should == 2
      # after 10 triggers we've taken 109 seconds - same as the long-term situation - should take us 1090 seconds for the lot
      @states[0].short_eta.should be_close(1090 - 109, 0.1)
      # after 20 triggers it's picked up, we're now averaging 1 per second - should take us 80 seconds to finish
      @states[1].short_eta.should be_close(80, 0.1)
    end
  end
end
