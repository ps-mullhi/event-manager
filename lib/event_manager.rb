require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'


def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  phone_number = phone_number.gsub(/[^0-9]/, '')

  if phone_number.length < 10 || phone_number.length > 11
    phone_number = 'No Phone Number'
  elsif phone_number.length == 11
    if phone_number[0] == "1"
      phone_number = phone_number[1..10]
    else
      phone_number = 'No Phone Number'
    end
  end

  unless phone_number == 'No Phone Number'
    phone_number = phone_number.insert(3, '-')
    phone_number = phone_number.insert(7, '-')
  end

  phone_number
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('secret.key').strip

  begin
    legislators = civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def most_sign_ups_per_hour(reg_by_hour)
  most_sign_ups_per_hour = 0
  reg_by_hour.each do |reg|
    if reg > most_sign_ups_per_hour
      most_sign_ups_per_hour = reg
    end
  end

  most_sign_ups_per_hour
end

def most_popular_hours(reg_by_hour, most_sign_ups_per_hour)
  most_popular_hours = Array.new
  reg_by_hour.each_with_index do |reg, i|
    if reg == most_sign_ups_per_hour
      most_popular_hours.push(i)
    end
  end

  most_popular_hours
end

puts 'Event Manager Initialized!'

unless File.exist? "event_attendees.csv"
  abort('event_attendees.csv does not exist!')
end
unless File.exist? "form_letter.erb"
  abort('form_letter.erb does not exist!')
end

contents = CSV.open(
  'event_attendees.csv', 
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

reg_by_hour = Array.new(23) {0}
contents.each do |row|
  id = row[0]
  name = row[:first_name]
  phone_number = clean_phone_number(row[:homephone])
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)  
  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)

  date, time = row[:regdate].split(' ')
  hour, minute = time.split(':')
  reg_by_hour[hour.to_i] += 1
end

most_sign_ups_per_hour = most_sign_ups_per_hour(reg_by_hour)
most_popular_hours = most_popular_hours(reg_by_hour, most_sign_ups_per_hour)

p most_popular_hours


