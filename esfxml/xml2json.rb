#!/usr/bin/env ruby

require 'rexml/document'
require 'json'
require 'fileutils'
require_relative 'armyxml2json'
require_relative 'regionxml2json'

def xml_to_hash(element)
  result = {}

  # Process Attributes
  element.attributes.each do |name, value|
    result[name] = value
  end

  # Process Children
  element.elements.each do |child|
    child_data = xml_to_hash(child)

    if result.key?(child.name)
      if result[child.name].is_a?(Array)
        result[child.name] << child_data
      else
        result[child.name] = [result[child.name], child_data]
      end
    else
      result[child.name] = child_data
    end
  end

  # Process Text
  if element.has_text?
    text = element.text.strip
    unless text.empty?
      if result.empty?
        return text 
      else
        result['content'] = text
      end
    end
  end

  result.empty? ? nil : result
end

def convert_xml_to_json(xml_path, json_path)
  xml_file = File.new(xml_path)
  doc = REXML::Document.new(xml_file)
  
  if doc.root
    hash = { doc.root.name => xml_to_hash(doc.root) }
    
    File.open(json_path, "w") do |f|
      f.write(JSON.pretty_generate(hash))
    end
  else
    puts "  Error: No root element found in #{xml_path}"
  end
end

def convert_army_xml_to_json(xml_path, json_path)
  # Call the specialized army script
  args = ["ruby", "armyxml2json.rb"]
  args << "--verbose" if @verbose
  args << xml_path
  args << json_path
  success = system(*args)
  unless success
    puts "  Error: armyxml2json.rb failed for #{xml_path}"
  end
end

def convert_region_xml_to_json(xml_path, json_path)
  # Call the specialized region script
  args = ["ruby", "regionxml2json.rb"]
  args << "--verbose" if @verbose
  args << xml_path
  args << json_path
  success = system(*args)
  unless success
    puts "  Error: regionxml2json.rb failed for #{xml_path}"
  end
end

@verbose = false
if ARGV[0] == "--verbose"
  @verbose = true
  ARGV.shift
end

if ARGV.length != 2
  puts "Usage: ruby xml2json.rb [--verbose] <input_dir> <output_dir>"
  exit 1
end

input_dir = ARGV[0]
output_dir = ARGV[1]

# User requested ability to iterate through these subdirectories
sub_dirs_to_process = ['army', 'region']

unless Dir.exist?(input_dir)
  puts "Error: Input directory '#{input_dir}' not found."
  exit 1
end

FileUtils.mkdir_p(output_dir)

# Iterate through each faction directory
Dir.foreach(input_dir) do |faction|
  next if faction == '.' || faction == '..'
  
  faction_path = File.join(input_dir, faction)
  next unless File.directory?(faction_path)
  
  puts "Processing faction: #{faction}" if @verbose
  
  sub_dirs_to_process.each do |sub_dir|
    sub_dir_path = File.join(faction_path, sub_dir)
    next unless Dir.exist?(sub_dir_path)
    
    # Create matching output directory
    target_output_dir = File.join(output_dir, faction, sub_dir)
    FileUtils.mkdir_p(target_output_dir)
    
    # Find all XML files in the subdirectory
    Dir.glob(File.join(sub_dir_path, "*.xml")).each do |xml_path|
      filename = File.basename(xml_path, ".xml")
      json_path = File.join(target_output_dir, "#{filename}.json")
      
      begin
        if sub_dir == "army"
          convert_army_xml_to_json(xml_path, json_path)
        elsif sub_dir == "region"
          convert_region_xml_to_json(xml_path, json_path)
        else
          convert_xml_to_json(xml_path, json_path)
        end
      rescue REXML::ParseException => e
        puts "  Error parsing XML in #{xml_path}: #{e.message}"
      rescue => e
        puts "  An error occurred processing #{xml_path}: #{e.message}"
      end
    end

    # Aggregate armies if we just processed the army directory
    if sub_dir == "army"
      final_file = File.join(target_output_dir, "army_final.json")
      puts "  Aggregating armies for #{faction}..." if @verbose
      aggregate_args = ["ruby", "armyxml2json.rb"]
      aggregate_args << "--verbose" if @verbose
      aggregate_args << "--aggregate"
      aggregate_args << target_output_dir
      aggregate_args << final_file
      system(*aggregate_args)
    end
  end
end

puts "Conversion complete. JSON files are in #{output_dir}"
