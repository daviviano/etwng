#!/usr/bin/env ruby

require 'nokogiri'
require 'json'

class EsfParser
  def initialize(xml_string)
    @doc = Nokogiri::XML(xml_string)
  end

  def to_json
    root = @doc.root
    result = parse_node(root)
    JSON.pretty_generate(result)
  end

  private

  def parse_node(node)
    return nil if node.nil?
    
    # 1. Handle "MILITARY_FORCE" specifically to map unnamed <u> tags to keys
    if node['type'] == 'MILITARY_FORCE'
      return parse_military_force(node)
    end

    # 2. Handle "ARMY" specifically to capture the footer data
    if node['type'] == 'ARMY'
      return parse_army(node)
    end

    # 3. Handle recursive structures (ARMY_ARRAY, etc)
    if ['rec', 'ary'].include?(node.name)
      return parse_container(node)
    end

    # 4. Handle "land_unit" (Extract attributes)
    if node.name == 'land_unit'
      return parse_attributes(node)
    end
    
    # Fallback for other tags
    if node.text?
      text = node.text.strip
      return text.empty? ? nil : text
    end
    
    parse_container(node)
  end

  def parse_container(node)
    data = {}
    
    # If the container has a type, use it as a key context or just pass through
    # For UNITS_ARRAY, we want to return a list of the land_units inside
    if node['type'] == 'UNITS_ARRAY'
      units = []
      node.xpath('.//land_unit').each do |unit|
        units << parse_attributes(unit)
      end
      return units
    end

    # Generic container recursion
    node.children.each do |child|
      next if child.text? && child.text.strip.empty? # Skip whitespace
      next if child.comment? # Skip comments

      child_data = parse_node(child)
      next if child_data.nil?
      
      if child['type']
        key = child['type'].downcase
        data[key] = child_data
      elsif child.name == 'rec'
        # Handle nested recs without types if necessary
        data['data'] ||= []
        data['data'] << child_data
      elsif !child.name.empty? && child.name != 'text'
        # Handle other named tags (u, i, etc)
        key = child.name
        if data.key?(key)
          data[key] = [data[key]] unless data[key].is_a?(Array)
          data[key] << child_data
        else
          data[key] = child_data
        end
      end
    end
    
    # If we are at the root or a generic wrapper, structured return
    if node['type']
      return { node['type'].downcase => data } if node == @doc.root
      return data
    end
    data
  end

  # Specific mapper for MILITARY_FORCE to match your desired JSON output
  def parse_military_force(node)
    values = node.xpath('./u').map(&:text).map(&:to_i)
    {
      "army_id" => values[0],
      "character_id" => values[1]
    }
  end

  # Specific mapper for ARMY to combine Military Force, Units, and Footer data
  def parse_army(node)
    # Extract Military Force
    mf_node = node.at_xpath('./rec[@type="MILITARY_FORCE"]')
    military_force = parse_node(mf_node)

    # Extract Units
    units_node = node.at_xpath('./ary[@type="UNITS_ARRAY"]')
    units_array = parse_node(units_node)

    # Extract Footer Data (The unnamed tags at the bottom of ARMY)
    # We rely on specific tag types/order based on the provided XML
    footer_i_tags = node.xpath('./i').map(&:text).map(&:to_i)
    footer_u_tags = node.xpath('./u').map(&:text).map(&:to_i)
    under_siege = node.at_xpath('./no') ? false : true

    {
      "military_force" => military_force,
      "units_array" => units_array,
      "meta_data" => {
        "army_id_check" => footer_i_tags[0],
        "army_in_building_slot_id" => footer_u_tags[0],
        "under_siege" => under_siege,
        "escorting_ship_id" => footer_u_tags[1] || 0
      }
    }
  end

  # Convert XML attributes to a Hash with proper Types
  def parse_attributes(node)
    data = {}
    node.attributes.each do |k, v|
      val = v.value
      # Attempt to convert integers
      if val.match?(/^-?\d+$/)
        val = val.to_i 
      end
      data[k] = val
    end
    data
  end
end

if __FILE__ == $0
  verbose = false
  if ARGV[0] == "--verbose"
    verbose = true
    ARGV.shift
  end

  if ARGV.length != 2
    puts "Usage: ruby armyxml2json.rb [--verbose] <input_xml> <output_json>"
    exit 1
  end

  xml_path = ARGV[0]
  json_path = ARGV[1]

  unless File.exist?(xml_path)
    puts "Error: Input file #{xml_path} not found."
    exit 1
  end

  xml_string = File.read(xml_path)
  parser = EsfParser.new(xml_string)
  File.write(json_path, parser.to_json)
end
