node.default['sysctl']['params']['fs']['file-max'] = '204252'
include_recipe 'sysctl::apply'
include_recipe 'java'

# Make sure we have what we need to unpack archives
package 'unzip' do
  action :install
end

directory "#{node['opendj']['install_dir']}" do
  mode '0755'
end

cookbook_file "#{node['opendj']['installer_archive']}" do
  cookbook node['opendj']['cookbook_source']
  mode '0644'
end

user "#{node['opendj']['user']}" do
  comment 'OpenDJ user'
  system true
end

script 'unpack_archive' do
  interpreter 'bash'
  cwd "#{node['opendj']['install_dir']}"
  code <<-EOH
  unzip #{node['opendj']['installer_archive']}
  chown -R #{node['opendj']['user']} #{node['opendj']['home']}
  chmod -R a+r #{node['opendj']['home']}
  find #{node['opendj']['home']} -type d -print0 | xargs -0 chmod a+x
  EOH
  not_if "test -d #{node['opendj']['home']}"
end


node['opendj']['schema_files'].each do |schema|
  cookbook_file "#{node['opendj']['home']}/config/schema/#{schema}" do
    cookbook node['opendj']['cookbook_source']
    user 'opendj'
    source "schema/#{schema}"
    mode '0644'
  end
end

opendj_postinstallconfig 'default' do
  action :nothing
  subscribes :run, resources('script[unpack_archive]'), :immediately
end

set_limit 'opendj' do
  type 'soft'
  item 'nofile'
  value 65536
end

set_limit 'opendj' do
  type 'hard'
  item 'nofile'
  value 131072
end

cookbook_file "#{node['opendj']['home']}/dsml.war" do
  cookbook node['opendj']['cookbook_source']
  source "#{node['opendj']['dsml_war']}"
  mode '0644'
end

if node['opendj']['dsml_enabled']
  template "#{node['tomcat']['config_dir']}/Catalina/localhost/dsml.xml" do
    source 'dsml.xml.erb'
    mode 0644
  end
end

if node['opendj']['sync_enabled']
  group "#{node['opendj']['sync_group']}" do
    system true
  end
  user "#{node['opendj']['sync_user']}" do
    comment 'OpenDJ sync user'
    gid "#{node['opendj']['sync_group']}"
    system true
  end
  directory "#{node['opendj']['sync_dir']}" do
    owner "#{node['opendj']['sync_user']}"
    mode '0755'
  end
  directory "#{node['opendj']['sync_dir']}/.ssh" do
    owner "#{node['opendj']['sync_user']}"
    mode '0755'
  end
  template "#{node['opendj']['sync_dir']}/.ssh/authorized_keys" do
    owner "#{node['opendj']['sync_user']}"
    mode '0644'
  end
  template '/etc/cron.daily/ldapsync.sh' do
    mode '0755'
  end
end

results = Chef::Search::Query.new.search(:node, node['opendj']['replication']['host_search']).first
if !results.nil? && results.count > 1
  repargs = ''
  hostnum = 0
  results.each do |n|
    unless n.nil?
      host = n['ipaddress']
      hostnum += 1
      repargs << " --host#{hostnum} #{host}"
      repargs << " --port#{hostnum} #{node['opendj']['ssl_port']}"
      repargs << " --bindDN#{hostnum} \"#{node['opendj']['dir_manager_bind_dn']}\""
      repargs << " --bindPassword#{hostnum} #{node['opendj']['dir_manager_password']}"
      repargs << " --replicationPort#{hostnum} #{node['opendj']['replication']['port']} \\\n"
    end
  end
  file "#{node['opendj']['home']}/setup_replication.sh" do
    mode '0700'
    owner "#{node['opendj']['user']}"
    content <<-EOH
#!/bin/bash
#{node['opendj']['home']}/bin/dsframework create-admin-user \\
 --port #{node['opendj']['ssl_port']} \\
 --hostname 127.0.0.1 \\
 --bindDN "#{node['opendj']['dir_manager_bind_dn']}" \\
 --bindPassword "#{node['opendj']['dir_manager_password']}" \\
 --trustAll \\
 --userID #{node['opendj']['replication']['uid']} \\
 --set password:"#{node['opendj']['replication']['password']}"
#{node['opendj']['home']}/bin/dsreplication enable \\
 --adminUID #{node['opendj']['replication']['uid']} \\
 --adminPassword "#{node['opendj']['replication']['password']}" \\
 --baseDN #{node['opendj']['user_root_dn']} \\
#{repargs} --trustAll \\
 --no-prompt
    EOH
  end
end
