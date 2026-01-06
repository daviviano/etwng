#!/usr/bin/env ruby

# Define input and output
input_file = "input/FRANCE.empire_save"
output_root = "output"
xml_input_dir = "output/xml"
json_output_dir = "output/json"

# Check if input file exists
unless File.exist?(input_file)
  puts "Error: Input file '#{input_file}' not found."
  exit 1
end

# Call esf2xml
puts "Calling esf2xml with input: #{input_file} and output: #{output_root}"
# esf2xml handles creating its own subdirs like 'raw' and 'cleaned'
success = system("ruby", "esf2xml", "--verbose", input_file, output_root)

if success
  puts "esf2xml completed successfully."
else
  puts "esf2xml failed."
  exit 1
end

# Call xml2json.rb
puts "Calling xml2json.rb with input: #{xml_input_dir} and output: #{json_output_dir}"
# Note: we use 'xml2json.rb' as the script name
success = system("ruby", "xml2json.rb", "--verbose", xml_input_dir, json_output_dir)

if success
  puts "xml2json.rb completed successfully."
else
  puts "xml2json.rb failed."
  exit 1
end
