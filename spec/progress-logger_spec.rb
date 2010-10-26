require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe ProgressLogger do
  context "basic parameter options" do
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
  end

  context "with numeric step size" do
    it "should call the passed block every time when called with size of one" do
      count = 0
      p = ProgressLogger.new(:step => 1) do
        count += 1
      end
      p.trigger
      count.should == 1
      p.trigger
      count.should == 2
    end
    it "should call the passed block every N times shen called with a size of N" do
      count = 0
      p = ProgressLogger.new(:step => 2) do
        count += 1
      end
      p.trigger
      count.should == 0
      p.trigger
      count.should == 1
      p.trigger
      count.should == 1
      p.trigger
      count.should == 2
    end
  end
  context "with time-based step size" do
    it "should trigger the body once after the specified number of seconds" do
      count = 0
      p = ProgressLogger.new(:seconds => 10) do
        count += 1
      end
      p.trigger
      count.should == 0  # unless you have a *very* slow machine
      Delorean.jump 10
      p.trigger
      count.should == 1
    end
    it "should trigger the body only once even if multiple time intervals have passed" do
      count = 0
      p = ProgressLogger.new(:seconds => 10) do
        count += 1
      end
      Delorean.jump 1000
      p.trigger
      count.should == 1
    end
    it "should trigger based on interval since last trigger, not total elapsed time (as it's easier)" do
      count = 0
      p = ProgressLogger.new(:seconds => 10) do
        count += 1
      end
      Delorean.jump 1000
      p.trigger
      count.should == 1
      p.trigger
      count.should == 1
      Delorean.jump 10
      p.trigger
      count.should == 2
    end
    after :each do
      Delorean.back_to_the_present
    end
  end
end
