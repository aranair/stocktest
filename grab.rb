require 'csv'
require 'net/http'

DAY_COUNT=40
IMPLIED_VOL=0.005 # 1% underlying

EXCHANGE="HKG"
tickers = [
  '3333',
  '0968',
  '0836',
  '3988',
  '2318',
  '1023',
]

# EXCHANGE="NASDAQ"
# tickers = [
#   'GOOGL',
#   'AMZN',
#   'FB',
#   'NFLX'
# ]

def curl_data(ticker)
  uri = URI("https://www.google.com/finance/getprices?i=3600&p=#{DAY_COUNT}d&f=d,o,h,l,c,v&df=cpct&q=#{ticker}&x=#{EXCHANGE}")
  res = Net::HTTP.get_response(uri)
  res.body.split("\n")[9..-1].map { |r| r.split(",") }
end

# https://www.google.com/finance/getprices?i=3600&p=20d&f=d,o,h,l,c,v&df=cpct&q=3333&x=HKG
def calculate_for(ticker)
  days, current_day = [], []
  prev, diff = 0, 0

  # Separate out per day
  # CSV.foreach("#{ticker}.csv") do |row|
  curl_data(ticker).each do |row|
    idx, close, high, low, open, volume = row.map { |r| r.to_f }
    diff = idx - prev

    # idx is separated by 10
    if diff > 10
      days << current_day
      current_day = []
    else
      current_day << {
        idx: idx,
        close: close,
        high: high,
        low: low,
        open: open,
        volume: volume
      }
    end
    prev = idx
  end

  fail_count, success_count = 0, 0
  days.each do |day|
    second_hour = day[1]
    vol = second_hour[:high] - second_hour[:open]
    target = if vol > 0
               second_hour[:high] * (1 - IMPLIED_VOL) # From uptrend to downtrend
             else
               second_hour[:high] * (1 + IMPLIED_VOL) # From downtrend to uptrend
             end

    # Starting from third hour, see if it is between low/high
    # If found -> trade succeeded
    target_earliest_hour = nil
    day[2..-1].each_with_index do |hour, index|
      if target > hour[:low] and target < hour[:high]
        target_earliest_hour = index
        break
      end
    end

    if target_earliest_hour.nil?
      fail_count += 1
      # p 'Failed'
    else
      success_count += 1
      # p target_earliest_hour + 3
    end

    # day_high = day[2..-1].map { |x| x[:high] }.max
    # day_low = day[2..-1].map { |x| x[:low] }.min
    # day_vol = day_high - day_low
    # p "magnitude: #{magnitude.round(3)}, day_high: #{day_high}, day_low: #{day_low}, day_vol: #{day_vol}"
  end

  puts "TICKER: #{ticker}, Total failed : #{fail_count}, Total sucesss: #{success_count}, Percentage: #{success_count*1.0/(success_count+fail_count)*100}"
end

tickers.each do |ticker|
  calculate_for(ticker) # 1%
end
