#!/usr/bin/env ruby
# 

require 'rubygems'
require 'ruby-debug'
require 'xmlsimple'
require 'bigdecimal'

class Trans
  attr_accessor :store, :sku, :amount, :currency
  
  def initialize(trans_array)
    @store, @sku, amount = trans_array    
    amount, @currency = amount.split(" ")
    @amount = BigDecimal(amount)
  end
  
  def to_usd(rates)
    return @amount if @currency == "USD"
    rate = rates["#{@currency}-USD"]
    bankers_round(@amount * rate.conversion)
  end
  
  :private
  def bankers_round(amount)
    scaled_amt = amount * 100
    even = (scaled_amt).to_i % 2 == 0
    if even
      if (scaled_amt).frac <= BigDecimal('.5')
        return (BigDecimal(scaled_amt.floor.to_s) / 100)
      else
        return (BigDecimal(scaled_amt.ceil.to_s) / 100)
      end
    else
      if (scaled_amt).frac < BigDecimal('.5')
        return (BigDecimal(scaled_amt.floor.to_s) / 100)
      else
        return (BigDecimal(scaled_amt.ceil.to_s) / 100)
      end
    end
  end 
end

class Rate
  attr_accessor :from, :to, :conversion  
  
  #{"from"=>["AUD"], "conversion"=>["1.0079"], "to"=>["CAD"]}
  def initialize(*args)
    if((args.size == 1) && (args.first.is_a? Hash))
      rate_hash = args.first
      @from = rate_hash["from"].first
      @to = rate_hash["to"].first
      @conversion = BigDecimal(rate_hash["conversion"].first)
    else
      @from, @to, @conversion = args
    end
  end
  
  def to_s
    "#{@from}-#{@to}=#{@conversion.to_s('F')}"
  end
end

def derive_missing_rates(rates)
  rates.delete_if{|key, val| val.from == "USD"} #we don't care about rates from USD
  until (unconverted_rates = rates.select{|key, val| val.to != "USD"}).empty? do
    rates.delete_if{|key,val| val.to != "USD" && rates["#{val.from}-USD"]} #if we already have a conversion from this to USD delete it
    to_usd = rates.select{|key, val| val.to == "USD"}
    to_usd.each do |u_key, val|
      convertable_rates = rates.select{|c_key, non_usd_rate | non_usd_rate.to == val.from }
      convertable_rates.each do |c_key, rate|
        rates["#{rate.from}-USD"] = Rate.new(rate.from, "USD", rate.conversion * val.conversion)
        rates.delete(c_key)
      end
    end
  end
end

trans_input = File.read(ARGV[0]).lines.to_a
trans_input.slice!(0) #discard first line
transactions = trans_input.collect { |trans_raw| Trans.new(trans_raw.split(",")) }

rates_xml = File.read(ARGV[1])
rates_obj = XmlSimple.xml_in(rates_xml)
rates = {}
rates_obj["rate"].each do |rate_obj| 
  rate = Rate.new(rate_obj)
  rates["#{rate.from}-#{rate.to}"] = rate
end
debugger

derive_missing_rates(rates)
debugger
sales_of_DM1182 = transactions.select{|trans| trans.sku == "DM1182"}
total = BigDecimal.new("0")
sales_of_DM1182.each {|trans| total += trans.to_usd(rates)}
puts("%05.2f" % total)



