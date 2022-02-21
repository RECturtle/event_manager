require "csv"
require "date"
require "erb"
require "google/apis/civicinfo_v2"

TIME = Time.new

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, "0")[0..4]
end

def clean_phone_number(phone_number)
  clean_phone = phone_number.tr("^0-9", "")
  if clean_phone.length == 10
    return clean_phone
  elsif clean_phone.length == 11 and clean_phone[0] == "1"
    clean_phone.slice(1..)
  else
    return nil
  end
end

def find_counts(times)
  freq = times.each_with_object(Hash.new(0)) do |hour, counts|
    counts[hour] += 1
  end
  return freq.sort_by { |k, v| -v }
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  # Note: This is a key provided by the odin project, not some super secret
  civic_info.key = "AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw"

  begin
    legislators = civic_info.representative_info_by_address(
      address: zipcode,
      levels: "country",
      roles: ["legislatorUpperBody", "legislatorLowerBody"],
    ).officials
  rescue
    "You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials"
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir("output") unless Dir.exist?("output")

  filename = "output/thanks_#{id}.html"

  File.open(filename, "w") do |file|
    file.puts form_letter
  end
end

def save_contacts(f_name, l_name, phone)
  File.open("contacts_#{TIME.strftime("%d_%m_%Y")}.txt", "a") do |file|
    file.puts "#{(f_name + " " + l_name).ljust(20)} #{phone || "No phone number provided"}"
  end
end

def hour_count_report(hour_counts)
  File.open("hourly_reg_count_report_#{TIME.strftime("%d_%m_%Y")}.txt", "w") do |file|
    file.puts "The most active registration hours are:"
    hour_counts.each_with_index do |hour_count, idx|
      file.puts "#{idx + 1}: Hour: #{hour_count[0]} - Registration Count: #{hour_count[1]}"
    end
  end
end

def day_count_report(day_counts)
  File.open("day_of_week_reg_count_report_#{TIME.strftime("%d_%m_%Y")}.txt", "w") do |file|
    file.puts "The most active registration days are:"
    day_counts.each_with_index do |day_count, idx|
      file.puts "#{idx + 1}: Day: #{Date::DAYNAMES[day_count[0]]} - Registration Count: #{day_count[1]}"
    end
  end
end

puts "EventManager initialized."

contents = CSV.open("event_attendees.csv", headers: true, header_converters: :symbol)
template_letter = File.read("form_letter.erb")
erb_template = ERB.new template_letter
hours = []
days = []

contents.each do |row|
  id = row[0]
  f_name = row[:first_name]
  l_name = row[:last_name]

  reg_date = DateTime.strptime(row[:regdate], "%m/%d/%y %H:%M")
  hours.append(reg_date.hour)
  days.append(reg_date.wday)

  zipcode = clean_zipcode(row[:zipcode])
  phone = clean_phone_number(row[:homephone])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)
  save_contacts(f_name, l_name, phone)
end

hour_count_report(find_counts(hours))
day_count_report(find_counts(days))

puts "EventManager complete."
