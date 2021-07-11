require 'net/https'
require 'nokogiri'
require 'xcodeproj'
require 'json'

def source_for(url)
    uri = URI.parse(url)
    path = uri.path == "" ? "/" : uri.path
    result = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https' || uri.scheme == nil) { |http| http.get(path) }
    result.code.to_i == 200 ? result.body : nil
end

def extract_instatus(source)
    document = Nokogiri::HTML(source)

    document.css("#__NEXT_DATA__").each do |data|
        site = JSON.parse(data.inner_html)["props"]["pageProps"]["site"]
        name = site["name"]
        url = "https://#{site["subdomain"]}.instatus.com"

        create_file "stts/Services/Instatus/#{name}.swift", <<-INSTATUS
//
//  #{name}.swift
//  stts
//

import Foundation

class #{name}: InstatusService {
    let url = URL(string: "#{url}")!
}
        INSTATUS

        return true
    end

    return false
end

def extract_statuspage(url)
    source = source_for("#{url}/api/v2/summary.json")
    return false unless source

    page = JSON.parse(source)["page"]
    id = page["id"]
    name = page["name"]

    create_file "stts/Services/StatusPage/#{name}.swift", <<-STATUSPAGE
//
//  #{name}.swift
//  stts
//

import Foundation

class #{name}: StatusPageService {
    let url = URL(string: "#{url}")!
    let statusPageID = "#{id}"
}
    STATUSPAGE

    true
end

def create_file(path, content)
    File.open(path, "w") do |f|
        f.write(content)
    end

    puts "Created #{path}"

    # Open the existing Xcode project
    project_file = "stts.xcodeproj"
    project = Xcodeproj::Project.open(project_file)

    # Add a file to the project
    file_name = path.split("/").last
    group = project.main_group

    path.split("/")[0..-2].each do |group_name|
        group = group[group_name] if group[group_name]
    end

    # Get the file reference for the file to add
    file = group.new_file(file_name)

    # Add the file reference to the target
    main_target = project.targets.first
    main_target.add_file_references([file])

    # Sort it
    project.main_group.sort_recursively_by_type

    # Save it
    project.save

    puts "Created #{file_name} to project"
end

def sort_group(group)
    group.groups.each do |subgroup|
        sort_group(subgroup)
    end

    group.sort
end

def finish
    puts "Done!"
    exit
end

def fail_params
    puts "Usage:"
    puts "bundle exec ruby extract.rb <url>"
    puts
    puts "Example:"
    puts "bundle exec ruby extract.rb https://status.notion.so/"
end

def fail_network
    puts "Could not check that link :("
    puts "Network issue or invalid link?"
end

def fail
    puts "No service found :("
    puts "Maybe create a ticket? https://github.com/inket/stts/issues"
    exit
end

url = ARGV[0]
url = url.strip if url
fail_params unless url && url != ""

source = source_for(url)

fail_network unless source

finish if extract_instatus(source)
finish if extract_statuspage(url)

sort

fail
