name 'opendj'
maintainer 'Elliot Kendall'
maintainer_email 'elliot.kendall@ucsf.edu'
license 'Apache 2.0'
description 'Installs OpenDJ LDAP server'
version '0.1.15'

recipe 'opendj', 'Installs OpenDJ LDAP server'

%w( redhat centos fedora ubuntu debian ).each do |os|
  supports os
end

depends 'limits', '~> 1.0.0'
depends 'sysctl', '~> 0.6.0'
