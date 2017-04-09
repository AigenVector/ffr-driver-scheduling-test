#!/usr/bin/env ruby

require 'time'

# Calibration loop
count = 0
tot = 0
while true do
  print "\nSensor data ->"
  sensor_data = gets # obviously read from a sensor here instead of STDIN
  reading = sensor_data.to_i
  # start accumulating an average for proof that 
  # we are, in fact, getting consistent flow...
  #
  # we'll use the average to seed our high/low calculations next
  if reading > 0
    count += 1
    tot += reading
    puts "Flow began... average at #{tot/count}"
  else
    puts "Awaiting flow or sensor read incorrectly..."
    next
  end
  if count == 10
    puts "Calibrated after ten readings... finding systol/diastol cycles..."
  end
  if count >= 10 and count < 30
    # set up some counters to track what the 
    # highest throughput (potential systol) and 
    # lowest throughput(potential diastol)  we have seen are
    highest ||= tot/count
    lowest ||= tot/count

    # Do the actual comparison per loop
    if reading > highest
      highest = reading
      puts "New high of #{highest} found."
    elsif reading < lowest
      lowest = reading
      puts "New low of #{lowest} found."
    end
  end
  if count == 30
    # Keep the end users busy with some shiny TEXTTT!!!!
    puts "Proceeding with presumed systol of #{highest} and presumed diastol of #{lowest}..."
  end
  if count >=30 and count < 50
    # set up our variables if needed
    systol_duration_total ||= 0
    systol_count ||= 0
    diastol_duration_total ||= 0
    diastol_count ||= 0
    systol_timestamp ||= nil
    diastol_timestamp ||= nil
    state ||= :none

    # figure out if we are nearest to systol (highest) or diastol (lowest)
    diff_to_systol = (highest - reading).abs
    diff_to_diastol = (lowest - reading).abs
    if diff_to_systol > diff_to_diastol
      puts "Reading is in diastol range..."
      # we are diastol!!!
      case state
      when :none
        # we were not running and this is our first time.
        # let's get a timestamp and remember it for later... :)
        diastol_timestamp = DateTime.now
      when :diastol
        # we are _still_ diastol and waiting for the damn pump to switch back over
      when :systol
        # uh-oh!!! this is a time when we have just changed from systol to diastol...
        # let's remember this event too... :)
        diastol_timestamp = DateTime.now
        if !systol_timestamp.nil?
          systol_duration_total += (diastol_timestamp.to_time.to_f - systol_timestamp.to_time.to_f)
          systol_count += 1
        end
      end
      state = :diastol
    else
      puts "Reading is in systol range..."
      # we are systol!!!
      case state
      when :none
        # looks like we started out as systol for the first time.  Coolio :)
        # let's write this down...
        systol_timestamp = DateTime.now
      when :diastol
        # we have freshly changed over from diastol to systol.  This is an event to be remembered.
        systol_timestamp = DateTime.now
        if !diastol_timestamp.nil?
          diastol_duration_total += (systol_timestamp.to_time.to_f - diastol_timestamp.to_time.to_f)
          diastol_count += 1
        end
      when :systol
        # we are still in systol
      end
      state = :systol
    end
    puts "Average systol duration at #{systol_duration_total.to_f / systol_count}s" if systol_count > 0
    puts "Average diastol duration at #{diastol_duration_total.to_f / diastol_count}s" if diastol_count > 0
  end
  if count >=50
    diff_to_systol = (highest - reading).abs
    diff_to_diastol = (lowest - reading).abs
    if diff_to_systol > diff_to_diastol
      case state
      when :diastol
        # we are _still_ diastol and waiting for the damn pump to switch back over
      when :systol
        # it switched!!! time to kick into scheduled mode!!!
        break
      end
    else
      case state
      when :diastol
        # it switched!!! time to kick into scheduled mode!!!
        break
      when :systol
        # we are _still_ systol and waiting for the damn pump to switch back over
      end
    end
  end
end
# Scheduled mode!!!
while true do
  if state == :diastol
    puts "Flipping to diastol..."
    sleep (diastol_duration_total.to_f / diastol_count)
    state = :systol
  elsif state == :systol
    puts "Flipping to systol..."
    sleep (systol_duration_total.to_f / systol_count)
    state = :diastol
  end
end
