class ProgressLogger
  def initialize(params = {}, &block)
    unless params[:step] || params[:seconds] || params[:minutes] || params[:hours]
      raise ArgumentError.new("You must specify a :step, :seconds, :minutes or :hours interval criterion to ProgressLogger")
    end
    unless block_given?
      raise ArgumentError.new("You must pass a block to ProgressLogger")
    end
    @stepsize = params[:step]
    raise ArgumentError.new("Step size must be greater than 0") if @stepsize && @stepsize <= 0

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
    @start_time = Time.now
    @last_report = Time.now
    @last_count = 0
  end

  def trigger
    @count += 1
    now = Time.now
    delta = now - @last_report
    if (@count_based && @count % @stepsize == 0) || (@time_based && (delta > @seconds))
      @block.call(:count => @count, :delta_count => @count - @last_count, :delta_time => delta)
      @last_report = now
      @last_count = @count
    end
  end
end