# Copyright (c) Facebook, Inc. and its affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Cookbook Name:: cpe_hosts
# Resource:: cpe_hosts

resource_name :cpe_hosts
provides :cpe_hosts
default_action :run

action :run do
  HOSTS_FILE = value_for_platform_family(
    'windows' =>
      ::File.join(
        (ENV['WINDIR'] || 'C:\\Windows'), 'System32', 'drivers', 'etc', 'hosts'
      ),
    'default' => '/etc/hosts'.freeze,
  )
  lines = ::File.readlines(HOSTS_FILE)
  chef_managed = lines.select { |x| x.include?('# Chef Managed') }
  if chef_managed && node['cpe_hosts']['manage_by_line']
    require 'English'
    LINE_MARKER = ' # Chef Managed' + $RS
    host_entries = node['cpe_hosts']['extra_entries'].reject do |_k, v|
      v.nil? || v.empty?
    end
    lines = get_user_added_entries(lines)
    unless host_entries.empty?
      host_entries.each do |ip, names|
        entry = ip + ' ' + names.join(' ')
        lines.push(entry + LINE_MARKER)
      end
    end

    # Write out the new `/etc/hosts` file using the normal chef machinery.
    # The defaults for `file` will only write the file if the contents has
    # changed, and will do so atomically.
    file HOSTS_FILE do
      retries 2
      ignore_failure true
      unless node.windows?
        owner node.root_user
        group node.root_group
        mode '0644'
      end
      content lines.join
    end
  else
    template HOSTS_FILE do # ~FB031
      retries 2
      ignore_failure true
      source 'hosts.erb'
      unless node.windows?
        owner node.root_user
        group node.root_group
        mode '0644'
      end
    end
  end
end

def get_user_added_entries(lines)
  excluded_lines = [
    'Generated by Chef',
    'Local modifications will be overwritten',
    'Chef Managed',
  ]
  user_added_entries = []
  lines.each do |line|
    unless excluded_lines.any? { |l| line.include?(l) }
      user_added_entries << line
    end
  end
  user_added_entries
end
